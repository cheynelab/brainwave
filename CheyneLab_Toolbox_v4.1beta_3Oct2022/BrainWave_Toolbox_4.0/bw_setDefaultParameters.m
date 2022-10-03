%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%       bw_setDefaultParameters
%
%   function [beamformer_params vs_params tfr_params] =  bw_setDefaultParameters([dsName])
%
%   DESCRIPTION: generate default settings for structs used by beamformer
%   code.  Note that data dependent fields are initialized after reading
%   data
%
% (c) D. Cheyne, August 2010. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   D. Cheyne, July 11, 2011
%
%   added convenience function for setting default parameters
%   ** added filterData parameter since filtering can now be disabled
%
%  - D. Cheyne, July 22, 2011
%   ** added new params for VS - autoflip, autoFlipLatency and searchRadius  
%
%  - D. Cheyne, Aug, 2011 - added option to pass a dsName to initiaze all
%  fields (e.g., to use as stand-alone)
%
%   - D. Cheyne, Jan, 2012  - changed defaults res to 4 mm and BB to -2 to
%   14.  This gives slightly better resolution with less than double images
%   size (computation time). This makes BB equally divisible by 4 mm in all
%   dimensions  
%
%   - D. Cheyne, May, 2012 - reduced vs_params and tfr_params to options
%   only to reduce redundancy between structs - i.e., contains only values
%   that can be directly set in the dialogs...
%
%   ***  D. Cheyne, November 2015 - combined structures into one parent struct
%  to simplify passing variables (adding more structs...)
%
% (c) D. Cheyne. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function [params] = bw_setDefaultParameters(dsName)

    global BW_VERSION
    
    params.version = BW_VERSION;
    % Data and beamformer parameters
    params.beamformer_parameters.rms=0;
    params.beamformer_parameters.stepSize=0.4;                     % modified in ver 1.6
    params.beamformer_parameters.boundingBox=[-12 12 -9 9 -2 14];  % incr. X and Y in version 3.0
    params.beamformer_parameters.nr=0;
    params.beamformer_parameters.pm=0;
    params.beamformer_parameters.mean=0;
    params.beamformer_parameters.covWindow = [0 0];
    params.beamformer_parameters.noise=3e-15;
    
    params.beamformer_parameters.useRegularization= 1;             % Version 3.1 - on by default 
    params.beamformer_parameters.regularization=1e-28;   % 10 fT^2

    params.beamformer_parameters.useBaselineWindow = 0;    
    params.beamformer_parameters.baseline = [0 0];

    params.beamformer_parameters.filter = [1 50];
    params.beamformer_parameters.filterData = 1;
    params.beamformer_parameters.useReverseFilter = 1;
    
    params.beamformer_parameters.surfaceFile='';
    params.beamformer_parameters.useSurfaceFile=0;
    params.beamformer_parameters.useSurfaceNormals=0;

    params.beamformer_parameters.voxFile='';
    params.beamformer_parameters.useVoxFile=0;
    params.beamformer_parameters.useVoxNormals=0;
    params.beamformer_parameters.outputFormat=0;       % for surface images (0 = ASCII (.txt), 1 = freesurfer overlay (.w)
    
    params.beamformer_parameters.hdmFile='';
    params.beamformer_parameters.useHdmFile=0;
    params.beamformer_parameters.sphere=[0 0 5];

    params.beamformer_parameters.beam.use='ERB';
    
    params.beamformer_parameters.beam.latencyStart=0.0;
    params.beamformer_parameters.beam.latencyEnd=0.0;
    params.beamformer_parameters.beam.step=0.005;   
    params.beamformer_parameters.beam.activeStart = 0.0;
    params.beamformer_parameters.beam.activeEnd = 0.0;
    params.beamformer_parameters.beam.active_step=0.0;
    params.beamformer_parameters.beam.no_step=0;
    params.beamformer_parameters.beam.baselineStart=0;
    params.beamformer_parameters.beam.baselineEnd=0;
    params.beamformer_parameters.beam.latencyList = '';        % new in version 2.2

    % new - flags for which covariance data to use
    params.beamformer_parameters.contrastImage = 0;
    params.beamformer_parameters.covarianceType = 0;            % 0 = default, 1 = common, 2 = custom
    params.beamformer_parameters.multiDsSAM = 0;
    
    params.beamformer_parameters.useBrainMask = 0;
    params.beamformer_parameters.brainMaskFile = '';
    
    % Virtual Sensor options 
    params.vs_parameters.raw=0;
    params.vs_parameters.rms=0;
    params.vs_parameters.pseudoZ=0; 
    params.vs_parameters.autoFlip = 0;
    params.vs_parameters.autoFlipLatency = 0.0;
    params.vs_parameters.autoFlipPolarity = 1;
    params.vs_parameters.useSR = 0;
    params.vs_parameters.searchRadius = 10;
    params.vs_parameters.searchLatency = 0.0;
    params.vs_parameters.searchMethod = 'ERB';
    params.vs_parameters.searchActiveWindow = [0 0];
    params.vs_parameters.searchBaselineWindow = [0 0];
    
    params.vs_parameters.saveSingleTrials = 0;    
    params.vs_parameters.subtractAverage = 1;        

    params.vs_parameters.plotColor = [0 0 1];    
    params.vs_parameters.plotLabel = [];    
    params.vs_parameters.plotAnalyticSignal = 0;        
    params.vs_parameters.errorBarType = 0;        
    params.vs_parameters.errorBarInterval = 0.1;      % in seconds        
    params.vs_parameters.errorBarWidth = 10;          % now in points !        
    
    % TFR options 
    params.tfr_parameters.method=0;              % 0 = morlet wavelet, 1 = hilbert
    params.tfr_parameters.freqStep=1;
    params.tfr_parameters.fOversigmafRatio=7;      % modified in version 1.6  * Version 3.1 - set default back to 7 cycles
    params.tfr_parameters.plotType=0;              % 0 = plot power, 1 = power minus average, 2 = average, 3 = phase-locking factor
    params.tfr_parameters.plotUnits=2;             % 0 =  power, 1 = dB, 2 = percent change 
    params.tfr_parameters.baseline = [0 0];        % separate baseline applies to TFR only - always has baseline so don't need flag
    params.tfr_parameters.saveSingleTrials = 0;    % added in version 2.4
    params.tfr_parameters.filterWidth=4;           % ver 3.0 - for hilbert transform total width of filter
    
    params.spm_options.useDefaultTemplate = 1;
    params.spm_options.maskFile = '';
    params.spm_options.templateFile = '';
    
    % previously only saved in prefs file... 
    params.gui.radioscalar = 1;
    params.gui.radiovector = 0;
    params.gui.radiofixed = 0;
    
    % if dataset passed initialize some data dependent variables
    if exist('dsName','var')
        if ~exist(dsName,'file')
            fprintf('Cannot find dataset %s to set defaults, check file path and permissions\n',dsName);
            return;
        end
        
        header=bw_CTFGetHeader(dsName);
        params.beamformer_parameters.baseline=[header.epochMinTime header.epochMaxTime];
        params.beamformer_parameters.covWindow=[header.epochMinTime header.epochMaxTime];
        params.tfr_parameters.baseline=[header.epochMinTime header.epochMaxTime];
        
        clear header
    end
    
end
