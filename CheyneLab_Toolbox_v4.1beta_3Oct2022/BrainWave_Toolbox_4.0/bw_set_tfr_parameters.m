function params = bw_set_tfr_parameters(oldpar, dsName)
%       BW_SET_TFR_PARAMETERS
%
%   function params = bw_set_tfr_parameters(oldpar)
%
%   DESCRIPTION: Creates a GUI that allow users to set a series of
%   parameters related to creating TFR plots. The variable oldpar is the
%   values perviously set for the parameters while params returns the new
%   values.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%
%   --VERSION 4.0--
% Last Revised by N.v.L. on 06/07/2010
% Major Changes: Change the name to set_tfr_parameters, edited the help
% file, made RAW stuff always appear, etc.
%
% Revised by N.v.L. on 23/06/2010
% Major Changes: Changed the help file.
%
% Revised by N.v.L. on 03/06/2010
% Major Changes: Changed name from bw_set_params_same to
% bw_set_vs_parameters. Added in boxes and rearranged all the uicontrols on
% the figure.
%
% Revised by N.v.L. on 27/05/2010
% Major Changes: Instead of becoming visible or not, options to be selected
% when raw is selected now become enabled or disabled. Also changed how the
% save button looks.
%
% Revised by N.v.L on 26/05/2010
% Major Changes: Completely rewrote the file so that it sets up to
% bw_vs_defaults and then lets you edit them in a GUI instead of making
% them the same as the passed bw_beamformer_defaults.
%
% Written by N.v.L. on 21/05/2010 for the Hospital for Sick Children.
%


%% CREATE FIGURE

button_color = [1,1,1];

scrnsizes=get(0,'MonitorPosition');

f=figure('color','white','name','Time-Frequency Options','numbertitle','off',...
        'menubar','none','position',[scrnsizes(1,3)/3 scrnsizes(1,4)/2 680 300]);
   
%SAVES PARAMS
SAVE_BUTTON = uicontrol('Units','Normalized','Position',[0.28 0.08 0.12 0.12],'String','OK',...
      'BackgroundColor',[0.99,0.64,0.3],'FontSize',13,'ForegroundColor','black','FontWeight','b','Callback',@save_callBack); 


CANCEL_BUTTON = uicontrol('Units','Normalized','Position',[0.08 0.08 0.14 0.12],'String','Cancel',...
      'BackgroundColor','white','FontSize',13,'ForegroundColor','black','Callback',@cancel_callBack);
  
    function cancel_callBack(src,evt)
            params = oldpar;  % undo changes
            uiresume(gcbf); 
    end

    function save_callBack(src,evt)
            string_value=get(BASELINE_START_EDIT,'String');
            params.baseline(1)=str2double(string_value);
            string_value=get(BASELINE_END_EDIT,'String');
            params.baseline(2)=str2double(string_value);            
            uiresume(gcbf); 
    end

DEFAULT_BUTTON = uicontrol('units','normalized','position',[0.55 0.08 0.19 0.12],'string','Set to Default',...
    'backgroundcolor','white','fontsize',10,'foregroundcolor','blue','callback',@default_callback);

    function default_callback(src,evt)

        [junk junk tfr_defaults] = bw_setDefaultParameters;        

        params.freqStep=tfr_defaults.freqStep;
        params.fOversigmafRatio=tfr_defaults.fOversigmafRatio;
        params.plotType=tfr_defaults.plotType;   
        params.plotUnits = tfr_defaults.plotUnits;
        params.saveSingleTrials = tfr_defaults.saveSingleTrials;
        
        ctf_params=bw_CTFGetParams(dsName);      
        ctfmin = ctf_params(12); % in s   
        ctfmax = ctf_params(13); % in s
        params.baseline=[ctfmin ctfmax];
        set(BASELINE_START_EDIT,'string', num2str(params.baseline(1)));
        set(BASELINE_END_EDIT,'string', num2str(params.baseline(2)));
        set(SAVE_SINGLE_CHECK,'value',params.saveSingleTrials); 
        

        set(FREQ_STEP_EDIT,'string',params.freqStep)
        set(F_OVER_SIGMA_F_RATIO_EDIT,'string',params.fOversigmafRatio)


        set(RADIO_PLOT_POWER,'value',1);
        set(RADIO_PLOT_SUBTRACTION,'value',0);
        set(RADIO_PLOT_AVERAGE,'value',0);
        set(RADIO_PLOT_PLF,'value',0); 


        % need single trial VS data...
        params.raw=1;
    
    end
    
%% INITIALIZE VARIABLES       
   
params.freqStep=oldpar.freqStep;
params.fOversigmafRatio=oldpar.fOversigmafRatio;
params.plotType = oldpar.plotType;
params.plotUnits = oldpar.plotUnits;
params.baseline = oldpar.baseline;
params.saveSingleTrials = oldpar.saveSingleTrials;


FREQ_STEP_TITLE=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.79 0.38 0.06],'String','Freq. Bin Size (Hz)','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black');    
FREQ_STEP_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.32 0.77 0.1 0.1],'String', params.freqStep, 'FontSize', 12,...
          'BackGroundColor','white','callback',@freq_step_edit_callback);
    function freq_step_edit_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.freqStep=1;
            set(FREQ_STEP_EDIT,'string',params.freqStep);
        else
            params.freqStep=str2double(string_value);
        end
    end

F_OVER_SIGMA_F_RATIO_TITLE=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
    [0.05 0.68 0.41 0.06],'String','Morlet Width (cycles)',...
        'FontSize',12,'BackGroundColor','white','foregroundcolor','black');
    
F_OVER_SIGMA_F_RATIO_EDIT=uicontrol('style','edit','units','normalized',...
        'position', [0.32 0.66 0.1 0.1],'String', params.fOversigmafRatio,...
        'FontSize', 12, 'BackGroundColor','white','callback',...
        @f_over_sigma_f_ratio_edit_callback);
    function f_over_sigma_f_ratio_edit_callback(src,evt)
        string_value=get(src,'String');
        if isempty(string_value)
            params.fOversigmafRatio=7;
            set(F_OVER_SIGMA_F_RATIO_EDIT,'string',params.fOversigmafRatio);
        else
            params.fOversigmafRatio=str2double(string_value);
        end
    end
    

% TFR now has own baseline values

BASELINE_TITLE1=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.54 0.35 0.06],'String','TFR Baseline Window (s):','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black');  

BASELINE_TITLE2=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.445 0.18 0.06],'String','Start:','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black');  
   
BASELINE_TITLE3=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.28 0.445 0.08 0.06],'String','End:','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black'); 
    
BASELINE_START_EDIT=uicontrol('style','edit','units','normalized','position',...
      [0.12 0.42 0.12 0.1],'String', params.baseline(1), 'FontSize', 12,...
      'BackGroundColor','white');
    
BASELINE_END_EDIT=uicontrol('style','edit','units','normalized','position',...
      [0.34 0.42 0.12 0.1],'String', params.baseline(2), 'FontSize', 12,...
          'BackGroundColor','white');

SAVE_SINGLE_CHECK=uicontrol('style','checkbox','units','normalized','horizontalalignment','left','position',...
        [0.05 0.30 0.38 0.06],'String','   Save Single Trial Magn. / Phase','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black','value',params.saveSingleTrials, 'callback',@SAVE_SINGLE_CALLBACK);    
      

OPTIONS_TITLE=uicontrol('style','text','units','normalized','position',...
    [0.04 0.88 0.1 0.06],'string','Options','backgroundcolor','white',...
    'fontsize',12,'fontweight','b','foregroundcolor','blue');

OPTIONS_BOX=annotation('rectangle','position',[0.03 0.23 0.45 0.68],'edgecolor','blue');


    % PLOT TYPE
RADIO_PLOT_POWER=uicontrol('style','radiobutton','units','normalized','fontsize',12,'position',[0.54 0.75 0.35 0.06],...
    'string',' Plot Total Power','backgroundcolor','white','value',0,'callback',@RADIO_POWER_CALLBACK);
RADIO_PLOT_SUBTRACTION=uicontrol('style','radiobutton','units','normalized','fontsize',12,'position',[0.54 0.60 0.35 0.06],...
    'string',' Plot Power minus Average','backgroundcolor','white','value',0,'callback',@RADIO_SUB_CALLBACK);
RADIO_PLOT_AVERAGE=uicontrol('style','radiobutton','units','normalized','fontsize',12,'position',[0.54 0.45 0.35 0.06],...
    'string',' Plot Average','backgroundcolor','white','value',0,'callback',@RADIO_AVE_CALLBACK);
RADIO_PLOT_PLF=uicontrol('style','radiobutton','units','normalized','fontsize',12,'position',[0.54 0.30 0.35 0.06],...
    'string',' Plot Phase-locking Factor','backgroundcolor','white','value',0,'callback',@RADIO_PLF_CALLBACK);
    function RADIO_POWER_CALLBACK(src,evt)
        set(RADIO_PLOT_POWER,'value',1);
        set(RADIO_PLOT_SUBTRACTION,'value',0);
        set(RADIO_PLOT_AVERAGE,'value',0);
        set(RADIO_PLOT_PLF,'value',0);
        params.plotType = 0;
        
    end
    function RADIO_SUB_CALLBACK(src,evt)
        set(RADIO_PLOT_POWER,'value',0);
        set(RADIO_PLOT_SUBTRACTION,'value',1);
        set(RADIO_PLOT_AVERAGE,'value',0);
        set(RADIO_PLOT_PLF,'value',0);
        params.plotType = 1;
        
    end
    function RADIO_AVE_CALLBACK(src,evt)
        set(RADIO_PLOT_POWER,'value',0);
        set(RADIO_PLOT_SUBTRACTION,'value',0);
        set(RADIO_PLOT_AVERAGE,'value',1);
        set(RADIO_PLOT_PLF,'value',0);
        params.plotType = 2;
        
    end
    function RADIO_PLF_CALLBACK(src,evt)
        set(RADIO_PLOT_POWER,'value',0);
        set(RADIO_PLOT_SUBTRACTION,'value',0);
        set(RADIO_PLOT_AVERAGE,'value',0);
        set(RADIO_PLOT_PLF,'value',1);
        params.plotType = 3; 
    end

    function SAVE_SINGLE_CALLBACK(src,evt)
        params.saveSingleTrials = get(src,'value');     
    end

PLOT_MODE_TITLE=uicontrol('style','text','units','normalized','position',...
    [0.53 0.88 0.15 0.06],'string','Plot Type:','backgroundcolor','white',...
    'fontsize',12,'fontweight','b','foregroundcolor','blue');
PLOT_MODE_BOX=annotation('rectangle','position',[0.53 0.23 0.4 0.68],'edgecolor','blue');

if params.plotType == 0
    set(RADIO_PLOT_POWER,'value',1);
elseif params.plotType == 1
    set(RADIO_PLOT_SUBTRACTION,'value',1);
elseif params.plotType == 2
    set(RADIO_PLOT_AVERAGE,'value',1);
elseif params.plotType == 3
    set(RADIO_PLOT_PLF,'value',1);
end

%% PAUSES MATLAB
 uiwait(gcf);
%% CLOSES GUI
  if ishandle(f)
    close(f);  
  end
    
    
    
    
    
end