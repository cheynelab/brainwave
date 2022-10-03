% function to plot VS or TFR directly from an imageset and peak list
%
%   
function bw_plot_peak( voxelList, mniList, imagelist, tfr_flag )
            
    % set some default plot options
    
    dsName = char(imageset.dsName(1));
    
    ds_info = bw_CTFGetParams(dsName);            
    sampleRate = ds_info(5);
    dataRange = [ds_info(12) ds_info(13)];

    % save all params in imageset ???
    [t_params, vs_options, tfr_options] = bw_setDefaultParameters;
    params = imageset.params;
    
    [t_params, vs_options, tfr_options] = bw_plot_options(params, vs_options, tfr_options, dsName, false, tfr_flag);
 
    if isempty(t_params)
        return;             % user cancelled
    end
    
    if ( tfr_flag )
        vs_options.saveSingleTrials = 1;
    end

    if SUBJECT_NO == 0
        numSubjects = imageset.no_subjects;
    else 
        numSubjects = 1;
    end

    wbh = waitbar(0,'Computing VS data...');

    for k=1:numSubjects

        if SUBJECT_NO == 0
            thisSubject = k;
        else
            thisSubject = SUBJECT_NO;
        end

        dsName = char(imageset.dsName(thisSubject));
        
        % need to make sure datatype is correct..
        voxel = double(voxelList(thisSubject,1:3));
        mni_voxel = double(mniList(thisSubject,1:3));
               
        fprintf('Generating virtual sensor waveforms for dataset %s...\n', dsName);
        s = sprintf('plotting data for subject %d', k);
        waitbar(k/numSubjects,wbh,s);

        % for TFRs have to force return of single trial VS data
        options = vs_options;           
        if tfr_flag
            options.saveSingleTrials = 1;
        end
        
        % need option to fix orientation...
        [timeVec vs_data comnorm] = bw_make_vs(dsName, voxel, [1 0 0], 0, params, options);

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

            TFR_DATA = bw_compute_tfr(vs_data, freqVec, timeVec, fs, tfr_options.fOversigmafRatio, tfr_options.saveSingleTrials);

            if isempty(TFR_DATA)
                return;
            end

            if vs_options.rms
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(rms)', dsName, voxel);
            else
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(%.3f_%.3f_%.3f)', dsName, voxel, comnorm);
            end

            TFR_DATA.dsName = dsName;
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
            VS_DATA.voxel = voxel;
            VS_DATA.voxel_mni = mni_voxel;
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
