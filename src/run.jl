function getcmd(fpsim::FlexpartSim)
    pn_path = pathnames_path(fpsim)
    `$CMD_FLEXPART $pn_path`
end

"""
    $(TYPEDSIGNATURES)

Run Flexpart using the paths of `fpsim`.
"""
function run(fpsim::FlexpartSim{Deterministic}; log = false) 
    if log == false 
        _run_helper(fpsim; f = nothing)
    else
        logpath = joinpath(fpsim[:output], "output.log")
        open(logpath, "w") do logf
            run(fpsim) do io
                log_output(io, logf)
            end
        end
    end
end

run(f::Function, fpsim::FlexpartSim{Deterministic}) = _run_helper(fpsim; f = f)

run(fpsim::FlexpartSim{Ensemble}) = _run_helper(fpsim)

run() = FlexpartSim() do fpsim
    default_run(fpsim)
end

function _run_helper(fpsim::FlexpartSim{Deterministic}; f = nothing)
    # println("The following command will be run : $cmd")
    tempfpdir = FlexpartSim()
    tempfpdir[:options] = fpsim[:options]
    tempfpdir[:output] = fpsim[:output]
    tempfpdir[:input] = fpsim[:input]
    tempfpdir[:available] = fpsim[:available]

    save(tempfpdir)
    cmd = getcmd(tempfpdir)
    # println("Will run Flexpart with following pathnames: ")
    # println(tempfpdir.pathnames)
    if isnothing(f)
        Base.run(cmd)
    else
        pipe = Pipe()
        @async while true
            f(pipe)
        end

        Base.run(pipeline(cmd, stdout=pipe, stderr=pipe))
    end
end

function _run_helper(fpsim::FlexpartSim{Ensemble})
    inputs = InputFiles(fpsim[:input])
    members = [x.member for x in inputs] |> unique 
    sep_inputs = [filter(x -> x.member==i, inputs) for i in members]

    for realization in sep_inputs
        imember = realization[1].member
        tempfpdir = FlexpartSim()
        memb_out_path = joinpath(fpsim[:output], "member$(imember)")
        mkpath(memb_out_path)
        tempfpdir[:options] = fpsim[:options]
        tempfpdir[:output] = memb_out_path
        tempfpdir[:input] = fpsim[:input]

        det_inputs = convert.(DeterministicInput, realization)
        real_av = Available(det_inputs, tempfpdir[:available])
        save(real_av)
        saveabs(tempfpdir)
        
        log_path = joinpath(getpath(fpsim), "member$(imember).log")
        @async open(log_path, "w") do logf
            run(tempfpdir) do io
                log_output(io, logf)
            end
        end 
    end
    # for i in 0:nmember-1
    #     push!(sep_inputs, filter(x -> x.member==i, inputs))
    # end
end

function log_output(io::IO, fileio::IO)
    line = readline(io, keep=true)
    Base.write(fileio, line)
    flush(fileio)
end

function default_run(fpsim::FlexpartSim{Deterministic})
    fpsim[:input] = abspath(FP_TESTS_DETER_INPUT)
    dummy_run(fpsim)
end

function dummy_run(fpsim::FlexpartSim{Deterministic})
    avs = Available(fpsim)
    options = FlexpartOption(fpsim)
    set_cmd_dates!(options, avs)
    set_release_at_start!(options, avs, Dates.Minute(30))
    input_area = grib_area(avs[1])
    lon = input_area[2] + (input_area[4] - input_area[2]) / 2
    lat = input_area[3] + (input_area[1] - input_area[3]) / 2
    set_point_release!(options, lon, lat)
    gridres, _ = Flexpart.grib_resolution(avs[1])
    outgrid = Flexpart.area2outgrid(fpsim, gridres)
    merge!(options["OUTGRID"][:OUTGRID], outgrid)
    options["COMMAND"][:COMMAND][1][:IOUT] = 9
    Flexpart.save(avs)
    Flexpart.save(options)
    Flexpart.run(fpsim)
end
