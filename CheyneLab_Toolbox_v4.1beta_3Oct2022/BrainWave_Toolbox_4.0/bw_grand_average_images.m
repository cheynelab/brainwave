function bw_grand_average_images(fileList, aveName)
%       BW_GRAND_AVERAGE_IMAGES 
%
%   function bw_grand_average_images(fileList, aveName)
%
%  replaces bw_grand_average_analyze_files - takes cellstr as input instead
%  of file
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% function grand_average_analyze_files(listFile, outFile, [writeLAS])
% list file is list of analyze files (.img) to average
% fileprefix is name of output analyze file omitting extension


if ~exist('writeLAS','var')
    writeLAS = false;
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

% substitute average data
if writeLAS
    fprintf('writing results flipped to LAS...\n');
    ave = flipdim(ave, 1); % flip left -> right
    fileprefix = strcat(listFile(1:end-5),'_LAS');
end

aveImg.fileprefix = fileprefix;
aveImg.img = ave;

% write_spm_analyze retains the original SPM origin!
if spmVersion==2
    file = strcat(listFile(1:end-5),'.img');
    bw_write_spm_analyze(aveImg, file);
elseif spmVersion==8
    file = strcat(listFile(1:end-5),'.nii');
    save_nii(aveImg, file)
end 

% if displaycheck
    bw_mip_plot_4D(file,0);
% end

return;


