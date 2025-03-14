
const DEFAULT_OPTIONS_PATH = joinpath(Flexpart.DEFAULT_FP_DIR, "options")
struct NotNamelistError <: Exception
    filename::String
end
Base.showerror(io::IO, e::NotNamelistError) = print(io, "Namelist format not valid : ", e.filename)

struct MultipleSubOptionError <: Exception
end
Base.showerror(io::IO, e::MultipleSubOptionError) = print(io, "Multiple sub options exist for this key.")
mutable struct OptionEntry
    name::Symbol
    value::Any
    doc::String
end
function OptionEntry(line::String)
    # Separate the name, value and comment.
    reg = r"(.*?)=(.*?),(\s*!(.*))?"
    m = match(reg, line)
    if isnothing(m)
        error("Option entry could not be parsed: $line")
    end
    na, val, _, doc = m.captures
    name = Symbol(strip(na))
    value = string(strip(val))
    doc = isnothing(doc) ? "" : string(lstrip(doc))
    name => OptionEntry(name, value, doc)
end
Base.copy(entry::OptionEntry) = OptionEntry([getfield(entry, n) for n in fieldnames(typeof(entry))]...)
function Base.show(io::IO, ::MIME"text/plain", entry::OptionEntry)
    print(io, "$(entry.name) = $(entry.value)")
    !isempty(entry.doc) && printstyled(io, "\t! " * entry.doc * ".", color = :cyan)
    print(io, "\n")
end

const OptionEntriesType = OrderedDict{Symbol, OptionEntry}
const OptionGroupType = DefaultOrderedDict{Symbol, Vector{<:OptionEntriesType}}
const OptionType = OrderedDict{String, OptionGroupType}


function OptionEntries(lines::Vector{<:String})
    OptionEntriesType(
        OptionEntry(line) for line in lines
    )
end
function Base.setindex!(entries::OptionEntriesType, v::Union{Real, AbstractString}, k)
    # if haskey(entries, k)
    entry = getindex(entries, k)
    entry.value = v
    # end
end


function parse_namelist(filepath)
    lines = readlines(filepath)
    reg_header = r"^\&(\w*)"
    iheader = findall(line -> !isnothing(match(reg_header, strip(line))), lines) # find headers
    iend = findall(line -> strip(line) == "/", lines) # find end of body

    (length(iheader) == 0 || (length(iheader) !== length(iend))) && throw(NotNamelistError(filepath))
    bodys = [lines[i+1:j-1] for (i, j) in zip(iheader, iend)]
    headers = lines[iheader]
    headers = [match(reg_header, line).captures[1] |> uppercase |> Symbol for line in headers]

    suboptions = [header => OptionEntries(body) for (header, body) in zip(headers, bodys)]
    optiongroup = OptionGroupType(Vector{OptionEntriesType})
    for pairs in suboptions
        push!(optiongroup[pairs[1]], pairs[2])
    end
    optiongroup
end

# Don't error if only one suboption for the current key (could be done with a macro)
function Base.getindex(group::Vector{<:OptionEntriesType}, k::Symbol)
    # try
    #     group[1][k]
    # catch e
    #     if length(group) == 1
    #         group[1][k]
    #     elseif length(group) > 1
    #         throw(MultipleSubOptionError())
    #     else
    #         rethrow()
    #     end
    # end

    if length(group) == 1
        group[1][k]
    else
        throw(MultipleSubOptionError())
    end
end
function Base.setindex!(group::Vector{<:OptionEntriesType}, v, k::Symbol)
    # try
    #     setindex!(group[1], v, k)
    # catch e
    #     if length(group) == 1
    #         setindex!(group[1], v, k)
    #     elseif length(group) > 1
    #         throw(MultipleSubOptionError())
    #     else
    #         rethrow()
    #     end
    # end

    if length(group) == 1
        setindex!(group[1], v, k)
    else
        throw(MultipleSubOptionError())
    end
end
function Base.merge!(group::Vector{<:OptionEntriesType}, dict::AbstractDict)
    if length(group) == 1
        merge!(group[1], dict)
    else
        throw(MultipleSubOptionError())
    end
end
mutable struct FlexpartOption
    dirpath::String
    options::OptionType
end
function Base.show(io::IO, ::MIME"text/plain", fpopt::FlexpartOption)
    println(io, "FlexpartOption @ $(fpopt.dirpath) with options:")
    for (k,_) in fpopt.options
        println(io, k)
    end
end

FlexpartOption(path::String) = FlexpartOption(path, walkoptions(path))

FlexpartOption(fpsim::FlexpartSim) = FlexpartOption(fpsim[:options])

FlexpartOption() = FlexpartOption("", walkoptions(DEFAULT_OPTIONS_PATH))

Base.parent(fpopt::FlexpartOption) = fpopt.options
Base.getindex(fpopt::FlexpartOption, name) = getindex(parent(fpopt), name)
Base.size(fpopt::FlexpartOption) = size(parent(fpopt))
Base.length(fpopt::FlexpartOption) = length(parent(fpopt))
Base.iterate(fpopt::FlexpartOption, args...) = iterate(parent(fpopt), args...)
Base.filter(f::Any, fpopt::FlexpartOption, args...) = filter(f, parent(fpopt), args...)

"""
    $(TYPEDSIGNATURES)

Return the names of the species that are available by default with Flexpart
"""
function species_name()
    FlexpartSim() do fpsim
        [v[:SPECIES_PARAMS][:PSPECIES].value for (k, v) in FlexpartOption(fpsim) if occursin("SPECIES", k)]
    end
end

"""
    $(TYPEDSIGNATURES)

Return specie number needed for the RELEASES options from the name `specie`.

# Examples
```julia-repl
julia> Flexpart.specie_number("CH4")
26
```
"""
function specie_number(specie::AbstractString)
    println("REVISED ?????")
    fp_species = Flexpart.species_name()
    if !(specie in replace.(fp_species, "\"" => ""))
        error("the specie name $specie has not been found in Flexpart default species")
    end
    FlexpartSim() do fpsim
        allspecies = filter(p -> occursin("SPECIES", first(p)), FlexpartOption(fpsim))
        specie_opt = filter(p -> occursin(specie, p[2][:SPECIES_PARAMS][:PSPECIES].value), allspecies)
        try
            parse(Int, first(first(specie_opt))[end-2:end])
        catch
            error("The specie file seems not to have a proper name format. It must be SPECIES_XXX with XXX being a digit.")
        end
    end
end

function walkoptions(path::String)
    dict = OptionType()
    for (root, _, files) in walkdir(path)
        for file in files
            name = root == path ? file : joinpath(relpath(root, path), file)
            absfile = joinpath(root, file)
            try
                dict[name] = parse_namelist(absfile)
            catch e
                if e isa NotNamelistError
                    nothing
                else
                    rethrow()
                end
            end
        end
    end
    dict
end

function format(entry::OptionEntry)
    str = " $(entry.name) = $(entry.value),"
    if !isempty(entry.doc)
        str *= " ! $(entry.doc)"
    end
    str
end

function format(entries::OptionEntriesType)
    lines = String[]
    for (k, v) in entries
        push!(lines, format(v))
    end
    lines
end

function format(entriesvec::Vector{<:OptionEntriesType}, header)
    lines = String[]
    for entries in entriesvec
        push!(lines, header)
        push!(lines, format(entries)...)
        push!(lines, " /")
    end
    lines
end

function format(group::OptionGroupType)
    lines = String[]
    for (k, v) in group
        head = k |> string |> uppercase
        push!(lines, format(v, "&$(head)")...)
    end
    lines
end

function format(opt::OptionType)
    lines = String[]
    for (k, v) in opt
        push!(lines, format(v)...)
    end
    lines
end

function Flexpart.save(flexpartoption::FlexpartOption, newpath::String = "")
    flexpartoption.dirpath == "" && error("Path to option directory is empty")
    options_dir = newpath == "" ? flexpartoption.dirpath : newpath
    try
        mkdir(options_dir)
    catch
    end

    for (k, v) in flexpartoption.options
        filepath = joinpath(options_dir, k)
        writelines(filepath, format(v))
    end
end
# diffkeys(dict1, dict2) = [k for k in keys(dict1) if dict1[k] != get(dict2, k, nothing)]


# function compare(file1::String, file2::String)
#     opt1 = namelist2dict(file1)
#     opt2 = namelist2dict(file2)
#     compare(opt1, opt2)
#     # diffs
# end

# function compare(fpdir1::FlexpartSim, fpdir2::FlexpartSim, filename1::String; filename2::String = "", which = :output)
#     filename2 = filename2 |> isempty ? filename1 : filename2
#     file1 = joinpath(Flexpart.abspath(fpdir1, which), filename1)
#     file2 = joinpath(Flexpart.abspath(fpdir2, which), filename2)
#     compare(file1, file2)
# end
