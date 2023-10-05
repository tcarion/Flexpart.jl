import Flexpart: FP_TESTS_DETER_INPUT, FP_TESTS_ENS_INPUT, DEFAULT_FP_DIR, SimType, Deterministic, Ensemble
import Flexpart: DeterministicInput, EnsembleInput, AbstractInputFile, format, input_type
using Test, Dates
using Flexpart

# For debugging
import Flexpart: _header, _input_from_available_line, _input_from_filename,_available_from_dir, _available_from_file

infiles_path = readdir(FP_TESTS_DETER_INPUT, join = true)
infilesdet = inputs_from_dir(FP_TESTS_DETER_INPUT)
infilesens = inputs_from_dir(FP_TESTS_ENS_INPUT)

@testset "DeterministicInput and EnsembleInput" begin
    detin = DeterministicInput(infiles_path[1])
    @test detin.filename == "ENH21090500"
    input_type(detin) == Deterministic
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
av_from_file = Available(FP_TESTS_DETER_INPUT, av_default_path; fromdir = false)
av_from_dir = Available(FP_TESTS_DETER_INPUT, av_default_path; fromdir = true)

@testset "Available length and filter" begin
    @test length(av_from_file) == 24
    @test filter(x -> Dates.Hour(x.time) == Dates.Hour(0), av_from_file)[1].time == DateTime(2012,1,1,0,0,0)
    @test filter(x -> Dates.Hour(x.time) == Dates.Hour(0), av_from_file) isa Available
end

# TODO improve this test
@testset "Format and save Available" begin
    formated = format(av_from_dir)
    FlexpartSim() do fpsim
        av = Available(fpsim)
        Flexpart.save(av)
    end
end