using Flexpart.FlexpartInputs
import Flexpart.FlexpartInputs: getpath
using Rasters

function read_input(input::AbstractInputFile)
    inpath = getpath(input)
    nc_dirname = inpath*"_ncf"
    ncf_dir = mkpath(nc_dirname)
    ncf_files = get_ncfiles(nc_dirname)
    if isempty(ncf_files)
        gribs = copy_grib(inpath, ncf_dir)
        ncf_files = to_netcdf(gribs, ncf_dir)        
        rm.(gribs)
    end
    fnames = getindex.(splitext.(ncf_files), 1) .|> basename
    layer_names = getindex.(split.(fnames, input.filename), 2)
    Dict(Symbol(layer) => RasterStack(ncf) for (layer, ncf) in zip(layer_names, ncf_files))
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

get_ncfiles(dirpath) = filter(x -> splitext(x)[2] == ".nc", readdir(dirpath, join = true))

function dict_layers(rasters)
    lt = keys(rasters)

    Dict(k => collect(keys(rasters[k])) for k in lt)
end