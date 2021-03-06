#!/bin/bash

source env/bin/activate

ITERATE=$(sed -n${SLURM_ARRAY_TASK_ID}p iterates.txt)

python3 post-process.py glob --datadir=$DATADIR \
                             --iterate=$ITERATE \
                             --outdir=$OUTDIR \
                             --zsplit=$ZSPLIT \
                             --simulation_phase=$SIMULATION_PHASE \
                             --simulation_id=$SIMULATION_ID \
                             --deltaTclock=$DELTA_T_CLOCK
                             
