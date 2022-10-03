function bw_permute_image_files(listFile, alpha, max_permutations, roi_bounds, showNeg)
%       BW_PERMUTE_ANALYZE_FILES
%
%   function bw_permute_image_files(listFile,alpha, max_permutations)
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
% function bw_permute_analyze_files(listFile, [alpha], [max_permutations], [roi_bounds])
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
%
%
%  D. Cheyne     April, 2011 - new version, replaces bw_permute_analyze_files
%
%               May, 2011 - fixed bug that prevented finding sig. negative
%               voxels in difference images. 
%   
%               Dec 13, 2011 - correction to sig test for differential
%               images when not making a one-tailed contrast. Needed to pass
%               the showNeg flag to tell routine to include negative values in
%               images as significant.
%
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


if ~exist('roi_bounds','var')
    roi_bounds = [];
end

if ~exist('showNeg','var')
    showNeg = true;
end

% get array of file names to process
filelist = bw_read_list_file(listFile);

% check file type
file = char( filelist(1,:) );
[image fileType] = bw_read_SPM_file(file);
if (fileType == 0)
    fprintf('Can only average Analyze or NIfTI files...\n');
    return;
end

numSubjects = size(filelist,1);

for j=1:numSubjects
    
    file = char( filelist(j,:) );
    fprintf('reading file %s\n', file);
    [image fileType] = bw_read_SPM_file(file);

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
% aveMax = max(max(max((abs(ave)))));

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
    thisAve = mean(dataMat(cols,:));      % compute mean image
    thisMax = max(abs(thisAve));
    permDist(k) = thisMax;      % permute maximum value of the mean
end
toc;

sortedDist = sort(permDist);

% get threshold for specified significance level
cutoff = (1.0 - alpha) * num_perm;
cutoff_bin = floor(cutoff);
threshold = sortedDist(cutoff_bin);

% here we are testing for significance of either positive or negative values 
% although only sign. positive values are in the direction of the requested
% contrast
sigvox = find(abs(ave) >= threshold);
numsig = size(sigvox,1);
fprintf('Threshold for P < %g = %.3f (# of sig. voxels in distribution = %d)\n', alpha, threshold, numsig);

% show the permutation distribution
figure('Name','Permuation Test');
hold on;  % needed to eliminate hist from creating new plot
hist(sortedDist);

tstr = sprintf('Permutation Distribution: Thresh. = %.2f (P < %.3f)', threshold, alpha);
tt = title(tstr);
set(tt,'Interpreter','none','fontsize',12);
if (numsig == 0)
    fprintf('No significant voxels at P < %g\n', alpha);
    maxValInImage = max(max(max(abs(ave))));
    tidx = find(sortedDist < maxValInImage);
    maxBin = max(tidx);
    Pvalue = 1 - (maxBin/num_perm);
    fprintf('Maximum value in image corresponds to P = %g\n', Pvalue);
    return;
end

ax = axis;
line_h1 = line([threshold threshold],[ax(3) ax(4)]);
set(line_h1, 'Color', [1 0 0]);
hold off;

% set non-sig voxels to NaN for thresholded images

% D. Cheyne, July 2011 - change to logic 
% if plotNeg == true shows negative voxels that are greater than threshold 
% otherwise tests significanct of only positive voxels (e.g.,  A > B contrast)
% even though perm. distribution is based on both pos and neg values (e.g.,
% for difference images that have noise distributed about zero.

% Dec 2011 - showNeg flag is now passed from calling routine
%
if ~showNeg
    if (max(max(max(ave))) < threshold)
        fprintf('*** No significant voxels for this contrast ***\n');        
        return;
     end
end

% set non-sig voxels to NaNs
tidx = find(abs(ave) < threshold);
threshold_ave = ave; 
threshold_ave(tidx) = NaN;

% warn if only neg sig values
if max(max(max(threshold_ave))) < 0.0
    fprintf('*** note image contains only negative significant values ***\n');
end

% write average image
outfilePrefix = strrep(listFile,'.list','');


% save and display thresholded image
fileprefix = sprintf('%s_alpha=%g',outfilePrefix,alpha);
aveImg.img = threshold_ave;
if fileType==1
    filename = sprintf('%s.img',fileprefix);
    aveImg.fileprefix = fileprefix;
    bw_write_spm_analyze(threshold_ave, aveImg.fileprefix);
elseif fileType==2
    filename = sprintf('%s.nii',fileprefix);
    save_nii(aveImg,filename);
end

bw_mip_plot_4D(filename, threshold);



return;


