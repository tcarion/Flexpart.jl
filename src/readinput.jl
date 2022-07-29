using Flexpart.FlexpartInputs
import Flexpart.FlexpartInputs: getpath
using Rasters

function read_input(input::AbstractInputFile)
    inpath = getpath(input)
    ncf_dir = mkpath(inpath*"_ncf")
    gribs = copy_grib(inpath, ncf_dir)
    ncfs = to_netcdf(gribs, ncf_dir)
    rm.(gribs)
    fnames = getindex.(splitext.(ncfs), 1) .|> basename
    layer_names = getindex.(split.(fnames, input.filename), 2)
    Dict(Symbol(layer) => RasterStack(ncf) for (layer, ncf) in zip(layer_names, ncfs))
end

function Rasters.RasterSeries(input::AbstractInputFile)
    inpath = getpath(input)
    ncf_dir = mkpath(inpath*"_ncf")
    gribs = copy_grib(inpath, ncf_dir)
    ncfs = to_netcdf(gribs, ncf_dir)
    rm.(gribs)
    fnames = getindex.(splitext.(ncfs), 1) .|> basename
    layer_types = getindex.(split.(fnames, input.filename), 2)
    layer_dims = [Dim{Symbol(layer)}() for layer in layer_types]
    Rasters.RasterSeries(ncfs, layer_dims)
end


function copy_grib(fpath, dest)
    fname = splitext(fpath)[1] |> basename
    fdest = joinpath(dest, fname)
    fdest *= "[typeOfLevel].grb"
    Base.run(`grib_copy $fpath $fdest`)
    filter(x -> occursin(".grb", x), readdir(dest, join = true))
end

function to_netcdf(fpaths, dest)
    fnames = getindex.(splitext.(fpaths), 1) .|> basename
    fdests = joinpath.(dest, fnames.*".nc")
    for (fname, fdest) in zip(fpaths, fdests)
        Base.run(`grib_to_netcdf $fname -o $fdest`)
    end
    fdests
end