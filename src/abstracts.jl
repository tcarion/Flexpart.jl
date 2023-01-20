abstract type AbstractPathnames end

getpath(pn::AbstractPathnames) = pn.dirpath
Base.getindex(pn::AbstractPathnames, name::Symbol) = joinpath(getpath(pn), getfield(pn, name)) |> Base.abspath
function Base.setindex!(pn::AbstractPathnames, val::String, name::Symbol)
    setfield!(pn, name, val)
end
function Base.iterate(pn::AbstractPathnames, state=1)
    fn = filter(x -> x!==:dirpath, fieldnames(typeof(pn)))
    state > length(fn) ? nothing : ( (fn[state], getfield(pn, fn[state])), state + 1)
end
function Base.show(io::IO, ::MIME"text/plain", pn::AbstractPathnames)
    println(io, "pathnames:")
    for (k, v) in pn
        println(io, "\t", "$k => $v")
    end
end


abstract type AbstractFlexDir end
Base.getindex(flexdir::AbstractFlexDir, name::Symbol) = getindex(getpathnames(flexdir), name)
function Base.setindex!(flexdir::AbstractFlexDir, value::String, name::Symbol)
    getpathnames(flexdir)[name] = value
end