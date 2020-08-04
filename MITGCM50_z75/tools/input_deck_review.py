#!/usr/bin/python3

import sys
import subprocess
import shlex
import numpy as np
import netCDF4 as nc
import matplotlib.pyplot as plt
import seaborn as sns
import datetime


def loadAtmBinaryFile(filename,nx,ny,nt):

  field = np.fromfile(filename,dtype='>f')

  outField = np.reshape(field,(nx,ny,nt),'F')

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

def plotAtmVelocity(lon,lat,topog,u,v,nlevels,fieldname,plotDir):

  fieldPlotDir = '{}/{}'.format(plotDir,fieldname)
  subprocess.run(shlex.split('mkdir -p {}/{}'.format(plotDir,fieldname))) 

  nt = np.shape(u)[2]
  print(np.shape(u))
  coastLine = np.linspace(-5,0,2)

  for i in range(0,nt):

     date = (datetime.datetime(2003, 1, 1) + datetime.timedelta(i*6/24)).strftime('%d/%m/%Y')

     fig, ax = plt.subplots(constrained_layout=True)
     speed = np.squeeze(np.sqrt( np.square(u[:,:,i]) + np.square(v[:,:,i]) ))
     sns.set_style('ticks')

     CS = plt.contour(lon,lat,topog,coastLine)
     sLev = np.linspace(0,20,nlevels)
     CS2 = ax.contourf(np.transpose(lon),np.transpose(lat),speed,sLev,cmap='Reds')
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

#def plotAtmField(lon,lat,topog,field,minmax,units,nlevels,fieldname,plotDir):
def plotAtmField(lon,lat,topog,field,units,nlevels,fieldname,plotDir):

  fieldPlotDir = '{}/{}'.format(plotDir,fieldname)
  subprocess.run(shlex.split('mkdir -p {}/{}'.format(plotDir,fieldname))) 

  nt = np.shape(field)[2]
  print(np.shape(field))
  coastLine = np.linspace(-5,0,2)

  for i in range(0,nt):

     date = (datetime.datetime(2003, 1, 1) + datetime.timedelta(i*6/24)).strftime('%d/%m/%Y')

     fig, ax = plt.subplots(constrained_layout=True)
     sns.set_style('ticks')

     CS = plt.contour(lon,lat,topog,coastLine)
     #lev = linspace(minmax[0],minmax[1],nlevels]
     #CS2 = ax.contourf(np.transpose(lon),np.transpose(lat),field[:,:,i],lev)
     CS2 = ax.contourf(np.transpose(lon),np.transpose(lat),field[:,:,i],nlevels)

     ax.annotate(date,xy=(0.1,0.9),xycoords='axes fraction',backgroundcolor='white')

     # Colorbar
     cbar = fig.colorbar(CS2)
     cbar.ax.set_ylabel(units)

     sns.despine()
     fig.savefig(fieldPlotDir+'/frame-%04d.png' %(i))
     plt.close(fig)



#END plotAtmField

def plotTopog(lon,lat,topog,nlevels,plotDir):

  fig, ax = plt.subplots(constrained_layout=True)
  sns.set_style('ticks')

  CS = ax.contourf(lon,lat,topog,nlevels,cmap='terrain')

  coastLine = np.linspace(-5,0,2)
  CS2 = plt.contour(lon,lat,topog,coastLine)

  # Colorbar
  cbar = fig.colorbar(CS)
  cbar.ax.set_ylabel('(m)')

  sns.despine()
  fig.savefig(plotDir+'/topog.png')

#END plotTopog

def main():


  daysPerYear = 365
  plotDir = '../plots'
  #atmFiles = ['u10.bin','v10.bin','radsw.bin','r2.bin','q2.bin','radlw.bin','precip.bin']
  atmUV = ['u10_2003.box','v10_2003.box']
  #atmFiles = ['radsw_2003.box','t2_2003.box','q2_2003.box','radlw_2003.box','precip_2003.box']
  atmFiles = ['t2_2003.box','q2_2003.box','radlw_2003.box','precip_2003.box']
#  minmax = [[100 800],[15 30],[],[],[100 800],[]]
#  units = ['(W/m^2)','(C)','(kg/kg)','(W/m^2)','(kg)']
  atmFieldsPerDay = 4
  atmNt = daysPerYear*atmFieldsPerDay
  inputDeckDir = '../input'

  subprocess.run(shlex.split('mkdir -p {}'.format(plotDir)))

  lon, lat, topog = load_bathy_nc_file('../input/gebco_smoothed_topog.nc')
  ny, nx = np.shape(topog)
  print(np.shape(topog))

  plotTopog(lon,lat,topog,50,plotDir)

  u = loadAtmBinaryFile(inputDeckDir+'/'+atmUV[0],nx,ny,atmNt)
  v = loadAtmBinaryFile(inputDeckDir+'/'+atmUV[1],nx,ny,atmNt)
  plotAtmVelocity(lon,lat,topog,u,v,50,'u10',plotDir)
  for f in atmFiles:
    print(f)
    atmField = loadAtmBinaryFile(inputDeckDir+'/'+f,nx,ny,atmNt)

    fieldname = f.split('.')[0]
    plotAtmField(lon,lat,topog,atmField,'(units)',50,fieldname,plotDir)


if __name__ == '__main__':
  main()

