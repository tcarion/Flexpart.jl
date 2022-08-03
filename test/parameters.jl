using Flexpart
import Flexpart: Parameters, Constants
using Test

@testset "Parameters" begin
    p = Parameters()
    c = Constants(p)
end