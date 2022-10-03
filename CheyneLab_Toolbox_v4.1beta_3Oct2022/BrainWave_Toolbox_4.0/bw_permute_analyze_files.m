function bw_permute_analyze_files(listFile, displaycheck, alpha, max_permutations,spmVersion, roi_bounds, outfilePrefix)
%       BW_PERMUTE_ANALYZE_FILES
%
%   function bw_permute_analyze_files(listFile, displaycheck, alpha, max_permutations,spmVersion, roi_bounds, outfilePrefix)
%
%   DESCRIPTION: Performs an omnibus permutation test for a list of 
%   normalized analyze images (listFile) using the specified significance 
%   value (alpha) and optionally the ROI bounding box (roi_bounds) and 
%   maximum number of permutations (max_permutations). The resulting will 
%   then be displayed if displaycheck has been checked and then saved using 
%   the filename and outfilePrefix. 
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_permute_analyze_files(listFile, [alpha], [max_permutations], [roi_bounds], [outfilePrefix])
% 
% D. Cheyne, March 2009
% perform omnibus permutation test for a list of normalized analyze images
%
% Input:
% listFile:        Ascii list of normalized analyze files to permute
%
% Options:
% alpha:           alpha level for thresholding (default = 0.05)
% max_perms:       maximum # of permutations (default=1024, cannot exceed 2^nsubjects)
% roi_bounds:      specify bounding box [xmin xmax ymin ymax zmin zmax] in mm
%                  for ROI test (will truncate image)
% outfilePrefix:   prefix for saving averaged file (default: use listFile name)
%                  
% Version 1.1   August 2009 - added ROI option
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if ~exist('alpha','var')
    alpha = 0.05;
end

if ~exist('roi_bounds','var')
    roi_bounds = [];
end

% based on Wilken's paper null permutation
% dist'n seems to stabilize around 10 - 11 subjects
if ~exist('max_permutations','var')
    max_permutations = 1024;
end

if ~exist('outfilePrefix','var')
    outfilePrefix = listFile;
end

% get array of file names to process
filelist = bw_read_list_file(listFile);

numSubjects = size(filelist,1);

for j=1:numSubjects
    
    file = char( filelist(j,:) );
    fprintf('reading file %s\n', file);

    if spmVersion==2
        image = bw_read_spm_analyze(file);
    elseif spmVersion==8
        [image.hdr, image.filetype, image.fileprefix, image.machine] = load_nii_hdr(file);   
        [image.img,image.hdr2] = load_nii_img(image.hdr,image.filetype,image.fileprefix,image.machine);
    end

    % use first file to get header paramaters
    % then do consistency check as going through the other files
    
    if (j==1)
        aveImg = image;         
        data(:,:,:,1) = image.img;
        
        hdr = image.hdr;
        xdim1 = int32(hdr.dime.dim(2));
        ydim1 = int32(hdr.dime.dim(3));
        zdim1 = int32(hdr.dime.dim(4));
        xres1 = double(hdr.dime.pixdim(2));
        yres1 = double(hdr.dime.pixdim(3));
        zres1 = double(hdr.dime.pixdim(4));
        
        spm_x_origin = hdr.hist.originator(1);
        spm_y_origin = hdr.hist.originator(2);
        spm_z_origin = hdr.hist.originator(3);
        
        % create  equivalent of the SPM XYZ array
        % useful for doing ROI analyis and debugging
        numVoxels = xdim1 * ydim1 * zdim1;
        Xvoxels = zeros(1,numVoxels);
        Yvoxels = zeros(1,numVoxels);
        Zvoxels = zeros(1,numVoxels);
        count=1;
        for ii=1:zdim1
            z = (ii-spm_z_origin) * zres1;
            for jj=1:ydim1
                y = (jj-spm_y_origin) * yres1;
                for kk=1:xdim1     
                    x = (kk - spm_x_origin) * xres1;
                    Xvoxels(count) = x;
                    Yvoxels(count) = y;               
                    Zvoxels(count) = z;
                    count = count+1;
                end
            end
        end
        min_x = min(Xvoxels);
        max_x = max(Xvoxels);
        min_y = min(Yvoxels);
        max_y = max(Yvoxels);
        min_z = min(Zvoxels);
        max_z = max(Zvoxels);
        fprintf('reading SPM images with bounding box = [%g %g %g %g %g %g], resolution = %g mm\n', ...
                min_x, max_x, min_y, max_y, min_z, max_z, xres1);
        if ~isempty(roi_bounds)
            fprintf('*** truncating images to bounding box = [%g %g %g %g %g %g] ***\n', ...
            roi_bounds(1), roi_bounds(2), roi_bounds(3), roi_bounds(4), roi_bounds(5), roi_bounds(6) );    
        end
     else
        data(:,:,:,j) = image.img;

        hdr = image.hdr;
        xdim2 = int32(hdr.dime.dim(2));
        ydim2 = int32(hdr.dime.dim(3));
        zdim2 = int32(hdr.dime.dim(4));
        xres2 = double(hdr.dime.pixdim(2));
        yres2 = double(hdr.dime.pixdim(3));
        zres2 = double(hdr.dime.pixdim(4));  
        
        % do sanity check on image size and resolution
        if (xdim1 ~= xdim2 || ydim1 ~= ydim2 || zdim1 ~= zdim2)
            fprintf('Images are not all same dimensions...\n');
            return;
        end
        if (xres1 ~= xres2 || yres1 ~= yres2 || zres1 ~= zres2)
            fprintf('Images are not all same voxel size...\n');
            return;
        end        
    end
    
    % ROI mode:
    % zero out excluded voxels
    if ~isempty(roi_bounds)
        Z = data(:,:,:,j);
        excludeVoxels = find(Xvoxels < roi_bounds(1) | Xvoxels > roi_bounds(2));
        Z(excludeVoxels) = NaN;
        excludeVoxels = find(Yvoxels < roi_bounds(3) | Yvoxels > roi_bounds(4));
        Z(excludeVoxels) = NaN;
        excludeVoxels = find(Zvoxels < roi_bounds(5) | Zvoxels > roi_bounds(6));
        Z(excludeVoxels) = NaN;
        data(:,:,:,j) = Z;
    end

end


num_voxels = xdim1 * ydim1 * zdim1;
% build unthresholded average 
% - need the max value of this for histogram
ave = sum(data,4)/numSubjects;
aveMax = max(max(max((abs(ave)))));


% determine # of permutations possible
num_perm = 2^numSubjects;

if ( num_perm > max_permutations )       
    num_perm = max_permutations;        
end

minP = 1 / num_perm;
if ( minP > alpha)
    fprintf('Insufficient number of subject to do permutation test at P < %g level\n', alpha);
    return;
end

% use Wilken's subroutine to get randomly sampled permutation table
%
perm_table = bw_get_perm_table(numSubjects, num_perm);

% put data in alternating columns - unflipped  / flipped
nn = 0;
for k=1:numSubjects
    t = data(:,:,:,k);                  % get data  for subject k, this is a 3 dimensional array
    tt = reshape(t, num_voxels,1);      % reshape into one-dimensional column vector
    nn = nn + 1;
    dataMat(nn,:) = tt;
    nn = nn + 1;
    dataMat(nn,:) = -tt;
end
odd_columns = [1:2:numSubjects*2];
permDist = zeros(1,num_perm);

% do permutation
tic;
for k=1:num_perm
    if (mod(k,8) == 1)
        disp(sprintf('Computing permutation: %d of %d',k-1, num_perm));
    end
    % use odd numbered elements of perm table to select images for this iteration
    cols = perm_table(odd_columns, k);
    thisAve = mean(dataMat(cols,:));       % compute mean 
    permDist(k) = max(abs(thisAve));       % permute maximum value of the mean
end
toc;

sortedDist = sort(permDist);

% set all voxels below alpha level to NaN
cutoff = (1.0 - alpha) * num_perm;
cutoff_bin = floor(cutoff);
threshold = sortedDist(cutoff_bin);
sigvox = find(ave >= threshold);
numsig = size(sigvox,1);
if (numsig == 0)
    fprintf('No significant voxels at p < %g\n', alpha);
    return;
end
fprintf('Minimum threshold for p < %g = %.3f (# of sig. voxels = %d)\n', alpha, threshold, numsig);


% set non-sig voxels to NaN for thresholded images
numZero = find(ave < threshold);
threshold_ave = ave; 
threshold_ave(numZero) = NaN;
minThreshold = threshold;

% write average image
aveFilePrefix = sprintf('%s_ave',outfilePrefix(1:end-5));
aveImg.fileprefix = aveFilePrefix;
aveImg.img = ave;
if spmVersion==2
    bw_write_spm_analyze(aveImg, aveImg.fileprefix);
elseif spmVersion==8
    save_nii(aveImg, aveImg.fileprefix)
end

% save permutation distribution 
matfilename = sprintf('%s.mat',aveFilePrefix);
tt.listFile = listFile;
tt.num_permutations = num_perm;
tt.num_subjects = numSubjects;
tt.distribution = permDist;
save(matfilename, '-struct', 'tt')
fprintf('writing permuation results to %s\n', matfilename);

filename = sprintf('%s_alpha=%g',outfilePrefix,alpha);
aveImg.fileprefix = filename;
aveImg.img = ave;
if spmVersion==2
    bw_write_spm_analyze(aveImg, aveImg.fileprefix);
elseif spmVersion==8
    save_nii(aveImg,aveImg.fileprefix);
end

filename = sprintf('%s.img',aveFilePrefix);

% call separate routine for plotting - this allows for changing threshold
% later without recomputing the permutation...

bw_plot_permutation(filename, matfilename, alpha, displaycheck);

return;


