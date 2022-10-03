function bw_single_subject_analysis
%   function bw_single_subject_analysis
%
%   DESCRIPTION: Creates the BrainWave's main params.gui. It has an optional 
%   structure input called settings can be loaded from a saved .mat which 
%   sets the gui to the settings and options specified by the file.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%
%   --VERSION 0.34beta --
%
% first official "release" version
% made several changes to main window and functionality, added Help menu
% D. Cheyne, Sept, 2010
%
%
%   --VERSION 1.1--
% Revised D. Cheyne 
% replaced hardcoded file separators with filesep function 
%
% Last Revised on 08/07/2010
% Major Changes: Now only display .mri files in the mri selection box and
% .ds in the dataset selection box.
%
% Revised by N.v.L. on 07/07/2010
% Major Changes: Moved things around, created a new button that can grab
% the last selected peak coordinates from bw_mip_plot_4D, have the
% selected mri file actually passing somewhere,etc.
%
% Revised by N.v.L. on 06/07/2010
% Major Changes: Rename buttons, moved buttons around, split plot vs into
% two set of buttons, etc.
%
% Revised by N.v.L. on 23/06/2010
% Major Changes: Created the help file.
%
% Written by N.v.L. on 19/06/2010 for the Hospital for Sick Children.
%
%
%   June, 2012 Version 2.0 
%        ** this is old version of bw_start.m which is now a separate module renamed
%        bw_single_subject_analysis, group analysis moved to another module
%
%
global SPM_VERSION;
global global_voxel
global global_latency

scrnsizes=get(0,'MonitorPosition');

screenWidth = 1400;
screenHeight = 950;
screenX = round(scrnsizes(1,3) * 0.05);
screenY = 40;  %round(scrnsizes(1,4) * 0.5);

% Initialize Variables
ds_filename='';
full_ds_filename='';

global_voxel = [];
global_latency = [];


% initialize data variables (no longer in settings file)
workspace1='';
ds_title='No dataset selected...';
ds_info='';

covDsName = '';
useCovDs = 0;
useFullEpoch = 1;
usePreStim = 1;

dsParams = [];
covDsParams = []; % if different covariance need to check cov window....

% initialize parameters (new version)
params = bw_checkPrefs;
 
normalize_images = 0;

selected_surface = 1;
meshFile = [];
meshNames = [];
meshes = [];

f=figure('Name', 'BrainWave - Single Subject Analysis', 'Position', [screenX screenY screenWidth screenHeight],...
            'menubar','none','numbertitle','off', 'Color','white', 'CloseRequestFcn',@QUIT_MENU_CALLBACK);

% workspace controls
if ispc
    movegui(f,'center');
end

button_orange = [0.8,0.4,0.1];

uicontrol('style','text','fontsize',11,'units','normalized','position',...
    [0.03 0.965 0.1 0.025],'string','Data Selection','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
annotation('rectangle',[0.02 0.54 0.6 0.44],'EdgeColor','blue');

WORKSPACE_TEXT_TITLE = uicontrol('Style','Text','Units','Normalized','Position',...
        [0.05 0.91 0.35 0.06],'String','Data Directory:','HorizontalAlignment','left',...
        'BackgroundColor','White', 'enable','off');
    
DS_LISTBOX=uicontrol('Style','Listbox','enable','off','fontName','lucinda','fontSize',10,'Units','Normalized','Position',...
    [0.05 0.75 0.34 0.16],'String',ds_filename,'HorizontalAlignment','Center','BackgroundColor',...
    'White','Callback',@DS_LISTBOX_CALLBACK);

COV_DS_LISTBOX=uicontrol('Style','Listbox','enable','off','fontName','lucinda','fontSize',10,'Units','Normalized','Position',...
    [0.05 0.55 0.34 0.16],'String',ds_filename,'HorizontalAlignment','Center','BackgroundColor',...
    'White','Callback',@COV_DS_LISTBOX_CALLBACK);

SET_WORKSPACE_BUTTON = uicontrol('Style','PushButton','enable','on','FontSize',10,'Units','Normalized','Position',...
    [0.049 0.92 0.06 0.02],'String','Change Dir','HorizontalAlignment','Left',...
    'foregroundcolor','blue','Callback',@WORKSPACE_BUTTON_CALLBACK);

REFRESH_DS_BUTTON = uicontrol('Style','PushButton','enable','on','FontSize',10,'Units','Normalized','Position',...
    [0.12 0.92 0.05 0.02],'String','Refresh','HorizontalAlignment','Left',...
    'foregroundcolor','blue','Callback',@REFRESH_DS_CALLBACK);

COMBINE_DS_BUTTON = uicontrol('Style','PushButton','enable','on','FontSize',10,'Units','Normalized','Position',...
    [0.2 0.92 0.08 0.02],'String','Combine Datasets','HorizontalAlignment','Left',...
    'foregroundcolor','blue','Callback',@COMBINE_DS_BUTTON_CALLBACK);

COPY_HEADMODEL_BUTTON = uicontrol('Style','PushButton','enable','on','FontSize',10,'Units','Normalized','Position',...
    [0.3 0.92 0.08 0.02],'String','Copy Head Models','HorizontalAlignment','Left',...
    'foregroundcolor','blue','Callback',@COPY_HEADMODEL_BUTTON_CALLBACK);

% dataset name
DATASET_TEXT_TITLE = uicontrol('style','text','Units','Normalized','Position',...
    [0.4 0.85 0.22 0.06],'String',ds_title,'BackgroundColor','White','HorizontalAlignment','left');

DATASET_INFO_TEXT=uicontrol('style','text','Units','Normalized','Position',...
    [0.4 0.75 0.22 0.12],'String',ds_info,'BackgroundColor','White','HorizontalAlignment','left');

PLOT_DATA_BUTTON=uicontrol('Style','PushButton','FontSize',10,'Units','Normalized','Position',...
    [0.4 0.75 0.1 0.03], 'String','Plot Data','HorizontalAlignment','Center',...
    'ForegroundColor','blue','Callback',@PLOT_DATA_BUTTON_CALLBACK);

% generate buttons 
PLOT_BEAMFORMER_BUTTON=uicontrol('Style','PushButton','FontSize',12,'Units','Normalized','Position',...
    [0.78 0.1 0.18 0.07],'String','Generate Images','HorizontalAlignment','Center',...
    'ForegroundColor',button_orange,'Callback',@PLOT_BEAMFORMER_BUTTON_CALLBACK);

LATENCY_EDIT_BUTTON=uicontrol('Style','PushButton','FontSize',10,'Units','Normalized','ForegroundColor','blue','Position',...
    [0.48 0.43 0.04 0.03],'String','Load','enable','off','Callback',@LATENCY_EDIT_CALLBACK);

if isunix && ~ismac
    set(PLOT_DATA_BUTTON,'BackGroundColor','white');
    set(SET_WORKSPACE_BUTTON,'BackGroundColor','white');
    set(REFRESH_DS_BUTTON,'BackGroundColor','white');
    set(COMBINE_DS_BUTTON,'BackGroundColor','white');
    set(COPY_HEADMODEL_BUTTON,'BackGroundColor','white');
    set(PLOT_BEAMFORMER_BUTTON,'BackGroundColor','white');
    set(LATENCY_EDIT_BUTTON,'BackGroundColor','white');
end

% ERB controls
uicontrol('style','text','fontsize',11,'units','normalized','position',...
    [0.03 0.51 0.15 0.02],'string','Latency / Time Windows','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
annotation('rectangle',[0.02 0.25 0.6 0.27],'EdgeColor','blue');

uicontrol('Style','Text','FontSize',12,'Units','Normalized','Position',...
    [0.04 0.46 0.06 0.025],'String','ERB','FontWeight','b','Background','White','horizontalAlignment','left');

RADIO_RANGE=uicontrol('style','radiobutton','units','normalized','position',[0.08 0.46 0.12 0.03],...
    'string','Latency Range (s)','backgroundcolor','white','value',0,'callback',@RADIO_RANGE_CALLBACK);
LAT_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','HorizontalAlignment','left','Position',...
    [0.19 0.465 0.06 0.02],'String','Start:','BackgroundColor','White');
LAT_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','HorizontalAlignment','left','Position',...
    [0.28 0.465 0.06 0.02],'String','End:','BackgroundColor','White');
LAT_STEPSIZE_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','HorizontalAlignment','left','Position',...
    [0.37 0.465 0.06 0.02],'String','Step:','BackgroundColor','White');


RADIO_LIST=uicontrol('style','radiobutton','units','normalized','position',[0.46 0.46 0.08 0.03],...
    'string','Latency List ','backgroundcolor','white','value',0,'callback',@RADIO_LIST_CALLBACK);
LATENCY_LIST=uicontrol('Style','edit','FontSize',10,'Units','Normalized','Min',1,'Max',10000,'enable','off','Position',...
    [0.53 0.42 0.08 0.07],'String',{params.beamformer_parameters.beam.latencyList},'HorizontalAlignment','left',...
    'BackgroundColor','White', 'Callback',@latencyListCallback);
    function LATENCY_EDIT_CALLBACK(~,~)
    
        [filename, pathname, idx]=uigetfile({'*.txt','Text file (*.txt)';'*.mrk','Marker File (*.mrk)';},...
            'Select  file containing latencies', full_ds_filename);
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        
        file = fullfile(pathname,filename);
        
        if idx == 1
            list = bw_read_list_file(file);
        elseif idx == 2          
            [list, ~] = bw_readCTFMarkers(file);
        end
        
        tlist = get(LATENCY_LIST,'String');
        if ~isempty (tlist)
            r = questdlg('Add to current list or replace?','BrainWave','Add to List','Replace','Add to List');
            if strcmp(r,'Replace')
                tlist = [];
            end
        end
        latencyList = [tlist; list];
        
        if ~isempty(latencyList)
            set(LATENCY_LIST,'string',latencyList);
        end
                
    end
    % update list if numbers entered manually
    function latencyListCallback(~,~)

        tlist = get(LATENCY_LIST,'String');
        if ~isempty (tlist)
            latencies=cellfun(@str2num,tlist);
            params.beamformer_parameters.beam.latencyList = latencies';
        end
    end

PLOT_BEAMFORMER_START_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.22 0.455 0.05 0.04],'String',params.beamformer_parameters.beam.latencyStart,'BackgroundColor','White','Callback',...
    @PLOT_BEAMFORMER_START_LAT_EDIT_CALLBACK);
PLOT_BEAMFORMER_END_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.31 0.455 0.05 0.04],'String',params.beamformer_parameters.beam.latencyEnd,'BackgroundColor','White','Callback',...
    @PLOT_BEAMFORMER_END_LAT_EDIT_CALLBACK);
PLOT_BEAMFORMER_STEP_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.4 0.455 0.05 0.04],'String',params.beamformer_parameters.beam.step,'BackgroundColor',...
    'White','Callback',@PLOT_BEAMFORMER_STEP_LAT_EDIT_CALLBACK);
% COMPUTE_MEAN_CHECK=uicontrol('style','check', 'units', 'normalized','position',[0.48 0.45 0.1 0.05],...
%         'Background','white','String','compute mean','FontSize', 11,'Value', params.beamformer_parameters.mean,'callback',@mean_check_callback);
%     function mean_check_callback(src,~)
%        params.beamformer_parameters.mean=get(src,'Value');
%     end

COV_DS_CHECK=uicontrol('Style','checkbox','FontSize',12,'Units','Normalized','Position',...
    [0.05 0.71 0.18 0.04],'String','Select Covariance Dataset','HorizontalAlignment','Center',...
    'BackgroundColor','White','value',useCovDs,'Callback',@COV_DS_CHECK_CALLBACK);

    function COV_DS_CHECK_CALLBACK(src,~)
       useCovDs = get(src,'value');
       init_ds_params(full_ds_filename);
       update_fields;
    end

MULTI_DS_SAM_CHECK=uicontrol('Style','checkbox','FontSize',12,'Units','Normalized','Position',...
    [0.2 0.71 0.18 0.04],'String','Select SAM Baseline Dataset','HorizontalAlignment','Center',...
    'BackgroundColor','White','value',params.beamformer_parameters.multiDsSAM,'Callback',@MULTI_DS_SAM_CALLBACK);
    
    function MULTI_DS_SAM_CALLBACK(src,~)
       params.beamformer_parameters.multiDsSAM = get(src,'value');
       init_ds_params(full_ds_filename);
       update_fields;
    end
    
% SAM controls 

uicontrol('Style','Text','FontSize',12,'Units','Normalized','Position',...
    [0.04 0.37 0.06 0.025],'String','SAM','FontWeight','b','Background','White','horizontalAlignment','left');
RADIO_Z=uicontrol('style','radiobutton','units','normalized','position',[0.08 0.37 0.1 0.03],...
    'string','Pseudo-Z','backgroundcolor','white','value',0,'callback',@RADIO_Z_CALLBACK);
RADIO_T=uicontrol('style','radiobutton','units','normalized','position',[0.08 0.31 0.1 0.03],...
    'string','Pseudo-T','backgroundcolor','white','value',0,'callback',@RADIO_T_CALLBACK);
RADIO_F=uicontrol('style','radiobutton','units','normalized','position',[0.08 0.27 0.1 0.03],...
    'string','Pseudo-F','backgroundcolor','white','value',0,'callback',@RADIO_F_CALLBACK);


ACTIVE_WINDOW_LABEL = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.17 0.41 0.15 0.025],'String','Active Window (s):','Background','White','HorizontalAlignment','Left');
ACTIVE_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','HorizontalAlignment','Left','Position',...
    [0.17 0.37 0.05 0.02],'String','Start:','BackgroundColor','White');
ACTIVE_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','HorizontalAlignment','Left','Position',...
    [0.27 0.37 0.04 0.02],'String','End:','BackgroundColor','White');
ACTIVE_STEPSIZE_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','HorizontalAlignment','Left','Position',...
    [0.37 0.37 0.08 0.02],'String','Step Size:','BackgroundColor','White');
ACTIVE_NO_STEP_LABEL=uicontrol('style','text','fontsize',10,'units','normalized','HorizontalAlignment','Left','position',...
    [0.47 0.37 0.08 0.02],'string','No. Steps:','backgroundcolor','white');


ACTIVE_START_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.2 0.36 0.05 0.04],'String',params.beamformer_parameters.beam.activeStart,'BackgroundColor','White','Callback',@ACTIVE_START_EDIT_CALLBACK);
ACTIVE_END_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.3 0.36 0.05 0.04],'String',params.beamformer_parameters.beam.activeEnd,'BackgroundColor','White','Callback',@ACTIVE_END_EDIT_CALLBACK);
ACTIVE_STEP_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.41 0.36 0.05 0.04],'String',params.beamformer_parameters.beam.active_step,'BackgroundColor',...
    'White','Callback',@ACTIVE_STEP_LAT_EDIT_CALLBACK);
ACTIVE_NO_STEP_EDIT=uicontrol('style','edit','fontsize',10,'units','normalized','position',...
    [0.51 0.36 0.05 0.04],'string',params.beamformer_parameters.beam.no_step,'Backgroundcolor','white','callback',@ACTIVE_NO_STEP_EDIT_CALLBACK);


BASELINE_WINDOW_LABEL = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.17 0.32 0.18 0.025],'String','Baseline Window (s):','Background','White','HorizontalAlignment','Left');
BASELINE_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','HorizontalAlignment','Left','Position',...
    [0.17 0.28 0.05 0.02],'String','Start:','BackgroundColor','White');
BASELINE_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','HorizontalAlignment','Left','Position',...
    [0.27 0.28 0.04 0.02],'String','End:','BackgroundColor','White');

BASELINE_START_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.2 0.27 0.05 0.04],'String',params.beamformer_parameters.beam.baselineStart,'BackgroundColor',...
    'White','Callback',@BASELINE_START_EDIT_CALLBACK);
BASELINE_END_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.3 0.27 0.05 0.04],'String',params.beamformer_parameters.beam.baselineEnd,'BackgroundColor',...
    'White','Callback',@BASELINE_END_EDIT_CALLBACK);

% Image type fields

uicontrol('style','text','fontsize',11,'units','normalized','position',...
    [0.03 0.21 0.1 0.02],'string','Image Type','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
annotation('rectangle',[0.02 0.03 0.6 0.19],'EdgeColor','blue');

VOLUME_RADIO=uicontrol('Style','radiobutton','FontSize',10,'Units','Normalized','Position',...
    [0.05 0.15 0.08 0.04],'String','Volume','HorizontalAlignment','Center',...
    'BackgroundColor','White','value',~params.beamformer_parameters.useVoxFile,'Callback',@VOLUME_RADIO_CALLBACK);

MEG_RADIO=uicontrol('Style','radiobutton','FontSize',10,'Units','Normalized','Position',...
    [0.14 0.15 0.17 0.04],'String','MEG Coordinates','HorizontalAlignment','Center',...
    'BackgroundColor','White','value',~normalize_images,'Callback',@MEG_RADIO_CALLBACK);

SPM_RADIO=uicontrol('Style','radiobutton','FontSize',10,'Units','Normalized','Position',...
    [0.14 0.11 0.17 0.04],'String','MNI Coordinates','HorizontalAlignment','Center',...
    'BackgroundColor','White','value',normalize_images,'Callback',@SPM_RADIO_CALLBACK);

SURFACE_RADIO=uicontrol('Style','radiobutton','FontSize',10,'Units','Normalized','Position',...
    [0.05 0.05 0.08 0.04],'String','Surface','HorizontalAlignment','Center',...
    'BackgroundColor','White','value',params.beamformer_parameters.useVoxFile,'Callback',@SURFACE_RADIO_CALLBACK);
  
SURFACE_FILE_EDIT=uicontrol('style','edit','units','normalized','position', [0.13 0.05 0.15 0.04],...
        'String', params.beamformer_parameters.surfaceFile, 'FontSize', 10, 'BackGroundColor','white');

SURFACE_MENU = uicontrol('style','popup','units','normalized','position', [0.3 0.04 0.1 0.04],...
        'string','none','FontSize', 12,'callback',@surface_menu_callback);

SURFACE_FILE_BUTTON=uicontrol('style','pushbutton','units','normalized','position', [0.41 0.05 0.1 0.04],...
        'string', 'Load Surface...', 'FontSize', 12,'ForeGroundColor','blue','callback',@surface_file_button_callback);

    
IMAGE_OPTIONS_BUTTON=uicontrol('Style','PushButton','FontSize',10,'Units','Normalized','Position',...
    [0.46 0.14 0.12 0.05],'String','Image Options...','HorizontalAlignment','Center',...
    'Callback',@IMAGE_OPTIONS_BUTTON_CALLBACK);
    
    
% check valid initial states
if params.beamformer_parameters.useVoxFile
    set(SURFACE_FILE_EDIT, 'enable','on');
    set(SURFACE_MENU, 'enable','on');
    set(SURFACE_FILE_BUTTON, 'enable','on');
    set(MEG_RADIO,'enable','off');
    set(SPM_RADIO, 'enable','off');
              
else
    set(SURFACE_FILE_EDIT, 'enable','off');
    set(SURFACE_MENU, 'enable','off');
    set(SURFACE_FILE_BUTTON, 'enable','off');
    set(MEG_RADIO,'enable','on');
    set(SPM_RADIO, 'enable','on');  
end

if SPM_VERSION == 0
    set(MEG_RADIO,'value',1);
    set(SPM_RADIO, 'enable','off');  
end

if strcmp(params.beamformer_parameters.beam.use,'ERB') 
    set(RADIO_RANGE,'value',1);
elseif strcmp(params.beamformer_parameters.beam.use,'ERB_LIST')
    set(RADIO_LIST,'value',1);
elseif strcmp(params.beamformer_parameters.beam.use,'T')
    set(RADIO_T,'value',1);
elseif strcmp(params.beamformer_parameters.beam.use,'F')
    set(RADIO_F,'value',1);
end


uicontrol('style','text','fontsize',11,'units','normalized','position',...
    [0.65 0.965 0.18 0.025],'string','Beamformer Parameters','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
annotation('rectangle',[0.64 0.25 0.35 0.73],'EdgeColor','blue');

uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.92 0.25 0.04],...
        'String','Beamformer Type:','FontSize',12,'FontWeight','bold','BackGroundColor','white');

SCALAR_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.65 0.89 0.15 0.04],...
    'value',~params.beamformer_parameters.rms,'string','Scalar','fontsize',12,'backgroundcolor','white','callback',@scalar_radio_callback);

VECTOR_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.72 0.89 0.15 0.04],...
    'value',params.beamformer_parameters.rms,'string','Vector (LCMV)','fontsize',12,'backgroundcolor','white','callback',@vector_radio_callback);

    function scalar_radio_callback(src,~)
        set(src,'value',1);
        set(VECTOR_RADIO,'value',0);
        params.beamformer_parameters.rms = 0;
    end

    function vector_radio_callback(src,~)
        set(src,'value',1);
        set(SCALAR_RADIO,'value',0);
        params.beamformer_parameters.rms = 1;  
    end

% filter settings
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.825 0.2 0.04],...
        'String','Filter Bandpass (Hz):','FontSize',12,'FontWeight','bold','BackGroundColor','white');
    
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.78 0.1 0.04],...
        'String','Highpass:','FontSize',12,'BackGroundColor','white');

FILTER_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.72 0.79 0.04 0.04],...
        'String', params.beamformer_parameters.filter(1), 'FontSize', 12, 'BackGroundColor','white','callback',@filter_edit_min_callback);
    function filter_edit_min_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.filter(1) = 1;
            set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
            params.beamformer_parameters.filter(2) = 50;
            set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
        else
        params.beamformer_parameters.filter(1)=str2double(string_value);
        if params.beamformer_parameters.filter(1) < 0
            params.beamformer_parameters.filter(1) = 0;
        end
        if params.beamformer_parameters.filter(1) > dsParams.sampleRate / 2.0
            params.beamformer_parameters.filter(1)=dsParams.sampleRate / 2.0;
        end
            set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1))
        end
    end

uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.78 0.78 0.1 0.04],...
        'String','Lowpass:','FontSize',12,'BackGroundColor','white');

FILTER_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.85 0.79 0.04 0.04],...
        'String',params.beamformer_parameters.filter(2), 'FontSize', 12, 'BackGroundColor','white','callback',@filter_edit_max_callback);
    function filter_edit_max_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.filter(2)=50;
            set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
            params.filter(1)=1;
            set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
        else
        params.beamformer_parameters.filter(2)=str2double(string_value);
        if params.beamformer_parameters.filter(2) > dsParams.sampleRate / 2
            params.beamformer_parameters.filter(2) = dsParams.sampleRate / 2;
        end
        if params.beamformer_parameters.filter(2) < 0
            params.beamformer_parameters.filter(2)=0;
        end
            set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2))
        end
    end

REVERSE_CHECK = uicontrol('style','checkbox','units','normalized','position',[0.91 0.79 0.07 0.04],...
        'String','zero phase','BackGroundColor','white','FontSize',12,'Value',...
        params.beamformer_parameters.useReverseFilter,'callback',@reverse_check_callback);
 
    function reverse_check_callback(src,~)
        params.beamformer_parameters.useReverseFilter=get(src,'Value');
    end

% set initial state
set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1))
set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2))
set(REVERSE_CHECK,'value',params.beamformer_parameters.useReverseFilter)
 

% baseline window 
BASELINE_CORRECT_CHECK = uicontrol('style','checkbox','units','normalized','position',[0.65 0.74 0.18 0.04],...
        'String','Remove Offset (s)','BackGroundColor','white','FontSize',12,...
        'Value',params.beamformer_parameters.useBaselineWindow,'callback',@baseline_check_callback);
 
BASELINE_LABEL_MIN=uicontrol('style','text','units','normalized','position',[0.65 0.69 0.1 0.04],...
        'String','Start:','FontSize',12,'BackGroundColor','white','HorizontalAlignment','left');

BASELINE_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.68 0.7 0.05 0.04],...
        'String', params.beamformer_parameters.baseline(1), 'FontSize', 12, 'BackGroundColor','white','callback',@baseline_edit_min_callback);
    
    function baseline_edit_min_callback(src,~)
        string_value=get(src,'String');          
        params.beamformer_parameters.baseline(1) = str2double(string_value);
        if params.beamformer_parameters.baseline(1) < dsParams.epochMinTime || params.beamformer_parameters.baseline(1) > dsParams.epochMaxTime
            params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
            set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
        end   
    end

BASELINE_LABEL_MAX=uicontrol('style','text','units','normalized','position',[0.75 0.69 0.1 0.04],...
        'String','End:','FontSize',12,'BackGroundColor','white','HorizontalAlignment','left');
BASELINE_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.78 0.7 0.05 0.04],...
        'String', params.beamformer_parameters.baseline(2), 'FontSize', 12, 'BackGroundColor','white','callback',@baseline_edit_max_callback);
    function baseline_edit_max_callback(src,~)
        string_value=get(src,'String');          
        params.beamformer_parameters.baseline(2)=str2double(string_value);
        if params.beamformer_parameters.baseline(2) < dsParams.epochMinTime || params.beamformer_parameters.baseline(2) > dsParams.epochMaxTime
            params.beamformer_parameters.baseline(2) = dsParams.epochMaxTime;
            set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))
        end   
    end

BASELINE_SET_FULL_BUTTON=uicontrol('style','checkbox','units','normalized','position', [0.85 0.7 0.1 0.04],...
        'BackGroundColor','white','string', 'Use pre-stim', 'FontSize', 12, 'value',usePreStim, 'callback',@baseline_set_full_callback);

     function baseline_set_full_callback(src,~)
        usePreStim = get(src,'value');       
        params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
        params.beamformer_parameters.baseline(2) = 0.0;
        set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
        set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))    
     end        

    function baseline_check_callback(src,~)
        val=get(src,'Value');
        if (val)
           params.beamformer_parameters.useBaselineWindow = 1;
           set(BASELINE_SET_FULL_BUTTON,'enable','on')
           set(BASELINE_EDIT_MAX,'enable','on')
           set(BASELINE_EDIT_MIN,'enable','on')
           set(BASELINE_LABEL_MIN,'enable','on')
           set(BASELINE_LABEL_MAX,'enable','on')
           if params.beamformer_parameters.baseline(1) < dsParams.epochMinTime || params.beamformer_parameters.baseline(1) > dsParams.epochMaxTime
                params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
           end
           if params.beamformer_parameters.baseline(2) < dsParams.epochMinTime || params.beamformer_parameters.baseline(2) > dsParams.epochMaxTime
                params.beamformer_parameters.baseline(2) = 0.0;
           end     	    
           set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
           set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))
        else
            params.beamformer_parameters.useBaselineWindow = 0;     
            set(BASELINE_SET_FULL_BUTTON,'enable','off')
            set(BASELINE_EDIT_MIN,'enable','off')
            set(BASELINE_EDIT_MAX,'enable','off')
            set(BASELINE_LABEL_MIN,'enable','off')
            set(BASELINE_LABEL_MAX,'enable','off')
        end
    end

% set initial state
set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))
if params.beamformer_parameters.useBaselineWindow == 1
    set(BASELINE_SET_FULL_BUTTON,'enable','on')
    set(BASELINE_EDIT_MIN,'enable','on')
    set(BASELINE_EDIT_MAX,'enable','on')
    set(BASELINE_LABEL_MIN,'enable','on')
    set(BASELINE_LABEL_MAX,'enable','on')

else
    set(BASELINE_SET_FULL_BUTTON,'enable','off')
    set(BASELINE_EDIT_MIN,'enable','off')
    set(BASELINE_EDIT_MAX,'enable','off')
    set(BASELINE_LABEL_MIN,'enable','off')
    set(BASELINE_LABEL_MAX,'enable','off')
end


% data Parameters


uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.61 0.2 0.04],...
        'String','Covariance Window (s):','FontSize',12,'FontWeight','bold','BackGroundColor','white');

COV_LABEL_MIN = uicontrol('style','text','units','normalized','position',[0.65 0.56 0.1 0.04],'horizontalAlignment','left',...
    'String','Start:','FontSize',12,'BackGroundColor','white');

COV_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.68 0.57 0.05 0.04],...
    'String', params.beamformer_parameters.covWindow(1), 'FontSize', 12, 'BackGroundColor','white','callback',@cov_edit_min_callback);

COV_LABEL_MAX = uicontrol('style','text','units','normalized','position',[0.75 0.56 0.1 0.04],'horizontalAlignment','left',...
    'String','End:','FontSize',12,'BackGroundColor','white');

COV_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.78 0.57 0.05 0.04],...
    'String', params.beamformer_parameters.covWindow(2), 'FontSize', 12, 'BackGroundColor','white','callback',@cov_edit_max_callback);

COV_USE_FULL_CHECK = uicontrol('style','checkbox','units','normalized','position', [0.85 0.56 0.1 0.06],...
        'string', 'Use whole epoch', 'FontSize', 12,'value',useFullEpoch, ...
        'BackGroundColor','white','callback',@cov_set_full_callback);
    
    function cov_edit_min_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1));
            params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2));
        else
            params.beamformer_parameters.covWindow(1)=str2double(string_value);
            if params.beamformer_parameters.covWindow(1) > covDsParams.epochMaxTime
                params.beamformer_parameters.covWindow(1) = covDsParams.epochMaxTime;
            end
            if params.beamformer_parameters.covWindow(1) < covDsParams.epochMinTime
                params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
            end
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1))
        end
    end

  
    function cov_edit_max_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1));
            params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2));
        else
            params.beamformer_parameters.covWindow(2)=str2double(string_value);
            if params.beamformer_parameters.covWindow(2) > covDsParams.epochMaxTime
                params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
            end
            if params.beamformer_parameters.covWindow(2) < covDsParams.epochMinTime
                params.beamformer_parameters.covWindow(2) = covDsParams.epochMinTime;
            end
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2))
        end
    end


     function cov_set_full_callback(src,~)
        useFullEpoch = get(src,'value');
        if useFullEpoch
            params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
            params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
            set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1))
            set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2))    
            set(COV_EDIT_MIN,'enable', 'off');
            set(COV_EDIT_MAX,'enable', 'off');            
        else
            set(COV_EDIT_MIN,'enable', 'on');
            set(COV_EDIT_MAX,'enable', 'on');                        
        end
     end        

    
% note params.regulalarization holds the power (in Telsa squared) to add to diagonal    
reg_fT = sqrt(params.beamformer_parameters.regularization) * 1e15;  %% convert to fT  RMS for edit box

uicontrol('style','checkbox','units','normalized','position',[0.65 0.51 0.25 0.04],'String','Apply diagonal regularization:',...
        'BackGroundColor','white','FontSize',12,'fontname','lucinda','Value',params.beamformer_parameters.useRegularization,'callback',@reg_check_callback);
    function reg_check_callback(src,~)
        val=get(src,'Value');
        if (val)
            params.beamformer_parameters.useRegularization=1;
            set(REG_EDIT,'enable','on')
        else
            params.beamformer_parameters.useRegularization=0;
            set(REG_EDIT,'enable','off')
        end
    end
     
REG_EDIT=uicontrol('style','edit','units','normalized','position', [0.81 0.51 0.05 0.04],...
        'String', reg_fT, 'FontSize', 12, 'BackGroundColor','white','callback',@reg_edit_callback);
    function reg_edit_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.regularization=0;
            set(REG_EDIT,'string',params.beamformer_parameters.regularization);
        else
            reg_fT = str2double(string_value);            
            params.beamformer_parameters.regularization = (reg_fT * 1e-15)^2; % convert from fT squared to Tesla squared 
        end
    end
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.87 0.5 0.1 0.04],...
        'String','fT / sqrt(Hz)','FontSize',12,'BackGroundColor','white');
 
% head model settings
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.65 0.43 0.25 0.04],...
        'String','Head Model:','FontSize',12,'FontWeight','bold','BackGroundColor','white');

HDM_RADIO = uicontrol('style','radio','units','normalized','position',[0.65 0.4 0.3 0.04],...
    'string','Use Head Model File (*.hdm):','Fontsize',12,'Backgroundcolor','white',...
    'value',params.beamformer_parameters.useHdmFile,'callback',@hdm_radio_callback);
    
    function hdm_radio_callback (~,~)
        params.beamformer_parameters.useHdmFile=1;
        set(HDM_EDIT,'enable','on');
        set(HDM_PUSH,'enable','on');
        set(SPHERE_RADIO,'value',0);
        set(SPHERE_EDIT_X,'enable','off');
        set(SPHERE_EDIT_Y,'enable','off');
        set(SPHERE_EDIT_Z,'enable','off');
        set(SPHERE_TITLE_X,'enable','off');
        set(SPHERE_TITLE_Y,'enable','off');
        set(SPHERE_TITLE_Z,'enable','off');

    end    
    
HDM_EDIT=uicontrol('style','edit','units','normalized','position', [0.65 0.36 0.18 0.04],...
        'String', params.beamformer_parameters.hdmFile, 'FontSize', 12, 'BackGroundColor','white','callback',@hdm_edit_callback);
    function hdm_edit_callback(src,~)
        params.beamformer_parameters.hdmFile=get(src,'String');
        if isempty(params.beamformer_parameters.hdmFile)
             params.beamformer_parameters.hdmFile='';
        end
    end

HDM_PUSH = uicontrol('style','pushbutton','units','normalized','position',[0.85 0.36 0.12 0.04],...
        'String','Load Head Model...','FontSize',12,'callback',@HDM_PUSH_CALLBACK);

    function HDM_PUSH_CALLBACK(~,~)
        s = fullfile(char(full_ds_filename),'*.hdm');
        [hdmfilename, hdmpathname, ~] = uigetfile('*.hdm','Select a Head Model (.hdm) file', s);
        if isequal(hdmfilename,0) || isequal(hdmpathname,0)
          return;
        end       
        dsPath = char(full_ds_filename);
        hdmPath = hdmpathname(1:end-1);
        hdmFile = fullfile(hdmpathname,hdmfilename);
        if ~strcmp(dsPath,hdmPath)
            s = sprintf('Copy headmodel file %s to the current dataset?', hdmFile);
            response = questdlg(s,'BrainWave','Yes','No','No');
            if strcmp(response,'No')            
                return;
            else
                if ispc
                    s = sprintf('copy %s %s', hdmFile, dsPath);
                else
                    s = sprintf('cp %s %s', hdmFile, dsPath);
                end
                system(s);
            end
        end
        params.beamformer_parameters.hdmFile=hdmfilename;

        set(HDM_EDIT,'string',hdmfilename)
        if isempty(params.beamformer_parameters.hdmFile)
            params.beamformer_parameters.hdmFile='';
        end

    end

SPHERE_RADIO = uicontrol('style','radio','units','normalized','position',[0.65 0.32 0.3 0.04],...
    'string','Use Single Sphere Origin (cm):','Fontsize',12,'Backgroundcolor','white',...
    'value',~params.beamformer_parameters.useHdmFile,'callback',@sphere_radio_callback);
    
    function sphere_radio_callback(~,~)
        params.beamformer_parameters.useHdmFile=0;
        set(HDM_RADIO,'value',0);
        set(HDM_EDIT,'enable','off');
        set(HDM_PUSH,'enable','off');
        set(SPHERE_EDIT_X,'enable','on');
        set(SPHERE_EDIT_Y,'enable','on');
        set(SPHERE_EDIT_Z,'enable','on');
        set(SPHERE_TITLE_X,'enable','on');
        set(SPHERE_TITLE_Y,'enable','on');
        set(SPHERE_TITLE_Z,'enable','on');
        if isempty(params.beamformer_parameters.sphere)
            params.beamformer_parameters.sphere = [0 0 5];
        end
        set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
        set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
        set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));
       
    end    
        
SPHERE_EDIT_X=uicontrol('style','edit','units','normalized','position', [0.68 0.28 0.05 0.04],...
        'String', params.beamformer_parameters.sphere(1), 'FontSize', 12, 'BackGroundColor','white','callback',@sphere_edit_x_callback);
    function sphere_edit_x_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
            params.beamformer_parameters.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
            params.beamformer_parameters.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));
        else
        params.beamformer_parameters.sphere(1)=str2double(string_value);
        end
    end
    SPHERE_TITLE_X=uicontrol('style','text','units','normalized','position',[0.66 0.27 0.02 0.04],...
       'String','X:','FontSize',12,'BackGroundColor','white');
 
SPHERE_EDIT_Y=uicontrol('style','edit','units','normalized','position', [0.76 0.28 0.05 0.04],...
        'String', params.beamformer_parameters.sphere(2), 'FontSize', 12, 'BackGroundColor','white','callback',@sphere_edit_y_callback);
    function sphere_edit_y_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
            params.beamformer_parameters.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
            params.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));
        else
        params.beamformer_parameters.sphere(2)=str2double(string_value);
        end
    end
SPHERE_TITLE_Y=uicontrol('style','text','units','normalized','position',[0.74 0.27 0.02 0.04],...
        'String','Y:','FontSize',12,'BackGroundColor','white');
       
SPHERE_EDIT_Z=uicontrol('style','edit','units','normalized','position', [0.84 0.28 0.05 0.04],...
        'String', params.beamformer_parameters.sphere(3), 'FontSize', 12, 'BackGroundColor','white','callback',@sphere_edit_z_callback);
    function sphere_edit_z_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            params.beamformer_parameters.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
            params.beamformer_parameters.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
            params.beamformer_parameters.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));
        else
        params.beamformer_parameters.sphere(3)=str2double(string_value);
        end
    end
    SPHERE_TITLE_Z=uicontrol('style','text','units','normalized','position',[0.82 0.27 0.02 0.04],...
        'String','Z:','FontSize',12,'BackGroundColor','white');
    
% set initial state
set(HDM_RADIO,'value',params.beamformer_parameters.useHdmFile);
set(SPHERE_EDIT_X,'string',params.beamformer_parameters.sphere(1));
set(SPHERE_EDIT_Y,'string',params.beamformer_parameters.sphere(2));
set(SPHERE_EDIT_Z,'string',params.beamformer_parameters.sphere(3));

if params.beamformer_parameters.useHdmFile
    set(HDM_EDIT,'enable','on');
    set(HDM_PUSH,'enable','on');
    set(SPHERE_EDIT_X,'enable','off');
    set(SPHERE_EDIT_Y,'enable','off');
    set(SPHERE_EDIT_Z,'enable','off');
    set(SPHERE_TITLE_X,'enable','off');
    set(SPHERE_TITLE_Y,'enable','off');
    set(SPHERE_TITLE_Z,'enable','off');
else
    set(HDM_EDIT,'enable','off');
    set(HDM_PUSH,'enable','off');
    set(SPHERE_EDIT_X,'enable','on');
    set(SPHERE_EDIT_Y,'enable','on');
    set(SPHERE_EDIT_Z,'enable','on');
    set(SPHERE_TITLE_X,'enable','on');
    set(SPHERE_TITLE_Y,'enable','on');
    set(SPHERE_TITLE_Z,'enable','on');
end
            

update_fields;


%%%%%%%%%%%%
% Menus
%%%%%%%%%%%%

% File Menu
FILE_MENU=uimenu('Label','File');
    OPEN_SETTINGS = uimenu(FILE_MENU,'label','Load Settings ...','Accelerator',...
        'L','enable','off','Callback',@LOAD_BUTTON_CALLBACK);
    SAVE_SETTINGS = uimenu(FILE_MENU,'label','Save Settings','Accelerator','S',...
        'enable','off','separator','on','Callback',@SAVE_BUTTON_CALLBACK);
    SAVE_SETTINGS_AS = uimenu(FILE_MENU,'label','Save Settings As...',...
        'enable','off','Callback',@SAVE_AS_BUTTON_CALLBACK);
    uimenu(FILE_MENU,'label','Close','accelerator','W','Callback',@QUIT_MENU_CALLBACK,'separator', 'on');
    
        
%%%%%%%%%%%%%%%%%%%%%%%%
% Callback Functions
%%%%%%%%%%%%%%%%%%%%%%%% 

    function WORKSPACE_BUTTON_CALLBACK(~,~)
        tdir =uigetdir;                    
        if isequal(tdir,0) 
           return;
        end
        
        setWorkSpace(tdir);
        
        % changed - now set CWD when changing Dataset Directory
        cd(tdir)
        fprintf('setting current working directory to %s\n',tdir);
        
    end


    % update text box...
    function REFRESH_DS_CALLBACK(~,~)
        setWorkSpace(workspace1);
    end

    % if new dataset selected...

    function DS_LISTBOX_CALLBACK(src,~)
        
        selection = get(src,'value');
        ds_filenames=get(src,'string');        
        ds_filename=ds_filenames(selection,:);
        
        if isempty(ds_filenames)
            return;
        end
        
        full_ds_filename = fullfile(workspace1,char(ds_filename));
  
        if ~useCovDs && ~ params.beamformer_parameters.multiDsSAM
            covDsName = full_ds_filename;
        end
        
        init_ds_params(full_ds_filename);   % updates dsParams
 
        set(DATASET_TEXT_TITLE,'enable', 'on');
        set(DATASET_INFO_TEXT,'enable', 'on');  
        set(PLOT_BEAMFORMER_BUTTON,'enable','on')
        set(PLOT_DATA_BUTTON,'enable','on')       
  
    end

    function COV_DS_LISTBOX_CALLBACK(src,~)
        if ~useCovDs && ~ params.beamformer_parameters.multiDsSAM
           return;
        end    
        selection = get(src,'value');
        cov_ds_filenames=get(src,'string');                   
        cov_ds_name=cov_ds_filenames(selection,:);       
        covDsName = fullfile(workspace1,char(cov_ds_name));
                
        init_ds_params(full_ds_filename);   % re-check params

    end

    % note image options and beamformer parameters in one structure. 
    % should move images options to general preferences....
    function IMAGE_OPTIONS_BUTTON_CALLBACK(~,~)
        params = bw_set_image_options(full_ds_filename, params);
    end

    %%%%% plot images %%%%

    function PLOT_BEAMFORMER_BUTTON_CALLBACK(~,~)
        if params.beamformer_parameters.useVoxFile
            if isempty(meshFile) 
                errordlg('No surface or voxfile has been selected ...');
                beep;
                return;
            end
        end
        
        if useCovDs || params.beamformer_parameters.multiDsSAM
            [~, ~,subjectID, ~, ~] = bw_parse_ds_filename(full_ds_filename);
            [~, ~, covSubjectID, ~, ~] = bw_parse_ds_filename(covDsName);        
            if ~strcmp(subjectID,covSubjectID)
                errordlg('Selected Dataset and Covariance / Baseline Dataset must have same subject ID');
                return;
            end
            params.beamformer_parameters.covarianceType = 2;
        else
            params.beamformer_parameters.covarianceType = 0;
       end  
        
        % always make sure we are in still in the working directory
        covDsParams = bw_CTFGetHeader(covDsName);
        if (params.beamformer_parameters.covWindow(1) < covDsParams.epochMinTime || params.beamformer_parameters.covWindow(2) > covDsParams.epochMaxTime)
            s = sprintf('Covariance window (%.3f to %.3f seconds) exceeds data range (%.3f to %.3f seconds)\n',....
                params.beamformer_parameters.covWindow, covDsParams.epochMinTime, covDsParams.epochMaxTime);
            beep;
            errordlg(s)
            return;
        end
        
        if (params.beamformer_parameters.useHdmFile)
            hdmFile = fullfile(full_ds_filename, params.beamformer_parameters.hdmFile);
            if ~exist(hdmFile,'file')
                s = sprintf('Head model file %s does not exist for this dataset\n', params.beamformer_parameters.hdmFile);
                beep;
                errordlg(s)
                return;
            end
        end
        
        cd(workspace1) 

        % make a pseudo progress bar so user knows something is happening
        wbh = waitbar(0,'Generating images...');
        for i=10:5:20
            waitbar(i/100,wbh);
        end

        % Nov 11 - fix - passing full ds names results in images list have
        % full path 
        [~, name, ext] = bw_fileparts(full_ds_filename);
        dsName = strcat(name,ext);
        
        if params.beamformer_parameters.useVoxFile
            meshName = char(meshNames(selected_surface));
            mesh = meshes.(meshName);       
            voxels = [mesh.meg_vertices mesh.normals];
            [~,name,~] =  fileparts(meshFile);
            voxFile = sprintf('%s_%s.vox',name, meshName);
            fprintf('writing voxel coordinates to vox file %s...\n', voxFile);
            fid = fopen(voxFile,'w');
            fprintf(fid,'%d\n', size(voxels,1));
            fclose(fid);
            dlmwrite(voxFile, voxels, '-append','delimiter','\t');            
            params.beamformer_parameters.voxFile = voxFile;
            
        else   
        	params.beamformer_parameters.voxFile = '';   
        end
        
        % make sure we have updated values from edit fields
        filter_edit_min_callback(FILTER_EDIT_MIN)
        filter_edit_max_callback(FILTER_EDIT_MAX);
        baseline_edit_min_callback(BASELINE_EDIT_MIN);
        baseline_edit_max_callback(BASELINE_EDIT_MAX);
        
        imageList = bw_make_beamformer(dsName, covDsName, params.beamformer_parameters);        

        if isempty(imageList)
            delete(wbh);
            return;
        end

        delete(wbh);       
        
        if params.beamformer_parameters.useVoxFile   
            dt_meshViewer(meshFile, imageList);
        else
            imageset.imageType = 'Volume';
            % new create an imageset mat file for multiple images.

            [~, ds_name, ~, ~, ~] = bw_parse_ds_filename(full_ds_filename);
            [~, cov_ds_name, ~, ~, mri_filename] = bw_parse_ds_filename(covDsName);

            imageset.no_subjects = 1;
            imageset.params = params;
            imageset.no_images = size(imageList,1);

            imageset.dsName{1} = ds_name;
            imageset.covDsName{1} = cov_ds_name;
            imageset.isNormalized = false;
            imageset.imageList{1} = imageList;
            imageset.cond1Label = 'Single Subject';

            % generate imageset name
            tname = char(imageList(1,:));
            imageset_BaseName=tname(1,1:strfind(tname,'Hz')+1);  
            if (params.beamformer_parameters.beam.use == 'T' |  params.beamformer_parameters.beam.use == 'F')
                s = sprintf('_pseudo_%s_A=%s_%s_B=%s_%s', params.beamformer_parameters.beam.use, ...
                        num2str(params.beamformer_parameters.beam.activeStart), num2str(params.beamformer_parameters.beam.activeEnd), ...
                        num2str(params.beamformer_parameters.beam.baselineStart) ,num2str(params.beamformer_parameters.beam.baselineEnd) );
                imageset_BaseName = strcat(imageset_BaseName, s);
            else
                imageset_BaseName = strcat(imageset_BaseName, '_ERB');
            end

            if normalize_images
                imageset_BaseName = strcat(imageset_BaseName, '_MNI');
            end
            
            if (normalize_images)
                imageset.mriName{1} = mri_filename;        
                imageset.isNormalized = true;

                fprintf('Normalizing images...\n');                
                [normalized_imageList] = bw_normalize_images(mri_filename, imageList, params.spm_options);             
                imageset.imageList{1} = char(normalized_imageList);
            end
            imagesetName = sprintf('%s_IMAGES.mat', imageset_BaseName);

            fprintf('Saving image set information in %s\n', imagesetName);
            save(imagesetName, '-struct', 'imageset');
            bw_mip_plot_4D(imagesetName);               
        end  
        

    end

    function MEG_RADIO_CALLBACK(src,~)
       set(src,'value',1);
       normalize_images=0;
       set(SPM_RADIO,'value',0);
    end

    function SPM_RADIO_CALLBACK(src,~)
       set(src,'value',1);
       normalize_images=1;
       set(MEG_RADIO,'value',0);
    end

    function VOLUME_RADIO_CALLBACK(src,~)
       params.beamformer_parameters.useVoxFile = 0;
       set(src,'value',1);
       set(SURFACE_RADIO,'value',0);
       set(MEG_RADIO,'enable','on');
       set(SPM_RADIO,'enable','on');
       set(SURFACE_FILE_EDIT, 'enable','off');
       set(SURFACE_FILE_BUTTON, 'enable','off');
       set(SURFACE_MENU, 'enable','off');
    end
    
    function SURFACE_RADIO_CALLBACK(src,~)
       params.beamformer_parameters.useVoxFile = 1;
       set(src,'value',1);
       set(VOLUME_RADIO,'value',0);
       set(MEG_RADIO,'enable','off');
       set(SPM_RADIO,'enable','off');
       set(SURFACE_FILE_EDIT, 'enable','on');
       set(SURFACE_FILE_BUTTON, 'enable','on');       
       set(SURFACE_MENU, 'enable','on');
   end

    function surface_file_button_callback(~,~)
        
        [~, ~, ~, mriDir, ~] = bw_parse_ds_filename(full_ds_filename);

        s = strcat(mriDir,filesep,'*.mat');
        [surfaceFileName,filepath,~] = uigetfile({'*_SURFACES.mat','Surface File (*_SURFACE.mat)'},'Select a surface file...', s);
        if isequal(surfaceFileName,0)
          return;
        end
        
 
        set(SURFACE_FILE_EDIT,'string',surfaceFileName)
        meshFile = fullfile(filepath, surfaceFileName);
        fprintf('Loading surface from %s\n', meshFile);
        loadMesh(meshFile);
        
    end


    function loadMesh(meshFile)

        % check for correct .mat file structure
        t = load(meshFile);   
        if ~isstruct(t)
            errordlg('This does not appear to be a valid surface file\n');
            return;
        end  
        fnames = fieldnames(t);
        test = t.(char(fnames(1)));
        if ~isfield(test,'vertices')
            errordlg('This does not appear to be a valid surface file\n');
            return;
        end        
        meshes = t;
        clear t;
        
        meshNames = fieldnames(meshes);
        selected_surface = 1; 
        set(SURFACE_MENU,'string', meshNames)

    end

    function surface_menu_callback(src,~)
        selected_surface = get(src,'value');
    end


    function PLOT_DATA_BUTTON_CALLBACK(~,~)      
        selection = get(DS_LISTBOX,'value');
        ds_filenames = get(DS_LISTBOX,'string');
        
        if ~isempty(ds_filenames)
            name = ds_filenames(selection,:);
            dsName=fullfile(workspace1,char(name));
            fwindow(1) = params.beamformer_parameters.filter(1);
            fwindow(2) = params.beamformer_parameters.filter(2);
            bwindow = [];
            if params.beamformer_parameters.useBaselineWindow
                bwindow(1) = params.beamformer_parameters.baseline(1);
                bwindow(2) = params.beamformer_parameters.baseline(2);
            end
            bw_dipoleFitGUI(dsName, fwindow, bwindow);
        end        
    end

    function COMBINE_DS_BUTTON_CALLBACK(~,~)      
        startPath = pwd;
        bw_combine_datasets(startPath);
        % refresh
        setWorkSpace(workspace1);
    end

    function COPY_HEADMODEL_BUTTON_CALLBACK(~,~)      
        selection = get(DS_LISTBOX,'value');
        ds_filenames = get(DS_LISTBOX,'string');
        
        if ~isempty(ds_filenames)
            name = ds_filenames(selection,:);
            dsName=fullfile(workspace1,char(name));
        end
        
        s = fullfile(char(dsName),'*.hdm');
        [hdmfilename, hdmpathname, ~] = uigetfile('*.hdm','Select a Head Model (.hdm) file', s);
        if isequal(hdmfilename,0) || isequal(hdmpathname,0)
          return;
        end       
        hdmFile = fullfile(hdmpathname,hdmfilename);        
        
        % to multiselect directories use uigetdir2          
        fileList = uigetdir2(workspace1,'Select datasets to copy Head Models to:');
        if isempty(fileList)
            return;
        end
        for j=1:numel(fileList)       
            targetDs = char(fileList(j));
            s = sprintf('cp %s %s', hdmFile, targetDs);
            system(s);
        end       
    end

    function PLOT_BEAMFORMER_START_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.latencyStart=str2double(get(src,'String'));
    end

    function PLOT_BEAMFORMER_END_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.latencyEnd=str2double(get(src,'String'));
    end

    function PLOT_BEAMFORMER_STEP_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.step=str2double(get(src,'String'));
    end

    function BASELINE_START_EDIT_CALLBACK(src,~)
    params.beamformer_parameters.beam.baselineStart=str2double(get(src,'String'));
    end
    
    function BASELINE_END_EDIT_CALLBACK(src,~)
    params.beamformer_parameters.beam.baselineEnd=str2double(get(src,'String'));
    end

    function ACTIVE_START_EDIT_CALLBACK(src,~)
    params.beamformer_parameters.beam.activeStart=str2double(get(src,'String'));
    end
    
    function ACTIVE_END_EDIT_CALLBACK(src,~)
    params.beamformer_parameters.beam.activeEnd=str2double(get(src,'String'));
    end

    function ACTIVE_STEP_LAT_EDIT_CALLBACK(src,~)
    params.beamformer_parameters.beam.active_step=str2double(get(src,'string'));
    end

    function ACTIVE_NO_STEP_EDIT_CALLBACK(src,~)
    params.beamformer_parameters.beam.no_step=str2double(get(src,'string'));
    end

    %  Image controls....
    function RADIO_RANGE_CALLBACK(src,~)
        set_radios(0);  % all off
        set(src,'value',1);
        params.beamformer_parameters.beam.use='ERB';
        init_ds_params(full_ds_filename);
        update_fields;
    end

    function RADIO_LIST_CALLBACK(src,~)
        set_radios(0);  % all off
        set(src,'value',1);
        params.beamformer_parameters.beam.use='ERB_LIST';
        init_ds_params(full_ds_filename);
        update_fields;
    end

    function RADIO_Z_CALLBACK(src,~)
        set_radios(0);  % all off
        set(src,'value',1);
        params.beamformer_parameters.beam.use='Z';      
        init_ds_params(full_ds_filename);
        update_fields;        
    end

    function RADIO_T_CALLBACK(src,~)
        set_radios(0);  % all off
        set(src,'value',1);
        params.beamformer_parameters.beam.use='T';      
        init_ds_params(full_ds_filename);
        update_fields;        
    end

    function RADIO_F_CALLBACK(src,~)
        set_radios(0);  % all off
        set(src,'value',1);
        params.beamformer_parameters.beam.use='F';      
        init_ds_params(full_ds_filename);
        update_fields;              
    end

    function set_radios(val)
        set(RADIO_RANGE,'value',val)
        set(RADIO_LIST,'value',val)
        set(RADIO_Z,'value',val)
        set(RADIO_T,'value',val)
        set(RADIO_F,'value',val)
    end
 
    function update_fields
        
        if strcmp(params.beamformer_parameters.beam.use,'ERB') || strcmp(params.beamformer_parameters.beam.use,'ERB_LIST')

            if strcmp(params.beamformer_parameters.beam.use,'ERB')
 
                set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','on')
                set(LAT_STEPSIZE_LABEL,'enable','on')
                set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','on')
                params.beamformer_parameters.beam.latencyStart=str2double(get(PLOT_BEAMFORMER_START_LAT_EDIT,'string'));
                set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','on')
                params.beamformer_parameters.beam.latencyEnd=str2double(get(PLOT_BEAMFORMER_END_LAT_EDIT,'string'));
                set(LAT_START_LABEL,'enable','on')
                set(LAT_END_LABEL,'enable','on')     
                set(LATENCY_LIST,'enable','off');
                set(LATENCY_EDIT_BUTTON,'enable','off');
%                 set(COMPUTE_MEAN_CHECK,'enable','on')  
                 
            elseif strcmp(params.beamformer_parameters.beam.use,'ERB_LIST')

                set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','off')
                set(LAT_STEPSIZE_LABEL,'enable','off')
                set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','off')
                set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','off')
                set(LAT_START_LABEL,'enable','off')
                set(LAT_END_LABEL,'enable','off')    
                set(LATENCY_LIST,'enable','on');
                set(LATENCY_EDIT_BUTTON,'enable','on');
%                 set(COMPUTE_MEAN_CHECK,'enable','off')  

            end
            
            set(COV_DS_CHECK,'enable','on')             
            if useCovDs
                set(COV_DS_LISTBOX,'enable','on');
            else
                 set(COV_DS_LISTBOX,'enable','off');
            end
            set(MULTI_DS_SAM_CHECK,'enable','off')             
            
            set(COV_EDIT_MIN,'enable','on')
            set(COV_EDIT_MAX,'enable','on')
            set(COV_LABEL_MIN,'enable','on')
            set(COV_LABEL_MAX,'enable','on')               
            set(COV_USE_FULL_CHECK,'enable','on')               
            set(BASELINE_CORRECT_CHECK,'enable','on')
                      
            if params.beamformer_parameters.useBaselineWindow == 1
                set(BASELINE_SET_FULL_BUTTON,'enable','on')
                set(BASELINE_EDIT_MAX,'enable','on')
                set(BASELINE_EDIT_MIN,'enable','on')
                set(BASELINE_LABEL_MIN,'enable','on')
                set(BASELINE_LABEL_MAX,'enable','on')
            else
                set(BASELINE_SET_FULL_BUTTON,'enable','off')
                set(BASELINE_EDIT_MAX,'enable','off')
                set(BASELINE_EDIT_MIN,'enable','off')
                set(BASELINE_LABEL_MIN,'enable','off')
                set(BASELINE_LABEL_MAX,'enable','off')
            end
            
            set_SAM_enable('off');
        else
            
            % set SAM options on
            set(MULTI_DS_SAM_CHECK,'enable','on')             
            if params.beamformer_parameters.multiDsSAM
                set(COV_DS_LISTBOX,'enable','on');
            else
                 set(COV_DS_LISTBOX,'enable','off');
            end
            set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','off')
            set(LAT_STEPSIZE_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','off')
            set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','off')
            set(LAT_START_LABEL,'enable','off')
            set(LAT_END_LABEL,'enable','off')     
            set(COV_DS_CHECK,'enable','off')                  
                     
            set(BASELINE_CORRECT_CHECK,'enable','off')
            set(BASELINE_SET_FULL_BUTTON,'enable','off')
            set(BASELINE_EDIT_MAX,'enable','off')
            set(BASELINE_EDIT_MIN,'enable','off')
            set(BASELINE_LABEL_MIN,'enable','off')
            set(BASELINE_LABEL_MAX,'enable','off')
                 
%             set(COMPUTE_MEAN_CHECK,'enable','off')  
                     
            % enable SAM fields
            set_SAM_enable('on');
            if strcmp(params.beamformer_parameters.beam.use,'Z')
                set(BASELINE_WINDOW_LABEL,'enable','off')
                set(BASELINE_START_EDIT,'enable','off')
                set(BASELINE_START_LABEL,'enable','off')
                set(BASELINE_END_EDIT,'enable','off')
                set(BASELINE_END_LABEL,'enable','off')
            end                    
           
        end
    end

    function set_SAM_enable(str)
           
        %  SAM fields
        set(ACTIVE_WINDOW_LABEL,'enable',str)
        set(BASELINE_WINDOW_LABEL,'enable',str)
        set(BASELINE_START_EDIT,'enable',str)
        set(BASELINE_START_LABEL,'enable',str)
        set(BASELINE_END_EDIT,'enable',str)
        set(BASELINE_END_LABEL,'enable',str)
        set(ACTIVE_START_EDIT,'enable',str)
        set(ACTIVE_START_LABEL,'enable',str)
        set(ACTIVE_END_EDIT,'enable',str)
        set(ACTIVE_END_LABEL,'enable',str)
        set(ACTIVE_STEP_LAT_EDIT,'enable',str)
        set(ACTIVE_STEPSIZE_LABEL,'enable',str)
        set(ACTIVE_NO_STEP_LABEL,'enable',str)
        set(ACTIVE_NO_STEP_EDIT,'enable',str)   
    end

    function SAVE_AS_BUTTON_CALLBACK(~,~)
        defPath = 'bw_prefs_custom.mat';
        [name,path,~] = uiputfile('*.mat','Select name for settings file:', defPath);
        if isequal(name,0)
            return;
        end

        filename = fullfile(path,name);      
        save_current_settings(filename)        
    end

    function SAVE_BUTTON_CALLBACK(~,~)
        filename = fullfile(pwd,'bw_prefs.mat');      
        save_current_settings(filename)        
    end

    function LOAD_BUTTON_CALLBACK(~,~)
        [settingfilename, settingpathname, ~]=uigetfile('*.mat','Select Settings File:');
        if isequal(settingfilename,0)
            return;
        end

        fullname=[settingpathname,settingfilename];
               
        params = bw_readPrefsFile(fullname);
        
        set(PLOT_BEAMFORMER_START_LAT_EDIT,'string',params.beamformer_parameters.beam.latencyStart)
        set(PLOT_BEAMFORMER_END_LAT_EDIT,'string',params.beamformer_parameters.beam.latencyEnd)
        set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'string',params.beamformer_parameters.beam.step)

        
        set(ACTIVE_START_EDIT,'string',params.beamformer_parameters.beam.activeStart)
        set(ACTIVE_END_EDIT,'string',params.beamformer_parameters.beam.activeEnd)
        set(ACTIVE_STEP_LAT_EDIT,'string',params.beamformer_parameters.beam.active_step)
        set(ACTIVE_NO_STEP_EDIT,'string',params.beamformer_parameters.beam.no_step)
        set(BASELINE_START_EDIT,'string',params.beamformer_parameters.beam.baselineStart)
        set(BASELINE_END_EDIT,'string',params.beamformer_parameters.beam.baselineEnd)
  
        if ~isempty(params.beamformer_parameters.beam.latencyList)
            set(LATENCY_LIST,'string',{params.beamformer_parameters.beam.latencyList});
        end
               
        if strcmp(params.beamformer_parameters.beam.use,'ERB')
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',0)
            set(BASELINE_START_EDIT,'enable','off')
            set(BASELINE_START_LABEL,'enable','off')
            set(BASELINE_END_EDIT,'enable','off')
            set(BASELINE_END_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','on')
            set(LAT_STEPSIZE_LABEL,'enable','on')
            set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','on')
            set(LAT_START_LABEL,'enable','on')
            set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','on')
            set(LAT_END_LABEL,'enable','on')
            set(ACTIVE_START_EDIT,'enable','off')
            set(ACTIVE_START_LABEL,'enable','off')
            set(ACTIVE_END_EDIT,'enable','off')
            set(ACTIVE_END_LABEL,'enable','off')
            set(ACTIVE_STEP_LAT_EDIT,'enable','off')
            set(ACTIVE_STEPSIZE_LABEL','enable','off')
            set(ACTIVE_NO_STEP_LABEL,'enable','off')
            set(ACTIVE_NO_STEP_EDIT,'enable','off')
        elseif strcmp(params.beamformer_parameters.beam.use,'ERB_LIST')
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',0)
            set(BASELINE_START_EDIT,'enable','off')
            set(BASELINE_START_LABEL,'enable','off')
            set(BASELINE_END_EDIT,'enable','off')
            set(BASELINE_END_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','off')
            set(LAT_STEPSIZE_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','off')
            set(LAT_START_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','off')
            set(LAT_END_LABEL,'enable','off')
            set(ACTIVE_START_EDIT,'enable','off')
            set(ACTIVE_START_LABEL,'enable','off')
            set(ACTIVE_END_EDIT,'enable','off')
            set(ACTIVE_END_LABEL,'enable','off')
            set(ACTIVE_STEP_LAT_EDIT,'enable','off')
            set(ACTIVE_STEPSIZE_LABEL','enable','off')
            set(ACTIVE_NO_STEP_LABEL,'enable','off')
            set(ACTIVE_NO_STEP_EDIT,'enable','off')
        elseif strcmp(params.beamformer_parameters.beam.use,'T')
            set(RADIO_T,'value',1)
            set(RADIO_F,'value',0)
            set(BASELINE_START_EDIT,'enable','on')
            set(BASELINE_START_LABEL,'enable','on')
            set(BASELINE_END_EDIT,'enable','on')
            set(BASELINE_END_LABEL,'enable','on')
            set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','off')
            set(LAT_STEPSIZE_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','off')
            set(LAT_START_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','off')
            set(LAT_END_LABEL,'enable','off')
            set(ACTIVE_START_EDIT,'enable','on')
            set(ACTIVE_START_LABEL,'enable','on')
            set(ACTIVE_END_EDIT,'enable','on')
            set(ACTIVE_END_LABEL,'enable','on')
            set(ACTIVE_STEP_LAT_EDIT,'enable','on')
            set(ACTIVE_STEPSIZE_LABEL,'enable','on')
            set(ACTIVE_NO_STEP_LABEL,'enable','on')
            set(ACTIVE_NO_STEP_EDIT,'enable','on')
        else
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',1)
            set(BASELINE_START_EDIT,'enable','on')
            set(BASELINE_START_LABEL,'enable','on')
            set(BASELINE_END_EDIT,'enable','on')
            set(BASELINE_END_LABEL,'enable','on')
            set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','off')
            set(LAT_STEPSIZE_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','off')
            set(LAT_START_LABEL,'enable','off')
            set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','off')
            set(LAT_END_LABEL,'enable','off')
            set(ACTIVE_START_EDIT,'enable','on')
            set(ACTIVE_START_LABEL,'enable','on')
            set(ACTIVE_END_EDIT,'enable','on')
            set(ACTIVE_END_LABEL,'enable','on')
            set(ACTIVE_STEP_LAT_EDIT,'enable','on')
            set(ACTIVE_STEPSIZE_LABEL,'enable','on')
            set(ACTIVE_NO_STEP_LABEL,'enable','on')
            set(ACTIVE_NO_STEP_EDIT,'enable','on')
        end
    end

    function QUIT_MENU_CALLBACK(~,~)       
        response = questdlg('Save current settings?','Brainwave','Yes','No','Cancel','Yes');
        if strcmp(response,'Cancel')  
            return;
        end
        if strcmp(response,'Yes')          
            prefFile = strcat(pwd,filesep,'bw_prefs.mat');
            [dsName,dsPath,~] = uiputfile('*.mat','Select Name for combined dataset:',prefFile);
            if ~isequal(dsName,0)
                prefFile = fullfile(dsPath,dsName);   
                save_current_settings(prefFile);        
            end  
        end      
        delete(f);
    end


% Initial state for various buttons...

set(IMAGE_OPTIONS_BUTTON,'enable','off')
set(PLOT_BEAMFORMER_BUTTON,'enable','off')
set(PLOT_DATA_BUTTON,'enable','off')


switch params.beamformer_parameters.beam.use
    case 'ERB'
        set(BASELINE_START_EDIT,'enable','off')
        set(BASELINE_START_LABEL,'enable','off')
        set(BASELINE_END_EDIT,'enable','off')
        set(BASELINE_END_LABEL,'enable','off')
        set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','on')
        set(LAT_STEPSIZE_LABEL,'enable','on')
        set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','on')
        set(LAT_START_LABEL,'enable','on')
        set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','on')
        set(LAT_END_LABEL,'enable','on')
        set(ACTIVE_START_EDIT,'enable','off')
        set(ACTIVE_START_LABEL,'enable','off')
        set(ACTIVE_END_EDIT,'enable','off')
        set(ACTIVE_END_LABEL,'enable','off')
        set(ACTIVE_STEP_LAT_EDIT,'enable','off')
        set(ACTIVE_STEPSIZE_LABEL,'enable','off')
        set(ACTIVE_NO_STEP_LABEL,'enable','off')
        set(ACTIVE_NO_STEP_EDIT,'enable','off')
    case 'ERB_LIST'

        set(BASELINE_START_EDIT,'enable','off')
        set(BASELINE_START_LABEL,'enable','off')
        set(BASELINE_END_EDIT,'enable','off')
        set(BASELINE_END_LABEL,'enable','off')
        set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','off')
        set(LAT_STEPSIZE_LABEL,'enable','off')
        set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','off')
        set(LAT_START_LABEL,'enable','off')
        set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','off')
        set(LAT_END_LABEL,'enable','off')
        set(ACTIVE_START_EDIT,'enable','off')
        set(ACTIVE_START_LABEL,'enable','off')
        set(ACTIVE_END_EDIT,'enable','off')
        set(ACTIVE_END_LABEL,'enable','off')
        set(ACTIVE_STEP_LAT_EDIT,'enable','off')
        set(ACTIVE_STEPSIZE_LABEL,'enable','off')
        set(ACTIVE_NO_STEP_LABEL,'enable','off')
        set(ACTIVE_NO_STEP_EDIT,'enable','off')
    otherwise
        set(BASELINE_START_EDIT,'enable','on')
        set(BASELINE_START_LABEL,'enable','on')
        set(BASELINE_END_EDIT,'enable','on')
        set(BASELINE_END_LABEL,'enable','on')
        set(PLOT_BEAMFORMER_STEP_LAT_EDIT,'enable','off')
        set(LAT_STEPSIZE_LABEL,'enable','off')
        set(PLOT_BEAMFORMER_START_LAT_EDIT,'enable','off')
        set(LAT_START_LABEL,'enable','off')
        set(PLOT_BEAMFORMER_END_LAT_EDIT,'enable','off')
        set(LAT_END_LABEL,'enable','off')
        set(ACTIVE_START_EDIT,'enable','on')
        set(ACTIVE_START_LABEL,'enable','on')
        set(ACTIVE_END_EDIT,'enable','on')
        set(ACTIVE_END_LABEL,'enable','on')
        set(ACTIVE_STEP_LAT_EDIT,'enable','on')
        set(ACTIVE_STEPSIZE_LABEL,'enable','on')
        set(ACTIVE_NO_STEP_LABEL,'enable','on')
        set(ACTIVE_NO_STEP_EDIT,'enable','on')
        set(COV_DS_CHECK,'enable','on')

end

% initialize states

setWorkSpace(pwd);

ds_filenames=get(DS_LISTBOX,'string');        
if ~isempty(ds_filenames)
    file_number_ds = 1;
    ds_filename = ds_filenames(file_number_ds,:);
    full_ds_filename = fullfile(workspace1,char(ds_filename));

    covDsName = full_ds_filename;
    init_ds_params(full_ds_filename);

    set(PLOT_BEAMFORMER_BUTTON,'enable','on')
    set(PLOT_DATA_BUTTON,'enable','on')
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% helper functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function setWorkSpace(dataDir)
    
    if isempty(dataDir)
        return;
    end

    workspace1=dataDir;

    % version 3.3 - rewrote to exclude Mac metadata files begining with ._
    Workspace=dir(workspace1);
    WorkSpace={Workspace.name};
    numfiles=size(WorkSpace,2);
    count=1;
    DSworkspace={};
    for k=1:numfiles
       s = WorkSpace(1,k);
       str = char(s);
       idx = strfind(str,'.ds');
       idx2 = strfind(str,'.');
       if ~isempty(idx)
           if idx2 ~= 1
               DSworkspace(1,count)={str};
               count = count+1;
           end
       end   
    end
   
    set(DS_LISTBOX,'enable','on','String',DSworkspace)
    set(COV_DS_LISTBOX,'String',DSworkspace)

    tstr = sprintf('Data Directory: (%s%s)', workspace1, filesep);
    set(WORKSPACE_TEXT_TITLE,'string',tstr, 'enable','on');
end

function init_ds_params(dsName)
    
    dsParams = bw_CTFGetHeader(dsName);
    covDsParams = bw_CTFGetHeader(covDsName);     % may be different dataset
    [~,n,e] = fileparts(covDsName);
    
    if strcmp(params.beamformer_parameters.beam.use,'ERB')
        ds_title=sprintf('Dataset: %s\nCovariance Dataset:%s',char(ds_filename),[n e]);  
    else
        ds_title=sprintf('Dataset: %s\nBaseline Dataset:%s',char(ds_filename),[n e]);  
    end
    
    set(DATASET_TEXT_TITLE,'string',ds_title)

    ds_info=sprintf('Acquistion Parameters:\n%d sensors, %d trials, %d Samples/trial\nBW: %g to %g Hz, %g Samples/s\nTrial duration: %g to %g s', ...
        dsParams.numSensors, dsParams.numTrials, dsParams.numSamples,...
        dsParams.highPass, dsParams.lowPass, dsParams.sampleRate, dsParams.epochMinTime, dsParams.epochMaxTime);               
    set(DATASET_INFO_TEXT,'string',ds_info);

    % update cov window 
    if useFullEpoch
        params.beamformer_parameters.covWindow(1) = covDsParams.epochMinTime;
        set(COV_EDIT_MIN,'string',params.beamformer_parameters.covWindow(1));
        params.beamformer_parameters.covWindow(2) = covDsParams.epochMaxTime;
        set(COV_EDIT_MAX,'string',params.beamformer_parameters.covWindow(2));
    end 
    
    if usePreStim       
       params.beamformer_parameters.baseline(1) = dsParams.epochMinTime;
       params.beamformer_parameters.baseline(2) = 0.0;
       set(BASELINE_EDIT_MIN,'string',params.beamformer_parameters.baseline(1))
       set(BASELINE_EDIT_MAX,'string',params.beamformer_parameters.baseline(2))    
    end
    
    % enable controls each time...
    set(OPEN_SETTINGS,'enable','on')
    set(SAVE_SETTINGS,'enable','on')
    set(SAVE_SETTINGS_AS,'enable','on')
    set(IMAGE_OPTIONS_BUTTON,'enable','on')
    
    
end


function save_current_settings(filename)
   
    fprintf('saving current settings to file %s\n', filename)
    save(filename,'-struct', 'params')    
    
end

end


