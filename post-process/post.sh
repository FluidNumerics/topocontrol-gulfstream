#!/bin/bash

export ACCOUNT=cfd
export PARTITION=vtk-processing
export SIMULATION_ID="mitgcm50-z75-l1a"
export SIMULATION_PHASE="production"
export DATADIR=/mnt/mitgcm-datastore/MITgcm/MITGCM50_z75/run/
export OUTDIR=/mnt/mitgcm-datastore/MITgcm/MITGCM50_z75/run/production-l1detrend/
export ZSPLIT="-300"
export DELTA_T_CLOCK="120"

source env/bin/activate

mkdir -p $OUTDIR

# Create a list of available iterates for time-series processing
python3 gen-iterates.py list --datadir=$DATADIR > tmp.txt
tail -n +3 tmp.txt > iterates.txt
rm tmp.txt

niterates=$(cat iterates.txt | wc -l)

# Launch job arrays for post processing
# Convert output to VTK
sbatch --get-user-env \
       --ntasks=1 \
       --mem=20g \
       --array=1-${niterates}%50\
       --account=$ACCOUNT \
       --partition=$PARTITION \
       vtk.sh

# Upper and lower temperature average
sbatch --get-user-env \
       --ntasks=1 \
       --mem=20g \
       --array=1-${niterates}%50 \
       --account=$ACCOUNT \
       --partition=$PARTITION \
       zbox.sh

#sbatch --get-user-env \
#       --ntasks=1 \
#       --mem=1g \
#       --array=1-$niterates \
#       --account=$ACCOUNT \
#       --partition=$PARTITION \
#       advf.sh
#
#sbatch --get-user-env \
#       --ntasks=1 \
#       --mem=1g \
#       --array=1-$niterates \
#       --account=$ACCOUNT \
#       --partition=$PARTITION \
#       glob.sh
#
