%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function function aal_region = dt_get_AAL2_labels (index)
%
% get labels and atlas indices for AAL2 atlas
%
% D. Cheyne, October 2021
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [labels, values, atlasFile] = dt_get_Talairach_labels(atlasPath)
     
    atlasFile = sprintf('%s%sTalairach%stalairach.nii', atlasPath,filesep,filesep);
    matFile = sprintf('%s%sTalairach%stalairach_data.mat', atlasPath,filesep,filesep);
    t = load(matFile);
    tlabels = t.talairach_data.labels;
    
    labels = {};
    values = [];
    
    % get unique labels for Brodmann areas left and right
    for i=1:size(tlabels,1)
        s = strtrim(tlabels(i,:));
        % ignore non-gyral labels
        if contains(s, '*') || contains(s, 'Sub-Gyral') || contains(s, 'White Matter')
            continue; 
        end

        idx = strfind(s,'Brodmann area');
        if ~isempty(idx)
            dots = strfind(s,'.');          
            % include gyral labels
            s2 = s(dots(1)+1:dots(2)-1);
            s3 = s(dots(2)+1:dots(3)-1);
            if contains(s,'Left')
                str = sprintf('%s %s %s (L)',s2, s3, s(idx:end));
            else
                str = sprintf('%s %s %s (R)',s2, s3, s(idx:end));
            end
            labels(end+1) = cellstr(str);     
            values(end+1) = i-1;
        end
    end
    % remove duplicates from both lists without sorting
    [~, idxA, ~] = unique(labels,'stable');
    labels = labels(idxA);
    values = values(idxA);
    
end
