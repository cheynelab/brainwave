%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% D. Cheyne, 2013
% function [ph] = bw_plotMesh(meshFile, matFile, txtFile, threshold)
% function plotMesh(meshFile, txtFile, matFile, threshold)
%
% plot a CIVET or Freesurfer (ASCII) mesh file
% if matFile is passed will transform mesh to MEG coordinates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
function [ph] = bw_plotMesh(mesh, matFile,  txtFile, threshold)

if ~exist('matFile','var')
    matFile = [];
end

if ~exist('txtFile','var')
    txtFile = [];
end

% option to pass mess data directly instead of file names
if isstruct(mesh)
    
    vertices = mesh.vertices;    
%     vertices = mesh.inflated_vertices;
%     vertices = mesh.normalized_vertices;

    faces = mesh.faces;
    
else
    meshFile = mesh;
    mesh = [];
    
    if iscellstr(meshFile)
        numFiles = size(meshFile,1);
    else
        numFiles = 1;
    end

    for k=1:numFiles

        if iscellstr(meshFile)
            file = char( meshFile(k) );
        else
            file = meshFile;
        end

        [meshtype, meshdata] = bw_readMeshFile(file);


        if isempty(meshdata.vertices) || isempty(meshdata.faces)
            fprintf('failed to read mesh file - check format...\n');
            return;
        end
        
        % rotate vertices into head coordinates if transformation matrix passed
        if ~isempty(matFile)
            % load rotation matrix from .mat file 
            tmat = load(matFile);
            M = tmat.M;      % voxel-to-head transformation matrix

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
            % have to scale mesh back to voxels since transformation matrix
            % will re-scale to cm
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
            fprintf('rescaling mesh from mm to voxels\n');
            meshdata.vertices = meshdata.vertices ./tmat.mmPerVoxel;
                      
            if isequal(meshtype,'FSL')
                fprintf('This is FSL .off mesh, assume right/left flipping required\n');
                meshdata.vertices(:,1) = 255 - meshdata.vertices(:,1);
            end

            
            fprintf('rotating vertices into CTF coordinate system ...\n');    

            meshdata.vertices = [meshdata.vertices, ones(size(meshdata.vertices,1), 1) ];
            meshdata.vertices = (meshdata.vertices * M) * 0.1;  %% transform to head coordinates and scale to cm
            meshdata.vertices(:,4) = [];
        end
        
        
        if k == 1
            vertices = meshdata.vertices;
            faces = meshdata.faces;
        else
            offset = size(vertices,1);
            vertices = [vertices; meshdata.vertices];

            % have to add offset to face indices
            meshdata.faces = meshdata.faces + offset;
            faces = [faces; meshdata.faces];     
        end

        clear meshdata;
    end

end
    


Nvertices = size(vertices,1);
Nfaces = size(faces,1);

% *** for plotting we have to increment face indices for Matlab arrays ***
faces = faces + 1;  

%%%%%%%%%% ADDED BY CECILIA %%%%%%%%%%
if ~isempty(txtFile)

    fid1 = fopen(txtFile,'r');
    if (fid1 == -1)
        fprintf('failed to open file <%s>\n',txtFile);
        return;
    end
    C = textscan(fid1,'%f');
    fclose(fid1);

    if exist('threshold','var')  % DC - optional thresholding
        idx = abs( C{1} ) < threshold;
        C{1}(idx,1) = 0.0;
    end

    faceColors=cell2mat(C);
    NfaceColors=length(faceColors);
    if NfaceColors ~= Nfaces  && NfaceColors ~= Nvertices
        fprintf(1,'Number of voxels (%d) must be same as number of Vertices (%d) or number of Faces: (%d)\n',NfaceColors, Nfaces(1),Nvertices);
        return
    end
end


%%%%%%%%%% END OF ADDED BY CECILIA %%%%%%%%%%

fh = figure('Color','white','name','3D Mesh','numberTitle','off','Position',[25 800 800 600]);
if ispc
    movegui(fh,'center')
end
hold on;
    
if ~exist('faceColors','var')
    faceColors = ones(size(vertices,1),1);
    ph = patch('Vertices',vertices, 'Faces', faces, 'EdgeColor', 'none', 'facevertexcdata', faceColors(:) );
    shading interp
    colormap(gray)
%     ph = patch('Vertices',vertices, 'Faces', faces, 'EdgeColor', 'none', 'facecolor', [0.3 0.3 0.3] );
else
    ph = patch('Vertices',vertices, 'Faces', faces, 'EdgeColor', 'none', 'facevertexcdata', faceColors(:) );

    shading interp
    colorbar
end
% 

lighting gouraud
camlight left
camlight right

ax = gca;

axis off
axis vis3d
axis equal

hold off;

if ~isempty(matFile)
    set(ax,'CameraViewAngle',6,'View',[180, 0]);
else
    set(ax,'CameraViewAngle',7,'View',[-90, 90]);
end

rotate3d on

if ~isempty(mesh)
    h = datacursormode(fh);
    set(h,'enable','on','UpdateFcn',@UpdateCursors);
    set(h,'UpdateFcn',@UpdateCursors);
end

    
    function newText = UpdateCursors(varargin)

        % get cursorMode object of figure
        cursorMode = datacursormode(fh);
        set(cursorMode, 'displayStyle','window');

        % identify which datatip is active
        currentDatatip = cursorMode.CurrentDataCursor;
        if isempty(currentDatatip)
            % exit if there is no active datatip
            return;
        end

        dataTipsH = cursorMode.DataCursors;   

        % we just need handle for first tip (there is only one...)

        dataTipH = dataTipsH(1);

        position = get(dataTipH,'Position');
        patchH = get(dataTipH,'Host');
        set(patchH,'DisplayName', 'MEG coordinates');
        
        selectedVertex = find(position(1) == patchH.Vertices(:,1) & position(2) == patchH.Vertices(:,2)  & position(3));

        normal = mesh.normals(selectedVertex,:);    
        s = sprintf('VERTEX # %d\nPosition (cm):\nx = %.2f   y=  %.2f   z=  %.2f\nNormal:\nx= %.2f   y=  %.2f   z=  %.2f)',...
            selectedVertex, position, normal);   

        newText = s;
    end


end
