"""
    $(TYPEDSIGNATURES)

Calculate Obukhov scale height from surface meteorological data and sensible heat flux.
# Arguments                                           
- ps:      surface pressure [Pa]                  
- ts:      surface temperature [K]                
- td:      surface dew point [K]                  
- t:       temperature first model level [K]
- p :      pressure first model level [Pa]
- u_star: scale velocity [m/s]                   
- q:       surface sensible heat flux [W/m2]      
"""
function obukhov(ps, ts, td, t, p, u_star, q, c_p = 1004.5, R_gas = 287.05, karman = 0.4, g = 9.81)
    e = saturation_pressure(td)
    tv = virtual_temp(ps, t, e)
    rho = p / (R_gas * tv)
    θ = potential_temp(t, p, c_p, R_gas)
    θ_star = friction_temp(q, rho, u_star, c_p)
    u_star^2 * ts / (karman * g * θ_star)
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

"""
    $(TYPEDSIGNATURES)

Calculate the potential temperature.

# Arguments                                           
- t:       temperature [K]                
- p:       pressure [Pa]                
- c_p:     specific heat capacities of dry air [J/kg/K]                
- R_gas:   individual gas constant for dry air [J/kg/K]
"""
potential_temp(t, p, akap) = t * (1e5 / p)^(akap)
potential_temp(t, p, R_gas, c_p) = potential_temp(t, p, R_gas / c_p)


"""
    $(TYPEDSIGNATURES)

Calculate the friction temperature from the surface pressure `p` [Pa], temperature `t` [K], dewpoint temp `td` [K] and stress `stress` [N/m²].

# Arguments                                              
- q:       surface sensible heat flux [W/m²]
- rho:     air density [kg/m³]
- u_star:   scale velocity [m/s]
- c_p:     specific heat capacities of dry air [J/kg/K]
"""
friction_temp(q, rho, u_star, c_p) = - q / (rho * c_p * u_star)

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