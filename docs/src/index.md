# Flexpart.jl Documentation

`Flexpart.jl` is a package that allows to prepare and run the [Flexpart](https://www.flexpart.eu/) Lagrangian atmospheric dispersion model with a Julia interface. More precisely, it is possible to:

- Retrieve the meteorological data from the ECMWF MARS system. It wraps the [flex_extract](https://www.flexpart.eu/flex_extract/) software that retrieve the meteorological fields and pre-process them to produce inputs for Flexpart.
- Modify the options of Flexpart in a Julia way.
- Run simulations with an existing installation of Flexpart.