#!/usr/bin/python3
DOC="""monitorStats
A script used to plot the monitor statistics reported in STDOUT.

Usage:
  monitorStats plot <file> [--simulation_id=<simid>]


Commands:
  plot              Create plots
  report            Create a json payload for the report


Options:
  -h --help                 Display this help screen
  --simulation_id=<simid>   An alphanumeric simulation identifier [default: mitgcm-50z75-spinup-1]
"""
from MITgcmutils import mds
from matplotlib import pyplot as plt
from docopt import docopt
import numpy as np
import json
import os
from dictdiffer import diff, patch

def parse_cli():

  args = docopt(DOC,version='monitorStats 0.0.0')
  return args

#END parse_cli

def plotStats(monStats, opts, outdir):

    for var in monStats.keys():
      if not var == 'time_secondsf':
        nt = len(monStats[var])
        f, ax = plt.subplots()
        ax.plot(monStats['time_secondsf'][0:nt-1], monStats[var][0:nt-1], marker='', color='black', linewidth=2, label=var)
        ax.fill_between(monStats['time_secondsf'][0:nt-1], 0.0, monStats[var][0:nt-1], color=(0.8,0.8,0.8,0.8))

        ax.grid(color='gray', linestyle='-', linewidth=1)
        ax.set(xlabel=var, ylabel='Time (s)')
        f.savefig(outdir+var+'.png')
        plt.close('all')

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

  plotdir = args['--simulation_id']+'/plots/'
  try:
    os.makedirs(plotdir)
  except:
    print(plotdir + ' directory creation failed')

  # Load existing raw stats
  print('Loading raw_stats')
  try:
    with open(args['--simulation_id']+'/raw_stats.json') as f:
      raw = json.load(f)
  except:
    raw = {}

  with open(args['<file>'], 'r') as fp:
    for line in fp:
      for var in stats.keys():
        if var in line:
          stats[var].append(np.float(line.split('=')[-1].lstrip().rstrip()))

  with open(args['--simulation_id']+'/raw_stats.json','w') as f:
    json.dump(stats,f)

  #plotStats(stats, {}, plotdir )

  # Calculate the difference in data so that we only load new data to BQ
  if raw:
    statsDiff = diff(raw,stats)
    newStats = {}
    for d in list(statsDiff):
      if d[0] == 'add':
        newStats[d[1]] = []
        for v in d[2]:
          newStats[d[1]].append(v[1])
  else:
    newStats = stats

  # Create a JSON payload for output
  output_payload = {'monitor_stats':[]}
  for var in newStats.keys():
    for k in range(len(newStats[var])):
      pl = {'name':var,
            'time_seconds':newStats['time_secondsf'][k],
            'value':newStats[var][k],
            'simulation_id':args['--simulation_id']}
      output_payload['monitor_stats'].append(pl)

  with open(args['--simulation_id']+'/bq_payload.json','w') as f:
    for io in output_payload['monitor_stats']:
      json.dump(io,f)
      f.write('\n')

#END main

if __name__ == '__main__':
  main()
