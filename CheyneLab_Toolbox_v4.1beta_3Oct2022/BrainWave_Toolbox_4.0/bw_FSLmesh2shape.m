function [shapeFile] = bw_FSLmesh2shape(meshFile, matFile, filePrefix)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% function bw_FSLmesh2shape(meshFile, matFile, [filePrefix] )
%%
%%  script to run convert an FSL mesh (.off) file to CTF shape file.  
%%  Requires the  <SUBJ_ID>.mat file to get conversion to CTF head coordinates
%%  if filePrefix not specified uses the meshfile name
%%
%%  ** note on left-right flipping
%%  due to output of FSL .off meshes in LAS orientation we 
%%  left-right flip the images automatically.  Should be OK as long we don't allow 
%%  conversions with FSL Versions 4.0 or earlier
%%
%%  written by D. Cheyne, Oct 2012
%%  modified Jan, 2017 - need to be able to read .vtk format for FSL version 5.0.10 
%%  can use existing function bw_readMeshFile
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if ~exist('filePrefix','var')        
        [path, name, ~] = bw_fileparts(meshFile);
        filePrefix = fullfile(path,name);
    end

    [~, meshdata] = bw_readMeshFile(meshFile);
    vertices = meshdata.vertices';
    Nvertices = size(vertices,2);
    
    clear meshdata;
    
    M = [];
    le = [];
    re = [];
    na = [];
    mmPerVoxel = 0;

    load(matFile);  % sets above variables    
    % Note2: from BET website:
    % ....The .off Geomview mesh output files contain vertex co-ordinates in 
    % real-world space with the co-ordinate axis in the corner of the image 
    % - i.e., the values are the integer voxel co-ordinates multiplied by the 
    % voxel size values ...
    %
    % scale back to voxels before applying transformation and transpose to Nx3

    vertices = vertices' ./ mmPerVoxel;

    % convert mesh from LAS back to RAS. According to Marc's notes 
    % FSL voxels indexed from 0 to 255 so subtract from 255
    %
    vertices(:,1) = 255 - vertices(:,1);
    
    % convert vertices to head coordinate system and scale to cm
    pts = [vertices ones(Nvertices,1)];     % add ones
    headpts = pts*M;                        % convert to MEG coords
    clear pts;

    headpts(:,4) = [];                      % remove ones
    headpts = headpts * 0.1;                % scale to cm  
    

    % headpts is now a N x 3 array of surface points in cm in MEG coordinates


    % create CTF shape files - have to put fiducials back in CTF coords
    % since Fiducials indexted 1 to 256, subtract from 256
    na(2) = 256 - na(2); le(2) = 256 - le(2); re(2) = 256 - re(2);
    na(3) = 256 - na(3); le(3) = 256 - le(3); re(3) = 256 - re(3);
    
    [shapeFile, ~] = bw_write_ctf_shape(filePrefix, headpts, na, le, re, mmPerVoxel);  
    
end



