function bw_plot_data(dsName, bparams)
%       BW_PLOT_DATA
%
%   function bw_plot_data(dsName, bparams, ctf_params)
%
%   DESCRIPTION: Creates a GUI to plot dataset dsName's global field power
%   as well as the channels. For indiidual channel selection the GUI will
%   aslo display the corresponding latency topoplot.
%
% (c) D. Cheyne, August 2010. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%  bw_plot_data
%   D. Cheyne, Nov, 26, 2010
%
%   routine to plot MEG data (average or global field power)
%
%
%   major code rewrite adn updates for version 4.0 Jan, 2022 (D. Cheyne)
%
%
% (c) D. Cheyne, August 2010. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

    %adding topoplot folder to path
    topocheck=exist('topoplot/topoplot.m','file');
    if topocheck ~= 2
        topopath=which('bw_start');
        topopath=[topopath(1:end-10),'topoplot/'];
        addpath(topopath)
    end

    scrnsizes=get(0,'MonitorPosition');

    BACKCOLOR = [.93 .96 1];
    BACKCOLOR = [1 1 1];

    global global_latency

    plotmode = 0;
    plotPlanar = false;
    plotRMS = false;
    plotSingleTrials = false;
    integrateOverTrials = false;
    trialData = [];
    latency = 0.05;
    rmsWindow = 0.02;
    header = [];
    excludeChannelList = [];
    channelset = 1;
    showSensors = 1;
    showSensorLabels = 0;
    cursorHandle = 0;
    mapAxis = 0;

    % Draw arrows - calls:  uparrow.m and downarrow.m - %%%% ADDED BY CECILIA %%%%
    uparrow_im=draw_uparrow;
    downarrow_im=draw_downarrow;
    leftarrow_im=draw_leftarrow;
    rightarrow_im=draw_rightarrow;
    
    if ~exist('dsName','var')
        dsName = uigetdir('.ds', 'Select CTF dataset ...');
        if dsName == 0
            return;
        end    
        params = bw_setDefaultParameters(dsName);
        bparams = params.beamformer_parameters;
    end
   

    warning('off','MATLAB:griddata:DuplicateDataPoints')

    fh = figure('Position',[scrnsizes(1,3)/3+200 scrnsizes(1,4)/2 1200 900],'color','white','menubar','none',...
        'numberTitle','off','WindowButtonUpFcn',@stopdrag,'WindowButtonDownFcn',@buttondown);

    if ispc
        movegui(fh,'center');
    end  
    
    if bparams.filterData
       highPass = bparams.filter(1);
       lowPass = bparams.filter(2);
    else
       lowPass = 0;
       highPass = 0;
    end
    
    filterOrder = 4;    % keep fixed for now?
    
    if bparams.useReverseFilter
        bidirectional = 1;
    else
        bidirectional = 0;
    end    
    
    baselineStart = bparams.baseline(1);
    baselineEnd = bparams.baseline(2);    
    useBaseline =  bparams.useBaselineWindow;

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
    [timeVec, channelNames, originalData] = bw_CTFGetAverage(dsName); 
  
    [channelNames, ~, ~] = bw_CTFGetSensors(dsName, 0);
        
    originalData = originalData * 1e15;  % display in femtoTesla
    
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
      
    uicontrol('style','popup','units','normalized',...
        'position',[0.12 0.88 0.15 0.1],'String',clabels,...
        'Backgroundcolor','white','fontsize',12,'fontname','lucinda','value',1,'callback',...
        @channel_dropDown_Callback);
   
     uicontrol('style','pushbutton','units','normalized','position',[0.28 0.95 0.1 0.04],'string','Edit Channels',...
            'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@edit_channels_callback);                    
        function edit_channels_callback(~,~)
            [excludeChannelList, channelset] = bw_select_data(dsName, excludeChannelList, channelset);
            updatePlot;
            % update Map
            mapLocs = getMapLocs(header, plotPlanar);
            mapLocs(excludeChannelList) = [];
            drawMap(latency);
        end  
    
    mapLocs = getMapLocs(header, plotPlanar);

    %needs to be accessible outside child function
    ax=[];
    axtest=[];
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
    minRange = timeVec(1);
    maxRange = timeVec(end);
    
    updatePlot;  
    autoScale;
    updatePlot;
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % uicontrols
    
    s = sprintf('Latency = %.4f s', latency);
    latency_text = uicontrol('style','text','units','normalized','position',[0.7 0.52 0.15 0.03],...
            'string',s,'fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');

    uicontrol('style','pushbutton','units','normalized','position',[0.82 0.52 0.04 0.04],...
            'CData',leftarrow_im,'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@cursor_left_callback);                         
        function cursor_left_callback(~,~)
             t = latency-dwel;
             if (t > min_time)
                latency = t;      
                updateCursors
                drawMap(latency);
             end
        end 
    uicontrol('style','pushbutton','units','normalized','position',[0.87 0.52 0.04 0.04],...
            'CData',rightarrow_im,'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@cursor_right_callback);                    
         function cursor_right_callback(~,~)
             t = latency+dwel;
             if (t < max_time)
                latency = t;                 
                updateCursors;
                drawMap(latency);
             end    
         end
  
    s = sprintf('Trial = %d', selectedTrial);
    trial_text = uicontrol('style','text','units','normalized','enable','off','position',[0.15 0.52 0.08 0.03],...
            'string',s,'fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');

    trialIncArrow = uicontrol('style','pushbutton','units','normalized','enable','off','position',[0.22 0.52 0.04 0.04],...
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
    trialDecArrow = uicontrol('style','pushbutton','units','normalized','enable','off','position',[0.27 0.52 0.04 0.04],...
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
     
    plotAllTrialsToggle = uicontrol('style','checkbox','units','normalized','position',[0.32 0.51 0.15 0.05],'value',plotAllTrials,'enable','off',...
        'string','Plot All Trials','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@plot_all_callback);
    function plot_all_callback(src,~)
        plotAllTrials = get(src,'value');
        
        if plotAllTrials
            set(trial_text, 'string','Trial = All');
            set(trialIncArrow,'enable','off');
            set(trialDecArrow,'enable','off');
        else
            s = sprintf('Trial = %d', selectedTrial);
            set(trialIncArrow,'enable','on');
            set(trialDecArrow,'enable','on');
            set(trial_text, 'string',s);             
        end
        
        updatePlot;
           
    end

    uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.91 0.76 0.03 0.04],...
    'CData',uparrow_im,'Foregroundcolor','black','backgroundcolor','white','callback',@scaleUp_callback);

    uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.91 0.71 0.03 0.04],...
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

    uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.91 0.65 0.07 0.04],...
    'Foregroundcolor','black','string','AutoScale','backgroundcolor','white','callback',@autoScale_callback);

    function autoScale_callback(~,~)
        autoScale;
        updatePlot;
    end

    uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.91 0.59 0.07 0.04],...
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

    plotTFRButton = uicontrol('style','pushbutton','units','normalized','position',[0.8 0.95 0.1 0.04],'string','Plot TFR','enable','off',...
            'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@plot_tfr_callback);                    
        function plot_tfr_callback(~,~)
            chName = channelNames(selectedchannel,:);
            bw_plot_channel_tfr(dsName, chName, [highPass lowPass], 1, 7)
        end  
    

    annotation('rectangle',[0.38 0.037 0.21 0.44],'EdgeColor',[0.5 0.5 0.5]); %% ADDED BY CECILIA    
 
    uicontrol('style','text','units','normalized','position',[0.43 0.42 0.14 0.05],...
        'string','Map Options','fontname','lucinda','fontsize',14,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');

    uicontrol('style','checkbox','units','normalized','position',[0.4 0.38 0.14 0.05],'value',showSensors,...
            'string','Show Sensors','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@show_sensors_callback);
        function show_sensors_callback(src,~)
            showSensors = get(src,'val');
            drawMap(latency);
        end

    uicontrol('style','checkbox','units','normalized','position',[0.4 0.33 0.14 0.05],'value',showSensorLabels,...
        'string','Show Labels','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@show_sensor_labels_callback);
    function show_sensor_labels_callback(src,~)
        showSensorLabels = get(src,'val');
        drawMap(latency);
    end

    uicontrol('style','checkbox','units','normalized','position',[0.39 0.20 0.18 0.05],'value',plotPlanar,...
            'string','Planar Gradiometers','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@plot_planar_callback);
  
    function plot_planar_callback(src,~)
            plotPlanar = get(src,'value');
            if plotPlanar
                fprintf('treating gradiometers as planar...plotting RMS');
            end
            
            drawMap(latency);
    end

    uicontrol('style','checkbox','units','normalized','position',[0.39 0.15 0.13 0.05],'value',plotRMS,...
            'string','Plot RMS','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@plot_RMS_callback);
              
    uicontrol('style','text','units','normalized','position',[0.4 0.10 0.16 0.05],...
        'string','RMS window (s)','fontname','lucinda','fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    
    rmsWindowEdit=uicontrol('style','edit','units','normalized','position',[0.52 0.11 0.06 0.06],...
        'FontSize', 12,'fontname','lucinda', 'BackGroundColor','white','string',rmsWindow,'callback',@rms_window_callback);

    integrateToggle =  uicontrol('style','checkbox','units','normalized','position',[0.4 0.07 0.18 0.03],'value',integrateOverTrials,...
            'string','Integrate over trials','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',11,'callback',@integrate_callback);
       
    set(rmsWindowEdit,'enable','off');
    set(integrateToggle,'enable','off');
    
    function rms_window_callback(src,~)
           rmsWindow=str2double(get(src,'string'));                               
           drawMap(latency);
    end

    function integrate_callback(src,~)
           integrateOverTrials = get(src,'value');               
           drawMap(latency);
    end
        
  
    function plot_RMS_callback(src,~)
            plotRMS = get(src,'val');            
            if plotRMS
                set(rmsWindowEdit,'enable','on');
                set(integrateToggle,'enable','on');
            else
                set(rmsWindowEdit,'enable','off');
                set(integrateToggle,'enable','off');
            end
                                   
            drawMap(latency);
    end
    

    uicontrol('style','text','units','normalized','position',[0.14 0.42 0.14 0.05],...
        'string','Plot Options','fontname','lucinda','fontsize',14,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    
    uicontrol('style','text','units','normalized','position',[0.03 0.35 0.14 0.05],...
        'string','Highpass (Hz):','fontname','lucinda','fontsize',11,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    uicontrol('style','edit','units','normalized','position',[0.13 0.36 0.05 0.06],...
        'FontSize', 11,'fontname','lucinda', 'BackGroundColor','white','string',highPass,'callback',@filter_hipass_callback);  
        function filter_hipass_callback(src,~)
            highPass=str2double(get(src,'string'));
                if plotSingleTrials && plotmode == 2
                    loadTrialData(selectedchannel);
                end
                updatePlot;
                drawMap(latency);
        end
    
    uicontrol('style','text','units','normalized','position',[0.2 0.35 0.12 0.05],...
        'string','Lowpass (Hz):','fontname','lucinda','fontsize',11,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    uicontrol('style','edit','units','normalized','position',[0.3 0.36 0.05 0.06],...
        'FontSize', 12,'fontname','lucinda', 'BackGroundColor','white','string',lowPass,'callback',@filter_lowpass_callback);       
        function filter_lowpass_callback(src,~)
            lowPass=str2double(get(src,'string'));
            if plotSingleTrials && plotmode == 2
                loadTrialData(selectedchannel);
            end
            updatePlot;
            drawMap(latency);
        end
    
    uicontrol('style','checkbox','units','normalized','position',[0.03 0.33 0.17 0.03],'value',bidirectional,...
        'string','zero phase shift','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@bidirectional_callback);           
        function bidirectional_callback(src,~)
            bidirectional = get(src,'val');
            updatePlot;
            drawMap(latency);
        end
        
    uicontrol('style','checkbox','units','normalized','position',[0.03 0.25 0.15 0.05],'value',useBaseline,...
            'string','Baseline Data','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@baseline_callback);
       
        function baseline_callback(src,~)
            useBaseline = get(src,'val');
            if useBaseline
                set(base_start_txt, 'enable','on');
                set(base_start, 'enable','on');
                set(base_end_txt, 'enable','on');
                set(base_end, 'enable','on');
            else
                set(base_start_txt, 'enable','of');
                set(base_start, 'enable','off');
                set(base_end_txt, 'enable','off');
                set(base_end, 'enable','off');
            end
                      
            updatePlot;
            drawMap(latency);
        end
    
    base_start_txt=uicontrol('style','text','units','normalized','position',[0.03 0.18 0.12 0.05],...
        'string','Start (s):','fontname','lucinda','fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    base_start=uicontrol('style','edit','units','normalized','position',[0.1 0.19 0.05 0.06],...
        'FontSize', 11,'fontname','lucinda', 'BackGroundColor','white','string',baselineStart,'callback',@baseStart_callback);        
        function baseStart_callback(src,~)
            baselineStart=str2double(get(src,'string'));
            drawMap(latency);
            updatePlot;
        end

    base_end_txt=uicontrol('style','text','units','normalized','position',[0.2 0.18 0.12 0.05],...
        'string','End (s):','fontname','lucinda','fontsize',12,'backgroundcolor',BACKCOLOR,'horizontalalignment','left');
    base_end=uicontrol('style','edit','units','normalized','position',[0.27 0.19 0.05 0.06],...
        'FontSize', 11,'fontname','lucinda', 'BackGroundColor','white','string',baselineEnd,'callback',@baseEnd_callback);
        function baseEnd_callback(src,~)
            baselineEnd=str2double(get(src,'string'));
            updatePlot;
            drawMap(latency);
        end

    plotGFPToggle = uicontrol('style','checkbox','units','normalized','position',[0.03 0.1 0.2 0.05],'value',0,'enable','on',...
        'string','Plot Global Field Power','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@plot_gfp_callback);

    function plot_gfp_callback(src,~)
        val = get(src,'value');
        if val
            plotmode = 1;
        else
            plotmode = 0;
        end
        updatePlot;
        autoScale;
        updatePlot;
    end
        
    plotSingleTrialToggle = uicontrol('style','checkbox','units','normalized','position',[0.03 0.05 0.15 0.05],'value',plotSingleTrials,'enable','off',...
        'string','Plot Single Trials','fontname','lucinda','Foregroundcolor','black','backgroundcolor',BACKCOLOR,'FontSize',12,'callback',@plot_single_callback);

    function plot_single_callback(src,~)
        plotSingleTrials = get(src,'value');
        
        if plotSingleTrials
            plotAllTrials = 1;
            s = sprintf('All Trials');
            set(plotAllTrialsToggle,'value',plotAllTrials);
            
            set(trial_text,'string',s);
            set(plotAllTrialsToggle, 'enable','on');
            set(trial_text, 'enable','on');
        else
            s = sprintf('All Trials');
            set(plotAllTrialsToggle, 'enable','off');
            set(trial_text, 'enable','off');
            set(trialIncArrow, 'enable','off');
            set(trialDecArrow, 'enable','off');
        end
            
        updatePlot;
    end

    annotation('rectangle',[0.02 0.037 0.35 0.44],'EdgeColor',[0.5 0.5 0.5]); %% ADDED BY CECILIA
        
    if useBaseline
        set(base_start_txt, 'enable','on');
        set(base_start, 'enable','on');
        set(base_end_txt, 'enable','on');
        set(base_end, 'enable','on');
    else
        set(base_start_txt, 'enable','of');
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
            mapLocs = getMapLocs(header, plotPlanar);
            mapLocs(excludeChannelList) = [];
            plotSingleTrials = 0;
            set(plotSingleTrialToggle,'value',0);
            set(plotSingleTrialToggle,'enable','off');
            set(plotTFRButton,'enable','off');
            set(plotGFPToggle,'enable','on');
        else
            plotmode = 2;
            selectedchannel = selection - 1;
            loadTrialData(selectedchannel);
            
            set(plotSingleTrialToggle,'enable','on');
            set(plotTFRButton,'enable','on');
            set(plotGFPToggle,'enable','off');
            set(plotGFPToggle,'value',0);
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
        axtest=subplot(2,1,1);
        
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
        axtest=subplot(2,1,1);
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
        
        axtest=subplot(2,1,1);
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

    % update drawing while cursor being dragged
    function updateCursors                 
        if ~isempty(cursorHandle)
            set(cursorHandle, 'XData', [latency latency]);      
        end 
        s = sprintf('Cursor = %.4f s', latency);
        set(latency_text, 'string', s);
    end
        
 
    function buttondown(~,~)         

        ax = gca;
        if ax == mapAxis
%             mapclick = get(ax,'currentpoint');
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

    function drawMap(latency)

        subplot(2,2,4);
             
        mapAxis = gca;
        
        sample = round (latency * fs) + preTrigPts + 1;             
        if sample < 1 || sample > size(data,1)
            return;
        end
        
        % integrate power over window
        if plotRMS
                            
            startSample = sample - round( (rmsWindow/2) * fs);
            endSample = sample + round( (rmsWindow/2) * fs);
            
            if startSample < 1
                fprintf('WARNING: rms window exceeds trial boundaries\n');
                return;            
            end
            if endSample > size(data,1)
                fprintf('WARNING: rms window exceeds trial boundaries\n');
                return;
            end
            
            if integrateOverTrials
                % need RMS amplitude for all channels
                for k=1:size(channelNames,1)
                    s = sprintf('getting map data for channel %s\n',char(channelNames(k,:)));
                    fprintf(s);
                    loadTrialData(k);
                    segData = trialData(:,startSample:endSample);
                    map_data(k) = sqrt(mean(segData(:) .*segData(:) ) );
                                        
                end
                % reload current trial displayed
                loadTrialData(selectedchannel);
            else
                temp_data = data(startSample:endSample,:)';  
                map_data = rms(temp_data,2);
            end 
            
        else
            map_data = data(sample,:)';
            if plotPlanar 
                map_data = abs(map_data);
            end
        end

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
        
        if plotRMS && rmsWindow > 0
            t1 = (latency - rmsWindow/2) * 1000;
            t2 = (latency + rmsWindow/2) * 1000;
            tstr = sprintf('t = %.1f to %.1f ms',t1,t2);
        else
            tstr = sprintf('t = %.1f ms', latency*1000);
        end
        tt = title(tstr);
        set(tt,'Interpreter','none','fontsize',14,'fontweight','bold');

        h = colorbar;

        set(h,'fontsize',14);
        if plotRMS || plotPlanar
            tstr = sprintf('femtoTesla  RMS');
        else
            tstr = sprintf('femtoTesla');
        end
        set(get(h,'YLabel'),'String',tstr);

        global_latency = latency;       % for passing to beamformer

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
