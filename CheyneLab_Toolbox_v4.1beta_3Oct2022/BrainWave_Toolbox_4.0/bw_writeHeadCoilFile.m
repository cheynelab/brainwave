function bw_writeHeadCoilFile(dsName, fid_pts_head, fid_pts_dewar)
%       BW_WRITEHEADCOILFILE
%
%   function bw_writeHeadCoilFile(dsName, fid_pts_head, fid_pts_dewar)
%
%   DESCRIPTION: this function will write a .hc head coil file into the
%   newly create .ds dataset when given the full pathname of the dataset as 
%   well the head and dewar fiducial coordinates.
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

na_head = fid_pts_head.na;
le_head = fid_pts_head.le;
re_head = fid_pts_head.re;

na_dewar = fid_pts_dewar.na;
le_dewar = fid_pts_dewar.le;
re_dewar = fid_pts_dewar.re;

[garbage1, name, garbage2] = bw_fileparts(dsName);
hcname = sprintf('%s.hc',name);
filename = fullfile(dsName,hcname);

fp = fopen(filename,'w');
if (fp == -1)
    fprintf('failed to open file %s',filename);
    return;
end

% default head position
fprintf(fp, 'standard nasion coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = 2.82843\n');
fprintf(fp, '\ty = 2.82843\n');
fprintf(fp, '\tz = -27\n');
fprintf(fp, 'standard left ear coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = -2.82843\n');
fprintf(fp, '\ty = 2.82843\n');
fprintf(fp, '\tz = -27\n');	
fprintf(fp, 'standard right ear coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = 2.82843\n');
fprintf(fp, '\ty = -2.82843\n');
fprintf(fp, '\tz = -27\n');	
fprintf(fp, 'standard inion coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = -2.82843\n');
fprintf(fp, '\ty = -2.82843\n');
fprintf(fp, '\tz = -27\n');	
fprintf(fp, 'standard Cz coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = 0\n');
fprintf(fp, '\ty = 0\n');
fprintf(fp, '\tz = -23\n');	

fprintf(fp, 'measured nasion coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', na_dewar(1));
fprintf(fp, '\ty = %.5f\n', na_dewar(2));
fprintf(fp, '\tz = %.5f\n', na_dewar(3));	
fprintf(fp, 'measured left ear coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', le_dewar(1));
fprintf(fp, '\ty = %.5f\n', le_dewar(2));
fprintf(fp, '\tz = %.5f\n', le_dewar(3));
fprintf(fp, 'measured right ear coil position relative to dewar (cm):\n');
fprintf(fp, '\tx = %.5f\n', re_dewar(1));
fprintf(fp, '\ty = %.5f\n', re_dewar(2));
fprintf(fp, '\tz = %.5f\n', re_dewar(3));
fprintf(fp, 'measured inion coil position relative to dewar (cm):\n');  
fprintf(fp, '\tx = 0\n');
fprintf(fp, '\ty = 0\n');
fprintf(fp, '\tz = 0\n');	
fprintf(fp, 'measured Cz coil position relative to dewar (cm):\n');		
fprintf(fp, '\tx = 0\n');
fprintf(fp, '\ty = 0\n');
fprintf(fp, '\tz = 0\n');	

fprintf(fp, 'measured nasion coil position relative to head (cm):\n');
fprintf(fp, '\tx = %.5f\n', na_head(1));
fprintf(fp, '\ty = %.5f\n', na_head(2));
fprintf(fp, '\tz = %.5f\n', na_head(3));
fprintf(fp, 'measured left ear coil position relative to head (cm):\n');
fprintf(fp, '\tx = %.5f\n', le_head(1));
fprintf(fp, '\ty = %.5f\n', le_head(2));
fprintf(fp, '\tz = %.5f\n', le_head(3));
fprintf(fp, 'measured3 right ear coil position relative to head (cm):\n');
fprintf(fp, '\tx = %.5f\n', re_head(1));
fprintf(fp, '\ty = %.5f\n', re_head(2));
fprintf(fp, '\tz = %.5f\n', re_head(3));
fprintf(fp, 'measured3 inion coil position relative to head (cm):\n'); 
fprintf(fp, '\tx = 0.0\n');
fprintf(fp, '\ty = 0.0\n');
fprintf(fp, '\tz = 0.0\n');
fprintf(fp, 'measured3 Cz coil position relative to head (cm):\n');
fprintf(fp, '\tx = 0.0\n');
fprintf(fp, '\ty = 0.0\n');
fprintf(fp, '\tz = 0.0\n');

fclose(fp);

end