mutable struct Particle
    # Temporal position of the particle
    t::DateTime
    # Spatial position of the particle
    x::Float64
    y::Float64
    z::Float64
    # Mass position of the particle [kg]
    mass::Float64
end

# mutable struct ParticleMut
#     # Temporal position of the particle
#     t::DateTime
#     # Spatial position of the particle
#     x::Float64
#     y::Float64
#     z::Float64
#     mass::Float64
# end

"""
    $(TYPEDSIGNATURES)
Create a particle at the `release` point, by locating it inside the release volume.
Also assign mass by dividing the total mass released by the number of particles.
"""
function Particle(release::Release)
    @unpack start, lon1, lat1, z1, lon2, lat2, z2, mass, parts = release
    londiff = lon2 - lon1
    latdiff = lat2 - lat1
    zdiff = z2 - z1
    # TODO: take into account global fields
    xpos = lon1 + rand() * londiff 
    ypos = lat1 + rand() * latdiff 
    zpos = z1 + rand() * zdiff
    # TODO: take into account the species-average correction (see releaseparticles.f90:164)
    # TODO: other parameters (see releaseparticles.f90:176-187)
    Particle(release.start, xpos, ypos, zpos, mass / parts)
end

function move!(part::Particle; kwargs...)

    # Not the cleanest implementation but the other ones happend to be 10x slower
    part.x = try part.x + kwargs[:x] catch end
    part.y = try part.y + kwargs[:y] catch end
    part.z = try part.z + kwargs[:z] catch end

    # ks = keys(kwargs)
    # newv = getfield.(Ref(part), ks) .+ collect(values(kwargs))
    # setfield!.(Ref(part), ks, newv)

    # part.x = part.x + kwargs[:x]
    # part.y = part.y + kwargs[:y]
    # part.z = part.z + kwargs[:z]

    # for (k,v) in kwargs
    #     prev = getfield(part, k)
    #     setfield!(part, k, prev + v)
    # end
end

# ParticleMut(release::Release) = ParticleMut(getfield.(Ref(Particle(release)), fieldnames(Particle))...)

# function move(part::Particle, dx)
#     Particle(part.t, part.x + dx, part.y, part.z, part.mass)
# end

# move!(part::ParticleMut, dx) = part.x = part.x + dx