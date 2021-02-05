#!/usr/bin/python3

from pymitgcm import pymitgcm
import matplotlib.pyplot as plt
from docopt import docopt

DOC="""downscale
A tool for creating initial & boundary conditions from MITgcm data for higher resolution 
downscaling runs.

Usage:
downscale create <datadir> [--outdir=<outdir>] [--iterate=<iterate>] [--south=<lat>] [--north=<lat>] [--west=<lon>] [--east=<lon>] [--refine-factor=<int>]

Commands:
convert            Convert the MITgcm meta-data output to VTK

Options:
-h --help                     Display this help screen
--outdir=<outdir>             Output directory [default: ./]
--iterate=<iterate>           MITgcm iterate number
--south=<lat>                 Southern latitude for new domain
--north=<lat>                 Northern latitude for new domain
--west=<lon>                  Western longitude for new domain (relative to old domain)
--east=<lon>                  Eastern longitude for new domain (relative to old domain)
--refine-factor=<int>         Integer factor to increase the resolution by [default: 2]
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
  downscaled.print_grid_size()
  downscaled.write_state_binary(args['--outdir'])
  downscaled.write_boundary_state_binary(args['--outdir'])

if __name__=='__main__':
  main()

