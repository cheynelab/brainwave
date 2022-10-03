function [minRange maxRange] = bw_average_images(aveList, aveName)
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% function grand_average_analyze_files(listFile, outFile, [writeLAS])
% list file is list of analyze files (.img) to average
% fileprefix is name of output analyze file omitting extension

%  D. Cheyne April, 2011  - replaces bw_grand_average_analyze_files() 
% 

% get array of file names to process

numSubjects = size(aveList,1);

file = char( aveList(1,:) );

% check file type
[path name ext] = bw_fileparts(file);

minRange = 0.0;
maxRange = 0.0;

if strncmp(ext,'.txt',4) == 1
    
    % average and save surface images (text files)
    t = load(file);
    numVoxels = size(t,1);
    ave = zeros(numVoxels,1);
    fid = fopen(aveName,'w');
    
    for j=1:numSubjects
        file = char( aveList(j,:) );
%         fprintf('reading file %s\n', file);
        t = load(file);
        
        % return data range 
        mx = max(t);
        if mx > maxRange
            maxRange = mx;
        end
        mn = min(t);
        if mn < minRange
            minRange = mn;
        end
        
        ave = ave + t;      
    end   
    ave = ave ./ numSubjects;
    fprintf(fid,'%.6f\n',ave);
    fclose(fid);
    
elseif strncmp(ext,'.nii',4) == 1
   
    for j=1:numSubjects

        file = char( aveList(j,:) );
        fprintf('reading file %s\n', file);

        image = load_nii(file);
        % use first file to get header paramaters
        % then do consistency check as going through the other files

        mx = max(image.img);
        if mx > maxRange
            maxRange = mx;
        end
        mn = min(image.img);
        if mn < minRange
            minRange = mn;
        end
        
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
    save_nii(aveImg, aveName);
     
else
    fprintf('can only average NIfTI images or ASCII (surface) files\n');
end

return;


