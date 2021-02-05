#!/bin/sh

set -x

#N=8 # Number of processes in each batch for the downscaling script
ITER0=108720 # June 1 (Day 151)
ITERN=1749600 # September 30 (Day 243)
dITER=720 # Iterate difference between successive files ( 1 day @ deltaTclock=120s )

SIM_PATH=/tank/topog/gulf-stream/simulation/MITGCM50_z75/run/production/metadata/
OUTDIR=/tank/topog/gulf-stream/simulation/MITGCM100_z75/input

mkdir -p $OUTDIR/prep

for i in `seq $ITER0 $dITER $ITERN`; do

    python3 downscale.py create "$SIM_PATH" --iterate="$i" \
                                            --south="29.0" \
                                            --north="41.215" \
                                            --west="0.0" \
                                            --east="15.0" \
                                            --outdir="$OUTDIR/prep"
done

wait
