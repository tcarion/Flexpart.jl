using Flexpart
using Flexpart: FpPathnames, DEFAULT_PATHNAMES, DEFAULT_PATH_PATHNAMES, DEFAULT_FP_DIR
using Test

@testset "FpPathnames" begin
    defpathnames = FpPathnames()
    @test defpathnames.input == FpPathnames(DEFAULT_PATH_PATHNAMES).input
    @test defpathnames[:input] == joinpath(DEFAULT_FP_DIR, "input/")
    mktempdir() do dir
        wrong_fn = joinpath(dir, "wrong")
        open(wrong_fn, "w") do f end
        @test_throws ErrorException FpPathnames(wrong_fn)
    end
end

@testset "FlexpartSim" begin
    fpsim = FlexpartSim(DEFAULT_PATH_PATHNAMES)
    mktempdir() do dir
        created = Flexpart.create(dir)
        @test created[:options] == joinpath(dir, "options/")
        @test Flexpart.getpath(created) == dir

        created[:input] = "./another"

        Flexpart.save(created)
        readpn = Flexpart.read_pathnames(created)
        @test readpn[3] == "./another"
    end

    FlexpartSim() do fpsim
        @test isempty(readdir(fpsim[:output]))
        @test fpsim isa FlexpartSim{Deterministic}
    end

    FlexpartSim{Ensemble}() do fpsim
        @test fpsim isa FlexpartSim{Ensemble}
    end
end