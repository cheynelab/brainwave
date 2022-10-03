function [meanOrigin, meanRadius, err] = bw_fitMultipleSpheres(dsName, shape, nameList, chan_pos, savePath, patchRadius )
%       BW_FITMULTIPLESPHERES
%
%   function [meanOrigin, meanRadius, err] = bw_fitMultipleSpheres(dsName, shape, nameList, chan_pos, savePath, patchRadius )
%
%   DESCRIPTION: Given the name of the dataset (dsName), .shape file
%   (shape) and the name of the new .hdm file (savePath) as well as the 
%   list of sensor names (nameList), good channels (chan_pos) and a radius
%   to search for points (patchRadius) the function will fit multiple local
%   spheres to it and save the results to the .hdm file to savePath. The
%   function will aslo return the spheres mean origin (meanOrigin) and
%   radius (meanRadius) and an error flag (err) for convenience.
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [meanOrigin, meanRadius, err] = bw_fitMultipleSpheres(dsName, shape, nameList, chan_pos, savePath, patchRadius )
% fits multiple local sphere to passed shape data
% and saves results in the dataset in a .hdm file 
% written by D. Cheyne
% Dec, 2007
%
% version 1.1 Jan 2008 - changed method for validity check 
%
% version 1.2 July 2011  nameList is now passed as cellstr array - this seemedd inconsistent in last version
% 
% modified for Brainwave Jan, 2011 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

MIN_FIT_PTS = 8;   % set min. number of points to fit sphere 
MAX_FIT_PTS = 10000;   % set max. number of points to fit sphere 

if ~exist('savePath','var')
    savePath = fullfile(dsName,'multiSphere.hdm');
end

if ~exist('patchRadius','var')
    patchRadius = 9.0;
end

if (size(shape,2) ~= 3)
    fprintf('shape array must be n x 3 array\n');
    err = -1;
    return;
end

numChannels = size(chan_pos,1);
npts = size(shape,1);

err = 0;
meanPts = 0;
meanRadius = 0;
meanOrigin = [0 0 0];

% flag overly dense shape files (e.g., from new version of MRIViewer
if npts > MAX_FIT_PTS
    factor = floor( npts / MAX_FIT_PTS );
    fprintf('File contains too many points (%g) - downsampling by factor of %d\n', npts, factor);
    shape = downsample(shape,factor);
    npts = size(shape,1);
    
    [path,name,ext] = bw_fileparts(dsName);
    filename = sprintf('multisphere.shape',name);
    shapeName = fullfile(dsName,filename);
    fprintf('Saving downsample shape file in %s\n',shapeName);
    fid = fopen(shapeName,'w');
    fprintf(fid,'%d\n', npts);
    for i=1:npts
        fprintf(fid, '%.3f    %.3f    %.3f\n', shape(i,1:3));
    end
    fclose(fid);   
end

fprintf('\nfitting spheres\n');

wbh = waitbar(0,'Fitting multiple spheres');
for i=10:5:20
    waitbar(i/100,wbh);
end

for i=1:numChannels
    
    pos = chan_pos(i,1:3);
    sensorname = char(nameList{i});

   s = sprintf('\nfitting sphere for channel %s ...\n', sensorname);
   waitbar(i/numChannels,wbh,s);
        
        
    % find closest mesh point 
    d = zeros(npts,1);
    for j=1:npts
        p = shape(j,:);
        d(j) = norm(p-pos);
    end
    [dist idx] = min(d);
    center = shape(idx,:);
        
    % fprintf('closest surface point is = %.2f %.2f %.2f (dist = %.2f cm)...\n',center, dist);   
 
    %find points in range
    np = 0;
    clear patch;        % reset patch size to zero!
    for j=1:npts
        if (j ~= idx)
            p = shape(j,:);
            dist = norm(p-center);
            if (dist <= patchRadius)
                np = np+1;
                patch(np,1:3) = p;
            end
        end
    end

    % fit sphere with some sanity checks
    if (np < MIN_FIT_PTS)
        fprintf('Warning: Insufficient number of points in search radius for multiSphere calculation, try increasing number of head points\n');
        err = -1;
        return;
    end

    % for patch the default start params may not be optimal
    % modified fitSphere to take fixed params
    startParams = [0 0 5 7];
    [o, r] = bw_fitSphere(patch, startParams);

    meanPts = meanPts + np;
    meanRadius = meanRadius + r;
    meanOrigin = meanOrigin + o;
    sphereList(i,:) = [o r];


   % fprintf('found %d points, sphere = %.2f %.2f %.2f, radius = %.2f cm)\n', np, o, r);
        
end

delete(wbh);

fprintf('\n');

meanPts = meanPts / numChannels;
meanRadius = meanRadius / numChannels;
meanOrigin = meanOrigin ./numChannels;

% check for invalid spheres - for now assume that distance of any origin 
% from mean origin should not exceed the radius of the mean sphere.

for i=1:numChannels
    o = sphereList(i,1:3);
    r = sphereList(i,4);
    deltaR = norm(o - meanOrigin);
    if (deltaR > meanRadius)
        sensorname = char(nameList{i});
        fprintf('ERROR: distance of sphere origin for sensor %s (%.2f %.2f %.2f, r=%.2f) is %.3f cm\n', sensorname, o, r, deltaR);
        fprintf('from mean sphere origin (%.2f %.2f %.2f) and may be outside of head...Try increasing patch size.\n', meanOrigin);
        err = -1;
        return;
    end
end


% if everthing OK write file
fid = fopen(savePath,'w');
for i=1:numChannels
    sensorname = char(nameList{i});
    sphere = sphereList(i,:);
    fprintf(fid, '%s:    %.3f    %.3f    %.3f    %.3f\n', sensorname, sphere);
end
fclose(fid);

return;