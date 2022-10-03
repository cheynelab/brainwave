function normalized_imageList = bw_normalize_images(mriFile, imageList, spm_options)
%       BW_NORMALIZE_IMAGES
%
%   function [normalized_list] = bw_normalize_images(mriFile, listFile, spmVersion)
%
%   DESCRIPTION:Using the MRI file specified by mriFile this function will
%   normalize the images specified in listFile using SPM2 or SPM8 depending
%   on the variable spmVersion. The list of names of the normalized images
%   is output in normalized_list and fulllist (where fulllist contains the
%   filename's full paths). The function also outputs the bounding box used
%   (bb).
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% routine to normalize the .svl files after creating them
% based on normalize_svl_batch() modified to work with BrainWave
%
% D. Cheyne, Dec. 2010.
% 
% D. Cheyne Mar 13, 2011
%      modified to work properly with SPM2 or SPM8  (currently still saves
%      normalized images as Analyze for back-compatibility)
%
% D. Cheyne, April, 2011
%      now works with SPM8 and NIfTI files 
%
% D. Cheyne, Feb, 2012 
%      modified to work independently of .mri files.
%
% D. Cheyne, Oct, 2013
%      made inner loop to normalize a single svl a separate m-file for standalone use 
%
% D. Cheyne, Mar, 2014
%      replaced list files with cellstr arrays...

    % turn off annoying FINITE is obsolete warning
    warning('off','MATLAB:FINITE:obsoleteFunction');
      
    normalized_imageList = [];
    for i=1:size(imageList,1)
        
        svlFile = deblank(char(imageList(i,:)));      
                
        % normalize image - returns _fullpath_ name!
        normalizedFileName = bw_normalize_svl(mriFile, svlFile, spm_options);
        
        if isempty(normalizedFileName)
            return;
        end
        
        % append name with full path to the returned cellstr array
        c_list{i} = normalizedFileName;
        
    end
    
    % return as char array
    normalized_imageList = c_list';
  
    fprintf('....all done!\n');

end
