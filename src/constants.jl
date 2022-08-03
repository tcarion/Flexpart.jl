"""
Struct holding the parameters needed at runtime in number format NF.
"""
struct Constants

    # PHYSICAL CONSTANTS
    radius_earth::Float64        # Radius of Earth
    rotation_earth::Float64      # Angular frequency of Earth's rotation
    gravity::Float64             # Gravitational acceleration
    akap::Float64                # Ratio of gas constant to specific heat of dry air at constant pressure
    R_gas::Float64               # Universal gas constant
    karman::Real                 # Von Karman constant

    # TIME STEPPING
    Δt::Float64                  # time step [s/m], use 2Δt for leapfrog, scaled by Earth's radius
    # Δt_unscaled::Float64         # time step [s], as Δt but not scaled with Earth's radius
    # Δt_sec::Int             # time step [s] but encoded as 64-bit integer for rounding error-free accumulation
    # Δt_hrs::Float64         # time step [hrs]
    n_output_steps::Int        # number of time steps to integrate for

    # OUTPUT TIME STEPPING
    # output_dt::Int   # output every n time steps

    releases::Vector{Release}
    command::Command
    # PARAMETRIZATIONS
    # # Large-scale condensation (occurs when relative humidity exceeds a given threshold)
    # RH_thresh_boundary::NF  # Relative humidity threshold for boundary layer
    # RH_thresh_range::NF     # Vertical range of relative humidity threshold
    # RH_thresh_max ::NF      # Maximum relative humidity threshold
    # humid_relax_time::NF    # Relaxation time for humidity (hours)
end

"""
Generator function for a Constants struct.
"""
function Constants(P::Parameters)

    # PHYSICAL CONSTANTS
    @unpack radius_earth, rotation_earth, gravity, akap, R_gas, karman = P

    # ORIGINAL FLEXPART OPTIONS
    @unpack releases, command = P

    @unpack sim_start, sim_stop = command

    Δt      = command.loutstep
    n_output_steps = ceil(Int, Second(sim_stop - sim_start).value / Δt)    # number of time steps to integrate for

    # This implies conversion to NF
    return Constants( radius_earth,rotation_earth,gravity,akap,R_gas,karman,
                            Δt,n_output_steps,
                            releases, command
                            )
end
