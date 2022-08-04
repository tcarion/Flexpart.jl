using Flexpart
import Flexpart: Parameters, Constants
using Test

@testset "Parameters" begin
    P = Parameters()
    C = Constants(P)
end