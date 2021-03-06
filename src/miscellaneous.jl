"""
    $(TYPEDSIGNATURES)

Update the simulation start and stop options with `start` date and `stop` date. 
"""
function set_cmd_dates!(options::FlexpartOption, start::DateTime, stop::DateTime)
    options["COMMAND"][:COMMAND][:IBDATE] = Dates.format(start, "yyyymmdd")
    options["COMMAND"][:COMMAND][:IBTIME] = Dates.format(start, "HHMMSS")
    options["COMMAND"][:COMMAND][:IEDATE] = Dates.format(stop, "yyyymmdd")
    options["COMMAND"][:COMMAND][:IETIME] = Dates.format(stop, "HHMMSS")
end

"""
    $(TYPEDSIGNATURES)

Update the simulation start and stop options from the inputs available in `avs`. 
"""
set_cmd_dates!(options::FlexpartOption, avs::Available) = set_cmd_dates!(options::FlexpartOption, avs[1].time, avs[end].time)

function set_release_at_start!(options::FlexpartOption, avs::Available, duration::Dates.AbstractTime)
    options["RELEASES"][:RELEASE][:IDATE1] = Dates.format(avs[1].time, "yyyymmdd")
    options["RELEASES"][:RELEASE][:ITIME1] = Dates.format(avs[1].time, "HHMMSS")
    options["RELEASES"][:RELEASE][:IDATE2] = Dates.format(avs[1].time, "yyyymmdd")
    options["RELEASES"][:RELEASE][:ITIME2] = Dates.format(avs[1].time + duration, "HHMMSS")
end

"""
    $(TYPEDSIGNATURES)

Update a release option `release` start and stop datetime given the `start` and `duration`.
# Examples
```jldoctest
julia> fpoptions = FlexpartOption(FlexpartDir())
julia> Flexpart.set_release_duration!(fpoptions["RELEASES"][:RELEASE][1], Dates.now(), Dates.Second(120))
```
"""
function set_release_duration!(release::FlexpartOptions.OptionEntriesType, start::DateTime, duration::Dates.AbstractTime)
    stop = start + duration
    set_release_dates!(release, start, stop)
end

"""
    $(TYPEDSIGNATURES)

Update a release option `release` start and stop datetime given the `start` and `stop` DateTime.
# Examples
```jldoctest
julia> fpoptions = FlexpartOption(FlexpartDir())
julia> Flexpart.set_release_dates!(fpoptions["RELEASES"][:RELEASE][1], Dates.now(), Dates.now() + Dates.Second(120))
```
"""
function set_release_dates!(release::FlexpartOptions.OptionEntriesType, start::DateTime, stop::DateTime)
    release[:IDATE1] = _date_format(start)
    release[:ITIME1] = _time_format(start)
    release[:IDATE2] = _date_format(stop)
    release[:ITIME2] = _time_format(stop)
end

"""
    $(TYPEDSIGNATURES)

Update a release option `release` location with `lon` and `lat`.
"""
function set_point_release!(release::FlexpartOptions.OptionEntriesType, lon, lat)
    release[:LAT1] = lat
    release[:LAT2] = lat
    release[:LON1] = lon
    release[:LON2] = lon 
end

set_point_release!(options::FlexpartOption, lon, lat) = set_point_release!(options["RELEASES"][:RELEASE][1], lon, lat)

function area2outgrid(area::Vector{<:Real}, gridres::Real = 0.01; nested = false)
    outlon0 = area[2]
    outlat0 = area[3]
    ??lon = area[4] - outlon0
    ??lat = area[1] - outlat0
    ??lon, ??lat = round.([??lon, ??lat], digits = 5)
    (numxgrid, numygrid) = try
        convert(Int, round(??lon / gridres)), convert(Int, round(??lat / gridres))
    catch
        error("gridres must divide area")
    end
    dxout = gridres
    dyout = gridres
    res = Dict(
        :OUTLON0 => outlon0, :OUTLAT0 => outlat0, :NUMXGRID => numxgrid, :NUMYGRID => numygrid, :DXOUT => dxout, :DYOUT => dyout,
    )
    nested ? Dict(
        String(k) * 'N' |> Symbol => v for (k, v) in res
    ) : res
end

function area2outgrid(fpdir::FlexpartDir, gridres::Real; nested = false)
    firstinput = readdir(fpdir[:input], join = true)[1]
    area = grib_area(firstinput)

    area2outgrid(area, gridres; nested)
end

function remove_unused_species!(fpoptions::FlexpartOption)
    nspec = parse(Int, fpoptions["RELEASES"][:RELEASES_CTRL][:SPECNUM_REL].value)
    for (k, v) in fpoptions.options
        try
            specnum = parse(Int, k[end-2:end])
            if !(nspec == specnum)
                pop!(fpoptions.options, k)
            end
        catch
        end
    end
end

"""
    $(TYPEDSIGNATURES)

Update the specie number in the RELEASES options from the name `specie`.

# Examples
```jldoctest
julia> Flexpart.set_specie!(FlexpartOption(FlexpartDir()), "CH4")
26
```
"""
function set_specie!(fpoptions::FlexpartOption, specie::String)
    fpoptions["RELEASES"][:RELEASES_CTRL][:SPECNUM_REL] = specie_number(specie)
end

_time_format(date::DateTime) = Dates.format(date, "HHMMSS")
_date_format(date::DateTime) = Dates.format(date, "yyyymmdd")