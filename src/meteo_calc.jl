
"""
    $(TYPEDSIGNATURES)

Calculate the friction velocity from the surface pressure `p` [Pa], temperature `t` [K], dewpoint temp `td` [K] and stress `stress` [N/m²].
"""
function friction_velocity(p, t, td, stress, R_gas)
    # vapor pressure
    e = saturation_pressure(td)
    tv = virtual_temp(p, t, e)
    rho_moist = p / (R_gas * tv)
    sqrt(abs(stress) / rho_moist)
end

"""
    $(TYPEDSIGNATURES)

Calculate the saturation vapor pressure from Arden Buck equations (Buck, 1996). `t` is in K, result in Pa.
"""
function saturation_pressure(t)
    t = t - 273.15
    if t >= 0.
        r = 6.1121 * exp( (18.678 - t / 234.5) * t / (257.14 + t) )
    else
        r = 6.1115 * exp( (23.036 - t / 333.7) * t / (279.82 + t) ) 
    end
    r * 100.
end

"""
    $(TYPEDSIGNATURES)

Calculate the virtual temperature from the surface pressure `ps` [Pa], the temperature `t` [K], and the vapor pressure `e` [Pa].
"""
virtual_temp(ps, t, e) = t / (1 - 0.378 * e / ps )