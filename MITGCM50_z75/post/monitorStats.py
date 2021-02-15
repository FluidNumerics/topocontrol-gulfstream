#!/usr/bin/python3
DOC="""monitorStats
A script used to plot the monitor statistics reported in STDOUT.

Usage:
  monitorStats report <file> [--simulation_id=<simid>] [--simulation_phase=<simphase>]


Commands:
  plot              Create plots
  report            Create a json payload for the report


Options:
  -h --help                 Display this help screen
  --simulation_id=<simid>   An alphanumeric simulation identifier [default: mitgcm50_z75]
  --simulation_phase=<simphase>   An alphanumeric simulation phase identifier [default: production]
"""

from MITgcmutils import mds
from docopt import docopt
import numpy as np
import json
import os
import datetime

simStart = datetime.datetime(2003,1,1,0,0,0)

def parse_cli():

  args = docopt(DOC,version='monitorStats 0.0.0')
  return args

#END parse_cli

def main():

  args = parse_cli()

#  args = {'<file>':'output/STDOUT.0000', '--simulation_id':'mitgcm-50-z75-spinup'}
  stats = {'time_tsnumber':[],
           'time_secondsf':[],
           'dynstat_eta_max':[],
           'dynstat_eta_min':[],
           'dynstat_eta_mean':[],
           'dynstat_eta_sd':[],
           'dynstat_eta_del2':[],
           'dynstat_uvel_max':[],
           'dynstat_uvel_min':[],
           'dynstat_uvel_mean':[],
           'dynstat_uvel_sd':[],
           'dynstat_uvel_del2':[],
           'dynstat_vvel_max':[],
           'dynstat_vvel_min':[],
           'dynstat_vvel_mean':[],
           'dynstat_vvel_sd':[],
           'dynstat_vvel_del2':[],
           'dynstat_wvel_max':[],
           'dynstat_wvel_min':[],
           'dynstat_wvel_mean':[],
           'dynstat_wvel_sd':[],
           'dynstat_wvel_del2':[],
           'dynstat_theta_max':[],
           'dynstat_theta_min':[],
           'dynstat_theta_mean':[],
           'dynstat_theta_sd':[],
           'dynstat_theta_del2':[],
           'dynstat_salt_max':[],
           'dynstat_salt_min':[],
           'dynstat_salt_mean':[],
           'dynstat_salt_sd':[],
           'dynstat_salt_del2':[],
           'trAdv_CFL_u_max':[],
           'trAdv_CFL_v_max':[],
           'trAdv_CFL_w_max':[],
           'advcfl_uvel_max':[],
           'advcfl_vvel_max':[],
           'advcfl_wvel_max':[],
           'advcfl_W_hf_max':[],
           'pe_b_mean':[],
           'ke_max':[],
           'ke_mean':[],
           'ke_vol':[],
           'vort_r_min':[],
           'vort_r_max':[],
           'vort_a_mean':[],
           'vort_a_sd':[],
           'vort_p_mean':[],
           'vort_p_sd':[],
           'surfExpan_theta_mean':[],
           'surfExpan_salt_mean':[]}

  with open(args['<file>'], 'r') as fp:
    for line in fp:
      for var in stats.keys():
        if var in line:
          stats[var].append(np.float64(line.split('=')[-1].lstrip().rstrip()))

  # Create a JSON payload for output
  output_payload = {'monitor_stats':[]}
  for var in stats.keys():
    for k in range(len(stats[var])):
      simDateTime = simStart + datetime.timedelta(seconds=stats['time_secondsf'][k])
      pl = {'simulation_datetime': simDateTime.strftime("%Y/%m/%d %H:%M:%S"),
            'metric_name':var,
            'metric_value':stats[var][k],
            'simulation_id':args['--simulation_id'],
            'simulation_phase':args['--simulation_phase']}
      output_payload['monitor_stats'].append(pl)

  with open('./bq_payload.json','w') as f:
    for io in output_payload['monitor_stats']:
      json.dump(io,f)
      f.write('\n')

#END main

if __name__ == '__main__':
  main()
