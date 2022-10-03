
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% coregister Yokogawa Marker data to polhemus HPI and fiducials
% July 31, 2018 (written by M. Woodbury)
% modified by D. Cheyne - Sept, 2018
% now checks if HPI coil locations in .mrk file are set to zero (disabled?) 
% and if so removes that coil from both arrays prior to fit
% Now also returns fit error (in cm) for each coil
% 
function [meg2head_transm] = MEG2polhemus_matrix(elpFile, mrkFile)

    errorLimit = 1.0;  % in cm, exclude coil if its fit error is greater than this 

    meg2head_transm = [];

    % get coordinates of digitized points in headshape-relative coords
    [shape] = readElpFile(elpFile); % in meters
    fid_pnts_cm = shape.fid.pnt(4:end,:)*100; % convert to cm 

    % get coordinates of digitized points in MEG-relative coords
    fprintf('Reading HPI coil locations from %s\n', mrkFile);
    HPI_coils_head = readKITMarkers(mrkFile); % returns in cm

    % first check for disabled HPI coils - all coords set to zero...
    sumVec = sum(HPI_coils_head,2);
    badCoils = find(sumVec == 0.0);
    if ~isempty(badCoils)
      HPI_coils_head(badCoils,:) = [];
      fid_pnts_cm(badCoils,:) = [];
    end

    if length(HPI_coils_head) < 3
      fprintf('Error computing co-registration matrix: Need at least 3 valid HPI coils\n');
      return;
    end

    % compute fit recursively until coil error is below limit or only 3
    % coils left
    while 1
        [R,T,Yf,Err] = rot3dfit(HPI_coils_head,fid_pnts_cm); %calc rotation transform
        delta = fid_pnts_cm - Yf;
        coil_error_cm = cellfun(@norm,num2cell(delta,2))
        
        % exclude coils with large eror to flag bad coils... 
        [maxError, maxCoil] = max(coil_error_cm);
        if maxError > errorLimit 
            if length(HPI_coils_head) < 4
                beep;
                fprintf('*** Warning: one or more coil fit errors exceed %.1f cm. Co-registration may be affected ***\n',errorLimit);
                break;
            end
            fprintf('Excluding coil %d (error = %.2f cm) and re-trying fit...\n',maxCoil,maxError);
            HPI_coils_head(maxCoil,:) = [];
            fid_pnts_cm(maxCoil,:) = [];
        else
            break;
        end
    end

    meg2head_transm = [[R;T]'; 0 0 0 1];  %reorganise and make 4*4 transformation matrix


end





