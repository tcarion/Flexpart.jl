import Flexpart: FP_TESTS_DETER_INPUT, FP_TESTS_ENS_INPUT, DEFAULT_FP_DIR, SimType, Deterministic, Ensemble
import Flexpart.FlexpartInputs: InputFiles, DeterministicInput, EnsembleInput, AbstractInputFile, format
using Test, Dates
using Flexpart

infiles_path = readdir(FP_TESTS_DETER_INPUT, join = true)
infilesdet = InputFiles(Deterministic, FP_TESTS_DETER_INPUT)
infilesens = InputFiles(Ensemble, FP_TESTS_ENS_INPUT)

@testset "DeterministicInput and EnsembleInput" begin
    detin = DeterministicInput(infiles_path[1])
    @test detin.filename == "ENH21090500"
end

@testset "InputFiles length and filter" begin
    @test infilesdet[1] isa DeterministicInput
    @test eltype(infilesens) <: AbstractInputFile
    @test length(infilesdet) == 3
    @test length(infilesens) == 4
    @test filter(x -> Dates.Hour(x.time) >= Dates.Hour(1), infilesdet)[1] == infilesdet[2]
    @test filter(x -> x.member == 1, infilesens)[1] == infilesens[2]
end

av_default_path = joinpath(DEFAULT_FP_DIR, "AVAILABLE")
av_from_file = Available{Deterministic}(av_default_path, FP_TESTS_DETER_INPUT, fromdir = false)
av_from_dir = Available{Deterministic}(av_default_path, FP_TESTS_DETER_INPUT, fromdir = true)

@testset "Available length and filter" begin
    @test length(av_from_file) == 24
    @test filter(x -> Dates.Hour(x.time) == Dates.Hour(0), av_from_file)[1].time == DateTime(2012,1,1,0,0,0)
end

# TODO improve this test
@testset "Format and save Available" begin
    formated = format(av_from_dir)
    FlexpartDir() do fpdir
        av = Available(fpdir)
        Flexpart.save(av)
    end
end