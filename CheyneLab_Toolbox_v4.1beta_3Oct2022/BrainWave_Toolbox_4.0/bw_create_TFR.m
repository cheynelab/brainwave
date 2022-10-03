%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [TFR_ARRAY] = bw_create_TFR( dsList, covDsList, voxelList, orientationList, params)
% old syntax
%    function [TFR_ARRAY] = bw_create_TFR( dsList, covDsList, voxelList, orientationList, params, vs_options, tfr_options)
% 
% replaces bw_plot_virtual_sensors.  Just computes and returns the TFR_ARRAY
%
% (c) D. Cheyne, 2014
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [TFR_ARRAY] = bw_create_TFR( dsList, covDsList, voxelList, orientationList, labelList, params)
            
    TFR_ARRAY = [];
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

        % for TFRs have to force return of single trial VS data
        params.vs_parameters.saveSingleTrials = 1;

        % note in this case we cannot specify orientation
        if ~isempty(orientationList)
            normal = orientationList(k,1:3);
        else
            normal = [];
        end
        
        [timeVec, vs_data, comnorm] = bw_make_vs(dsName, covDsName, voxel, normal, params);

        if isempty(timeVec)    % in case aborted
            return;
        end

        % compute frequency transform
        freqStep = params.tfr_parameters.freqStep;                             % frequency bin size for TF plot
        freqStart = params.beamformer_parameters.filter(1);
        freqEnd = params.beamformer_parameters.filter(2);
        freqVec = freqStart:freqStep:freqEnd;
        fs = 1.0 / ( timeVec(2) - timeVec(1) );
        
        if params.tfr_parameters.method == 0
            TFR_DATA = bw_compute_tfr(vs_data, freqVec, timeVec, fs, params.tfr_parameters.fOversigmafRatio, params.tfr_parameters.saveSingleTrials);
        elseif params.tfr_parameters.method == 1
            TFR_DATA = bw_compute_hilbert_tfr(vs_data, freqVec, timeVec, fs, params.tfr_parameters.filterWidth, params.tfr_parameters.saveSingleTrials);
        else
            fprintf('unknown TFR method index\n');
            return;
        end

        if isempty(TFR_DATA)
            delete(wbh);
            return;
        end
        
        % * new in ver 4.0 - added labels from plot dialog or voxelList ...
        TFR_DATA.label = label; 
        
        if params.vs_parameters.rms
            plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(rms)', dsName, voxel);
        else
            plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(%.3f_%.3f_%.3f)', dsName, voxel, comnorm);
        end

        TFR_DATA.dsName = dsName;
        TFR_DATA.covDsName = covDsName;
        TFR_DATA.plotLabel = plotLabel;
        TFR_DATA.baseline =  [timeVec(1) timeVec(end)];  

        if (params.vs_parameters.pseudoZ)   
            TFR_DATA.dataUnits = 'Pseudo-Z';
        else
            TFR_DATA.dataUnits = 'nAm';
        end
        TFR_DATA.plotUnits = params.tfr_parameters.plotUnits; 
        TFR_DATA.plotType = params.tfr_parameters.plotType;

        TFR_ARRAY{k} = TFR_DATA;            
        
    end
    
    delete(wbh);

end
