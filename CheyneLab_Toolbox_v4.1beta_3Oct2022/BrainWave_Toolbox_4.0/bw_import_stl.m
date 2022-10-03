function bw_import_stl( file )

[~,~,e] = fileparts(file);
colors = [];
hasColor = 0;
if strcmp(e,'.stl')
    stl = stlread(file);
    faces = stl.ConnectivityList;
    vertices = stl.Points * 100.0;    
    colors = [];
    hasColor = 0;
elseif strcmp(e,'.obj')
    mesh = bw_readObjFile(file);
    faces = mesh.faces;
    vertices = mesh.vertices * 100.0; 
    colors = mesh.colors;
    hasColor = 1;
else
    errordlg('unknown file type');
    return;
end 

fprintf('Read %d vertices, %d faces, %d colors from %s\n', size(vertices,1), size(faces,1), size(colors,1), file);
    
% assume stl files are in units of meters - convert to cm

fvc = [];

patch_vertices = [];
patch_faces = [];
bb = [-12.0 12.0 -10.0 10.0 -8.0 12.0];

fh = figure('Color','white','name','Import STL Surface','numberTitle','off','menubar','none','Position',[25 800 800 800]);

hold on

% Add a camera light, and tone down the specular highlighting
lh = camlight('headlight');

% Fix the axes scaling, and set a nice view angle
axis('equal');
view([-135 35]);
        
% get handle to cursor
cursorH = datacursormode;

% update lighting during rotate
h = rotate3d;
h.Enable = 'on';
h.ActionPostCallback = @updateLight;
    function updateLight(~,~)
        delete(lh)
        lh = camlight('headlight');
    end

if isempty(colors)
    faceColor = [223/255 206/255 166/255];
    colors = repmat(faceColor,size(vertices,1),1);
end

fvc = colors;

ph = patch('Vertices',vertices,'Faces',faces,'FaceVertexCData',fvc,...
      'FaceColor','flat','EdgeColor','none');
ph.Clipping = 'off';

shading flat
material dull;
lighting gouraud;

tfids = [[0 0 0]; [0 0 0]; [0 0 0]];
fidcols = [ 0 0 1; 0 1 0; 1 0 0 ];
fidH = scatter3(tfids(:,1),tfids(:,2),tfids(:,3),100, fidcols,'filled');  

axtoolbar('Visible', 'on');
axtoolbar('default');
updateLight

axis off
hold off

FILE_MENU = uimenu('Label','File');
uimenu(FILE_MENU,'label','Save As...','Callback',@save_OBJ_Callback);    
uimenu(FILE_MENU,'label','Export to VTK Mesh ...','separator','on','Callback',@save_meshCallback);    
uimenu(FILE_MENU,'label','Export to Shape File ...','Callback',@save_shapeCallback);    
uimenu(FILE_MENU,'label','Close','Callback','closereq','Accelerator','W','separator','on');    

       % set fiducials
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.02 0.9 0.1 0.04],'String','Set Nasion','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','blue','callback',@set_nas_callback);
        
        function set_nas_callback(~,~)
            s = getCursorInfo(cursorH);
            tfids(1,:) = s.Position;
            set(fidH,'XData',tfids(:,1), 'YData',tfids(:,2), 'ZData',tfids(:,3))         
        end
    
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.02 0.84 0.1 0.04],'String','Set Left Ear','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','green','callback',@set_le_callback);
        function set_le_callback(~,~)
            s = getCursorInfo(cursorH);
            tfids(2,:) = s.Position;
            set(fidH,'XData',tfids(:,1), 'YData',tfids(:,2), 'ZData',tfids(:,3))         
        end  
    
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.02 0.78 0.1 0.04],'String','Set Right Ear','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@set_re_callback);
        function set_re_callback(~,~)
            s = getCursorInfo(cursorH);
            tfids(3,:) = s.Position;
            set(fidH,'XData',tfids(:,1), 'YData',tfids(:,2), 'ZData',tfids(:,3))         
        end               
    
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.02 0.7 0.1 0.04],'String','Re-align','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','black','callback',@realign_callback);      
        function realign_callback(~,~)
            % put values in fiducial relative coordinates - keep in cm
            M = getAffineVox2CTF(tfids(1,:), tfids(2,:),tfids(3,:) ,1.0);
            pts = [vertices ones(size(vertices,1),1)];    
            vertices = pts*M;                        
            clear pts;
            vertices(:,4) = [];  
           
            % now update fids to new coordinates           
            rfids = [tfids ones(3,1)] * M;  
            tfids = rfids(:,1:3); 

            % update display
            set(ph, 'Vertices',vertices);
            set(fidH,'XData',tfids(:,1), 'YData',tfids(:,2), 'ZData',tfids(:,3))         
            
            xlim([-15 15]);
            ylim([-15 15]);
            zlim([-15 15]);
            
            set(gca,'View',[180 0]);        
            updateLight
        end
    
        cursorR = uicontrol('style','radiobutton','units','normalized','Position',...
            [0.85 0.8 0.08 0.04],'String','Cursor','BackgroundColor','white','value',0,...
            'FontSize',12,'ForegroundColor','black','callback',@cursor_callback);
        function cursor_callback(src,~)
            set(src,'value',1);
            set(rotateR,'value',0);
            cursorH = datacursormode;          
        end 
        rotateR = uicontrol('style','radiobutton','units','normalized','Position',...
            [0.85 0.76 0.08 0.04],'String','Rotate','BackgroundColor','white','value',1,...
            'FontSize',12,'ForegroundColor','black','callback',@rotate_callback);
        function rotate_callback(src,~)
            set(src,'value',1);
            set(cursorR,'value',0);
            delete(findall(gcf,'Type','hggroup'));           
            rotate3d;
        end  
    
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.02 0.5 0.08 0.04],'String','Revert','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','red','callback',@reset);      
        function reset(~,~) 
            
            r = questdlg('Revert to original mesh?','Import STL Surface','Yes','No','No');
            if strcmp(r,'Yes')
                faces = stl.ConnectivityList;
                vertices = stl.Points * 100.0;    
                fvc = colors;
                set(ph, 'Vertices',vertices,'Faces',faces,'FaceVertexCData',fvc);          
            end
        end
    
    
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.02 0.64 0.16 0.04],'String','Crop to Bounding Box','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','black','callback',@crop_callback);      
        function crop_callback(~,~)

            % get bounding box for head
            % set bounding box
            bb_x = sprintf('%.1f %.1f', bb(1), bb(2));
            bb_y = sprintf('%.1f %.1f', bb(3), bb(4));
            bb_z = sprintf('%.1f %.1f', bb(5), bb(6));
            
            input = inputdlg({'Head bounding box X range (cm)'; 'Head bounding box Y range (cm)';'Head bounding box Z range (cm)'},......
                'Set Bounding Box',[1 50; 1 50; 1 50],{bb_x, bb_y, bb_z});
            if isempty(input)
                return;
            end   
            bb(1:2) = str2num(input{1});
            bb(3:4) = str2num(input{2});
            bb(5:6) = str2num(input{3});            
          
            f = faces;
            fidx = [];
            for k=1:size(f,1)
               if   all( vertices(f(k),1) < bb(2) ) && all( vertices(f(k),1) > bb(1)) && ....
                    all( vertices(f(k),2) < bb(4) ) && all( vertices(f(k),2) > bb(3)) && ...
                    all( vertices(f(k),3) < bb(6) ) && all( vertices(f(k),3) > bb(5) )
                   fidx(end+1) = k;
               end
            end
            faces = f(fidx,:);
                                   
            set(ph,'Faces',faces);
            updateLight
                        
        end     

        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.02 0.18 0.14 0.04],'String','Grow Mask at Cursor','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','black','callback',@extract_surface_callback);      
        function extract_surface_callback(~,~)
            
            % get vertex at cursor position
            s = getCursorInfo(cursorH);
            if isempty(s)
                fprintf('Select seed point with cursor ...\n');
                return;
            end
            selectedVertex = find(s.Position(1) == vertices(:,1) & s.Position(2) == vertices(:,2)  & s.Position(3) == vertices(:,3));
            
            if isempty(selectedVertex)
                warndlg('Use cursor to select a seed vertex ...');
                return;
            end
                        
            % GUI to get patch order 
            patchOrder = 50; 
            input = inputdlg('Select Neighborhood Order','Patch Parameters',[1 35], {num2str(patchOrder)});
            if isempty(input)
                return;
            end
          
            patchOrder = str2double(input{1});
            
            % function uses MEG vertices in cm!
            % dt_compute_patch_from_vertex expects faces as base 0 numbering
            mesh.meg_vertices = vertices;
            mesh.faces = faces - 1;
            
            [patch_vertices, patch_faces, area] = dt_compute_patch_from_vertex(mesh, selectedVertex, patchOrder);
                
            fprintf('patchOrder %d (# vertices = %d, # triangles = %d, area = %g cm^2\n',...
                patchOrder, size(patch_vertices,1), size(patch_faces,1), area );       
                         
            if ~isempty(patch_vertices)  
                fvc = colors;
                fvc(patch_vertices,:) = repmat([1 0 0],size(patch_vertices,1),1);
                set(ph,'FaceVertexCData', fvc);                
            end

        end      
    
        uicontrol('style','pushbutton','units','normalized','Position',...
            [0.02 0.12 0.12 0.04],'String','Crop to Mask','BackgroundColor','white',...
            'FontSize',10,'ForegroundColor','black','callback',@crop_to_mask_callback);      
        function crop_to_mask_callback(~,~)

            if isempty(patch_faces)
                return;
            end
            faces = faces(patch_faces,:);       
            fvc = colors;
                    
            set(ph,'Faces',faces);
            
            % reset from red to original colours
            set(ph,'FaceVertexCData',fvc);
                           
            updateLight
                        
        end
      
        function save_OBJ_Callback( ~,~ )

                if isempty(vertices)
                    warndlg('No surface points to save');
                    return;            
                end
                [~,name,~] = fileparts(file);
                saveName = strcat(name,'_edited.obj');

                [filename, pathname, ~] = uiputfile( ...
                    {'*.obj','OBJ file (*.obj)'}, ...
                    'Save mesh as',saveName);

                if filename == 0
                    return;
                end
                
                % remove unused vertices before saving
%                 fprintf('Removing redundant vertices from mesh ...\n');
%                 [mesh.faces, mesh.vertices, mesh.colors] = relabelFaces(faces,vertices,colors);
               
                fprintf('Writing edited mesh (%d vertices, %d faces)\n', size(vertices,1), size(faces,1));
                fullname = fullfile(pathname,filename);
                mesh.vertices = vertices * 0.01;  % convert back to meters
                mesh.faces = faces;
                if hasColor
                    mesh.colors = colors;
                else
                    mesh.colors = [];
                end
                bw_writeObjFile(fullname, mesh);

        end
    
    
        function save_meshCallback( ~,~ )

                if isempty(vertices)
                    warndlg('No surface points to save');
                    return;            
                end
                saveName = strrep(file,'.stl','.vtk');

                [filename, pathname, ~] = uiputfile( ...
                    {'*.vtk','VTK mesh file (*.vtk)'}, ...
                    'Save surface as mesh file',saveName);

                if isequal(filename,0) || isequal(pathname,0)
                    return;
                end

                fullname = fullfile(pathname,filename);
                save_surface_vtk(vertices, faces, fullname);

        end
    
        function save_shapeCallback( ~,~ )

                if isempty(vertices)
                    warndlg('No surface points to save');
                    return;            
                end
                
                saveName = strrep(file,'.stl','.pos');

                [filename, pathname, ~] = uiputfile( ...
                    {'*.pos','Shape/Polhemus file (*.pos)'}, ...
                    'Save surface as mesh file',saveName);

                if isequal(filename,0) || isequal(pathname,0)
                    return;
                end

                fullname = fullfile(pathname,filename);
                
                fid = fopen(fullname,'w');
                
                % save vertices for displayed faces only                             
                save_verts = [];
                for k=1:size(faces,1)
                    verts = faces(k,1:3)';
                    save_verts = [save_verts; verts];                   
                end
                save_verts = unique(save_verts);
                
                savePts = vertices(save_verts,1:3);
                npts = size(savePts,1);
                
                fprintf('Saving %d points to file %s...\n', npts, fullname);
                fprintf(fid,'%d\n', npts);
                for k=1:npts
                    fprintf(fid,'%d %.2f %.2f %.2f\n', k, savePts(k,1:3));
                end   
                
                fprintf(fid,'Nasion %.2f %.2f %.2f\n',  tfids(1,1:3));
                fprintf(fid,'LPA %.2f %.2f %.2f\n',  tfids(2,1:3));
                fprintf(fid,'RPA %.2f %.2f %.2f\n', tfids(3,1:3));
               
                fclose(fid);
             

        end
end


function save_surface_vtk(vertices, faces, filename )

    fid=fopen(filename,'w');
    if fid == 0
        return;
    end

    faces = faces - 1;  % faces are base 0 in vtk files.
    npts = size(vertices,1);

    fprintf('Saving %d points to VTK file %s\n', npts, filename);
    fprintf(fid,'# vtk DataFile Version 3.0\nvtk output\nASCII\nDATASET POLYDATA\n');
    % write vertices
    fprintf(fid,'POINTS %d float\n',npts);

    for k=1:npts
        fprintf(fid,'%3.7f %3.7f %3.7f\n', vertices(k,1), vertices(k,2), vertices(k,3));
    end
    % write faces
    nfaces=size(faces,1);
    fprintf(fid,'POLYGONS %d %d\n',nfaces,4*nfaces);
    for k=1:nfaces
       fprintf(fid,'3 %d %d %d\n',faces(k,1), faces(k,2), faces(k,3));
    end
    fclose(fid);        


end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% remove unused vertices in a mesh and return the 
% new vertex list and relabeled faces indices
%
function [f2, v2, c2] = relabelFaces(faces, vertices, vertexColors)

    keepVerts = unique(faces(:));  % valid vertices

    vidx = zeros(size(vertices,1), 1);
    vidx(keepVerts) = 1;            

    f2 = faces;

    for k=1:size(vertices,1)
        if vidx(k) == 0
            % renumber face indices that will be deleted. 
            idx = find(f2 > k);
            f2(idx) = f2(idx) - 1;          
        end
    end

    % compress vertex list
    v2 = vertices(keepVerts,:);
    if ~isempty(vertexColors)
        c2 = vertexColors(keepVerts,:);
    else
        c2 = [];
    end
end



% local copy for stand-alone
function M = getAffineVox2CTF(nasion_pos, left_preauricular_pos, right_preauricular_pos, mmPerVoxel )
%
%   function M = bw_getAffineVox2CTF(nasion_pos, left_preauricular_pos, right_preauricular_pos, mmPerVoxel )
%
%   DESCRIPTION: Takes the voxel coordinates of fiducial points 
%   (nasion_pos, left_preauricular_pos, right_preauricular_pos) and the 
%   scaling factor (mmPerVoxel) from an isotropic MRI and returns the 4 by 
%   4 affine transformation matrix (M) that is capable of transforming a 
%   point from voxel coordinates to CTF head coordinates.
%
% (c) D. Cheyne, 2011. All rights reserved.
% 
%  
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% written by D. Cheyne.  September 2006
%
% this script takes as input the voxel coordinates of the fiducial points
% and the scaling factor from mm to voxel dimensions, assuming that
% scaling is the same in all directions (isotropic  MRI), and returns the
% 4x4 affine tranformation matrix that converts a point in voxel
% coordinates to CTF head coordinates 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% build CTF coordinate system
% origin is midpoint between ears
origin = (left_preauricular_pos + right_preauricular_pos) /2;

% x axis is vector from this origin to Nasion
x_axis = nasion_pos - origin; 
x_axis=x_axis/norm(x_axis);

% y axis is origin to left ear vector
y_axis= left_preauricular_pos - origin;
y_axis=y_axis/norm(y_axis);

% This y-axis is not necessarely perpendicular to the x-axis, this corrects
z_axis=cross(x_axis,y_axis);
z_axis=z_axis/norm(z_axis);

y_axis=cross(z_axis,x_axis);
y_axis=y_axis/norm(y_axis);

% now build 4 x 4 affine transformation matrix

% rotation matrix is constructed from principal axes as unit vectors
% note transpose for correct direction of rotation 
rmat = [ [x_axis 0]; [y_axis 0]; [z_axis 0]; [0 0 0 1] ]';

% scaling matrix from mm to voxels
smat = diag([mmPerVoxel mmPerVoxel mmPerVoxel 1]);

% translation matrix - subtract origin
tmat = diag([1 1 1 1]);
tmat(4,:) = [-origin, 1];

% affine transformation matrix for voxels to CTF is concatenation of these
% three transformations. Order of first two operations is important. Since
% the origin is in units of voxels we must subtract it BEFORE scaling. Also
% since translation vector is in original coords must be also be rotated in
% order to rotate and translate with one matrix operation

M = tmat * smat * rmat;

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
