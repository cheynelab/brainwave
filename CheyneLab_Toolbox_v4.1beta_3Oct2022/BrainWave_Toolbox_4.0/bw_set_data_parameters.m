function params = bw_set_data_parameters(init_params, dsName, covDsName)
%        
%   function params = params = bw_set_data_parameters(inputParams,dsName)
%
%   DESCRIPTION: Creates a GUI that allows the user to select the more 
%   general options of BrainWave for beamformer image generation, TFR 
%   generation, virtual sensor generation and more. To work it requires
%   some basic dataset information such as the time before and after the
%   trigger latency (ctfmin and ctfmax), the sample rate (sr) and the
%   dataset's name.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Liehsout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


% CREATE FIGURE
params = [];

if isempty(dsName)
    fprintf('Invalid dataset name\n');
    return;
end

button_color = [1,1,1];

scrnsizes=get(0,'MonitorPosition');

f=figure('Name', 'Data Parameters', 'Position', [scrnsizes(1,3)/4 scrnsizes(1,4)/2 900 500],...
        'menubar','none','numbertitle','off', 'Color','white');
if ispc
    movegui(f,'center');
end
    %SAVES THE VSparameters
SAVE_BUTTON = uicontrol('Units','Normalized','Position',[0.685 0.1 0.12 0.08],'String','Save',...
              'FontSize',13,'FontWeight','b','ForegroundColor',...
              'black','Callback','uiresume(gcbf)'); 

% LOAD DEFAULT PARAMS
% save initial state for cancel

params = init_params;   % returned params

header = bw_CTFGetHeader(dsName);
sampleRate = header.sampleRate;
dataRange = [header.epochMinTime header.epochMaxTime];
clear header

% ** new covDs might have different data range ??
header = bw_CTFGetHeader(covDsName);
covDataRange = [header.epochMinTime header.epochMaxTime];
clear header


s = sprintf('Data Parameters: %s', dsName);
set(f,'Name',s);

CANCEL_BUTTON = uicontrol('style','PushButton','units','normalized','Position',[0.535 0.1 0.12 0.08],'String','Cancel',...
   'FontSize',13,'ForegroundColor','black','callback',@cancel_callBack);
              
        function cancel_callBack(src,evt)
            params = init_params;  % undo changes                
            uiresume(gcbf);
        end

DEFAULT_BUTTON = uicontrol('style','pushbutton','units','normalized','position',[0.835 0.1 0.12 0.08],'string','Set to Default',...
    'fontsize',11,'Foregroundcolor','blue','callback',@default_callback);

    function default_callback(src,evt)
        
        t_params = bw_setDefaultParameters(char(dsName));
        params = t_params.beamformer_parameters;
        
        set(FILTER_CHECK,'value',1);
        set(FILTER_EDIT_MIN,'string',params.filter(1))
        set(FILTER_EDIT_MAX,'string',params.filter(2))
        set(REVERSE_CHECK,'value',params.useReverseFilter)
        
        set(FILTER_EDIT_MIN,'enable','on')
        set(FILTER_EDIT_MAX,'enable','on')
        set(REVERSE_CHECK,'enable','on')
        
%         set(COV_EDIT_MIN,'string',params.covWindow(1))
%         set(COV_EDIT_MAX,'string',params.covWindow(2))
%         set(COVDS_CHECK,'value',params.useCovDs)    
        
        set(BASELINE_EDIT_MIN,'string',params.baseline(1))
        set(BASELINE_EDIT_MAX,'string',params.baseline(2))
        set(BASELINE_CHECK,'value',params.useBaselineWindow)
        set(BASELINE_EDIT_MIN,'enable','off')
        set(BASELINE_EDIT_MAX,'enable','off')
        set(BASELINE_TITLE_MIN,'enable','off')
        set(BASELINE_TITLE_MAX,'enable','off')
        set(HDM_RADIO,'value',params.useHdmFile)
        set(SPHERE_RADIO,'value',~params.useHdmFile)
        set(SPHERE_EDIT_X,'string',params.sphere(1))
        set(SPHERE_EDIT_Y,'string',params.sphere(2))
        set(SPHERE_EDIT_Z,'string',params.sphere(3))
        set(HDM_EDIT,'enable','off');
        set(HDM_PUSH,'enable','off');
        set(SPHERE_EDIT_X,'enable','on');
        set(SPHERE_EDIT_Y,'enable','on');
        set(SPHERE_EDIT_Z,'enable','on');
        set(SPHERE_TITLE_X,'enable','on');
        set(SPHERE_TITLE_Y,'enable','on');
        set(SPHERE_TITLE_Z,'enable','on');
        set(NOISE_EDIT,'string',params.noise*1e15)
        reg_fT = sqrt(params.regularization) * 1e15;  %% convert to fT  RMS for edit box
        set(REG_EDIT,'string',reg_fT)
    end
    
%% CONTROLS AND CALLBACK FUNCTIONS

% FILTER

FILTER_TITLE=uicontrol('style','text','units','normalized','position',[0.03 0.895 0.15 0.04],...
        'String','Data Processing','FontWeight','b','FontSize',12,'BackgroundColor','white','foregroundcolor','blue');
% FILTER_BOX=annotation('rectangle','position',[0.01 0.74 0.48 0.18],'edgecolor','blue');
% 
FILTER_TITLE_MIN=uicontrol('style','text','units','normalized','position',[0.03 0.815 0.1 0.04],...
        'String','Highpass (Hz):','FontSize',12,'BackGroundColor','white');

FILTER_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.14 0.8 0.06 0.07],...
        'String', params.filter(1), 'FontSize', 12, 'BackGroundColor','white','callback',@filter_edit_min_callback);
    function filter_edit_min_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.filter(1)=1;
            set(FILTER_EDIT_MIN,'string',params.filter(1));
            params.filter(2)=50;
            set(FILTER_EDIT_MAX,'string',params.filter(2));
        else
        params.filter(1)=str2double(string_value);
        if params.filter(1) < 0
            params.filter(1)=0;
        end
        if params.filter(1) > sampleRate
            params.filter(1)=sampleRate;
        end
            set(FILTER_EDIT_MIN,'string',params.filter(1))
        end
    end

FILTER_TITLE_MAX=uicontrol('style','text','units','normalized','position',[0.21 0.815 0.1 0.04],...
        'String','Low Pass (Hz):','FontSize',12,'BackGroundColor','white');

FILTER_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.32 0.8 0.06 0.07],...
        'String',params.filter(2), 'FontSize', 12, 'BackGroundColor','white','callback',@filter_edit_max_callback);
    function filter_edit_max_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.filter(2)=50;
            set(FILTER_EDIT_MAX,'string',params.filter(2));
            params.filter(1)=1;
            set(FILTER_EDIT_MIN,'string',params.filter(1));
        else
        params.filter(2)=str2double(string_value);
        if params.filter(2) > sampleRate
            params.filter(2)=sampleRate;
        end
        if params.filter(2) < 0
            params.filter(2)=0;
        end
            set(FILTER_EDIT_MAX,'string',params.filter(2))
        end
    end

 
FILTER_CHECK=uicontrol('style','checkbox','units','normalized','position',[0.39 0.815 0.09 0.04],...
        'String','enable','BackGroundColor','white','FontSize',12,'Value',params.filterData,'callback',@filter_check_callback);
 
    function filter_check_callback(src,evt)
        val=get(src,'Value');
        if (val)
            params.filterData=1;
            set(FILTER_EDIT_MIN,'enable','on')
            set(FILTER_TITLE_MIN,'enable','on')
            set(FILTER_EDIT_MAX,'enable','on')
            set(FILTER_TITLE_MAX,'enable','on')
            
            set(FILTER_EDIT_MIN,'string',params.filter(1))
            set(FILTER_EDIT_MAX,'string',params.filter(2))

        else
            params.filterData=0;
            set(FILTER_EDIT_MIN,'enable','off')
            set(FILTER_TITLE_MIN,'enable','off')
            set(FILTER_EDIT_MAX,'enable','off')
            set(FILTER_TITLE_MAX,'enable','off')
        end
    end


REVERSE_CHECK=uicontrol('style','checkbox','units','normalized','position',[0.04 0.75 0.25 0.04],...
        'String','zero phase shift','BackGroundColor','white','FontSize',12,'Value',params.useReverseFilter,'callback',@reverse_check_callback);
 
    function reverse_check_callback(src,evt)
        params.useReverseFilter=get(src,'Value');
    end

% set initial state
set(FILTER_EDIT_MIN,'string',params.filter(1))
set(FILTER_EDIT_MAX,'string',params.filter(2))
set(REVERSE_CHECK,'value',params.useReverseFilter)

if params.filterData
    set(FILTER_CHECK,'value',1);
    set(FILTER_EDIT_MIN,'enable','on')
    set(FILTER_TITLE_MIN,'enable','on')
    set(FILTER_EDIT_MAX,'enable','on')
    set(FILTER_TITLE_MAX,'enable','on')
    set(REVERSE_CHECK,'enable','on')   
else
    set(FILTER_CHECK,'value',0);
    set(FILTER_EDIT_MIN,'enable','off')
    set(FILTER_TITLE_MIN,'enable','off')
    set(FILTER_EDIT_MAX,'enable','off')
    set(FILTER_TITLE_MAX,'enable','off')
    set(REVERSE_CHECK,'enable','off')   
end
    
% baseline window 
% uicontrol('style','text','units','normalized','position',[0.05 0.66 0.25 0.04],'horizontalAlignment','left',...
%         'String','Offset Removal (s)','fontsize',12,'backgroundcolor','white');
BASELINE_BOX=annotation('rectangle','position',[0.01 0.52 0.48 0.4],'edgecolor','blue');

BASELINE_TITLE_MIN=uicontrol('style','text','units','normalized','position',[0.03 0.58 0.1 0.04],...
        'String','Start (s):','FontSize',12,'BackGroundColor','white');

BASELINE_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.14 0.57 0.06 0.07],...
        'String', params.baseline(1), 'FontSize', 12, 'BackGroundColor','white','callback',@baseline_edit_min_callback);
    
    function baseline_edit_min_callback(src,evt)
        string_value=get(src,'String');          
        params.baseline(1)=str2double(string_value);
        if params.baseline(1) < dataRange(1) || params.baseline(1) > dataRange(2)
            params.baseline(1)=dataRange(1);
            set(BASELINE_EDIT_MIN,'string',params.baseline(1))
        end   
    end


BASELINE_TITLE_MAX=uicontrol('style','text','units','normalized','position',[0.21 0.58 0.1 0.04],...
        'String','End (s):','FontSize',12,'BackGroundColor','white');
BASELINE_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.32 0.57 0.06 0.07],...
        'String', params.baseline(2), 'FontSize', 12, 'BackGroundColor','white','callback',@baseline_edit_max_callback);
    function baseline_edit_max_callback(src,evt)
        string_value=get(src,'String');          
        params.baseline(2)=str2double(string_value);
        if params.baseline(2) < dataRange(1) || params.baseline(2) > dataRange(2)
            params.baseline(2)=dataRange(2);
            set(BASELINE_EDIT_MAX,'string',params.baseline(2))
        end   
    end

   
BASELINE_SET_FULL_BUTTON=uicontrol('style','pushbutton','units','normalized','position', [0.39 0.575 0.08 0.06],...
        'string', 'full range', 'FontSize', 12, ...
        'ForeGroundColor','blue','callback',@baseline_set_full_callback);

     function baseline_set_full_callback(src,evt)
        params.baseline(1) = dataRange(1);
        params.baseline(2) = dataRange(2);
        set(BASELINE_EDIT_MIN,'string',params.baseline(1))
        set(BASELINE_EDIT_MAX,'string',params.baseline(2))    
     end        
 
BASELINE_CHECK=uicontrol('style','checkbox','units','normalized','position',[0.03 0.65 0.18 0.04],...
        'String','Baseline Correction','BackGroundColor','white','FontSize',12,'Value',params.useBaselineWindow,'callback',@baseline_check_callback);
 
    function baseline_check_callback(src,evt)
        val=get(src,'Value');
        if (val)
           params.useBaselineWindow=1;
           set(BASELINE_SET_FULL_BUTTON,'enable','on')
           set(BASELINE_EDIT_MAX,'enable','on')
           set(BASELINE_EDIT_MIN,'enable','on')
           set(BASELINE_TITLE_MIN,'enable','on')
           set(BASELINE_TITLE_MAX,'enable','on')
           if params.baseline(1) < dataRange(1) || params.baseline(1) > dataRange(2)
                params.baseline(1)=dataRange(1);
           end
           if params.baseline(2) < dataRange(1) || params.baseline(2) > dataRange(2)
                params.baseline(2)=0.0;
           end     	    
           set(BASELINE_EDIT_MIN,'string',params.baseline(1))
           set(BASELINE_EDIT_MAX,'string',params.baseline(2))
        else
            params.useBaselineWindow = 0;     
            set(BASELINE_SET_FULL_BUTTON,'enable','off')
            set(BASELINE_EDIT_MIN,'enable','off')
            set(BASELINE_EDIT_MAX,'enable','off')
            set(BASELINE_TITLE_MIN,'enable','off')
            set(BASELINE_TITLE_MAX,'enable','off')
        end
    end


% set initial state
set(BASELINE_EDIT_MIN,'string',params.baseline(1))
set(BASELINE_EDIT_MAX,'string',params.baseline(2))
if params.useBaselineWindow==1
    set(BASELINE_SET_FULL_BUTTON,'enable','on')
    set(BASELINE_EDIT_MIN,'enable','on')
    set(BASELINE_EDIT_MAX,'enable','on')
    set(BASELINE_TITLE_MIN,'enable','on')
    set(BASELINE_TITLE_MAX,'enable','on')

else
    set(BASELINE_SET_FULL_BUTTON,'enable','off')
    set(BASELINE_EDIT_MIN,'enable','off')
    set(BASELINE_EDIT_MAX,'enable','off')
    set(BASELINE_TITLE_MIN,'enable','off')
    set(BASELINE_TITLE_MAX,'enable','off')
end


% Beamformer Parameters BOX

uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.04 0.39 0.25 0.04],...
        'String','Beamformer Type:','FontSize',12,'FontWeight','bold','BackGroundColor','white');

SCALAR_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.04 0.34 0.15 0.04],...
    'value',~params.rms,'string','Scalar','fontsize',12,'backgroundcolor','white','callback',@scalar_radio_callback);

VECTOR_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.16 0.34 0.15 0.04],...
    'value',params.rms,'string','Vector (LCMV)','fontsize',12,'backgroundcolor','white','callback',@vector_radio_callback);

    function scalar_radio_callback(src,evt)
        set(src,'value',1);
        set(VECTOR_RADIO,'value',0);
        params.rms = 0;
    end

    function vector_radio_callback(src,evt)
        set(src,'value',1);
        set(SCALAR_RADIO,'value',0);
        params.rms = 1;  
    end

uicontrol('style','text','units','normalized','position',[0.02 0.455 0.26 0.04],...
        'String','Beamformer Parameters','Fontweight','b','fontsize',12,'backgroundcolor','white','foregroundcolor','blue');
COV_BOX=annotation('rectangle','position',[0.01 0.03 0.48 0.45],'edgecolor','blue');

uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.04 0.25 0.25 0.04],...
        'String','ERB / VS Covariance Window:','FontSize',12,'FontWeight','bold','BackGroundColor','white');

COV_TITLE_MIN=uicontrol('style','text','units','normalized','position',[0.04 0.19 0.1 0.04],'horizontalAlignment','left',...
    'String','Start (s):','FontSize',12,'BackGroundColor','white');

COV_EDIT_MIN=uicontrol('style','edit','units','normalized','position', [0.12 0.18 0.08 0.07],...
    'String', params.covWindow(1), 'FontSize', 12, 'BackGroundColor','white','callback',@cov_edit_min_callback);

COV_TITLE_MAX=uicontrol('style','text','units','normalized','position',[0.21 0.19 0.1 0.04],'horizontalAlignment','left',...
    'String','End (s):','FontSize',12,'BackGroundColor','white');

COV_EDIT_MAX=uicontrol('style','edit','units','normalized','position', [0.28 0.18 0.08 0.07],...
    'String', params.covWindow(2), 'FontSize', 12, 'BackGroundColor','white','callback',@cov_edit_max_callback);

COV_SET_FULL_BUTTON=uicontrol('style','pushbutton','units','normalized','position', [0.39 0.19 0.08 0.06],...
        'string', 'full range', 'FontSize', 12, ...
        'ForeGroundColor','blue','callback',@cov_set_full_callback);
    
    function cov_edit_min_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.covWindow(2)=covDataRange(2);
            set(COV_EDIT_MAX,'string',params.covWindow(2));
            params.covWindow(1)=covDataRange(1);
            set(COV_EDIT_MIN,'string',params.covWindow(1));
            
        else
        params.covWindow(1)=str2double(string_value);
        if params.covWindow(1) < covDataRange(1)
            params.covWindow(1)=covDataRange(1);
        end
        if params.covWindow(1) > covDataRange(2)
            params.covWindow(1)=covDataRange(2);
        end
            set(COV_EDIT_MIN,'string',params.covWindow(1))
        end
    end

  
    function cov_edit_max_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.covWindow(1)=covDataRange(1);
            set(COV_EDIT_MIN,'string',params.covWindow(1));
            params.covWindow(2)=covDataRange(2);
            set(COV_EDIT_MAX,'string',params.covWindow(2));
        else
        params.covWindow(2)=str2double(string_value);
        if params.covWindow(2) > covDataRange(2)
            params.covWindow(2)=covDataRange(2);
        end
        if params.covWindow(2) < covDataRange(1)
            params.covWindow(2)=covDataRange(1);
        end
            set(COV_EDIT_MAX,'string',params.covWindow(2))
        end
    end


     function cov_set_full_callback(src,evt)
        params.covWindow(1) = covDataRange(1);
        params.covWindow(2) = covDataRange(2);
        set(COV_EDIT_MIN,'string',params.covWindow(1))
        set(COV_EDIT_MAX,'string',params.covWindow(2))    
     end        

    
% note params.regulalarization holds the power (in Telsa squared) to add to diagonal    
reg_fT = sqrt(params.regularization) * 1e15;  %% convert to fT  RMS for edit box

REG_CHECK=uicontrol('style','checkbox','units','normalized','position',[0.05 0.08 0.25 0.04],'String','Apply diagonal regularization:',...
        'BackGroundColor','white','FontSize',10,'fontname','lucinda','Value',params.useRegularization,'callback',@reg_check_callback);
    function reg_check_callback(src,evt)
        val=get(src,'Value');
        if (val)
            params.useRegularization=1;
            set(REG_EDIT,'enable','on')
        else
            params.useRegularization=0;
            set(REG_EDIT,'enable','off')
        end
    end
     
REG_EDIT=uicontrol('style','edit','units','normalized','position', [0.29 0.07 0.05 0.07],...
        'String', reg_fT, 'FontSize', 12, 'BackGroundColor','white','callback',@reg_edit_callback);
    function reg_edit_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.regularization=0;
            set(REG_EDIT,'string',params.regularization);
        else
            reg_fT = str2double(string_value);            
            params.regularization = (reg_fT * 1e-15)^2; % convert from fT squared to Tesla squared 
        end
    end

uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.35 0.075 0.12 0.04],...
        'String','fT / sqrt(Hz)','FontSize',12,'BackGroundColor','white');
 
        
% HEAD MODEL BOX
HEADMODEL_TITLE=uicontrol('style','text','units','normalized','position',[0.52 0.895 0.1 0.04],...
        'String','Head Model','FontSize',12,'BackGroundColor','white','Fontweight','b','foregroundcolor','blue');
    
HDM_EDIT=uicontrol('style','edit','units','normalized','position', [0.55 0.75 0.3 0.07],...
        'String', params.hdmFile, 'FontSize', 12, 'BackGroundColor','white','callback',@hdm_edit_callback);
    function hdm_edit_callback(src,evt)
        params.hdmFile=get(src,'String');
        if isempty(params.hdmFile)
             params.hdmFile='';
        end
    end

HDM_PUSH=uicontrol('style','pushbutton','units','normalized','position',[0.86 0.755 0.1 0.06],...
        'String','Browse','FontSize',12,'callback',@HDM_PUSH_CALLBACK);

    function HDM_PUSH_CALLBACK(src,evt)
        
    s = fullfile(char(dsName),'*.hdm');
    [hdmfilename,hdmpathname,garbage] = uigetfile('*.hdm','Select a Head Model (.hdm) file', s);
       if isequal(hdmfilename,0) || isequal(hdmpathname,0)
          %cancelled
       else
            dsPath = char(dsName);
            hdmPath = hdmpathname(1:end-1);
            hdmFile = fullfile(hdmpathname,hdmfilename);
            if ~strcmp(dsPath,hdmPath)
                s = sprintf('Copy headmodel file %s to the current dataset?', hdmFile);
                answer = bw_warning_dialog(s);
                if answer == 0            
                    return;
                else
                    s = sprintf('cp %s %s', hdmFile, dsPath);
                    system(s);
                end
            end
            params.hdmFile=hdmfilename;

            set(HDM_EDIT,'string',hdmfilename)
            if isempty(params.hdmFile)
                params.hdmFile='';
            end
       end
    end
        
SPHERE_EDIT_X=uicontrol('style','edit','units','normalized','position', [0.57 0.56 0.1 0.07],...
        'String', params.sphere(1), 'FontSize', 12, 'BackGroundColor','white','callback',@sphere_edit_x_callback);
    function sphere_edit_x_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.sphere(1));
            params.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.sphere(2));
            params.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.sphere(3));
        else
        params.sphere(1)=str2double(string_value);
        end
    end
    SPHERE_TITLE_X=uicontrol('style','text','units','normalized','position',[0.545 0.575 0.02 0.04],...
       'String','X:','FontSize',12,'BackGroundColor','white');
 
SPHERE_EDIT_Y=uicontrol('style','edit','units','normalized','position', [0.71 0.56 0.1 0.07],...
        'String', params.sphere(2), 'FontSize', 12, 'BackGroundColor','white','callback',@sphere_edit_y_callback);
    function sphere_edit_y_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.sphere(1));
            params.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.sphere(2));
            params.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.sphere(3));
        else
        params.sphere(2)=str2double(string_value);
        end
    end
SPHERE_TITLE_Y=uicontrol('style','text','units','normalized','position',[0.685 0.575 0.02 0.04],...
        'String','Y:','FontSize',12,'BackGroundColor','white');
       
SPHERE_EDIT_Z=uicontrol('style','edit','units','normalized','position', [0.85 0.56 0.1 0.07],...
        'String', params.sphere(3), 'FontSize', 12, 'BackGroundColor','white','callback',@sphere_edit_z_callback);
    function sphere_edit_z_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.sphere(1)=0;
            set(SPHERE_EDIT_X,'string',params.sphere(1));
            params.sphere(2)=0;
            set(SPHERE_EDIT_Y,'string',params.sphere(2));
            params.sphere(3)=5;
            set(SPHERE_EDIT_Z,'string',params.sphere(3));
        else
        params.sphere(3)=str2double(string_value);
        end
    end
    SPHERE_TITLE_Z=uicontrol('style','text','units','normalized','position',[0.825 0.575 0.02 0.04],...
        'String','Z:','FontSize',12,'BackGroundColor','white');
    
HEADMODEL_BOX=annotation('rectangle','position',[0.51 0.52 0.48 0.4],'edgecolor','blue');    
    
    
    
% NOISE NORMALIZATION
% add variance normalization ??

noisedisplay=params.noise*1e15;
    
NOISE_TITLE=uicontrol('style','text','units','normalized','position',[0.52 0.455 0.2 0.04],...
        'String','Beamformer Normalization','FontSize',12,'BackGroundColor','white',...
        'fontweight','b','foregroundcolor','blue');

NOISE_TXT=uicontrol('style','text','units','normalized','HorizontalAlignment','Left','position',[0.68 0.335 0.1 0.07],...
        'String','RMS Noise:','FontSize',12,'BackGroundColor','white','foregroundcolor','black');
NOISE_UNITS=uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.85 0.335 0.12 0.07],...
        'String','fT / sqrt(Hz)','FontSize',12,'BackGroundColor','white','foregroundcolor','black');
NOISE_EDIT=uicontrol('style','edit','units','normalized','position', [0.77 0.355 0.07 0.07],...
        'String',noisedisplay , 'FontSize', 12, 'BackGroundColor','white','callback',@noise_edit_callback);
    function noise_edit_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.noise=3e-15;
            set(NOISE_EDIT,'string',3)
        else
            params.noise=str2double(string_value)*1e-15;
        end
    end

% only one normalization method currently - could add here variance
% normalization etc...
NOISE_Z_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.55 0.37 0.13 0.04],...
    'value',1,'string','Pseudo-Z','fontsize',12,'backgroundcolor','white','callback',@noise_z_radio_callback);
    function noise_z_radio_callback(src,evt)
        set(NOISE_Z_RADIO,'value',1);
    end
NOISE_BOX=annotation('rectangle','position',[0.51 0.3 0.48 0.18],'edgecolor','blue');
    
HDM_RADIO=uicontrol('style','radio','units','normalized','position',[0.55 0.83 0.3 0.04],...
    'string','Use Head Model File (*.hdm):','Fontsize',12,'Backgroundcolor','white','value',params.useHdmFile,'callback',@hdm_radio_callback);
    function hdm_radio_callback (src,evt)
    params.useHdmFile=1;
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

SPHERE_RADIO=uicontrol('style','radio','units','normalized','position',[0.55 0.64 0.3 0.04],...
    'string','Use Single Sphere Origin (cm):','Fontsize',12,'Backgroundcolor','white','value',~params.useHdmFile,'callback',@sphere_radio_callback);
    function sphere_radio_callback(src,evt)
    params.useHdmFile=0;
    set(HDM_RADIO,'value',0);
    set(HDM_EDIT,'enable','off');
    set(HDM_PUSH,'enable','off');
    set(SPHERE_EDIT_X,'enable','on');
    set(SPHERE_EDIT_Y,'enable','on');
    set(SPHERE_EDIT_Z,'enable','on');
    set(SPHERE_TITLE_X,'enable','on');
    set(SPHERE_TITLE_Y,'enable','on');
    set(SPHERE_TITLE_Z,'enable','on');
    if isempty(params.sphere)
        params.sphere=[0 0 5];
    end
    set(SPHERE_EDIT_X,'string',params.sphere(1));
    set(SPHERE_EDIT_Y,'string',params.sphere(2));
    set(SPHERE_EDIT_Z,'string',params.sphere(3));
       
    end    

% set initial state
set(HDM_RADIO,'value',params.useHdmFile);
set(HDM_RADIO,'value',params.useHdmFile);
set(SPHERE_EDIT_X,'string',params.sphere(1));
set(SPHERE_EDIT_Y,'string',params.sphere(2));
set(SPHERE_EDIT_Z,'string',params.sphere(3));

if params.useHdmFile
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

if params.useRegularization
    set(REG_EDIT,'enable','on');
else
    set(REG_EDIT,'enable','off');
end


% %  

%% PAUSES MATLAB
 uiwait(gcf);
%% CLOSES GUI
    if ishandle(f)
        close(f);  
    end












end