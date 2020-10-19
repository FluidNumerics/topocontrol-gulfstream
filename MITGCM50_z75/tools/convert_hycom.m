addpath('./Inpaint_nans')
%the path to where all of the hycom data is installed
hycomDataRoot='/tank/topog/gulf-stream/hycom/';

% Set the path to where output will be written
outputDir='/tank/users/schoonover/topocontrol-gulfstream/MITGCM50_z75/input/';

daysPerYear = 365;

%
inpaintMethod = 5;

% Number of parallel workers
nWorkers = 12;

% Vertical interpolation method
vInterpMethod  = 'linear';

% Layer thickness tolerance - Any layers with thickness less than this value from HYCOM will be hard-set to exactly 0.
htol = 1.0e-3;

% Initial conditions
fprintf('Load HYCOM initial conditions \n')
load(strcat(hycomDataRoot,'uvhtseta_WNA_ATLb02_0017_001_12.mat'))
%
% Clean out large velocity values -- not sure why abs(u) ~ O(100 m/s) in the HYCOM data
% We set them to NaN and let inpainting fill in these values.
uu( abs(uu) > max(max(uu(:,:,1))) ) = NaN;
vv( abs(vv) > max(max(vv(:,:,1))) ) = NaN;

fprintf('Inpaint HYCOM initial conditions \n')
pool = parpool(nWorkers);
parfor (k = 1:size(tt,3), nWorkers)
  %fprintf('Inpaint HYCOM Initial Condition : Vertical Level : %d \n',k)

  % Temperature
  var = tt(:,:,k);
  tt(:,:,k) = inpaint_nans(var,inpaintMethod);  

  % Salinity
  var = ss(:,:,k);
  ss(:,:,k) = inpaint_nans(var,inpaintMethod);  

  % Zonal velocity
  var = uu(:,:,k);
  uu(:,:,k) = inpaint_nans(var,inpaintMethod);  

  % Meridional Velocity
  var = vv(:,:,k);
  vv(:,:,k) = inpaint_nans(var,inpaintMethod);  

end


% At each lat-lon we need to interpolate to the DRAKKAR vertical grid.
% On input, the fields are 997x1281x32. To make a grid that is easy to decompose,
% we will trim off the east and north most grid cells to give 996x1280 grid cells,
% incurring an O(dx) error on the boundary conditions


% Vertical grid from section 2.3 of https://www.drakkar-ocean.eu/publications/reports/orca025-grd100-report-dussin
zt = [0.51 1.56 2.67 3.86 5.14 6.54 8.09 9.82 11.77 13.99 16.53 19.43 22.76 26.56 30.87 35.74 41.18 47.21 53.85 61.11 69.02 77.61 86.93 97.04 108.03 120.00 133.08 147.41 163.16 180.55 199.79 221.14 244.89 271.36 300.89 333.86 370.69 411.79 457.63 508.64 565.29 628.03 697.26 773.37 856.68 947.45 1045.85 1151.99 1265.86 1387.38 1516.36 1652.57 1795.67 1945.30 2101.03 2262.42 2429.03 2600.38 2776.04 2955.57 3138.56 3324.64 3513.45 3704.66 3897.98 4093.16 4289.95 4488.15 4687.58 4888.07 5089.48 5291.68 5494.58 5698.06 5902.06];


uinit = zeros(1280,996,75);
vinit = zeros(1280,996,75);
tinit = zeros(1280,996,75);
sinit = zeros(1280,996,75);

% For each latitude, longitude, we interpolate from the the HYCOM layered grid to the DRAKKAR 75 layer vertical grid with extrapolation. For extrapolation we prolong the last value in each given fields vertical profile. Additionally, for any cells on the DRAKKAR grid shallower than the first HYCOM layer center, we prolong the first layer value to the surface. Any location within land is indicated by the layer thickness (hh) set to NaN. For these location, we set the initial conditions to NaN as well and use inpaint_nans to clean up afterwards.

fprintf('Regirid HYCOM initial conditions to target vertical grid \n')
parfor (j = 1:1280, nWorkers)
  for i = 1:996

    % Layer thickness
    h = squeeze(hh(i,j,:));
    if ~isnan(h(1)) 

      % find the last nonzero layer thickness
      h( h < htol ) = 0;
      kmax = find(h,1,'last');
      th = h(1:kmax);
      
      % Obtain the hycom layer mid-depths
      zh = cumsum(th)-0.5*th;

      % Temperature
      var = squeeze(tt(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      tinit(j,i,:) = out;

      % Salinity
      var = squeeze(ss(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      sinit(j,i,:) = out;

      % Zonal Velocity
      var = squeeze(uu(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      uinit(j,i,:) = out;

      % Meridional Velocity
      var = squeeze(vv(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      vinit(j,i,:) = out;

    else

      % Set these values, where layer thickness is nonexistent to NaN for inpainting
      tinit(j,i,:) = NaN;
      sinit(j,i,:) = NaN;
      uinit(j,i,:) = NaN;
      vinit(j,i,:) = NaN;

    end

  end
end

% Inpaint the initial conditions where needed
fprintf('Inpaint regridded HYCOM initial conditions on target grid \n')
parfor (k = 1:size(tinit,3), nWorkers)

  % Temperature
  var = tinit(:,:,k);
  tinit(:,:,k) = inpaint_nans(var,inpaintMethod);  

  % Salinity
  var = sinit(:,:,k);
  sinit(:,:,k) = inpaint_nans(var,inpaintMethod);  

  % Zonal velocity
  var = uinit(:,:,k);
  uinit(:,:,k) = inpaint_nans(var,inpaintMethod);  

  % Meridional Velocity
  var = vinit(:,:,k);
  vinit(:,:,k) = inpaint_nans(var,inpaintMethod);  

end


fprintf('Write initial conditions to file \n')
% Free surface height
var = ssh;
ssh = inpaint_nans(var,inpaintMethod);

ssh = transpose(ssh(1:996,1:1280));

% Write initial conditions to single precision big-endian binary files
fileID = fopen(strcat(outputDir,'t.init.bin'),'w');
fwrite(fileID,tinit,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'s.init.bin'),'w');
fwrite(fileID,sinit,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'u.init.bin'),'w');
fwrite(fileID,uinit,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'v.init.bin'),'w');
fwrite(fileID,vinit,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'eta.init.bin'),'w');
fwrite(fileID,ssh,'single','ieee-be');
fclose(fileID);

fprintf(' ------- Initial Conditions Stats -------- \n')
fprintf('  Min(T)   : %.2f (C)\n', min(min(min(tinit))) )
fprintf('  Max(T)   : %.2f (C)\n', max(max(max(tinit))) )
fprintf('  Min(S)   : %.2f (PSU)\n', min(min(min(sinit))) )
fprintf('  Max(S)   : %.2f (PSU)\n', max(max(max(sinit))) )
fprintf('  Min(U)   : %.2f (m/s)\n', min(min(min(uinit))) )
fprintf('  Max(U)   : %.2f (m/s)\n', max(max(max(uinit))) )
fprintf('  Min(V)   : %.2f (m/s)\n', min(min(min(vinit))) )
fprintf('  Max(V)   : %.2f (m/s)\n', max(max(max(vinit))) )
fprintf('  Min(Eta) : %.2f (m)\n', min(min(ssh)) )
fprintf('  Max(Eta) : %.2f (m)\n', max(max(ssh)) )
fprintf(' \n')
fprintf(' > Gradients \n')
fprintf('  Max(|dU|){i}   : %.2f (m/s)\n', max(max(max(abs(diff(uinit,1,1))))) )
fprintf('  Max(|dU|){j}   : %.2f (m/s)\n', max(max(max(abs(diff(uinit,1,2))))) )
fprintf('  Max(|dV|){i}   : %.2f (m/s)\n', max(max(max(abs(diff(vinit,1,1))))) )
fprintf('  Max(|dV|){j}   : %.2f (m/s)\n', max(max(max(abs(diff(vinit,1,2))))) )
fprintf(' ----------------------------------------- \n')


%% Boundary conditions
boundaryFiles = ["uvhtseta_WNA3secs_ATLb02_017a.mat","uvhtseta_WNA3secs_ATLb02_017b.mat","uvhtseta_WNA3secs_ATLb02_017c.mat","uvhtseta_WNA3secs_ATLb02_017d.mat","uvhtseta_WNA3secs_ATLb02_017e.mat","uvhtseta_WNA3secs_ATLb02_017f.mat","uvhtseta_WNA3secs_ATLb02_017g.mat","uvhtseta_WNA3secs_ATLb02_017h.mat","uvhtseta_WNA3secs_ATLb02_017i.mat","uvhtseta_WNA3secs_ATLb02_017j.mat","uvhtseta_WNA3secs_ATLb02_017k.mat","uvhtseta_WNA3secs_ATLb02_017l.mat","uvhtseta_WNA3secs_ATLb02_018a.mat","uvhtseta_WNA3secs_ATLb02_018b.mat","uvhtseta_WNA3secs_ATLb02_018c.mat","uvhtseta_WNA3secs_ATLb02_018d.mat","uvhtseta_WNA3secs_ATLb02_018e.mat","uvhtseta_WNA3secs_ATLb02_018f.mat","uvhtseta_WNA3secs_ATLb02_018g.mat","uvhtseta_WNA3secs_ATLb02_018h.mat","uvhtseta_WNA3secs_ATLb02_018i.mat","uvhtseta_WNA3secs_ATLb02_018j.mat","uvhtseta_WNA3secs_ATLb02_018k.mat","uvhtseta_WNA3secs_ATLb02_018l.mat","uvhtseta_WNA3secs_ATLb02_019a.mat","uvhtseta_WNA3secs_ATLb02_019b.mat","uvhtseta_WNA3secs_ATLb02_019c.mat","uvhtseta_WNA3secs_ATLb02_019d.mat","uvhtseta_WNA3secs_ATLb02_019e.mat","uvhtseta_WNA3secs_ATLb02_019f.mat","uvhtseta_WNA3secs_ATLb02_019g.mat","uvhtseta_WNA3secs_ATLb02_019h.mat","uvhtseta_WNA3secs_ATLb02_019i.mat","uvhtseta_WNA3secs_ATLb02_019j.mat","uvhtseta_WNA3secs_ATLb02_019k.mat","uvhtseta_WNA3secs_ATLb02_019l.mat"];

% variables (no western boundary conditions)
% h_*
% s_*
% ssh_*
% t_*
% u_*
% v_*
% 
% * can be e | n | s
% Dimensions are (time,lon | lat, layer)
%
% Output is daily - every 12 files corresponds to a year
%
% We want to ensemble average over years and detrend to create 1 year cyclic forcing


fprintf('Ensemble average boundary condition files \n')
k = 1;
days = zeros(1,12);
for year = 1:3
  for month = 1:12
    %fprintf('Boundary Condition Prep: Year, Month : %d, %d \n',year, month)

    load(strcat(hycomDataRoot,boundaryFiles(k)));
    if year == 1 && month == 1
      days(month) = size(h_e,1);
      H_e = h_e/3.0;
      H_n = h_n/3.0;
      H_s = h_s/3.0;

      S_e = s_e/3.0;
      S_n = s_n/3.0;
      S_s = s_s/3.0;

      T_e = t_e/3.0;
      T_n = t_n/3.0;
      T_s = t_s/3.0;

      U_e = u_e/3.0;
      U_n = u_n/3.0;
      U_s = u_s/3.0;

      V_e = v_e/3.0;
      V_n = v_n/3.0;
      V_s = v_s/3.0;

      SSH_e = ssh_e/3.0;
      SSH_n = ssh_n/3.0;
      SSH_s = ssh_s/3.0;

    elseif year > 1 % Average over the corresponding months

      if k == 13
        % Calculate the day number for the last day for each month
        d2 = zeros(1,12);
        d2 = cumsum(days);
        % Calculate the day number for the first day for each month
        d1 = ones(1,12);
        d1(2:12) = d1(2:12)+d2(1:11);
      end
      H_e(d1(month):d2(month),:,:) = H_e(d1(month):d2(month),:,:)+h_e/3.0;
      H_n(d1(month):d2(month),:,:) = H_n(d1(month):d2(month),:,:)+h_n/3.0;
      H_s(d1(month):d2(month),:,:) = H_s(d1(month):d2(month),:,:)+h_s/3.0;
                                                     
      S_e(d1(month):d2(month),:,:) = S_e(d1(month):d2(month),:,:)+s_e/3.0;
      S_n(d1(month):d2(month),:,:) = S_n(d1(month):d2(month),:,:)+s_n/3.0;
      S_s(d1(month):d2(month),:,:) = S_s(d1(month):d2(month),:,:)+s_s/3.0;
                                                     
      T_e(d1(month):d2(month),:,:) = T_e(d1(month):d2(month),:,:)+t_e/3.0;
      T_n(d1(month):d2(month),:,:) = T_n(d1(month):d2(month),:,:)+t_n/3.0;
      T_s(d1(month):d2(month),:,:) = T_s(d1(month):d2(month),:,:)+t_s/3.0;
                                                     
      U_e(d1(month):d2(month),:,:) = U_e(d1(month):d2(month),:,:)+u_e/3.0;
      U_n(d1(month):d2(month),:,:) = U_n(d1(month):d2(month),:,:)+u_n/3.0;
      U_s(d1(month):d2(month),:,:) = U_s(d1(month):d2(month),:,:)+u_s/3.0;
                                                     
      V_e(d1(month):d2(month),:,:) = V_e(d1(month):d2(month),:,:)+v_e/3.0;
      V_n(d1(month):d2(month),:,:) = V_n(d1(month):d2(month),:,:)+v_n/3.0;
      V_s(d1(month):d2(month),:,:) = V_s(d1(month):d2(month),:,:)+v_s/3.0;

      SSH_e(d1(month):d2(month),:) = SSH_e(d1(month):d2(month),:)+ssh_e/3.0;
      SSH_n(d1(month):d2(month),:) = SSH_n(d1(month):d2(month),:)+ssh_n/3.0;
      SSH_s(d1(month):d2(month),:) = SSH_s(d1(month):d2(month),:)+ssh_s/3.0;

    elseif year == 1 && month > 1
      days(month) = size(h_e,1);
      H_e = cat(1,H_e,h_e/3.0);
      H_n = cat(1,H_n,h_n/3.0);
      H_s = cat(1,H_s,h_s/3.0);

      S_e = cat(1,S_e,s_e/3.0);
      S_n = cat(1,S_n,s_n/3.0);
      S_s = cat(1,S_s,s_s/3.0);

      T_e = cat(1,T_e,t_e/3.0);
      T_n = cat(1,T_n,t_n/3.0);
      T_s = cat(1,T_s,t_s/3.0);

      U_e = cat(1,U_e,u_e/3.0);
      U_n = cat(1,U_n,u_n/3.0);
      U_s = cat(1,U_s,u_s/3.0);

      V_e = cat(1,V_e,v_e/3.0);
      V_n = cat(1,V_n,v_n/3.0);
      V_s = cat(1,V_s,v_s/3.0);

      SSH_e = cat(1,SSH_e,ssh_e/3.0);
      SSH_n = cat(1,SSH_n,ssh_n/3.0);
      SSH_s = cat(1,SSH_s,ssh_s/3.0);

    end
    k = k+1;
  end
end

clear days h_e h_n h_s k month s_e s_n s_s t_e t_n t_s u_e u_n u_s v_e v_n v_s ssh_e ssh_n ssh_s year

fprintf('Inpaint boundary condition files \n')
% Clean out large velocity values -- not sure why abs(u) ~ O(100 m/s) in the HYCOM data
% We set them to NaN and let inpainting fill in these values.
U_e( abs(U_e) > max(max(abs(U_e(:,:,1)))) ) = NaN;
U_s( abs(U_s) > max(max(abs(U_s(:,:,1)))) ) = NaN;
U_n( abs(U_n) > max(max(abs(U_n(:,:,1)))) ) = NaN;
V_e( abs(V_e) > max(max(abs(V_e(:,:,1)))) ) = NaN;
V_s( abs(V_s) > max(max(abs(V_s(:,:,1)))) ) = NaN;
V_n( abs(V_n) > max(max(abs(V_n(:,:,1)))) ) = NaN;

% Inpaint boundary conditions at each time level
parfor (t = 1:size(H_e,1), nWorkers)

  %fprintf('Inpaint Boundary Conditions: Day : %d \n',t)
  % Temperature
  var = squeeze(T_e(t,:,:));
  T_e(t,:,:) = inpaint_nans(var,inpaintMethod);  

  var = squeeze(T_n(t,:,:));
  T_n(t,:,:) = inpaint_nans(var,inpaintMethod);  

  var = squeeze(T_s(t,:,:));
  T_s(t,:,:) = inpaint_nans(var,inpaintMethod);  

  % Salinity
  var = squeeze(S_e(t,:,:));
  S_e(t,:,:) = inpaint_nans(var,inpaintMethod);  

  var = squeeze(S_n(t,:,:));
  S_n(t,:,:) = inpaint_nans(var,inpaintMethod);  

  var = squeeze(S_s(t,:,:));
  S_s(t,:,:) = inpaint_nans(var,inpaintMethod);  

  % Zonal Velocity
  var = squeeze(U_e(t,:,:));
  U_e(t,:,:) = inpaint_nans(var,inpaintMethod);  

  var = squeeze(U_n(t,:,:));
  U_n(t,:,:) = inpaint_nans(var,inpaintMethod);  

  var = squeeze(U_s(t,:,:));
  U_s(t,:,:) = inpaint_nans(var,inpaintMethod);  

  % Meridional Velocity
  var = squeeze(V_e(t,:,:));
  V_e(t,:,:) = inpaint_nans(var,inpaintMethod);  

  var = squeeze(V_n(t,:,:));
  V_n(t,:,:) = inpaint_nans(var,inpaintMethod);  

  var = squeeze(V_s(t,:,:));
  V_s(t,:,:) = inpaint_nans(var,inpaintMethod);  
  
end

MT_e = zeros(daysPerYear,996,75);
MS_e = zeros(daysPerYear,996,75);
MU_e = zeros(daysPerYear,996,75);
MV_e = zeros(daysPerYear,996,75);

fprintf('Interpolate boundary conditions onto target vertical grid \n')
% Eastern boundary interpolation
parfor (j = 1:996,nWorkers)
  %fprintf('East boundary interpolation: Latitude : %d \n',j)
  for i = 1:daysPerYear

    % Layer thickness
    h = squeeze(H_e(i,j,:));
    if ~isnan(h(1)) 

      % find the last nonzero layer thickness
      h( h < htol ) = 0;
      kmax = find(h,1,'last');
      th = h(1:kmax);
      
      % Obtain the hycom layer mid-depths
      zh = cumsum(th)-0.5*th;

      % Temperature
      var = squeeze(T_e(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MT_e(i,j,:) = out;

      % Temperature
      var = squeeze(S_e(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MS_e(i,j,:) = out;

      % Zonal Velocity
      var = squeeze(U_e(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MU_e(i,j,:) = out;

      % Meridional Velocity
      var = squeeze(V_e(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MV_e(i,j,:) = out;
    end
  end
end

MT_s = zeros(daysPerYear,1280,75);
MS_s = zeros(daysPerYear,1280,75);
MU_s = zeros(daysPerYear,1280,75);
MV_s = zeros(daysPerYear,1280,75);

MT_n = zeros(daysPerYear,1280,75);
MS_n = zeros(daysPerYear,1280,75);
MU_n = zeros(daysPerYear,1280,75);
MV_n = zeros(daysPerYear,1280,75);

% Southern & northern boundary interpolation
parfor (j = 1:1280,nWorkers)
  %fprintf('North/South boundary interpolation: Longitude: %d \n',j)
  for i = 1:daysPerYear

    % Layer thickness
    h = squeeze(H_s(i,j,:));
    if ~isnan(h(1)) 

      % find the last nonzero layer thickness
      h( h < htol ) = 0;
      kmax = find(h,1,'last');
      th = h(1:kmax);
      
      % Obtain the hycom layer mid-depths
      zh = cumsum(th)-0.5*th;

      % Temperature
      var = squeeze(T_s(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MT_s(i,j,:) = out;

      % Temperature
      var = squeeze(S_s(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MS_s(i,j,:) = out;

      % Zonal Velocity
      var = squeeze(U_s(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MU_s(i,j,:) = out;

      % Meridional Velocity
      var = squeeze(V_s(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MV_s(i,j,:) = out;

    end

    % Layer thickness
    h = squeeze(H_n(i,j,:));
    if ~isnan(h(1)) 

      % find the last nonzero layer thickness
      h( h < htol ) = 0;
      kmax = find(h,1,'last');
      th = h(1:kmax);
      
      % Obtain the hycom layer mid-depths
      zh = cumsum(th)-0.5*th;

      % Temperature
      var = squeeze(T_n(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MT_n(i,j,:) = out;

      % Temperature
      var = squeeze(S_n(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MS_n(i,j,:) = out;

      % Zonal Velocity
      var = squeeze(U_n(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MU_n(i,j,:) = out;

      % Meridional Velocity
      var = squeeze(V_n(i,j,1:kmax));
      out = interp1(zh,var,zt,vInterpMethod,var(kmax));
      out( zt <= zh(1) ) = var(1);
      MV_n(i,j,:) = out;

    end
  end
end

%% Detrend boundary conditions
%%parfor (k = 1:75,nWorkers)
%for k = 1:75
%  fprintf('North/South boundary conditions detrend: Vertical Level: %d \n',k)
%  for j = 1:1280
%
%    % North boundary
%    var = MT_n(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MT_n(1:daysPerYear,j,k) = out;
%
%    var = MS_n(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MS_n(1:daysPerYear,j,k) = out;
%
%    var = MU_n(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MU_n(1:daysPerYear,j,k) = out;
%
%    var = MV_n(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MV_n(1:daysPerYear,j,k) = out;
%
%    % South boundary
%    var = MT_s(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MT_s(1:daysPerYear,j,k) = out;
%
%    var = MS_s(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MS_s(1:daysPerYear,j,k) = out;
%
%    var = MU_s(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MU_s(1:daysPerYear,j,k) = out;
%
%    var = MV_s(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MV_s(1:daysPerYear,j,k) = out;
%
%  end
%
%  fprintf('East boundary conditions detrend: Vertical Level: %d \n',k)
%  for j = 1:996
%
%    % East boundary
%    var = MT_e(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MT_e(1:daysPerYear,j,k) = out;
%
%    var = MS_e(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MS_e(1:daysPerYear,j,k) = out;
%
%    var = MU_e(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MU_e(1:daysPerYear,j,k) = out;
%
%    var = MV_e(1:daysPerYear,j,k);
%    out = detrend(var,1);
%    MV_e(1:daysPerYear,j,k) = out;
%
%  end
%
%end

MT_e = permute(MT_e, [2 3 1]);
MS_e = permute(MS_e, [2 3 1]);
MU_e = permute(MU_e, [2 3 1]);
MV_e = permute(MV_e, [2 3 1]);
MT_s = permute(MT_s, [2 3 1]);
MS_s = permute(MS_s, [2 3 1]);
MU_s = permute(MU_s, [2 3 1]);
MV_s = permute(MV_s, [2 3 1]);
MT_n = permute(MT_n, [2 3 1]);
MS_n = permute(MS_n, [2 3 1]);
MU_n = permute(MU_n, [2 3 1]);
MV_n = permute(MV_n, [2 3 1]);

fprintf(' ------- Boundary Conditions Stats -------- \n')
fprintf(' > East \n')
fprintf('     Min(T)   : %.2f (C)\n', min(min(min(MT_e))) )
fprintf('     Max(T)   : %.2f (C)\n', max(max(max(MT_e))) )
fprintf('     NaNs(T)  : %d \n', sum(sum(sum(isnan(MT_e)))) )
fprintf('     Min(S)   : %.2f (PSU)\n', min(min(min(MS_e))) )
fprintf('     Max(S)   : %.2f (PSU)\n', max(max(max(MS_e))) )
fprintf('     NaNs(S)  : %d \n', sum(sum(sum(isnan(MS_e)))) )
fprintf('     Min(U)   : %.2f (m/s)\n', min(min(min(MU_e))) )
fprintf('     Max(U)   : %.2f (m/s)\n', max(max(max(MU_e))) )
fprintf('     NaNs(U)  : %d \n', sum(sum(sum(isnan(MU_e)))) )
fprintf('     Min(V)   : %.2f (m/s)\n', min(min(min(MV_e))) )
fprintf('     Max(V)   : %.2f (m/s)\n', max(max(max(MV_e))) )
fprintf('     NaNs(V)  : %d \n', sum(sum(sum(isnan(MV_e)))) )
fprintf(' > South \n')
fprintf('     Min(T)   : %.2f (C)\n', min(min(min(MT_s))) )
fprintf('     Max(T)   : %.2f (C)\n', max(max(max(MT_s))) )
fprintf('     NaNs(T)  : %d \n', sum(sum(sum(isnan(MT_s)))) )
fprintf('     Min(S)   : %.2f (PSU)\n', min(min(min(MS_s))) )
fprintf('     Max(S)   : %.2f (PSU)\n', max(max(max(MS_s))) )
fprintf('     NaNs(S)  : %d \n', sum(sum(sum(isnan(MS_s)))) )
fprintf('     Min(U)   : %.2f (m/s)\n', min(min(min(MU_s))) )
fprintf('     Max(U)   : %.2f (m/s)\n', max(max(max(MU_s))) )
fprintf('     NaNs(U)  : %d \n', sum(sum(sum(isnan(MU_s)))) )
fprintf('     Min(V)   : %.2f (m/s)\n', min(min(min(MV_s))) )
fprintf('     Max(V)   : %.2f (m/s)\n', max(max(max(MV_s))) )
fprintf('     NaNs(V)  : %d \n', sum(sum(sum(isnan(MV_s)))) )
fprintf(' > North \n')
fprintf('     Min(T)   : %.2f (C)\n', min(min(min(MT_n))) )
fprintf('     Max(T)   : %.2f (C)\n', max(max(max(MT_n))) )
fprintf('     NaNs(T)  : %d \n', sum(sum(sum(isnan(MT_n)))) )
fprintf('     Min(S)   : %.2f (PSU)\n', min(min(min(MS_n))) )
fprintf('     Max(S)   : %.2f (PSU)\n', max(max(max(MS_n))) )
fprintf('     NaNs(S)  : %d \n', sum(sum(sum(isnan(MS_n)))) )
fprintf('     Min(U)   : %.2f (m/s)\n', min(min(min(MU_n))) )
fprintf('     Max(U)   : %.2f (m/s)\n', max(max(max(MU_n))) )
fprintf('     NaNs(U)  : %d \n', sum(sum(sum(isnan(MU_n)))) )
fprintf('     Min(V)   : %.2f (m/s)\n', min(min(min(MV_n))) )
fprintf('     Max(V)   : %.2f (m/s)\n', max(max(max(MV_n))) )
fprintf('     NaNs(V)  : %d \n', sum(sum(sum(isnan(MV_n)))) )
fprintf(' ----------------------------------------- \n')

fprintf('Write boundary conditions to file \n')
fileID = fopen(strcat(outputDir,'t.east.bin'),'w');
fwrite(fileID,MT_e,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'s.east.bin'),'w');
fwrite(fileID,MS_e,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'u.east.bin'),'w');
fwrite(fileID,MU_e,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'v.east.bin'),'w');
fwrite(fileID,MV_e,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'t.south.bin'),'w');
fwrite(fileID,MT_s,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'s.south.bin'),'w');
fwrite(fileID,MS_s,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'u.south.bin'),'w');
fwrite(fileID,MU_s,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'v.south.bin'),'w');
fwrite(fileID,MV_s,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'t.north.bin'),'w');
fwrite(fileID,MT_n,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'s.north.bin'),'w');
fwrite(fileID,MS_n,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'u.north.bin'),'w');
fwrite(fileID,MU_n,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'v.north.bin'),'w');
fwrite(fileID,MV_n,'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'lat.bin'),'w');
fwrite(fileID,plat(1:996,1:1280),'single','ieee-be');
fclose(fileID);

fileID = fopen(strcat(outputDir,'lon.bin'),'w');
fwrite(fileID,plon(1:996,1:1280),'single','ieee-be');
fclose(fileID);


delete(pool);
