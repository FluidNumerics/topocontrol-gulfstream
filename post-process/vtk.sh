#!/bin/bash

source env/bin/activate

ITERATE=$(sed -n ${SLURM_ARRAY_TASK_ID}p iterates.txt)
echo $ITERATE

python3 post-process.py vtk --datadir=$DATADIR --iterate=$ITERATE --outdir=$OUTDIR 
                             
