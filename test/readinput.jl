using Flexpart
using Flexpart.FlexpartInputs
inpath = "test/fp_dir_test/input/EH20010100"

input = DeterministicInput(inpath)
rasters = Flexpart.read_input(input) 
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

