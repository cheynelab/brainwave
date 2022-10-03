% function to read Skanect version of Wavefront OBJ files 
% vertex RGB colors follow each vertex coordinate. 
% faces are base 1 numbered !

function mesh = bw_readObjFile(file)

    tt = importdata(file);
    
    vidx = find(strcmp(tt.textdata,'v'));
    fidx = find(strcmp(tt.textdata,'f'));
    
    % importdata drops #comments and blank lines so indexing is off by one 
    % - may need more checking for other formats
    
    % faces
    flines  = tt.data(fidx(1)-1:fidx(end)-1,:);
    mesh.faces = flines(:,1:3);
    
    % vertices and colors
    vlines = tt.data(vidx(1)-1:vidx(end)-1,:);
    mesh.vertices = vlines(:,1:3);
    if size(vlines,2) > 4
        mesh.colors = vlines(:,4:6);
    else
        mesh.colors = [];
    end
    
end
