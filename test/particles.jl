using Flexpart
import Flexpart: Particle, Release, move!
using Dates
using Test

# @testset "Particles" begin
    release = Release()
    # n = 10000
    # parts = [Particle(release) for _ in 1:n]
    part = Particle(release)
    prevx = part.x
    Flexpart.move!(part, x = 1., y = 2., z = 3.)
    # @benchmark Flexpart.move!(part, x = 1., y = 2., z = 3.)
    @test part.x == prevx + 1.
    # partmuts = [ParticleMut(release) for _ in 1:n]

    # @benchmark move.(parts, 1.)
    # @benchmark move!.(partmuts, 1.)
# end