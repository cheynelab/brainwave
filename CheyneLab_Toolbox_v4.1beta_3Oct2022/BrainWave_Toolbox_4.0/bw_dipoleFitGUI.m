function bw_dipoleFitGUI(dsName, fwindow, bwindow)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   function bw_dipoleFitGUI(dsName, filter, baseline)
%
%   GUI for single dipole fit
%
%   based on bw_data_plot - can be used to plot MEG data and/or dipole fit
%   inputs:  dsName - CTF dataset (else will prompt for dataset on launch)
%   
%   Version 1.0, May, 2022
%
% (c) D. Cheyne, August 2022. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    scrnsizes=get(0,'MonitorPosition');
   
    BACKCOLOR = [1 1 1];        % topoplot default background
    plotbox = [0.05 0.62 0.54 0.34];
    mapbox = [0.63 0.58 0.36 0.36];
    dipMapbox = [0.63 0.05 0.36 0.36];
    dipPlotbox = [0.4 0.2 0.22 0.22];

    plotmode = 0;
    plotPlanar = false;
    plotSingleTrials = false;
    plotAllTrials = false;
    
    latency = 0.05;
    header = [];
    excludeChannelList = [];
    badChannelList = {};
    
    channelset = 1;
    showSensors = 1;
    showSensorLabels = 0;
    cursorHandle = 0;
    mapAxis = 0;
    dipMapAxis = 0;
    dipPlotAxis = 0;
    
    mapScale = [];
    selectedchannel =  1;
    selectedTrial = 1;
    mapLocs = [];
    
    originalData = [];
    trialData = [];
    plotdata = [];
    timeVec = [];
    channelNames = [];
    data = [];
    
    ax=[];
    axtest=[];
    maxScale = [];
    minScale = [];   
    minRange = [];
    maxRange = [];
    autoscaleMap = 1;
        
    nsamples = 0;
    nchannels = 0;
    fs = 600;
    preTrigPts = 0;
    min_time = 0;
    max_time = 0;
    dwel = 1.0/fs;
    baselineStart = 0.0;
    baselineEnd = 0.0;
    useBaseline =  0;

    highPass = 1.0;    % safe defaults
    lowPass = 50.0;
    latency = 0.05;    
    
    filterOrder = 4;    % fixed for now
    bidirectional = 1;
    
    % dipole controls and defaults
    
    enableDipoleFit = 0;
    forward_data = [];
    
    % need to modify for multiple dipole fit ...
    numDips = 1;
    currentDip = 1;

    sphere = [0; 0; 5];
    maxDipoles = 8;
    moments = ones(1,maxDipoles) * 20.0;

    defaultStartPos = [0 3 8; 0 -3 8; 3 3 6; 3 -3 6;...
        -3 3 6; -3 -3 6; -2 -6 2; 2 -6 2]';
    defaultStartOri = [1 0 0; 1 0 0; 0 0 1; 0 0 1;...
        0 1 0; 0 -1 0; 0 2 -2; 0 -2 -2]';
    
    startPos = defaultStartPos(:,1);
    startOri = defaultStartOri(:,1);
    dipoleColors = [1 0 0; 0 1 0; 0 0 1; 1 0 1; 0 1 1; 0 0 0; 0.5 0.5 0.5; 1 1 0];  
    numPasses = 2;
    tolerance = 0.001;          
    isfitting = false;

    hPlotData = [];
    outlineHdl = [];
    
    lineHdl = [];
    tailLen = 2.5;
    tailWidth = 1.5;
    plotInitialized = 0;
    
    if ~exist('dsName','var')
       dsName = uigetdir('.ds', 'Select CTF dataset ...');
        if dsName == 0
            return;
        end      
    end
    
    % optionally pass filter or baseline window
    if exist('fwindow','var')
        highPass = fwindow(1);
        lowPass = fwindow(2);
    end
    
    if exist('bwindow','var')
        if ~isempty(bwindow)
            baselineStart = bwindow(1);
            baselineEnd = bwindow(2);
            useBaseline = 1;
        end
    end
    
    % Draw arrows - calls:  uparrow.m and downarrow.m - %%%% ADDED BY CECILIA %%%%
    uparrow_im=draw_uparrow;
    downarrow_im=draw_downarrow;
    leftarrow_im=draw_leftarrow;
    rightarrow_im=draw_rightarrow;
    warning('off','MATLAB:griddata:DuplicateDataPoints')

    fh = figure('Position',[scrnsizes(1,3)/3+200 scrnsizes(1,4)/2 1400 900],'color','white','menubar','none',...
        'numberTitle','off','WindowButtonUpFcn',@stopdrag,'WindowButtonDownFcn',@buttondown,'CloseRequestFcn',@quit_callback);

    if ispc
        movegui(fh,'center');
    end  
        
    filemenu=uimenu('label','File');
    uimenu(filemenu,'label','Load CTF Dataset...','accelerator','O','callback',@load_dataset_callback);
    uimenu(filemenu,'label','Close','accelerator','W','separator','on','callback',@quit_callback);
    
    plotOptionsMenu = uimenu('label','Plot');
    plotAverageToggle = uimenu(plotOptionsMenu,'label','Plot Average','checked','on','callback',@plot_average_callback);
    plotAllTrialsToggle = uimenu(plotOptionsMenu,'label','Overlay All Trials','checked','off','enable','off','callback',@plot_all_callback);
    plotSingleTrialToggle = uimenu(plotOptionsMenu,'label','Plot Single Trial','checked','off','enable','off','callback',@plot_single_callback);
    plotGFPToggle = uimenu(plotOptionsMenu,'label','Plot Global Field Power','checked','off','separator','on','callback',@plot_gfp_callback);
  
    optionsMenu = uimenu('label','Options');
    uimenu(optionsMenu,'label','Edit Channel List...','callback',@edit_channels_callback)  
    plotTFRButton = uimenu(optionsMenu,'label','Plot Single Channel TFR...','enable','off','callback',@plot_tfr_callback);
       
    
    function load_dataset_callback(~,~)
        dsName = uigetdir('.ds', 'Select CTF dataset ...');
        if dsName == 0
            return;
        end      
        loadData;
    end

    function edit_channels_callback(~,~)
        [excludeChannelList, channelset] = bw_select_data(dsName, excludeChannelList, channelset);
        badChannelList = cellstr(channelNames(excludeChannelList,:));
        
        updatePlot;
        % update Map
        mapLocs = getMapLocs(header, plotPlanar);
        mapLocs(excludeChannelList) = [];
        drawMap(latency);
    end  

    function plot_tfr_callback(~,~)
        chName = channelNames(selectedchannel,:);
        bw_plot_channel_tfr(dsName, chName, [highPass lowPass], 1, 7)
    end

    function quit_callback(~,~)       
        response = questdlg('Quit DataPlot / Dipole Fit?','Brainwave','Yes','No','No');
        if strcmp(response,'No') 
            return;
        end
        delete(fh);
    end

    function plot_average_callback(src,~)
        plotSingleTrials = 0;
        plotAllTrials = 0;

        s = sprintf('Average');
        set(trial_text,'string',s);
        set(trialIncArrow,'enable','off');
        set(trialDecArrow,'enable','off');
        
        set(plotAllTrialsToggle,'checked','off');
        set(plotSingleTrialToggle,'checked','off');
        set(src,'checked','on');

        updatePlot;
    end

    function plot_all_callback(src,~)
        plotSingleTrials = 1;
        plotAllTrials = 1;
        s = sprintf('Trial = All');
        set(trial_text,'string',s);
        
        set(plotAverageToggle,'checked','off');
        set(plotSingleTrialToggle,'checked','off');
        set(src,'checked','on');
        
        set(trial_text, 'string','Trial = All');
        set(trialIncArrow,'enable','off');
        set(trialDecArrow,'enable','off');
        
        updatePlot;
           
    end

    function plot_single_callback(src,~)
        plotSingleTrials = 1;
        plotAllTrials = 0;
        s = sprintf('Trial = %d', selectedTrial);
        set(trial_text,'string',s);
        set(trialIncArrow,'enable','on');
        set(trialDecArrow,'enable','on');
        
        set(plotAverageToggle,'checked','off');
        set(plotAllTrialsToggle,'checked','off');
        set(src,'checked','on');
            
        updatePlot;
    end
      
    function plot_gfp_callback(src,~)
        if plotmode == 1
            plotmode = 0;
            set(src,'checked','off');
        else
            plotmode = 1;
            set(src,'checked','on');
        end
        updatePlot;
        autoScale;
        updatePlot;
    end

    % has to be defined before loading data. 
    channel_dropdown = uicontrol('style','popup','units','normalized',...
        'position',[0.06 0.85 0.1 0.1],'String',{'none'},...
        'Backgroundcolor','white','fontsize',12,'fontname','lucinda','value',1,'callback',...
        @channel_dropDown_Callback);
    
    loadData;    
    
    function loadData
               
        header = bw_CTFGetHeader(dsName);
        
        nsamples = header.numSamples;
        nchannels = header.numSensors;
        fs = header.sampleRate;
        preTrigPts = header.numPreTrig;
        min_time = header.epochMinTime;
        max_time = header.epochMaxTime;
        dwel = 1.0/fs;
        
        fprintf('Getting averaged data...\n');

        % note: even though this reads raw data, averages and filters,
        % it is faster than reading the average ascii file 

        % get unfiltered average
        [timeVec, ~, originalData] = bw_CTFGetAverage(dsName); 

        [channelNames, ~, ~] = bw_CTFGetSensors(dsName, 0);

        originalData = originalData * 1e15;  % display in femtoTesla
       
        selectedchannel=1;
        selectedTrial = 1;
        plotAllTrials = 1;

        latency = 0.05; 

        data = originalData;
        plotdata = data;

        maxScale = max(max( abs(plotdata) ));
        if (maxScale == 0)
            maxScale = 1;
        end

        minScale = -maxScale;   
        
        mapScale(1) = minScale;
        mapScale(2) = maxScale;
        
        minRange = timeVec(1);
        maxRange = timeVec(end);
        % remove coeff number from channel names
        for j=1:size(channelNames,1)
            name = channelNames(j,:);
            idx = strfind(name,'-');
            if ~isempty(idx)
                temp(j,:)=channelNames(j,1:idx-1);
            else
                temp(j,:)=channelNames(j,:);
            end

        end
        channelNames=temp;
        clabels = {'All Channels'; channelNames};      
        set(channel_dropdown,'string',clabels);
     
        mapLocs = getMapLocs(header, plotPlanar);
        
        updatePlot;  
        autoScale;      
        updatePlot;            
        
        set(plotOptionsMenu,'enable','on');
        
    end


   %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % uicontrols
  
    s = sprintf('Latency = %.4f s', latency);
    latency_text = uicontrol('style','text','units','normalized','position',[0.05 0.53 0.1 0.03],...
            'string',s,'fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');

    uicontrol('style','pushbutton','units','normalized','position',[0.15 0.535 0.03 0.03],...
            'CData',leftarrow_im,'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@cursor_left_callback);                         
        function cursor_left_callback(~,~)
             t = latency-dwel;
             if (t > min_time)
                latency = t;      
                updateCursors
                drawMap(latency);
             end
        end 
    uicontrol('style','pushbutton','units','normalized','position',[0.19 0.535 0.03 0.03],...
            'CData',rightarrow_im,'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@cursor_right_callback);                    
         function cursor_right_callback(~,~)
             t = latency+dwel;
             if (t < max_time)
                latency = t;                 
                updateCursors;
                drawMap(latency);
             end    
         end
  
    trial_text = uicontrol('style','text','units','normalized','position',[0.07 0.62 0.08 0.03],...
            'string','Average','fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');

    trialIncArrow = uicontrol('style','pushbutton','units','normalized','enable','off','position',[0.6 0.68 0.04 0.04],...
            'CData',leftarrow_im,'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@trialInc_callback);                         
        function trialInc_callback(~,~)
             if plotAllTrials
                 return;
             end
             if selectedTrial > 1
                 selectedTrial = selectedTrial - 1;
             end
             s = sprintf('Trial = %d', selectedTrial);
             set(trial_text, 'string',s);
             updatePlot;
        end 
    trialDecArrow = uicontrol('style','pushbutton','units','normalized','enable','off','position',[0.6 0.63 0.04 0.04],...
            'CData',rightarrow_im,'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@trialDec_callback);                    
         function trialDec_callback(~,~)
             if plotAllTrials
                 return;
             end
             if selectedTrial < size(trialData,1)
                 selectedTrial = selectedTrial + 1;
             end
             s = sprintf('Trial = %d', selectedTrial);
             set(trial_text, 'string',s);             
             updatePlot;    
         end
     
    % plot scaling
    
    uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.6 0.9 0.03 0.04],...
    'CData',uparrow_im,'Foregroundcolor','black','backgroundcolor','white','callback',@scaleUp_callback);

    uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.6 0.85 0.03 0.04],...
    'CData',downarrow_im,'Foregroundcolor','black','backgroundcolor','white','callback',@scaleDown_callback);

    function scaleUp_callback(~,~)
        inc = maxScale * 0.2;
        maxScale = maxScale  - inc;
        minScale = minScale + inc;
        updatePlot;
    end

    function scaleDown_callback(~,~)
        inc = maxScale * 0.2;
        maxScale = maxScale  + inc;
        minScale = minScale - inc;
        updatePlot;
    end

    uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.6 0.8 0.05 0.04],...
    'Foregroundcolor','black','string','Auto Fit','backgroundcolor','white','callback',@autoScale_callback);

    function autoScale_callback(~,~)
        autoScale;
        updatePlot;
    end

    uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.6 0.75 0.05 0.04],...
    'Foregroundcolor','black','string','Set Range','backgroundcolor','white','callback',@editAxes_callback);

    function editAxes_callback(~,~)
        
        input = inputdlg({'Amplitude Range (fT)'; 'Time Range (s)'},'Set Plot Range ', [1 50; 1 50],...
            {num2str([minScale maxScale]),num2str([minRange maxRange])});
        if isempty(input)
            return;
        end   
        yrange = str2num(input{1});
        minScale = yrange(1);
        maxScale = yrange(2);
        xrange = str2num(input{2});
        minRange = xrange(1);
        maxRange = xrange(2);
        
        updatePlot;
    end


    %%%%%%%%
    % data bandpass and baseline
    
      
    uicontrol('style','text','units','normalized','position',[0.24 0.52 0.14 0.04],...
        'string','Filter (Hz):','fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    uicontrol('style','edit','units','normalized','position',[0.30 0.53 0.03 0.04],...
        'FontSize', 12,'BackGroundColor','white','string',highPass,'callback',@filter_hipass_callback);  
        function filter_hipass_callback(src,~)
            highPass=str2double(get(src,'string'));
                if plotSingleTrials && plotmode == 2
                    loadTrialData(selectedchannel);
                end
                updatePlot;
                drawMap(latency);
        end
    
    uicontrol('style','text','units','normalized','position',[0.34 0.52 0.12 0.04],...
        'string','to','fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    uicontrol('style','edit','units','normalized','position',[0.36 0.53 0.03 0.04],...
        'FontSize', 12, 'BackGroundColor','white','string',lowPass,'callback',@filter_lowpass_callback);       
        function filter_lowpass_callback(src,~)
            
            val=str2double(get(src,'string'));
            nyquist = fs / 2.0;
            if val > nyquist
               s = sprintf('Low-pass frequency must be less than Nyquist (= %.1f)',nyquist);
               errordlg(s);
               set(src,'string',num2str(nyquist) );
               return;
            end
            
            lowPass=str2double(get(src,'string'));
               
            if plotSingleTrials && plotmode == 2
                loadTrialData(selectedchannel);
            end
            updatePlot;
            drawMap(latency);
        end
            
    uicontrol('style','checkbox','units','normalized','position',[0.41 0.53 0.18 0.04],'value',useBaseline,...
            'string','Apply Baseline','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@baseline_callback);
       
        function baseline_callback(src,~)
            useBaseline = get(src,'val');
            if useBaseline
                set(base_start_txt, 'enable','on');
                set(base_start, 'enable','on');
                set(base_end_txt, 'enable','on');
                set(base_end, 'enable','on');
            else
                set(base_start_txt, 'enable','off');
                set(base_start, 'enable','off');
                set(base_end_txt, 'enable','off');
                set(base_end, 'enable','off');
            end
                      
            updatePlot;
            drawMap(latency);
        end
    
    base_start=uicontrol('style','edit','units','normalized','position',[0.5 0.53 0.03 0.04],...
        'FontSize', 12, 'BackGroundColor','white','string',baselineStart,'callback',@baseStart_callback);        
        function baseStart_callback(src,~)
            baselineStart=str2double(get(src,'string'));
            drawMap(latency);
            updatePlot;
        end

    base_start_txt=uicontrol('style','text','units','normalized','position',[0.54 0.52 0.12 0.04],...
        'string','to','fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    
    base_end=uicontrol('style','edit','units','normalized','position',[0.56 0.53 0.03 0.04],...
        'FontSize', 12, 'BackGroundColor','white','string',baselineEnd,'callback',@baseEnd_callback);
        function baseEnd_callback(src,~)
            baselineEnd=str2double(get(src,'string'));
            updatePlot;
            drawMap(latency);
        end
    base_end_txt=uicontrol('style','text','units','normalized','position',[0.6 0.52 0.12 0.04],...
        'string','seconds','fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');

        
    if useBaseline
        set(base_start_txt, 'enable','on');
        set(base_start, 'enable','on');
        set(base_end_txt, 'enable','on');
        set(base_end, 'enable','on');
    else
        set(base_start_txt, 'enable','off');
        set(base_start, 'enable','off');
        set(base_end_txt, 'enable','off');
        set(base_end, 'enable','off');
    end

    function autoScale
        if plotmode == 2
            if plotSingleTrials
                maxScale = max(max( abs(trialData) )) * 1.2;
            else
                maxScale = max( abs(plotdata(:,selectedchannel)) ) * 1.2;
            end
        elseif plotmode == 1
            rms = zeros(1,nsamples);
            for i=1:nsamples
                tt = plotdata(i,:);
                rms(i) = norm(tt) / sqrt(length(tt));
            end
            maxScale = max(rms) * 1.2;
        else
            maxScale = max(max( abs(plotdata) )) * 1.2;
        end
        minScale = -maxScale;
    end
 

    function channel_dropDown_Callback(src,~)   
        
        selection = get(src,'value');
        if selection == 1
            % update map locs
            plotmode = 0;
            set(plotAverageToggle,'checked','on');
            
            mapLocs = getMapLocs(header, plotPlanar);
            mapLocs(excludeChannelList) = [];
            plotSingleTrials = 0;
            set(plotSingleTrialToggle,'enable','off','checked','off');
            set(plotAllTrialsToggle,'enable','off','checked','off');
            set(plotTFRButton,'enable','off');
            set(plotGFPToggle,'enable','on');
        else
            plotmode = 2;
            selectedchannel = selection - 1;
            loadTrialData(selectedchannel);
            
            set(plotSingleTrialToggle,'enable','on');
            set(plotAllTrialsToggle,'enable','on');
            set(plotTFRButton,'enable','on');
            set(plotGFPToggle,'enable','off');
        end
        updatePlot;
    end

    function updatePlot
        
        % filter and average data if not plotting single trials 
        % filter all data then exclude bad channels
        if ~plotSingleTrials           
                data = [];
                for k=1:nchannels
                    data(:,k) = bw_filter(originalData(:,k)', fs, [highPass lowPass], filterOrder, bidirectional, 0);  % 0 = bandReject flag
                    if useBaseline
                        bstart = round ((baselineStart * fs) + preTrigPts) + 1;
                        bend = round( (baselineEnd * fs) + preTrigPts) + 1;
                        ave = data(:,k);
                        b = mean(ave(bstart:bend)); 
                        data(:,k) = ave-b;
                    end
                end
                data(:,excludeChannelList) = [];           
                plotdata = data;               
        end
        
        if plotmode == 0
            plot_average;
        elseif plotmode == 1
            plot_GFP;
        else
            plot_single_channel;
        end
        
    end
     
    function loadTrialData(chan)
        chName = channelNames(chan,:);

        [~, trialData] = bw_CTFGetChannelData(dsName, chName);
        trialData = trialData' * 1e15;
        for k=1:size(trialData,1)
            tdata = trialData(k,:);
            trialData(k,:) = bw_filter(tdata, fs, [highPass lowPass], filterOrder, bidirectional, 0);  % 0 = bandReject flag
        end
        maxScale = max(max( abs(trialData) ));
        minScale = -maxScale;
    end
   
    function plot_average

        cla;
        axtest = subplot('Position', plotbox);      
        
        plot(timeVec, plotdata);
        
        set(axtest,'ylim',[minScale maxScale],'xlim',[minRange maxRange]);
        
        ax=axis;
        cursorHandle=line([latency latency], [ax(3) ax(4)],'color',[0.8,0.4,0.1]);
        
        % time zero vertical and baseline
        line_h1 = line([0 0],[ax(3) ax(4)]);
        set(line_h1, 'Color', [0 0 0]);
        vertLineVal = 0;
        if vertLineVal > ax(3) && vertLineVal < ax(4)
            line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
            set(line_h2, 'Color', [0 0 0]);
        end
        
        % annotate
  
        set(fh,'Name','MEG Average');
        xlabel('Time (sec)');
        ylabel('femtoTesla');        
        tt = title(dsName);
        set(tt,'fontsize',10,'fontname','lucinda','Interpreter','none');
            
        drawMap(latency);
    end

    function plot_GFP
        
        nsamples = size(plotdata,1);
        
        rms = zeros(1,nsamples);
        for i=1:nsamples
            tt = plotdata(i,:);
            rms(i) = norm(tt) / sqrt(length(tt));
        end
        
        cla;
        axtest = subplot('Position', plotbox);      
        plot(timeVec, rms);
        set(axtest,'ylim',[0 maxScale],'xlim',[minRange maxRange]);
                 
        ax=axis;        
        cursorHandle=line([latency latency], [ax(3) ax(4)],'color',[0.8,0.4,0.1]);
        % annotate
        set(fh,'Name','MEG Average (Global Field Power)');
        xlabel('Time (sec)');
        ylabel('femtoTesla (RMS)');

        tt = title(dsName);
        set(tt,'fontsize',11,'Interpreter','none');
        line_h1 = line([0 0],[ax(3) ax(4)]);
         set(line_h1, 'Color', [0 0 0]);
        vertLineVal = 0;
        if vertLineVal > ax(3) && vertLineVal < ax(4)
            line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
            set(line_h2, 'Color', [0 0 0]);
        end
        drawMap(latency);
        
    end

    function plot_single_channel
        set(fh,'Name','MEG Average (Single Channel)');
 
        % which channel to plot...        
        chName = channelNames(selectedchannel,:);
        
        axtest = subplot('Position', plotbox);      
        if plotSingleTrials          
            if plotAllTrials 
               tdata = trialData';
            else
               tdata = trialData(selectedTrial,:)';
            end
            
            set(fh,'Name','MEG Data (Single Channel)');
            plot(timeVec,tdata);           
        else
            set(fh,'Name','MEG Average (Single Channel)');
            plot(timeVec,plotdata(:,selectedchannel));
        end
                
        hold off
        set(axtest,'ylim',[minScale maxScale],'xlim',[minRange maxRange]);

        ax=axis;
        
        cursorHandle=line([latency latency], [ax(3) ax(4)],'color',[0.8,0.4,0.1]);
        %plot annotations

        xlabel('Time (sec)');
        ylabel('femtoTesla');
        tt = title(dsName);
        set(tt,'fontsize',11,'Interpreter','none');
        
        legend(chName, 'AutoUpdate','off');
        
        line_h1 = line([0 0],[ax(3) ax(4)]);
        set(line_h1, 'Color', [0 0 0]);
        vertLineVal = 0;
        if vertLineVal > ax(3) && vertLineVal < ax(4)
            line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
            set(line_h2, 'Color', [0 0 0]);
        end
        
        hold off      
        drawMap(latency);             
    end


    %%%%%%%%%%%%%%%%%
    % Dipole Fitting
    %%%%%%%%%%%%%%%%%

    
    uicontrol('style','checkbox','units','normalized','position',[0.06 0.48 0.08 0.04],...
        'string','Dipole Fit','backgroundcolor','white','foregroundcolor','blue','fontweight','bold',...
        'value',enableDipoleFit,'FontSize',11,'callback',@enable_dipole_callback);

    annotation('rectangle',[0.03 0.03 0.94 0.47],'EdgeColor','blue');
    
    
    dip_text(1) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.44 0.05 0.03],...
            'string','Position:','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(2) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.4 0.05 0.03],...
            'string','X (cm)','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(3) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.36 0.05 0.03],...
            'string','Y (cm)','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(4) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.32 0.05 0.03],...
            'string','Z (cm)','fontsize',12,'horizontalalignment','left', 'enable','off');

    dip_text(5) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.28 0.1 0.03],...
            'string','Orientation:','fontsize',12,'horizontalalignment','left', 'enable','off');    
    dip_text(6) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.24 0.05 0.03],...
            'string','xo','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(7) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.2 0.05 0.03],...
            'string','yo','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(8) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.16 0.05 0.03],...
            'string','zo','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(9) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.05 0.11 0.05 0.05],...
            'string','Moment (nAm)','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(10) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.2 0.36 0.12 0.03],...
            'string','# of Passes:','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(11) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.2 0.32 0.12 0.03],...
            'string','Fit Tolerance:','fontsize',12,'horizontalalignment','left', 'enable','off');
          
      
    dip_text(12) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.2 0.28 0.1 0.03],...
            'string','Sphere Origin:','fontsize',12,'horizontalalignment','left', 'enable','off');    
    dip_text(13) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.2 0.24 0.05 0.03],...
            'string','X (cm)','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(14) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.2 0.2 0.05 0.03],...
            'string','Y (cm)','fontsize',12,'horizontalalignment','left', 'enable','off');
    dip_text(15) = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.2 0.16 0.05 0.03],...
            'string','Z (cm)','fontsize',12,'horizontalalignment','left', 'enable','off');    
        
        
    fit_text = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.2 0.4 0.15 0.03],...
            'string','Fit Error = 0.0','fontsize',12,'fontweight','bold','horizontalalignment','left', 'enable','off');  
         
    xedit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.1 0.405 0.08 0.03],...
            'string',startPos(1,currentDip),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@updateParams_callback);
    yedit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.1 0.365 0.08 0.03],...
            'string',startPos(2,currentDip),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@updateParams_callback);
    zedit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.1 0.325 0.08 0.03],...
            'string',startPos(3,currentDip),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@updateParams_callback);
 
    xoedit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.1 0.245 0.08 0.03],...
            'string',startOri(1,currentDip),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@updateParams_callback);
    yoedit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.1 0.205 0.08 0.03],...
            'string',startOri(2,currentDip),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@updateParams_callback);
    zoedit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.1 0.165 0.08 0.03],...
            'string',startOri(3,currentDip),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@updateParams_callback);

    sphereX = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.24 0.245 0.04 0.03],...
            'string',sphere(1),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@fitDipole_callback);
    sphereY = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.24 0.205 0.04 0.03],...
            'string',sphere(2),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@fitDipole_callback);
    sphereZ = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.24 0.165 0.04 0.03],...
            'string',sphere(3),'fontsize',12,'horizontalalignment','left', 'enable','off','callback',@fitDipole_callback);    
        
    momentEdit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.1 0.125 0.08 0.03],...
            'string',moments(1),'fontsize',12,'horizontalalignment','left', 'enable','off');        
        
        
    passesEdit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.28 0.365 0.04 0.03],...
            'string',numPasses,'fontsize',12,'horizontalalignment','left', 'enable','off');
    toleranceEdit = uicontrol('style','edit','units','normalized','backgroundcolor','white','position',[0.28 0.325 0.04 0.03],...
            'string',tolerance,'fontsize',12,'horizontalalignment','left', 'enable','off');    
            
    dipole_menu = uicontrol('style','popup','units','normalized','fontsize',11,'position',[0.1 0.445 0.08 0.03],...
        'Foregroundcolor','black','string', {'Dipole 1'},'enable','off','backgroundcolor','white','callback',@dipoleMenu_callback);   
 
    add_dipole_button = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.2 0.45 0.04 0.03],...
        'Foregroundcolor','black','string','Add','enable','off','backgroundcolor','white','callback',@addDipole_callback);   

    remove_dipole_button = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.25 0.45 0.05 0.03],...
        'Foregroundcolor','black','string','Remove','enable','off','backgroundcolor','white','callback',@removeDipole_callback);   
   
    fitDipole_button = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.05 0.05 0.08 0.04],...
        'Foregroundcolor','blue','string','Fit Dipole','enable','off','backgroundcolor','white','callback',@fitDipole_callback);
       
    reset_button = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.15 0.05 0.08 0.04],...
        'Foregroundcolor','blue','string','Reset Parameters','enable','off','backgroundcolor','white','callback',@resetParams_callback);

    fitting_txt = uicontrol('style','text','units','normalized','backgroundcolor','white','position',[0.28 0.05 0.12 0.03],...
            'string','','fontsize',14,'foregroundColor','red','horizontalalignment','left', 'enable','off');  
 
    headModel_button = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.2 0.125 0.1 0.03],...
        'Foregroundcolor','black','string','Read Head Model','enable','off','backgroundcolor','white','callback',@headModel_callback);
    
    plotDipoleButton = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.37 0.05 0.1 0.04],...
        'Foregroundcolor','black','string','Overlay on MRI','enable','off','backgroundcolor','white','callback',@plotDipole_callback);
    
    saveDipoleButton = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.48 0.05 0.08 0.04],...
        'Foregroundcolor','black','string','Save to File','enable','off','backgroundcolor','white','callback',@saveDipole_callback);
    
      
    function dipoleMenu_callback(src,~)
        currentDip = get(src,'value');
        pos = startPos(:,currentDip);
        set(xedit,'string',pos(1));
        set(yedit,'string',pos(2));
        set(zedit,'string',pos(3));
        ori = startOri(:,currentDip);
        set(xoedit,'string',ori(1));
        set(yoedit,'string',ori(2));
        set(zoedit,'string',ori(3));
        set(momentEdit,'string',moments(currentDip));
        
        updateDipolePlot(startPos,startOri);
        
        % in case dipole fit exited with error
        isfitting = false;
        set(fitting_txt,'string','');
        drawnow;
    end
    
    function headModel_callback(~,~)
        s = fullfile(dsName,'*.hdm');
        [name, path, ~] = uigetfile('*.hdm','Select a Head Model (.hdm) file', s);
        if name == 0
          return;
        end
        hdmFile = [path name];
        origin = readHeadModelFile(hdmFile);
        
        if ~isempty(origin)
            sphere = origin';
            set(sphereX,'string',sphere(1));
            set(sphereY,'string',sphere(2));
            set(sphereZ,'string',sphere(3));
        end
    end

    function plotDipole_callback(~,~)

        [~, ~, ~, ~, mri_filename] = bw_parse_ds_filename(dsName);
        if ~exist(mri_filename,'file')
            errordlg('No MRI file associated with this dataset');
            return;
        end
        ndip = size(startPos,2);
        dip_params = [startPos' startOri' moments(1:ndip)'];

        tfile = fullfile(dsName,'tempDipFile_000.dip');
        bw_writeCTFDipoleFile(tfile, dip_params);
        bw_MRIViewer(mri_filename, tfile);
           
    end

    function saveDipole_callback(~,~)
        
        defPath = strcat(dsName,filesep,'test.dip');

        [filename, pathname, ~] = uiputfile( ...
            {'*.dip','CTF Dipole file (*.dip)'}, ...
            'Save dipole file',defPath);
        
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        
        fullname = fullfile(pathname,filename);
        ndip = size(startPos,2);
        dip_params = [startPos' startOri' moments(1:ndip)'];

        bw_writeCTFDipoleFile(fullname, dip_params);
           
    end

    function origin = readHeadModelFile(file)
        
        fprintf('Reading head model file %s...\n',file);
       
        t = importdata(file);
        % get origins for MEG channels only
        if iscell(t)
            count = 1;
            for k=1:length(t)
                s = char(t(k));
                if contains(s,'M')
                    x = sscanf(s,'%s %lf %lf %lf %lf');
                    origins(count,1:3) = [x(end-3) x(end-2) x(end-1)];
                    count = count+1;
                end
            end
        else
            % for CTF files??
            tab = char(t.textdata);
            idx = find(tab(:,1) == 'M');
            origins = t.data(idx,:);  
            origins(:,4) = [];
        end
        % just return mean in case multiSphere, else is single sphere
        origin = mean(origins,1);
        fprintf('Mean sphere origin = %.2f %.2f %.2f cm \n',origin(1:3));
          
    end

    function addDipole_callback(~,~)
        if numDips == maxDipoles
            fprintf('Exceeded maximum number of dipoles\n');
            return;
        end       
        numDips = numDips+1;
        currentDip = numDips;
        startPos(:,currentDip) = defaultStartPos(:,currentDip);
        startOri(:,currentDip) = defaultStartOri(:,currentDip);
        
        for k=1:numDips
            temp{k} = sprintf('Dipole %d',k);
        end            
        set(dipole_menu,'string',temp);
        set(dipole_menu,'value',numDips);
       
        updateDipolePlot(startPos,startOri);
        
    end

    function removeDipole_callback(~,~)
        if numDips == 1
            return;
        end       
        startPos(:,currentDip) = [];
        startOri(:,currentDip) = [];
        numDips = numDips-1;
        currentDip = numDips;
        
        for k=1:numDips
            tstr{k} = sprintf('Dipole %d',k);
        end            
        set(dipole_menu,'string',tstr);
        set(dipole_menu,'value',numDips);
        
        updateDipolePlot(startPos,startOri);
        
    end

    function resetParams_callback(~,~)
        for k=1:numDips
            startPos(:,k) = defaultStartPos(:,k);
            startOri(:,k) = defaultStartOri(:,k);  
        end
        pos = defaultStartPos(:,currentDip);
        ori = defaultStartOri(:,currentDip);
        set(xedit,'string',pos(1));
        set(yedit,'string',pos(2));
        set(zedit,'string',pos(3));
        set(xoedit,'string',ori(1));
        set(yoedit,'string',ori(2));
        set(zoedit,'string',ori(3));
        set(momentEdit,'string',moments(currentDip));
        
        updateDipolePlot(startPos,startOri);
        
        % in case dipole fit exited with error
        isfitting = false;
        set(fitting_txt,'string','');
        drawnow;
    end

    function updateParams_callback(~,~)
        startPos(1,currentDip) = str2double(get(xedit,'string'));
        startPos(2,currentDip) = str2double(get(yedit,'string'));
        startPos(3,currentDip) = str2double(get(zedit,'string'));
        startOri(1,currentDip) = str2double(get(xoedit,'string'));
        startOri(2,currentDip) = str2double(get(yoedit,'string'));
        startOri(3,currentDip) = str2double(get(zoedit,'string'));
        
        updateDipolePlot(startPos,startOri);
       
    end

    function fitDipole_callback(~,~)
        if isfitting
            return;
        end
        
        isfitting = true;
        set(fitting_txt,'string','Fitting...');
        drawnow;
       
        % note this makes positions column vectors
        startPos(1) = str2double(get(xedit,'string'));
        startPos(2) = str2double(get(yedit,'string'));
        startPos(3) = str2double(get(zedit,'string'));
        startOri(1) = str2double(get(xoedit,'string'));
        startOri(2) = str2double(get(yoedit,'string'));
        startOri(3) = str2double(get(zoedit,'string'));

        sphere(1) = str2double(get(sphereX,'string'));
        sphere(2) = str2double(get(sphereY,'string'));
        sphere(3) = str2double(get(sphereZ,'string'));
        
        numPasses = str2double(get(passesEdit,'string'));
        tolerance = str2double(get(toleranceEdit,'string'));
        
        if useBaseline
            baseline = [baselineStart baselineEnd];
        else
            baseline = [];
        end
        
        if isempty(excludeChannelList)      
            badChannelList = {};
        end
                
        % mex function to do fit ...  pass empty arguments to use defaults         
        [forward_data, startPos, startOri, mom, error] = bw_fitDipole(dsName, [highPass lowPass],latency,numDips, ...
                    startPos, startOri, sphere', numPasses, tolerance, baseline, badChannelList);   
        
        moments(1:numDips) = mom(1:numDips);
        % pos and ori returned as continuous arrays
        startPos = reshape(startPos,3,numDips);
        startOri = reshape(startOri,3,numDips);
        
        forward_data = forward_data * 1e15; % forward returned in Tesla
        
        pos = startPos(:,currentDip);
        ori = startOri(:,currentDip);
        set(xedit,'string',pos(1));
        set(yedit,'string',pos(2));
        set(zedit,'string',pos(3));
        set(xoedit,'string',ori(1));
        set(yoedit,'string',ori(2));
        set(zoedit,'string',ori(3));     
        set(momentEdit,'string',moments(currentDip));

        s = sprintf('Fit Error = %0.3f%%',error);
        set(fit_text, 'string',s);
        
        set(fitting_txt,'string','');  

        drawMap(latency); 
        updateDipolePlot(startPos,startOri);
        
        isfitting = false;
            
    end
    function enable_dipole_callback(src,~)
        enableDipoleFit = get(src,'val');
        enableDipole;
    end


    function enableDipole
        if enableDipoleFit 
            s = 'on';
        else
            s = 'off';
        end
        set(dip_text(:),'enable',s);
        set(fitDipole_button,'enable',s);
        set(xedit,'enable',s);
        set(yedit,'enable',s);
        set(zedit,'enable',s);
        set(xoedit,'enable',s);
        set(yoedit,'enable',s);
        set(zoedit,'enable',s);
        set(sphereX,'enable',s);
        set(sphereY,'enable',s);
        set(sphereZ,'enable',s);
        set(momentEdit,'enable',s);
        set(fit_text,'enable',s);
        set(passesEdit,'enable',s);
        set(toleranceEdit,'enable',s);
        set(dipole_menu,'enable',s);
        set(add_dipole_button,'enable',s);   
        set(remove_dipole_button,'enable',s);
        set(fitting_txt,'enable',s);
        set(reset_button,'enable',s);
        set(headModel_button,'enable',s);
        set(plotDipoleButton,'enable',s);
        set(saveDipoleButton,'enable',s);
        drawMap(latency);  
        
          
        if ~enableDipoleFit
            objs = get(dipPlotAxis,'Children');
            set(objs,'visible','off');   
        else
            objs = get(dipPlotAxis,'Children');
            set(objs,'visible','on');   

        end
        
        
        updateDipolePlot(startPos, startOri);
        
    end
           


    % Cursor routines
    function updateCursors                 
        if ~isempty(cursorHandle)
            set(cursorHandle, 'XData', [latency latency]);      
        end 
        s = sprintf('Cursor = %.4f s', latency);
        set(latency_text, 'string', s);
    end
        
    function buttondown(~,~)         

        ax = gca;
        if ax == mapAxis || ax == dipMapAxis || ax == dipPlotAxis
            return;
        end
        
        % get current latency in s (x coord)
        mousecoord = get(ax,'currentpoint');
        x = mousecoord(1,1);
        y = mousecoord(1,2);
        xbounds = xlim;
        ybounds = ylim;
        if x < xbounds(1) | x > xbounds(2) | y < ybounds(1) | y > ybounds(2)
            return;
        end
        
        % move to current location on click ...
        latency = mousecoord(1,1);
        updateCursors;        
        ax = gca;
        set(fh,'WindowButtonMotionFcn',{@dragCursor,ax}) % need to explicitly pass the axis handle to the motion callback   
    end

    % button down function - drag cursor
    function dragCursor(~,~, ax)
        mousecoord = get(ax,'currentpoint');
        x = mousecoord(1,1);
        y = mousecoord(1,2);
        xbounds = xlim;
        ybounds = ylim;
        if x < xbounds(1) | x > xbounds(2) | y < ybounds(1) | y > ybounds(2)
            return;
        end        
        latency = mousecoord(1,1);
        updateCursors;
    end

    % on button up event set motion event back to no callback 
    function stopdrag(~,~)
        set(fh,'WindowButtonMotionFcn','');
        drawMap(latency);
    end



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % map routines 

    MapScale_button = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.84 0.55 0.06 0.04],...
    'Foregroundcolor','black','string','Set Scale','enable','off','backgroundcolor','white','callback',@editMapRange_callback);

    function editMapRange_callback(~,~)
        
        input = inputdlg({'Min. Amplitude Scale (fT)';'Max. Amplitude Scale (fT)'},'Set Map Range ', [1 50; 1 50],...
            {num2str(mapScale(1)), num2str(mapScale(2))});
        if isempty(input)
            return;
        end   
        mapScale(1) = str2num(input{1});
        mapScale(2) = str2num(input{2});
        
        drawMap(latency);
                
        updatePlot;
    end

    uicontrol('style','checkbox','units','normalized','fontsize',11,'value',autoscaleMap,'position',[0.76 0.55 0.08 0.04],...
    'Foregroundcolor','black','string','AutoScale','backgroundcolor','white','callback',@autoScaleMap_callback);

    function autoScaleMap_callback(src,~)     
        autoscaleMap = get(src,'value');    
        
        if autoscaleMap 
            set(MapScale_button,'enable','off');
        else
             set(MapScale_button,'enable','on');
        end
        drawMap(latency);               
        updatePlot;
    end

    uicontrol('style','checkbox','units','normalized','fontsize',11,'value',showSensorLabels,'position',[0.76 0.52 0.08 0.04],...
    'Foregroundcolor','black','string','Show Labels','backgroundcolor','white','callback',@show_sensor_labels_callback);

    function show_sensor_labels_callback(src,~)
        showSensorLabels = get(src,'value');
        drawMap(latency);
    end

    function drawMap(latency)

        subplot('Position', mapbox);
        mapAxis = gca;
        sample = round (latency * fs) + preTrigPts + 1;             
        if sample < 1 || sample > size(data,1)
            return;
        end
       
        map_data = data(sample,:)'; 
        
        tempLocs = mapLocs;
        
        if showSensors && showSensorLabels
            topoplot(map_data, tempLocs,'colormap',jet,'numcontour',10,'electrodes','ptslabels','shrink',0.1);
        elseif showSensors 
            topoplot(map_data, tempLocs,'colormap',jet,'numcontour',10,'electrodes','on','shrink',0.1);
        elseif showSensorLabels 
            topoplot(map_data, tempLocs,'colormap',jet,'numcontour',10,'electrodes','labels','shrink',0.1);        
        else
            topoplot(map_data, tempLocs,'colormap',jet,'numcontour',10,'electrodes','off','shrink',0.1);        
        end
        
        if ~autoscaleMap           
            caxis(mapScale);
        end
        
        tstr = sprintf('t = %.1f ms', latency*1000);
        tt = title(tstr);
        set(tt,'Interpreter','none','fontsize',14,'fontweight','bold');

        h = colorbar;
        set(h,'fontsize',12);
        set(get(h,'YLabel'),'String','femtoTesla');
        
        
        %%%%%%%%%%
        % always update forward map but hide if option deselected
        
        subplot('Position', dipMapbox);
        

        tempLocs = mapLocs;

        if showSensors && showSensorLabels
            topoplot(forward_data, tempLocs,'colormap',jet,'numcontour',10,'electrodes','ptslabels','shrink',0.1);
        elseif showSensors 
            topoplot(forward_data, tempLocs,'colormap',jet,'numcontour',10,'electrodes','on','shrink',0.1);
        elseif showSensorLabels 
            topoplot(forward_data, tempLocs,'colormap',jet,'numcontour',10,'electrodes','labels','shrink',0.1);        
        else
            topoplot(forward_data, tempLocs,'colormap',jet,'numcontour',10,'electrodes','off','shrink',0.1);        
        end

        dipMapAxis = gca;
        
        if ~autoscaleMap           
            caxis(mapScale);
        end

        if ~enableDipoleFit 
            objs = get(dipMapAxis,'Children');
            set(objs,'visible','off');
            tt = title('');
            set(tt,'fontsize',14,'fontweight','bold');
        else               
            tt = title('Forward Model');
            set(tt,'fontsize',14,'fontweight','bold');
            h = colorbar;
            set(h,'fontsize',12);
            set(get(h,'YLabel'),'String','femtoTesla');
        end
                
    end

    function updateDipolePlot(position, orientation)           
                    
        pos = repmat(100,3,maxDipoles);
         
        if ~plotInitialized
            subplot('Position', dipPlotbox);    

            dipPlotAxis = gca;
            hold on;            
            % initialize dipole plot - create markers for all and for invalid ones just set 
            % position out of view, then just update parameters 
            hPlotData = scatter3(pos(1,:), pos(2,:), pos(3,:), 50, dipoleColors, 'filled');  
            outlineHdl = scatter3(pos(1,1), pos(2,1), pos(3,1), 70, 'black', 'o');

            for k=1:maxDipoles
                h = [pos(1,k) pos(2,k) pos(3,k)];
                x2 = pos(1,k) + (orientation(1,1) * tailLen);
                y2 = pos(2,k) + (orientation(2,1) * tailLen);
                z2 = pos(3,k) + (orientation(3,1) * tailLen);
                v = [x2 y2 z2];
                col = dipoleColors(k,1:3);
                lineHdl(k) = line(h,v, 'Color', col, 'LineWidth', tailWidth);
            end
            
            grid on
            xlabel('X (cm)')
            ylabel('Y (cm)')
            zlabel('Z (cm)')

            xlim([-10 10]);
            ylim([-10 10]);
            zlim([-15 15]);

            view(20,20)      
            set(dipPlotAxis,'Clipping','off');
            
            axis on
                                                 
            plotInitialized = 1;
                      
        end
        
        % update current dipoles
        ndip = size(position,2);
        pos(1:3,1:ndip) = position(1:3,1:ndip);
        set(hPlotData,'XData',pos(1,:),'YData',pos(2,:),'ZData',pos(3,:));  
        set(outlineHdl,'XData',pos(1,currentDip),'YData',pos(2,currentDip),'ZData',pos(3,currentDip));  
            
        for k=1:ndip
            xd = [position(1,k) (position(1,k) + (orientation(1,k)*tailLen)) ];
            yd = [position(2,k) (position(2,k) + (orientation(2,k)*tailLen)) ];
            zd = [position(3,k) (position(3,k) + (orientation(3,k)*tailLen)) ];
            set(lineHdl(k),'XData', xd, 'YData', yd, 'ZData', zd);              
        end
        % ned to re-hide any deleted dipoles...
        for k=ndip+1:maxDipoles
            xd = [pos(1,k) (pos(1,k) + (orientation(1,1)*tailLen)) ];
            yd = [pos(2,k) (pos(2,k) + (orientation(2,1)*tailLen)) ];
            zd = [pos(3,k) (pos(3,k) + (orientation(3,1)*tailLen)) ];
            set(lineHdl(k),'XData', xd, 'YData', yd, 'ZData', zd); 
        end
 
        
        hold off;
    end

end

function [mapLocs] = getMapLocs(header, plotPlanar)

    % create an EEGLAB chanlocs structure to avoid having to save .locs file
    mapLocs = struct('labels',{},'theta', {}, 'radius', {});
    
    channelIndex = 1;
    for i=1:header.numChannels
            
        chan = header.channel(i);
        if ~chan.isSensor
            continue;
        end
        
        name = chan.name;
        % remove dashes in CTF names
        idx = strfind(name,'-');
        if ~isempty(idx)
            temp=name(1:idx-1);
            name = temp;
        end
        
        if plotPlanar && chan.sensorType == 5
            % for planar grads position is midpoint between coils          
            X = (chan.xpos + chan.xpos2) / 2.0;
            Y = (chan.ypos + chan.ypos2) / 2.0;
            Z = (chan.zpos + chan.zpos2) / 2.0;
        else
            X = chan.xpos;
            Y = chan.ypos;
            Z = chan.zpos;
        end
        
        [th, phi, ~] = cart2sph(X,Y,Z);

        decl = (pi/2) - phi;
        radius = decl / pi;
        theta = th * (180/pi);
        if (theta < 180)
            theta = -theta;
        else
            theta = 360 - theta;
        end

        mapLocs(channelIndex).labels = name;
        mapLocs(channelIndex).theta = theta;
        mapLocs(channelIndex).radius = radius;  
        channelIndex = channelIndex + 1;
    end
end

