using Flexpart
using Test

@testset "input" begin include("input.jl") end
@testset "options" begin include("options.jl") end
@testset "flexpartsim" begin include("flexpartsim.jl") end
@testset "run and output" begin include("outputs.jl") end
@testset "miscellaneous" begin include("miscellaneous.jl") end