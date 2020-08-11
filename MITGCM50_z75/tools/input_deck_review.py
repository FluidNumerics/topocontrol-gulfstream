#!/usr/bin/python3

import sys
import subprocess
import shlex
import numpy as np
import netCDF4 as nc
import matplotlib.pyplot as plt
import seaborn as sns
import datetime
from docopt import docopt

DOC="""input_deck_review
A tool for visualizing MITgcm input files.


Usage:
input_deck_review bathymetry <bathyfile> [--outdir=<outdir>] [--cmap=<cmap>] [--nlevels=<nlevels>]
input_deck_review cheapaml-velocity <bathyfile> <ufile> <vfile> <min> <max> <dt_hour> [--outdir=<outdir>] [--cmap=<cmap>] [--nlevels=<nlevels>]
input_deck_review cheapaml-field <bathyfile> <fieldfile> <name> <units> <min> <max> <dt_hour> [--outdir=<outdir>] [--cmap=<cmap>] [--nlevels=<nlevels>]

Commands:
bathymetry            Plot the bathymetry field only.
cheapaml-velocity     Plot the CheapAML velocity field, showing vectors and speed with a coastline from the provided bathymetry file.
cheapaml-field        Plot a scalar CheapAML field with a coastline from the provided bathymetry file.

Options:
-h --help                     Display this help screen
--outdir=<outdir>             Output directory [default: ../plots]
--cmap=<cmap>                 Colormap for plotting [default: Reds]
--nlevels=<nlevels>           Number of distinct levels to use in contourf plots [default: 50]
"""


def loadAtmBinaryFile(filename,nx,ny):

  field = np.fromfile(filename,dtype='>f')

  outField = np.reshape(field,(nx,ny,-1),'F')

  return outField
#END load_atmbinary_file

def load_bathy_nc_file(filename):

    nc_fid = nc.Dataset(filename, 'r')

    lat = nc_fid.variables['latitude'][:]
    lon = nc_fid.variables['longitude'][:]
    topog = nc_fid.variables['topog'][:]
    lon, lat = np.meshgrid(lon,lat)

    return lon, lat, topog

#END load_bathy_nc_file

def plotAtmVelocity(lon,lat,topog,u,v,nlevels,fieldname,dt_hour,cmap,plotDir):

  fieldPlotDir = plotDir

  nt = np.shape(u)[2]
  print(np.shape(u))
  coastLine = np.linspace(-5,0,2)

  for i in range(0,nt):

     date = (datetime.datetime(2003, 1, 1) + datetime.timedelta(i*dt_hour/24)).strftime('%d/%m/%Y')

     fig, ax = plt.subplots(constrained_layout=True)
     speed = np.squeeze(np.sqrt( np.square(u[:,:,i]) + np.square(v[:,:,i]) ))
     sns.set_style('ticks')

     CS = plt.contour(lon,lat,topog,coastLine)
     sLev = np.linspace(0,20,nlevels)
     CS2 = ax.contourf(np.transpose(lon),np.transpose(lat),speed,sLev,cmap=cmap)
     skip = 25
     CS3 = ax.quiver(np.transpose(lon[::skip,::skip]),
                     np.transpose(lat[::skip,::skip]),
                     np.squeeze(u[::skip,::skip,i]),
                     np.squeeze(v[::skip,::skip,i]))

     ax.annotate(date,xy=(0.1,0.9),xycoords='axes fraction',backgroundcolor='white')

     # Colorbar
     cbar = fig.colorbar(CS2)
     cbar.ax.set_ylabel('(m/s)')

     sns.despine()
     fig.savefig(fieldPlotDir+'/frame-%04d.png' %(i))
     plt.close(fig)



#END plotAtmVelocity

def plotAtmField(lon,lat,topog,field,minmax,units,nlevels,fieldname,dt_hour,cmap,plotDir):

  fieldPlotDir = plotDir

  nt = np.shape(field)[2]
  print(np.shape(field))
  coastLine = np.linspace(-5,0,2)

  for i in range(0,nt):

     date = (datetime.datetime(2003, 1, 1) + datetime.timedelta(i*dt_hour/24)).strftime('%d/%m/%Y')

     fig, ax = plt.subplots(constrained_layout=True)
     sns.set_style('ticks')

     CS = plt.contour(lon,lat,topog,coastLine)
     lev = np.linspace(minmax[0],minmax[1],nlevels)
     CS2 = ax.contourf(np.transpose(lon),np.transpose(lat),field[:,:,i],lev,cmap=cmap)

     ax.annotate(date,xy=(0.1,0.9),xycoords='axes fraction',backgroundcolor='white')

     # Colorbar
     cbar = fig.colorbar(CS2)
     cbar.ax.set_ylabel(units)

     sns.despine()
     fig.savefig(fieldPlotDir+'/frame-%04d.png' %(i))
     plt.close(fig)



#END plotAtmField

def plotTopog(lon,lat,topog,nlevels,cmap,plotDir):

  fig, ax = plt.subplots(constrained_layout=True)
  sns.set_style('ticks')
  CS = ax.contourf(lon,lat,topog,nlevels,cmap=cmap)

  coastLine = np.linspace(-5,0,2)
  CS2 = plt.contour(lon,lat,topog,coastLine)

  # Colorbar
  cbar = fig.colorbar(CS)
  cbar.ax.set_ylabel('(m)')

  sns.despine()
  fig.savefig(plotDir+'/topog.png')

#END plotTopog

def parse_cli():

    args = docopt(DOC,version='input_deck_review 0.0.0')

    return args

def main():

  args = parse_cli()

  subprocess.run(shlex.split('mkdir -p {}'.format(args['--outdir'])))

  lon, lat, topog = load_bathy_nc_file(args['<bathyfile>'])
  ny, nx = np.shape(topog)

  if args['bathymetry'] :

      plotTopog(lon,lat,topog,
                int(args['--nlevels']),
                args['--cmap'],
                args['--outdir'])

  elif args['cheapaml-velocity'] :
  
      outDir = '{}/{}'.format(args['--outdir'],'10_meter_wind')
      subprocess.run(shlex.split('mkdir -p {}'.format(outDir)))
      u = loadAtmBinaryFile(args['<ufile>'],nx,ny)
      v = loadAtmBinaryFile(args['<vfile>'],nx,ny)
      plotAtmVelocity(lon,lat,topog,u,v,
                      int(args['--nlevels']),
                      '10 meter wind',
                      int(args['<dt_hour>']),
                      args['--cmap'],
                      outDir)

  elif args['cheapaml-field'] :

      outDir = '{}/{}'.format(args['--outdir'],args['<name>'])
      subprocess.run(shlex.split('mkdir -p {}'.format(outDir)))
      atmField = loadAtmBinaryFile(args['<fieldfile>'],nx,ny,)
      plotAtmField(lon,lat,topog,atmField,
                   [float(args['<min>']),float(args['<max>'])],
                   args['<units>'],int(args['--nlevels']),
                   args['<name>'],int(args['<dt_hour>']),
                   args['--cmap'],outDir)


if __name__ == '__main__':
  main()

