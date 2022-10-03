%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_eventMarker(dsName, channelName)
% GUI to view any channel to mark event latencies and save in text files
%
% Usage eventMarker(dsName, [channelName]);
%
% Input variables:
% dsName :         dataset path
% channelName:     channel name (default - 1st non-MEG channel)
% 
% updated March, 2022 to do conditional combination of markers
% simplified writing and reading of events / markers
% 
% (c) D. Cheyne. All rights reserved.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_eventMarker(dsName, channelName)

versionNo = 4.0;

tStr = sprintf('Event Marker (ver %.1f)', versionNo);

fprintf(tStr);
fprintf('\n(c) D. Cheyne, Hospital for Sick Children\n');

if ~exist(dsName,'file')
    fprintf('Could not find file %s...\n', dsName);
    return;
end

eventList = [];  
currentEvent = 1;
numEvents = 0;

threshold = 0;
maxAmplitude = 0.0;
minAmplitude = 0.0;
minSeparation = 0.0;

peakToThresholdRatio = 2.5;

params = bw_CTFGetHeader(dsName);

if params.numTrials > 1
    fprintf('eventMarker can only be used with single-trial (raw) data...\n');
    return;
end

% set defaults
rectify = false;
envelope = false;
notchFilter = false;
invertData = false;
differentiate = false;

bandPass = [0 50];
minDuration = 0.01;
dc_offset = 0.0;
filterOff = true;

enableMarking = false;
autoThreshold = false;
reverseScan = false;


cursorHandle = 0;
cursorLatency = 0.0;

% conditional marking
showMarkerWindow = 0;
markerWindowStart = -0.1;
markerWindowEnd = 0.1;


% set defaults
% Draw arrows - calls:  uparrow.m and downarrow.m - %%%% ADDED BY CECILIA %%%%
uparrow_im=draw_uparrow;
downarrow_im=draw_downarrow;

isdragging = false;
orange = [0.6,0.25,0.1];


channelList = {params.channel(:).name};

% if no channel name passed take the first channel
currentChannelIndex = 1;
if ~exist('channelName','var')
    for i=1:params.numChannels
        channelName = char( channelList(currentChannelIndex) );
    end
else
    currentChannelIndex = find(strncmp(channelName,channelList,length(channelName)) == 1);
    if isempty(currentChannelIndex)
        fprintf('Could not find channel %s\n', channelName);
    return;
end  


end

timeVec = [];
data = [];

numMarkers = 0;
currentMarkerIndex = 1;
markerNames = {};
markerLatencies = {};

minScale = 0.0;
maxScale = 0.0;

epochStart = params.epochMinTime;
epochTime = 30;

epochSamples = round(epochTime * params.sampleRate);

fprintf('Loading data...\n\n');

markerFileName = strcat(dsName,filesep,'MarkerFile.mrk');

markerNames = {'none'};
if exist(markerFileName,'file')
    fprintf('found marker file %s\n', markerFileName); 
    [names, markerData] = bw_readCTFMarkerFile(markerFileName);
   
    % drop trial numbers for now
    numMarkers = size(names,1);
    fprintf('dataset has %d markers ...\n', numMarkers); 
    if (numMarkers > 0)
        for j = 1:numMarkers
            x = markerData{j}; 
            markerLatencies{j} = x(:,2);
            markerNames{j+1} = names{j};
        end
    end
else
   fprintf('no marker file found...\n'); 
   numMarkers = 0;
end

tStr = sprintf('Event Marker: %s', dsName);

fh = figure('numbertitle','off','position',[200, 800, 1400, 750],...
    'Name',tStr, 'Color','white','menubar','none','WindowButtonUpFcn',@stopdrag,'WindowButtonDownFcn',@buttondown);

if ispc
    movegui(fh, 'center');
end

filemenu=uimenu('label','File');
uimenu(filemenu,'label','Import Events from Text File...','callback',@load_events_callback)
uimenu(filemenu,'label','Import Events from KIT Event File...','callback',@load_KIT_events_callback)
uimenu(filemenu,'label','Write Events to MarkerFile...','separator','on','callback',@save_marker_callback)
uimenu(filemenu,'label','Write Events to Text  File...','callback',@save_events_callback)
uimenu(filemenu,'label','Export Markers to Excel...','separator','on','callback',@save_marker_as_excel_callback)
uimenu(filemenu,'label','Close','accelerator','W','separator','on','callback',@quit_filemenu_callback)

uicontrol('style','text','fontsize',14,'units','normalized','horizontalalignment','left','position',...
     [0.05 0.96 0.08 0.03],'string','Channel:','BackgroundColor','white','foregroundcolor','black');
uicontrol('style','popup','units','normalized','fontsize',12,'position',[0.1 0.9 0.12 0.09],...
    'string',channelList,'value',currentChannelIndex,'Foregroundcolor','black','backgroundcolor','white','callback',@channel_popup_callback);

    function channel_popup_callback(src,~)    
        currentChannelIndex = get(src,'value');
        channelName = char( channelList(currentChannelIndex) );
        loadData;
        
        % new ** reset parameters if changing channels...
        threshold = 0.05 * max(data);       
        maxAmplitude = threshold * 6.0;
        minAmplitude = threshold * 2.0;
        
        set(threshold_edit,'string',threshold);
        set(max_amplitude_edit,'string',maxAmplitude);
        set(min_amplitude_edit,'string',minAmplitude);
        
        drawTrial;
        
    end


uicontrol('style','text','fontsize',14,'units','normalized','horizontalalignment','left','position',...
     [0.23 0.96 0.08 0.03],'string','Marker:','BackgroundColor','white','foregroundcolor','black');
marker_Popup =uicontrol('style','popup','units','normalized','fontsize',12,'position',[0.28 0.9 0.12 0.09],...
    'string',markerNames,'value',currentMarkerIndex,'Foregroundcolor','black','backgroundcolor','white','callback',@marker_popup_callback);

    function marker_popup_callback(src,~)    
        currentMarkerIndex = get(src,'value');
        drawTrial;
    end

    function quit_filemenu_callback(~,~)
        close(fh);
    end

    function defaults_callback(~,~)
        set_EMGDefaults;
    end


uicontrol('style','checkbox','units','normalized','fontsize',12,'position',[0.4 0.955 0.13 0.04],...
    'string','Marker Window','value',0,'Foregroundcolor','black','backgroundcolor','white','callback',@show_window_callback);

    function show_window_callback(src,~)    
        showMarkerWindow = get(src,'value');
        drawTrial;
    end

uicontrol('style','edit','units','normalized','position',[0.51 0.96 0.04 0.035],...
    'FontSize', 11, 'BackGroundColor','white','string',markerWindowStart,'callback',@windowStart_edit_callback);
    function windowStart_edit_callback(src,~)
        markerWindowStart =str2double(get(src,'string'));
        drawTrial;
    end
uicontrol('style','text','fontsize',11,'units','normalized','position',[0.56 0.96 0.02 0.03],...
     'string','to','BackgroundColor','white');
uicontrol('style','edit','units','normalized','position',[0.58 0.96 0.04 0.035],...
    'FontSize', 11, 'BackGroundColor','white','string',markerWindowEnd,'callback',@windowEnd_edit_callback);
    function windowEnd_edit_callback(src,~)
        markerWindowEnd =str2double(get(src,'string'));
        drawTrial;
    end
uicontrol('style','text','fontsize',11,'units','normalized','position',[0.62 0.96 0.05 0.03],...
     'string','seconds','BackgroundColor','white');

cursor_text = uicontrol('style','text','fontsize',11,'units','normalized','position',[0.65 0.96 0.2 0.03],...
     'string','Cursor = 0.0 seconds','BackgroundColor','white','foregroundColor',[0.8,0.4,0.1]);
 
s = sprintf('Number of Events = %d', numEvents);
numEventsTxt = uicontrol('style','text','units','normalized','position',[0.86 0.95 0.12 0.04],...
    'string',s,'fontsize',12,'fontweight','bold','backgroundcolor','white', 'foregroundcolor', 'red','horizontalalignment','left');

annotation('rectangle',[0.05 0.02 0.53 0.3],'EdgeColor','blue');
uicontrol('style','text','fontsize',11,'units','normalized','position',...
     [0.08 0.305 0.1 0.025],'string','Data Parameters','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
annotation('rectangle',[0.6 0.02 0.35 0.3],'EdgeColor','blue');

% event detection controls

uicontrol('style','checkbox','units','normalized','position',[0.62 0.305 0.08 0.025],...
    'string','Mark Events','backgroundcolor','white','foregroundcolor','blue','fontweight','bold',...
    'value',enableMarking,'FontSize',11,'callback',@enable_mark_check_callback);

    function enable_mark_check_callback(src,~)
        enableMarking = get(src,'value');
        
        if enableMarking
            set(threshold_text,'enable','on')
            set(threshold_edit,'enable','on')
            set(min_duration_text,'enable','on')
            set(min_duration_edit,'enable','on')
            set(min_amplitude_edit,'enable','on')
            set(max_amplitude_edit,'enable','on')
            set(min_amp_text,'enable','on')
            set(min_amp_text2,'enable','on')
            set(min_sep_text,'enable','on')
            set(min_sep_edit,'enable','on')
            set(min_sep_text,'enable','on')
            set(auto_check,'enable','on')
            set(reverse_scan_text,'enable','on')
            set(auto_check,'enable','on')
            set(find_events_button,'enable','on')
        else
            set(threshold_text,'enable','off')
            set(threshold_edit,'enable','off')
            set(min_duration_text,'enable','off')
            set(min_duration_edit,'enable','off')
            set(min_amplitude_edit,'enable','off')
            set(max_amplitude_edit,'enable','off')
            set(min_amp_text,'enable','off')
            set(min_amp_text2,'enable','off')
            set(min_sep_text,'enable','off')
            set(min_sep_edit,'enable','off')
            set(min_sep_text,'enable','off')
            set(auto_check,'enable','off')
            set(reverse_scan_text,'enable','off')
            set(auto_check,'enable','off')
            set(find_events_button,'enable','off')
        end
        drawTrial;
        
    end

threshold_text = uicontrol('style','text','units','normalized','position',[0.63 0.235 0.2 0.05],...
    'enable','off','string','Threshold:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
threshold_edit=uicontrol('style','edit','units','normalized','position',[0.71 0.25 0.05 0.05],...
    'enable','off','FontSize', 11, 'BackGroundColor','white','string',threshold,'callback',@threshold_callback);
    function threshold_callback(src,~)
        threshold =str2double(get(src,'string'));
        drawTrial;
    end
min_duration_text = uicontrol('style','text','units','normalized','position',[0.63 0.165 0.12 0.05],...
    'enable','off','string','Min. duration (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
min_duration_edit=uicontrol('style','edit','units','normalized','position',[0.71 0.18 0.05 0.05],...
    'enable','off','FontSize', 11, 'BackGroundColor','white','string',minDuration,...
    'callback',@min_duration_callback);

    function min_duration_callback(src,~)
        minDuration=str2double(get(src,'string'));
    end
min_amplitude_edit=uicontrol('style','edit','units','normalized','position',[0.71 0.11 0.05 0.05],...
    'enable','off','FontSize', 11, 'BackGroundColor','white','string',minAmplitude,...
    'callback',@max_amplitude_callback);

    function max_amplitude_callback(src,~)
        minAmplitude=str2double(get(src,'string'));
        drawTrial;
    end
min_amp_text = uicontrol('style','text','units','normalized','position',[0.63 0.095 0.05 0.05],...
    'enable','off','string','Amplitude Range:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
max_amplitude_edit=uicontrol('style','edit','units','normalized','position',[0.78 0.11 0.05 0.05],...
    'enable','off','FontSize', 11, 'BackGroundColor','white','string',maxAmplitude,...
    'callback',@min_amplitude_callback);
min_amp_text2 = uicontrol('style','text','units','normalized','position',[0.765 0.095 0.01 0.05],...
    'enable','off','string','to','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
    function min_amplitude_callback(src,~)
        maxAmplitude=str2double(get(src,'string'));
        drawTrial;
    end

min_sep_text = uicontrol('style','text','units','normalized','position',[0.63 0.025 0.12 0.05],...
    'enable','off','string','Min. separation (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
min_sep_edit = uicontrol('style','edit','units','normalized','position',[0.71 0.04 0.05 0.05],...
    'enable','off','FontSize', 11, 'BackGroundColor','white','string',minSeparation,...
    'callback',@min_separation_callback);

    function min_separation_callback(src,~)
        minSeparation=str2double(get(src,'string'));
        drawTrial;
    end
auto_check=uicontrol('style','checkbox','units','normalized','position',[0.78 0.25 0.12 0.05],...
    'enable','off','string','3.0 Std.Dev.','backgroundcolor','white','value',autoThreshold,'FontSize',11,'callback',@auto_check_callback);

reverse_scan_text = uicontrol('style','checkbox','units','normalized','position',[0.85 0.1 0.08 0.05],...
    'enable','off','string','reverse scan','backgroundcolor','white','value',reverseScan,'FontSize',11,'callback',@reverse_check_callback);

find_events_button = uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.85 0.04 0.08 0.05],...
    'enable','off','string','Find Events','Foregroundcolor','blue','backgroundcolor','white','callback',@update_callback);


%
uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.5 0.04 0.06 0.05],...
    'string','Plot Epoch','Foregroundcolor','blue','backgroundcolor','white','callback',@plot_callback);

sliderScale = [(epochTime / params.trialDuration) * 0.02 (epochTime / params.trialDuration) * 0.08];

latency_slider = uicontrol('style','slider','units', 'normalized',...
    'position',[0.05 0.43 0.9 0.02],'min',0,'max',1,'Value',0,...
    'sliderStep', sliderScale,'BackGroundColor',[0.8 0.8 0.8],'ForeGroundColor',...
    'white'); 

% this callback is called everytime slider value is changed. 
% therefore replaces slider callback function

addlistener(latency_slider,'Value','PostSet',@slider_moved_callback);

    function slider_moved_callback(~,~)   
       val = get(latency_slider,'Value');
       epochStart = (val * params.trialDuration) - params.epochMinTime;
       if (epochStart + epochTime > params.epochMaxTime)
            epochStart = params.epochMaxTime - epochTime;
       end
       
       if epochStart < params.epochMinTime
           epochStart = params.epochMinTime;
       end
       drawTrial;
    end

% plot controls

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.6 0.35 0.06 0.05],...
    'string','First Event','Foregroundcolor','blue','backgroundcolor','white','callback',@first_event_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.68 0.35 0.06 0.05],...
    'string','Last Event','Foregroundcolor','blue','backgroundcolor','white','callback',@last_event_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.78 0.35 0.09 0.05],...
    'string','Previous Event','Foregroundcolor','blue','backgroundcolor','white','callback',@event_dec_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.88 0.35 0.07 0.05],...
    'string','Next Event','Foregroundcolor','blue','backgroundcolor','white','callback',@event_inc_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.05 0.35 0.07 0.05],...
    'string','Add Event','Foregroundcolor', [0.3 0.6 0],'backgroundcolor','white','callback',@add_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.13 0.35 0.07 0.05],...
    'string','Delete Event','Foregroundcolor','red','backgroundcolor','white','callback',@delete_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.22 0.35 0.07 0.05],...
    'string','Clear Events','Foregroundcolor','black','backgroundcolor','white','callback',@delete_all_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.33 0.35 0.1 0.05],...
    'string','Load Marker Events...','Foregroundcolor','blue','backgroundcolor','white','callback',@load_marker_events_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.45 0.35 0.07 0.05],...
    'string','Filter Events','Foregroundcolor','blue','backgroundcolor','white','callback',@filter_events_callback);

uicontrol('style','checkbox','units','normalized','position',[0.5 0.18 0.06 0.05],...
    'string','Filter','backgroundcolor','white','value',~filterOff,'FontSize',11,'callback',@filter_check_callback);

notch_check=uicontrol('style','checkbox','units','normalized','position',[0.5 0.14 0.06 0.05],...
    'string','60 Hz','backgroundcolor','white','value',notchFilter,'FontSize',11,'callback',@notch_check_callback);

invert_check=uicontrol('style','checkbox','units','normalized','position',[0.4 0.11 0.08 0.05],...
    'string','Invert','backgroundcolor','white','value',invertData,'FontSize',11,'callback',@invert_check_callback);

rectify_check=uicontrol('style','checkbox','units','normalized','position',[0.3 0.11 0.08 0.05],...
    'string','Rectify','backgroundcolor','white','value',rectify,'FontSize',11,'callback',@rectify_check_callback);

diff_check=uicontrol('style','checkbox','units','normalized','position',[0.3 0.04 0.12 0.05],...
    'string','Differentiate','backgroundcolor','white','value',differentiate,'FontSize',11,'callback',@firstDiff_check_callback);

envelope_check=uicontrol('style','checkbox','units','normalized','position',[0.4 0.04 0.08 0.05],...
    'string','Envelope (hilbert)','backgroundcolor','white','value',envelope,'FontSize',11,'callback',@envelope_check_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.49 0.255 0.03 0.04],...
    'CData',uparrow_im,'Foregroundcolor','black','backgroundcolor','white','callback',@scaleUp_callback);

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.53 0.255 0.03 0.04],...
    'CData',downarrow_im,'Foregroundcolor','black','backgroundcolor','white','callback',@scaleDown_callback);


uicontrol('style','text','units','normalized','position',[0.1 0.165 0.2 0.05],...
    'string','High Pass (Hz):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
filt_hi_pass=uicontrol('style','edit','units','normalized','position',[0.2 0.18 0.08 0.05],...
    'FontSize', 11, 'BackGroundColor','white','string',bandPass(1),...
    'callback',@filter_hipass_callback);

    function filter_hipass_callback(src,~)
        bandPass(1)=str2double(get(src,'string'));
        loadData;
        drawTrial;
    end

uicontrol('style','text','units','normalized','position',[0.3 0.165 0.2 0.05],...
    'string','Low Pass (Hz):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
filt_low_pass=uicontrol('style','edit','units','normalized','position',[0.39 0.18 0.08 0.05],...
    'FontSize', 11, 'BackGroundColor','white','string',bandPass(2),...
    'callback',@filter_lowpass_callback);

    function filter_lowpass_callback(src,~)
        bandPass(2)=str2double(get(src,'string'));
        loadData;
        drawTrial;
    end

if filterOff
    set(filt_hi_pass, 'enable','off');
    set(filt_low_pass, 'enable','off');
else
    set(filt_hi_pass, 'enable','on');
    set(filt_low_pass, 'enable','on');
end
uicontrol('style','text','units','normalized','position',[0.1 0.095 0.2 0.05],...
    'string','Epoch Duration (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
uicontrol('style','edit','units','normalized','position',[0.2 0.11 0.08 0.05],...
    'FontSize', 11, 'BackGroundColor','white','string',epochTime,...
    'callback',@epoch_duration_callback);

    function epoch_duration_callback(src,~)
        epochTime =str2double(get(src,'string'));
        epochSamples = round(epochTime * params.sampleRate);
        sliderScale = [(epochTime / params.trialDuration) * 0.02 (epochTime / params.trialDuration) * 0.08];
        set(latency_slider,'sliderStep',sliderScale);
        drawTrial;
    end

uicontrol('style','text','units','normalized','position',[0.1 0.025 0.2 0.05],...
    'string','DC Offset:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
uicontrol('style','edit','units','normalized','position',[0.2 0.04 0.08 0.05],...
    'FontSize', 11, 'BackGroundColor','white','string','0.0',...
    'callback',@dc_offset_callback);

    function dc_offset_callback(src,~)
        dc_offset =str2double(get(src,'string'));
        loadData;
        drawTrial;
    end

uicontrol('style','text','units','normalized','position',[0.1 0.235 0.2 0.05],...
    'string','Scale Maximum:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
max_scale=uicontrol('style','edit','units','normalized','position',[0.2 0.25 0.08 0.05],...
    'FontSize', 11, 'BackGroundColor','white','string',maxScale,...
    'callback',@max_scale_callback);

    function max_scale_callback(src,~)
        maxScale =str2double(get(src,'string'));
        drawTrial;
    end

uicontrol('style','text','units','normalized','position',[0.3 0.235 0.08 0.05],...
    'string','Scale Minimum:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
min_scale=uicontrol('style','edit','units','normalized','position',[0.39 0.25 0.08 0.05],...
    'FontSize', 11, 'BackGroundColor','white','string',minScale,...
    'callback',@min_scale_callback);

    function min_scale_callback(src,~)
        minScale =str2double(get(src,'string'));
        drawTrial;
    end

    function scaleUp_callback(~,~)
        inc = maxScale * 0.1;
        maxScale = maxScale  - inc;
        minScale = minScale + inc;
        set(max_scale,'String', maxScale);
        set(min_scale,'String', minScale);
        drawTrial;
    end

    function scaleDown_callback(~,~)
        inc = maxScale * 0.1;
        maxScale = maxScale  + inc;
        minScale = minScale - inc;
        set(max_scale,'String', maxScale);
        set(min_scale,'String', minScale);
        drawTrial;
    end

    function first_event_callback(~,~)   
        if numEvents < 1
            return;
        end
        currentEvent = 1;
        epochStart = eventList(currentEvent) - (epochTime / 2);
        drawTrial;   
        % adjust slider position
        val = (epochStart + params.epochMinTime) / params.trialDuration;
        if val < 0, val = 0.0; end
        if val > 1.0, val = 1.0; end
        set(latency_slider, 'value', val);
    end

    function last_event_callback(~,~)   
        if numEvents < 1
            return;
        end
        currentEvent = numEvents;
        epochStart = eventList(currentEvent) - (epochTime / 2);
        drawTrial;   
        % adjust slider position
        val = (epochStart + params.epochMinTime) / params.trialDuration;
        if val < 0, val = 0.0; end
        if val > 1.0, val = 1.0; end
        set(latency_slider, 'value', val);
    end

    function event_inc_callback(~,~)  
        if numEvents < 1
            return;
        end
        
        if currentEvent < numEvents
            currentEvent = currentEvent + 1;
            epochStart = eventList(currentEvent) - (epochTime / 2);
            drawTrial;       
            % adjust slider position
            val = (epochStart + params.epochMinTime) / params.trialDuration;
            if val < 0, val = 0.0; end
            if val > 1.0, val = 1.0; end
            set(latency_slider, 'value', val);
        end
    end
    function event_dec_callback(~,~)  
        if numEvents < 1
            return;
        end
        
        if currentEvent > 1
            currentEvent = currentEvent - 1;
            epochStart = eventList(currentEvent) - (epochTime / 2);
            drawTrial;       
            % adjust slider position
            val = (epochStart + params.epochMinTime) / params.trialDuration;
            if val < 0, val = 0.0; end
            if val > 1.0, val = 1.0; end
            set(latency_slider, 'value', val);
        end
    end

    function add_callback(~,~)
        % manually add event
        
        response = questdlg('Add new event at cursor latency?','BrainWave','Yes','No','Yes');
        if strcmp(response,'No')
            return;
        end
        
        latency = cursorLatency;
        if isempty(eventList)
            eventList = latency;
            currentEvent = 1;
        else
            % add to list and resort - idx tells me where the last value
            % moved to in the sorted list
            eventList = [eventList latency];
            [eventList, idx] = sort(eventList);
            currentEvent = find(idx == length(eventList));
        end
        numEvents = length(eventList);
        
        s = sprintf('No. events = %d', numEvents);
        set(numEventsTxt,'String',s);
        
        drawTrial;
    end

    function delete_callback(~,~)
        
       if numEvents < 1
           errordlg('No events to delete ...');
           return;
       end
       % make sure we have currentEvent in window
       if ( eventList(currentEvent) > epochStart & eventList(currentEvent) < (epochStart+epochTime) )        
           s = sprintf('Delete event #%d? (Cannot be undone)', currentEvent);
           response = questdlg(s,'Mark Events','Yes','No','No');
           if strcmp(response,'No')
               return;
           end
           eventList(currentEvent) = [];
           numEvents = length(eventList);         
           drawTrial;
           s = sprintf('Number of events = %d', numEvents);
           set(numEventsTxt,'String',s);
       end
    end

   function delete_all_callback(~,~)
       if numEvents < 1
           fprintf('No events to delete ...\n');
           return;
       end
       
       response = questdlg('Clear all events?','Event Marker','Yes','No','No');
       if strcmp(response','No')
           return;
       end
       
       eventList = [];
       numEvents = 0;
       drawTrial;
       s = sprintf('Number of events = %d', numEvents);
       set(numEventsTxt,'String',s);
   end

    function filter_events_callback(~,~)
        if numEvents < 1
           errordlg('No events defined ...');
           return;
        end
        
        markerTimes = markerLatencies{currentMarkerIndex-1};
         
        wStart = markerWindowStart;
        wEnd = markerWindowEnd;
        
        windowEvents = [];
        for k=1:numEvents  
            latency = eventList(k);
            for j=1:numel(markerTimes)
                wStart = markerTimes(j) + markerWindowStart;               
                wEnd = markerTimes(j) + markerWindowEnd;
                if latency > wStart && latency < wEnd
                    windowEvents(end+1) = k;
                end
            end
        end     
        
       if isempty(windowEvents)
           errordlg('No Events found within Marker Window ...');
           return;
       end
       
       response = questdlg('If event is within Marker window','Event Marker','Include Event','Exclude Event','Cancel','Cancel');

       if strcmp(response,'Include Event')
            s = sprintf('Including %d of %d events...Continue? (Cannot be undone)', numel(windowEvents), numEvents);
            response = questdlg(s,'Event Marker','Yes','No','No');
            if strcmp(response,'Yes')
                eventList = eventList(windowEvents);
            end  
       elseif strcmp(response,'Exclude Event')
            s = sprintf('Excluding %d of %d events...Continue? (Cannot be undone)', numel(windowEvents), numEvents);
            response = questdlg(s,'Event Marker','Yes','No','No');
            if strcmp(response,'Yes')
                eventList(windowEvents) = [];
            end  
       end       
       numEvents = numel(eventList);
       
       s = sprintf('No. events = %d', numEvents);
        set(numEventsTxt,'String',s);
        
        % since event list has changed goto first event
        first_event_callback;
        
        drawTrial;
    end

    function rectify_check_callback(src,~)
        rectify=get(src,'value');
        loadData;
        drawTrial;
    end

    function envelope_check_callback(src,~)
        envelope=get(src,'value');
        loadData;
        drawTrial;
    end

    function invert_check_callback(src,~)
        invertData=get(src,'value');
        loadData;
        drawTrial;
    end


    function firstDiff_check_callback(src,~)
        differentiate=get(src,'value');
        loadData;
        drawTrial;
    end

    function notch_check_callback(src,~)
        notchFilter=get(src,'value');
        loadData;
        drawTrial;
    end

    function filter_check_callback(src,~)
        filterOff=~get(src,'value');
        if filterOff
            set(filt_hi_pass, 'enable','off');
            set(filt_low_pass, 'enable','off');
        else
            set(filt_hi_pass, 'enable','on');
            set(filt_low_pass, 'enable','on');
        end
        
        loadData;
        drawTrial;
    end

    function update_callback(~,~)
        markData;
        drawTrial;
    end

    function auto_check_callback(src,~)
        autoThreshold=get(src,'value');
        
        if autoThreshold
            threshold = 3.0 * mean( std(data) );   
            peakThreshold = peakToThresholdRatio * threshold;
            set(threshold_edit,'String',threshold);
            set(threshold_edit,'enable', 'off');
        else
            set(threshold_edit,'enable', 'on');
        end

        drawTrial;
    end


    function reverse_check_callback(src,~)
        reverseScan=get(src,'value');
    end

    function plot_callback(~,~)
 
        if isempty(eventList)
            return;
        end
        
        % create average
        npts  = epochSamples+1;
        average = zeros(npts, 1);
        
        epochData = zeros(npts, numEvents);
        
        for j=1:numEvents
            startTime = eventList(j) - (epochTime /2.0);       
            
            [~, fd] = getTrial(startTime);        
           
            epochData(1:npts,j) = fd;
            
            average = average + fd;          
        end
        
        timebase = (-epochTime / 2.0:1/params.sampleRate: epochTime / 2.0)';
        plotData(timebase, epochData);
        
    end



    % load (all) data with current filter settings etc and adjust scale
    
    function loadData

        if filterOff
            [timeVec, data] = bw_CTFGetChannelData(dsName, channelName);
        else
            [timeVec, data] = bw_CTFGetChannelData(dsName, channelName, bandPass);
        end
        
        nyquist = params.sampleRate/2.0;
                
        if (notchFilter)
            d = data';
            data = bw_filter(d, params.sampleRate, [58 62], 4, 1, 1)';
            if nyquist > 120 
                d = data';
                data = bw_filter(d, params.sampleRate, [115 125], 4, 1, 1)';
            end
            if nyquist > 180
                d = data';           
                data = bw_filter(d, params.sampleRate, [175 185], 4, 1, 1)';
            end
            data = detrend(data);
        end

        if differentiate
            data = diff(data);
            data = [data; 0.0];  % keep num Samples the same!
        end
                
        if rectify
            data = abs(data);
        end
        
        if envelope
            data = abs(hilbert(data));
        end
        
        if invertData
            data = data * -1.0;
        end
        
        data = data - dc_offset;          
        
        maxScale = max( abs(data) );
        minval = min(data);
        
        % check for channels with all zeros (e.g., Stim channnel)
        if (maxScale == 0 & minval == 0.0)
            maxScale = 1;
        end
        
        minScale = -maxScale;
        
        set(max_scale,'String', maxScale);
        set(min_scale,'String', minScale);
        
    end

    function drawTrial
        
        
        [timebase, fd] = getTrial(epochStart);

        % avoid occasional mismatch - rounding error?
        
        plot(timebase,fd);

        hold on;

        if enableMarking
            samples = size(fd,1);       

            th = ones(samples,1) * threshold';

            plot(timebase, th', 'r:', 'lineWidth',1.5);

            th = ones(samples,1) * minAmplitude';
            plot(timebase, th', 'g:', 'lineWidth',1.5);

            th = ones(samples,1) * maxAmplitude';
            plot(timebase, th', 'c:', 'lineWidth',1.5);
        end
        
        xlim([timebase(1) timebase(end)]);   

        ylim([minScale maxScale]);

        xlabel('Time (sec)', 'fontsize', 12);
        ylabel('Amplitude', 'fontsize', 12);
       
        % check if events exist in this window and draw...      
        if ~isempty(eventList)
            events = find(eventList > epochStart & eventList < (epochStart+epochTime));
            
            if ~isempty(events)
                for i=1:length(events)
                    thisEvent = events(i);
                    t = eventList(thisEvent);
                    h = [t,t];
                    v = ylim;
                    if thisEvent == currentEvent
                        cursor = line(h,v, 'color', 'red','linewidth',1, 'ButtonDownFcn',@startdrag);
                        pos = h;
                        latency = eventList(thisEvent);
                        sample = round( (latency - params.epochMinTime) * params.sampleRate) + 1;
                        x = t + epochTime * 0.005;
                        y =  v(1) + (v(2) - v(1))*0.05;
                        s = sprintf('Event # %d  (latency = %.4f s)', currentEvent, latency);
                        text(x,y,s,'color','red');
                    else
                        line(h,v, 'color', 'black','ButtonDownFcn',@startdrag);
                    end                  
                end
            end
        end
        
       % check if markers exist in this window and draw...     
        if currentMarkerIndex > 1
            markerTimes = markerLatencies{currentMarkerIndex-1};
            markerName = char( markerNames{currentMarkerIndex} );
            markers = find(markerTimes > epochStart & markerTimes < (epochStart+epochTime));
            
            if ~isempty(markers)
                for k=1:length(markers)
                    t = markerTimes(markers(k));
                    h = [t,t];
                    v = ylim;
                    if showMarkerWindow
                        t1 = t + markerWindowStart;
                        t2 = t + markerWindowEnd;
                        xpoints = [t1, t1, t2, t2];
                        ypoints = [v(1), v(2), v(2), v(1)];
                        a = fill(xpoints,ypoints,'green','linestyle','none');
                        a.FaceAlpha = 0.05;
                    end
                      
                    line(h,v, 'color', 'green');
                    x = t + epochTime * 0.001;
                    y =  v(2) - (v(2) - v(1))*0.05;
                    s = sprintf('%s', markerName);
                    text(x,y,s,'color','green','interpreter','none');
                end
            end                         
        end
        
        if enableMarking 
            tt = legend(channelName, 'threshold', 'min. amplitude', 'max. amplitude'); 
        else
            tt = legend(channelName); 
        end
        set(tt,'interpreter','none','Autoupdate','off');
        
      
        ax=axis;
        cursorHandle=line([cursorLatency cursorLatency], [ax(3) ax(4)],'color',[0.8,0.4,0.1]);

        
        hold off;
        
        
    end

    % get processed trial data...
    function [timebase, fd] = getTrial(startTime)
              
        % check trial boundaries
       
        if startTime < params.epochMinTime 
            startTime = params.epochMinTime;
        end 
        
        if startTime + epochTime > params.epochMaxTime
            startTime = params.epochMaxTime-epochTime;
        end
        
        epochStart = startTime;
        
        % get data - note data indices start at 1;
        
        startSample = round( (epochStart - params.epochMinTime) * params.sampleRate) + 1;
        endSample = startSample + epochSamples;
       
        fd = data(startSample:endSample);
        timebase = timeVec(startSample:endSample);
               
    end

    % version 4.0 - new cursor function
    
    function updateCursors                 
        if ~isempty(cursorHandle)
            set(cursorHandle, 'XData', [cursorLatency cursorLatency]);      
        end 
        sample = round( (cursorLatency - params.epochMinTime) * params.sampleRate) + 1;
       
        val = data(sample);
        s = sprintf('Cursor = %.4f s (%.2g)', cursorLatency, val);
        set(cursor_text, 'string', s);

    end
        
    function buttondown(~,~) 
        
        if isempty(cursorHandle)
            return;
        end

        ax = gca;
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
        cursorLatency = mousecoord(1,1);
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
        cursorLatency = mousecoord(1,1);
        updateCursors;
    end

    % on button up event set motion event back to no callback 
    function stopdrag(~,~)
        set(fh,'WindowButtonMotionFcn','');
    end

    %%%%%%%%%%%%%%%%% search for events %%%%%%%%%%%%%%%

    function markData
      
        
        if ~isempty(eventList)
            hadEvents = true;
        else
            hadEvents = false;
        end
        
        eventList = [];
        numEvents = 0;
        
        excludedEvents = 0;
        
        if reverseScan
            fprintf('Searching for events in reverse direction...\n');
            sample = params.numSamples;
            inc = -1;
        else
            fprintf('searching for events...\n');
            sample = 1;
            inc = 1;
        end
        
        while (true)          
            value = data(sample);
            
            % scan until found suprathreshold value
            if value < threshold
                sample = sample + inc;
            else
                % mark event    
                eventSample = sample;
                latency = timeVec(eventSample);             
                includeEvent = true;
                            
                % scan data until value drops below threshold
                % this is the duration of the event. 
                while (value > threshold)
                    sample = sample + inc;
                    if sample >= params.numSamples || sample < 1
                        break;
                    end
                    value = data(sample);
                end  
                
                if sample > params.numSamples || sample < 1
                    break;
                end
                
                if reverseScan
                    eventData = data(sample:eventSample);
                else
                    eventData = data(eventSample:sample);
                end
                
                % *** exclusion critera ***
                
                % check for mininum required duration of the event (time till drops below
                % threshold
                
                eventDuration = (length(eventData) - 1) / params.sampleRate;                
                if eventDuration < minDuration
                    includeEvent = false;
                end                 

                % NEW *** instead of only checking min amplitude (meaning the minimum 
                % amplitude event had to reach to be accepted .. now checks that peak is within
                %  min / max range. 
                % i.e., has to surpass threshold AND reach at least min amplitude but not exceed
                %  max ampltiude.
                
                peak = max( eventData );
                
                % event must not exceed max amplitude
                if peak > maxAmplitude
                    includeEvent = false;
                end
                
                % event must reach min amplitude
                 if peak < minAmplitude
                    includeEvent = false;
                end   
                                
                % check for min. separation.
                
                if length(eventList) > 1
                    previousLatency = eventList(end);
                    separation = abs(latency - previousLatency);
                    
                    if separation < minSeparation
                        includeEvent = false;
                    end             
                end
                
                
                
                % if meets criteria add this event
                if includeEvent
                    if isempty(eventList)
                        eventList = latency;
                    else
                        eventList = [eventList latency];
                    end
                else
                    excludedEvents = excludedEvents + 1;
                end
                
                sample = sample+inc;
                               
            end
            
            if sample > params.numSamples || sample < 1
                break;
            end
        
        end
  
        if isempty(eventList)
            fprintf('No events found...\n');
            numEvents = 0;
        else
        
            if reverseScan
                eventList = sort(eventList);
            end

            % go to first event found
            numEvents = length(eventList);
            if ~hadEvents
                currentEvent = 1;
                epochStart = eventList(currentEvent) - (epochTime / 2.0);
            end
            drawTrial;
            fprintf('Excluded %d event(s)...\n', excludedEvents);   
        end
        
        s = sprintf('Number of events = %d', numEvents);
        set(numEventsTxt,'String',s);
         
    end

   % save latencies
    function load_events_callback(~,~)
        
        [loadlatname, loadlatpath, ~] = uigetfile( ...
            {'*.txt','Text File (*.txt)'}, ...
               'Select Event File', dsName);
        
        loadlatfull=[loadlatpath,loadlatname];
        if isequal(loadlatname,0) 
           return;
        end
  
        new_list =importdata(loadlatfull);
        
        new_list = new_list';
        
        if ~isempty(eventList)          
           response = questdlg('Replace or add to current events?','Event Marker','Replace','Add','Cancel','Replace');
           if strcmp(response','Cancel')
               return;
           end
           if strcmp(response','Replace')
               eventList = new_list;           
           else
               eventList = [eventList new_list];
               eventList = sort(eventList);
           end
        else        
            eventList = new_list;
        end
        
        numEvents = length(eventList);
        
        currentEvent = length(eventList);
        drawTrial;
        
        s = sprintf('Number of events = %d', numEvents);
        set(numEventsTxt,'String',s);
        
    end

    function load_KIT_events_callback(~,~)
        
        [loadlatname, loadlatpath, ~] = uigetfile( ...
            {'*.evt','KIT Event File (*.evt)'}, ...
               'Select Event File', dsName);
        
        loadlatfull=[loadlatpath,loadlatname];
        if isequal(loadlatname,0) 
           return;
        end
  
        [new_list, ~] = bw_readMACCSEventFile ( loadlatfull );
       
        new_list = new_list';
        
        if ~isempty(eventList)          
           response = questdlg('Replace or add to current events?','Event Marker','Replace','Add','Cancel','Replace');
           if strcmp(response','Cancel')
               return;
           end
           if strcmp(response','Replace')
               eventList = new_list;           
           else
               eventList = [eventList new_list];
               eventList = sort(eventList);
           end
        else        
            eventList = new_list;
        end
        
        numEvents = length(eventList);
        
        currentEvent = length(eventList);
        drawTrial;
        
        s = sprintf('Number of events = %d', numEvents);
        set(numEventsTxt,'String',s);
        
    end

    function load_marker_events_callback(~,~)
                  
        if ~exist(markerFileName,'file')
            errordlg('No marker file exists yet. Create or import latencies then save events as markers.');
            return;
        end
        
        [new_list, ~] = bw_readCTFMarkers(markerFileName);       
        new_list = new_list';
        
        if ~isempty(eventList)          
           response = questdlg('Replace or add to current events?','Event Marker','Replace','Add','Cancel','Replace');
           if strcmp(response','Cancel')
               return;
           end
           if strcmp(response,'Replace')
               eventList = new_list;           
           else
               eventList = [eventList new_list];
               eventList = sort(eventList);
           end
        else        
            eventList = new_list;
        end
        
        numEvents = length(eventList);
        
        currentEvent = length(eventList);
        drawTrial;
        
        s = sprintf('Number of events = %d', numEvents);
        set(numEventsTxt,'String',s);
        
        first_event_callback;
        
    end

    % save latencies
    function save_events_callback(~,~)
        if isempty(eventList)
            errordlg('No events defined ...');
            return;
        end
        
        saveName = strcat(dsName, filesep, '*.txt');
        [name,path,~] = uiputfile('*.txt','Save Event latencies in File:',saveName);
        if isequal(name,0)
            return;
        end         
        
        eventFile = fullfile(path,name);
        fprintf('Saving event times to text file %s \n', eventFile);
        
        fid = fopen(eventFile, 'w');
        fprintf(fid,'%.5f\n', eventList');
        fclose(fid);
    end

    % save current events as a marker 
    function save_marker_callback(~,~)
        if isempty(eventList)
            errordlg('No events defined ...');
            return;
        end 
        
        newName = getMarkerName(markerNames);
        
        if isempty(newName)
            return;
        end
            
        if ~isempty( find( strcmp(newName, markerNames) == 1))
            beep;
            warndlg('A Marker with this name already exists for this dataset...');
            return;
        end
        
        % add current event as marker               
        if numMarkers > 0        
            for i=1:numMarkers
                trig(i).ch_name = char(markerNames(i+1));
                markerTimes = markerLatencies{i};                
                trig(i).times = markerTimes;
            end         
        end     
        
        % add to MarkerFile
        trig(numMarkers+1).ch_name = newName;
        trig(numMarkers+1).times = eventList;
        success = write_MarkerFile(dsName, trig);  
        
        % if not cancelled save file 
        if success
            numMarkers = numMarkers + 1;
            % add to list
            markerNames{numMarkers+1} = newName;
            markerLatencies{numMarkers} = eventList;
            set(marker_Popup,'string',markerNames);
        end
        
    end

    % save current marker as ascii event file
    function save_marker_as_excel_callback(~,~)
        
        saveName = strrep(markerFileName,'.mrk','.csv');
        [name,path,~] = uiputfile('*.csv','Export Markers to File:',saveName);
        if isequal(name,0)
            return;
        end         
        
        eventFile = fullfile(path,name);
        fprintf('Saving marker data to csv file %s \n', eventFile);
        
        bw_markerFile2Excel(markerFileName, saveName)
        
    end

% set plot window
ph = subplot('position',[0.05 0.5 0.9 0.45]);

loadData;
threshold = 0.05 * max(data);
maxAmplitude = threshold * 6.0;
minAmplitude = threshold * 2.0;

set(max_amplitude_edit,'string',maxAmplitude);
set(threshold_edit,'string',maxAmplitude);

drawTrial;

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% for stand alone use:
% the following functions are copied from BrainWave 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function plotData(timebase, channelData)

    plotSingle = false;
    
    if isempty(channelData)
        return;
    end
   
    numEpochs = size(channelData,2);
    
    % create average
    average = mean(channelData,2);


    fh = figure('numbertitle','off','position',[400, 1000, 800, 400],'Color','white');
    PLOT_MENU=uimenu('Label','Brainwave');

    uimenu(PLOT_MENU,'label','Save Raw data...','Callback',@save_data_callback);
    PLOT_AVERAGE_MENU = uimenu(PLOT_MENU,'label','Plot Average','separator','on','Callback',@plot_average_callback);
    PLOT_SINGLE_MENU = uimenu(PLOT_MENU,'label','Overlay Single Epochs','Callback',@plot_single_callback);
    set(PLOT_AVERAGE_MENU,'checked','on');
    
    updatePlot;

    
    function plot_average_callback(~, ~)
        plotSingle = false;
        set(PLOT_AVERAGE_MENU,'checked','on');
        set(PLOT_SINGLE_MENU,'checked','off');
        updatePlot;
    end

    function plot_single_callback(~, ~)
        plotSingle = true;
        set(PLOT_AVERAGE_MENU,'checked','off');
        set(PLOT_SINGLE_MENU,'checked','on');
        updatePlot;
    end

    function updatePlot
     
        if plotSingle
            autoScale = max(max( abs(channelData) )) * 1.2;
            s = sprintf('All Epochs (%d events)\n', numEpochs);
            plot(timebase,channelData);
        else
            autoScale = max( abs(average) ) * 1.2;
            s = sprintf('Average (%d events)\n', numEpochs);
            plot(timebase,average);
        end
                
        set(fh, 'Name',s);
        ylim( [-autoScale autoScale]);

        line([0 0], [-autoScale autoScale], 'color', 'black');
        line(xlim, [0 0], 'color', 'black');
        
    end

    function save_data_callback(~,~)     
  
        saveName = sprintf('*.raw');        
        [name,path,~] = uiputfile('*.raw','Save data epochs  in File:',saveName);
        if isequal(name,0)
            return;
        end         
        
        outFile = fullfile(path,name);
        fprintf('Saving epoched data to text file %s \n', outFile);
        
        fid = fopen(outFile,'w');
        fprintf('Saving single trial data in file %s\n', outFile);
        for i=1:size(channelData,1)
            fprintf(fid, '%.6f', timebase(i));  % write time vec as first column
            for k=1:size(channelData,2)
                fprintf(fid, '\t%12g', channelData(i,k) );
            end   
            fprintf(fid,'\n');
        end
        fclose(fid);        
        
    end
end

%%% helper functions...


function [markerName] = getMarkerName(existingNames)
 
    markerName = 'newMarker';

    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Choose Marker Name','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 500 150]);
    

    markerNameEdit = uicontrol('style','edit','units','normalized','HorizontalAlignment','Left',...
        'position',[0.2 0.6 0.6 0.2],'String',markerName,'Backgroundcolor','white','fontsize',12);
                
    % check for duplicate name
    if ~isempty(existingNames)
        
    end      

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.6 0.3 0.25 0.25],'string','OK','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@ok_callback);
    
    function ok_callback(~,~)
        markerName = get(markerNameEdit,'string');
        uiresume(gcf);
    end

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.2 0.3 0.25 0.25],'string','Cancel','backgroundcolor','white',...
        'foregroundcolor','black','callback',@cancel_callback);
    
    function cancel_callback(~,~)
        markerName = [];
        uiresume(gcf);
    end
    
    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
    
    
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_write_MarkerFile(dsName,trig)
%   Writes a markerFile.mrk for the given input 'trig'
%   Returns on error if a markerFile.mrk exists
%   INPUT:
%         dsName = ctf dataset name
%         trig = 1 X N(num of trigs) structure
%                trig(1:N).ch_name 
%                         .onset_idx %sample index of trigger onsets                 
%                         .times     %dataset times of triggers onsets
%
%  pferrari@meadowlandshospital.org, Aug2012
%
% this is a modified version for eventMarker - apply changes to bw_write_MarkerFile?
%
function result = write_MarkerFile(dsName,trig)

result = 0;

no_trigs=numel(trig);

filepath=strcat(dsName, filesep, 'MarkerFile.mrk');
          
fprintf('writing marker file %s\n', filepath);

fid = fopen(filepath,'w','n');
fprintf(fid,'PATH OF DATASET:\n');
fprintf(fid,'%s\n\n\n',dsName);
fprintf(fid,'NUMBER OF MARKERS:\n');
fprintf(fid,'%g\n\n\n',no_trigs);

for i = 1:no_trigs
    
    fprintf(fid,'CLASSGROUPID:\n');
    fprintf(fid,'3\n');
    fprintf(fid,'NAME:\n');
    fprintf(fid,'%s\n',trig(i).ch_name);
    fprintf(fid,'COMMENT:\n\n');
    fprintf(fid,'COLOR:\n');
    fprintf(fid,'blue\n');
    fprintf(fid,'EDITABLE:\n');
    fprintf(fid,'Yes\n');
    fprintf(fid,'CLASSID:\n');
    fprintf(fid,'%g\n',i);
    fprintf(fid,'NUMBER OF SAMPLES:\n');
    fprintf(fid,'%g\n',length(trig(i).times));
    fprintf(fid,'LIST OF SAMPLES:\n');
    fprintf(fid,'TRIAL NUMBER\t\tTIME FROM SYNC POINT (in seconds)\n');
    for t = 1:length(trig(i).times)-1
        fprintf(fid,'                  %+g\t\t\t\t               %+0.6f\n',0,trig(i).times(t));
    end
    fprintf(fid,'                  %+g\t\t\t\t               %+0.6f\n\n\n',0,trig(i).times(end));
end

fclose(fid);

result = 1;

end



