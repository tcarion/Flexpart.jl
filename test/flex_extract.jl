using Flexpart.FlexExtract
using Flexpart.FlexExtract: FePathnames
using EcRequests
using Test

DEFAULT_FIRST_KEY = :START_DATE
DEFAULT_FIRST_VALUE = "20180809"

fedir = FlexExtractDir()
fcontrol = FeControl(fedir)
@testset "Create FlexExtractDir's" begin
    fedir = mktempdir() do dir
        FlexExtract.create(dir)
    end
    @test fedir isa FlexExtractDir
end

@testset "Iteration and indexing on FeControl" begin
    pairs = [k => v for (k, v) in fcontrol]
    @test pairs isa AbstractVector
    @test fcontrol[:START_DATE] == DEFAULT_FIRST_VALUE
end

@testset "Push, format, write FeControl" begin
    fcontrol = FeControl(fedir)
    knew, vnew = :REQUEST, 1
    push!(fcontrol, knew => vnew)
    FlexExtract.save(fcontrol)
    @test FlexExtract.format(fcontrol)[end] == "$knew $vnew"
end

@testset "set_area" begin
    set_area(fedir, [50, 0, 40, 10], grid = 0.5)
end

@testset "Submit, create CSV mars requests" begin
    submit(fedir)
    @test isfile(csvpath(fedir))
end

@testset "Convert CSV to EcRequest, handle EcRequest" begin
    requests = FlexExtract.ferequests(csvpath(fedir))
    firstreq = requests[1]
    @test firstreq["stream"] == "OPER"
    firstreq["class"] = "ERA"
    newf = EcRequests.writereq(joinpath(fedir.path, "req.yaml"), firstreq)
    @test isfile(newf)
end

# Only Julia 1.7
# open("test.txt", "w") do file
#     retrieve(req) do io
#         line = readline(io, keep=true)
#         write(file, io)
#     end
# end