#!/usr/bin/python3

import json
import scipy.interpolate as interp
import scipy.ndimage.filters as filters
import scipy.ndimage as ndimage
import numpy as np
import matplotlib.pyplot as plt
import netCDF4 as nc
import subprocess
import shlex
import struct
import sys
from docopt import docopt

DOC="""bathymetry-prep.py

Usage: 
  bathymetry-prep.py <input>

Commands:

Options:
  -h --help            Display this help screen
"""

def parse_cli():

    args = docopt(DOC,version='bathymetry-prep.py 0.0.0')
    return args

#END parse_cli

def load_config(args):

    with open(args['<input>']) as json_file:
        config = json.load(json_file)

    return config;

#END load_config

def load_box_files(box_config):

    f = open(box_config['topog_file'],'rb')
    topog = np.fromfile(f, '>f4')
    topog.shape = (box_config['shape'][1],box_config['shape'][0])
    f.close()

    f = open(box_config['lat_file'],'rb')
    lat = np.fromfile(f, '>f4')
    lat.shape = (box_config['shape'][1],1)
    f.close()

    f = open(box_config['lon_file'],'rb')
    lon = np.fromfile(f, '>f4')
    lon.shape = (box_config['shape'][0],1)
    f.close()

    return lon, lat, topog

#END load_box_files

def load_target_grid_nc_file(nc_config):

    nc_fid = nc.Dataset(nc_config['file'], 'r')

    lat = np.squeeze(nc_fid.variables[nc_config['lat_var']][0,:])
    lon = np.squeeze(nc_fid.variables[nc_config['lon_var']][:,0])

    if nc_config['lon_units'] == 'neg_deg_east':
        print('  Shifting longitude to pos_deg_east units')
        lon = lon + 360.0;

    return lon, lat

#END load_target_grid_nc_file

def load_nc_files(nc_config):

    nc_fid = nc.Dataset(nc_config['file'], 'r')

    lat = nc_fid.variables[nc_config['lat_var']][:]
    lon = nc_fid.variables[nc_config['lon_var']][:]
    topog = nc_fid.variables[nc_config['topog_var']][:]

    if nc_config['lon_units'] == 'neg_deg_east':
        print('  Shifting longitude to pos_deg_east units')
        lon = lon + 360.0;


    if nc_config['swap_dimensions']:
        current_shape = topog.shape
        print(current_shape)
        new_topog = np.zeros((current_shape[1], current_shape[0]))

        for j in range(current_shape[1]):
            for i in range(current_shape[0]):
                new_topog[j][i] = topog[i][j]

        topog = new_topog

    return lon, lat, topog

#END load_nc_files

def generate_target_grid(config):

    if 'netcdf' in config['target_grid']:
        
        x, y = load_target_grid_nc_file(config['target_grid']['netcdf'])

    elif 'bin' in config['target_grid']:


        f = open(config['target_grid']['bin']['lat_file'],'rb')
        y = np.fromfile(f,dtype='float32')
        y.byteswap()
        y.shape = (config['target_grid']['bin']['ny'],config['target_grid']['bin']['nx'])
        f.close()

        f = open(config['target_grid']['bin']['lon_file'],'rb')
        x = np.fromfile(f,dtype='float32')
        x.byteswap()
        x.shape = (config['target_grid']['bin']['ny'],config['target_grid']['bin']['nx'])
        f.close()

        x = np.squeeze(x[0,:])
        y = np.squeeze(y[:,0])
        print(x)

        x[:] += float(config['target_grid']['bin']['x_offset'])

    else:
        x = np.arange(config['target_grid']['lon_range'][0],
                      config['target_grid']['lon_range'][1],
                      config['target_grid']['lon_resolution'])

        y = np.arange(config['target_grid']['lat_range'][0],
                      config['target_grid']['lat_range'][1],
                      config['target_grid']['lat_resolution'])

    return x, y

#END generate_target_grid

def load_bathy(config):

    bathy_cache = []
    for bathymetry in config['bathymetry']:

        if bathymetry['io_type'] == 'box':
            print('Bathymetry IO Type : {}'.format(bathymetry['io_type']))
            x, y, topog = load_box_files(bathymetry['box_config'])
            bathy_cache.append({'x':x,'y':y,'topog':topog,
                                'interp_kind':bathymetry['interp_kind'],
                                'output':bathymetry['output'],
                                'smoothing': bathymetry['smoothing']})
            print('  Bathymetry Dataset : {}'.format(bathymetry['name']))
            print('  Longitude shape : {}'.format(x.shape))
            print('  Latitude shape : {}'.format(y.shape))
            print('  Topog shape : {}'.format(topog.shape))
            

        elif bathymetry['io_type'] == 'netcdf':
            print('Bathymetry IO Type : {}'.format(bathymetry['io_type']))
            x, y, topog = load_nc_files(bathymetry['nc_config'])
            bathy_cache.append({'x':x,'y':y,'topog':topog,
                                'interp_kind':bathymetry['interp_kind'],
                                'output':bathymetry['output'],
                                'smoothing': bathymetry['smoothing']})
            print('  Bathymetry Dataset : {}'.format(bathymetry['name']))
            print('  Longitude shape : {}'.format(x.shape))
            print('  Latitude shape : {}'.format(y.shape))
            print('  Topog shape : {}'.format(topog.shape))

        else:
            print('Unknown Bathymetry IO Type {}. Skipping'.format(bathymetry['io_type']))

    return bathy_cache

#END load_bathy

def smooth_bathy(bathy):

    bathy_cache = []
    for b in bathy:

        if b['smoothing']['active']:

            sigma = b['smoothing']['sigma']
            topog = filters.gaussian_filter(b['topog'], sigma, mode='constant')

            bathy_cache.append({'x':b['x'],'y':b['y'],'topog':topog,
                                'interp_kind':b['interp_kind'],
                                'output':b['output'],
                                'smoothing': b['smoothing']})

        else:
            bathy_cache.append(b)

    return bathy_cache

#end smooth_bathy

def interpolate_bathy(bathy, newx, newy, config):

    interp_cache = []
    k=0
    for b in bathy:
        min_depth=config['bathymetry'][k]['paving']['min_depth']
        f = interp.interp2d( b['x'], b['y'], b['topog'], kind=b['interp_kind'] )
        topog = f(newx, newy)
        topog = np.where(topog>min_depth, 0, topog)

        # fill in "lakes" in bathymetry
        mask = topog
        mask = np.where(mask<0, 1, mask).astype(int)
        # Invert the mask so that "lakes" have binary value of 0
        mask = 1.0-mask
        filled = ndimage.binary_fill_holes(mask).astype(int)
        # Reset the mask so that land has value of 0
        mask = 1.0-filled
        topog = np.multiply(topog,mask.astype(float))
      
        interp_cache.append({'x':newx,'y':newy,'topog':topog,
                             'interp_kind':b['interp_kind'],
                             'output': b['output']})
        k+=1

    return interp_cache

#END interpolate_bathy

def write_for_netcdf(config, bathy):

    for b in bathy:

        nlon = b['x'].size
        nlat = b['y'].size
        ncf = config['output_directory']+'/'+b['output']+'.nc'
        rootgrp = nc.Dataset(ncf,'w',format="NETCDF4")
        lon = rootgrp.createDimension('lon',nlon)
        lat = rootgrp.createDimension('lat',nlat)
        longitude = rootgrp.createVariable('longitude','f4',('lon',))
        latitude = rootgrp.createVariable('latitude','f4',('lat',))
        topog = rootgrp.createVariable('topog','f4',('lat','lon',))
        topog.units = 'm'

        longitude[:] = b['x']
        latitude[:] = b['y']
        topog[:,:] = b['topog']
        
        rootgrp.close()

def write_for_mitgcm(config, bathy):

    for b in bathy:
        temp = b['topog']
        data = temp.flatten().data
        bytedata = struct.pack('>'+'f'*len(data), *data)
        with open(config['output_directory']+'/'+b['output']+".bin","wb") as f:
            f.write(bytedata)

#END write_for_mitgcm

def write_for_obj(config, bathy):

  for b in bathy:
    nlon = b['x'].size
    nlat = b['y'].size
    with open(config['output_directory']+'/'+b['output']+".obj","w") as f:
      
      for j in range(nlat-1):
        for i in range(nlon-1):
           f.write('v %f %f %f\n'%(b['x'][i], b['y'][j], b['topog'][j][i]))
           f.write('v %f %f %f\n'%(b['x'][i+1], b['y'][j], b['topog'][j][i+1]))
           f.write('v %f %f %f\n'%(b['x'][i+1], b['y'][j+1], b['topog'][j+1][i+1]))
           f.write('v %f %f %f\n'%(b['x'][i], b['y'][j+1], b['topog'][j+1][i]))

      k = 1
      for j in range(nlat-1):
        for i in range(nlon-1):
           f.write('f %d %d %d %d\n'%(k, k+1, k+2, k+3))
           k+=4


#END write_for_obj


def main():

    args = parse_cli()

    config = load_config(args)
    print(json.dumps(config,sort_keys=True,indent=2))

    newx, newy = generate_target_grid(config)

    bathy = load_bathy(config)

    bathy = smooth_bathy(bathy)

    interp_bathy = interpolate_bathy(bathy, newx, newy, config)

    subprocess.call(shlex.split('mkdir -p {}'.format(config['output_directory'])))

    write_for_netcdf(config, interp_bathy)

    write_for_mitgcm(config, interp_bathy)


#END main

if __name__ == '__main__' :
    main()

