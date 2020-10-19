% DESCRIPTION: 
%
% Generate atmospheric fluxes used to force the 4 differents configurations
% from the DFS4.4 data set
% 
% extracted fields are :
% windx.box, windy.box, solar.box, tair.box, qair.box, longwave.box
% They are made of: 
% tair.box  -> file 't2.nc' (Air temperature at 2m [K], 6-hourly)
% qair.box  -> file 'q2.nc' (Air specific humidity at 2m [Kg/Kg], 6-hourly)
% windx.box -> file 'u10.nc' (Zonal wind component at 10m [m/s], 6-hourly)
% windy.box -> file 'v10.nc' (Meridional wind component at 10m [m/s], 6-hourly)
% solar.box -> file 'radsw.nc' (Downwelling shortwave radiation [W/m^2], daily)   
% longwave.box -> file 'radlw.nc' (DFS4.3: corrected Surface Downwelling Longwave Flux [W/m^2], daily)
%
% radsw and radlw must be interpolated in time 
%
% we also use prescribed precipitation (from DFS5.2). See mk_precip.m


clear all; close all

addpath('/tank/users/qjamet/MatLab/mk_Config/')

%yearStart=1963;
%yearEnd=2012;
yearStart=2003;
yearEnd=2003;

mitgcmGridNCFile = '/tank/topog/gulf-stream/hycom/input/mitgcm_input.nc';
lonVar = 'lon';
latVar = 'lat';

%------------
% Directories
%------------

%- output dir -
%dir_o = '/tank/chaocean/qjamet/Config/Test_cheapAML0.25/data_in/atm_cd/';
%dir_o = '/tank/topog/gulf-stream/hycom/input/';
dir_o='/tank/users/schoonover/topocontrol-gulfstream/MITGCM50_z75/input/';

%- atmospheric data -
dir_atm1 = '/tank/chaocean/atmospheric_data/DFS4.4_NorthAtl/';
dir_atm2= '/tank/chaocean/atmospheric_data/DFS5.2_NorthAtl/';

dfs1 = '_DFS4.4_y';
dfs2 = '_DFS5.2_y';


%------------------
% Specific flags
%------------------

ieee='b';
accuracy='real*4';

flg_cut = 0;
flag_interp = 0; % 1: matlab original interpolation (slower), 0: mygriddata
flag_plot = 0;
flag_save = 1;


%---------------------------
% generate the chaocean grid
%---------------------------
%global xLon yLat mask_mit mask_topo x_cut ybc
%mk_grid(4,0,flg_cut)
% create variables "xLon" and "yLat" for griddata calls below
%xLon  = double(ncread(mitgcmGridNCFile,lonVar));
%yLat  = double(ncread(mitgcmGridNCFile,latVar));
xx  = double(ncread(mitgcmGridNCFile,lonVar));
xx = xx(1,:);
yy  = double(ncread(mitgcmGridNCFile,latVar));
yy = yy(:,1);

[yLat,xLon]=meshgrid(yy,xx);


%-------------
% Set of field 
%-------------
var = {'t2','q2','u10','v10','radlw','radsw','precip'};

%-- loop over variables --
for iiVar = 1:length(var)
disp(['Variable: ' var{iiVar}])
%-- change directory for precip --
if strcmp(var{iiVar},'precip')
  dir_atm = dir_atm2;
  dfs = dfs2;
else
  dir_atm = dir_atm1;
  dfs = dfs1;
end

%-- Get dimension of inputs --
lat_atm = ncread([dir_atm var{iiVar} dfs '1987_chaO.nc'],'lat');
lon_atm = ncread([dir_atm var{iiVar} dfs '1987_chaO.nc'],'lon');
% turn into 'double'
lat_atm = double(lat_atm);
lon_atm = double(lon_atm);

nx_atm = size(lon_atm,1);
ny_atm = size(lat_atm,1);
for nx =1:nx_atm
  if (lon_atm(nx)> 180); lon_atm(nx) = lon_atm(nx) - 360; end
end

[yLat_atm,xLon_atm]=meshgrid(lat_atm,lon_atm);


%-- generate a new interpolant --
t_air = zeros(nx_atm,ny_atm);
if flag_interp == 0
fprintf('Creating new interpolant\n')
[t_aux,tri,wei] = my_griddata1(xLon_atm,yLat_atm,t_air,xLon,yLat,{'QJ'}); %
end  


disp('-------------------------')  
fprintf('Building fully forced atmospheric files \n');
disp('-------------------------')  

%-- Loop over years --
for iiYear = yearStart:yearEnd

fprintf('Year: %i\n', iiYear)

idate = num2str(iiYear);
time_atm = ncread([dir_atm var{iiVar} dfs idate '_chaO.nc'],'time');
[nt_atm] = size(time_atm,1);

[nLon,nLat] = size(yLat);
data_tmp = zeros(nLon,nLat,nt_atm);

%-- loop over time step for interpolation --
for iit=1:nt_atm

  fprintf('Variable: %s ; year: %i ; File number: %i \n',var{iiVar},iiYear,iit);
 
  tmpVar = ncread([dir_atm var{iiVar} dfs idate '_chaO.nc'],var{iiVar},[1 1 iit],[Inf Inf 1]);
  tmpVar = double(tmpVar);
  if strcmp(var{iiVar},'t2')
    tmpVar = tmpVar - 273.16;% convert t2 into degC
  end



  %- interpolation on the new grid -
  % cubic for u and v for cheapaml precip field
  if strcmp(var{iiVar},'u10') | strcmp(var{iiVar},'v10')
    tmpVar_MIT = griddata(yLat_atm,xLon_atm,tmpVar,yLat,xLon,'cubic');
  else  % linear for tair and qair
    if flag_interp
      tmpVar_MIT = griddata(xLon_atm,yLat_atm,tmpVar,xLon,yLat);
    else
      tmpVar_MIT = my_griddata2(xLon_atm,yLat_atm,tmpVar,xLon,yLat,tri,wei);
    end
  end  
  
  %- rearrange on the reshaped grid -
  %if flg_cut
  %  tmpVar_MIT = cut_gulf(tmpVar_MIT,mask_mit,x_cut,2,ybc);
  %end


  data_tmp(:,:,iit) = tmpVar_MIT;


end %iit


%-- the extrapolation for radsw from daily to  6-hr field --
%-- is made as 0 at 6h and 24h and double value at 12h and 18h --
%-- extrapolation for radlw and precip is standard --

if strcmp(var{iiVar},'radsw') | strcmp(var{iiVar},'radlw') | strcmp(var{iiVar},'precip')

  %- check that radLW or radSW are daily fields -
  if nt_atm == 365
    fprintf('Go for time interpolation from daily to 6-hr\n')
  elseif nt_atm == 366	% remove extra day for leap years
    fprintf('Remove extra day for leap year and go for time interpolation from daily to 6-hr\n')
    data_tmp = data_tmp(:,:,1:nt_atm-1);
    nt_atm = nt_atm-1;
  else
    fprintf(['!!!! ' var{iiVar} '(x,y,t)=(%i,%i,%i) !!!!\n'],nLon,nLat,nTime)
    error(['!!!! Not sure about the time dimension of ' var{iiVar} ' !!!!'])
  end

  %- reshape incoming variable -
  data_daily = reshape(data_tmp,[nLon*nLat nt_atm]);
  clear data_tmp;

  %- initialize -
  time_6hr= ncread(['/tank/chaocean/atmospheric_data/DFS4.4_NorthAtl/t2_DFS4.4_y1987_chaO.nc'],'time');
  nTime_6h = length(time_6hr);
  data_6h = zeros(nLon*nLat,nTime_6h);

  %- get days and hours -
  dDay = floor(time_6hr);
  hHour = time_6hr - dDay;

  switch var{iiVar}
    case 'radsw'
      %- data at 12h -
      iiDay = find(hHour == .5);
      data_6h(:,iiDay) = 2.*data_daily(:,:);
      %- data at 18h -
      iiDay = find(hHour == .75);
      data_6h(:,iiDay) = 2.*data_daily(:,:);
    case 'radlw'
      for ij = 1:nLon*nLat
        data_6h(ij,:) = interp1([time_6hr(1:4:nTime_6h); nt_atm+time_6hr(1)],...
            [data_daily(ij,:) data_daily(ij,1)],time_6hr);
      end
    case 'precip'
      for ij = 1:nLon*nLat
        data_6h(ij,:) = interp1([time_6hr(1:4:nTime_6h); nt_atm+time_6hr(1)],...
            [data_daily(ij,:) data_daily(ij,1)],time_6hr);
      end
  end %switch radsw, radlw

  data_tmp = data_6h;
  clear data_6h

end %if radlw, radsw



%- write data -
if flag_save
%    if iiYear == 1958
  fid=fopen([dir_o var{iiVar} '_' num2str(iiYear) '.box'] ,'w',ieee); 
  fwrite(fid,data_tmp,accuracy); fclose(fid);
%    else 
%      fid=fopen([dir_o var{iiVar} '_' num2str(iiYear) '.box'] ,'a',ieee); 
%      fwrite(fid,tmpVar_MIT,accuracy); fclose(fid);
%    end
end

end % iiYear

end % iiVar



