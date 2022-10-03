%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [labels, JuBrain, atlasFile] = dt_get_JuBrain_labels(atlasPath)
%
% get jubrain structure for SPM Anatomy (JuBrain) atlas
%
% D. Cheyne, October 2021
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [labels, JuBrain, atlasFile] = dt_get_JuBrain_labels(atlasPath)
     
    atlasFile = sprintf('%s%sJuBrain%sJuBrain_Map_v30.nii',atlasPath, filesep, filesep);
    matFile = sprintf('%s%sJuBrain%sJuBrain_Data_v30.mat',atlasPath, filesep, filesep);
    t = load(matFile);
    JuBrain = t.JuBrain;
    labels = {JuBrain.Namen};

    
end
