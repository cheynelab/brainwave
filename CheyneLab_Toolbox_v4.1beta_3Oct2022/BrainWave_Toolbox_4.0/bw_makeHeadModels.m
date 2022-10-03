function [hdmFile] = bw_makeHeadModels(dsName)
%       BW_MAKEHEADMODELS
%
%   function [hdmFile] = bw_makeHeadModels(dsName)
%
%   DESCRIPTION: Creates a headmodel file (.hdm) from a .sfp file or a CTF 
%   .shape file (dsName) amd returns the filename in hdmFile.
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% get shape file...

hdmFile = [];
[filename, pathname, filterIndex]=uigetfile(...
                {'*.sfp','Surface Point File (*.sfp)';...
                '*.shape','CTF Shape file (*.shape)'},...
                  'Select a surface point or shape file...');   
if isequal(filename,0) || isequal(pathname,0)
    return;
end

if filterIndex == 1
    shape_data = read_SFP_File(fullfile(pathname,filename));
elseif filterIndex == 2
    shape_data = read_shape_File(fullfile(pathname,filename));
end

% get channel names and positions. Include balancing refs!
[chan_names chan_pos] = bw_CTFGetSensors(dsName, 1);

% strip balancing file number of CTF names
for i=1:size(chan_names,1);
    xx = chan_names(i,:);
    idx = strfind(xx,'-');
    if ~isempty(idx)
       names{i} = xx(1:idx-1);
    end
end

% get best-fit single sphere...
fprintf('Generating single sphere head model (.hdm) file...\n');
[origin radius] = bw_fitSphere(shape_data);
fprintf('Best fit single sphere: origin = %.2f %.2f %.2f cm, radius = %.2f cm\n', origin, radius);

hdmFile = fullfile(dsName,'singleSphere.hdm');
fprintf('\nSaving best-fit single sphere in %s\n',hdmFile);
fid = fopen(hdmFile,'w');

for i=1:size(chan_names,1)
    s = char(names{i});
    fprintf(fid, '%s:    %.3f    %.3f    %.3f    %.3f\n', s, origin, radius);
end

fclose(fid);       

% do multiSphere
fprintf('Generating multiple (overlapping spheres) head model (.hdm) file\n');
[origin radius err] = bw_fitMultipleSpheres(dsName, shape_data, names, chan_pos);
if (err == 0)
    fprintf('Mean sphere single sphere: origin = %.2f %.2f %.2f cm, radius = %.2f cm\n', origin, radius);
end

% option - write shape data for overlay on MRI...
if filterIndex ~= 2
    [path,name,ext] = bw_fileparts(dsName);

    filename = sprintf('%s.shape',name);
    shapeName = fullfile(dsName,filename);
    fprintf('\nSaving head surface points in %s\n',shapeName);
    fid = fopen(shapeName,'w');
    npts = size(shape_data,1);
    fprintf(fid,'%d\n', npts);
    for i=1:npts
        fprintf(fid, '%.3f    %.3f    %.3f\n', shape_data(i,1:3));
    end

    fclose(fid);   
end    

end


% read BESA / KIT sfp file
% this file is in its own local coordinates but contains fiducial locations
% so we can tranform to CTF coords and return as point cloud in CTF coords
function [points] = read_SFP_File(sfpFile)

    sfp = importdata(sfpFile);

    idx = find(strcmp((sfp.rowheaders), 'fidnz'));
    if isempty(idx)
        fprintf('Could not find fidnz fiducial in sfp file\n');
        return;
    end
    na = sfp.data(idx,:);

    idx = find(strcmp((sfp.rowheaders), 'fidt9'));
    if isempty(idx)
        fprintf('Could not find fidt9 fiducial in sfp file\n');
        return;
    end
    le = sfp.data(idx,:);

    idx = find(strcmp((sfp.rowheaders), 'fidt10'));
    if isempty(idx)
        fprintf('Could not find fidt10 fiducial in sfp file\n');
        return;
    end
    re = sfp.data(idx,:);

    % get transformation matrix from kit space to CTF - includes scaling from
    % mm to cm.
    vox2ctf = bw_getAffineVox2CTF(na, le, re, 0.1);
    % show fiducials in CTF space
    na_ctf = [na 1] * vox2ctf;
    le_ctf = [le 1] * vox2ctf;
    re_ctf = [re 1] * vox2ctf;
    fprintf('KIT fidicials in CTF coordinate system => (na = %.3f %.3f %.3f cm, le = %.3f %.3f %.3f cm, re = %.3f %.3f %.3f cm)\n', ...
        na_ctf(1:3), le_ctf(1:3), re_ctf(1:3));

    fprintf('Converting sensor positions to CTF coordinates...\n');
    
    num_hd_pts = size(sfp.data,1);
    
    if num_hd_pts > 1
        % convert all points to CTF coords...
        pts = [sfp.data ones(num_hd_pts,1)];
        pts = pts * vox2ctf;
        points = pts(:,1:3);
    end

end

function [points] = read_shape_File(shapeFile)

    x = importdata(shapeFile);
    npts = x(1);
    data = x(2:end);
    
    npts = npts(1);  % seems to read more than one col...
    points = reshape(data,3,npts)';
end
    
    
