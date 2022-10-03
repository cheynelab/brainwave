function [dip_params] = bw_readCTFDipoleFile(dipoleFile)    
    
        dip_params = [];
        
        fid = fopen(dipoleFile,'r');                

        if (fid == -1)
            fprintf('failed to open file <%s>\n',dipoleFile);
            return;
        end
                      
        num_dipoles = 0;
        
        ncount = 0;
        while 1
            s = fscanf(fid,'%s',1);
            if strncmp(s,'Dipoles',7)
                break;
            end
            if feof(fid)
                fprintf('Could not find Dipoles key word\n');
                return;
            end
        end
        
        s = fscanf(fid,'%s',1);  % skip {
        s = fgets(fid);
        while 1
            s = fgets(fid);
            if strncmp('}',s(1), 1)
                break;
            end
            colon = find(s==':');
            if ~isempty(colon)                        
                ss = s(colon+1:end);
                params = sscanf(ss,'%f %f %f %f %f %f %f %f');
                num_dipoles = num_dipoles+1;
                ncount = ncount + 1;
                dip_params(num_dipoles,:) = params(1:7);
            end
        end

        fclose(fid);                            
        fprintf('Read %d dipoles from file %s...\n',ncount, dipoleFile);

end
