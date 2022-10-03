function [VS_ARRAY] = bw_subtract_VS( VS_ARRAY1, VS_ARRAY2 )
%
% script to subtract two virtual sensor data structures passed as VS_ARRAY 
%

    VS_ARRAY = [];
    
    t = size(VS_ARRAY1,2);
    numSubjects = size(VS_ARRAY2,2);
    fprintf('Creating difference waveforms for %d subjects...\n', numSubjects);

    if t ~= numSubjects
        fprintf('VS_ARRAYS contain different number of datasets\n');
        return;
    end
    
    s1 = VS_ARRAY1{1};
    numTrials = size(s1.vs_data,2);
     
    % currently average is not saved if array contains single trial data. 
    % Since conditions may have different number of trials cannot subtract at
    % the single trial level - for now exit.
         
    if numTrials > 1
        fprintf('Cannot subtract single trial VS data ...\n');
        return;
    end

    VS_ARRAY = VS_ARRAY1;  % copy voxel parameters etc ... assumes they are the same...
    for j=1:numSubjects
        s1 = VS_ARRAY1{j};
        s2 = VS_ARRAY2{j};
        
        s = sprintf('%s-%s',s1.dsName, s2.dsName);
        VS_ARRAY{j}.dsName = s;

        idx = strfind(s1.plotLabel,'.ds');        
        idx2 = strfind(s2.plotLabel,'.ds');
        s = sprintf('%s-%s_%s',s1.plotLabel(1:idx-1), s2.plotLabel(1:idx2-1), s1.plotLabel(idx+2:end));
        VS_ARRAY{j}.plotLabel = s;
              
        % now subtract the data
        VS_ARRAY{j}.vs_data = VS_ARRAY1{j}.vs_data - VS_ARRAY2{j}.vs_data;
    end

end

