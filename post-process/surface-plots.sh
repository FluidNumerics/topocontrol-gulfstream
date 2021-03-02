#!/bin/bash

DELTAT=120
DIR=/tank/topog/gulf-stream/simulation/MITGCM50_z75/run/production/metadata
OUTDIR=/tank/topog/gulf-stream/simulation/MITGCM50_z75/run/production/plots/surface



mkdir -p $OUTDIR

for f in $DIR/S.*.data;
do

  iter=$(echo $f | awk -F "." '{print $2}')
  echo $iter
#surface-plot plot [--datadir=<path>] [--deltaTclock=<seconds>] [--iterate=<integer>] [--outdir=<path>]

  python3 surface-plot.py plot --datadir=$DIR \
                               --deltaTclock=$DELTAT \
                               --iterate=$iter \
                               --outdir=$OUTDIR



done
