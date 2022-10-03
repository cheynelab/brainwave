function err = bw_generateFSLMeshes(niftiFile, fvalue, T2file)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% function bw_generateFSLMeshes(niftiFile,fvalue, T2file)
%%
%%  written by D. Cheyne, April 2012
%%
%%  script to run FSL to get surface meshes from a NifTI file using FSL
%% 
%% Version 4.0 July, 2022 -- pass more options to bet...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fsldir = getenv('FSLDIR');

err = 1;

if isempty(fsldir)
    response = bw_warning_dialog('Cannot find FSL directory. Would you like to look for it?');      
    if response
        fsldir = uigetdir;
    else
        return;
    end
    if ~exist(fsldir,'dir')
        fprintf('Error:  FSL does not seem to be installed and configured on this computer. Exiting...\n');
        return;
    end
end
fslVerFile = [fsldir,'/etc/fslversion'];
FSLVer = load(fslVerFile);      % just gets major version number to avoid version 4

if FSLVer < 6.0
    s = sprintf('Warning: You are running FSL version %g. Use FSL version 6.0 or higher recommended...\n', FSLVer);
    errdlg(s);
    return;
end

fid = fopen(fslVerFile);        % get exact version 
FSLVerTxt = fscanf(fid,'%s');
fclose(fid);
fprintf('Using FSL version %s in %s ...\n', FSLVerTxt, fsldir);

tic;

% don't save compressed images
setenv('FSLOUTPUTTYPE','NIFTI');

matFile = strrep(niftiFile,'.nii','.mat');
M = [];
le = [];
re = [];
na = [];
mmPerVoxel = 0;

load(matFile);

% fix from Marc and Sonya - 
% use brain center to set an optimal center of gravity for bet

% *** bug fix for version 3.0beta 
% origin of 70 mm is too high and occasionally causes skull stripping to
% fail, changed to 50 mm

% origin = [0 0 70 1] * inv(M);
headCenter = [0 0 50];
origin = [headCenter 1] * inv(M);
origin = round(origin(1:3));

fprintf('Running FSL version %g (bet2 / betsurf) to get brain meshes...\n', FSLVer);
fprintf('Initializing with head origin (%g %g %g mm) = (RAS voxels %d %d %d)...\n', headCenter, origin);
fprintf('Fractional intensity threshold = %g (try increasing if non-brain regions not excluded)\n', fvalue);

fileprefix = strrep(niftiFile,'.nii','');

drawnow; % make sure warning dialog pops down.


% change version 3.0 - save FSL surfaces without SUBJ ID prepended
idx = find(fileprefix==filesep);
mri_path = fileprefix(1:idx(end));

% if ~isempty(T2file)
%     fprintf('T2 image available. Running FSL with -A2 option..\n');
% %            cmd = sprintf('%s/bin/bet %s %sbet -c %d %d %d -m -A2 %s',...
% %             fsldir, fileprefix, mri_path, origin, T2_fileprefix);
% else
%     cmd = sprintf('%s/bin/bet %s %sbet -c %d %d %d -m -A -R',...
%         fsldir, fileprefix, mri_path, origin);
    cmd = sprintf('%s/bin/bet %s %sbet -c %d %d %d -m -f %.2f -A',...
        fsldir, fileprefix, mri_path, origin, fvalue);
    if ~isempty(T2file)
        cmd = strcat(cmd ,' -A2 ', T2File);
    end
% end

system(cmd);

t=toc; fprintf('...done (%5.2f sec).\n\n',t);

err = 0;

end
    



