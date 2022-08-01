using Flexpart
import Flexpart: ReleasePoint, rfraction!
using Dates
using Test

@testset "Release" begin
    relpoint = ReleasePoint()
    release = relpoint.release
    dt = 3600
    totrel = 0
    for itime in release.start:Second(dt):release.stop
        frac = rfraction!(relpoint, dt, itime)
        totrel += frac
    end
    @test totrel == release.parts
end