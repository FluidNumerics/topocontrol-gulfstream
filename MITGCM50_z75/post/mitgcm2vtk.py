#!/usr/bin/python3

import subprocess
import shlex
import glob
import numpy as np
import scipy.interpolate as interp
import MITgcmutils as mitgcm
from docopt import docopt
from pyevtk.hl import gridToVTK, pointsToVTK

DOC="""mitgcm2vtk
A tool for converting MITgcm meta-data output to VTK


Usage:
mitgcm2vtk convert <datadir> [--outdir=<outdir>]

Commands:
convert            Convert the MITgcm meta-data output to VTK

Options:
-h --help                     Display this help screen
--outdir=<outdir>             Output directory [default: ./vtk]
"""

fillValue=1000.0

def loadMITgcmField(prefix, field, iterate=0):

  mitFile = prefix+'/'+field
  print('Loading %s'%mitFile)
  
  if field in ['Depth','XC','YC','XG','YG','RC','RF','hFacC']:
    #meta = mitgcm.mds.parsemeta(prefix+'/'+field)
    data = mitgcm.mds.rdmds(prefix+'/'+field)

  else:
    #meta = mitgcm.mds.parsemeta(prefix+'/'+field)
    data = mitgcm.mds.rdmds(prefix+'/'+field, iterate)
  
  #return {'meta': {}, 'data': data}
  return data

#END loadMITgcmField

def parse_cli():

    args = docopt(DOC,version='mitgcm2vtk 0.0.0')

    return args

def main():

  args = parse_cli()

  subprocess.run(shlex.split('mkdir -p {}'.format(args['--outdir'])))

  xc = loadMITgcmField(args['<datadir>'],'XC')
  yc = loadMITgcmField(args['<datadir>'],'YC')
  xg = loadMITgcmField(args['<datadir>'],'XG')
  yg = loadMITgcmField(args['<datadir>'],'YG')
  rc = loadMITgcmField(args['<datadir>'],'RC')
  rf = loadMITgcmField(args['<datadir>'],'RF')
  hFacC = loadMITgcmField(args['<datadir>'],'hFacC')
  topog = loadMITgcmField(args['<datadir>'],'Depth')

  ny, nx = np.shape(topog)
  nz = np.shape(rc)[0]

  ncells = nx*ny*nz
  npoints = (nx+1)*(ny+1)*(nz+1) 

  x = np.zeros((nx + 1))
  y = np.zeros((ny + 1))
  z = np.zeros((nz + 1))

  # Append the east-most xg point xg
  for i in range(nx):
    x[i] = xg[0,i]
  x[nx] = xg[0,nx-1] + xg[0,nx-1] - xg[0,nx-2] 

  for j in range(ny):
    y[j] = yg[j,0]
  y[ny] = yg[ny-1,0] + yg[ny-1,0] - yg[ny-2,0] 

  for k in range(nz+1):
    z[k] = rf[k]/1000.0

  # Create the topographic mask vtk output
  wetdryMask = np.transpose(hFacC, (2, 1, 0))
  wetdryMask[wetdryMask<1.0] = 0.0

  gridToVTK(args['--outdir']+"/mask",x,y,z, cellData = {"wetdry_mask": wetdryMask})

  sFiles = glob.glob(args['<datadir>']+'/S.*.data')

  for s in sFiles:
    iterate = int(s.split('.')[1])

    temperature = np.transpose(loadMITgcmField(args['<datadir>'],'T',iterate),(2,1,0))
    salinity = np.transpose(loadMITgcmField(args['<datadir>'],'S',iterate),(2,1,0))
    u = np.transpose(loadMITgcmField(args['<datadir>'],'U',iterate),(2,1,0))
    v = np.transpose(loadMITgcmField(args['<datadir>'],'V',iterate),(2,1,0))
    w = np.transpose(loadMITgcmField(args['<datadir>'],'W',iterate),(2,1,0))
    eta = np.transpose(loadMITgcmField(args['<datadir>'],'Eta',iterate),(1,0))

    temperature[wetdryMask==0.0] = fillValue
    salinity[wetdryMask==0.0] = fillValue
    u[wetdryMask==0.0] = fillValue
    v[wetdryMask==0.0] = fillValue
    w[wetdryMask==0.0] = fillValue
    eta[wetdryMask[:,:,0]==0.0] = fillValue
    eta = eta[:,:,np.newaxis]

    vtkFile = 'state.%s'%s.split('.')[1]
    gridToVTK(args['--outdir']+"/"+vtkFile,x,y,z, cellData = {"temperature": temperature,
                                                              "salinity": salinity,
                                                              "u": u,
                                                              "v": v,
                                                              "w": w})

    vtkFile = 'eta.%s'%s.split('.')[1]
    gridToVTK(args['--outdir']+"/"+vtkFile,x,y,z[0:1],cellData = {"eta":eta})

 # Load u and v and place on (xc,yc) grid
  #yc = loadMITgcmField(args['<datadir>'],'YC')


if __name__=='__main__':
  main()
