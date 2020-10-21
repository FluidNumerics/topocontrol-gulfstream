#!/bin/bash

SCRIPT_PATH="/home/joe/apps/topocontrol-gulfstream/MITGCM50_z75/post"
REMOTE_STDOUT="schoonover@port.ocean.fsu.edu:MITgcm/MITGCM50_z75/run/STDOUT.0000"
SIMULATION_ID="mitgcm-50z75-spinup-1"
BQ_TABLE="fsu-gulfstream:mitgcm_run_data.monitor_stats"

cd $SCRIPT_PATH
mkdir -p ${SCRIPT_PATH}/stats

# Copy STDOUT from remote host where the simulation is running
scp ${REMOTE_STDOUT} ${SCRIPT_PATH}/stats/STDOUT.0000

# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><> #
#   Run the monitorStats application and post the simulation
#   statistics to BigQuery

source env/bin/activate
python3 ./monitorStats.py plot ${SCRIPT_PATH}/stats/STDOUT.00  --simulation_id=${SIMULATION_ID}
deactivate

# Load the data to bigquery
bq load --source_format=NEWLINE_DELIMITED_JSON ${BQ_TABLE} ${SIMULATION_ID}/bq_payload.json

# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><> #
