%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% bw_Tal2MEG( dsName, tal_coords, params, vs_options )
%
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [ctf_coords] = bw_Tal2MEG( dsName, tal_coords, params, vs_options)
        
    ctf_coords = [];
    
    fprintf('\nUnwarping Talaraich coordinates %g %g %g to MEG coordinates for dataset %s\n\n', ...
        tal_coords, dsName);
        
    if ~exist(dsName,'dir')
        fprintf('cannot locate %s - check path and current working directory\n', dsName)
        return;
    end
    
    [ds_path, ds_name, subject_ID, mri_path, mri_filename] = bw_parse_ds_filename(dsName);

    if isempty(mri_filename) || isempty(subject_ID)
        fprintf('Could not get MRI file or subject ID for this subject\n');
        return;
    end
       
    mni_coord = bw_tal2mni(tal_coords);  % convert back to MNI 
        
    bb = params.boundingBox;        
    sn3dmat_file = sprintf('%s%s%s_resl_%g_%g_%g_%g_%g_%g_sn3d.mat',...
            mri_path,filesep, subject_ID, bb(1), bb(2),bb(3),bb(4),bb(5),bb(6));  
  
    % New method.  June 9, 2012

    % Get exact coordinate using passed parameters to estimate the unwarped
    % origin, rather than getting it from the image.  
    % 
    svlResolution = params.stepSize * 10.0;
    bb = params.boundingBox * 10.0;        
    dims(1) = size(bb(3):svlResolution:bb(4),2); % left -> right (sagittal - LAS )
    dims(2) = size(bb(1):svlResolution:bb(2),2); % posterior -> anterior (coronal) 
    dims(3) = size(bb(5):svlResolution:bb(6),2); % bottom -> top (axial)

    % origin is set to center of image by svl2nifti.m
    origin = [round(dims(1)/2) round(dims(2)/2) round(dims(3)/2)];
    % save_nii saves origin in mm
    unwarped_origin_mm = -(origin-1) * svlResolution;
   
    VU_mat = diag([svlResolution svlResolution svlResolution 1]);
    VU_mat(1:3,4) = unwarped_origin_mm;
        
    % Get coord in mm relative to unwarped origin
    orig_coord_mm = bw_get_orig_coord(mni_coord, sn3dmat_file);
    
    % Convert to RAS voxel coordinates
    UV_mat = inv(VU_mat);             
    orig_coord_vox =  UV_mat * [orig_coord_mm 1]';
    orig_coord_vox = round(orig_coord_vox(1:3))';
    
    % left over code??
%     bb_origin_vox = ([bb(4) -bb(1) -bb(5)] / svlResolution);
%     coord = ((orig_coord_vox - bb_origin_vox)) * svlResolution;
%     ctf_coord = [coord(2) -coord(1) coord(3)] * 0.1;    
    
    
    % if search option chosen, search through source images for peak voxel,
    % around the exact coordinate 
    if vs_options.useSR
        % search source image for peak voxel
        % use exact coordinate as starting point
        fprintf('Searching for closest peak within %g mm at latency = %g s\n', ...
            vs_options.searchRadius, vs_options.searchLatency);
 
        % set beamformer parameters here from vs_options
    
        if vs_options.searchMethod == 'ERB'
            params.beam.use = 'ERB';
            params.beam.latencyStart = vs_options.searchLatency; % convert to seconds
            params.beam.latencyEnd = params.beam.latencyStart;
        else
            params.beam.activeStart = vs_options.searchActiveWindow(1);
            params.beam.activeEnd = vs_options.searchActiveWindow(2);
            params.beam.baselineStart = vs_options.searchBaselineWindow(1);
            params.beam.baselineEnd = vs_options.searchBaselineWindow(2);
            params.beam.use = vs_options.searchMethod;
            params.beam.no_step = 0;
            params.beam.active_step = 0;
        end    
    
        imageList = bw_make_beamformer(dsName, params);
        
        bw_svl2nifti(imageList);
        unwarpedFile = strrep(imageList,'.svl','.nii');       
        fprintf('Searching unwarped image file %s\n',imageList);
                
        nii = load_nii(unwarpedFile);
        hdr = nii.hdr;
        img = nii.img;

        xdim = hdr.dime.dim(2);
        ydim = hdr.dime.dim(3);
        zdim = hdr.dime.dim(4);        
        
        % get SR in voxels
        sr = vs_options.searchRadius / svlResolution;
        sr = ceil(sr);

        img = abs(img);  % in case of pseudo-T image

        % - note that img indices need to be offset by one   
        peakLoc = orig_coord_vox + 1;
        
        orig_val = img(peakLoc(1), peakLoc(2), peakLoc(3));
        maxval = orig_val;  % we only care about values larger than this
        original_peakLoc = peakLoc;
        x = peakLoc(1);
        y = peakLoc(2);
        z = peakLoc(3);
              
        fprintf('\n ** Searching within %g mm (%d voxels) radius around original voxel (%g %g %g), val = %g)\n', ...
                vs_options.searchRadius, sr, orig_coord_vox, orig_val); 
        found_larger = false;
        for xx= x-sr:x+sr
            for yy= y-sr:y+sr           
                for zz=z-sr:z+sr           
                    if (xx < 1 || xx > xdim) continue; end;
                    if (yy < 1 || yy > ydim) continue; end;
                    if (zz < 1 || zz > zdim) continue; end;
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
            
            % set back relative to nii origin       
            orig_coord_vox = peakLoc - 1;
            
            dist = norm((peakLoc*svlResolution) - (original_peakLoc*svlResolution));
            fprintf(' ** Found larger peak (val= %g) at voxel (%g %g %g), distance to original location = %g mm\n\n', ...
                maxval, orig_coord_vox, dist); 
        else
            fprintf(' ** Larger peak not found within search radius.  Using exact coordinate...\n\n');         
        end
    end

    % translate into CTF space and convert to cm
  
    % subtract one to get to svl indices
    bb_origin_vox = ([bb(4) -bb(1) -bb(5)] / svlResolution);
    coord = ((orig_coord_vox - bb_origin_vox)) * svlResolution;
    ctf_coords = [coord(2) -coord(1) coord(3)] * 0.1;
    
end
