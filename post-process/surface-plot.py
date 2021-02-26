#/usr/bin/python3

import subprocess
import shlex
import glob
import json
from docopt import docopt
from pymitgcm import pymitgcm
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import numpy as np
import seaborn as sns

DOC="""mitgcm-post


Usage:
surface-plot plot [--datadir=<path>] [--deltaTclock=<seconds>] [--iterate=<integer>] [--outdir=<path>]

Commands:
plot            Plot the surface fields.

Options:
-h --help                     Display this help screen
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

  patch_color = (1.0,0.8314,0.5765)
  colors = {'temp':{'min':0,'max':30,'nlev':120},
            'salt':{'min':32,'max':37,'nlev':120},
            'speed':{'min':0,'max':2.5,'nlev':120},
            'ssh':{'min':-1.0,'max':1.0,'nlev':120}}

  cmap = {'temp': ListedColormap(
                    sns.diverging_palette(250, 
                                          30, 
                                          l=65,
                                          n=colors['temp']['nlev'],
                                          center="dark").as_hex()),
          'salt': ListedColormap(
                    sns.diverging_palette(145, 
                                          300, 
                                          l=60,
                                          n=colors['salt']['nlev'],
                                          center="dark").as_hex()),
          'speed': ListedColormap(
                    sns.color_palette("Reds",
                                      n_colors=colors['speed']['nlev']).as_hex()),
          'ssh': ListedColormap(
                    sns.color_palette("vlag",
                                      n_colors=colors['ssh']['nlev']).as_hex())}


  mitgcm = pymitgcm(directory = args['--datadir'],
                    deltaTclock = float(args['--deltaTclock']),
                    iterate = int(args['--iterate']),
                    dateTimeStart = [2003,1,1,0,0,0])

  fig, axs = plt.subplots(2,2,figsize=(20,20))
  # Set the dry values to nan so they show u
  var = np.squeeze(mitgcm.temperature[0,:,:])
  var[mitgcm.hfacc[0,:,:] == 0.0] = np.nan
  var = np.ma.array(var, mask=np.isnan(var))
  # Plot the variable with mask
  im = axs[0,0].contourf(mitgcm.xc, 
                         mitgcm.yc, 
                         var,
                         np.linspace(colors['temp']['min'],
                                     colors['temp']['max'],
                                     colors['temp']['nlev']),
                         cmap=cmap['temp'],extend="both")
  axs[0,0].set_title('Potential Temperature')
  fig.colorbar(im, ax=axs[0,0])
  # Set the dry cell color
  axs[0,0].patch.set_color(patch_color)

  # Set the dry values to nan
  var = np.squeeze(mitgcm.salinity[0,:,:])
  var[mitgcm.hfacc[0,:,:] == 0.0] = np.nan
  var = np.ma.array(var, mask=np.isnan(var))
  # Plot the variable with mask
  im = axs[0,1].contourf(mitgcm.xc, 
                         mitgcm.yc, 
                         var,
                         np.linspace(colors['salt']['min'],
                                     colors['salt']['max'],
                                     colors['salt']['nlev']),
                         cmap=cmap['salt'],extend="both")
  axs[0,1].set_title('Salinity')
  fig.colorbar(im, ax=axs[0,1])
  # Set the dry cell color
  axs[0,1].patch.set_color(patch_color)

  # Set the dry values to nan
  var = np.squeeze(np.sqrt(mitgcm.u[0,:,:]*mitgcm.u[0,:,:] + 
                           mitgcm.v[0,:,:]*mitgcm.v[0,:,:]))
  var[mitgcm.hfacc[0,:,:] == 0.0] = np.nan
  var = np.ma.array(var, mask=np.isnan(var))
  # Plot the variable with mask
  im = axs[1,0].contourf(mitgcm.xc, 
                         mitgcm.yc, 
                         var,
                         np.linspace(colors['speed']['min'],
                                     colors['speed']['max'],
                                     colors['speed']['nlev']),
                         cmap=cmap['speed'],extend="both")
  axs[1,0].set_title('Speed')
  fig.colorbar(im, ax=axs[1,0])
  # Set the dry cell color
  axs[1,0].patch.set_color(patch_color)

  # Set the dry values to nan
  var = np.squeeze(mitgcm.eta) 
  var[mitgcm.hfacc[0,:,:] == 0.0] = np.nan
  var = np.ma.array(var, mask=np.isnan(var))
  # Plot the variable with mask
  im = axs[1,1].contourf(mitgcm.xc, 
                         mitgcm.yc, 
                         var,
                         np.linspace(colors['ssh']['min'],
                                     colors['ssh']['max'],
                                     colors['ssh']['nlev']),
                         cmap=cmap['ssh'],extend="both")
  axs[1,1].set_title('SSH')
  fig.colorbar(im, ax=axs[1,1])
  # Set the dry cell color
  axs[1,1].patch.set_color(patch_color)

  plt.show()

if __name__=='__main__':
  main()

