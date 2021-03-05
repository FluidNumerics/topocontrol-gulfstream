#!/usr/bin/python3

from pymitgcm import pymitgcm
import matplotlib.pyplot as plt
from docopt import docopt

DOC="""downscale
A tool for creating initial & boundary conditions from MITgcm data for higher resolution 
downscaling runs.

Usage:
downscale init <datadir> [--outdir=<outdir>] [--iterate=<iterate>] [--south=<lat>] [--north=<lat>] [--west=<lon>] [--east=<lon>] [--refine-factor=<int>]
downscale boundary <datadir> [--outdir=<outdir>] [--iterate=<iterate>] [--south=<lat>] [--north=<lat>] [--west=<lon>] [--east=<lon>] [--refine-factor=<int>]
downscale atmosphere <datadir> [--outdir=<outdir>] [--iterate=<iterate>] [--south=<lat>] [--north=<lat>] [--west=<lon>] [--east=<lon>] [--refine-factor=<int>] [--cheapaml-file=<cheapfile>]

Commands:
init            Create refined initial condition data
boundary        Create refined boundary condition data

Options:
-h --help                     Display this help screen
--outdir=<outdir>             Output directory [default: ./]
--iterate=<iterate>           MITgcm iterate number
--south=<lat>                 Southern latitude for new domain
--north=<lat>                 Northern latitude for new domain
--west=<lon>                  Western longitude for new domain (relative to old domain)
--east=<lon>                  Eastern longitude for new domain (relative to old domain)
--refine-factor=<int>         Integer factor to increase the resolution by [default: 2]
--cheapaml-file=<cheapfile>   Path to a cheapaml file stored on the same grid as the model data in <datadir>.
"""


def parse_cli():

    args = docopt(DOC,version='downscale 0.0.0')
    return args

#END parse_cli

def main():

  args = parse_cli()


  mitgcm = pymitgcm(directory = args['<datadir>'],
                    iterate = int(args['--iterate']),
                    loadGrid = True)
  refined = mitgcm.refine(factor=int(args['--refine-factor']))
  downscaled = refined.subsample( south = float(args['--south']),
                                  north = float(args['--north']),
                                  west = float(args['--west']),
                                  east = float(args['--east']) )
  print('.. Downscaled Grid Size ..')
  downscaled.print_grid_size()
  if args['init'] :
    downscaled.write_state_binary(args['--outdir'])

  elif args['boundary']:
    downscaled.write_boundary_state_binary(args['--outdir'])

  # Get downscaled field statistics
  downscaled.print_field_statistics()


#END main

if __name__=='__main__':
  main()

