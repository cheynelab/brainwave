%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function function aal_region = dt_get_AAL2_labels (index)
%
% get labels and atlas indices for AAL2 atlas
%
% D. Cheyne, October 2021
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [labels, values, atlasFile] = dt_get_AAL2_labels(atlasPath)
     
    atlasFile = sprintf('%s%sAAL2%sROI_MNI_V5.nii',atlasPath, filesep, filesep);
    matFile = sprintf('%s%sAAL2%sROI_MNI_V5_List.mat',atlasPath, filesep, filesep);
    t = load(matFile);
    ROI = t.ROI;
    labels = {ROI.Nom_L};
    values = cell2mat({ROI.ID});
    
end
