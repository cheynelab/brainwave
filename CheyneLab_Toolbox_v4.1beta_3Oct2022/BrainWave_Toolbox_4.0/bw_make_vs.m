function [timeVec, vs_data, computed_normal] = bw_make_vs(dsName, covDsName, voxel, normal, params)
%
% function [timeVec vs_data computed_normal] = bw_make_vs(dsName, covDsName, voxel, normal, params)
% old syntax    function [timeVec vs_data computed_normal] = bw_make_vs(dsName, voxel, normal, useNormal, params)
%
%   DESCRIPTION: Oversees the generation of the virtual sensor for plotting.
%   It also assists with the generation of time frequency representations.
%   It requires the dataset's name (dsName), a voxel to compute the sensor
%   at (voxel), the virtual sensor parameters set earlier (params) and
%   optionally, a computed normal (normal and useNormal). If a set normal
%   vector is not used, the function will compute it's own and return in in
%   computed_normal.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%   --VERSION 1.2--
% Last Revised by N.v.L. on 19/07/2010
% Major Changes: Will now save TFR files as '.mat' in the dataset in a
% newly created folder labeled TFR and will simply load from there instead
% of computing if the file exists.
%
% Revised by N.v.L. on 23/06/2010
% Major Changes: Edited the help file and clean up the function.
%
%
% Revised by N.v.L. on 08/06/2010
% Major Changes: Added in a progress bar.
%
%  version 1.3
% D. Cheyne, Sept, 2010
%
% - added save menus to save data for waveforms and TFRs 
% - removed Natascha's code to automatically save TFR data...
%
% version 1.4
% D. Cheyne July  2011
%
% - split off tfr plotting to separate routine - simplified tfr_params struct
% - removed plotting code now just parses parameters, does some sanity 
% checking calls mex function and returns data to calling function 
%
% for version 3.2  (D. Cheyne, Dec, 2015)
%            - covDsName removed from params and is now passed, new params struct passed.
%            - instead of flag pass empty array to force calculation of normal
%

    timeVec = [];
    vs_data = [];
    computed_normal = [];
    
    isWriteable = bw_isWriteable(dsName);
    if ~isWriteable
        return;
    end

    if (params.beamformer_parameters.useHdmFile)
        params.beamformer_parameters.hdmFile=fullfile(dsName,params.beamformer_parameters.hdmFile);
        
        if ~exist(params.beamformer_parameters.hdmFile,'file')
            beep;
            fprintf('Head model file %s does not exist\n', params.beamformer_parameters.hdmFile);
            return;
        end
    end

    if isempty(normal)
        useNormal = 0;
        normal = [1 0 0];
    else
        useNormal = 1;
    end

    if params.beamformer_parameters.useBaselineWindow
        baseline(1) = params.beamformer_parameters.baseline(1);
        baseline(2) = params.beamformer_parameters.baseline(2);
        baselineData = 1;
    else
        baseline(1) = 0.0;
        baseline(2) = 0.0;
        baselineData = 0;
    end

    if params.vs_parameters.rms
        computeRMS = 1;
    else
        computeRMS = 0;
    end

    if params.vs_parameters.pseudoZ
        normalizeWeights = 1;
    else
        normalizeWeights = 0;
    end

    if ~params.beamformer_parameters.filterData 
        params.beamformer_parameters.filter(1) = 0.0;
        params.beamformer_parameters.filter(2) = 0.0;
    end
    
    if params.beamformer_parameters.useReverseFilter
        bidirectional = 1;
    else
        bidirectional = 0;
    end
    
    covWindow=params.beamformer_parameters.covWindow;
    % check that covariance window has been set
    if ( covWindow(1) == 0 && covWindow(2) == 0)
        beep;
        fprintf('Covariance window settings are invalid (%f to %f seconds)\n',covWindow);
        return;
    end

    if ~params.beamformer_parameters.useRegularization
        regularization = 0.0;
    else
        regularization = params.beamformer_parameters.regularization;
    end
    
    if params.vs_parameters.saveSingleTrials
        saveSingleTrials = 1;
    else
        saveSingleTrials = 0;
    end


    % MAKE VS USING MEX FILE

    % version 4.0 
    % - make sure coordinates are passed to mex function
    % as doubles, not ints or single precision
    dvoxel = double(voxel);
    dnormal = double(normal);
    
    [timeVec, vs_data, computed_normal] = bw_makeVS(dsName, covDsName, params.beamformer_parameters.hdmFile, params.beamformer_parameters.useHdmFile,...
        params.beamformer_parameters.filter, dvoxel, dnormal, useNormal, covWindow, baseline, baselineData, params.beamformer_parameters.sphere, ...
        normalizeWeights, params.beamformer_parameters.noise, regularization, computeRMS, bidirectional, saveSingleTrials );
    
    % autoflip 

    if params.vs_parameters.autoFlip && ~params.vs_parameters.rms
        ds_info = bw_CTFGetParams(dsName);
        sampleRate = ds_info(5);
        fprintf('Autoflip enabled...\n');
        
        t = params.vs_parameters.autoFlipLatency;
        x = round(t * sampleRate);
        flipSample = x + ds_info(2);
        if (flipSample < 1 || flipSample > length(vs_data) )
            fprintf('*** Warning: auto-flip latency out of range (t = %g s, sample %d) ***\n', t, flipSample);
        else
            amp = vs_data(flipSample);
            if params.vs_parameters.autoFlipPolarity == 1  % if positive make negative so doesn't flip negative peak
                if (amp < 0)
                    fprintf('...flipping source orientation to be positive at t = %g s (sample %d)\n', t, flipSample);
                    computed_normal = computed_normal * -1.0;
                    vs_data = vs_data * -1.0;
                end
            else
                if (amp > 0)
                    fprintf('...flipping source orientation to be negative at t = %g s (sample %d)\n', t, flipSample);
                    computed_normal = computed_normal * -1.0;
                    vs_data = vs_data * -1.0;
                end
            end
        end

    end

end


