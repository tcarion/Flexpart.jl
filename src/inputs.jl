abstract type InputStack end
abstract type AbstractVariables{T<:AbstractFloat} end

struct InputVariables{T<:AbstractFloat}
    u::Array{T, 3}
    v::Array{T, 3}
    t::Array{T, 3}
    qv::Array{T, 3}
    etadot::Array{T, 3}
    u10::Array{T, 2}
    v10::Array{T, 2}
    t2m::Array{T, 2}
    d2m::Array{T, 2}
    sp::Array{T, 2}
    sshf::Array{T, 2}
    z::Array{T, 2}
end
Base.getindex(v::InputVariables, name) = Base.getproperty(v, name)

struct ProcessedVariables{T<:AbstractFloat} <: AbstractVariables{T}
    # level pressures
    p_levs::Array{T, 3}
    # level heights
    h_levs::Array{T, 3}
    # Heights for vertical velocity grid
    h_w::Array{T, 3}
    # 3D variables interpolated on the reference heights
    u::Array{T, 3}
    v::Array{T, 3}
    t::Array{T, 3}
    qv::Array{T, 3}
    w::Array{T, 3}
end
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

    EcInputMeta(akm, bkm, akz, bkz, nlevel+1)
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

function load_layer(ec_input::EcInput, name)
    layer = ec_input[name]
    if hasdim(layer, Z)
        Array(layer[:,:,:,1])
    else
        Matrix(ec_input[name][:,:,1])
    end
end

function load_layers_3d(ec_input::EcInput)
    t = cat_layers(ec_input, :t2m, :t)

    u = cat_layers(ec_input, :u10, :u)
    v = cat_layers(ec_input, :v10, :v)

    qi = load_layer(ec_input, :q)
    q0 = Base.copy(qi[:,:,1])
    q = cat(q0, qi, dims = 3)

    etadot = load_layer(ec_input, :etadot)
    etadot = cat(etadot, zeros(eltype(etadot), size(etadot[:,:,1])), dims=3)
    u,v,t,q,etadot
end

cat_layers(ec_input::EcInput, l2d, l3d) = cat(load_layer(ec_input, l2d), load_layer(ec_input, l3d), dims = 3)

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

pressure_levels(ec_input::EcInput, sp) = cat([ec_input.vertical.(k, sp) for k in 1:138]..., dims = 3)

# function Base.setindex!(ec_input::EcInput, args...)
#     setindex!(ec_input.layers, args...)
# end

function InputVariables(ec_input::EcInput)
    # etadot = load_layer(ec_input, :etadot)
    d2m = load_layer(ec_input, :d2m)
    sp = load_layer(ec_input, :sp)
    sshf = load_layer(ec_input, :sshf)
    z = load_layer(ec_input, :z)
    u,v,t,w,etadot = load_layers_3d(ec_input)
    InputVariables{Float64}(u,v,t,w,etadot,
        u[:,:,1], v[:,:,1], t[:,:,1],
        d2m, sp, sshf, z
    )
end

"""
    (ecmeta::EcMeta)(ps::Real, ilevel::Int)
Give the pressure of the specified level of level border, given the surface pressure `ps` and the level number `ilevel`
"""
function (ecmeta::EcInputMeta)(ilevel::Int, ps::Real; border::Bool = false)
    @assert 1 <= ilevel <= ecmeta.nlevel
    ak = border ? ecmeta.akm : ecmeta.akz
    bk = border ? ecmeta.bkm : ecmeta.bkz
    ak[ilevel] + bk[ilevel] * ps
end

(ecmeta::EcInputMeta)(ps::Real; border::Bool = false) = ecmeta.(1:ecmeta.nlevel, ps; border)

struct InputGeometry
    # Number of longitudes
    nlon::Int
    # Number of latitudes
    nlat::Int
    # Number of vertical levels
    nlev::Int
    # grid spacing in longitude
    dlon::Float64
    # grid spacing in latitude
    dlat::Float64
    # array of longitudes in degrees (0...360˚)
    lond::Vector{Float64}
    # array of latitudes in degrees (90˚...-90˚)
    latd::Vector{Float64}
    # array of geometric heights in meters
    heights_ref::Vector{Float64}
    # array of pressure heights in Pa
    p_ref::Vector{Float64} 
end

function InputGeometry(ec_input::EcInput, variables::InputVariables, C::Constants)
    # the first hybrid layer should contain all the information about input geometry
    l = first(ec_input.layers[:hybrid])
    dimlon = dims(l, :X)
    dimlat = dims(l, :Y)
    dimlevels = dims(l, :Z)

    nlon = length(dimlon)
    nlat = length(dimlat)
    # We add one level at the surface were we put the surface fields
    nlev = length(dimlevels) + 1

    lond = dimlon |> collect
    latd = dimlat |> collect

    dlon = Rasters.step(dimlon)
    dlat = Rasters.step(dimlat)

    vertical = ec_input.vertical

    heights, p_refs = vertical_profiles(variables, vertical, C)

    InputGeometry(nlon, nlat, nlev, dlon, dlat, lond, latd, heights, p_refs)
end

Base.size(geom::InputGeometry) = (geom.nlon, geom.nlat, geom.nlev)

function ProcessedVariables(
    ec_input::EcInput,
    invars::InputVariables,
    geom::InputGeometry,
    C::Constants)

    @unpack u, v, t, qv, etadot, d2m, qv, sp = invars
    @unpack nlon, nlat, nlev = geom
    @unpack radius_earth = C

    p_levs = pressure_levels(ec_input, sp)

    h_levs = horizontal_height(p_levs, t, d2m, qv, C)

    h_w = similar(h_levs)
    fill!(h_w, 0.)

    # See verttransform_ecmwf.f90
    h_w[:,:,2:end-1] = 0.5 * (h_levs[:,:,3:end] + h_levs[:,:,2:end-1])
    h_w[:,:,end] = h_w[:,:,end-1] + h_levs[:,:,end] - h_levs[:,:,end-1]

    h_refs = geom.heights_ref

    uu, vv, tt, qvv, ww = _init_var_lev.((u,v,t,qv, etadot))
    
    idx = fill(2, (nlon, nlat))
    for k in 2:nlev-1
        h_ref = h_refs[k]
        for I in CartesianIndices(uu[:,:,k])
            i, j = Tuple(I)
            if h_ref > h_levs[i, j, end]
                uu[i,j,k] = uu[i,j,end]
                vv[i,j,k] = vv[i,j,end]
                tt[i,j,k] = tt[i,j,end]
                qvv[i,j,k] = qvv[i,j,end]
            else
                for kz in idx[I]:nlev
                    if idx[I] <= kz && (h_levs[i,j,kz-1] < h_ref <= h_levs[i,j,kz])
                        idx[I] = kz
                        continue
                    end
                end
            end
        end

        for I in CartesianIndices(uu[:,:,k])
            i, j = Tuple(I)
            if h_ref <= h_levs[i, j, end]
                kz = idx[I]
                dz1 = h_ref - h_levs[i,j,kz-1]
                dz2 = h_levs[i,j,kz] - h_ref
    
                Δz = dz1 + dz2
                uu[i,j,k] = (u[i,j,kz-1] * dz2 + u[i,j,kz] * dz1) / Δz
                vv[i,j,k] = (v[i,j,kz-1] * dz2 + v[i,j,kz] * dz1) / Δz
                tt[i,j,k] = (t[i,j,kz-1] * dz2 + t[i,j,kz] * dz1) / Δz
                qvv[i,j,k] = (qv[i,j,k-1] * dz2 + qv[i,j,k] * dz1) / Δz
            end
        end
    end
    # inds = h_refs .> h_levs[:,:,:]
    fac_conv = conversion_factor(h_levs, p_levs)

    # ww = fac_conv .* etadot

    # FIXME: Gives weird results with this multiplication factor  
    # ww = Base.copy(etadot)
    ww[:,:,1] = etadot[:,:,1] .* fac_conv[:,:,1]
    ww[:,:,end] = etadot[:,:,end] .* fac_conv[:,:,end]
    idx = fill(2, (nlon, nlat))
    for k in 2:nlev
        h_ref = h_refs[k]
        for I in CartesianIndices(ww[:,:,k])
            i, j = Tuple(I)
            for kz in idx[I]:nlev
                if idx[I] <= kz && (h_w[i,j,kz-1] < h_ref <= h_w[i,j,kz])
                    idx[I] = kz
                    continue
                end
            end
        end

        for I in CartesianIndices(ww[:,:,k])
            i, j = Tuple(I)
            # if h_ref <= h_levs[i, j, end]
                kz = idx[I]
                dz1 = h_ref - h_w[i,j,kz-1]
                dz2 = h_w[i,j,kz] - h_ref
    
                Δz = dz1 + dz2
                ww[i,j,k] = (etadot[i,j,kz-1] * fac_conv[i,j,kz-1] * dz2 
                    + etadot[i,j,kz] * fac_conv[i,j,kz] * dz1) / Δz
            # end
        end
    end

    # ww = ww .* fac_conv
    cosf = 1 ./ cosd.(geom.latd)

    idx = fill(2, (nlon, nlat))
    dxconst = 180. / (geom.dlon  * radius_earth * pi)
    dyconst = 180. / (geom.dlat  * radius_earth * pi)
    for k in 2:nlev-1
        h_ref = h_refs[k]
        for I in CartesianIndices(ww[:,:,k])[2:end-1, 2:end-1]
            i, j = Tuple(I)
            for kz in idx[I]:nlev
                if idx[I] <= kz && (h_levs[i,j,kz-1] < h_ref <= h_levs[i,j,kz])
                    idx[I] = kz
                    continue
                end
            end
        end

        for I in CartesianIndices(ww[:,:,k])[2:end-1, 2:end-1]
            i, j = Tuple(I)
            kz = idx[I]
            dz1 = h_ref - h_levs[i,j,kz-1]
            dz2 = h_levs[i,j,kz] - h_ref

            Δz = dz1 + dz2
            dzdx1=(h_levs[i+1,j,kz-1]-h_levs[i-1,j,kz-1])/2.
            dzdx2=(h_levs[i+1,j,kz]-h_levs[i-1,j,kz])/2.

            dzdx = (dzdx1 * dz2 + dzdx2 * dz1) / Δz

            dzdy1= ( h_levs[i,j+1,kz-1] - h_levs[i,j-1,kz-1] ) / 2.
            dzdy2=( h_levs[i,j+1,kz] - h_levs[i,j-1,kz] ) /2.

            dzdy = (dzdy1 * dz2 + dzdy2 * dz1) / Δz

            ww[i,j,k] += ( dzdx * uu[i,j,k] *  dxconst * cosf[j] + dzdy * vv[i,j,k] * dyconst ) 
        end
    end
    ProcessedVariables(p_levs, h_levs, h_w, uu, vv, tt, qvv, ww)
end

function _init_var_lev(from)
    to = similar(from)
    to[:,:,1] = from[:,:,1]
    to[:,:,end] = from[:,:,end]
    to
end

"""
    $(SIGNATURES)
Give the conversion factor to transform the vertical wind from Pa/s to m/s. (h₂ - h₁ / p₂ - p₁) 
"""
function conversion_factor(h_levs, p_levs)
    fac = similar(h_levs)
    conversion_factor!(fac, h_levs, p_levs)
    fac
    # cat(h_levs[:,:,k+1] -  for k in 1:138]..., dims = 3)
end

function conversion_factor!(fac, h_levs, p_levs)
    fac[:,:,1] = h_levs[:,:,2] ./ (p_levs[:,:,2] .- p_levs[:,:,1])
    for k in 2:size(fac, 3)-1
        fac[:,:,k] = (h_levs[:,:,k+1] .- h_levs[:,:,k-1])  ./ (p_levs[:,:,k+1] .- p_levs[:,:,k-1])
    end
    fac[:,:,end] = (h_levs[:,:,end] .- h_levs[:,:,end-1])  ./ (p_levs[:,:,end] .- p_levs[:,:,end-1])
end
struct Input
    time::DateTime
    invars::InputVariables
    procvars::ProcessedVariables
    geom::InputGeometry
end

function Input(finput::AbstractInputFile, C::Constants)
    ec_input = EcInput(finput)
    time = first(dims(first(ec_input.layers[:hybrid]), Ti))
    invars = InputVariables(ec_input)
    geom = InputGeometry(ec_input, invars, C)

    procvars = ProcessedVariables(ec_input, invars, geom, C)
    Input(time, invars, procvars, geom)
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
    # geometry::InputGeometry
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

    # geometry = InputGeometry(current.left)

    Inputs(
        # geometry,
        av_inputs,
        current
    )
end

function Base.show(io::IO, mime::MIME"text/plain", in::Inputs) 
    println(io, "available inputs:")
    show(io, mime, in.available)
end

function vertical_profiles(variables::InputVariables, vertical::EcInputMeta, C::Constants)
    @unpack R_gas, gravity = C
    ps = variables[:sp]
    t2d = variables[:d2m]
    t2 = variables[:t2m]
    t = variables[:t]
    w = variables[:qv]
    
    
    # Search for a point with high surface pressure (i.e. not above significant topography)
    # Then, use this point to construct a reference z profile, to be used at all times
    I = findfirst(x -> x > 1e5, ps)
    xi = I[1]
    yi = I[2]

    ps_ref = ps[I]
    td_surface = t2d[I]
    t_surface = t2[I]

    e = saturation_pressure(td_surface)
    tvold = virtual_temp(ps_ref, t_surface, e)

    heights = Vector{Float64}(undef, vertical.nlevel)
    heights[1] = 0.

    pold = ps_ref
    # we integrate the atmosphere state to get the height profile
    for k in 2:vertical.nlevel
        t_lev = t[xi, yi, k]
        w_lev = w[xi, yi, k]
        dz, tvold, pold = calc_Δz(k, ps_ref, t_lev, w_lev, tvold, pold, R_gas/gravity, vertical)
        heights[k] = heights[k-1] + dz
    end

    p_refs = vertical(ps_ref)
    heights, p_refs
end

function horizontal_height(plevs, t, d2m, w, C::Constants)
    @unpack R_gas, gravity = C
    rg = R_gas/gravity
    levels = similar(t)
    fill!(levels, 0.)

    p0 = plevs[:,:,1]
    e0 = saturation_pressure.(d2m)
    tvold = virtual_temp.(p0, t[:,:, 1], e0)
    pold = p0

    for k in 2:size(plevs, 3)
        tv = virtual_temp.(t[:,:,k], w[:,:,k])
        dz = _get_dz.(pold, plevs[:,:,k], tvold, tv, rg)
        levels[:,:,k] = levels[:,:,k-1] .+ dz
        tvold = tv 
        pold = plevs[:,:,k]
    end
    levels
end
function calc_Δz(k, ps_ref, t, w, tvold, pold, rg, vertical::EcInputMeta)
    p_lev = vertical(k, ps_ref)
    tv = virtual_temp(t, w)
    dz = _get_dz(pold, p_lev, tvold, tv, rg)
    dz, tv, p_lev
end

function _get_dz(p1, p2, t1, t2, rg)
    dt = t2 - t1
    if abs(dt) > 0.2
        dz = rg .* log.( p1 ./ p2 ) .* dt ./ log.( t2 ./ t1 )
    else
        dz = rg .* log.( p1 ./ p2 ) .* t2
    end
end
_get_left_date(inputs, date) = findlast(x -> x.time <= date, inputs)

function dict_layers(rasters)
    lt = keys(rasters)

    Dict(k => collect(keys(rasters[k])) for k in lt)
end
