
function get_ustar(layers::InputStack, stress, params = Parameters())
    friction_velocity.(layers[:sp], layers[:t2m], layers[:d2m], stress, params.R_gas)
end

get_stress(layers::InputStack) = sqrt.(layers[:ewss].^2 .+ layers[:nsss].^2)