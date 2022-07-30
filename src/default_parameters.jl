@with_kw struct Release
    # Species numbers in directory SPECIES
    specnum_rel::Int = 21
    # Release start datetime
    start::DateTime = DateTime(2018,9,5, 0)
    # Release end datetime
    stop::DateTime = DateTime(2018,9,5, 3)
    # Left longitude of release box -180 < LON1 <180
    lon1::Real = 16.1469
    # Right longitude of release box, same as lon1
    lon2::Real = 16.1469
    # Lower latitude of release box, -90 < LAT1 < 90
    lat1::Real = 49.0845
    # Upper latitude of release box same format as lat1
    lat2::Real = 49.0845
    # Lower height of release box meters/hPa above reference level
    z1::Real = 0.0
    # Upper height of release box meters/hPa above reference level
    z2::Real = 50.0
    # Reference level 1=above ground, 2=above sea level, 3 for pressure in hPa
    zkind::Int = 1
    # Total mass emitted, only relevant for fwd simulations
    mass::Real = 9.99999984e16
    # Total number of particles to be released
    parts::Int = 1000
    # Comment, written in the outputfile
    comment::String = "RELEASE 1"
end

"""
    P = Parameters(kwargs...)

A struct to hold all model parameters that may be changed by the user.
The struct uses keywords such that default values can be changed at creation.
The default values of the keywords define the default model setup.
"""
@with_kw struct Parameters
    sim_type::SimType=Deterministic
    # PHYSICAL CONSTANTS
    radius_earth::Real=6.371e6          # radius of Earth [m]
    rotation_earth::Real=7.29e-5        # angular frequency of Earth's rotation [rad/s]
    gravity::Real=9.81          # gravitational acceleration [m/s^2]
    akap::Real=2/7              # ratio of gas constant to specific heat of dry air
                                # at constant pressure = 1 - 1/γ where γ is the
                                # heat capacity ratio of a perfect diatomic gas (7/5)
    cp::Real=1004               # specific heat at constant pressure [J/K/kg]
    R_gas::Real=akap*cp         # specific gas constant for dry air [J/kg/K]
    alhc::Real=2501             # latent heat of condensation [J/g] for consistency with
                                # specific humidity [g/Kg]
    alhs::Real=2801             # latent heat of sublimation [?]
    sbc::Real=5.67e-8           # stefan-Boltzmann constant [W/m^2/K^4]

    # STANDARD ATMOSPHERE
    lapse_rate::Real=6          # reference temperature lapse rate -dT/dz [K/km]
    temp_ref::Real=288          # reference absolute temperature at surface z=0 [K]
    temp_top::Real=216          # reference absolute temperature in stratosphere [K]
    scale_height::Real=7.5      # reference scale height for pressure [km]
    pres_ref::Real=1013         # reference surface pressure [hPa]
    scale_height_humid::Real=2.5# reference scale height for specific humidity [km]
    relhumid_ref::Real=0.7      # reference relative humidity of near-surface air [1]
    water_pres_ref::Real=17     # reference saturation water vapour pressure [Pa]
    layer_thickness::Real=10    # layer thickness for the shallow water model [km]

    # INPUT FILES
    inputs::Vector{String}=readdir(FP_TESTS_DETER_INPUT, join=true)    # package location is default
    # orography_path::String=boundary_path
    # orography_file::String="orography_F512.nc"

    # OUTPUT
    verbose::Bool=true              # print dialog for feedback
    output::Bool=false              # Store data in netCDF?
    output_dt::Real=6               # output time step [hours]
    output_startdate::DateTime=DateTime(2000,1,1)
    out_path::String=pwd()          # path to output folder
    output_vars::Vector{String}=["u","v","temp","humid","pres"]
    compression_level::Int=3        # 1=low but fast, 9=high but slow
    keepbits::Int=7                 # mantissa bits to keep for every variable

    # OPTIONS
    releases::Vector{Release} = [Release()]

    # RESTART
    write_restart::Bool=true        # also write restart file if output==true?
    restart_path::String=out_path   # path for restart file
    restart_id::Integer=1           # run_id of restart file in run????/restart.jld2
end