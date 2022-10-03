function bw_writeSvlFile(svlFile, boundingBox, stepSize, SAMunits, SAMimage) 
%       
% write a CTF format .svl file (does not populate all fields...)
%
% (c) D. Cheyne, 2014. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

fid = fopen(svlFile, 'w', 'b','latin1');

%  write .svl header
s = 'SAMIMAGE';
blankstring = blanks(256);

fwrite(fid, s,'char');  % SAM identifier

fwrite(fid,1,'int32', 'ieee-be'); % SAM file version

setName = blankstring;
name = 'none';  % dsName - not needed ?
setName(1:length(name)) = name; % dsName padded to 256 bytes
fwrite(fid,setName,'char');   
fwrite(fid,151,'int32', 'ieee-be'); % numChans
fwrite(fid,0,'int32', 'ieee-be'); % numWeights - should be zero 

fwrite(fid,0,'int32', 'ieee-be'); % padBytes = 1

% write bounding box in m

fwrite(fid, boundingBox(1)* 0.01,'double', 'ieee-be');   % XStart
fwrite(fid, boundingBox(2) * 0.01,'double', 'ieee-be');  % XEnd
fwrite(fid, boundingBox(3) * 0.01,'double', 'ieee-be');  % YStart
fwrite(fid, boundingBox(4) * 0.01,'double', 'ieee-be');  % Yend
fwrite(fid, boundingBox(5) * 0.01,'double', 'ieee-be');  % ZStart
fwrite(fid, boundingBox(6) * 0.01,'double', 'ieee-be');  % ZEnd

fwrite(fid, stepSize * 0.01,'double', 'ieee-be');  % stepSize in meters

% pretty sure these filter values are never used, just write some default values
fwrite(fid,0.0,'double', 'ieee-be');    % hp
fwrite(fid,50.0,'double', 'ieee-be');   % lp
fwrite(fid,50.0,'double', 'ieee-be');   % bw
fwrite(fid,3e-30,'double', 'ieee-be');  % mean noise

fwrite(fid,blankstring,'char');     % MRIname

fwrite(fid, 0,'int32', 'ieee-be');  % Nasion
fwrite(fid, 0,'int32', 'ieee-be');
fwrite(fid, 0,'int32', 'ieee-be');

fwrite(fid, 0,'int32', 'ieee-be');  % LE
fwrite(fid, 0,'int32', 'ieee-be');
fwrite(fid, 0,'int32', 'ieee-be');

fwrite(fid, 0,'int32', 'ieee-be');  % RE
fwrite(fid, 0,'int32', 'ieee-be');
fwrite(fid, 0,'int32', 'ieee-be');

fwrite(fid, 0,'int32', 'ieee-be');   % SAM type code  = 0
fwrite(fid, SAMunits,'int32', 'ieee-be');   % SAM unit type **  3 = pseudoZ, 4 = pseudoT, 5 = pseudoF

fwrite(fid, 0,'int32', 'ieee-be');   % padbytes 2

% assume image passed as 1D array *** ?
fwrite(fid,SAMimage,'double', 'ieee-be'); 

fclose(fid);