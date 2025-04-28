abstract type AbstractOutputFile{SimType} end
getpath(output::AbstractOutputFile) = output.path
Base.convert(::Type{<:AbstractString}, output::AbstractOutputFile) = output.path
Base.string(out::AbstractOutputFile) = convert(String, out)

"""
    DeterministicOutput

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
    EnsembleOutput

Object that represents an ensemble output file.

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

OutputFiles(fpsim::FlexpartSim{T}) where T = OutputFiles{T}(fpsim[:output])

_gettype(path::String) = occursin(".nc", basename(path)) ? "ncf" : "binary"
_filter(files) = filter(x -> occursin("grid_", x), files)

function OutputFiles{Deterministic}(path::String)
    files = readdir(path, join = true)
    ffiles = _filter(files)
    map(ffiles) do file
        DeterministicOutput(file, _gettype(file))
    end
end

function OutputFiles{Ensemble}(path::String)
    files = readdir(path, join = true)
    outfiles = EnsembleOutput[]
    for file in files
        m = match(r"member(\d*)", file)
        if isnothing(m)
            push!(outfiles, EnsembleOutput(file, _gettype(file), 0))
        else
            number = parse(Int, m.captures[1])
            memdirfiles = readdir(joinpath(path, file), join=true)
            ffiles = _filter(memdirfiles)
            for memfile in ffiles
                push!(outfiles, EnsembleOutput(memfile, _gettype(memfile), number))
            end
        end
    end
    outfiles
end