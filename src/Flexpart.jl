module Flexpart


using GRIB
using Pkg.Artifacts
using Dates
using DataStructures: OrderedDict
using DocStringExtensions
using FLEXPART_jll
# using Debugger
# using PyPlot

export
    FlexpartSim,
    SimType,
    Deterministic,
    Ensemble,
    Available,
    FlexpartOption,
    FeControl,
    set_steps!

export 
    InputFiles, 
    Available, 
    DeterministicInput, 
    EnsembleInput,
    AbstractInputFile,
    inputs_from_dir

export    
    AbstractOutputFile,
    OutputFiles,
    DeterministicOutput,
    EnsembleOutput
# @template TYPES =
#     """
#     # Summary
#     $(TYPEDEF)

#     $(DOCSTRING)

#     # Fields

#     $(TYPEDFIELDS)

#     # Constructors

#     $(METHODLIST)
#     """
const CMD_FLEXPART = FLEXPART()
# TODO: UPDATE TO REAL ARTIFACT
const ROOT_ARTIFACT_FLEXPART_DATA = artifact"flexpart_data"
# const ROOT_ARTIFACT_FLEXPART = "test/flexpart_data"

# const OPTIONS_DIR_DEFAULT = "./options"
# const OUTPUT_DIR_DEFAULT = "./output"
# const INPUT_DIR_DEFAULT = "./input"
# const AVAILABLE_PATH_DEFAULT = "./AVAILABLE"
const PATHNAMES_FILENAME = "pathnames"
const DEFAULT_FP_DIR = joinpath(ROOT_ARTIFACT_FLEXPART_DATA, "default_fpdir")
const DEFAULT_PATH_PATHNAMES = joinpath(DEFAULT_FP_DIR, PATHNAMES_FILENAME)
const PATHNAMES_KEYS = (:options, :output, :input, :available)

# const DEFAULT_FP_DIR = joinpath(@__DIR__, "files", "flexpart_dir_template")
const FLEXIN_PATH = joinpath(ROOT_ARTIFACT_FLEXPART_DATA, "flexin")

# Paths to input files for testing purposes
const FP_TESTS_PATH = joinpath(ROOT_ARTIFACT_FLEXPART_DATA, "tests")
const FP_TESTS_DETER_INPUT = joinpath(FP_TESTS_PATH, "input", "deterministic")
const FP_TESTS_ENS_INPUT = joinpath(FP_TESTS_PATH, "input", "ensemble")

const DEFAULT_PATHNAMES = readlines(joinpath(DEFAULT_FP_DIR, PATHNAMES_FILENAME))

const MAX_PARTICLES = 2000000

function write end
function getpathnames end
function getpath end
# function create end
# function set! end

include("abstracts.jl")
include("flexpartsim.jl")
include("readgrib.jl")
include("utils.jl")
include("inputs.jl")
include("FlexpartOptions.jl")
include("outputs.jl")
include("run.jl")

using .FlexpartOptions
# using .FlexpartOutputs

include("miscellaneous.jl")

end


