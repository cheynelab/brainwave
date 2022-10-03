%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% function [patch_vertices, nfaces, area] = dt_compute_patch_from_vertex(mesh, seed_vertex, patchOrder)
%
% computes an n-th neighborhood order cortical surface patch on the passed mesh starting at the seed_vertex 
% returns patch_vertices = indices into passed mesh.
%
% (c) D. Cheyne, 2021. All rights reserved.
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [patch_vertices, patch_faces, total_area] = dt_compute_patch_from_vertex(mesh, seed_vertex, patchOrder)


    if ~exist('patchOrder','var')
        patchOrder = 5;
    end
    
    patch_vertices = [];
    NFaces = 0;
    total_area = 0.0;
    
     
    vertices = mesh.meg_vertices;
    faces = mesh.faces + 1;
    clear mesh;
    
    patch_vertices = seed_vertex;
    
    % iterate through increasing neighborhood order and get vertices
    % of surrounding triangles
    patch_faces = [];
    
    % grow patch outward from seed location...
         
    tic;
         
    fprintf('Generating cortical patch (order = %d) ... \n', patchOrder);

    % for patch order = 0 this loop is skipped
    if patchOrder == 0
        NFaces = 0;
        total_area = 0.0;
        return;
    end
    
    for j=1:patchOrder        
        
        new_vertices = [];
        
        % faster code without for loops! 
        [a, ~] = ismember(faces, patch_vertices);
        [fidx, ~] = find(a);
        verts = faces(fidx,1:3)';
        new_vertices = [new_vertices; verts];
        patch_faces = [patch_faces; fidx];

        % remove duplicate vertices for this iteration
        new_vertices = unique(new_vertices);
        
        % add to the retained vertices from last iteration
        patch_vertices = [patch_vertices; new_vertices];
          
        % remove duplicate entries
        patch_vertices = unique(patch_vertices,'rows');
        patch_faces = unique(patch_faces,'rows');
        
        if size(patch_faces,1) == size(faces,1)
            fprintf('patch reached total number of faces in mesh\n...');
            break;
        end
                
    end

    % get total surface area of patch
    total_area = 0.0;
    for k=1:size(patch_faces,1)
        idx = faces(patch_faces(k),:);
        verts = vertices(idx,:);
        v1 = verts(1,:);
        v2 = verts(2,:);
        v3 = verts(3,:);
        a = v1-v2;
        c = v1-v3;       
        area = norm(cross(a,c)) * 0.5;
        total_area = total_area + area;
    end    
    
    fprintf('... done. \n', patchOrder);
             
    toc;
    
end