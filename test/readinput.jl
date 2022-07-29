using Flexpart
using Flexpart.FlexpartInputs
inpath = "test/fp_dir_test/input/EH20010100"

input = DeterministicInput(inpath)
rasters = Flexpart.read_input(input) 
@testset "Read input" begin
    FlexpartDir() do fpdir
        default_run(fpdir)
        outputs = OutputFiles(fpdir)
        @test outputs[1].type == "binary"
    end
end