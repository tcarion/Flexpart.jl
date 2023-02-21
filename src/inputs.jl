
using DocStringExtensions


const AVAILABLE_HEADER = """XXXXXX EMPTY LINES XXXXXXXXX
XXXXXX EMPTY LINES XXXXXXXX
YYYYMMDD HHMMSS   name of the file(up to 80 characters)"""

const FLEXEXTRACT_OUTPUT_REG = r"(?<prefix>[A-Z]*)(?<year>\d{2})(?<month>\d{2})(?<day>\d{2})((\.(?<hour2>\d{2})\.(?<step>\d{3}))|(?<hour>\d{2}))(\.N(?<member>\d{3}))?"

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
DeterministicInput(path::String) = _input_from_filename(path)

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
EnsembleInput(path::String) = _input_from_filename(path)

getpath(input::AbstractInputFile) = joinpath(input.dirpath, input.filename)
grib_area(input::AbstractInputFile) = Flexpart.grib_area(getpath(input))
grib_resolution(input::AbstractInputFile) = Flexpart.grib_resolution(getpath(input))
Base.convert(::Type{String}, in::AbstractInputFile) = getpath(in)
Base.string(in::AbstractInputFile) = convert(String, in)

input_type(::AbstractInputFile{T}) where T = T

function _input_from_filename(path::String)
    filename = basename(path)
    dirpath = dirname(path)
    m = match(FLEXEXTRACT_OUTPUT_REG, filename)
    if !isnothing(m)
        valid_time = _construct_date(m)
        if isnothing(m[:member])
            DeterministicInput(valid_time, filename, dirpath)
        else
            EnsembleInput(valid_time, filename, parse(Int, m[:member]), dirpath)
        end
    else
        nothing
    end
end

function _input_from_available_line(line::String, inpath::String)
    sl = split(line)
    valid_time = DateTime(sl[1]*sl[2], "yyyymmddHHMMSS")
    filename = sl[3]
    m = match(FLEXEXTRACT_OUTPUT_REG, filename)
    if isnothing(m[:member])
        DeterministicInput(valid_time, filename, inpath)
    else
        EnsembleInput(valid_time, filename, parse(Int, m[:member]), inpath)
    end
end

function _construct_date(m)
    dtvec = [m[:year], m[:month], m[:day]]
    if isnothing(m[:step])
        push!(dtvec, m[:hour])
        dateYY(DateTime(parse.(Int, dtvec)...))
    else
        push!(dtvec, m[:hour2])
        dtld = DateTime(parse.(Int, dtvec)...)
        dateYY(dtld + Hour(parse(Int, m[:step])))
    end
end

function inputs_from_dir(path::String)
    infiles = readdir(path, join = true)
    length(infiles) == 0 && (return AbstractInputFile[])
    _input_from_filename.(readdir(path, join = true))
end

struct Available <: AbstractVector{AbstractInputFile}
    parent::Vector{<:AbstractInputFile}
    path::String
end
# Available(inputs::Vector{AbstractInputFile}, avpath) = Available{Deterministic}(inputs, avpath)
function Available(inpath::String, avpath::String; fromdir = true)
    fromdir ? _available_from_dir(inpath, avpath) : _available_from_file(inpath, avpath)
end
function Available(fpsim::FlexpartSim{T}) where T
    av = Available(fpsim[:input], fpsim[:available]; fromdir = true)
    # input_type(parent(av)) !== T && error("The simulation type $(T) does not correspond to the read inputs.")
    return av
end

Base.parent(av::Available) = av.parent
Base.size(av::Available) = size(parent(av))
Base.similar(av::Available, T::SimType, dims) = Available{T}(av.path, similar(parent(av), T, dims))
Base.similar(av::Available) = similar(parent(av))
Base.getindex(av::Available, i::Int) = getindex(parent(av), i)
Base.setindex!(av::Available, v, i::Int) = setindex!(parent(av), v, i)
Base.filter(f, av::Available) = Available(filter(f, parent(av)), av.path)
_available_from_dir(inpath::String, avpath::String) = Available(inputs_from_dir(inpath), avpath)


function _available_from_file(inpath::String, avpath::String)
    lines = readlines(avpath)
    header, ioc = _header(lines)
    filelines = isnothing(ioc) ? lines : lines[ioc+1:end]
    filelines = filter(x -> x !== "", filelines)
    inputfiles = _input_from_available_line.(filelines, inpath)

    Available(inputfiles, avpath)
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
    strs = [AVAILABLE_HEADER]
    for elem in av
        str = Dates.format(elem.time, "yyyymmdd")*" "*Dates.format(elem.time, "HHMMSS")*"      "*elem.filename*"      "*"ON DISK"
        push!(strs, str)
    end
    strs
end
