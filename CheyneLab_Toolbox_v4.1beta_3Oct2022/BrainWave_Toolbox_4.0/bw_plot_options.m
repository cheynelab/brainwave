function [peak_voxel, params, vs_params, tfr_params] = bw_plot_options(voxel, orientation, dsName, tal_flag, tfr_flag, ...
    init_params, init_vs_params, init_tfr_params)
%
%   function [options] = bw_vs_options(initial_options)
%
%   DESCRIPTION: Creates a GUI that allow users to set some options for
%   virtual sensor calculations
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%
% April 15, 2014 - combines bw_set_vs_options and bw_set_tfr_options into
% one dialog w/ reduced parameters for plotting directly from image plot
% tfr parameters are also reduced to freq step and cycles and added to
% vs_options struct
% 
% Aug 2014 - pass VS coordinates so they can be manipulated / edited here...

    scrnsizes=get(0,'MonitorPosition');
    button_orange = [0.8,0.4,0.1];

    fg=figure('color','white','name','Plot Virtual Sensor','numbertitle','off',...
        'menubar','none','position',[scrnsizes(1,3)/3 scrnsizes(1,4)/2 700 600],'CloseRequestFcn', @cancel_callback);
            
    if ~exist('init_vs_params','var')
        [xx init_vs_params init_tfr_params] = bw_setDefaultParameters();
    end
    
    if isempty(init_vs_params)
        [xx init_vs_params init_tfr_params] = bw_setDefaultParameters();
    end
    
    if ~exist('tal_flag','var');
        tal_flag = 1;
    end
    
    vs_params = init_vs_params;
    tfr_params = init_tfr_params;
    params = init_params;
    peak_voxel = voxel;

    % use beamformer type definition in data settings dialog 
    
    vs_params.rms = params.rms;
    
    OUTPUT2_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
        [0.05 0.76 0.2 0.15],'String','VS Units:','BackgroundColor','White','FontSize',12,'HorizontalAlignment','Left');
    
    MOMENT_RADIO=uicontrol('style','radiobutton','units','normalized','position',...
        [0.18 0.835 0.15 0.12],'string','Moment','backgroundcolor','white','value',~vs_params.pseudoZ,'callback',@MOMENT_RADIO_CALLBACK);
    PSEUDOZ_RADIO=uicontrol('style','radiobutton','units','normalized','position',...
        [0.3 0.835 0.15 0.12],'string','Pseudo-Z','backgroundcolor','white','value',vs_params.pseudoZ,'callback',@PSEUDOZ_RADIO_CALLBACK);

    AUTOFLIP_CHECK = uicontrol('Style','checkbox','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.05 0.77 0.25 0.12],'val',vs_params.autoFlip,'String','Make amplitude positive at:','BackgroundColor','White', 'Callback',@AUTOFLIP_CHECK_CALLBACK);
    AUTOFLIP_TEXT1 = uicontrol('Style','text','Units','Normalized','Position',...
        [0.43 0.78 0.1 0.06],'String','seconds','BackgroundColor','White','HorizontalAlignment','Left');
    AUTOFLIP_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.32 0.8 0.1 0.06],'String',num2str(vs_params.autoFlipLatency),'BackgroundColor','White');

    AVERAGE_RADIO = uicontrol('Style','radiobutton','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.05 0.72 0.35 0.06],'val',~vs_params.saveSingleTrials,'String','Average only','BackgroundColor','White', 'Callback',@AVERAGE_CALLBACK);
    SINGLE_TRIALS_RADIO = uicontrol('Style','radiobutton','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.22 0.72 0.35 0.06],'val',vs_params.saveSingleTrials,'String','Average + Single Trials','BackgroundColor','White', 'Callback',@SINGLE_TRIALS_CALLBACK);

    box1=annotation('rectangle',[0.02 0.7 0.6 0.26],'EdgeColor','blue');
	box1text=uicontrol('style','text','fontsize',11,'units','normalized','Position',...
    [0.06 0.92 0.16 0.05],'string','VS Options','BackgroundColor','white','foregroundcolor','blue','fontweight','b');


    if ~vs_params.autoFlip
        set(AUTOFLIP_EDIT,'enable','off');
        set(AUTOFLIP_TEXT1,'enable','off');
    end
   
    if vs_params.rms
        set(AUTOFLIP_CHECK,'enable','off');
    end    
    
    if tfr_flag
        pstr = 'Plot TFR';
    else
        pstr = 'Plot VS';
    end
    
    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.87 0.2 0.08],'string',pstr,'fontweight','bold',...
        'foregroundcolor',button_orange,'callback',@ok_callback);
 
    cancel=uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.76 0.2 0.08],'string','Cancel','callback',@cancel_callback);

    data_params = uicontrol('style','pushbutton','units','normalized','position',...
        [0.68 0.35 0.22 0.08],'string','Data Parameters','callback',@data_params_callback);
    
    
    function data_params_callback(src,evt)
        params = bw_set_data_parameters(params, dsName);
        vs_params.rms = params.rms;
    end  
    
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

    function AVERAGE_CALLBACK(src,evt)
        set(src,'value',1);
        vs_params.saveSingleTrials = 0;
        set(SINGLE_TRIALS_RADIO,'value',0);
    end

    function SINGLE_TRIALS_CALLBACK(src,evt)
        set(src,'value',1);
        vs_params.saveSingleTrials = 1;
        set(AVERAGE_RADIO,'value',0);
    end

    % TFR options

    
    TFR_OPTIONS_TEXT =uicontrol('style','text','fontsize',11,'units','normalized',...
        'position', [0.03 0.63 0.2 0.05],'string','TFR Options','BackgroundColor','white',...
       'foregroundcolor','blue','fontweight','b');

    box1=annotation('rectangle',[0.02 0.5 0.9 0.17],'EdgeColor','blue');

    FREQ_BIN_TEXT = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.05 0.56 0.18 0.06],'String','Frequency Step (Hz)','BackgroundColor','White');
    FREQ_BIN_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.22 0.58 0.08 0.06],'String',num2str(tfr_params.freqStep),'BackgroundColor','White');    

    MORLET_RADIO = uicontrol('Style','radio','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.38 0.6 0.2 0.06],'String','Morlet Wavelet','BackgroundColor','White', 'callback', @MORLET_CALLBACK);
    HILBERT_RADIO = uicontrol('Style','radio','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.38 0.52 0.2 0.06],'String','Hilbert Transform','BackgroundColor','White', 'callback', @HILBERT_CALLBACK);
    
    MORLET_CYCLE_TEXT = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.57 0.58 0.2 0.06],'String','Wavelet Width (cycles):','BackgroundColor','White');
    MORLET_CYCLE_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.75 0.6 0.08 0.06],'String',num2str(tfr_params.fOversigmafRatio),'BackgroundColor','White');    
    
    HILBERT_FILTER_TEXT = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.57 0.5 0.2 0.06],'String','Filter Width (Hz)','BackgroundColor','White');
    HILBERT_FILTER_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.75 0.52 0.08 0.06],'String','2.0','BackgroundColor','White');    
          
    TFR_SAVE_TRIALS=uicontrol('style','checkbox','units','normalized','position',[0.05 0.51 0.25 0.06],'BackgroundColor','White',...
        'string','Save Single Trial Mag./Phase','value', tfr_params.saveSingleTrials, 'callback',@TFR_SAVE_TRIALS_CALLBACK);
    
    function TFR_SAVE_TRIALS_CALLBACK(src,evt)
        tfr_params.saveSingleTrials = get(src,'value');
    end       

    set(MORLET_RADIO,'value',1);
    set(HILBERT_RADIO,'value',0);
    set(HILBERT_RADIO,'enable','off');
    set(HILBERT_FILTER_TEXT,'enable','off');
    set(HILBERT_FILTER_EDIT,'enable','off');
    
    function MORLET_CALLBACK(src,evt)
        set(src,'value',1);
    end    

    function HILBERT_CALLBACK(src,evt)
        set(src,'value',1);
    end    
    % Coordinates and search options

    
    COORDINATES_TEXT =uicontrol('style','text','fontsize',11,'units','normalized',...
        'position', [0.05 0.435 0.2 0.05],'string','VS Data','BackgroundColor','white',...
       'foregroundcolor','blue','fontweight','b');

    box1=annotation('rectangle',[0.02 0.05 0.9 0.42],'EdgeColor','blue');

    POS_TEXT = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.05 0.36 0.4 0.06],'String','MEG Coordinates (cm):','BackgroundColor','White');
    POS_X=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.25 0.38 0.08 0.06],'String','0','BackgroundColor','White');    
    POS_Y=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.35 0.38 0.08 0.06],'String','0','BackgroundColor','White');    
    POS_Z=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.45 0.38 0.08 0.06],'String','0','BackgroundColor','White');           
    
    TAL_TEXT = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.05 0.2 0.4 0.06],'String','Talairach Coordinates (mm):','BackgroundColor','White');
    TAL_POS_X=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.25 0.22 0.08 0.06],'String','0','BackgroundColor','White');    
    TAL_POS_Y=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.35 0.22 0.08 0.06],'String','0','BackgroundColor','White');    
    TAL_POS_Z=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.45 0.22 0.08 0.06],'String','0','BackgroundColor','White');    

    if tal_flag     
        set( TAL_POS_X,'string', voxel(1));
        set( TAL_POS_Y,'string', voxel(2));
        set( TAL_POS_Z, 'string',voxel(3));
        set( POS_TEXT, 'enable','off');
        set( POS_X, 'enable','off');
        set( POS_Y, 'enable','off');
        set( POS_Z, 'enable','off');
        
    else    
        set( POS_X,'string', voxel(1));
        set( POS_Y,'string', voxel(2));
        set( POS_Z,'string', voxel(3));
        set( TAL_TEXT, 'enable','off');
        set( TAL_POS_X, 'enable','off');
        set( TAL_POS_Y, 'enable','off');
        set( TAL_POS_Z, 'enable','off');
    end
    
    
    RADIO_EXACT=uicontrol('style','radiobutton','units','normalized','position',[0.05 0.15 0.3 0.06],'BackgroundColor','White',...
        'string','Use exact coordinates','value', ~vs_params.useSR, 'callback',@RADIO_EXACT_CALLBACK);
    
    RADIO_SEARCH=uicontrol('style','radiobutton','units','normalized','position',[0.05 0.075 0.4 0.06],'BackgroundColor','White',...
        'string','Find largest peak within a','value', vs_params.useSR, 'callback',@RADIO_SEARCH_CALLBACK);

    SR_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.31 0.075 0.1 0.06],'String',num2str(vs_params.searchRadius),'BackgroundColor','White');    
   
    SR_TEXT = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.42 0.058 0.4 0.06],'String','millimeter search radius','BackgroundColor','White');
  

    function RADIO_EXACT_CALLBACK(src,evt)
        vs_params.useSR = 0;
        set(src,'value',1);
        set(RADIO_SEARCH,'value',0);
        set(SR_EDIT,'enable','off');
        set(SR_TEXT,'enable','off');
    end    

    function RADIO_SEARCH_CALLBACK(src,evt)
        vs_params.useSR = 1;
        set(src,'value',1);
        set(RADIO_EXACT,'value',0);
        set(SR_EDIT,'enable','on');
        set(SR_TEXT,'enable','on');
    end   
    
    if ~tal_flag
        set(RADIO_EXACT,'enable','off');
        set(RADIO_SEARCH,'enable','off');     
        set(SR_TEXT,'enable','off');
    end
    
    if tfr_flag
        set(AUTOFLIP_CHECK,'enable','off');
        set(AUTOFLIP_TEXT1,'enable','off');     
        set(AUTOFLIP_EDIT,'enable','off');        
        set(RMS_CHECK,'enable','off');        
        set(AVERAGE_RADIO,'enable','off');        
        set(SINGLE_TRIALS_RADIO,'enable','off');        
    else
        set(FREQ_BIN_TEXT,'enable','off');
        set(FREQ_BIN_EDIT,'enable','off');     
        set(MORLET_CYCLE_TEXT,'enable','off');        
        set(MORLET_CYCLE_EDIT,'enable','off');
        set(TFR_SAVE_TRIALS,'enable','off');
    end    
    
    if ~vs_params.useSR
        set(SR_EDIT,'enable','off');
        set(SR_TEXT,'enable','off');
    end      
    
    function ok_callback(src,evt)

        if vs_params.autoFlip
            strval = get(AUTOFLIP_EDIT,'String');
            vs_params.autoFlipLatency = str2double(strval);
        end
        
        s = get(FREQ_BIN_EDIT,'String');
        tfr_params.freqStep = str2num(s);
        
        s = get(MORLET_CYCLE_EDIT,'String');
        tfr_params.fOversigmafRatio = str2num(s);
        
        if vs_params.useSR
            strval = get(SR_EDIT,'String');
            vs_params.searchRadius = str2double(strval);
        end
        
        if tal_flag  
            s = get(TAL_POS_X,'String');
            peak_voxel(1) = str2num(s);
            s = get(TAL_POS_Y,'String');
            peak_voxel(2) = str2num(s);
            s = get(TAL_POS_Z,'String');
            peak_voxel(3) = str2num(s);
        else       
            s = get(POS_X,'String');
            peak_voxel(1) = str2num(s);
            s = get(POS_Y,'String');
            peak_voxel(2) = str2num(s);
            s = get(POS_Z,'String');
            peak_voxel(3) = str2num(s);
        end
                
        uiresume(gcf);
        delete(fg);   
    end
  
   function cancel_callback(src,evt)
        % pass empty array to indicate user cancelled       
        vs_params = [];
        tfr_params = [];
        params = [];
        uiresume(gcf);
        delete(fg);   
    end    
    
    %%PAUSES MATLAB
    uiwait(gcf);

end