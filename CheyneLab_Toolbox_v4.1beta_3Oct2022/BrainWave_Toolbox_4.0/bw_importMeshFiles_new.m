%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% function mesh = bw_importMeshFiles(matfile, leftMesh, rightMesh)
%%
%% read one or more mesh files and return combined mesh in struct
%%
%% Input:       
%% matfile        - this is a file generated by mri2nii that contains the
%%                  nii to CTF (head) coordinates transformation matrix
%% mesh           - mesh file (can be .vtk from CIVET or .asc from Freesurfer
%%
%%
%% written by D. Cheyne, May, 2014
%%
%% October, 2019 Update (Merron Woodbury)
%% function meshfile = bw_importMeshFiles(mesh_dir, mri_dir)
%%
%% read mesh files and create combined mesh surface and single sphere headmodel
%%
%% Input:
%% mri_dir        - Subject's MRI directory
%% mesh_dir       - Subject's CIVET or Freesurfer directory
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_importMeshFiles(mesh_dir, mri_dir)

global BW_VERSION
global BW_PATH

% load rotation matrix from .mat file generated by mri2nii
[p n e] = fileparts(mri_dir);
postfix = regexp(n, '_MRI');
subjID = n(1:(postfix(end)-1));
matfile = fullfile(mri_dir, strcat(subjID,'.mat'));
tmat = load(matfile);       
M = tmat.M;             % voxel-to-head transformation matrix

if isequal(mesh_dir, 0)
    return;
end
if isequal(mri_dir, 0)
    return;
end

% use folder structure to do initial assesment of CIVET vs Freesurfer
if exist(fullfile(mesh_dir, 'surfaces'), 'dir') && exist(fullfile(mesh_dir, 'transforms'), 'dir')
    isCIVET = true;
    importCIVETmeshes(mesh_dir, mri_dir);
elseif exist(fullfile(mesh_dir, 'surf'), 'dir') && exist(fullfile(mesh_dir, 'mri', 'transforms'), 'dir')
    isCIVET = false;
    importFSmeshes(mesh_dir, mri_dir);
end

% create convex hull around gray surface mesh
if isCIVET
    gray_surf = fullfile(mri_dir, 'CIVET_gray_SURFACE.mat');
    if ~exist(gray_surf, 'file')
        return;
    end
else
    gray_surf = fullfile(mri_dir, 'FS_pial_SURFACE.mat');
    if ~exist(gray_surf, 'file')
        return;
    end
end
gray_mesh = load(gray_surf);


% 1) save surface as convex hull shape file
vertices = gray_mesh.mri_vertices;   
faces = gray_mesh.faces;

Nvertices = size(vertices,1);
Nfaces = size(faces,1);
fprintf('read total of %d vertices and % d faces ...\n', Nvertices, Nfaces);

surface_faces = faces;  % ignore 4th column
surface_points = round(vertices);


% create convex hull from the current surface_points
% which are mesh points in MEG coordinates if mesh has been loaded
% restore full mesh after saving.

% get vertices (in MEG coordinates) that make convex hull
points = double(surface_points);
idx = convhulln(points);
hullPts = points(idx,:);    
surface_points = hullPts;

shapefile = fullfile(mri_dir, strcat(subjID, '_brainHull.shape'));

% write
npts = size(surface_points,1);
pts = [surface_points ones(npts,1)];    % add ones
headpts = pts*tmat.M;                   % convert to MEG coords
clear pts;
headpts(:,4) = [];                      % remove ones
headpts = headpts * 0.1;                % scale to cm

fprintf('writing %d points to shape file (%s)\n', ...
    npts, shapefile);

fid = fopen(shapefile,'w');
fprintf(fid, '%d\n', npts);
for i=1:npts
    fprintf(fid,'%6.2f %6.2f  %6.2f\n', headpts(i,1), headpts(i,2), headpts(i,3));
end
fclose(fid);  
% INFO FILE ? Not used when viewing shape in MRIViewer any more

% read
shape_points = headpts*10;              % scale back to mm (still in MEG coords)

% 2) Create single sphere head model from convex hull
% hdmFile = fullfile(mri_dir,'singleSphere_brainhull.hdm');
% 
% fprintf('Generating single sphere head model (.hdm) file...\n');
% [sphere_o, sphere_r] = bw_fitSphere(double(shape_points/10));
% fprintf('Best fit single sphere: origin = %.2f %.2f %.2f cm, radius = %.2f cm\n', sphere_o, sphere_r);
% 
% fprintf('\nSaving best-fit single sphere in %s\n',hdmFile);
% fid = fopen(hdmFile,'w');
% 
% % create a channel and sphere list for saving...
% % for i=1:size(chan_names{k},1)
% %     s = char(names{i});
% %     fprintf(fid, '%s:    ', s);
%     fprintf(fid, 'NAN:    ');
%     fprintf(fid, '%.3f    %.3f    %.3f    %.3f\n', sphere_o, sphere_r);
% % end
% 
% fclose(fid);

% imports all CIVET meshes in chosen folder
 function importCIVETmeshes(mesh_dir, mri_dir)
        
        wbh = waitbar(0,'Reading CIVET meshfiles...');
        
        obj_files = dir(fullfile(mesh_dir, 'surfaces', '*.obj'));
        if isempty(obj_files)
            return;
        end
        
        % subject name
        names = cell(size(obj_files,1),1);
        for h=1:size(obj_files,1)
            names{h} = char(obj_files(h).name);
        end
        subj_name = names{1}(all(~diff(char(names(:)))));
        
        % different surfaces available
        for h=1:size(obj_files,1)
            surfs{h} = strrep(names(h), subj_name, '');
            surfs{h} = strrep(char(surfs{h}), '.obj', '');
        end
        
        surfaces{1, 1} = 'gray';
        surfaces{2, 1} = 'gray_rsl';
        surfaces{3, 1} = 'mid';
        surfaces{4, 1} = 'mid_rsl';
        surfaces{5, 1} = 'white';
        surfaces{6, 1} = 'white_rsl';
        
        % sort files into surface groups
        for h=1:size(surfs,2)
            name = char(surfs{h});
            
            % skip any files that are not followed by a hemisphere
            % specifier
            if strcmp(name((end-7):end), '_surface')
                continue;
            end

            if strncmp(name, 'gray_surface_left_', 18)
                surfaces{1, 2} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'gray_surface_right_', 19)
                surfaces{1, 3} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'gray_surface_rsl_left_', 22)
                surfaces{2, 2} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'gray_surface_rsl_right_', 23)
                surfaces{2, 3} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'mid_surface_left_', 17)
                surfaces{3, 2} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'mid_surface_right_', 18)   
                surfaces{3, 3} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'mid_surface_rsl_left_', 21)
                surfaces{4, 2} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'mid_surface_rsl_right_', 22)
                surfaces{4, 3} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));  
            elseif strncmp(name, 'white_surface_left_', 19)
                surfaces{5, 2} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'white_surface_right_', 20)   
                surfaces{5, 3} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'white_surface_rsl_left_', 23)
                surfaces{6, 2} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            elseif strncmp(name, 'white_surface_rsl_right_', 24)
                surfaces{6, 3} = fullfile(mesh_dir, 'surfaces', char(obj_files(h).name));
            end

        end
        

        % create each surface
        num_surf = size(surfaces,1);
        for h=1:size(surfaces,1)
            
            leftMesh = surfaces{h,2};
            rightMesh = surfaces{h,3};
            
            % skip surfaces without the requisite files
            if isempty(leftMesh) || isempty(rightMesh)
                continue;
            end
            
            s = sprintf('Creating %s surface...\n', surfaces{h, 1});
            st = strrep(s, '_', ' ');
            waitbar((h/num_surf), wbh, st);
            
            % read one or more mesh files and combine all vertices and faces
            mesh = [];
            meshtype = [];
            idx = [];
            vertices = [];
            faces = [];
            normalized_vertices = [];
            inflated_vertices = [];
            useFaces = false;
            native_to_mni = [];
            

            for k=1:2

                if k == 1 
                    if isempty(leftMesh)
                        mesh.numLeftVertices = 0;
                        mesh.numLeftFaces = 0;
                        continue;
                    else
                        file = leftMesh;
                    end
                else
                    
                    if isempty(rightMesh)
                        mesh.numRightVertices = 0;
                        mesh.numRightFaces = 0;
                        continue;
                    else
                        file = rightMesh;
                    end
                end

                [meshtype, meshdata] = bw_readMeshFile(file);

                if isempty(meshdata)
                    fprintf('failed to read mesh file %s - check format...\n', file);
                    return;
                end

                meshdata.inflated_vertices = [];
                
                % for CIVET meshes in non-native (MNI) coordinate space, we 
                % need transformation matrix from .xfm file to convert back to NIfTI coordinates

                if strcmp(meshtype,'VTK') == 1 || strcmp(meshtype,'OBJ') == 1        
                    % left
                    if k==1
                        % for CIVET mesh we want to save a copy of the original vertices  
                        % which are in MNI coords for co-registration to atlas etc...                  
                        normalized_vertices = meshdata.vertices;

                        % create inflated mesh
                        % load CIVET ellipsoid (in MNI coords)
                        ellipse_file = sprintf('%s%s%s%s', BW_PATH, 'template_MRI',filesep,'CIVET_ellipsoid_81920.obj');
                        [meshtype, ellipse_data] = bw_readMeshFile(ellipse_file); 
                        if size(meshdata.vertices, 1) == size(ellipse_data.vertices, 1)
                            fprintf('Creating inflated mesh...\n');  
                            % scale ellipsoid down - produces better flattening, have to
                            % remove origin offset prior to scaling 
                            ellipsoid_center = mean(ellipse_data.vertices,1);
                            ellipse_data.vertices = ellipse_data.vertices - repmat(ellipsoid_center,size(meshdata.vertices, 1),1); 
                            ellipse_data.vertices = ellipse_data.vertices * 0.8;
                            % stretch in y direction
                            ellipse_data.vertices(:,2) = ellipse_data.vertices(:,2) * 1.3;    
                            ellipse_data.vertices = ellipse_data.vertices + repmat(ellipsoid_center,size(meshdata.vertices, 1),1);             
                            % flatten mesial surface ...
                            idx = find(ellipse_data.vertices(:,1) > 20 );       
                            ellipse_data.vertices(idx,1) = 20;   
                            meshdata.inflated_vertices = (meshdata.vertices + ellipse_data.vertices) / 2.0;
                            % need to increase interhemispheric distance 
                            meshdata.inflated_vertices(:,1) = meshdata.inflated_vertices(:,1) - 10;  

                        end 
                        
                    % right
                    else
                        % for CIVET mesh we want to save a copy of the original vertices  
                        % which are in MNI coords for co-registration to atlas etc...                  
                        normalized_vertices = [normalized_vertices; meshdata.vertices];        

                        % create inflated mesh
                        % load CIVET ellipsoid (in MNI coords)
                        ellipse_file = sprintf('%s%s%s%s', BW_PATH, 'template_MRI',filesep,'CIVET_ellipsoid_81920.obj');
                        [meshtype, ellipse_data] = bw_readMeshFile(ellipse_file);  
                        if size(meshdata.vertices, 1) == size(ellipse_data.vertices, 1)
                            fprintf('Creating inflated mesh...\n');  
                            ellipse_data.vertices(:,1) = ellipse_data.vertices(:,1) * -1.0;           % flip ellipsoid for right hem vertices
                            % scale ellipsoid down - produces better flattening
                            % remove origin offset prior to scaling 
                            ellipsoid_center = mean(ellipse_data.vertices,1);
                            ellipse_data.vertices = ellipse_data.vertices - repmat(ellipsoid_center,size(meshdata.vertices, 1),1); 
                            % scale data
                            ellipse_data.vertices = ellipse_data.vertices * 0.8;
                            % stretch in y direction
                            ellipse_data.vertices(:,2) = ellipse_data.vertices(:,2) * 1.3;    
                            ellipse_data.vertices = ellipse_data.vertices + repmat(ellipsoid_center,size(meshdata.vertices, 1),1);                   
                            % flatten mesial surface...
                            idx = find(ellipse_data.vertices(:,1) < -20 );
                            ellipse_data.vertices(idx,1) = -20;     
                            % include scaling for 
                            meshdata.inflated_vertices = (meshdata.vertices + ellipse_data.vertices) / 2.0;
                            % need to increase interhemispheric distance 
                            meshdata.inflated_vertices(:,1) = meshdata.inflated_vertices(:,1) + 10;

                        end
                    end

                    % look for .xfm file in default location
                    transformPath = sprintf('%s%stransforms%slinear%s',mesh_dir,filesep,filesep,filesep);

                    s = sprintf('%st1_tal.xfm',subj_name);
                    transformFile = fullfile(transformPath,s);
                    fprintf('looking for transformation file (%s)\n', transformFile);

                    if exist(transformFile,'file') ~= 2
                        [tname, tpath, ext] = uigetfile(...
                           {'*.xfm','CIVET TRANSFORM (*.xfm)'},'Select the NIfTI to MNI transform file',mesh_dir);
                        if iequal(tname, 0) || isequal(tpath,0)
                            delete(wbh);
                            return;
                        end
                        transformFile = fullfile(tpath, tname);
                    end   

                    t = importdata(transformFile);
                    transform = [t.data; 0 0 0 1];
                    fprintf('transforming mesh from MNI to original NIfTI coordinates using transformation:\n');
                    mni_to_native = inv(transform)';
                    native_to_mni = transform';  % for saving

                    t_vertices = [meshdata.vertices, ones(size(meshdata.vertices,1), 1) ];
                    t_vertices = t_vertices * mni_to_native ; 
                    t_vertices(:,4) = [];
                    meshdata.vertices = t_vertices;

                    % scale mesh back to RAS voxels (native) space
                    fprintf('rescaling mesh from mm to voxels (scale = %g mm/voxel)\n', tmat.mmPerVoxel);
                    meshdata.vertices = meshdata.vertices ./tmat.mmPerVoxel;

                    % scale inflated mesh as well (to keep in same frame of reference as MEG)
                    t_vertices = [meshdata.inflated_vertices, ones(size(meshdata.inflated_vertices,1), 1) ];
                    t_vertices = t_vertices * mni_to_native ; 
                    t_vertices(:,4) = [];
                    meshdata.inflated_vertices = t_vertices;
                    meshdata.inflated_vertices = meshdata.inflated_vertices ./tmat.mmPerVoxel;

                    isCIVET = true;
                    
                else
                    fprintf('Is actually freesurfer folder. Restructure folder\n');
                    delete(wbh);
                    return;
                end
                
                % concatenate left and right meg relative meshes and faces
                if k == 1
                    mesh.numLeftVertices = size(meshdata.vertices,1);
                    mesh.numLeftFaces = size(meshdata.faces,1);
                    vertices = meshdata.vertices;
                    faces = meshdata.faces;

                    if ~isempty(meshdata.inflated_vertices)
                        inflated_vertices = meshdata.inflated_vertices;
                    end

                else
                    mesh.numRightVertices = size(meshdata.vertices,1);
                    mesh.numRightFaces = size(meshdata.faces,1);

                    offset = size(vertices,1);
                    vertices = [vertices; meshdata.vertices];

                    % have to add offset to face indices
                    meshdata.faces = meshdata.faces + offset;
                    faces = [faces; meshdata.faces];

                    if ~isempty(meshdata.inflated_vertices)
                        inflated_vertices = [inflated_vertices; meshdata.inflated_vertices];
                    end

                end        

                clear meshdata;

            end
            
            % should now have mesh vertices (including inflated) in native (RAS) voxel space 
            % based on original .nii volume used to generate meshes

            % *** keep a copy of vertices in MRI (native voxel space for viewing on MRI)  ***
            mesh.mri_vertices = single(vertices);

            % rotate vertices into head coordinates 
            fprintf('rotating and scaling vertices from voxels into MEG (head) coordinates ...\n');

            vertices = [vertices, ones(size(vertices,1), 1) ];
            vertices = (vertices * M) * 0.1;  % transform to head coordinates and scale to cm
            vertices(:,4) = [];

            if ~isempty(inflated_vertices)
                inflated_vertices = [inflated_vertices, ones(size(inflated_vertices,1), 1) ];
                inflated_vertices = (inflated_vertices * M) * 0.1;  % transform to head coordinates and scale to cm
                inflated_vertices(:,4) = [];
            end
            Nvertices = size(vertices,1);
            Nfaces = size(faces,1);

            % get normal vectors...

            waitbar((h/num_surf), wbh, 'computing surface normals... ',k);

            if useFaces
                % place sources at centroid of each triangle 

                nvoxels = Nfaces;
                voxels = zeros(nvoxels,3);
                normals = zeros(nvoxels,3);

                fprintf('computing face centers and normals....\n');

                for i=1:Nfaces
                    v1 = vertices(faces(i,1)+1,:);
                    v2 = vertices(faces(i,2)+1,:);
                    v3 = vertices(faces(i,3)+1,:);
                    voxels(i,1:3) =  (v1 + v2 + v3) / 3;
                    V = cross((v1-v2),(v2-v3));
                    normals(i,1:3) = V /norm(V);
                end
            else
                % place sources at vertices

                nvoxels = Nvertices;
                voxels = vertices;

                % for each vertex find its adjoining faces and take the mean of each face
                % normal as the normal for that vertex
                fprintf('computing vertex normals ...\n');

                if exist('bw_computeFaceNormals','file') == 3
                    % use mex function       
                    normals = bw_computeFaceNormals(double(vertices'), double(faces')); 
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

            end

            for k=80:5:100
                waitbar((h/num_surf), wbh,'finishing surface...');
            end

            %******************************************************************************** 
            % vertices are stored in 3 different coordinate systems
            % 1. mri_vertices:
            %    These are "native" MRI (RAS) voxel coordinates (i.e., original .nii volume).
            % 2. normalized_vertices:
            %    MNI coordinates in mm (native mesh coords for CIVET, have to be computed for Freesurfer).
            % 3. vertices
            %    These are vertices in MEG "head" coordinates (in cm) based on
            %    fiducials used to save the SUBJ_ID.mat file
            % 4. inflated_vertices
            %    These are the inflated surface meshes that have been combined and
            %    converted to MEG coordinate system
            %
            %    Face indices are valid for all
            %    *** normals are in MEG relative coordinates !!! 
            % 
            % mesh data saved in single precision to reduce memory / file size etc.
            %********************************************************************************

            mesh.meshType = meshtype;
            mesh.isCIVET = isCIVET;
            mesh.hasFaceNormals = useFaces;
            mesh.RAS_to_MNI = native_to_mni;

            mesh.faces = single(faces);

            mesh.numVertices = mesh.numLeftVertices + mesh.numRightVertices;
            mesh.numFaces = mesh.numLeftFaces + mesh.numRightFaces;

            if ~isempty(normalized_vertices)
                mesh.normalized_vertices = single(normalized_vertices);  
            else
                mesh.normalized_vertices = [];
            end

            if ~isempty(inflated_vertices)
                mesh.inflated_vertices = single(inflated_vertices);
            end

            mesh.vertices= single(vertices);        % vertices in MEG coords
            mesh.normals = single(normals);         % normals in MEG coords

            % automatically save
            meshfile = fullfile(mri_dir, sprintf('CIVET_%s_SURFACE.mat', surfaces{h, 1}));
            fprintf('Saving mesh data in file %s\n', meshfile);
            save(meshfile ,'-struct', 'mesh'); 

        end
        
        delete (wbh);
        fprintf('all done...\n');

 end

% imports all FSL meshes in chosen folder
 function importFSmeshes(mesh_dir, mri_dir)
        
        wbh = waitbar(0,'Reading meshfiles...');
        
        surfaces{1,1} = 'pial';
        surfaces{2,1} = 'white';
        
        % pial surface files
        sf = dir(fullfile(mesh_dir, 'surf', 'lh.pial'));
        if size(sf,1) == 1
            surfaces{1,2} = fullfile(mesh_dir, 'surf', char(sf.name));
        end
        sf = dir(fullfile(mesh_dir, 'surf', 'rh.pial'));
        if size(sf,1) == 1
            surfaces{1,3} = fullfile(mesh_dir, 'surf', char(sf.name));
        end
        
        % white surface files
        sf = dir(fullfile(mesh_dir, 'surf', 'lh.white'));
        if size(sf,1) == 1
            surfaces{2,2} = fullfile(mesh_dir, 'surf', char(sf.name));
        end
        sf = dir(fullfile(mesh_dir, 'surf', 'rh.white'));
        if size(sf,1) == 1
            surfaces{2,3} = fullfile(mesh_dir, 'surf', char(sf.name));
        end
        
        % create each surface
        num_surf = size(surfaces,1);
        for h=1:size(surfaces,1)
            
            leftMesh = surfaces{h,2};
            rightMesh = surfaces{h,3};
            
            % skip surfaces without the requisite files
            if isempty(leftMesh) || isempty(rightMesh)
                continue;
            end
            
            s = sprintf('Creating %s surfaces...\n', surfaces{h, 1});
            waitbar((h/num_surf), wbh, s);
            
            % read one or more mesh files and combine all vertices and faces
            vertices = [];
            faces = [];
            mesh = [];
            meshtype = [];
            idx = [];
            normalized_vertices = [];
            inflated_vertices = [];
            useFaces = false;
            native_to_mni = [];
            
            for k=1:2

                if k == 1 
                    if isempty(leftMesh)
                        mesh.numLeftVertices = 0;
                        mesh.numLeftFaces = 0;
                        continue;
                    else
                        file = leftMesh;
                    end
                else
                    if isempty(rightMesh)
                        mesh.numRightVertices = 0;
                        mesh.numRightFaces = 0;
                        continue;
                    else
                        file = rightMesh;
                    end
                end

                [meshtype, meshdata] = bw_readMeshFile(file);

                if isempty(meshdata)
                    fprintf('failed to read mesh file %s - check format...\n', file);
                    return;
                end

                meshdata.inflated_vertices = [];
        
                if strcmp(meshtype,'VTK') == 1 || strcmp(meshtype,'OBJ') == 1        
                    fprintf('Is actually CIVET folder. Restructure folder\n');
                    delete(wbh);
                    return;
                else

                    % ** for freesurfer meshes we have to scale mesh back to RAS voxels (native) space
                    % ** have to scale then translate origin which is center of image...

                    fprintf('rescaling mesh from mm to voxels (scale = %g mm/voxel)\n', tmat.mmPerVoxel);
                    original_vertices = meshdata.vertices;
                    meshdata.vertices = meshdata.vertices ./tmat.mmPerVoxel;

                    % translate origin to correspond to original RAS volume
                    % adding 129 instead of 128 seems to make MNI coords line up on midline better
                    % both on .nii and for Talairach coordinates. Also corresponds to
                    % conversion shown in srfaceRAS to Talairach conversion documentation
                    meshdata.vertices = meshdata.vertices + 129;

                    % For MNI coordinates, have to get transformation matrix to scale FS meshes
                    % from native to MNI (opposite to CIVET above). This can be done
                    % using the transformation in talairach.xfm.  However, this
                    % transform seems to assume that vertices are still in mm but with
                    % origin in the center of the image ???. This part is still
                    % unclear.  

                    % look for .xfm file in default location
                    transformPath = sprintf('%s%smri%stransforms%s',mesh_dir, filesep,filesep,filesep);

                    transformFile = sprintf('%stalairach.xfm',transformPath);
                    fprintf('looking for transformation file (%s)\n', transformFile);

                    if exist(transformFile,'file') ~= 2
                        [tname, tpath, ext] = uigetfile(...
                           {'*.xfm','Talairach transform (*.xfm)'},'Select the talairach transform file',mesh_dir);    
                        if isequal(tname, 0) || isequal(tpath, 0)
                            delete(wbh);
                            return;
                        end
                       transformFile = fullfile(tpath, tname);
                    end   

                    t = importdata(transformFile);
                    transform = [t.data; 0 0 0 1];
                    fprintf('transforming mesh to MNI from original NIfTI coordinates using transformation:\n');
                    native_to_mni = transform';        

                    % need to scale back to mm for talairach.xfm to work
                    fs_vertices = meshdata.vertices * tmat.mmPerVoxel;

                    t_vertices = [fs_vertices, ones(size(fs_vertices,1), 1) ];
                    t_vertices = t_vertices * native_to_mni; 
                    t_vertices(:,4) = [];

                    % look for inflated surfaces (assume user chooses lh.pial .... 

                    [meshPath, meshname, ext] = bw_fileparts(file);

                    inflatedFile = strcat(meshPath, filesep, meshname, '.inflated');     
                    fprintf('Looking for inflated mesh file %s\n',inflatedFile);
                    if exist(inflatedFile, 'file')
                        [meshtype, tdata] = bw_readMeshFile(inflatedFile);
                        meshdata.inflated_vertices = tdata.vertices ./tmat.mmPerVoxel;  % scale to voxels
                        meshdata.inflated_vertices = meshdata.inflated_vertices + 129;  % move origin from center

                        % FS inflated meshes are shifted to middle of image...?
                        mx = max(meshdata.inflated_vertices(:,1));
                        mn = min(meshdata.inflated_vertices(:,1));
                        if k==1
                            offset = mx - 128;                
                            meshdata.inflated_vertices(:,1) = meshdata.inflated_vertices(:,1) - offset;
                        else
                            offset = 128 - mn;                
                            meshdata.inflated_vertices(:,1) = meshdata.inflated_vertices(:,1) + offset;
                        end
                    end      

                    % get correct curvature file for surface
                    if ~isempty(strfind(file,'pial'))
                        curvFile = strcat(meshPath, filesep, meshname, '.curv.pial');
                    else
                        curvFile = strcat(meshPath, filesep, meshname, '.curv');   
                    end
                    fprintf('Looking for inflated mesh file %s\n',curvFile);
                    if exist(curvFile, 'file')
                        [meshtype, tdata] = bw_readMeshFile(curvFile);   
                        if k==1
                            mesh.curv = tdata.curv;
                        else
                            mesh.curv = [mesh.curv; tdata.curv];
                        end
                    end

                    if k==1
                        normalized_vertices = t_vertices;
                    else
                        normalized_vertices = [normalized_vertices; t_vertices];        
                    end        

                    isCIVET = false;
                end

                % concatenate left and right meg relative meshes and faces
                if k == 1
                    mesh.numLeftVertices = size(meshdata.vertices,1);
                    mesh.numLeftFaces = size(meshdata.faces,1);
                    vertices = meshdata.vertices;
                    faces = meshdata.faces;

                    if ~isempty(meshdata.inflated_vertices)
                        inflated_vertices = meshdata.inflated_vertices;
                    end

                else
                    mesh.numRightVertices = size(meshdata.vertices,1);
                    mesh.numRightFaces = size(meshdata.faces,1);

                    offset = size(vertices,1);
                    vertices = [vertices; meshdata.vertices];

                    % have to add offset to face indices
                    meshdata.faces = meshdata.faces + offset;
                    faces = [faces; meshdata.faces];

                    if ~isempty(meshdata.inflated_vertices)
                        inflated_vertices = [inflated_vertices; meshdata.inflated_vertices];
                    end

                end        

                clear meshdata;
            end
            
            % should now have mesh vertices (including inflated) in native (RAS) voxel space 
            % based on original .nii volume used to generate meshes

            % *** keep a copy of vertices in MRI (native voxel space for viewing on MRI)  ***
            mesh.mri_vertices = single(vertices);

            % rotate vertices into head coordinates 
            fprintf('rotating and scaling vertices from voxels into MEG (head) coordinates ...\n');

            vertices = [vertices, ones(size(vertices,1), 1) ];
            vertices = (vertices * M) * 0.1;  % transform to head coordinates and scale to cm
            vertices(:,4) = [];

            if ~isempty(inflated_vertices)
                inflated_vertices = [inflated_vertices, ones(size(inflated_vertices,1), 1) ];
                inflated_vertices = (inflated_vertices * M) * 0.1;  % transform to head coordinates and scale to cm
                inflated_vertices(:,4) = [];
            end
            Nvertices = size(vertices,1);
            Nfaces = size(faces,1);

            % get normal vectors...

            waitbar((h/num_surf),wbh, 'computing surface normals... ',k);

            if useFaces
                % place sources at centroid of each triangle 

                nvoxels = Nfaces;
                voxels = zeros(nvoxels,3);
                normals = zeros(nvoxels,3);

                fprintf('computing face centers and normals....\n');

                for i=1:Nfaces
                    v1 = vertices(faces(i,1)+1,:);
                    v2 = vertices(faces(i,2)+1,:);
                    v3 = vertices(faces(i,3)+1,:);
                    voxels(i,1:3) =  (v1 + v2 + v3) / 3;
                    V = cross((v1-v2),(v2-v3));
                    normals(i,1:3) = V /norm(V);
                end
            else
                % place sources at vertices

                nvoxels = Nvertices;
                voxels = vertices;

                % for each vertex find its adjoining faces and take the mean of each face
                % normal as the normal for that vertex
                fprintf('computing vertex normals ...\n');

                if exist('bw_computeFaceNormals','file') == 3
                    % use mex function       
                    normals = bw_computeFaceNormals(double(vertices'), double(faces')); 
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

            end

            for k=80:5:100
                waitbar((h/num_surf), wbh,'finishing surface...');
            end

            %******************************************************************************** 
            % vertices are stored in 3 different coordinate systems
            % 1. mri_vertices:
            %    These are "native" MRI (RAS) voxel coordinates (i.e., original .nii volume).
            % 2. normalized_vertices:
            %    MNI coordinates in mm (native mesh coords for CIVET, have to be computed for Freesurfer).
            % 3. vertices
            %    These are vertices in MEG "head" coordinates (in cm) based on
            %    fiducials used to save the SUBJ_ID.mat file
            % 4. inflated_vertices
            %    These are the inflated surface meshes that have been combined and
            %    converted to MEG coordinate system
            %
            %    Face indices are valid for all
            %    *** normals are in MEG relative coordinates !!! 
            % 
            % mesh data saved in single precision to reduce memory / file size etc.
            %********************************************************************************

            mesh.meshType = meshtype;
            mesh.isCIVET = isCIVET;
            mesh.hasFaceNormals = useFaces;
            mesh.RAS_to_MNI = native_to_mni;

            mesh.faces = single(faces);

            mesh.numVertices = mesh.numLeftVertices + mesh.numRightVertices;
            mesh.numFaces = mesh.numLeftFaces + mesh.numRightFaces;

            if ~isempty(normalized_vertices)
                mesh.normalized_vertices = single(normalized_vertices);  
            else
                mesh.normalized_vertices = [];
            end

            if ~isempty(inflated_vertices)
                mesh.inflated_vertices = single(inflated_vertices);
            end

            mesh.vertices= single(vertices);        % vertices in MEG coords
            mesh.normals = single(normals);         % normals in MEG coord


            % automatically save
            meshfile = fullfile(mri_dir, sprintf('FS_%s_SURFACE.mat', surfaces{h, 1}));
            fprintf('Saving mesh data in file %s\n', meshfile);
            save(meshfile ,'-struct', 'mesh'); 
            
        end
        
        
        delete (wbh);
        fprintf('all done...\n');
    end


end
