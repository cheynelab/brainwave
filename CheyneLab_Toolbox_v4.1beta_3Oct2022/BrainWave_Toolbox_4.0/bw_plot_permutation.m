function bw_plot_permutation(averageFile, matfile, alpha, displaycheck, outfile)
%       BW_PLOT_PERMUTATION 
%
%   function bw_plot_permutation(averageFile, matfile, alpha, displaycheck, outfile)
%
%   DESCRIPTION: Thresholds and plots the analyze image from an
%   existing permutation file specified by averageFile along with the 
%   accompanying .mat file (matfile), and significance value (alpha).
%   Whether the function plots results depends on displaycheck. Users can 
%   optionally specify whether to prefix the name of the save analyze image 
%   (outfile).   
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function plot_permutation(averageFile, matfile, alpha, [outfile])
% 
% D. Cheyne, March 2009
% set threshold and plot analyze image using existing permutation file
%
% [outfile] - save thresholded image using this prefix
%                  
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



fprintf('reading average file %s\n', averageFile);

[path name ext] = bw_fileparts(averageFile);
if ext == '.img'
    image = bw_read_spm_analyze(averageFile);
elseif ext == '.nii'
    [image.hdr, image.filetype, image.fileprefix, image.machine] = load_nii_hdr(file);   
    [image.img,image.hdr2] = load_nii_img(image.hdr,image.filetype,image.fileprefix,image.machine);
else
    fprintf('Can only average Analyze or NIfTI files...\n');
    return;
end
 
ave = image.img;
    
fprintf('reading permutation from %s\n', matfile);
load(matfile);

minP = 1 / num_permutations;
if ( minP > alpha)
    fprintf('Insufficient number of subjects apply threshold at P < %g \n', alpha);
    return;
end

sortedDist = sort(distribution);

% set all voxels below alpha level to NaN
cutoff = (1.0 - alpha) * num_permutations;
cutoff_bin = floor(cutoff);
threshold = sortedDist(cutoff_bin);

sigvox = find(ave >= threshold);
numsig = size(sigvox,1);
if (numsig == 0)
    fprintf('No significant voxels at p < %g\n', alpha);
    return;
end

fprintf('Threshold for p < %g = %.3f (# of sig. voxels = %d)\n', alpha, threshold, numsig);

% plot thresholded image
%plot_glass_brain(averageFile,threshold,-1);
% if displaycheck  
    bw_mip_plot_4D(averageFile,0);

    % show the permutation distribution and 0.05 cutoff
    figure;
    hold on;  % needed to eliminate hist from creating new plot?
    hist(distribution);
    tstr = sprintf('Permutation Distribution (thresh. = %.2f)', threshold);
    tt = title(tstr);
    set(tt,'Interpreter','none','fontsize',12);
    ax = axis;
    line_h1 = line([threshold threshold],[ax(3) ax(4)]);
    set(line_h1, 'Color', [1 0 0]);
    hold off;
% end           

    % write average image and thresholded average files.
% if exist('outfile','var')
%     zeroVox = find(ave < threshold);
%     ave(zeroVox) = NaN;
%     image.fileprefix = outfile;
%     image.img = ave;
%     bw_write_spm_analyze(image, image.fileprefix);
% end

return;


