abstract type InputStack end

"""
    Metadata for the vertical transformation of ECMWF η coordinates
"""
struct EcInputMeta
    # model discretization parameters at the border of each model layer
    akm::Vector{Float64}
    bkm::Vector{Float64}

    # model discretization parameters at the center of each model layer
    akz::Vector{Float64}
    bkz::Vector{Float64}

    # Number of vertical η levels
    nlevel::Int32
end
function EcInputMeta(inpath::String)
    coefs = Index(inpath, "typeOfLevel") do index
        # Find a message with hybrid levels
        select!(index, "typeOfLevel", "hybrid")
        # Get the coefficients for vertical level transformation
        Message(index)["pv"]
    end
    nlevel = Int(length(coefs) / 2 - 1)
    coefs = reshape(coefs, (nlevel+1, 2))

    # We want the lower border of the model level to be at the start of the vector
    akm = reverse(coefs[:,1])
    bkm = reverse(coefs[:,2])

    # Calcualte the coefficient values at the model levels
    # Add an artificial model level with akz=0 and bkz=1.0 for the 10m wind
    akz = (akm[2:end] .+ akm[1:end-1]) * 0.5 
    bkz = (bkm[2:end] .+ bkm[1:end-1]) * 0.5
    pushfirst!(akz, 0.)
    pushfirst!(bkz, 1.)

    EcInputMeta(akm, bkm, akz, bkz, nlevel)
end
EcInputMeta(finput::AbstractInputFile) = EcInputMeta(getpath(finput))
struct EcInput <: InputStack
    layers::NamedTuple
    layer_types::Dict{Symbol, Vector{<:Symbol}}
    vertical::EcInputMeta
end
function EcInput(finput::AbstractInputFile) 
    layers = read_input(finput)
    vertical = EcInputMeta(finput)
    EcInput(layers, dict_layers(layers), vertical)
end

Base.show(io::IO, mime::MIME"text/plain", in::EcInput) = show(io, mime, in.layers)

function add_surface_level(ec_input::EcInput)
    t = ec_input[:t]
end
# Bypass the type of level specification
function Base.getindex(ec_input::EcInput, name::Symbol)
    ltypes = ec_input.layer_types
    for k in keys(ltypes)
        if name in ltypes[k]
            return getindex(ec_input.layers[k], name)
        end
    end
    throw(KeyError(name))
end

# function Base.setindex!(ec_input::EcInput, args...)
#     setindex!(ec_input.layers, args...)
# end

"""
    (ecmeta::EcMeta)(ps::Real, ilevel::Int)
Give the pressure of the specified level of level border, given the surface pressure `ps` and the level number `ilevel`
"""
function (ecmeta::EcInputMeta)(ilevel::Int, ps::Real; border = false)
    @assert 1 <= ilevel <= ecmeta.nlevel + 1
    ak = border ? ecmeta.akm : ecmeta.akz
    bk = border ? ecmeta.bkm : ecmeta.bkz
    ak[ilevel] + bk[ilevel] * ps
end

struct InputGeometry
    nlon::Int           # Number of longitudes
    nlat::Int           # Number of latitudes
    nlev::Int           # Number of vertical levels

    dlon::Float64                # grid spacing in longitude
    dlat::Float64                # grid spacing in latitude

    lond::Vector{Float64}   # array of longitudes in degrees (0...360˚)
    latd::Vector{Float64}   # array of latitudes in degrees (90˚...-90˚)
    levels::Vector{Float64}
end

function InputGeometry(ec_input::EcInput)
    # the first hybrid layer should contain all the information about input geometry
    l = first(ec_input.layers[:hybrid])
    dimlon = dims(l, :X)
    dimlat = dims(l, :Y)
    dimlevels = dims(l, :Z)

    nlon = length(dimlon)
    nlat = length(dimlat)
    nlev = length(dimlevels)

    lond = dimlon |> collect
    latd = dimlat |> collect
    levels = dimlevels |> collect

    dlon = Rasters.step(dimlon)
    dlat = Rasters.step(dimlat)

    InputGeometry(nlon, nlat, nlev, dlon, dlat, lond, latd, levels)
end

"""
    CurrentInputs

Meteorological fields wrapping the current time step. Needed for time interpolation of the fields.
"""
mutable struct CurrentInputs
    left::InputStack
    right::InputStack
end

struct Inputs{T <: SimType}
    geometry::InputGeometry
    available::Vector{<:AbstractInputFile{T}}
    current::CurrentInputs
end

function Inputs(P::Parameters)
    @unpack sim_type, inputs, command = P
    sim_start = command.sim_start

    av_inputs = FlexpartInputs.to_inputs(sim_type, inputs)
    sort!(av_inputs, by = x -> x.time)

    # Determine which input to take to start with
    il = _get_left_date(av_inputs, sim_start)
    
    # TODO: check upfront that sim_date is not after last available input
    current = CurrentInputs(
        EcInput(av_inputs[il]),
        EcInput(av_inputs[il + 1]),
    )

    geometry = InputGeometry(current.left)

    Inputs(
        geometry,
        av_inputs,
        current
    )
end

function Base.show(io::IO, mime::MIME"text/plain", in::Inputs) 
    println(io, "available inputs:")
    show(io, mime, in.available)
end

function height_profile(ec_input::EcInput, C::Constants)
    @unpack R_gas, gravity = C
    ps = ec_input[:sp]
    t2d = ec_input[:d2m]
    t2 = ec_input[:t2m]
    t = ec_input[:t]
    w = ec_input[:q]
    I = findfirst(x -> x > 1e5, ps)
    xi = I[1]
    yi = I[2]

    ps_ref = ps[I]
    td_surface = t2d[I]
    t_surface = t2[I]

    e = saturation_pressure(td_surface)
    tvold = virtual_temp(ps_ref, t_surface, e)

    heights = Vector{Float64}(undef, ec_input.vertical.nlevel+1)
    heights[1] = 0.

    vertical = ec_input.vertical

    # we take the surface variables for the first integration step
    dz, tvold, pold = calc_Δz(2, ps_ref, t_surface, w[Tuple(I)..., 1], tvold, ps_ref, R_gas/gravity, vertical::EcInputMeta)
    heights[2] = heights[1] + dz
    for k in 3:ec_input.vertical.nlevel+1
        t_lev = t[xi, yi, k-1, 1]
        w_lev = w[xi, yi, k-1, 1]
        dz, tvold, pold = calc_Δz(k, ps_ref, t_lev, w_lev, tvold, pold, R_gas/gravity, vertical)
        heights[k] = heights[k-1] + dz
    end
end

function calc_Δz(k, ps_ref, t, w, tvold, pold, rg, vertical::EcInputMeta)
    p_lev = vertical(k, ps_ref)
    tv = virtual_temp(t, w)
    dt = tv - tvold
    if abs(dt) > 0.2
        dz = rg * log( pold / p_lev ) * dt / log(tv/tvold)
    else
        dz = rg * log( pold / p_lev ) * tv
    end
    dz, tv, p_lev
end

_get_left_date(inputs, date) = findlast(x -> x.time <= date, inputs)

function dict_layers(rasters)
    lt = keys(rasters)

    Dict(k => collect(keys(rasters[k])) for k in lt)
end
