abstract type InputStack end

struct EcInput <: InputStack
    layers::Dict{Symbol, <:AbstractRasterStack}
    layer_types::Dict{Symbol, Vector{<:Symbol}}
end
function EcInput(finput::AbstractInputFile) 
    layers = read_input(finput)
    ltypes = dict_layers(layers)
    EcInput(layers, ltypes)
end

Base.show(io::IO, mime::MIME"text/plain", in::EcInput) = show(io, mime, in.layers)

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

"""
    Metadata for the vertical transformation of ECMWF η coordinates
"""
struct EcInputMeta
    # model discretization parameters at the center of each model layer
    akm::Vector{Float64}
    bkm::Vector{Float64}
    # Number of vertical η levels
    nlevel::Int32
end
function EcInputMeta(finput::AbstractInputFile)
    inpath = getpath(finput)
    coefs = Index(inpath, "typeOfLevel") do index
        # Find a message with hybrid levels
        select!(index, "typeOfLevel", "hybrid")
        # Get the coefficients for vertical level transformation
        Message(index)["pv"]
    end
    nlevel = Int(length(coefs) / 2 - 1)
    coefs = reshape(coefs, (nlevel+1, 2))
    EcInputMeta(coefs[:,1], coefs[:,2], nlevel)
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

_get_left_date(inputs, date) = findlast(x -> x.time <= date, inputs)