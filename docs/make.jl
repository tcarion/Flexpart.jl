using Flexpart
using Documenter

DocMeta.setdocmeta!(Flexpart, :DocTestSetup, :(using Flexpart); recursive=true)

makedocs(;
    modules=[Flexpart],
    authors="tcarion <tristancarion@gmail.com> and contributors",
    repo="https://github.com/tcarion/Flexpart.jl/blob/{commit}{path}#{line}",
    sitename="Flexpart.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://tcarion.github.io/Flexpart.jl",
        edit_link="main",
        assets=String[],
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => "man/guide.md",
        "Library" => [
            "Internals" => "lib/internals/flexpart.md"
        ],
    ],
)

deploydocs(;
    repo="github.com/tcarion/Flexpart.jl",
    devbranch="main",
)
