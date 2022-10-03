% new routine to convert yokogawa geometry and HPI coil information to get
% both dewar and head relative geometry to make CTF compatible datasets
% 
% Takes ds name, confile, and other parameters for the dataset and 
% creates the struct res4, as well as head and dewar 
% fiducial coordinates. 
%
% The res4 struct has all the parameters (no_samples, no_channels, senres,
% etc.) required to write the res4 file. 
%
% written by M. Woodbury and D. Cheyne


function [res4, fid_pts_head, fid_pts_dewar] = yokogawa2res4(dsName, conFile, mrkFile, elpFile, numTrials, preTrigPts, bandpass, validChan)

  res4 = [];
  
  [path, basename, ext] = fileparts(dsName);
  
  % Fiducials in head and dewar coordinates.
  % original code does not work for averaging head position across runs as 
  % these are fids in headshape relative coords, i.e., locations move with the
  % head instead of the sensors. For true dewar coordinates need to put these
  % into a sensor relative coordinates and save these below as the coilTbl and dewar
  % relative fids in the .hc file
  
  fid_pts_head = [];
  fid_pts_dewar = [];
  
  fprintf('Getting fiducials from %s \n',  elpFile);
  [shape] = readElpFile(elpFile); 

  labels = shape.fid.label;
  for i=1:size(labels,1)
    if strcmp(labels(i), 'NASION')
      na = shape.fid.pnt(i, 1:3);
    elseif strcmp(labels(i), 'LPA')
      le = shape.fid.pnt(i, 1:3);
    elseif strcmp(labels(i), 'RPA')
      re = shape.fid.pnt(i, 1:3);
    end
  end
  
  fid_pts_head.na = na * 100; % convert to cm
  fid_pts_head.le = le * 100;
  fid_pts_head.re = re * 100;
  fprintf('KIT fiducials in head coordinate system => (na = %.3f %.3f %.3f cm, le = %.3f %.3f %.3f cm, re = %.3f %.3f %.3f cm)\n', ...
    fid_pts_head.na, fid_pts_head.le, fid_pts_head.re);
  
  
  % create res4 struct
  
  conHeader = read_yokogawa_header(conFile);
  % res4 constant fields
  res4.header = 'MEG42RS';
  
  res4.appName='';
  res4.dataOrigin='';
  res4.dataDescription='';
  res4.no_trials_avgd = 0;
  
  datetime = datestr(now);
  space_idx = find(isspace(datetime), 1, 'first');
  res4.data_date = datetime(1:space_idx-1);
  res4.data_time = datetime(space_idx+1:end);

  % new_general_setup_rec_ext part of meg41GeneralResRec
  res4.no_samples = conHeader.numSamples; 
  num_sensors = conHeader.numSensors;
  res4.sample_rate = conHeader.sampleRate;     
  
  trialDuration = res4.no_samples * (1.0 / res4.sample_rate);
  res4.epoch_time = trialDuration * numTrials;     
  res4.no_trials = numTrials;     
  res4.preTrigPts = preTrigPts;        
  res4.no_trials_done = 0;    
  res4.no_trials_display = 0; 
  res4.save_trials = 0;       

  % meg41TriggerData part of new_general_setup_rec_ext   10 bytes total
  res4.primaryTrigger = 0;
  res4.secondaryTrigger = 0;
  res4.triggerPolarityMask = 0; 

  % end of meg41TriggerData part of new_general_setup_rec_ext
  res4.trigger_mode = 0;   
  res4.accept_reject_Flag = 0;  
  res4.run_time_display = 0;

  res4.zero_Head_Flag = 0;      
  res4.artifact_mode = 0;       
  %  end of new_general_setup_rec_ext part of meg41GeneralResRec

  % meg4FileSetup part of meg41GeneralResRec
  res4.nf_run_name=basename;
  res4.nf_run_title=basename; % CHANGE? was geomFile
  res4.nf_instruments= '';
  
  res4.nf_subject_id= '';
  res4.nf_operator= 'none';
  res4.nf_sensorFileName= '';
  
  res4.run_description = 'Dataset created by yokogawa2res4';
  res4.size=length(res4.run_description);
  res4.nf_collect_descriptor= res4.run_description;
  %  end of meg4FileSetup part of meg41GeneralResRec
 
  % filter descriptions
  res4.fClass = 1;
  res4.fNumParams = 0;
  res4.lowPass = bandpass(2);
  res4.highPass = bandpass(1);
  if res4.highPass == 0
      res4.num_filters = 1;
  else 
      res4.num_filters = 2;
  end
  % end of filter descriptions
  
  
  % calculate channel positions and orientations
  fprintf('Converting sensor positions in %s to CTF coordinates...\n', conFile);
  
  if isempty(validChan)
     validChan = ones(num_sensors,1);  % use all channels
  end

  % coilTbl (device coords)
  for i=1:num_sensors 
      % coil 1
      res4.orig_senres(i).pos0(:,1) = [conHeader.channel(i).x; conHeader.channel(i).y; conHeader.channel(i).z] ;
    
      zdir = conHeader.channel(i).zdir;
      xdir = conHeader.channel(i).xdir;
      ori2_x = sind(zdir)*cosd(xdir); % find vector direction from zdir and xdir angles 
      ori2_y = sind(zdir)*sind(xdir);
      ori2_z = cosd(zdir);
      ori2(1:3,i) = [ori2_x; ori2_y; ori2_z]; % vector points away from coil 1
      
      % p-vectors
      res4.orig_senres(i).ori0(:,2) = ori2(1:3,i)/norm(ori2(1:3,i)); % make sure it's a unit vector
      res4.orig_senres(i).ori0(:,1) = res4.orig_senres(i).ori0(:,2) * -1;  % flip vector to point away from coil 2 (has opposite direction)

      % coil 2
      baseline = conHeader.channel(i).baseline; % typically 0.05 m
      res4.orig_senres(i).pos0(:,2) = res4.orig_senres(i).pos0(:,1) + (res4.orig_senres(i).ori0(:,2)* baseline);
  end

  k = 1; 
  for h=1:num_sensors

      % update res4.senres to skip over invalid sensors
      if validChan(h)
          res4.senres(k) = res4.orig_senres(h);
          if (res4.orig_senres(h).pos0(2,1) > 0.0) % name: check y coord of coilTbl, coil 1 (if > 0 then it's left)
              res4.chanNames(k) = cellstr(sprintf('MLG%03d',h));
          else
              res4.chanNames(k) = cellstr(sprintf('MRG%03d',h));
          end
          k = k + 1;
      else
          fprintf('Excluding channel %d\n', h);
      end
  end   
  num_sensors = k - 1;     
  
  meg2head_transm = MEG2polhemus_matrix(elpFile, mrkFile);

  % we now want the fiducials in true dewar coordinates to 
  na = [fid_pts_head.na 1] * inv(meg2head_transm');
  le = [fid_pts_head.le 1] * inv(meg2head_transm');
  re = [fid_pts_head.re 1] * inv(meg2head_transm');

  fid_pts_dewar.na = na(1:3);
  fid_pts_dewar.le = le(1:3);
  fid_pts_dewar.re = re(1:3);
  
  fprintf('KIT fiducials in MEG (dewar) coordinate system => (na = %.3f %.3f %.3f cm, le = %.3f %.3f %.3f cm, re = %.3f %.3f %.3f cm)\n', ...
    fid_pts_dewar.na, fid_pts_dewar.le, fid_pts_dewar.re);  

  % now create CTF format dewar to head coordinate system transformation
  % to ensure consistency with CTF coordinates use this to transform dewar
  % geometry to CTF coordinates. Note that since KIT polhemus LPA
  % and RPA seem to always be equidistant from origin, using dewar2ctf and
  % meg2headtransm yield same results...
  
  dewar2ctf = getAffineVox2CTF(fid_pts_dewar.na, fid_pts_dewar.le, fid_pts_dewar.re, 1);

  % scale and convert to ctf coordinates
  for l=1:num_sensors
    res4.senres(l).pos0 = res4.senres(l).pos0*100; % convert coilTbl to cm permanently
    res4.senres(l).pos  = [res4.senres(l).pos0' ones(2,1)];
    res4.senres(l).pos = res4.senres(l).pos * dewar2ctf;
    res4.senres(l).pos = res4.senres(l).pos(:,1:3)';
  end

  % recompute gradiometer orientation 
  % note that CTF convention is that p-vectors point outwards from
  % gradiometer center - otherwise dipole is flipped in CTF software
  for m=1:num_sensors
      x = res4.senres(m).pos(:,1) - res4.senres(m).pos(:,2); % coil1 - coil2
      res4.senres(m).ori(:,1) = x / norm(x);
      res4.senres(m).ori(:,2) = res4.senres(m).ori(:,1) * -1;   % second coil has opposite direction
  end
  % end of channel calculations
    
  % set rest of res4 params
  res4.no_channels = num_sensors + conHeader.numADC;
  for kchan=1:res4.no_channels
    
    % ADC channels 
    if kchan > num_sensors
      res4.senres(kchan).sensorTypeIndex = 18;
      res4.senres(kchan).properGain = 1;
      res4.senres(kchan).qGain = 1.0e8;
      res4.senres(kchan).numCoils = 1;
      
      % HdcoilTbl
      res4.senres(kchan).pos(:,1) = [0; 0; 0];
      res4.senres(kchan).ori(:,1) = [1; 0; 0];
      res4.senres(kchan).numturns(1) = 1;
      res4.senres(kchan).area(1) = 0;
      
      % coilTbl
      res4.senres(kchan).pos0(:,1) = [0; 0; 0];
      res4.senres(kchan).ori0(:,1) = [1; 0; 0];
      
      % name
      % Version 2.0 - corrected naming of ADC channels to have 3 digits
      % have to use cellstr for different length names...
      res4.chanNames(kchan)=cellstr(sprintf('UADC%03d',(kchan-num_sensors)));
    
    else
      
      res4.senres(kchan).sensorTypeIndex = 5; 
      
      % gain is now defined LSB value that will be used to scale the data
      res4.senres(kchan).properGain = 1/conHeader.LSB; 
      res4.senres(kchan).qGain = 1;
      res4.senres(kchan).numCoils = 2; % assumes 1st order grad system
      
      res4.senres(kchan).numturns(1) = 1; % assume this for now ...
      res4.senres(kchan).numturns(2) = 1;
      
      coilRadius = (conHeader.channel(1).size *100)/ 2.0;
      coilArea = pi * coilRadius * coilRadius;  % for CTF header
      res4.senres(kchan).area(1) = coilArea;
      res4.senres(kchan).area(2) = coilArea;
      
    end
    
    res4.senres(kchan).originalRunNum = 0;
    res4.senres(kchan).coilShape = 0;
    res4.senres(kchan).ioGain = 1;
    res4.senres(kchan).ioOffset = 0;
    res4.senres(kchan).grad_order_no = 0;

  end
  
  res4.numcoef = 0;
  
end

function M = getAffineVox2CTF(nasion_pos, left_preauricular_pos, right_preauricular_pos, mmPerVoxel )
%
%   function M = getAffineVox2CTF(nasion_pos, left_preauricular_pos, right_preauricular_pos, mmPerVoxel )
%
%   DESCRIPTION: Takes the voxel coordinates of fiducial points 
%   (nasion_pos, left_preauricular_pos, right_preauricular_pos) and the 
%   scaling factor (mmPerVoxel) from an isotropic MRI and returns the 4 by 
%   4 affine transformation matrix (M) that is capable of transforming a 
%   point from voxel coordinates to CTF head coordinates.
%
% (c) D. Cheyne, 2011. All rights reserved.
% 
%  
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% written by D. Cheyne.  September 2006
%
% this script takes as input the voxel coordinates of the fiducial points
% and the scaling factor from mm to voxel dimensions, assuming that
% scaling is the same in all directions (isotropic  MRI), and returns the
% 4x4 affine tranformation matrix that converts a point in voxel
% coordinates to CTF head coordinates 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% build CTF coordinate system
% origin is midpoint between ears
origin = (left_preauricular_pos + right_preauricular_pos) /2;

% x axis is vector from this origin to Nasion
x_axis = nasion_pos - origin; 
x_axis=x_axis/norm(x_axis);

% y axis is origin to left ear vector
y_axis= left_preauricular_pos - origin;
y_axis=y_axis/norm(y_axis);

% This y-axis is not necessarely perpendicular to the x-axis, this corrects
z_axis=cross(x_axis,y_axis);
z_axis=z_axis/norm(z_axis);

y_axis=cross(z_axis,x_axis);
y_axis=y_axis/norm(y_axis);

% now build 4 x 4 affine transformation matrix

% rotation matrix is constructed from principal axes as unit vectors
% note transpose for correct direction of rotation 
rmat = [ [x_axis 0]; [y_axis 0]; [z_axis 0]; [0 0 0 1] ]';

% scaling matrix from mm to voxels
smat = diag([mmPerVoxel mmPerVoxel mmPerVoxel 1]);

% translation matrix - subtract origin
tmat = diag([1 1 1 1]);
tmat(4,:) = [-origin, 1];

% affine transformation matrix for voxels to CTF is concatenation of these
% three transformations. Order of first two operations is important. Since
% the origin is in units of voxels we must subtract it BEFORE scaling. Also
% since translation vector is in original coords must be also be rotated in
% order to rotate and translate with one matrix operation

M = tmat * smat * rmat;

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
