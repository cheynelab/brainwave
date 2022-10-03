%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   getCTFHeadPosition
%
%   function [na le re] = getCTFHeadPosition(dsName, startSample, numSamples);
%
%   DESCRIPTION: Read CHL channels of a CTF dataset and return mean 
%                head position (fiducials in dewar coordinates) over the
%                specifed sample range
%
% (c) D. Cheyne, 2014. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [na, le, re] = bw_getCTFHeadPosition(dsName, startSample, numSamples)

    CHL_channels = {'HLC0011'; 'HLC0012'; 'HLC0013'; 'HLC0021'; 'HLC0022'; 'HLC0023'; 'HLC0031'; 'HLC0032'; 'HLC0033'};
    
    na = [7 7 -23];
    le = [-7 7 -23];
    re = [7 -7 -23];
           
  %  return;
    labels = bw_CTFGetChannelLabels(dsName);
             
    % get data segment - use new flag to get all channels
    
    data = bw_getCTFData(dsName, startSample, numSamples, 1)';
    pos = zeros(9,1);
    
    for i=1:size(CHL_channels,1)
        name = char( CHL_channels(i) );
        idx = find( strncmp(name,cellstr(labels),7) );
        chan_data = data(idx,:);
        pos(i) = mean(chan_data) * 100;  % return position data in cm
    end
    
    na = pos(1:3)';
    le = pos(4:6)';
    re = pos(7:9)';
    
end

