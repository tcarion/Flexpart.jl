using Flexpart.FlexpartInputs
using Rasters
const DD = Rasters.DimensionalData

function read_input(input::AbstractInputFile)
    inpath = convert(String, input)
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
    
    # NamedTuple would be better, but it seems that in that case,
    # the layers get loaded into memory.
    # set = Set(create_raster(ncf)[Ti(1)] for ncf in ncf_files)
    # merge(set...)

    nt = NamedTuple(Symbol(layer) => create_raster(ncf) |> _reorder for (layer, ncf) in zip(layer_names, ncf_files))

    # rpairs = map(zip(layer_names, ncf_files)) do (layer, ncf)
    #     stack = RasterStack(ncf)
    #     stack = reorder(stack,
    #         X => DD.ForwardOrdered, 
    #         Y => DD.ForwardOrdered,
    #     )

    #     if hasdim(stack, :Z)
    #         stack = reorder(stack, Z => DD.ReverseOrdered)
    #     end

    #     Symbol(layer) => stack
    # end
    # for (layer, ncf) in zip(layer_names, ncf_files)
    #     stack = RasterStack(ncf)
    #     stack = reorder(stack,
    #         X => DD.ForwardOrdered, 
    #         Y => DD.ForwardOrdered,
    #     )

    #     if hasdim(stack, :Z)
    #         stack = reorder(stack, Z => DD.ReverseOrdered)
    #     end

    #     push!(d, Symbol(layer) => stack)
    # end
    # Dict(rpairs)
end

"""
Create the RasterStack.
"""
create_raster(ncf) = RasterStack(ncf)

# function Rasters.RasterSeries(input::AbstractInputFile)
#     inpath = convert(String, input)
#     ncf_dir = mkpath(inpath*"_ncf")
#     gribs = copy_grib(inpath, ncf_dir)
#     ncfs = to_netcdf(gribs, ncf_dir)
#     rm.(gribs)
#     fnames = getindex.(splitext.(ncfs), 1) .|> basename
#     layer_types = getindex.(split.(fnames, input.filename), 2)
#     layer_dims = [Dim{Symbol(layer)}() for layer in layer_types]
#     Rasters.RasterSeries(ncfs, layer_dims)
# end


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

"""
Reorder the dimensions. Note: this will load the stack into memory 
It is considered more intuitive to have the last level at the first Z index (as the last level is bottom most level)
"""
function _reorder(stack)
    stack = reorder(stack,
        X => DD.ForwardOrdered, 
        Y => DD.ForwardOrdered,
    )

    if hasdim(stack, :Z)
        stack = reorder(stack, Z => DD.ReverseOrdered)
    end

    stack
end