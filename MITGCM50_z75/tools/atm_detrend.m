

outputDir='/tank/users/schoonover/topocontrol-gulfstream/MITGCM50_z75/input/';
mitgcmGridNCFile = '/tank/topog/gulf-stream/hycom/input/mitgcm_input.nc';
lonVar = 'lon';
latVar = 'lat';

daysPerYear=365;
fieldsPerDay=4;
nTimeLevels = daysPerYear*fieldsPerDay;

atmFiles = ["../input/precip_2003.box", "../input/q2_2003.box", "../input/radlw_2003.box", "../input/radsw_2003.box", "../input/t2_2003.box", "../input/u10_2003.box", "../input/v10_2003.box"]; 
atmNames = ["precip", "q2", "radlw", "radsw", "t2", "u10", "v10"];

xLon  = double(ncread(mitgcmGridNCFile,lonVar));
yLat  = double(ncread(mitgcmGridNCFile,latVar));

shape = [size(xLon,1), size(xLon,2), nTimeLevels]

for k = 2:length(atmFiles)

  fprintf('Reading %s \n',atmFiles(k))
  fileID = fopen(atmFiles(k),'r');
  var = fread(fileID,'single','ieee-be');
  var = reshape(var, shape);
  fclose(fileID);

  
  fprintf('Detrending data \n')
  % Loop over lat, lon and detrend over time
  for j = 1:size(var,2)
    for i = 1:size(var,1)
      var(i,j,:) = detrend(squeeze(var(i,j,:)),1);
    end
  end

  % Write new binary file
  fileID = fopen(strcat(outputDir,atmNames(k),'.bin'),'w');
  fwrite(fileID,var,'single','ieee-be');
  fclose(fileID);

end
