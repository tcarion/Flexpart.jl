module FlexpartInputs

using ..Flexpart: Flexpart, FlexpartDir, SimType, Deterministic, Ensemble, dateYY
using Dates
using DocStringExtensions

export 
    InputFiles, 
    Available, 
    DeterministicInput, 
    EnsembleInput,
    AbstractInputFile

const FLEXEXTRACT_OUTPUT_REG = r"^([A-Z]*)(\d{8,10})(\.N(\d{3}))?"

abstract type AbstractInputFile{T<:SimType} end

# abstract type AbstractFlexpartInput{SimType} end

"""
    DeterministicInput

Object that represents a deterministic input file.

$(TYPEDFIELDS)
"""
struct DeterministicInput <: AbstractInputFile{Deterministic}
    "Time of the input file"
    time::DateTime
    "Filename of the input file"
    filename::String
    "Absolute path of the directory"
    dirpath::String
end
DeterministicInput(path::String) = _input_helper(path, Deterministic)

"""
    EnsembleInput

Object that represents a ensemble input file.

$(TYPEDFIELDS)
"""
struct EnsembleInput <: AbstractInputFile{Ensemble}
    "Time of the input file"
    time::DateTime
    "Filename of the input file"
    filename::String
    "Ensemble member number of the input file"
    member::Int
    "Absolute path of the directory"
    dirpath::String
end
Base.convert(::Type{DeterministicInput}, in::EnsembleInput) = DeterministicInput(in.time, in.filename, in.dirpath)
EnsembleInput(path::String) = _input_helper(path, Ensemble)

getpath(input::AbstractInputFile) = joinpath(input.dirpath, input.filename)
Flexpart.grib_area(input::AbstractInputFile) = Flexpart.grib_area(getpath(input))
Flexpart.grib_resolution(input::AbstractInputFile) = Flexpart.grib_resolution(getpath(input))
Base.convert(::Type{String}, in::AbstractInputFile) = getpath(in)

function _input_helper(path::String, T)
    filename = basename(path)
    dirpath = dirname(path)
    m = match(FLEXEXTRACT_OUTPUT_REG, filename)
    if !isnothing(m)
        x = m.captures[2]
        m_sep = parse.(Int, [x[1:2], x[3:4], x[5:6], x[7:8]])
        formated_date = DateTime(m_sep...)
        T == Deterministic ? DeterministicInput(dateYY.(formated_date), filename, dirpath) : EnsembleInput(dateYY.(formated_date), filename, parse(Int, m.captures[4]), dirpath)
    end
end
# struct InputFiles{SimType} <: AbstractVector{AbstractInputFile} 
#     InputFiles{Deterministic}() = Vector{DeterministicInput}(undef, 0)
#     InputFiles{Ensemble}() = Vector{EnsembleInput}(undef, 0)
# end


"""
    $(TYPEDSIGNATURES)

Create a Vector of `AbstractInputFile` from reading the files in the `path` directory.
The files are expected to have the standard output format from `flex_extract`: <prefix>YYMMDDHH.N<ENSEMBLE_MEMBER>.
See [this link](https://www.flexpart.eu/flex_extract/Documentation/output.html) for more information.
"""
function InputFiles(T::Type{<:SimType}, path::String)
    files = readdir(path, join=true)
    if isempty(files) 
        InputFiles(T)
    else
        to_inputs(T, files)
    end
end
InputFiles(path::String) = InputFiles(Deterministic, path)
InputFiles(::Type{Deterministic}) = Vector{DeterministicInput}(undef, 0)
InputFiles(::Type{Ensemble}) = Vector{Ensemble}(undef, 0)

to_inputs(::Type{Deterministic}, files) = DeterministicInput.(files)
to_inputs(::Type{Ensemble}, files) = EnsembleInput.(files)

# TODO: Available struct is not really usefull, could be avoid, using always the same header
struct Available{T} <: AbstractVector{AbstractInputFile{T}}
    header::String
    path::String
    parent::Vector{<:AbstractInputFile{T}}
end
Available(inputfiles::Vector{<:AbstractInputFile{T}}, path) where T = Available{T}(
    """XXXXXX EMPTY LINES XXXXXXXXX
    XXXXXX EMPTY LINES XXXXXXXX
    YYYYMMDD HHMMSS   name of the file(up to 80 characters)""",
    path,
    inputfiles
    )
# Available(inputs::Vector{<:AbstractInputFile{T}}, path) where T = Available(InputFiles(T, inputs), path)
Available{T}(path) where T = Available{T}(InputFiles(T), path)
function Available{T}(avpath::String, inpath::String; fromdir = true) where T
    fromdir ? _available_from_dir(avpath, inpath, T) : _available_from_file(avpath, inpath, T)
end
Available(fpdir::FlexpartDir{T}, fromdir = true) where T = Available{T}(fpdir[:available], fpdir[:input], fromdir = fromdir)

Base.parent(av::Available) = av.parent
Base.size(av::Available) = size(parent(av))
Base.similar(av::Available, T::SimType, dims) = Available{T}(av.header, av.path, similar(parent(av), T, dims))
Base.similar(av::Available) = similar(parent(av))
Base.getindex(av::Available, i::Int) = getindex(parent(av), i)
Base.setindex!(av::Available, v, i::Int) = setindex!(parent(av), v, i)

_available_from_dir(avpath::String, inpath::String, T::Type{<:SimType}) = Available(InputFiles(T, inpath), avpath)


function _available_from_file(avpath::String, inpath::String, T::Type{<:SimType})
    lines = readlines(avpath)
    header, ioc = _header(lines)
    filelines = isnothing(ioc) ? lines : lines[ioc+1:end]
    filelines = filter(x -> x !== "", filelines)
    inputfiles = InputFiles(T)

    for l in filelines
        sl = split(l)
        date = DateTime(sl[1]*sl[2], "yyyymmddHHMMSS")
        filename = sl[3]
        m = match(FLEXEXTRACT_OUTPUT_REG, filename)
        toadd = T == Deterministic ? DeterministicInput(date, filename, inpath) : EnsembleInput(date, filename, parse(Int, m.captures[4]), inpath)
        push!(inputfiles, toadd)
    end

    Available{T}(header, avpath, inputfiles)
end

function _header(lines)
    ioc = findfirst(x -> occursin("YYYYMMDD HHMMSS", x), lines)
    headerlines = isnothing(ioc) ? [] : lines[1:ioc[1]]
    return join(headerlines, "\n"), ioc
end

function Flexpart.save(av::Available)
    (tmppath, tmpio) = mktemp()

    for line in format(av) Base.write(tmpio, line*"\n") end

    close(tmpio)
    dest = av.path

    mv(tmppath, dest, force=true)
end

function format(av::Available)
    strs = [av.header]
    for elem in av
        str = Dates.format(elem.time, "yyyymmdd")*" "*Dates.format(elem.time, "HHMMSS")*"      "*elem.filename*"      "*"ON DISK"
        push!(strs, str)
    end
    strs
end

end