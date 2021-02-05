#/usr/bin/python3

import subprocess
import shlex
import glob
import json
from docopt import docopt
from pymitgcm import pymitgcm

DOC="""mitgcm-post


Usage:
mitgcm-post zbox [--datadir=<path>] [--simulation_id=<simid>] [--simulation_phase=<phase>] [--deltaTclock=<seconds>] [--zsplit=<depth>] [--iterate=<integer>] [--outdir=<path>]
mitgcm-post advf [--datadir=<path>] [--simulation_id=<simid>] [--simulation_phase=<phase>] [--deltaTclock=<seconds>] [--iterate=<integer>] [--outdir=<path>]
mitgcm-post glob [--datadir=<path>] [--simulation_id=<simid>] [--simulation_phase=<phase>] [--deltaTclock=<seconds>] [--iterate=<integer>] [--outdir=<path>]
mitgcm-post vtk [--datadir=<path>] [--iterate=<integer>] [--outdir=<path>]
mitgcm-post mon [--datadir=<path>] [--simulation_id=<simid>] [--simulation_phase=<phase>] [--outdir=<path>]

Commands:
zbox            Create volume averaged time series for upper and lower ocean split at depth --zsplit.
advf            Calculate the max advective frequency ( max(U/dx) )
glob            Calculate global statistics reported by pymitgcm
vtk             Convert model output to vtk
mon             Parse the monitoring statistics

Options:
-h --help                     Display this help screen
--simulation_id=<simid>       An alphanumeric simulation identifier [default: mitgcm-50z75]
--simulation_phase=<simid>    An alphanumeric simulation phase identifier [default: production]
--zsplit=<depth>              Depth to split the ocean for zbox post processing [default: -300.0]
--datadir=<path>              Path to model output [default: ./]
--iterate=<integer>           Iterate number to use for file dependent post processing [default: 0]
--deltaTclock=<seconds>       The conversion factor from iterate to seconds [default: 120]
--outdir=<path>               The path to write output. [default: ./]
"""


def parse_cli():

    args = docopt(DOC,version='mitgcm_timeseries 0.0.0')

    return args

def main():

  args = parse_cli()
  print(args)


  if args['zbox']:
    mitgcm = pymitgcm(directory = args['--datadir'],
                    deltaTclock = float(args['--deltaTclock']),
                    iterate = int(args['--iterate']),
                    dateTimeStart = [2003,1,1,0,0,0])
    zbox = mitgcm.zBoxModel(float(args['--zsplit']))

    payload = {'stats':[]}
    for var in zbox.keys():
      payload['stats'].append({'simulation_id':args['--simulation_id'],
                               'simulation_phase':args['--simulation_phase'],
                               'metric_name':var,
                               'metric_value':zbox[var],
                               'simulation_datetime':mitgcm.dateTime.strftime("%Y/%m/%d %H:%M:%S")})

    outfile = args['--outdir']+'/zbox.%s.json' % str(mitgcm.iterate).zfill(10)
    with open(outfile,'w') as f:
      for io in payload['stats']:
        json.dump(io,f)
        f.write('\n')
 
  elif args['vtk']:
    mitgcm = pymitgcm(directory = args['--datadir'],
                      deltaTclock = float(args['--deltaTclock']),
                      iterate = int(args['--iterate']),
                      dateTimeStart = [2003,1,1,0,0,0])

    mitgcm.writeToVTK(args['--outdir']+'/vtk')

  elif args['mon']:
    mitgcm = pymitgcm(dateTimeStart = [2003,1,1,0,0,0],
                      directory = args['--datadir'],loadState=False,loadGrid=False)
    payload = mitgcm.monstats()
    with open(args['--outdir']+'/mon_stats.json','w') as f:
      for io in payload['monitor_stats']:
        pl = {'simulation_id':args['--simulation_id'],
              'simulation_phase':args['--simulation_phase'],
              'simulation_datetime': io['simulation_datetime'].strftime("%Y/%m/%d %H:%M:%S"),
              'metric_name':io['metric_name'],
              'metric_value':io['metric_value']}
        json.dump(pl,f)
        f.write('\n')

if __name__=='__main__':
  main()
