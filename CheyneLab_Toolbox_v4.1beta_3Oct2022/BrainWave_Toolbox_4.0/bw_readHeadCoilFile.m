%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [fids_head fids_dewar] = bw_readHeadCoilFile(dsName)
%
% function to read CTF Head Coil file
% returns the measured nasion, left ear and right fiducials in both head and dewar coords
%
% D. Cheyne, Jan, 2014
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [fids_head fids_dewar] = bw_readHeadCoilFile(dsName)

fids_head  = [];
fids_dewar = [];
        
[dsPath,dataset_name,ext] = bw_fileparts(dsName);
hcfile = strcat(dsName, filesep, dataset_name, '.hc');

fID=fopen(hcfile);

% find fidiciuls in sensor coordinates 

while ~feof(fID)
    fids=fgets(fID);
    if strncmp(fids,'measured nasion coil position relative to dewar',47) == 1
        break;
    end
end

% read fids from .hc file
s=fscanf(fID,'\nx = %s');
fids_dewar.na(1) = str2double(s);
s=fscanf(fID,'\ny = %s');
fids_dewar.na(2) = str2double(s);
s=fscanf(fID,'\nz = %s');
fids_dewar.na(3) = str2double(s);            
s=fgets(fID);
s=fscanf(fID,'\nx = %s');
fids_dewar.le(1) = str2double(s);
s=fscanf(fID,'\ny = %s');
fids_dewar.le(2) = str2double(s);
s=fscanf(fID,'\nz = %s');
fids_dewar.le(3) = str2double(s);           
s=fgets(fID);
s=fscanf(fID,'\nx = %s');
fids_dewar.re(1) = str2double(s);
s=fscanf(fID,'\ny = %s');
fids_dewar.re(2) = str2double(s);
s=fscanf(fID,'\nz = %s');
fids_dewar.re(3) = str2double(s);

% fidiciuls in dewar coordinates
while ~feof(fID)
    fids=fgets(fID);
    if strncmp(fids,'measured nasion coil position relative to head',20) == 1
        break;
    end
end

% read fids from .hc file
s=fscanf(fID,'\nx = %s');
fids_head.na(1) = str2double(s);
s=fscanf(fID,'\ny = %s');
fids_head.na(2) = str2double(s);
s=fscanf(fID,'\nz = %s');
fids_head.na(3) = str2double(s);            
s=fgets(fID);
s=fscanf(fID,'\nx = %s');
fids_head.le(1) = str2double(s);
s=fscanf(fID,'\ny = %s');
fids_head.le(2) = str2double(s);
s=fscanf(fID,'\nz = %s');
fids_head.le(3) = str2double(s);           
s=fgets(fID);
s=fscanf(fID,'\nx = %s');
fids_head.re(1) = str2double(s);
s=fscanf(fID,'\ny = %s');
fids_head.re(2) = str2double(s);
s=fscanf(fID,'\nz = %s');
fids_head.re(3) = str2double(s);

fclose(fID);
            
end