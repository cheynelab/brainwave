
% write a minimal Dipole file
function bw_writeCTFDipoleFile(dipoleFile, dip_params)    
        
        fid = fopen(dipoleFile,'w');                

        if (fid == -1)
            fprintf('failed to open file <%s>\n',dipoleFile);
            return;
        end                   

        fprintf(fid,'Dipoles\n');
        fprintf(fid,'{\n');
       	fprintf(fid,'// Dipole parameters ...\n');
        fprintf(fid,'// xp (cm)		yp (cm)		zp (cm)		xo		yo		zo			Mom(nAm)	Label\n');

        for k=1:size(dip_params,1)                     
            fprintf(fid,'%d: %.3f %.3f %.3f %.3f %.3f %.3f %.3f Dipole%d\n',k, dip_params(k,1), dip_params(k,2), dip_params(k,3),...
                dip_params(k,4), dip_params(k,5), dip_params(k,6), dip_params(k,7), k);
        end
        fprintf(fid,'}\n');

        fclose(fid);                            
        fprintf('Writing %d dipoles to file %s...\n',size(dip_params,1), dipoleFile);

end
