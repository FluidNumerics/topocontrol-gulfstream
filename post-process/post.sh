#!/bin/bash

ACCOUNT=cfd
PARTITION=vtk-processing
SIMULATION_ID="mitgcm50-z75"
SIMULATION_PHASE="spinup"
DATADIR=/mnt/mitgcm-datastore/MITgcm/MITGCM50_z75/run/spinup/metadata/
OUTDIR=/mnt/mitgcm-datastore/MITgcm/MITGCM50_z75/run/spinup/metadata/post
ZSPLIT="-300"

source env/bin/activate

mkdir -p $OUTDIR

# Create a list of available iterates for time-series processing
python3 gen-iterates.py list --datadir=$DATADIR > iterates.txt
niterates=$(wc -l iterates.txt)

# Launch job arrays for post processing
sbatch --get-user-env \
       --ntasks=1 \
       --mem=1g \
       --array=1-$niterates \
       --account=$ACCOUNT \
       --partition=$PARTITION \
       zbox.sh

sbatch --get-user-env \
       --ntasks=1 \
       --mem=1g \
       --array=1-$niterates \
       --account=$ACCOUNT \
       --partition=$PARTITION \
       advf.sh

sbatch --get-user-env \
       --ntasks=1 \
       --mem=1g \
       --array=1-$niterates \
       --account=$ACCOUNT \
       --partition=$PARTITION \
       glob.sh

sbatch --get-user-env \
       --ntasks=1 \
       --mem=1g \
       --array=1-$niterates \
       --account=$ACCOUNT \
       --partition=$PARTITION \
       vtk.sh
