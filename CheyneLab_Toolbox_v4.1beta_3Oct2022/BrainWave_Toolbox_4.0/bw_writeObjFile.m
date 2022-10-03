% function to write Skanect version of Wavefront OBJ files 
% if exist vertex RGB colors follow each vertex coordinate. 

function bw_writeObjFile(filename, mesh)

    fid=fopen(filename,'w');
    if fid == 0
        return;
    end

    fprintf('Saving mesh values to WaveFront format .obj format %s\n', filename);

    fprintf(fid,'# OBJ file saved from BrainWave\n');

    % write vertices and colors

    if isempty(mesh.colors)
        for k=1:size(mesh.vertices,1)
            fprintf(fid,'v %3.7f %3.7f %3.7f\n', mesh.vertices(k,1), mesh.vertices(k,2), mesh.vertices(k,3));
        end
    else
       for k=1:size(mesh.vertices,1)
            fprintf(fid,'v %3.7f %3.7f %3.7f %3.7f %3.7f %3.7f\n',...
                mesh.vertices(k,1), mesh.vertices(k,2), mesh.vertices(k,3), mesh.colors(k,1), mesh.colors(k,2), mesh.colors(k,3));
       end
    end

    fprintf(fid,'\n');  % need space here?

    % write faces
    for k=1:size(mesh.faces,1)
       fprintf(fid,'f %d %d %d\n',mesh.faces(k,1), mesh.faces(k,2), mesh.faces(k,3));
    end

    fprintf(fid,'# end of file\n');
    fclose(fid);        
     
  
end
