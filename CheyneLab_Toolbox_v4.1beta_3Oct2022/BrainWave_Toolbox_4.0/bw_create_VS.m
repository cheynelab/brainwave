%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [VS_ARRAY] = bw_create_VS( dsList, covDsList, voxelList, orientationList, labelList, params)
% % old syntax
%    function [VS_ARRAY] = bw_create_VS( dsList, covDsList, voxelList, orientationList, params, vs_options)
% 
% replaces bw_plot_virtual_sensor. Just creates and returns the VS_ARRAY  
%
% (c) D. Cheyne, 2015
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [VS_ARRAY] = bw_create_VS( dsList, covDsList, voxelList, orientationList, labelList, params)
            
    VS_ARRAY = [];
    
    numSubjects = size(voxelList,1);
    
    wbh = waitbar(0,'Computing VS data...');

    for k=1:numSubjects

        voxel = voxelList(k,:);
        dsName = char(dsList(k));
        covDsName = char(covDsList(k));
        label = char(labelList(k));
        
        fprintf('Generating virtual sensor waveforms for dataset %s...\n', dsName);

        s = sprintf('plotting data for subject %d', k);
        waitbar(k/numSubjects,wbh,s);

        % note in this case we cannot specify orientation
        if ~isempty(orientationList)
            normal = orientationList(k,1:3);
        else
            normal = [];
        end
        
        [timeVec, vs_data, comnorm] = bw_make_vs(dsName, covDsName, voxel, normal, params);

        if isempty(timeVec)    % in case aborted
            delete(wbh);
            return;
        end

        VS_DATA.dsName = dsName;
        VS_DATA.covDsName = covDsName;
        VS_DATA.voxel = voxel;
        VS_DATA.normal = comnorm';
        VS_DATA.timeVec = timeVec;
        VS_DATA.vs_data = vs_data;   

        VS_DATA.filter = params.beamformer_parameters.filter;    

        if params.beamformer_parameters.useBaselineWindow
            VS_DATA.baseline = params.beamformer_parameters.baseline;    
        else
            VS_DATA.baseline = [timeVec(1) timeVec(end)];  
        end
        
        % * new in ver 4.0 - added labels from plot dialog or voxelList ...
        VS_DATA.label = label; 
        
        % old default plot labels with more detail.... 
        if params.vs_parameters.rms
            plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(rms)', char(dsName), voxel);
        else
            plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(%.3f_%.3f_%.3f)', char(dsName), voxel, comnorm);
        end
        VS_DATA.plotLabel = plotLabel;
        
        VS_ARRAY{k} = VS_DATA;
        
    end

    delete(wbh);


end
