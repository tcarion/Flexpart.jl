
# """
#     $(TYPEDEF)

# Abstract supertype for FlexpartDir object that can be:
# - FlexpartDir{Deterministic} for deterministic flexpart runs
# - FlexpartDir{Ensemble} for ensemble flexpart runs
# """
# abstract type AbstractFlexpartDir end

abstract type SimType end

abstract type Deterministic <: SimType end
abstract type Ensemble <: SimType end

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
`FlexpartDir` represents the directory where the `pathnames` file is located. `pathnames` is the file indicating the paths 
to the files and directories needed by Flexpart (options, output, input and available).

The `FlexpartDir` object also indicates the type of the simulation:
- `FlexpartDir{Deterministic}` for deterministic flexpart runs
- `FlexpartDir{Ensemble}` for ensemble flexpart runs

If no type parameter is provided when using `FlexpartDir` constructors, the default will be `Deterministic`.
"""
struct FlexpartDir{SimType} <: AbstractFlexDir
    path::String
    pathnames::FpPathnames
    # FlexpartDir(path::String) = is_fp_dir(path) && new(path)
end

"""
    $(TYPEDSIGNATURES)

Read the `pathnames` file in `path` to create a `FlexpartDir`.
"""
FlexpartDir(path::String) = FlexpartDir{Deterministic}(path, _fpdir_helper(path))
FlexpartDir{T}(path::String) where T = FlexpartDir{T}(path, _fpdir_helper(path))

"""
    $(TYPEDSIGNATURES)

Create a `FlexpartDir` in a temporary directory whith the default options and pathnames. It can be copied afterwards with [`copy`](@ref).

The default paths for the pathnames are:

    $(DEFAULT_PATHNAMES)

# Examples
```jldoctest
julia> FlexpartDir()
FlexpartDir{Deterministic} @ /tmp/jl_a8gDYX
pathnames:
        :options => "./options/"
        :output => "./output/"
        :input => "./input/"
        :available => "./AVAILABLE"
```
"""
function FlexpartDir{T}() where T
    path = mktempdir()
    copyall(DEFAULT_FP_DIR, path)
    FlexpartDir{T}(path)
end
FlexpartDir() = FlexpartDir{Deterministic}()

"""
    $(TYPEDSIGNATURES)

Apply the function `f` to a `FlexpartDir` created in a temporary directory, and remove all of its content upon completion.

# Examples
julia> FlexpartDir() do fpdir
            default_run(fpdir)
        end
```
"""
function FlexpartDir{T}(f::Function) where T
    mktempdir() do path
        copyall(DEFAULT_FP_DIR, path)
        fpdir = FlexpartDir(path)
        f(fpdir)
    end
end
FlexpartDir(f::Function) = FlexpartDir{Deterministic}(f)

function Base.show(io::IO, mime::MIME"text/plain", fpdir::FlexpartDir) 
    println(io,"$(typeof(fpdir)) @ $(fpdir.path)")
    show(io, mime, getpathnames(fpdir))
end
getpathnames(fpdir::FlexpartDir) = fpdir.pathnames
getpath(fpdir::FlexpartDir) = fpdir.path

# Base.getindex(fpdir::FlexpartDir, name::Symbol) = getpathnames(fpdir)[name]
# Base.getindex(fpdir::FlexpartDir, name::Symbol) = joinpath(getpath(fpdir), getpathnames(fpdir)[name]) |> Base.abspath
# function Base.setindex!(fpdir::FlexpartDir, value::String, name::Symbol)
#     getpathnames(fpdir)[name] = value
# end


"""
    $(TYPEDSIGNATURES)

Copy an existing `FlexpartDir` to `path`.
"""
function copy(fpdir::FlexpartDir, path::String) :: FlexpartDir
    copyall(getpath(fpdir), path)
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
# pathnames(fpdir::FlexpartDir) = fpdir.pathnames

function create(path::String)
    newdir = mkdir(path)
    copyall(DEFAULT_FP_DIR, newdir)
    newfpdir = FlexpartDir{Deterministic}(newdir)
    newfpdir
end

function pathnames(fpdir::FlexpartDir)
    pathnames(pathnames_path(fpdir))
end

function pathnames(path::String)
    readlines(path)
end
pathnames_path(fpdir::FlexpartDir) = joinpath(getpath(fpdir), DEFAULT_PATH_PATHNAMES) |> Base.abspath

# abspath(fpdir::FlexpartDir, type::Symbol) = joinpath(getpath(fpdir), fpdir[type]) |> Base.abspath

"""
    $(TYPEDSIGNATURES)

Write the current `FlexpartDir` paths to the `pathnames` file.
"""
function save(fpdir::FlexpartDir)
    open(pathnames_path(fpdir), "w") do f
        for (_, v) in getpathnames(fpdir)
            Base.write(f, v*"\n")
        end
    end
end

"""
    $(TYPEDSIGNATURES)

Write the current `FlexpartDir` paths to the `pathnames` file. Relative paths are converted
to absolute path.
"""
function saveabs(fpdir::FlexpartDir)
    open(pathnames_path(fpdir), "w") do f
        for (k, _) in getpathnames(fpdir)
            Base.write(f, fpdir[k]*"\n")
        end
    end
end