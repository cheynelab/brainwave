function bw_topoplot_latency(datasetName, latency, baseline,data,params,names,positions)
%       BW_TOPOPLOT_LATENCY
%
%   function bw_topoplot_latency(datasetName, latency, baseline,data,params,names,positions)
%
%   DESCRIPTION: This functions creates a topoplot from the dataset 
%   specified by datasetName, at the latency specified using the specified
%   parameters (baseline,data,params,names,positions).
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% written by D. Cheyne, Feb 2008, modified for BrainWave, Mar, 2010
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% get data at sample
%[timeVec channelNames data] = bw_CTFGetAverage(datasetName, BW(1), BW(2));

%params = bw_CTFGetParams(datasetName);


numSamples = params(1);
fs = params(5);
preTrigPts = params(2);
numSensors = params(10);

bstart = round ((baseline(1) * fs) + preTrigPts) + 1;
bend = round( (baseline(2) * fs) + preTrigPts) + 1;
sample = round (latency * fs) + preTrigPts + 1;

for i=1:numSensors
    ave = data(:,i);
    b = mean(ave(bstart:bend)); 
    data(:,i) = ave-b;
end

map_data = data(sample,:)';  % plot in fT

% create an EEGLAB chanlocs structure to avoid having to save .locs file
eeglocs = struct('labels',{},'theta', {}, 'radius', {});

for i=1:numSensors
    name = names(i,1:5);
    pos = positions;

    X  = positions(i,1);
    Y  = positions(i,2);
    Z  = positions(i,3);
    [th phi radius] = cart2sph(X,Y,Z);
    
    decl = (pi/2) - phi;
    radius = decl / pi;
    theta = th * (180/pi);
    if (theta < 180)
        theta = -theta;
    else
        theta = 360 - theta;
    end
    
    eeglocs(i).labels = name;
	eeglocs(i).theta = theta;
	eeglocs(i).radius = radius;    
end

% map data
subplot(2,2,4);

topohandle=topoplot(map_data,eeglocs,'colormap',jet,'numcontour',5,'electrodes','off','shrink',0.15);

h = colorbar;

tstr = sprintf('femtoTesla');
set(get(h,'YLabel'),'String',tstr);

tstr = sprintf('time: %g s', latency);
tt = title(tstr);
set(tt,'Interpreter','none','fontsize',8);


end


