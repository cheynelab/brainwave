function [TFR_ARRAY] = bw_subtract_TFR( TFR_ARRAY1, TFR_ARRAY2 )
%
% script to subtract two virtual sensor data structures passed as VS_ARRAY 
%

    TFR_ARRAY = [];
    
    t = size(TFR_ARRAY1,2);
    numSubjects = size(TFR_ARRAY2,2);
    fprintf('Creating difference waveforms for %d subjects...\n', numSubjects);
    
    if t ~= numSubjects
        fprintf('VS_ARRAYS contain different number of datasets\n');
        return;
    end
    
    TFR_ARRAY = TFR_ARRAY1;  % copy voxel parameters etc ... assumes they are the same...
    for j=1:numSubjects
        s1 = TFR_ARRAY1{j};
        s2 = TFR_ARRAY2{j};
        
        s = sprintf('%s-%s',s1.dsName, s2.dsName);
        TFR_ARRAY{j}.dsName = s;

        idx = strfind(s1.plotLabel,'.ds');        
        idx2 = strfind(s2.plotLabel,'.ds');
        s = sprintf('%s-%s_%s',s1.plotLabel(1:idx-1), s2.plotLabel(1:idx2-1), s1.plotLabel(idx+2:end));
        TFR_ARRAY{j}.plotLabel = s;
              
        % now subtract the data
        TFR_ARRAY{j}.PLF = TFR_ARRAY1{j}.PLF - TFR_ARRAY2{j}.PLF;
        TFR_ARRAY{j}.TFR = TFR_ARRAY1{j}.TFR - TFR_ARRAY2{j}.TFR;
        TFR_ARRAY{j}.MEAN = TFR_ARRAY1{j}.MEAN - TFR_ARRAY2{j}.MEAN;
    end

end

