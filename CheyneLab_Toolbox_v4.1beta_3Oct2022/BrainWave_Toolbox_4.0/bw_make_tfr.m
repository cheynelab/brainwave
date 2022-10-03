function [TFR_DATA computed_normal] = bw_make_tfr(dsName, voxel, normal, useNormal, params, vs_options, tfr_params)
%       BW_MAKE_TFR 
%
%  function [TFR_DATA computed_normal] = bw_make_tfr(dsName, voxel, normal, useNormal, params, vs_options, tfr_params)
%
%   Generation of time frequency representations.
%   It requires the dataset's name (dsName), a voxel to compute the sensor
%   at (voxel), the virtual sensor parameters set earlier (params) and
%   optionally, a computed normal (normal and useNormal). If a set normal
%   vector is not used, the function will compute it's own and return in in
%   computed_normal.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%
% D. Cheyne July  2011
%
% - split off tfr plotting to separate routine
% - removed plotting code now just parses parameters, does some sanity 
% checking calls mex function and returns the TFR data to calling function 
%
% Written by D. Cheyne on --/04/2010 for the Hospital for Sick Children.

% CHECKING PARAMETERS

    % new popup wait bar for TFR...
    
    keepSingleTrials = tfr_params.saveSingleTrials;
          
    isWriteable = bw_isWriteable(dsName);
    if ~isWriteable
        return;
    end
    
    h = waitbar(0,'Please wait...');
    for n=0:10
        waitbar(n/100,h,'checking parameters...');
    end

    if (params.useHdmFile)
        params.hdmFile=fullfile(dsName,params.hdmFile);
    end

    if (useNormal == 0)
        normal = [1 0 0];
    end

    % disabled for GUI
    angleWindow(1) = 0.0;
    angleWindow(2) = 0.0;
    useAngleWindow = 0;

    % Don't need to baseline data since TFR always is highpass filtered.
    % tfr_parameters.baseline is used afterwards...
    baseline = [0 0];
    baselineData = 0;
    
    % TFR always uses non-rectified data
    computeRMS = 0;

    if vs_options.pseudoZ
        normalizeWeights = 1;
    else
        normalizeWeights = 0;
    end

    saveSingleTrials = 1;

    if ~params.filterData 
        params.filter(1) = 0.0;
        params.filter(2) = 0.0;
    end

    covWindow=params.covWindow;

    if params.useReverseFilter
        bidirectional = 1;
    else
        bidirectional = 0;
    end
    
    covWindow=params.covWindow;

    % **** 
    covDsName = dsName;
    
    
    % MAKE VS USING MEX FILE
    for n=10:60
        waitbar(n/100,h,'generating single trial data..');
    end
    
    [timeVec vs_data computed_normal] = bw_makeVS(dsName, covDsName, params.hdmFile, params.useHdmFile, params.filter, voxel, ...
        normal, useNormal, covWindow, baseline, baselineData, params.sphere, ...
        normalizeWeights, params.noise, params.regularization, vs_options.rms, bidirectional, saveSingleTrials );

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    for n=60:90
        waitbar(n/100,h,'saving data...');
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    waitbar(1,h,'done!');
    close(h);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
    
    % compute frequency transform
    freqStep = tfr_params.freqStep;                             % frequency bin size for TF plot
    fOversigmafRatio = tfr_params.fOversigmafRatio;             % usually not changed
    
    plotType = tfr_params.plotType;                             % 0 = plot power, 1 = power - average, 2 = Average, 3 = PLF
    plotUnits = tfr_params.plotUnits;                           % 0 =  power, 1 = dB, 2 = percent change

    freqStart = params.filter(1);
    freqEnd = params.filter(2);
    freqVec = freqStart:freqStep:freqEnd;

    nbins = size(freqVec,2);
    f = freqVec(1);
    dwel = timeVec(2) - timeVec(1);
    fs = 1/dwel;
    nsamples = size(vs_data,1);
    ntrials = size(vs_data,2);

    % get wavelet resolution
    sigmaF = f / fOversigmafRatio;
    sigmaT = 1.0 /  (2 * pi * sigmaF);

    if keepSingleTrials
        fprintf('saving single trial magnitude and phase data... \n');
    end
   
    
    TFR_DATA = bw_compute_tfr(vs_data, freqVec, timeVec, fs, fOversigmafRatio, keepSingleTrials);

    % save baseline and plot mode, but don't remove offset here
    % i.e., plot routine always gets original power data.
    
    if isempty(tfr_params.baseline)
        if (baselineData)
            offset = baseline;
        else
            offset = [timeVec(1) timeVec(end)];
        end
    else
        offset = tfr_params.baseline;
    end
    
    TFR_DATA.baseline = offset;
    
    if (vs_options.pseudoZ)   
        dataUnits = 'Pseudo-Z';
    else
        dataUnits = 'nAm';
    end
    TFR_DATA.dataUnits = dataUnits;    
    TFR_DATA.plotUnits = plotUnits; 
    TFR_DATA.plotType = plotType;
    
    % return all data needed to plot etc
    
    clear timeVec;
    clear vs_data;
    clear TFR;
    

end


