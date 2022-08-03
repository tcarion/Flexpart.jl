using Flexpart
using Flexpart.FlexpartInputs
import Flexpart: EcInputMeta, EcInput, InputGeometry, Inputs, get_ustar, get_stress
import Flexpart: Parameters
inpath = "/home/tcarion/Documents/Flexpart/dev/flexpart_src/src/fpdir/input/ENH21090500"

inputs_path = filter(isfile, readdir("/home/tcarion/Documents/Flexpart/dev/flexpart_src/src/fpdir/input", join = true))
P = Parameters(inputs = inputs_path)

inputs = DeterministicInput.(filter(isfile, inputs_path))

input = inputs[1]
ec_input = EcInput(input)
# @benchmark EcInput(input)
ec_input[:u]
hybrid = ec_input.layers[:hybrid]
surface = ec_input.layers[:surface]
allrast = merge(surface, hybrid)

ecmeta = EcInputMeta(input)

geom = InputGeometry(ec_input)

# stress = get_stress(layers)
# ustar = get_ustar(layers, stress)

# ustar[:,:,1]

I = Inputs(P)
I.current.left = EcInput(inputs[3]);

@testset "Read input" begin
    FlexpartDir() do fpdir
        default_run(fpdir)
        outputs = OutputFiles(fpdir)
        @test outputs[1].type == "binary"
    end
end

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

