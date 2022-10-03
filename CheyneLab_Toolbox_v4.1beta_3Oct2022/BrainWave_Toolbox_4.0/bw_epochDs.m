function errorFlag = bw_epochDs(dsName, newDsName, latencies, badChannels, epochWindow, bandpass, lineFilter, downSample, saveAverage, useExtraSamples, deidentify)
%       bw_epochDs
%
%   function errorFlag = bw_epochDs(dsName, newDsName, latencies, badChannels, epochWindow, bandpass, lineFilter, downSample, saveAverage, useExtraSamples, deidentify)
%
%   DESCRIPTION: Using the full path name of the .con, a given epoch time
%   window and a list of the valid channel list indices, this function will
%   create a CTF .ds dataset who's name corresponds to the string variable
%   dsName. This function will return a value other then 0 if an error
%   occured.
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


errorFlag = -1;
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get dataset info from .con file

ctf_info = bw_CTFGetParams(dsName);

if ctf_info(4) > 1  % make sure is one trial ds
    fprintf('Can only process CTF raw (single trial) datasets\n');
    return;
end
sampleRate = ctf_info(5);

numTrials = length(latencies);

preTrigPts = abs(epochWindow(1) * sampleRate);
postTrigPts = abs(epochWindow(2) * sampleRate);  
numSamples = postTrigPts + preTrigPts + 1; % add one sample for t=0 to avoid odd time values

if isempty(bandpass)
    filterData = 0;
    bandpass = [0 sampleRate/2];
else
    filterData = 1;
end

% make sure bools are passed as int

if saveAverage   
    saveAverage = 1;
else
    saveAverage = 0;
end

if useExtraSamples 
    useExpandedWindow = 1;
else
    useExpandedWindow = 0;
end

if deidentify 
    deidentify = 1;
else
    deidentify = 0;
end

if preTrigPts == 0
    preTime = 0;
else
    preTime = -preTrigPts / sampleRate;
end
% 
% fprintf('Epoching data...\n', preTime, postTrigPts / sampleRate, numSamples);
% fprintf('Epoch time = %g to %g s (%d samples)\n', preTime, postTrigPts / sampleRate, numSamples);
% 
% if filterData == 1
%     fprintf('Pre-filtering data from %g to %g Hz\n', bandpass);
% end

% mex function does the rest...
if ~isempty(badChannels)
    errorFlag = bw_CTFEpochDs(dsName, newDsName, latencies', epochWindow, saveAverage, filterData, bandpass, lineFilter, downSample, useExpandedWindow, deidentify, badChannels); 
else
    errorFlag = bw_CTFEpochDs(dsName, newDsName, latencies', epochWindow, saveAverage, filterData, bandpass, lineFilter, downSample, useExpandedWindow, deidentify);
end


end

