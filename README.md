# MITGCM50_z75
This simulation is the starting point of a series of downscaling simulations with the MITgcm to investigate the dynamics of the Gulf Stream separation and the potential interaction with topographic waves near Cape Hatteras. The ocean boundary and initial conditions are derived from years 17-19 of the HYCOM50 simulation described in [Chassignet and Xu (2017)](https://doi.org/10.1175/JPO-D-17-0031.1). Atmospheric fields that drive CheapAML are created from year 2003 of the (??) dataset, which is a neutral year for the NAO index. Ocean bathymetry is derived from the GEBCO-2019 global bathymetric/topographic data set. This README describes how all of the input fields are created and how the input namelist parameters are chosen.

## Ocean Boundary & Initial Conditions
Ocean boundary conditions are developed from years 17-19 of the HYCOM50 simulation of [Chassignet and Xu (2017)](https://doi.org/10.1175/JPO-D-17-0031.1). The authors of this paper have provided daily U, V, T, S, and Eta fields on the southern, eastern, and northern boundaries of our model domain (.mat files). The 3 years of data are climatologically averaged and linearly detrended to produce an annual cycle. The provided fields originally contained a 366 day year; we have removed (arbitrarily) day 366 from the climatology fields prior to removing the linear trend. A 365-day year is needed to match the 365-day year associated with the atmospheric fields that are produced from 2003 (neutral NAO year).

After temporal processing, fields are vertically interpolated from HYCOM's density grid to the vertical cell center's of the 75-Layer vertical grid. Prior to interpolation, "dry" grid cell locations are in-painted using [Inpaint_NaNs](https://www.mathworks.com/matlabcentral/fileexchange/4551-inpaint_nans) with the "spring metaphor" method (method=4). This method fills in dry cells using a constant-function extrapolation in each spatial-direction, which prevents spurious unrealistic values from being used with vertical interpolation.


## Atmospheric fields (CheapAML)

CheapAML settings are consistent with [ChaOcean simulation configurations](https://github.com/quentinjamet/chaocean/blob/master/MITgcm/ocac/memb00/data.cheapaml)

## Model Configuration

### Grid and Resolution
The grid is chosen to closely match the HYCOM50 simulation of [Chassignet and Xu (2017)](https://doi.org/10.1175/JPO-D-17-0031.1). We have selected a subdomain of the HYCOM50 grid, spanning from 27.9947 N to (??) N and (??) E to (??) E. The grid spacing from the HYCOM50 simulation is preserved, where the longitudinal grid spacing is dx = 0.02 degrees and the latitudinal grid spacing varies linearly with latitude from 0.0177 degrees at 27.9947 N to 0.0144 (verify??) degrees at (??) N.

The vertical grid is identical to the 75-layer vertical grid used in the [ORCA025.L75-GRD100 simulation of the DRAKKAR project](https://www.drakkar-ocean.eu/publications/reports/orca025-grd100-report-dussin)

*From data PARM04*
```
 &PARM04
 usingCartesianGrid=.FALSE.,
 usingSphericalPolarGrid=.TRUE.,
 ygOrigin=27.9947,
 delXFile='dx.bin',
 delYFile='dy.bin',
 delRFile='dz.bin',
 &end
```

### Advection Scheme
3-DST + Sweby Flux Limiter (Code=33)

### Lateral Viscosity & Diffusivity
Lateral Viscosity & Diffusivity values are chosen to be consistent with the HYCOM50 simulation of [Chassignet and Xu (2017)](https://doi.org/10.1175/JPO-D-17-0031.1). Specifically, lateral viscous and diffusive operators are a combination of Laplacian and Biharmonic. Lateral Laplacian viscosisty and diffusivity are set to `Ah = 10 m^2/s`. The biharmonic viscosity and diffusivity is set to `A4h = V4*dx^3` where `V4 = 4 cm/s` and `dx=1968.15` is the latitudinal grid spacing at the southern boundary (where it is largest). This gives (approximately) `A4h = 7.87E7 m^4/s` 

### Vertical Viscosity & Diffusivity
Vertical viscous and diffusion operators are Laplacian with combination of a fixed vertical viscosity and diffusivity of (??) and additional viscosity and diffusivity diagnosed from the K-Profile Parameterization of [Large et. al (1994)](https://agupubs.onlinelibrary.wiley.com/doi/abs/10.1029/94RG01872)


### Momentum Boundary Conditions
Free slip sides and free slip bottom
Quadratic bottom drag


