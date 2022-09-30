import Flexpart: FP_TESTS_DETER_INPUT, FP_TESTS_ENS_INPUT, default_run, OutputFiles
using Flexpart
using Test
using Dates

@testset "Deterministic run and reading of output" begin
    FlexpartDir() do fpdir
        default_run(fpdir)
        outputs = OutputFiles(fpdir)
        @test outputs[1].type == "ncf"
    end
end