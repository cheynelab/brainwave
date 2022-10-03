%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [new_coords] = bw_peak_search(normalized_image, mni_coord, searchRadius)
%
%
% (c) D. Cheyne, 2015. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%
% Nov, 2015 - moved peak search loop from bw_unwarp_mni_coord to separate routine, so that
% search can be done directly on MNI image, then unwarped, rather than manipulating file names to
% find the unwarped image. May change the exact peak found?
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [new_coords] = bw_peak_search(normalized_image, mni_coord, searchRadius)
        
    new_coords = mni_coord;
    
    % search source image for peak voxel
    % use exact coordinate as starting point
    fprintf('Searching for closest peak within %g mm in image %s\n',searchRadius, normalized_image );

    nii = load_nii(normalized_image);
    hdr = nii.hdr;
    img = nii.img;

    xdim = hdr.dime.dim(2);
    ydim = hdr.dime.dim(3);
    zdim = hdr.dime.dim(4);  
    imageResolution = hdr.dime.pixdim(2);   % code assumes images is isotropic 

    SPM_ORIGIN(1) = hdr.hist.originator(1);
    SPM_ORIGIN(2) = hdr.hist.originator(2);
    SPM_ORIGIN(3) = hdr.hist.originator(3);

    mni_voxel = mni_coord/imageResolution;
    peakLoc = round(mni_voxel + SPM_ORIGIN);
    
    % get SR in voxels
    sr = searchRadius / imageResolution;
    sr = ceil(sr);

    img = abs(img);  % in case image contains negative values


    orig_val = img(peakLoc(1), peakLoc(2), peakLoc(3));
    maxval = orig_val;  % we only care about values larger than this
    original_peakLoc = peakLoc;
    x = peakLoc(1);
    y = peakLoc(2);
    z = peakLoc(3);

    fprintf('\n ** Searching within %g mm (%d voxels) radius around original voxel (%g %g %g), val = %g)\n', ...
            searchRadius, sr, mni_coord, orig_val); 
    found_larger = false;
    for xx= x-sr:x+sr
        for yy= y-sr:y+sr           
            for zz=z-sr:z+sr           
                if (xx < 1 || xx > xdim); continue; end;
                if (yy < 1 || yy > ydim); continue; end;
                if (zz < 1 || zz > zdim); continue; end;
                v = img(xx,yy,zz);
                if (v > maxval)
                    maxval = v;
                    peakLoc = [xx yy zz];
                    found_larger = true;
                end
            end
        end

    end

    if ( found_larger )

        %  ** convert back to mni_coords in mm
        mni_voxel = peakLoc - SPM_ORIGIN;
        new_coords = mni_voxel * imageResolution;
                
        dist = norm((peakLoc*imageResolution) - (original_peakLoc*imageResolution));
        fprintf(' ** Found larger peak (val= %g) at voxel (%g %g %g), distance to original location = %g mm\n\n', ...
            maxval, new_coords, dist); 
    else
        fprintf(' ** Larger peak not found within search radius **\n\n');         
    end
end
