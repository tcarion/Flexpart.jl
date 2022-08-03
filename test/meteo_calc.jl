import Flexpart: saturation_pressure, virtual_temp, friction_velocity
using Test

@testset "fluid properties" begin
    ew = saturation_pressure(273.15 + 50.) * 1e-3
    @test ew ≈ 12.3440 atol = 1e-1

    ps = 99922.5703
    t2 = 290.316681
    td2 = 285.705688
    stress = 0.0230113287

    e = saturation_pressure(t2)
    tv = virtual_temp(ps, t2, e)
    u_start = friction_velocity(ps, t2, td2, stress, 287.05)
    @test u_start ≈ 0.138913378 atol = 1e-5
end