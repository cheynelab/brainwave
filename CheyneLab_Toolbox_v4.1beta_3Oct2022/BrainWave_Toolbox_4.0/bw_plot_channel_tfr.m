function bw_plot_channel_tfr(dsName, channelName, freqRange, freqStep, numCycles)
% function bw_plot_channel_tfr(dsName, channelName, freqRange, freqStep, numCycles)
%   stand-alone function to create a BW style TFR plot for any CTF data channel.
%   requires BrainWave toolbox installed and in path
%
%   Sept 2019       - version 1.0
%
%   (c) D. Cheyne, 2011. All rights reserved. 
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.

    plotAverage = 0;
    
    header = bw_CTFGetHeader(dsName);

    [timeVec, data] = bw_CTFGetChannelData(dsName, channelName, freqRange, -1);

    data = data .* 1e15;  % plot in femtTesla
     
    if plotAverage
        ave = mean(data,2);
        figure;
        plot(timeVec,ave);
        ylabel('Amplitude (fT)');
        xlabel('Time (s)');
        tt = title(plotLabel);
        set(tt,'fontsize',10,'fontname','lucinda','Interpreter','none');
    end
    
    plotLabel = sprintf('%s (Channel: %s)', dsName, channelName);
    freqVec = freqRange(1):freqStep:freqRange(2);
    
    TFR_DATA = bw_compute_tfr(data, freqVec, timeVec, header.sampleRate, numCycles, 0);

    if isempty(TFR_DATA)
        return;
    end


    TFR_DATA.dsName = dsName;
    TFR_DATA.covDsName = dsName;
    TFR_DATA.plotLabel = plotLabel;
    TFR_DATA.baseline =  [timeVec(1) timeVec(end)];  
    TFR_DATA.label = plotLabel;
    
    TFR_DATA.dataUnits = 'femtoTesla';

    
    % default type = total power, units percent change - these can be changed in menu
    TFR_DATA.plotUnits = 2;    
    TFR_DATA.plotType = 0;

    TFR_ARRAY{1} = TFR_DATA;      
    
    bw_plot_tfr(TFR_ARRAY,0,'label');

end