%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_plot_virtual_sensor( dsList, covDsList, voxelList, orientationList, tfr_flag, params, vs_options, tfr_options)
% 
% standalone function to plot a single VS or TFR directly or multiple + grand averager from a passed list of voxels and datasetnames 
% assumes voxels are passed in MEG coordinates and have already been
% converted from normalized coordinates
%
% (c) D. Cheyne, 2014
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function bw_plot_virtual_sensor( dsList, covDsList, voxelList, orientationList, tfr_flag, params, vs_options, tfr_options)
            

    numSubjects = size(voxelList,1);
    
    wbh = waitbar(0,'Computing VS data...');

    for k=1:numSubjects

        voxel = voxelList(k,:);
        dsName = char(dsList(k));
        covDsName = char(covDsList(k));
        
        fprintf('Generating virtual sensor waveforms for dataset %s...\n', dsName);

        s = sprintf('plotting data for subject %d', k);
        waitbar(k/numSubjects,wbh,s);

        % for TFRs have to force return of single trial VS data
        if tfr_flag
            vs_options.saveSingleTrials = 1;
        end

        % note in this case we cannot specify orientation
        if ~isempty(orientationList)
            normal = orientationList(k,1:3);
            useNormal = 1;
        else
            normal = [1 0 0];
            useNormal = 0;
        end
        
        [timeVec, vs_data, comnorm] = bw_make_vs(dsName, covDsName, voxel, normal, useNormal, params, vs_options);

        if isempty(timeVec)    % in case aborted
            return;
        end

        if tfr_flag

            % compute frequency transform
            freqStep = tfr_options.freqStep;                             % frequency bin size for TF plot
            freqStart = params.filter(1);
            freqEnd = params.filter(2);
            freqVec = freqStart:freqStep:freqEnd;
            fs = 1.0 / ( timeVec(2) - timeVec(1) );
            
            if tfr_options.method == 0
                TFR_DATA = bw_compute_tfr(vs_data, freqVec, timeVec, fs, tfr_options.fOversigmafRatio, tfr_options.saveSingleTrials);
            elseif tfr_options.method == 1
                TFR_DATA = bw_compute_hilbert_tfr(vs_data, freqVec, timeVec, fs, tfr_options.filterWidth, tfr_options.saveSingleTrials);
            else
                fprintf('unknown TFR method index\n');
                return;
            end
            
            if isempty(TFR_DATA)
                return;
            end

            if vs_options.rms
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(rms)', dsName, voxel);
            else
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(%.3f_%.3f_%.3f)', dsName, voxel, comnorm);
            end

            TFR_DATA.dsName = dsName;
            TFR_DATA.covDsName = covDsName;
            TFR_DATA.plotLabel = plotLabel;
            TFR_DATA.baseline = params.baseline;  % make TFR baseline same as for plots for 

            if (vs_options.pseudoZ)   
                TFR_DATA.dataUnits = 'Pseudo-Z';
            else
                TFR_DATA.dataUnits = 'nAm';
            end
            TFR_DATA.plotUnits = tfr_options.plotUnits; 
            TFR_DATA.plotType = tfr_options.plotType;

            TFR_ARRAY{k} = TFR_DATA;            
        else

            VS_DATA.dsName = dsName;
            TFR_DATA.covDsName = covDsName;
            VS_DATA.voxel = voxel;
            VS_DATA.normal = comnorm';
            VS_DATA.timeVec = timeVec;
            VS_DATA.vs_data = vs_data;   

            VS_DATA.filter = params.filter;    

            if params.useBaselineWindow
                VS_DATA.baseline = params.baseline;    
            else
                VS_DATA.baseline = [timeVec(1) timeVec(end)];  
            end

            if vs_options.rms
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(rms)', char(dsName), voxel);
            else
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(%.3f_%.3f_%.3f)', char(dsName), voxel, comnorm);
            end

            VS_DATA.plotLabel = plotLabel;

            VS_ARRAY{k} = VS_DATA;
        end

    end

    delete(wbh);

    if tfr_flag
        bw_plot_tfr(TFR_ARRAY);
    else
        bw_plot_vs(VS_ARRAY, vs_options); 
    end
end
