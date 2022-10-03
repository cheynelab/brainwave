function bw_plot_dialog( VS_DATA1, params)
%
% old syntax.
% function bw_plot_dialog( VS_DATA1.dsList, VS_DATA1.voxelList, VS_DATA1.orientationList, params, vs_params, tfr_params)
%
%   DESCRIPTION: Creates a GUI that allow users to set some options for
%   virtual sensor calculations
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
% Feb 2022 - rewrite for version 4.0  - removed conditions. Reformated
% layout - can pass additional peaks directly to open dialog
% 
% Aug 2014 - pass VS coordinates so they can be manipulated / edited here...

    global g_peak
    global addPeakFunction
    global PLOT_WINDOW_OPEN

    scrnsizes=get(0,'MonitorPosition');
    button_orange = [0.8,0.4,0.1];
        
    % initial settings    
    if ~exist('VS_DATA1','var')
        VS_DATA1.dsList{1} = 'not_selected';
        VS_DATA1.covDsList{1} = 'not_selected';
        VS_DATA1.voxelList(1,1:3) = [0 0 10];
        VS_DATA1.orientationList(1,1:3) = [1 0 0]; 
        VS_DATA1.labelList{1} = 'not_selected';
        params = bw_setDefaultParameters;
    end
    
    if isempty(params)       
        % if passing data with no params struct 
        % ensure that covWindow is not set to [0 0] 
        if ~isempty(VS_DATA1)
            covName = char(VS_DATA1.covDsList{1});
        else
            params = bw_setDefaultParameters();
        end
    end
   
    % override defaults
    params.vs_parameters.subtractAverage = 0;
    useNormal = 0;
    selectedRows = 1;
    
    PLOT_WINDOW_OPEN = 1;
    
    titleStr = sprintf('Virtual Sensor Analysis');
    
    fg=figure('color','white','name',titleStr,'numbertitle','off',...
        'menubar','none','position',[scrnsizes(1,3)/3 scrnsizes(1,4)/2 1150 550],'CloseRequestFcn', @close_callback);
    if ispc
        movegui(fg,'center');
    end
    FILE_MENU = uimenu('label','File');
    
    uimenu(FILE_MENU,'label','Load Voxel List ...','Callback',@open_vlist_callback);
    uimenu(FILE_MENU,'label','Load VS Plot (.mat)...','Callback',@open_vs_plot_callback);
    uimenu(FILE_MENU,'label','Save Voxel List...','separator','on','Callback',@save_vlist_callback);
    uimenu(FILE_MENU,'label','Save Raw VS Data...','Callback',@save_raw_callback);
    uimenu(FILE_MENU,'label','Edit Beamformer Parameters...','separator','on','Callback',@data_params_callback);
    uimenu(FILE_MENU,'label','Close','separator','on','Callback',@close_callback);
    
    %%%%%%%%%%%%
    % VS plot
    
    annotation('rectangle',[0.5 0.05 0.45 0.36],'EdgeColor','blue');
    uicontrol('style','text','fontsize',12,'units','normalized','Position',...
    [0.52 0.37 0.18 0.06],'string','Virtual Sensor Plot','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
    AVERAGE_RADIO = uicontrol('Style','radiobutton','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.52 0.32 0.15 0.05],'val',~params.vs_parameters.saveSingleTrials,'String','Average only','BackgroundColor','White', 'Callback',@AVERAGE_CALLBACK);
    SINGLE_TRIALS_RADIO = uicontrol('Style','radiobutton','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.64 0.32 0.2 0.05],'val',params.vs_parameters.saveSingleTrials,'String','Average + Single Trials','BackgroundColor','White', 'Callback',@SINGLE_TRIALS_CALLBACK);
    
    AUTOFLIP_CHECK = uicontrol('Style','checkbox','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.52 0.25 0.15 0.05],'val',params.vs_parameters.autoFlip,'String','Make polarity','BackgroundColor','White', 'Callback',@AUTOFLIP_CHECK_CALLBACK);
    AUTOFLIP_POS_RADIO = uicontrol('Style','radio','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.63 0.25 0.14 0.05],'val',params.vs_parameters.autoFlipPolarity,'String','positive at','BackgroundColor','White', 'Callback',@AUTOFLIP_POS_CALLBACK);
    AUTOFLIP_NEG_RADIO = uicontrol('Style','radio','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.72 0.25 0.14 0.05],'val',~params.vs_parameters.autoFlipPolarity,'String','negative at','BackgroundColor','White', 'Callback',@AUTOFLIP_NEG_CALLBACK);   
    AUTOFLIP_EDIT=uicontrol('Style','Edit','Units','Normalized','fontsize',12,'Position',...
        [0.83 0.25 0.05 0.05],'String',num2str(params.vs_parameters.autoFlipLatency),'BackgroundColor','White');
    AUTOFLIP_TEXT1 = uicontrol('Style','text','Units','Normalized','fontsize',12,'Position',...
        [0.9 0.23 0.03 0.05],'String','sec','BackgroundColor','White','HorizontalAlignment','Left');
    
    SUBTRACT_AVERAGE_CHECK = uicontrol('Style','checkbox','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.52 0.18 0.25 0.05],'val',params.vs_parameters.subtractAverage,'String','Subtract Average from Single Trials','BackgroundColor','White', 'Callback',@SUBTRACT_AVERAGE_CHECK_CALLBACK);
    
    uicontrol('Style','Text','FontSize',11,'Units','Normalized','fontsize',12,'fontweight','bold','Position',...
        [0.65 0.84 0.06 0.06],'String','Units:','BackgroundColor','White','HorizontalAlignment','Left');    
    MOMENT_RADIO=uicontrol('style','radiobutton','units','normalized','fontsize',11,'position',...
        [0.72 0.85 0.1 0.06],'string','Moment','backgroundcolor','white','value',~params.vs_parameters.pseudoZ,'callback',@MOMENT_RADIO_CALLBACK);
    PSEUDOZ_RADIO=uicontrol('style','radiobutton','units','normalized','fontsize',11,'position',...
        [0.8 0.85 0.1 0.06],'string','Pseudo-Z','backgroundcolor','white','value',params.vs_parameters.pseudoZ,'callback',@PSEUDOZ_RADIO_CALLBACK);    
            
    function MOMENT_RADIO_CALLBACK(~,~)
        params.vs_parameters.pseudoZ=0;
        set(PSEUDOZ_RADIO,'value',0)
        set(MOMENT_RADIO,'value',1)
    end

    function PSEUDOZ_RADIO_CALLBACK(~,~)
        params.vs_parameters.pseudoZ=1;
        set(PSEUDOZ_RADIO,'value',1)
        set(MOMENT_RADIO,'value',0)
    end
    
    function AUTOFLIP_CHECK_CALLBACK(src,~)
        params.vs_parameters.autoFlip = get(src,'val');
        
        if params.vs_parameters.autoFlip
            set(AUTOFLIP_EDIT,'enable','on');
            set(AUTOFLIP_TEXT1,'enable','on');
            set(AUTOFLIP_POS_RADIO,'enable','on');
            set(AUTOFLIP_NEG_RADIO,'enable','on');
        else
            set(AUTOFLIP_EDIT,'enable','off');
            set(AUTOFLIP_TEXT1,'enable','off');
            set(AUTOFLIP_POS_RADIO,'enable','off');
            set(AUTOFLIP_NEG_RADIO,'enable','off');
        end
        
    end

    function AUTOFLIP_POS_CALLBACK(src,~)
        params.vs_parameters.autoFlipPolarity = 1;
        set(src,'value',1);        
        set(AUTOFLIP_NEG_RADIO,'value',0);        
    end

    function AUTOFLIP_NEG_CALLBACK(src,~)
        params.vs_parameters.autoFlipPolarity = -1;
        set(src,'value',1);        
        set(AUTOFLIP_POS_RADIO,'value',0);        
    end

    function AVERAGE_CALLBACK(src,~)
        set(src,'value',1);
        params.vs_parameters.saveSingleTrials = 0;
        set(SINGLE_TRIALS_RADIO,'value',0);
        set(SUBTRACT_AVERAGE_CHECK,'enable','off');
    end    

    function SINGLE_TRIALS_CALLBACK(src,~)
        set(src,'value',1);
        params.vs_parameters.saveSingleTrials = 1;
        set(AVERAGE_RADIO,'value',0);
        set(SUBTRACT_AVERAGE_CHECK,'enable','on');
    end

    function SUBTRACT_AVERAGE_CHECK_CALLBACK(src,~)
        params.vs_parameters.subtractAverage = get(src,'val'); 
    end

    function plot_VS_callback(~,~)
        
        if isempty(VS_DATA1.dsList)
            return;
        end
        
        if params.vs_parameters.autoFlip
            strval = get(AUTOFLIP_EDIT,'String');
            params.vs_parameters.autoFlipLatency = str2double(strval);
        end
                
        rows = selectedRows;
                
        if useNormal  
            oriList = VS_DATA1.orientationList(rows,1:3);
        else
            oriList = [];
        end
                
        VS_ARRAY1 = bw_create_VS(VS_DATA1.dsList(rows), VS_DATA1.covDsList(rows), VS_DATA1.voxelList(rows,1:3),...
                oriList, VS_DATA1.labelList(rows), params); 
        if isempty(VS_ARRAY1)
            return;
        end
        
        params.vs_parameters.plotLabel = sprintf('Average');
        params.vs_parameters.plotColor = [0 0 1];
        
        bw_VSplot(VS_ARRAY1, params); 
       
    end

    %%%%%%%%%%%%
    % TFR plot
    
    annotation('rectangle',[0.02 0.05 0.45 0.36],'EdgeColor','blue');
    uicontrol('style','text','fontsize',12,'units','normalized',...
        'position', [0.03 0.37 0.18 0.05],'string','Time-Frequency Plot','BackgroundColor','white',...
       'foregroundcolor','blue','fontweight','b');

    uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.05 0.29 0.18 0.05],'String','Frequency Step (Hz)','BackgroundColor','White');
    FREQ_BIN_EDIT=uicontrol('Style','Edit','Units','Normalized','fontsize',12,'Position',...
        [0.22 0.3 0.06 0.05],'String',num2str(params.tfr_parameters.freqStep),'BackgroundColor','White');    
    uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.05 0.22 0.2 0.05],'String','Wavelet Width (cycles):','BackgroundColor','White');
    MORLET_CYCLE_EDIT=uicontrol('Style','Edit','Units','Normalized','fontsize',12,'Position',...
        [0.22 0.23 0.06 0.05],'String',num2str(params.tfr_parameters.fOversigmafRatio),'BackgroundColor','White');    
   
    uicontrol('style','checkbox','units','normalized','fontsize',12,'position',...
        [0.05 0.16 0.3 0.05],'BackgroundColor','White','string','Save Trial Magnitude/Phase','value',...
        params.tfr_parameters.saveSingleTrials, 'callback',@TFR_SAVE_TRIALS_CALLBACK);  

    function TFR_SAVE_TRIALS_CALLBACK(src,~)
        params.tfr_parameters.saveSingleTrials = get(src,'value');
    end

    params.tfr_parameters.method = 0;
    
    
    function plot_TFR_callback(~,~)

        if isempty(VS_DATA1.dsList)
            return;
        end
        
        s = get(FREQ_BIN_EDIT,'String');
        params.tfr_parameters.freqStep = str2double(s);
        
        s = get(MORLET_CYCLE_EDIT,'String');
        params.tfr_parameters.fOversigmafRatio = str2double(s);

        rows = selectedRows;
        
        if useNormal  
            oriList = VS_DATA1.orientationList(rows,1:3);
        else
            oriList = [];
        end

        TFR_ARRAY1 = bw_create_TFR(VS_DATA1.dsList(rows),VS_DATA1.covDsList(rows),VS_DATA1.voxelList(rows,1:3),...
            oriList, VS_DATA1.labelList(rows), params); 
       
        if isempty(TFR_ARRAY1)
            return;
        end
        label = sprintf('Average');
        bw_plot_tfr(TFR_ARRAY1, 0, label);        
            
    end  
    
    tfrButton=uicontrol('style','pushbutton','units','normalized','fontsize',12,'position',...
        [0.04 0.07 0.13 0.07],'string','Plot TFR','fontweight','bold','foregroundcolor',button_orange,'callback',@plot_TFR_callback);
    
    vsButton=uicontrol('style','pushbutton','units','normalized','fontsize',12,'position',...
        [0.52 0.07 0.13 0.07],'string','Plot VS','fontweight','bold','foregroundcolor',button_orange,'callback',@plot_VS_callback);
           
    if ~ismac
        set(tfrButton,'backgroundcolor','white');
        set(vsButton,'backgroundcolor','white');
    end  
    
    %%%%%%%%%%%%
    % VS parameters and data   
    
    annotation('rectangle',[0.02 0.45 0.93 0.5],'EdgeColor','blue');
    uicontrol('style','text','fontsize',12,'units','normalized',...
        'position', [0.03 0.91 0.2 0.06],'string','Virtual Sensor Parameters','BackgroundColor','white',...
       'foregroundcolor','blue','fontweight','b');

    uicontrol('Style','Text','FontSize',11,'Units','Normalized','fontsize',12,'Position',...
        [0.03 0.86 0.12 0.06],'String','VS Coordinates:','BackgroundColor','White','HorizontalAlignment','Left');   
    uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','fontsize',12,'Position',...
        [0.03 0.82 0.6 0.06],...
        'String','Position (cm)            Orientation           Dataset            (Covariance Dataset )       Label',...
        'BackgroundColor','White');  
    vsListBox=uicontrol('style','listbox','units','normalized','position',...
        [0.03 0.52 0.6 0.31],'fontsize',10,'max',10000,'background','white','callback', @listBoxCallback);    

    
    % params

        % 
    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.65 0.79 0.2 0.04],'String','Filter Data:','FontSize',12,'Fontweight','bold','BackGroundColor','white');

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.65 0.735 0.1 0.04],'String','Highpass (Hz):','FontSize',12,'BackGroundColor','white');

    FILTER_EDIT_MIN=uicontrol('style','edit','units','normalized','position',...
        [0.74 0.73 0.05 0.05],'String', params.beamformer_parameters.filter(1),...
        'FontSize', 12, 'BackGroundColor','white','callback',@filter_edit_min_callback);
        function filter_edit_min_callback(src,~)
            string_value=get(src,'String');
            if isempty(string_value)
                params.beamformer_parameters.filter(1) = 1;
                set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
                params.beamformer_parameters.filter(2) = 50;
                set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
                clear dsParams;
            else
                dsName = char(VS_DATA1.dsList{selectedRows(1)});
                dsParams = bw_CTFGetHeader(dsName);
                params.beamformer_parameters.filter(1)=str2double(string_value);
                if params.beamformer_parameters.filter(1) < 0
                    params.beamformer_parameters.filter(1) = 0;
                end
                if params.beamformer_parameters.filter(1) > dsParams.sampleRate / 2.0
                    params.beamformer_parameters.filter(1) = dsParams.sampleRate / 2.0;
                end
                set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1))
            end
        end

    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',...
        [0.8 0.735 0.1 0.04],'String','Lowpass (Hz):','FontSize',12,'BackGroundColor','white');

    FILTER_EDIT_MAX=uicontrol('style','edit','units','normalized','position',...
        [0.89 0.73 0.05 0.05],'String',params.beamformer_parameters.filter(2),...
        'FontSize', 12, 'BackGroundColor','white','callback',@filter_edit_max_callback);
        function filter_edit_max_callback(src,~)
            string_value=get(src,'String');
            if isempty(string_value)
                params.beamformer_parameters.filter(2)=50;
                set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));
                params.filter(1)=1;
                set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
            else
                dsName = char(VS_DATA1.dsList{selectedRows(1)});
                dsParams = bw_CTFGetHeader(dsName);
                params.beamformer_parameters.filter(2)=str2double(string_value);
                if params.beamformer_parameters.filter(2) > dsParams.sampleRate
                    params.beamformer_parameters.filter(2) = dsParams.sampleRate;
                end
                if params.beamformer_parameters.filter(2) < 0
                    params.beamformer_parameters.filter(2)=0;
                end
                set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2))
                clear dsParams;
            end
        end
    
    uicontrol('style','text','units','normalized','HorizontalAlignment','left','position', ...
        [0.65 0.65 0.2 0.05],'String','Source Orientation:','FontSize',12,'Fontweight','bold','BackGroundColor','white');
   
    EDIT_PARAMS_BUTTON = uicontrol('style','pushbutton','units','normalized','position',...
        [0.645 0.52 0.18 0.05],'string','Edit Beamformer Parameters','FontSize', 12,'callback',@data_params_callback);
    
    if ~ismac
        set(EDIT_PARAMS_BUTTON,'backgroundcolor','white');
    end
    
    function data_params_callback(~,~)
        
        if isempty(VS_DATA1.dsList)
            return;
        end
                
        dsName = char(VS_DATA1.dsList{selectedRows(1)});
        if ~exist(dsName,'file')
            fprintf('Cannot open dataset %s\n', dsName);
            return;
        end
        if params.beamformer_parameters.covarianceType == 2
            covDsName = deblank( VS_DATA1.covDsList{1,selectedRows} );
            params.beamformer_parameters = bw_set_data_parameters(params.beamformer_parameters, dsName, covDsName );
        else           
            params.beamformer_parameters = bw_set_data_parameters(params.beamformer_parameters, dsName, dsName );
        end
        
        % update in case filter settings changed
        set(FILTER_EDIT_MIN,'string',params.beamformer_parameters.filter(1));
        set(FILTER_EDIT_MAX,'string',params.beamformer_parameters.filter(2));

        updateRMSControls;
        
    end 
      
    ORIENTATION_POPUP_MENU = uicontrol('style','popup','units','normalized','position', [0.64 0.6 0.27 0.04],...
        'string',{'Optimized (maximum power)';'Constrained (use orientation vector)';'RMS (vector beamformer)'},'FontSize', 12,'callback',@orientation_menu_callback);
   
        function orientation_menu_callback(src,~)
            val = get(src,'value');
            if val == 1
                useNormal = 0;
                params.vs_parameters.rms = 0;
            elseif val == 2
                useNormal = 1;                
                params.vs_parameters.rms = 0;
            elseif val == 3
                params.vs_parameters.rms = 1;
            end
            updateRMSControls;               
        end
    % use beamformer type passed in beamformer_parameter
    useNormal = 0;
    
    params.vs_parameters.rms = params.beamformer_parameters.rms;
    if params.vs_parameters.rms
        set(ORIENTATION_POPUP_MENU,'value',3);
    else
        set(ORIENTATION_POPUP_MENU,'value',1);
    end    
    updateRMSControls;
    
    if isempty(VS_DATA1)
        % need to set some valid params.
        params = bw_setDefaultParameters; 
    else
        if isempty(VS_DATA1.orientationList)
            for k=1:size(VS_DATA1.voxelList,1)        
                VS_DATA1.orientationList(k,1:3) = [1 0 0];
            end       
        end        
        updateDataWindow;
    end
    

    if ~params.vs_parameters.autoFlip
        set(AUTOFLIP_EDIT,'enable','off');
        set(AUTOFLIP_TEXT1,'enable','off');
        set(AUTOFLIP_POS_RADIO,'enable','off');
        set(AUTOFLIP_NEG_RADIO,'enable','off');
    end    
       
    if ~params.vs_parameters.saveSingleTrials
        set(SUBTRACT_AVERAGE_CHECK,'enable','off');
    else    
        set(SUBTRACT_AVERAGE_CHECK,'enable','on');
    end    

    function updateRMSControls
        if params.vs_parameters.rms        
            set(AUTOFLIP_CHECK,'enable','off');
            set(AUTOFLIP_EDIT,'enable','off');
            set(AUTOFLIP_TEXT1,'enable','off');
            set(AUTOFLIP_POS_RADIO,'enable','off');
            set(AUTOFLIP_NEG_RADIO,'enable','off');    
        else
            set(AUTOFLIP_CHECK,'enable','on');
            if params.vs_parameters.autoFlipLatency
                set(AUTOFLIP_EDIT,'enable','on');
                set(AUTOFLIP_TEXT1,'enable','on');
                set(AUTOFLIP_POS_RADIO,'enable','on');
                set(AUTOFLIP_NEG_RADIO,'enable','on'); 
            end
        end  
    end

    function addGlobalPeak
        VS_DATA1.dsList{end+1} = g_peak.dsName;
        VS_DATA1.covDsList{end+1} = g_peak.covDsName;
        VS_DATA1.voxelList(end+1,1:3) = g_peak.voxel;
        VS_DATA1.orientationList(end+1,1:3) =  g_peak.normal;
        VS_DATA1.labelList{end+1} = g_peak.label;
        
        numPeaks = numel(VS_DATA1,1);
         
        updateDataWindow;

    end

    addPeakFunction = @addGlobalPeak;


    function open_vs_plot_callback(~, ~)
        [filename, pathname, ~]= uigetfile({'*.mat',' (*_WAVEFORMS.mat)'},...
            'Select VS Plot .mat file');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        
        matfile = fullfile(pathname, filename);
        
        t = load(matfile);
        params = t.params;

        for k=1:size(t.VS_ARRAY,2)
            vs_data = t.VS_ARRAY{k};
            VS_DATA1.dsList{k} = vs_data.dsName;
            VS_DATA1.covDsList{k} = vs_data.covDsName;
            VS_DATA1.voxelList(k,1:3) = vs_data.voxel;
            VS_DATA1.orientationList(k,1:3) =  vs_data.normal; 
            VS_DATA1.labelList{k} =  vs_data.label; 
        end     
        set(vsListBox,'value',1);
        VS_DATA1.condLabel = t.groupLabel;

        updateDataWindow;
        
    end


    % ** old format
    function open_vlist_callback(~, ~)
        [filename, pathname, ~]=uigetfile({'*.vs','Virtual Sensor File (*.vs)'},...
            'Select list file containing virtual sensor parameters');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
                
        listFile = fullfile(pathname, filename);
        
        list = bw_read_list_file(listFile);

        for k=1:size(list,1)
            str = char(list(k,:));
            a = strread(str,'%s','delimiter',' ');
            VS_DATA1.dsList{k} = char( a(1) );
             
            VS_DATA1.covDsList{k} = char( a(2) );
            VS_DATA1.voxelList(k,1:3) = str2double( a(3:5))';
            VS_DATA1.orientationList(k,1:3) = str2double( a(6:8))';  
            VS_DATA1.orientationList(k,1:3) = str2double( a(6:8))';  
            VS_DATA1.labelList{k} = char( a(9) );
        end

        set(vsListBox,'value',1);
        VS_DATA1.condLabel = filename;
        
        updateDataWindow;
        
    end
      
    function save_vlist_callback(~, ~)
 
        if isempty(VS_DATA1)
            return;
        end
        
        [filename, pathname, ~]=uiputfile({'*.vs','Virtual Sensor File (*.vs)'},'Save virtual sensor parameters for Condition 1 as...');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end      
        saveName = fullfile(pathname, filename);
        save_VS_File( VS_DATA1, saveName);
   end


    function save_VS_File(VS_DATA, saveName)
                                  
        fprintf('Saving voxel parameters in file %s\n', saveName);
        fid = fopen(saveName,'w');
                     
        for j=1:size(VS_DATA.voxelList,1)
            dsName = char(VS_DATA.dsList{j});
            covDsName = char(VS_DATA.covDsList{j});
            voxel = VS_DATA.voxelList(j,1:3);
            normal = VS_DATA.orientationList(j,1:3);
            label = char(VS_DATA.labelList{j});
            s = sprintf('%s    %s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f    %s', dsName, covDsName, voxel, normal, label);    
            fprintf(fid,'%s\n', s);           
        end        
        
        fclose(fid);
                
   end

    function save_raw_callback(~,~)

        if isempty(VS_DATA1)
            return;
        end
                       
        wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wbh,'canceling',0)
       
        tic;
                    
        [name,path,idx] = uiputfile({'*.mat','MAT-file (*.mat)';'*','ASCII files (Directory)';},...
                'Select output name virtual sensor data for condition %d ...',char(k));
        if isequal(name,0)
            return;
        end
        path = fullfile(path,name);

        if idx == 1
            saveMatFile = true;
        else
            saveMatFile = false;
            fprintf('Saving virtual sensor raw data to directory %s\n', path); 
            mkdir(path);          
        end

        % assume voxel list sizes are the same for all conditions
        for j=1:size(VS_DATA1.voxelList,1)
            if getappdata(wbh,'canceling')
                delete(wbh);   
                fprintf('*** cancelled ***\n');
                return;
            end
            waitbar(j/size(VS_DATA1.voxelList,1),wbh,sprintf('generating virtual sensor %d',j));

            % get raw data...
            fprintf('computing single trial data ...\n');

            % override some parameters...
            params.vs_parameters.saveSingleTrials = 1;
            voxel = VS_DATA1.voxelList(j,1:3);
            normal = VS_DATA1.orientationList(j,1:3);
            dsName = char(VS_DATA1.dsList{j});
            covDsName = char(VS_DATA1.covDsList{j});

            [timeVec, vs_data_raw, comnorm] = bw_make_vs(dsName, covDsName, voxel, normal, params);

            [samples, trials] = size(vs_data_raw);

            % store all data in one matfile 
            %
            % format:
            % vsdata.timeVec = 1D array of latencies (nsamples x 1)
            % vsdata.voxels = 2D array of voxel coords (nvoxels x 6)
            % vsdata.trials = 3D array of vs data (nvoxels x ntrials x nsamples)

            if saveMatFile
                vsdata.timeVec = timeVec;
                vox_params = [voxel comnorm'];
                vsdata.voxel(j,1:6) = vox_params;
                vsdata.trial(j,1:trials,1:samples) = single(vs_data_raw');    % save as single precision - reduces file size by 50%       
            else
                outFile = sprintf('%s%s%s_voxel_%4.2f_%4.2f_%4.2f.raw', ...
                    path, filesep, char(dsName), voxel(1), voxel(2), voxel(3));
                fid = fopen(outFile,'w');
                fprintf('Saving single trial data in file %s\n', outFile);
                for i=1:size(vs_data_raw,1)
                    fprintf(fid, '%.4f', timeVec(i));
                    for k=1:size(vs_data_raw,2)
                        fprintf(fid, '\t%8.4f', vs_data_raw(i,k) );
                    end   
                    fprintf(fid,'\n');
                end
                fclose(fid);                 
            end

        end
        delete(wbh);  
        toc

        if saveMatFile
            fprintf('Writing VS data to file %s\n', path);
            save(path,'-struct','vsdata');
        end
        
        
        fprintf('\n...all done\n');
        
    end

    uicontrol('style','pushbutton','units','normalized','fontweight','bold','position',...
    [0.03 0.46 0.08 0.05],'string','Edit','callback',@listEditCallback);
    
    uicontrol('style','pushbutton','units','normalized','fontweight','bold','position',...
    [0.12 0.46 0.08 0.05],'string','Delete','callback',@listDeleteCallback); 

    uicontrol('style','pushbutton','units','normalized','fontweight','bold','position',...
    [0.22 0.46 0.08 0.05],'string','Copy','callback',@listCopyCallback); 


    function listCopyCallback(~, ~)               
        if isempty(VS_DATA1.voxelList)
           return;
        end
        selectedRows = get(vsListBox,'value');
        if size(selectedRows,2) > 1
            errordlg('Select single VS to copy')
            return;
        end      
        VS_DATA1.voxelList(end+1,:) = VS_DATA1.voxelList(selectedRows,:);
        VS_DATA1.orientationList(end+1,:) = VS_DATA1.orientationList(selectedRows,:);
        VS_DATA1.dsList(end+1) = VS_DATA1.dsList(selectedRows);
        VS_DATA1.covDsList(end+1) = VS_DATA1.covDsList(selectedRows);               
        updateDataWindow;   
    end

    function listEditCallback(~, ~)               
        if isempty(VS_DATA1.voxelList)
           return;
        end
        selectedRows = get(vsListBox,'value');
        if size(selectedRows,2) > 1
            errordlg('Select single VS to edit')
            return;
        end      
        edit_selected_VS(selectedRows);     
    end

    function listDeleteCallback(~, ~)               
        if isempty(VS_DATA1.voxelList)
           return;
        end
        selectedRows = get(vsListBox,'value');
        numToDelete = size(selectedRows,2);

        s = sprintf('Delete %d virtual sensors', numToDelete);
        response = questdlg(s,'BrainWave','Yes','Cancel','Yes');
        if strcmp(response,'Cancel')
            return;     
        end        
        VS_DATA1.voxelList(selectedRows,:) = [];
        VS_DATA1.orientationList(selectedRows,:) = [];
        VS_DATA1.dsList(selectedRows) = [];
        VS_DATA1.covDsList(selectedRows) = [];
        set(vsListBox,'value',1);
        updateDataWindow;   
    end

    function listBoxCallback(src, ~)        
       if strcmp( get(gcf,'selectiontype'), 'open')     % look for double click only           
           selectedRows = get(src,'value');             
           edit_selected_VS(selectedRows);          
       else
           selectedRows = get(src,'value');
       end       
    end       

    function edit_selected_VS(selection)
       if isempty(VS_DATA1.voxelList)
           return;
       end
       pos = VS_DATA1.voxelList(selection,1:3);
       ori = VS_DATA1.orientationList(selection,1:3);
       dsName = VS_DATA1.dsList{selection};
       covDsName = VS_DATA1.covDsList{selection};  
       label =  VS_DATA1.labelList{selection};
       
       [pos, ori, dsName, covDsName, label] = bw_vs_params_dialog(pos, ori, dsName, covDsName, label);  % edit CTF coords only

       if ~isempty(pos)
            VS_DATA1.voxelList(selection,1:3) = pos;
            VS_DATA1.orientationList(selection,1:3) = ori;
            VS_DATA1.dsList{selection} = dsName;
            VS_DATA1.covDsList{selection} = covDsName;
            VS_DATA1.labelList{selection} = label;
            updateDataWindow;
       end       
    end

    function updateDataWindow
        tlist = {};
     
        for k=1:size(VS_DATA1.voxelList,1)
            dsName = char(VS_DATA1.dsList{k});
            covDsName = char(VS_DATA1.covDsList{k});     
            voxel = VS_DATA1.voxelList(k,1:3);
            orientation = VS_DATA1.orientationList(k,1:3);         
            label = char(VS_DATA1.labelList{k});
            
            s = sprintf('%6.2f %6.2f %6.2f    %6.2f %6.2f %6.2f     %s         (%s)       %s',...
                voxel, orientation, dsName, covDsName, label );                  
            tlist(k,:) = cellstr(s);
        end
        set(vsListBox,'string',tlist);

    end

    function close_callback(~,~)  
        PLOT_WINDOW_OPEN = 0;
        uiresume(gcf);
        delete(fg);   
    end    

end