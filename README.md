# Flexpart

[![lifecycle](https://www.repostatus.org/badges/latest/wip.svg)](https://www.repostatus.org/#wip)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://tcarion.github.io/Flexpart.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://tcarion.github.io/Flexpart.jl/dev/)
[![Build Status](https://github.com/tcarion/Flexpart.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/tcarion/Flexpart.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/tcarion/Flexpart.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/tcarion/Flexpart.jl)

Flexpart.jl is a Julia interface to the [FLEXPART](https://www.flexpart.eu/) Lagrangian transport and dispersion model. It provides the following:

- It makes the FLEXPART executable available in the Julia environment.
- It maps the FLEXPART syntax to common Julia data structures to facilitate the settings of simulations in Julia

## Installation
The package is not yet on the official registry, and must be installed this way:
```julia
using Pkg; Pkg.add(url="https://github.com/tcarion/Flexpart.jl")
```

## Quick start
The first thing to do for running FLEXPART is to create a directory with a `pathnames` file:
```julia
using Flexpart

# You can create a default Flexpart directory with:
fpsim = Flexpart.create("example")

# you can use an existing one with:
fpsim = FlexpartSim("existing")

# or you can create a temporary default directoy with:
fpsim = FlexpartSim()
```

Then let's define the location of the input files. The retrieval and pre-processing of the input meteorological data for Flexpart needs to be done with the [FlexExtract.jl](https://github.com/tcarion/FlexExtract.jl) package.
```julia
fpsim[:input] = "path/to/inputs"

# This will write the changes to the pathnames file.
Flexpart.save(fpsim)
```

The FLEXPART options can be modified this way:

```julia
using Flexpart.FlexpartOptions
options = FlexpartOption(fpsim)

# Options can be accessed and modified as a Julia Dictionnary
options["COMMAND"][:COMMAND][:IOUT] = 9

# Some helper functions also exist to facilitate the modification of the options
set_point_release!(options, 4.4, 50.5)

# We write the changes to the files
Flexpart.save(options)
```

And finally Flexpart can be run:
```julia
Flexpart.run(fpsim)
```

The NetCDF output can be easily read and plotted with Rasters.jl and Plots.jl:

```julia
using Rasters, Plots
# loading of the output file
output_file = first(OutputFiles(fpsim))

# we read the output with Rasters.jl
output_stack = RasterStack(string(output_file))
conc = output_stack[:spec001_mr]

# and plot the result
plot(conc[Ti = 2, height = 1, pointspec = 1, nageclass = 1])
```

## Caveat:
- This package is under heavy development and the API is subjected to change substantially.
- The FLEXPART binary has only been compiled for Linux systems for now, so this package won't work on Windows and macOS.