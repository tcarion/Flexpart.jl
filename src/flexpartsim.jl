
# """
#     $(TYPEDEF)

# Abstract supertype for FlexpartSim object that can be:
# - FlexpartSim{Deterministic} for deterministic flexpart runs
# - FlexpartSim{Ensemble} for ensemble flexpart runs
# """
# abstract type AbstractFlexpartDir end

abstract type SimType end

struct Deterministic <: SimType end
struct Ensemble <: SimType end

"""
    FpPathnames
Object that represents the `pathnames` file. The paths are expected in the following order:

    $(FIELDS)
"""
mutable struct FpPathnames <: AbstractPathnames
    dirpath::String
    options::String
    output::String
    input::String
    available::String
end
function FpPathnames(path::AbstractString)
    basename(path) == PATHNAMES_FILENAME || error("The name of the pathnames file should be `pathnames`")
    FpPathnames(dirname(path), readlines(path)...)
end
FpPathnames() = FpPathnames(DEFAULT_PATH_PATHNAMES)
getpath(pn::FpPathnames) = pn.dirpath

function save(pn::FpPathnames)
    open(pathnames_path(pn), "w") do f
        for (_, v) in pn
            Base.write(f, v*"\n")
        end
    end
end

pathnames_path(o) = joinpath(getpath(o), PATHNAMES_FILENAME) |> Base.abspath
pathnames_path(path::String) = joinpath(path, PATHNAMES_FILENAME) |> Base.abspath

"""
    $(TYPEDEF)
`FlexpartSim` represents the directory where the `pathnames` file is located. `pathnames` is the file indicating the paths 
to the files and directories needed by Flexpart (options, output, input and available).

The `FlexpartSim` object also indicates the type of the simulation:
- `FlexpartSim{Deterministic}` for deterministic flexpart runs
- `FlexpartSim{Ensemble}` for ensemble flexpart runs

If no type parameter is provided when using `FlexpartSim` constructors, the default will be `Deterministic`.
"""
struct FlexpartSim{SimType} <: AbstractFlexDir
    pathnames::FpPathnames
    simtype::SimType
end
getpathnames(fpsim::FlexpartSim) = fpsim.pathnames
getpath(fpsim::FlexpartSim) = getpath(getpathnames(fpsim))


"""
    $(TYPEDSIGNATURES)

Read the `pathnames` file in `path` to create a `FlexpartSim`.
"""
FlexpartSim{T}(path::String) where T = FlexpartSim(FpPathnames(path), T())
FlexpartSim(path::String) = FlexpartSim{Deterministic}(path)

"""
    $(TYPEDSIGNATURES)

Create a `FlexpartSim` in a temporary directory whith the default options and pathnames. It can be copied afterwards with [`copy`](@ref).

The default paths for the pathnames are:

    $(DEFAULT_PATHNAMES)

# Examples
```julia-repl
julia> FlexpartSim()
FlexpartSim{Deterministic} @ /tmp/jl_a8gDYX
pathnames:
        :options => "./options/"
        :output => "./output/"
        :input => "./input/"
        :available => "./AVAILABLE"
```
"""
function FlexpartSim{T}() where T
    path = mktempdir()
    return Flexpart.create(path; simtype = T)
end
FlexpartSim() = FlexpartSim{Deterministic}()

"""
    $(TYPEDSIGNATURES)

Apply the function `f` to a `FlexpartSim` created in a temporary directory, and remove all of its content upon completion.

# Examples
julia> FlexpartSim() do fpsim
            default_run(fpsim)
        end
```
"""
function FlexpartSim{T}(f::Function) where T
    mktempdir() do path
        fpsim = Flexpart.create(path; simtype = T)
        f(fpsim)
    end
end
FlexpartSim(f::Function) = FlexpartSim{Deterministic}(f)

function Base.show(io::IO, mime::MIME"text/plain", fpsim::FlexpartSim) 
    println(io,"$(typeof(fpsim)) @ $(getpath(fpsim))")
    show(io, mime, getpathnames(fpsim))
end
# Base.getindex(fpsim::FlexpartSim, name::Symbol) = getpathnames(fpsim)[name]
# Base.getindex(fpsim::FlexpartSim, name::Symbol) = joinpath(getpath(fpsim), getpathnames(fpsim)[name]) |> Base.abspath
# function Base.setindex!(fpsim::FlexpartSim, value::String, name::Symbol)
#     getpathnames(fpsim)[name] = value
# end


"""
    $(TYPEDSIGNATURES)

Copy an existing `FlexpartSim` to `path`.
"""
function copy(fpsim::FlexpartSim, path::String) :: FlexpartSim
    copyall(getpath(fpsim), path)
end

function create(path::String; simtype = Deterministic)
    copyall(DEFAULT_FP_DIR, path)
    newfpdir = FlexpartSim{simtype}(pathnames_path(path))
    newfpdir
end

function read_pathnames(fpsim::FlexpartSim)
    read_pathnames(pathnames_path(fpsim))
end

function read_pathnames(path::String)
    readlines(path)
end

# abspath(fpsim::FlexpartSim, type::Symbol) = joinpath(getpath(fpsim), fpsim[type]) |> Base.abspath

"""
    $(TYPEDSIGNATURES)

Write the current `FlexpartSim` paths to the `pathnames` file.
"""
function save(fpsim::FlexpartSim)
    save(getpathnames(fpsim))
end

"""
    $(TYPEDSIGNATURES)

Write the current `FlexpartSim` paths to the `pathnames` file. Relative paths are converted
to absolute path.
"""
function saveabs(fpsim::FlexpartSim)
    open(pathnames_path(fpsim), "w") do f
        for (k, _) in getpathnames(fpsim)
            Base.write(f, fpsim[k]*"\n")
        end
    end
end