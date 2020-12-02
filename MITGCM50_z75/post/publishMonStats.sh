#!/bin/bash

set -x
SCRIPT_PATH="/home/joe/topocontrol-gulfstream/MITGCM50_z75/post"
REMOTE_STDOUT="/mnt/mitgcm-datastore/MITgcm/MITGCM50_z75/run/STDOUT.0000"
SIMULATION_ID="mitgcm-50z75-spinup-phaseII-gcp"
BQ_TABLE="fsu-gulfstream:mitgcm_run_data.monitor_stats"

cd $SCRIPT_PATH
source ${SCRIPT_PATH}/env/bin/activate
mkdir -p ${SCRIPT_PATH}/stats

# Copy STDOUT from remote host where the simulation is running
scp ${REMOTE_STDOUT} ${SCRIPT_PATH}/stats/STDOUT.0000

# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><> #
#   Run the monitorStats application and post the simulation
#   statistics to BigQuery

source env/bin/activate
python3 ./monitorStats.py plot ${SCRIPT_PATH}/stats/STDOUT.0000  --simulation_id=${SIMULATION_ID}
deactivate

# Load the data to bigquery
if [ -s ${SIMULATION_ID}/bq_payload.json ]
then
  bq load --source_format=NEWLINE_DELIMITED_JSON ${BQ_TABLE} ${SIMULATION_ID}/bq_payload.json
else
  echo "${SIMULATION_ID}/bq_payload.json is empty. Nothing to load at the moment :)"
fi

# <><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><> #

deactivate
