function [vs_params] = bw_set_vs_options(init_vs_params)
%       BW_SET_VS_OPTIONS
%
%   function [options] = bw_set_vs_options(initial_options)
%
%   DESCRIPTION: Creates a GUI that allow users to set some options for
%   virtual sensor calculations
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
    scrnsizes=get(0,'MonitorPosition');

    fg=figure('color','white','name','Virtual Sensor Options','numbertitle','off',...
        'menubar','none','position',[scrnsizes(1,3)/3 scrnsizes(1,4)/2 600 500]);
            
    if ~exist('init_vs_params','var')
        [xx init_vs_params zz] = bw_setDefaultParameters();
    end
    
    if isempty(init_vs_params)
        [xx init_vs_params zz] = bw_setDefaultParameters();
    end
    
    vs_params = init_vs_params;

    OUTPUT2_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
        [0.05 0.75 0.2 0.15],'String','VS Units:','BackgroundColor','White','FontSize',12,'HorizontalAlignment','Left');
    MOMENT_RADIO=uicontrol('style','radiobutton','units','normalized','position',...
        [0.23 0.82 0.3 0.12],'string','Moment','backgroundcolor','white','value',~vs_params.pseudoZ,'callback',@MOMENT_RADIO_CALLBACK);
    PSEUDOZ_RADIO=uicontrol('style','radiobutton','units','normalized','position',...
        [0.4 0.82 0.3 0.12],'string','Pseudo-Z','backgroundcolor','white','value',vs_params.pseudoZ,'callback',@PSEUDOZ_RADIO_CALLBACK);

    AUTOFLIP_CHECK = uicontrol('Style','checkbox','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.05 0.73 0.25 0.12],'val',vs_params.autoFlip,'String','Make amplitude positive at:','BackgroundColor','White', 'Callback',@AUTOFLIP_CHECK_CALLBACK);
    AUTOFLIP_TEXT1 = uicontrol('Style','text','Units','Normalized','Position',...
        [0.42 0.73 0.1 0.08],'String','seconds','BackgroundColor','White','HorizontalAlignment','Left');
    AUTOFLIP_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.32 0.75 0.1 0.08],'String',num2str(vs_params.autoFlipLatency),'BackgroundColor','White');

    
    
% ******** should set option in Data Parameters ????
    
    RMS_CHECK = uicontrol('Style','checkbox','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.05 0.64 0.35 0.12],'val',vs_params.rms,'String','Use RMS beamformer','BackgroundColor','White', 'Callback',@USE_RMS_CALLBACK);

    SAVE_SINGLE_TRIALS = uicontrol('Style','checkbox','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.05 0.56 0.35 0.12],'val',vs_params.saveSingleTrials,'String','Generate single trial data','BackgroundColor','White', 'Callback',@SAVE_SINGLE_TRIALS_CALLBACK);

    
    box1=annotation('rectangle',[0.02 0.58 0.68 0.38],'EdgeColor','blue');
	box1text=uicontrol('style','text','fontsize',11,'units','normalized','Position',...
    [0.06 0.92 0.16 0.05],'string','VS Options','BackgroundColor','white','foregroundcolor','blue','fontweight','b');


    if ~vs_params.autoFlip
        set(AUTOFLIP_EDIT,'enable','off');
        set(AUTOFLIP_TEXT1,'enable','off');
    end
   
    if vs_params.rms
        set(AUTOFLIP_CHECK,'enable','off');
    end
               
    
    
    % talaiarch option
 
       
    TAL_OPTIONS_TEXT =uicontrol('style','text','fontsize',11,'units','normalized',...
        'position', [0.03 0.49 0.28 0.05],'string','Talairach Options','BackgroundColor','white',...
       'foregroundcolor','blue','fontweight','b');

    box1=annotation('rectangle',[0.02 0.05 0.9 0.48],'EdgeColor','blue');
  

    RADIO_EXACT=uicontrol('style','radiobutton','units','normalized','position',[0.05 0.39 0.3 0.15],...
        'string','Use exact coordinates','backgroundcolor','white','callback',@RADIO_EXACT_CALLBACK);
    
    RADIO_SEARCH=uicontrol('style','radiobutton','units','normalized','position',[0.05 0.31 0.4 0.15],...
        'string','Find largest peak within','backgroundcolor','white','callback',@RADIO_SEARCH_CALLBACK);

    SR_TEXT1 = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.3 0.22 0.2 0.08],'String','at latency:','BackgroundColor','White');
    
    SR_TEXT2 = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.58 0.22 0.2 0.08],'String','seconds:','BackgroundColor','White');
 
    SR_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.35 0.35 0.1 0.08],'String',num2str(vs_params.searchRadius),'BackgroundColor','White');    
    SR_TEXT3 = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.48 0.33 0.4 0.08],'String','mm search radius using:','BackgroundColor','White');

    SR_LATENCY_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.45 0.24 0.1 0.08],'String',num2str(vs_params.searchLatency),'BackgroundColor','White');    
    
    SR_TEXT4 = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
        [0.3 0.16 0.3 0.05],'String','Active Window (s):','Background','White','HorizontalAlignment','Left');

    SR_TEXT5 = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
        [0.6 0.16 0.3 0.05],'String','Baseline Window (s):','Background','White','HorizontalAlignment','Left');

    ACTIVE_START_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.3 0.08 0.1 0.08],'String',num2str(vs_params.searchActiveWindow(1)),'BackgroundColor','White');
    
    ACTIVE_END_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.45 0.08 0.1 0.08],'String',num2str(vs_params.searchActiveWindow(2)),'BackgroundColor','White');

    SR_TEXT6 = uicontrol('Style','text','FontSize',12,'Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.41 0.06 0.03 0.08],'String','to','BackgroundColor','White');

    BASELINE_START_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.6 0.08 0.1 0.08],'String',num2str(vs_params.searchBaselineWindow(1)),'BackgroundColor','White');
    
    BASELINE_END_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.75 0.08 0.1 0.08],'String',num2str(vs_params.searchBaselineWindow(2)),'BackgroundColor','White');

    SR_TEXT7 = uicontrol('Style','text','FontSize',12,'Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.71 0.08 0.03 0.06],'String','to','BackgroundColor','White');

    RADIO_ERB=uicontrol('style','radiobutton','units','normalized','position',[0.12 0.25 0.16 0.05],...
        'string','ERB','backgroundcolor','white','callback',@RADIO_ERB_CALLBACK);

    RADIO_T=uicontrol('style','radiobutton','units','normalized','position',[0.12 0.15 0.16 0.05],...
        'string','Pseudo-T','backgroundcolor','white','callback',@RADIO_T_CALLBACK);

    RADIO_F=uicontrol('style','radiobutton','units','normalized','position',[0.12 0.08 0.16 0.05],...
        'string','Pseudo-F','backgroundcolor','white','callback',@RADIO_F_CALLBACK);

   function RADIO_EXACT_CALLBACK(src,evt)
        vs_params.useSR = 0;
        updateRadios;
    end    

    function RADIO_SEARCH_CALLBACK(src,evt)
        vs_params.useSR = 1;
        updateRadios;
    end   

    function RADIO_ERB_CALLBACK(src,evt)
        vs_params.searchMethod = 'ERB';
        updateRadios;
    end

    function RADIO_T_CALLBACK(src,evt)
        vs_params.searchMethod = 'T';
        updateRadios; 
    end

    function RADIO_F_CALLBACK(src,evt)
        vs_params.searchMethod = 'F';
        updateRadios;
   
    end   
 
    % set initial state 
    updateRadios;

    
    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.8 0.2 0.1],'string','OK','BackgroundColor',[0.99,0.64,0.3],...
        'foregroundcolor','black','callback',@ok_callback);
 
    cancel=uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.6 0.2 0.1],'string','Cancel','backgroundcolor','white',...
        'foregroundcolor','black','callback',@cancel_callback);

    
    function MOMENT_RADIO_CALLBACK(src,evt)
        vs_params.pseudoZ=0;
        set(PSEUDOZ_RADIO,'value',0)
        set(MOMENT_RADIO,'value',1)
    end

    function PSEUDOZ_RADIO_CALLBACK(src,evt)
        vs_params.pseudoZ=1;
        set(PSEUDOZ_RADIO,'value',1)
        set(MOMENT_RADIO,'value',0)
    end
    
    
    function AUTOFLIP_CHECK_CALLBACK(src,evt)
        vs_params.autoFlip = get(src,'val');
        
        if vs_params.autoFlip
            set(AUTOFLIP_EDIT,'enable','on');
            set(AUTOFLIP_TEXT1,'enable','on');
        else
            set(AUTOFLIP_EDIT,'enable','off');
            set(AUTOFLIP_TEXT1,'enable','off');
        end
        
    end

    function SAVE_SINGLE_TRIALS_CALLBACK(src,evt)
        vs_params.saveSingleTrials = get(src,'val'); 
    end

    function USE_RMS_CALLBACK(src,evt)
        vs_params.rms = get(src,'val'); 
        
        if vs_params.rms
            set(AUTOFLIP_CHECK,'enable','off');
        else
            set(AUTOFLIP_CHECK,'enable','on');
        end        
    end

    function updateRadios
        
        if vs_params.useSR
            set(RADIO_EXACT,'value',0)
            set(RADIO_SEARCH,'value',1)
            set(RADIO_ERB,'enable','on')
            set(RADIO_T,'enable','on')
            set(RADIO_F,'enable','on')
        else
            set(RADIO_EXACT,'value',1)
            set(RADIO_SEARCH,'value',0)
            set(RADIO_ERB,'enable','of')
            set(RADIO_T,'enable','of')
            set(RADIO_F,'enable','of')
        end
        if vs_params.searchMethod == 'ERB'
            set(RADIO_ERB,'value',1)
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',0)
        elseif vs_params.searchMethod == 'T'
            set(RADIO_ERB,'value',0)
            set(RADIO_T,'value',1)
            set(RADIO_F,'value',0)
        elseif vs_params.searchMethod == 'F'
            set(RADIO_ERB,'value',0)
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',1)
        end
        
        if (vs_params.useSR)
            set(SR_EDIT,'enable','on')
            if vs_params.searchMethod == 'ERB'
                set(SR_LATENCY_EDIT,'enable','on')
                set(ACTIVE_START_EDIT,'enable','off');
                set(ACTIVE_END_EDIT,'enable','off');
                set(BASELINE_START_EDIT,'enable','off');
                set(BASELINE_END_EDIT,'enable','off');        
            else
                set(SR_LATENCY_EDIT,'enable','off')
                set(ACTIVE_START_EDIT,'enable','on');
                set(ACTIVE_END_EDIT,'enable','on');
                set(BASELINE_START_EDIT,'enable','on');
                set(BASELINE_END_EDIT,'enable','on');        
            end 
            set(SR_TEXT1,'enable','on');
            set(SR_TEXT2,'enable','on');
            set(SR_TEXT3,'enable','on');
            set(SR_TEXT4,'enable','on');
            set(SR_TEXT5,'enable','on');
            set(SR_TEXT6,'enable','on');
            set(SR_TEXT7,'enable','on');
        else
            set(SR_EDIT,'enable','off')
            set(SR_LATENCY_EDIT,'enable','off')
            set(ACTIVE_START_EDIT,'enable','off');
            set(ACTIVE_END_EDIT,'enable','off');
            set(BASELINE_START_EDIT,'enable','off');
            set(BASELINE_END_EDIT,'enable','off');   
            
            set(SR_TEXT1,'enable','off');
            set(SR_TEXT2,'enable','off');
            set(SR_TEXT3,'enable','off');
            set(SR_TEXT4,'enable','off');
            set(SR_TEXT5,'enable','off');
            set(SR_TEXT6,'enable','off');
            set(SR_TEXT7,'enable','off');
        end
    end

    
    function ok_callback(src,evt)

        if vs_params.autoFlip
            strval = get(AUTOFLIP_EDIT,'String');
            vs_params.autoFlipLatency = str2double(strval);
        end
        
        if vs_params.useSR
            strval = get(SR_EDIT,'String');
            vs_params.searchRadius = str2double(strval);
            if vs_params.searchMethod == 'ERB'
                strval = get(SR_LATENCY_EDIT,'String');
                vs_params.searchLatency = str2double(strval);
            else
                strval = get(ACTIVE_START_EDIT,'String');
                vs_params.searchActiveWindow(1) = str2double(strval);
                strval = get(ACTIVE_END_EDIT,'String');
                vs_params.searchActiveWindow(2) = str2double(strval);
                strval = get(BASELINE_START_EDIT,'String');
                vs_params.searchBaselineWindow(1) = str2double(strval);
                strval = get(BASELINE_END_EDIT,'String');
                vs_params.searchBaselineWindow(2) = str2double(strval);
            end
        end

        uiresume(gcf);
    end
  
   function cancel_callback(src,evt)
        % pass empty array to indicate user cancelled       
        uiresume(gcf);
    end    
    
    %%PAUSES MATLAB
    uiwait(gcf);
    
    %%CLOSES GUI
    if ishandle(fg)
        close(fg);   
    end

end