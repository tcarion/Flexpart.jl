
Base.@kwdef mutable struct ReleasePoint
    release::Release = Release()
    remaining::Real = 0.
end
"""
    $(TYPEDSIGNATURES)
Calculate the number of particles to be released during the time `itime`. At start and at end of release,
only half the particles are released
"""
function rfraction!(relpoint::ReleasePoint, Δt, itime::DateTime)
    @unpack start, stop, mass, parts = relpoint.release
    start == stop && return parts

    frac = parts * Δt / Second(stop - start).value

    if itime == start || itime == stop
        frac = frac / 2.
    end

    #TODO add time dependant correction (see releaseparticles.f90:96)

    frac = relpoint.remaining + frac
    numrel = round(frac)
    relpoint.remaining = frac - numrel
    Int(numrel)
end