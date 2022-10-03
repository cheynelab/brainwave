%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% function [filetype meshdata] = dt_readMeshFile(meshFile)
%%
%% - script to read various mesh formats and return the filetype
%%   vertices and face indices in Matlab friendly format 
%%   (e.g., face indices numbered from one)
%% 
%%   NOTE:  meshdata is return in file based coordinates so rescaling to 
%%          original MRI voxel size etc must be done by calling routine
%%
%%  returns filetype and meshdata as struct (to add more stuff later...)
%%  
%%  supported file type labels 
%%  'VTK'  - vtk mesh format created by obj2vtk (CIVET)
%%  'OBJ'  - MNI object file format (CIVET)
%%  'FSA'  - Freesurfer SURF format in ascii format
%%  'FSB'  - Freesurfer SURF format in binary format
%%  'FSC'  - Freesurfer curvature file in binary format
%%  'FSL'  - FSL .off mesh  (assumes in LAS)
%%              
%%  written by D. Cheyne, Dec, 2013 (c) Hospital for Sick Children
%%
%%  modified in Oct, 2021 to read thickness files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
function [filetype, meshdata]  = dt_readMeshFile(meshFile)

meshdata = [];
filetype = 'unknown';

% try to figure out format

[~,~,EXT] = fileparts(meshFile);

% since we cannot properly check extension for freesurfer binary files due 
% to the use of dots in the filenames we have to check for magic number first
if isFSB(meshFile)
    fprintf('Reading Freesurfer (binary) mesh File ...\n');    
    meshdata = read_freesurfer_mesh_file(meshFile);
    filetype = 'FSB'; 
elseif isFSBCurv(meshFile)
    % magic number is same for thickness so have to check filename...
    if ~isempty(strfind(meshFile,'curv'))
        fprintf('Reading Freesurfer (binary) curvature File ...\n');    
        meshdata = read_freesurfer_curvature_file(meshFile);
        filetype = 'FSC';
    elseif ~isempty(strfind(meshFile,'thickness'))
        fprintf('Reading Freesurfer (binary) curvature File ...\n');    
        meshdata = read_freesurfer_thickness_file(meshFile);
        filetype = 'FST';
    end
elseif strcmp(EXT,'.asc')
    fprintf('Reading Freesurfer (ASCII) mesh File ...\n');
    meshdata = read_freesurfer_ascii_mesh_file(meshFile);
    filetype = 'FSA';
elseif strcmp(EXT,'.vtk')
    fprintf('Reading VTK surface mesh  ...\n');
    meshdata = read_vtk_mesh_file(meshFile);
    filetype = 'VTK';
elseif strcmp(EXT,'.obj')
    fprintf('Reading MNI Object file (.obj) mesh File ...\n');
    meshdata = read_object_mesh_file(meshFile);
    filetype = 'OBJ';
elseif strcmp(EXT,'.off')
    fprintf('Reading FSL (.off) mesh File ...\n');
    meshdata = read_FSL_mesh_file(meshFile);
    filetype = 'FSL';
else
    fprintf('unsupported mesh format\n');
end

end

% read vtk formatted mesh file
function meshdata = read_vtk_mesh_file(meshFile)

meshdata.vertices = [];
meshdata.faces = [];
meshdata.normals = [];

fid = fopen(meshFile,'r');
if (fid == -1)
    fprintf('failed to open file <%s>\n',meshFile);
    return;
end

% read VTK header properly
s = fgetl(fid); 
if strncmp(s,'# vtk',5) == 0
    fprintf('not a VTK file...\n');
    return;
end 
s = fgetl(fid);
s = fgetl(fid);
if strncmp(s,'ASCII',5) == 0
    fprintf('not ASCII format..\n');
    return;
end 

s = fgetl(fid);
while ~feof(fid)
    s = fscanf(fid,'%s',1);    

    if strcmp(s,'POINTS')
        % read vertices 
        Nvertices = fscanf(fid,'%d',1);
        s = fscanf(fid,'%s',1); % float
        fprintf('reading %d vertices from %s...\n',Nvertices,meshFile);
        meshdata.vertices = fscanf(fid,'%f',[3,Nvertices])';
        
    elseif strncmp(s,'NORMALS',7)
        % read NORMALS 
        s = fscanf(fid,'%s',1); % dataname
        s = fscanf(fid,'%s',1); % float
        fprintf('reading %d normals from %s...\n',Nvertices,meshFile);
        meshdata.normals = fscanf(fid,'%f',[3,Nvertices])';
        
    elseif strncmp(s,'POLYGONS',8)
        % read faces
        Nfaces = fscanf(fid,'%d',1);
        s = fscanf(fid,'%s',1); % total number of values...
        fprintf('reading %d faces from %s...\n',Nfaces,meshFile);
        meshdata.faces = fscanf(fid,'%f',[4,Nfaces])';
        meshdata.faces(:,1) = [];  % get rid of polygon dimension (assumes is always 3!)
    else 
        % ignore other keywords
    end
        
end

fclose(fid);

end

% read MNI (CIVET) object file 
function meshdata = read_object_mesh_file(meshFile)

meshdata.vertices = [];
meshdata.faces = [];
meshdata.normals = [];

fid = fopen(meshFile,'r');
if (fid == -1)
    fprintf('failed to open file <%s>\n',meshFile);
    return;
end

s = fgetl(fid);
idx = find(s == 'P');
if isempty(idx)
    fprintf('does not appear to be CIVET .obj file..\n');
    return;
end
[str, ~] = sscanf(s,'%c %g %g %g %d %d %d');
Nvertices = str(7);

% read vertices 
fprintf('reading %d vertices from %s...\n',Nvertices,meshFile);
meshdata.vertices = fscanf(fid,'%f',[3,Nvertices])';

s = fgetl(fid);  % skip blank line

% this appears to be followed by normals
meshdata.normals = fscanf(fid,'%f',[3,Nvertices])';

s = fgetl(fid);  % skip blank line
Nfaces = fscanf(fid,'%d',1);
s = fgetl(fid);  % skip blank line
s = fgetl(fid);  % skip blank line

% this is followed by 10240 lines of text, 8 values on each line 
% = 81920 values (not exactly sure what these are)
% This is followed by a blank line, after which come the vertices, but 
% again as 8 values per line (i.e., triangles split across lines). 
for i=1:10240
    s = fgetl(fid);
end

fprintf('reading %d faces from %s...\n',Nfaces,meshFile);
s = fgetl(fid);  % skip blank line

% read face indices
for i=1:Nfaces
    meshdata.faces(i,1) = fscanf(fid,'%d',1);
    meshdata.faces(i,2) = fscanf(fid,'%d',1);
    meshdata.faces(i,3) = fscanf(fid,'%d',1);
end

fclose(fid);

end

% read ASCII exported Freesurfer meshes (SURF files)
function meshdata = read_freesurfer_ascii_mesh_file(meshFile)

meshdata.vertices = [];
meshdata.faces = [];
meshdata.normals = [];

fid = fopen(meshFile,'r');
if (fid == -1)
    fprintf('failed to open file <%s>\n',meshFile);
    return;
end

t = fgetl(fid);  % skip comment line  

% read vertices 
Nvertices = fscanf(fid,'%d',1);
Nfaces = fscanf(fid,'%d',1);

fprintf('reading %d vertices and %d faces from %s...\n',Nvertices,Nfaces, meshFile);
meshdata.vertices = fscanf(fid,'%f',[4,Nvertices])';

% get rid of 4th column (all zeros ?)
meshdata.vertices(:,4) = [];  

% Freesurfer mesh is in mm with origin at center of image
% translate origin to convert to RAS  
% NOTE mesh must be scaled to voxels with original MRI voxelSize before
% transforming to CTF space
meshdata.vertices = meshdata.vertices + 128;

% read faces
meshdata.faces = fscanf(fid,'%f',[4,Nfaces])';

% get rid of polygon dimension (assumes is always 3!)
meshdata.faces(:,4) = [];  

fclose(fid);

end

% read binary Freesurfer meshes (SURF files)
function meshdata = read_freesurfer_mesh_file(meshFile)

meshdata.vertices = [];
meshdata.faces = [];
meshdata.normals = [];

fid = fopen(meshFile,'rb','b');
if (fid == -1)
    fprintf('failed to open file <%s>\n',meshFile);
    return;
end
b1 = fread(fid,1,'uchar');
b2 = fread(fid,1,'uchar');
b3 = fread(fid,1,'uchar');
val = bitshift(b1, 16) + bitshift(b2,8) + b3;
if val ~= 16777214
    fprintf('incorrect magic number in freesurfer SURF file\n');
    return;
end

% this is  one line of text (as in documentation) 
% but need to read line feed or else next is off by one byte
t = fgets(fid);
b1 = fread(fid,1,'uchar');  

Nvertices = fread(fid,1,'int32');
Nfaces = fread(fid,1,'int32');
fprintf('reading %d vertices and %d faces from %s...\n',Nvertices,Nfaces, meshFile);

meshdata.vertices = fread(fid, Nvertices*3, 'float32')';
meshdata.vertices = reshape(meshdata.vertices,3,Nvertices)';

% Freesurfer mesh is in mm with origin at center of image
% translate origin to convert to RAS  
% NOTE mesh must be scaled to voxels with original MRI voxelSize before
% transforming to CTF space
% meshdata.vertices = meshdata.vertices + 128;

meshdata.faces = fread(fid, Nfaces*3, 'int32')';
meshdata.faces = reshape(meshdata.faces,3,Nfaces)';

fclose(fid);

end

% read binary Freesurfer meshes (SURF files)
function meshdata = read_freesurfer_curvature_file(meshFile)

meshdata.curv = [];

fid = fopen(meshFile,'rb','b');
if (fid == -1)
    fprintf('failed to open file <%s>\n',meshFile);
    return;
end
b1 = fread(fid,1,'uchar');
b2 = fread(fid,1,'uchar');
b3 = fread(fid,1,'uchar');
val = bitshift(b1, 16) + bitshift(b2,8) + b3;
if val ~= 16777215
    fprintf('incorrect magic number in freesurfer CURV file\n');
    return;
end

% this is  one line of text (as in documentation) 
% but need to read line feed or else next is off by one byte
Nvertices = fread(fid, 1, 'int32');
Nfaces = fread(fid, 1, 'int32');
vals_per_vertex = fread(fid, 1, 'int32');
meshdata.curv = fread(fid, Nvertices, 'float');

fclose(fid);

end


% read binary Freesurfer meshes (SURF files)
function meshdata = read_freesurfer_thickness_file(meshFile)

meshdata.thickness = [];

fid = fopen(meshFile,'rb','b');
if (fid == -1)
    fprintf('failed to open file <%s>\n',meshFile);
    return;
end
b1 = fread(fid,1,'uchar');
b2 = fread(fid,1,'uchar');
b3 = fread(fid,1,'uchar');
val = bitshift(b1, 16) + bitshift(b2,8) + b3;
if val ~= 16777215
    fprintf('incorrect magic number in freesurfer Thickness file\n');
    return;
end

% this is  one line of text (as in documentation) 
% but need to read line feed or else next is off by one byte
Nvertices = fread(fid, 1, 'int32');
Nfaces = fread(fid, 1, 'int32');
vals_per_vertex = fread(fid, 1, 'int32');
meshdata.thickness = fread(fid, Nvertices, 'float');

fclose(fid);

end


% check for freesurfer magic number for triangular mesh file 
function tf = isFSB(meshFile)
tf = false;
fid = fopen(meshFile,'rb','b');
if (fid == -1)
    fprintf('failed to open file <%s>\n',meshFile);
    return;
end
% stored as int3 ! 
b1 = fread(fid,1,'uchar');
b2 = fread(fid,1,'uchar');
b3 = fread(fid,1,'uchar');
val = bitshift(b1, 16) + bitshift(b2,8) + b3;
if val == 16777214
    tf = true;
end
fclose(fid);

end

% check for freesurfer magic number for curv (or thickness) file 
function tf = isFSBCurv(meshFile)
tf = false;
fid = fopen(meshFile,'rb','b');
if (fid == -1)
    fprintf('failed to open file <%s>\n',meshFile);
    return;
end
% stored as int3 ! 
b1 = fread(fid,1,'uchar');
b2 = fread(fid,1,'uchar');
b3 = fread(fid,1,'uchar');
val = bitshift(b1, 16) + bitshift(b2,8) + b3;
if val == 16777215
    tf = true;
end
fclose(fid);

end

% read FSL mesh file
function meshdata = read_FSL_mesh_file(meshFile)

meshdata.vertices = [];
meshdata.faces = [];
meshdata.normals = [];

fid = fopen(meshFile,'r');

if (fid == -1)
    fprinf('failed to open file \n',meshFile);
    return;
end

t = fgetl(fid);   % OFF keyword
if t ~= 'OFF'
    fprintf('this does not appear to be FSL .off file\n');
    return;
end        
Nvertices = fscanf(fid,'%d',1);
Nfaces    = fscanf(fid,'%d',1);
Nedges    = fscanf(fid,'%d',1);
 
meshdata.vertices = fscanf(fid,'%f',[3,Nvertices])';
% FSL mesh is LAS (unless using older version) 
% flip mesh from LAS to RAS. According to Marc's notes 
% FSL voxels indexed from 0 to 255 so subtract from 255
%
% ** note was incorrect as FSL mesh is in mm relative to LAS origin
% has to be converted to voxels in order to flip to RAS but we don't have
% scaling factor available here... have to return in LAS
% meshdata.vertices(:,1) = 255 - meshdata.vertices(:,1);

% read faces                
meshdata.faces = fscanf(fid,'%f',[4,Nfaces])';               
meshdata.faces(:,1) = [];

fclose(fid);
 
end
