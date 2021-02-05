#!/usr/bin/python3

from docopt import docopt
from pymitgcm import pymitgcm

DOC="""gen-iterates


Usage:
gen-iterates list [--datadir=<path>] 

Commands:
list     List all iterates available in MITgcm database

Options:
-h --help                     Display this help screen
--datadir=<path>              Path to model output [default: ./]
"""


def parse_cli():

    args = docopt(DOC,version='mitgcm_timeseries 0.0.0')

    return args

def main():

  args = parse_cli()

  mitgcm = pymitgcm(directory = args['--datadir'],loadState=False)
  iterates = mitgcm.getIterateList()
  
  for i in iterates:
    print(i)

if __name__ == '__main__':
  main()
