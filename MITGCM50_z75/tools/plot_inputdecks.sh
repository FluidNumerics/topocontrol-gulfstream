#!/bin/bash

#source env/bin/activate

# Plot the bathymetry
python3 input_deck_review.py bathymetry ../input/gebco_smoothed_topog.nc --outdir=./plots --cmap=terrain

# Plot the velocity
python3 input_deck_review.py cheapaml-velocity ../input/gebco_smoothed_topog.nc ../input/u10.bin ../input/v10.bin 0.0 25.0 6 --outdir=./plots --cmap=Reds


# Short wave radiation
python3 input_deck_review.py cheapaml-field ../input/gebco_smoothed_topog.nc ../input/radsw.bin radsw "(W/m^2)" 0.0 800 6 --outdir=./plots --cmap=Reds

# 2m Temperature
python3 input_deck_review.py cheapaml-field ../input/gebco_smoothed_topog.nc ../input/t2.bin temperature "(C)" -10 0.0006 6 --outdir=./plots --cmap=Reds

# 2m Humidity
python3 input_deck_review.py cheapaml-field ../input/gebco_smoothed_topog.nc ../input/q2.bin humidity "(kg/kg)" 0.0 0.02 6 --outdir=./plots --cmap=Reds

# Long wave radiation
python3 input_deck_review.py cheapaml-field ../input/gebco_smoothed_topog.nc ../input/radlw.bin radlw "(W/m^2)" 200 450 6 --outdir=./plots --cmap=Reds

# Precipitation
python3 input_deck_review.py cheapaml-field ../input/gebco_smoothed_topog.nc ../input/precip.bin precip "(kg/m^2)" 0.0 0.0006 6 --outdir=./plots --cmap=Reds
