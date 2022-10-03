function aveFileName = bw_grand_average_image_files(listFile, plotImage)
%       BW_GRAND_AVERAGE_ANALYZE_FILES 
%
%   function bw_grand_average_image_files(listFile)
%
%   DESCRIPTION: Grand averages the given list of normalized images
%   (listFile), save the resulting image to the name given by fileprefix
%   and then display the image if displaycheck has been selected.
%   Optionally the orientation of the images can be made LAS using
%   writeLAS.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% function grand_average_analyze_files(listFile, outFile, [writeLAS])
% list file is list of analyze files (.img) to average
% fileprefix is name of output analyze file omitting extension

%  D. Cheyne April, 2011  - replaces bw_grand_average_analyze_files() 
% 


% get array of file names to process

filelist = bw_read_list_file(listFile);

numSubjects = size(filelist,1);

if ~exist('plotImage','var')
    plotImage = true;
end

% check file type
file = char( filelist(1,:) );

[image fileType] = bw_read_SPM_file(file);
if (fileType == 0)
    fprintf('Can only average Analyze or NIfTI files...\n');
    return;
end

for j=1:numSubjects
    
    file = char( filelist(j,:) );
    fprintf('reading file %s\n', file);
       
    [image fileType] = bw_read_SPM_file(file);
    
    % use first file to get header paramaters
    % then do consistency check as going through the other files
    
    if (j==1)
        aveImg = image;         
        ave = image.img;
        hdr = image.hdr;
        
        xdim1 = int32(hdr.dime.dim(2));
        ydim1 = int32(hdr.dime.dim(3));
        zdim1 = int32(hdr.dime.dim(4));
        xres1 = double(hdr.dime.pixdim(2));
        yres1 = double(hdr.dime.pixdim(3));
        zres1 = double(hdr.dime.pixdim(4));        

    else
        ave = ave + image.img;

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

end

ave = ave ./ numSubjects;

aveImg.img = ave;

% write_spm_analyze retains the original SPM origin!
% eventually replace with routine bw_write_spm_image..

if fileType==1
    aveImg.fileprefix = strrep(listFile,'.list','');
    bw_write_spm_analyze(aveImg, aveImg.fileprefix);
    aveFileName = strcat(aveImg.fileprefix,'.img');
elseif fileType==2
    aveFileName = strrep(listFile,'.list','.nii');
    save_nii(aveImg, aveFileName);
end 

if (plotImage)
    bw_mip_plot_4D(aveFileName,0);
end

return;


