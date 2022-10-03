function [filename, threshold] = bw_permute_surface_images(filelist, outputName, perm_options)
%
% new version of permutation test for surface images (text files)
%
% (c) D. Cheyne, 2014. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

filename = [];
threshold = [];

numSubjects = size(filelist,1);

% determine # of permutations possible
max_permutations = 2^numSubjects;

% permutation type 
% 1 = max_statistic (omnibus)
% 2 = uncorrected 


alpha = perm_options.alpha;
roi_bounds = perm_options.roi;
num_perm = perm_options.num_permutations;
showNeg = perm_options.showNeg;
showDist = perm_options.showDist;


for j=1:numSubjects
    file = strtrim(char( filelist(j,:) ));
    fprintf('reading file %s\n', file);
    data(j,:) = load(file);
end

% build unthresholded average 
ave = mean(data,1);
num_voxels = size(ave,2);

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
global_min = 0.0;

for k=1:numSubjects
    tt = data(k,:)';   % data as single column vector
    if min(tt) < global_min
        global_min = min(tt);
    end
    
    nn = nn + 1;
    dataMat(nn,:) = tt;
    nn = nn + 1;
    dataMat(nn,:) = -tt;
end
odd_columns = 1:2:numSubjects*2;

% do permutation

% get threshold for specified significance level
cutoff = (1.0 - alpha) * num_perm;
cutoff_bin = floor(cutoff);

if perm_options.corrected
                
    
    fprintf('**************************************************\n');
    fprintf('Computing maximal statistic permutation threshold\n');
    fprintf('**************************************************\n');

    permDist = zeros(1,num_perm);
    
    tic;
    for k=1:num_perm
        if (mod(k,8) == 1)
            disp(sprintf('Computing permutation: %d of %d',k-1, num_perm));
        end
        % use odd numbered elements of perm table to select images for this iteration
        cols = perm_table(odd_columns, k);
        thisAve = mean(dataMat(cols,:));        % compute mean image 
        
        thisMax = max(abs(thisAve));            % compute maximal statistic for single perm. distribution
        permDist(k) = thisMax;                  % add to distribution
        
    end
    toc;

    sortedDist = sort(permDist);
    threshold = sortedDist(cutoff_bin);
   
    % here we are testing for significance of either positive or negative values 
    % although only sign. positive values are in the direction of the requested
    % contrast
    sigvox = find(abs(ave) >= threshold);
    numsig = size(sigvox,2);
    fprintf('Threshold for P < %g = %.3f (# of sig. voxels in distribution = %d)\n', alpha, threshold, numsig);

    if (numsig == 0)
        fprintf('No significant voxels at P < %g\n', alpha);
        maxValInImage = max(ave);      
        tidx = find(sortedDist < maxValInImage);
        maxBin = max(tidx);
        Pvalue = 1 - (maxBin/num_perm);
        fprintf('Maximum value in image corresponds to P = %g\n', Pvalue);
        return;
    end

    % if showNeg == true shows negative voxels that are greater than threshold 
    % otherwise tests significance of only positive voxels (e.g.,  A > B contrast)
    % even though perm. distribution can be based on both pos and neg values 

    if ~showNeg
        if ( max(ave) < threshold)
            fprintf('*** No significant voxels for this contrast ***\n');        
            return;
         end
    end

    % show the permutation distribution

    if showDist
        figure('Name','Permuation Test');
        hold on;  % needed to eliminate hist from creating new plot
        hist(sortedDist);
        tstr = sprintf('Permutation Distribution: Thresh. = %.2f (P < %.3f)', threshold, alpha);
        tt = title(tstr);
        set(tt,'Interpreter','none','fontsize',12);
        ax = axis;
        line_h1 = line([threshold threshold],[ax(3) ax(4)]);
        set(line_h1, 'Color', [1 0 0]);
        hold off;
    end
    
    % set non-sig voxels to NaNs
    tidx = find(abs(ave) < threshold);
    threshold_ave = ave; 
    threshold_ave(tidx) = 0.0;

    
else
    fprintf('**************************************************\n');
    fprintf('Computing voxelwise (uncorrected) threshold\n');
    fprintf('**************************************************\n');
    
    % voxel wise test
    permDist = zeros(num_perm, num_voxels);
   
    tic;
    for k=1:num_perm
        if (mod(k,8) == 1)
            disp(sprintf('Computing permutation: %d of %d',k-1, num_perm));
        end
        
        % use odd numbered elements of perm table to select images for this iteration
        cols = perm_table(odd_columns, k);
        thisAve = mean(dataMat(cols,:));
        % voxelwise, save whole permuted image
        % i.e., each voxel has its own perm. distn.
        % take absolute to flip neg half of perm is
        permDist(k,1:num_voxels) = abs(thisAve(1:num_voxels)); 
        
    end

    % sort the distributions for each voxel (columns)
    % sort along columns, since each row is a value in permutation, 
    % and each column is the permuted values for that voxel 
    sortedDist = sort(permDist,1);
    
    % get threshold for each voxel

    c = cutoff_bin;
    threshold_ave = ave;
       
    numsig = 0.0;
    for j=1:num_voxels
        
        % get perm distn for voxel j
        voxelThresh = sortedDist(cutoff_bin,j);       
        
        val = abs(threshold_ave(j));
        if val < voxelThresh
            threshold_ave(j) = 0.0;
        else
            numsig = numsig + 1;
        end        
        
        threshList(j) = voxelThresh;  % list of thresholds
    end
    
    % pass minimum threshold to display
    threshold = min(threshList);
    max_threshold = max(threshList);

    fprintf('Minimum threshold across all voxels for P < %g = %.3f (# of sig. voxels = %d)\n', alpha, threshold, numsig);
    fprintf('Maximum threshold across all voxels for P < %g = %.3f\n', alpha, max_threshold);
    toc; 
    
end

if ~perm_options.corrected && global_min >= 0.0
    fprintf('********************************************************************************************************\n');
    fprintf('Warning: Voxelwise (uncorrected) permutation test is not valid for images with only positive values. ...\n');
    fprintf('********************************************************************************************************\n');
end


% warn if only neg sig values
if max(threshold_ave) < 0.0
    fprintf('*** note image contains only negative significant values ***\n');
end

filename = sprintf('%s_alpha=%g.txt',outputName,alpha);

fid = fopen(filename,'w');
fprintf(fid,'%.6f\n',threshold_ave);
fclose(fid);

return;


