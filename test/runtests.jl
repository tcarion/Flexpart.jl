using Flexpart
using Test
using Dates

@testset "input" begin include("input.jl") end
@testset "options" begin include("options.jl") end
@testset "run and output" begin include("outputs.jl") end
@testset "miscellaneous" begin include("miscellaneous.jl") end
@testset "flex_extract" begin include("flex_extract.jl") end

@testset "release" begin include("release.jl") end
@testset "release" begin include("particles.jl") end