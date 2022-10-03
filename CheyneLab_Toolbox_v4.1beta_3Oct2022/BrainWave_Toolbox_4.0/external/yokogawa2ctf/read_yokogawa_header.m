function [header] = read_yokogawa_header(conFile)
%       BW_READ_YOKOGAWA_HEADER
%
%   function [header] = bw_read_yokogawa_header(conFile)
%
%   DESCRIPTION: Read some critical header values from a Yokogawa continuous
%   data file and return in a struct.
%
%   (c) D. Cheyne, 2011. All rights reserved.
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   D. Cheyne, March, 2011
%   Revised Jan, 2012 to use new Yokogawa functions and return channel
%   geometry here
%
%   D. Cheyne, Feb 2017 
%   added more information for ADC channels etc
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

header = [];

t = getYkgwHdrAcqCond(conFile);
header.sampleRate = t.sample_rate;
header.numSamples = t.sample_count;

t = getYkgwHdrChannel(conFile);

totalChannels = t.channel_count;

% return info for grad sensors only.  Also return the channel geometry
% structs for these channels, although bw_yokogawa2ctf still uses .pos file 
% to get the co-registered channel geometry and fiducials

numSensorChannels = 0;
for i=1:totalChannels
    if t.channel(i).type == 2
        numSensorChannels = numSensorChannels + 1;
        chanData = t.channel(i).data;               % these structs are empty for non sensor channels !
        header.channel(numSensorChannels) = chanData;
    end
end

header.dataType = 'continuous_raw';
header.totalChannels = totalChannels;
header.numSensors = numSensorChannels;

% ** temp fix to include ADCs - treat everything after MEG sensors as ADC
% ** this should be corrected for Macquarie child system which has 3
% reference channels after MEG sensors (before first ADC). 
header.numADC = totalChannels - numSensorChannels;  

% since we no longer have access to true gains, set the system sensitivity 
% to be 0.1 fT by default. I.e., gain = 1e16.  This is slightly
% higher than the actual KIT and CTF LSB's which are both around 0.3 fT
 
header.MEGgain = 1e16;  % 
header.ADCgain = 1e8;   % default ADC gain for CTF (0.01 mV?)
header.LSB = 1.0 / header.MEGgain;      % still used by yokogawa2geom

end



