    function [headshape, NASION, LPA, RPA] = bw_readPolhemusFile (filename)

        % function to read Polemus data from various file formats
        % written by D. Cheyne and M. Woodbury

        % returns fiducials if available and head surface points in mm 

        headshape = [];
        NASION = [];
        LPA = [];
        RPA = [];
        
        [~,~,EXT] = fileparts(filename);
        
        if (strcmp(EXT,'.pos') == 1)

            fid = fopen(filename);
            if fid == -1
                error('Unable to open shape file.');
            end

            A = textscan(fid,'%s%s%s%s');
            fclose(fid);

            headshape = [str2double(A{2}(2:end))*10 str2double(A{3}(2:end))*10 str2double(A{4}(2:end))*10];

            idx = find(strcmp((A{1}), 'nasion') | strcmp((A{1}), 'Nasion'));
            if isempty(idx)
                fprintf('Could not find nasion fiducial in pos file\n');
                return;
            end
                       
            NASION = [str2double(A{2}(idx)) str2double(A{3}(idx)) str2double(A{4}(idx))] * 10.0;
            if size(NASION,1) > 1     % average if multiple instances
                NASION = mean(NASION,1);
            end
                
            idx = find(strcmp((A{1}), 'left') | strcmp((A{1}), 'LPA'));
            if isempty(idx)
                fprintf('Could not find left fiducial in pos file\n');
                return;
            end
            LPA = [str2double(A{2}(idx)) str2double(A{3}(idx)) str2double(A{4}(idx))] * 10.0;
            if size(LPA,1) > 1     % average if multiple instances
                LPA = mean(LPA,1);
            end
            
            idx = find(strcmp((A{1}), 'right') | strcmp((A{1}), 'RPA'));
            if isempty(idx)
                fprintf('Could not find right fiducial in pos file\n');
                return;
            end
            RPA = [str2double(A{2}(idx)) str2double(A{3}(idx)) str2double(A{4}(idx))] * 10.0;
            if size(RPA,1) > 1     % average if multiple instances
                RPA = mean(RPA,1);
            end
            
        elseif (strcmp(EXT,'.hsp') == 1)

            % read KIT / Macquarie .hsp file - data is in meters
            fid = fopen(filename);
            E = fscanf(fid,'%c');
            fclose(fid);

            % get coordinates for fiducials
            fidstarti = strfind(E,'%F');
            fidendi = regexp(E(fidstarti(1):end),'\r');
            fidendi = fidendi(1:length(fidstarti)) + fidstarti(1);

            NASION = E(fidstarti(1)+2:fidendi(1));
            NASION = str2num(NASION) * 1000.0;

            LPA = E(fidstarti(2)+2:fidendi(2));
            LPA = str2num(LPA) * 1000.0;

            RPA = E(fidstarti(3)+2:fidendi(3));
            RPA = str2num(RPA) * 1000.0;

            % get coordinates for headshape
            headshapestarti = strfind(E,'position of digitized points');
            headshapestartii = regexp(E(headshapestarti(1):end),'\r');
            headshape = E(headshapestarti(1)+headshapestartii(2)+1:end);
            headshape = str2num(headshape) * 1000.0;  % return in mm        
        end

    end