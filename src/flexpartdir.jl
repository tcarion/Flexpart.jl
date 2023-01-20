
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
    options::String
    output::String
    input::String
    available::String
end
FpPathnames() = FpPathnames(DEFAULT_PATHNAMES...)

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
    path::String
    pathnames::FpPathnames
    simtype::SimType
end

"""
    $(TYPEDSIGNATURES)

Read the `pathnames` file in `path` to create a `FlexpartSim`.
"""
FlexpartSim(path::String) = FlexpartSim(path, _fpdir_helper(path), Deterministic())
FlexpartSim{T}(path::String) where T = FlexpartSim{T}(path, _fpdir_helper(path), T())

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
    copyall(DEFAULT_FP_DIR, path)
    FlexpartSim{T}(path)
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
        copyall(DEFAULT_FP_DIR, path)
        fpsim = FlexpartSim(path)
        f(fpsim)
    end
end
FlexpartSim(f::Function) = FlexpartSim{Deterministic}(f)

function Base.show(io::IO, mime::MIME"text/plain", fpsim::FlexpartSim) 
    println(io,"$(typeof(fpsim)) @ $(fpsim.path)")
    show(io, mime, getpathnames(fpsim))
end
getpathnames(fpsim::FlexpartSim) = fpsim.pathnames
getpath(fpsim::FlexpartSim) = fpsim.path

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

function _fpdir_helper(path::String)
    pn_path = joinpath(path, DEFAULT_PATH_PATHNAMES)
    isfile(pn_path) || error("No `pathnames` file has been found in the directory")
    try
        FpPathnames(pathnames(pn_path)...)
    catch e
        if isa(e, SystemError)
            FpPathnames()
        else
            throw(e)
        end
    end
end
# pathnames(fpsim::FlexpartSim) = fpsim.pathnames

function create(path::String)
    newdir = mkdir(path)
    copyall(DEFAULT_FP_DIR, newdir)
    newfpdir = FlexpartSim{Deterministic}(newdir)
    newfpdir
end

function pathnames(fpsim::FlexpartSim)
    pathnames(pathnames_path(fpsim))
end

function pathnames(path::String)
    readlines(path)
end
pathnames_path(fpsim::FlexpartSim) = joinpath(getpath(fpsim), DEFAULT_PATH_PATHNAMES) |> Base.abspath

# abspath(fpsim::FlexpartSim, type::Symbol) = joinpath(getpath(fpsim), fpsim[type]) |> Base.abspath

"""
    $(TYPEDSIGNATURES)

Write the current `FlexpartSim` paths to the `pathnames` file.
"""
function save(fpsim::FlexpartSim)
    open(pathnames_path(fpsim), "w") do f
        for (_, v) in getpathnames(fpsim)
            Base.write(f, v*"\n")
        end
    end
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