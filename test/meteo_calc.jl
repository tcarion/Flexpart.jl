import Flexpart: saturation_pressure, virtual_temp, friction_velocity, potential_temp, friction_temp, obukhov
import Flexpart: Parameters
using Test

@testset "fluid properties" begin
    cp = 1004.5
    R_gas = 287.05
    ew = saturation_pressure(273.15 + 50.) * 1e-3
    @test ew ≈ 12.3440 atol = 1e-1

    ps = 99922.5703
    t2 = 290.316681
    td2 = 285.705688
    stress = 0.0230113287

    e = saturation_pressure(t2)
    tv = virtual_temp(ps, t2, e)
    u_star = friction_velocity(ps, t2, td2, stress, 287.05)
    @test u_star ≈ 0.138913378 atol = 1e-5
    
    p1 = 99804.1719
    t1 = 291.607758
    θ = potential_temp(291.607758, p1, R_gas, cp)
    @test θ ≈ 291.77113 atol = 1e-4

    q = 6.3768158
    rho = ps / (R_gas * tv)
    θ_star = friction_temp(q, rho, u_star, cp)
    @test θ_star ≈ -0.0383189023 atol = 1e-4

    L = obukhov(ps, t2, td2, t1, p1, u_star, q)
    @test L ≈ -37 atol = 1
end