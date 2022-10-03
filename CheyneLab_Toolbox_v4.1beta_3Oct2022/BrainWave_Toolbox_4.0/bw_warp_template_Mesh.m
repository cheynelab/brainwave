
function [mesh fileName] = bw_warp_template_Mesh( mriFile, templateMesh )
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [mesh fileName] = bw_warp_template_Mesh( mriFile, templateMesh )
%
% script to warp the Colin-27 mni template mesh to an individual's MRI using SPM normalization
%
% (c) D. Cheyne, 2015. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    mesh = [];
    fileName = '';
    % load template mesh 
    fprintf('\nLooking for template mesh %s\n', templateMesh);
    mesh = load(templateMesh);

    fprintf('Warping template to MEG coordinates for %s\n', mriFile);
    vtemp = zeros(size(mesh.normalized_vertices,1), 4);

    % convert ch2 template mesh MNI coordinates to NIfTI voxels in the
    % subject's original NIfTI MRI file using MNI to RAS transform

    tic
    
    % need sn3d file and original image used to generate it
    [sn3dmat_file, reslicedMRI] = getDefaultNormalization(mriFile);    

    vlist = mesh.normalized_vertices(:,1:3);
    
    % John Ashburner's algorthm returns unwarped coord in voxels if passed
    % original image using both linear and non-linear transform
    tic
    vlist_RAS = bw_get_orig_coord(vlist, sn3dmat_file, reslicedMRI);

    % translate into CTF coords and convert to cm
    % there are two ways to this
    
    % use the RAS_to_MEG transformation matrix in .mat
    % file for the resliced MRI 

    matFile = strrep(reslicedMRI,'.nii','.mat');
    
    if ~exist(matFile,'file')
        fprintf('Cannot find .mat file for resliced MRI. Need to re-run spatial normalization.\n');
        return;
    end
    
    tmat = load(matFile);

    vlist_RAS = [vlist_RAS ones(size(vlist,1),1) ];
    vlist_cm = (vlist_RAS * tmat.M) * 0.1;
   
    mesh.vertices = single(vlist_cm(:,1:3));
    toc

    % we now need to convert vertices in MEG space to RAS coords for the subject's
    % original MRI image (SUBJ_ID.nii) if we want to view them in MRIViewer
    fprintf('Saving voxel coordinates for original NIfTI image %s\n', mriFile);
    matFile = strrep(mriFile,'.nii','.mat');
    tmat = load(matFile);

    %  MEG vertices have to be in mm
    vlist_RAS = [ (mesh.vertices * 10.0) ones(size(vlist,1),1) ];
    vlist_RAS_original = vlist_RAS * inv(tmat.M);

    mesh.mri_vertices = single( round(vlist_RAS_original(:,1:3)) );
    
    % Now have the mesh with new (warped) RAS and MEG coordinates
    % have to recompute the surface normals for the reshaped mesh

    % for each vertex find its adjoining faces and take the mean of each face
    % normal as the normal for that vertex
    fprintf('computing vertex normals ...\n');

    if exist('bw_computeFaceNormals','file') == 3
        % use mex function       
        normals = bw_computeFaceNormals(double(mesh.vertices'), double(mesh.faces')); 
        normals = normals';
    else  
        % matlab code to get vertices
        % get normal for each vertex.  This is the mean of the surrounding face normals
        fprintf('mex function bw_computeFaceNormals not found. Computing normals using m-file...\n');
        normals = zeros(nvoxels,3);

        for i=1:size(vertices,1)  
            voxels(i,1:3) = vertices(i,1:3);
            faceIdx = i-1;  % since face numbers start at zero
            [idx, ~] = find(faces == faceIdx);
            meanVertex = zeros(1,3);
            numFaces = length(idx);
            for j=1:numFaces
                faceNo = idx(j);
                v1 = vertices(faces(faceNo,1)+1,:);   % add 1 to vertex number since matlab array indices start at 1 not zero.
                v2 = vertices(faces(faceNo,2)+1,:);
                v3 = vertices(faces(faceNo,3)+1,:);
                V = cross((v1-v2),(v2-v3));
                V = V / norm(V); 
                meanVertex = meanVertex + V;       
            end
            meanVertex = meanVertex / numFaces;
            meanVertex = meanVertex / norm(meanVertex);  % rescale to unit vector 
            normals(i,1:3) = meanVertex(1:3);         
        end
    end

    mesh.normals = single(normals);         % normals in MEG coords

    % save warped mesh in MRI folder

    [MRI_path,name,ext] = bw_fileparts(mriFile);
    [path,templateName,template_ext] = bw_fileparts(templateMesh);
        
    fileName = fullfile(MRI_path, [templateName template_ext]);
    fprintf('Saving mesh data in file %s\n', fileName);

    save(fileName ,'-struct', 'mesh');  

end

% get default normalization 
function [sn3dmat_file reslicedMRI] = getDefaultNormalization( mriFile )

    sn3dmat_file = []; 
    
    params = bw_setDefaultParameters;
    bb = params.beamformer_parameters.boundingBox;        
    [mri_path mriName] = bw_fileparts(mriFile);
    subject_ID = mriName;
    sn3dmat_file = sprintf('%s%s%s_resl_%g_%g_%g_%g_%g_%g_sn3d.mat',...
                mri_path,filesep, subject_ID, bb(1), bb(2),bb(3),bb(4),bb(5),bb(6));
    reslicedMRI = sprintf('%s%s%s_resl_%g_%g_%g_%g_%g_%g.nii',...
                mri_path,filesep, subject_ID, bb(1), bb(2),bb(3),bb(4),bb(5),bb(6));
            
    if exist(sn3dmat_file,'file')
        % file already exists
        return;
    end
    
    % have to create normalization file..
    fprintf('checking for existing resliced MRI file %s\n', reslicedMRI);

    if ~exist(reslicedMRI,'file')
        fprintf('re-slicing MRI file into bounding box of svl volume\n');   
        bw_reslice_nii(mriFile, bb);
    else
        fprintf('using existing resliced MRI file %s (delete file to overwrite)\n', reslicedMRI);
    end
     
    % use default template and parameters

    defs = spm_get_defaults('normalise'); 
    templateFile = fullfile(spm('Dir'),'templates','T1.nii');
    maskFile = fullfile(spm('Dir'),'apriori','brainmask.nii');
    
    estimate_flags = defs.estimate;
    estimate_flags.nits = 16;      

    fprintf('\nComputing SPM8 linear and non-linear warping parameters using template file -> \n   %s\n', templateFile);

    % open SPM windows
    [Finter,Fgraph,CmdLine] = spm('FnUIsetup','Image normalization');

    % run spm_normalize to get normalization parameters 
    % disp(['']);
    spm('FigName',['Finding Norm params for ' reslicedMRI],Finter,CmdLine);
    
    disp('------------------------------------');
    disp(['Calculating normalisation parameters from ' reslicedMRI ]);
    disp(['Saving normalisation parameters in ' sn3dmat_file ]);       
    
    objMaskFile = '';
   
    spm_normalise(templateFile, reslicedMRI, sn3dmat_file, maskFile, objMaskFile, estimate_flags);
    
    % For back compatibility - store the CTF bounding box in the snMatFile
    % this can be used during unwarping to get from NIfTI to 
    % CTF coordinates (i.e., to get the CTF origin in the unwarped volume)

    ctf_bb = bb;
    t = load(sn3dmat_file);
    t.ctf_bb = bb;
    save(sn3dmat_file, '-struct', 't')
    fprintf('writing bounding box to file %s\n', sn3dmat_file);
end
