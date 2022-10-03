%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% function bw_write_ctf_shape(fileprefix, pts, na, le, re, voxelSize)
%%
%%  written by D. Cheyne, Oct 2012
%%  script to save a point cloud as a CTF shape file in HEAD coordinates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [shapeFile, shapeInfoFile] = bw_write_ctf_shape(fileprefix, pts, na, le, re, voxelSize)

    npts = size(pts,1);
    fprintf('writing %d points to shape files (%s.shape, %s.shape_info)\n', ...
            npts, fileprefix, fileprefix);

    % write shape_info fi
    shapeInfoFile = strcat(fileprefix,'.shape_info');

    fid = fopen(shapeInfoFile,'w');

    fprintf(fid, 'MRI_Info\n');
    fprintf(fid, '{\n');
    fprintf(fid, 'VERSION:     1.00\n\n');
    fprintf(fid, 'NASION:      %d   %d   %d\n', na(1), na(2), na(3) );  
    fprintf(fid, 'LEFT_EAR:    %d   %d   %d\n', le(1), le(2), le(3) );  
    fprintf(fid, 'RIGHT_EAR:   %d   %d   %d\n\n', re(1), re(2), re(3) );  
    fprintf(fid, 'MM_PER_VOXEL_SAGITTAL:   %.6f\n', voxelSize );  
    fprintf(fid, 'MM_PER_VOXEL_CORONAL:    %.6f\n', voxelSize );  
    fprintf(fid, 'MM_PER_VOXEL_AXIAL:      %.6f\n\n', voxelSize );  
    fprintf(fid, 'COORDINATES:      HEAD\n' );  
    fprintf(fid, '}\n');

    fclose(fid); 

    % write shape data

    shapeFile = strcat(fileprefix,'.shape');
    fid = fopen(shapeFile,'w');

    fprintf(fid, '%d\n', npts);

    for i=1:npts
        fprintf(fid,'%6.2f %6.2f  %6.2f\n', pts(i,1), pts(i,2), pts(i,3));
    end

    fclose(fid);

end
    
    



