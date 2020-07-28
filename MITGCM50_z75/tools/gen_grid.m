
%the path to where all of the hycom data is installed
hycomDataRoot='/tank/topog/gulf-stream/hycom/';

% Set the path to where output will be written
outputDir='/tank/users/schoonover/topocontrol-gulfstream/MITGCM50_z75/input/';


mitgcmGridNCFile = '/tank/topog/gulf-stream/hycom/input/mitgcm_input.nc';
lonVar = 'lon';
latVar = 'lat';

%% Vertical Grid
% Vertical grid cell centers
zc = [0.51 1.56 2.67 3.86 5.14 6.54 8.09 9.82 11.77 13.99 16.53 19.43 22.76 26.56 30.87 35.74 41.18 47.21 53.85 61.11 69.02 77.61 86.93 97.04 108.03 120.00 133.08 147.41 163.16 180.55 199.79 221.14 244.89 271.36 300.89 333.86 370.69 411.79 457.63 508.64 565.29 628.03 697.26 773.37 856.68 947.45 1045.85 1151.99 1265.86 1387.38 1516.36 1652.57 1795.67 1945.30 2101.03 2262.42 2429.03 2600.38 2776.04 2955.57 3138.56 3324.64 3513.45 3704.66 3897.98 4093.16 4289.95 4488.15 4687.58 4888.07 5089.48 5291.68 5494.58 5698.06 5902.06];

% Vertical grid cell faces
nz = size(zc,2);
zf = zeros(nz+1,1);
for i = 1:nz-1
  zf(i+1) = (zc(i) + zc(i+1) )/2.0;
end
zf(nz+1) = zf(nz) + ( zc(nz) - zc(nz-1) ); 

% Calculate dz as the distance between cell faces (vertically)
dz = diff(zf);
fileID = fopen(strcat(outputDir,'dz.bin'),'w');
fwrite(fileID,dz,'single','ieee-be');
fclose(fileID);


%% Lateral Grid
xLon  = double(ncread(mitgcmGridNCFile,lonVar));
yLat  = double(ncread(mitgcmGridNCFile,latVar));

xLon = squeeze(xLon(1,:));
yLat = squeeze(yLat(:,1));
fprintf('ygOrigin = %f\n',min(yLat))

nx = size(xLon,2);
dx = zeros(nx,1);
dx(1:nx-1) = diff(xLon);
% Assume that dx varies linearly with longitude and prolong the last value by linear interpolation
dx(nx) = 2.0*dx(nx-1) - dx(nx-2);
fileID = fopen(strcat(outputDir,'dx.bin'),'w');
fwrite(fileID,dx,'single','ieee-be');
fclose(fileID);

ny = size(yLat,1);
dy = zeros(ny,1);
dy(1:ny-1) = diff(yLat);
% Assume that dy varies linearly with latitude and prolong the last value by linear interpolation
dy(ny) = 2.0*dy(ny-1) - dy(ny-2);
fileID = fopen(strcat(outputDir,'dy.bin'),'w');
fwrite(fileID,dy,'single','ieee-be');
fclose(fileID);







