function bw_plot_channel(dsName, channelName, freqRange, plot_single_trials)
% function bw_plot_channel(dsName, channelName)
%   stand-alone function to plot a CTF data channel.
%   requires BrainWave toolbox installed and in path
%
%   Sept 2020       - version 1.0
%
%   (c) D. Cheyne, 2020. All rights reserved. 
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.
 
    if ~exist('plot_single_trials','var')
        plot_single_trials = 0;
    end
    
    header = bw_CTFGetHeader(dsName);
    channelList = bw_CTFGetChannelLabels(dsName);
    channelIndex = find( strncmp(channelName,cellstr(channelList),length(channelName)) );

    [timeVec, data] = bw_CTFGetChannelData(dsName, channelName, freqRange, -1);

    data = data .* 1e15;  % plot in femtTesla
     
    if plot_single_trials == 1
        figure;
        plot(timeVec, data);
    end
    
    ave = mean(data,2);
    
    % else plot average
    figure;
    plot(timeVec,ave);
    ylabel('Amplitude (fT)');
    xlabel('Time (s)');
    plotLabel = sprintf('%s (Channel: %s)', dsName, channelName);
    tt = title(plotLabel);
    set(tt,'fontsize',10,'fontname','lucinda','Interpreter','none');

end