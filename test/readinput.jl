using Flexpart
using Flexpart.FlexpartInputs
import Flexpart: EcInputMeta, EcInput, InputGeometry, Input, Inputs, InputVariables, ProcessedVariables
import Flexpart: vertical_profiles, get_ustar, get_stress, load_layer, pressure_levels, horizontal_height, conversion_factor, _init_var_lev
import Flexpart: calc_Δz
import Flexpart: Parameters, Constants, @unpack
using Test
inpath = "/home/tcarion/Documents/Flexpart/dev/flexpart_src/src/fpdir/input/ENH21090500"
inpath2 = "/home/tcarion/rocourt/EH20010100"
inspath = "/home/tcarion/Documents/Flexpart/dev/flexpart_src/src/fpdir/input/"

inputs_path = filter(isfile, readdir(inspath, join = true))
P = Parameters(inputs = inputs_path)
C = Constants(P)

finputs = DeterministicInput.(filter(isfile, inputs_path))
finput = finputs[1]
# finput = DeterministicInput(inpath2)
# layers = Flexpart.read_input(finput)
ec_input = EcInput(finput)

vertical = EcInputMeta(finput)
@test vertical.(1, 101325., border = true) == 101325.
@test vertical.(2, 101325.) ≈ 101204.94 atol = 1e-2

invars = InputVariables(ec_input);

heights = vertical_profiles(invars, vertical, C)

plevs = pressure_levels(ec_input, invars[:sp])

geom = InputGeometry(ec_input, invars, C)

input = Input(finput, C)

procvars = ProcessedVariables(ec_input, invars, geom, C)
procvars = input.procvars
@unpack h_levs, h_w = procvars


# e = saturation_pressure.(variables.d2m[:,:,1])
# tv1 = virtual_temp.(variables.sp, variables.t2m, e)
# tv2 = virtual_temp.(variables.t[:,:,5], variables.w[:,:,5])
# contourf(geom.lond, geom.latd, permutedims(tv1 - tv2))

# plotvar!(v, kws...) = plot!(v / sum(v) * length(v), heights, marker = :dot, ylim = [0, 13e3], kws...)
# plot()
# plotvar!(variables.w[1,1,:])
# plotvar!(variables.t[1,1,:])
# plotvar!(variables.u[1,1,:])
# plotvar!(variables.v[1,1,:])
# @benchmark EcInput(input)


# scatter(fill(1, 138), ecmeta.(1:138, 101325), marker=:dot, markersize=1)
# scatter!(fill(1, 138), ecmeta.(1:138, 101325, border=true), marker=:dot, markersize=1)

# stress = get_stress(layers)
# ustar = get_ustar(layers, stress)

# ustar[:,:,1]

# t = ec_input[:t]
# t2 = ec_input[:t2m]

# tcat = cat(t, t2, dims = Z)

# newz = Z(DD.Sampled(collect(1:138), DD.ReverseOrdered(), DD.Regular(-1), DD.Points(), DD.NoMetadata()))

# tcatz = set(tcat, Z => newz)
# tperm = permutedims(t, (X,Y,Ti,Z))
# ec_input.layers[:t] = tperm

# rt2 = reshape(t2, (axes(t2)..., 1))
# set(rt2, )
# dat2 = DD.DimArray(reshape(t2, (axes(t2)..., 1)), (dims(t2)..., newz))

# t2arr = Array(t2[X(:), Y(:), Ti(:)])
# rt2arr = reshape(t2arr, (axes(t2)..., 1))

# tarr = Array(t[X(:), Y(:), Ti(:), Z(:)])

# cated = cat(tarr, t2arr, dims = 3)
# cat(t, copy(t2arr), dims = 3)
# ec_input[:t] = cated

# DD.rebuild_from_arrays(cated, dims = DD.combinedims(dims(t2), newz))

# rt2 = reshape(t2, (axes(t2)..., 1))

# cat(ec_input.layers, keys = (:t, :t2m), dims = Z)

# cat(rt2, t, dims = Z)
# cat(dat2, t, dims = Z)
# zdim = dims(t, Z)
# pushfirst!(zdim.val.data, 138)
# push!(zdim, 138)

# t2 = DimArray(t2)
# newdims = DD.combinedims(dims(t), newz)
# newz = Z(DD.Sampled(collect(1:138), DD.ReverseOrdered(), DD.Regular(-1), DD.Points(), DD.NoMetadata()))

# newZ = Z([138, collect(dims(t, Z))...])
# Rasters.setdims(t, newZ)


# r1 = DimArray(rand(2, 2, 1), X(1:2), Y(1:2), Ti(1))

# 24-element Vector{Pair{Symbol, String}}:
#    :sp => "Surface pressure"
#    :sd => "Snow depth"
#   :msl => "Mean sea level pressure"
#   :tcc => "Total cloud cover"
#   :u10 => "10 metre U wind component"
#   :v10 => "10 metre V wind component"
#   :t2m => "2 metre temperature"
#   :d2m => "2 metre dewpoint temperature"
#   :lsp => "Large-scale precipitation"
#    :cp => "Convective precipitation"
#  :sshf => "Surface sensible heat flux"
#  :ewss => "Eastward turbulent surface stress"
#  :nsss => "Northward turbulent surface stress"
#   :ssr => "Surface net solar radiation"
#  :sdor => "Standard deviation of orography"
#   :cvl => "Low vegetation cover"
#   :cvh => "High vegetation cover"
#    :sr => "Surface roughness"
#     :z => "Geopotential"
#   :lsm => "Land-sea mask"
#   :lcc => "Low cloud cover"
#   :mcc => "Medium cloud cover"
#   :hcc => "High cloud cover"
#   :skt => "Skin temperature"

