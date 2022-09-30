abstract type AbstractOutputFile{SimType} end
Base.convert(::Type{<:AbstractString}, output::AbstractOutputFile) = output.path
Base.string(out::AbstractOutputFile) = convert(String, out)

"""
    DeterministicInput

Object that represents a deterministic output file.

$(TYPEDFIELDS)
"""
struct DeterministicOutput <: AbstractOutputFile{Deterministic}
    "Path to the output file"
    path::String
    "Type of the output file (ncf, binary)"
    type::String
end

"""
    EnsembleInput

Object that represents a ensemble output file.

$(TYPEDFIELDS)
"""
struct EnsembleOutput <: AbstractOutputFile{Ensemble}
    "Path to the output file"
    path::String
    "Type of the output file (ncf, binary)"
    type::String
    "Ensemble member number"
    member::Int
end
isncf(output::AbstractOutputFile) = output.type == "ncf"

const OutputFiles{T} = Vector{<:AbstractOutputFile{T}}

OutputFiles(fpdir::FlexpartDir{T}) where T = OutputFiles{T}(fpdir[:output])

_gettype(path::String) = occursin(".nc", basename(path)) ? "ncf" : "binary"
_filter(files) = filter(x -> occursin("grid_", x), files)
function OutputFiles{Deterministic}(path::String)
    files = readdir(path, join = true)
    ffiles = _filter(files)
    map(ffiles) do file
        DeterministicOutput(file, _gettype(file))
    end
end

# TO BE TESTED
function OutputFiles{Ensemble}(path::String)
    files = readdir(path, join = true)
    outfiles = EnsembleOutput[]
    for file in files
        m = match(r"member(\d*)", file)
        number = parse(Int, m.captures[1])
        memdirfiles = joinpath(path, file) |> readdir
        ffiles = _filter(memdirfiles)
        for memfile in ffiles
            path = joinpath(memfile, ncfile)
            push!(outfiles, EnsembleOutput(path, _gettype(path), number))
        end
    end
    outfiles
end