function bw_main_menu
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   *new for version 4.0
%   bw_menu.m - replaces bw_start.m
%
%   DESCRIPTION: Creates the BrainWave's main GUI. 
%   (c) D. Cheyne, 2011. All rights reserved. 
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   June, 2012, Version 2.0
%   
%   This is now main menu to define globals and launch other modules
%
%  Last update Sept 18, 2014, Version 3.0 beta
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    global BW_VERSION;
    global SPM_VERSION;
    global BW_PATH;
    global HAS_SIGNAL_PROCESSING
    global global_voxel
    global global_latency
    global defaultPrefsFile

    global addPeakFunction
    global PEAK_WINDOW_OPEN

    PEAK_WINDOW_OPEN = 0;

    fig_handles = [];

    BW_VERSION = '4.1beta (June 17, 2022)';
    
    versionStr = version;
    versionNo = str2double(versionStr(1:3));
    
    if versionNo < 9.0
        warndlg('MATLAB Version 9.0 or later recommended');
    end
    
    result = license('test','signal_toolbox');
    if result == 1
        HAS_SIGNAL_PROCESSING = true;
    else
        HAS_SIGNAL_PROCESSING = false;
        fprintf('Signal processing toolbox not found. Some feature may not be available\n');
    end    

    tpath=which('bw_main_menu');

    pathparts = strsplit(tpath,filesep);
    s = pathparts(1:end-1);
    BW_PATH = strjoin(s,filesep);
    BW_PATH = strcat(BW_PATH,filesep);  % strjoin doesn't add trailing filesep

    addpath(BW_PATH);

    % add paths for other modules ....
    s = pathparts(1:end-2);  % get top directory 
    topPath = strjoin(s,filesep);
    DT_PATH = strcat(topPath,filesep,'DTI Toolbox');
    addpath(DT_PATH);

    SIM_PATH = strcat(topPath,filesep,'SimDs');
    addpath(SIM_PATH);

    HELP_PATH = strcat(topPath,filesep,'Manuals');
    addpath(HELP_PATH);

    
    % brainwave subfolder paths...
    MEX_PATH = strcat(BW_PATH,'mex');
    addpath(MEX_PATH);

    defaultPrefsFile = sprintf('%sbw_prefs.mat', BW_PATH);
    externalPath = strcat(BW_PATH,'external',filesep);

    dirpath=strcat(externalPath,'topoplot');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: topoplot folder is missing...\n');
    else
        addpath(dirpath);
    end

    dirpath=strcat(externalPath,'NIfTI');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: NIfTI folder is missing...\n');
    else
        addpath(dirpath);
    end

    dirpath=strcat(externalPath,'dicm2nii');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: dicm2nii folder is missing...\n');
    else
        addpath(dirpath);
    end

    dirpath=strcat(externalPath,'YokogawaMEGReader_R1.04.00');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: YokogawaMEGReader_R1.04.00 folder is missing...\n');
    else
        addpath(dirpath);
    end

    dirpath=strcat(externalPath,'yokogawa2ctf');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: yokogawa2ctf is missing...\n');
    else
        addpath(dirpath);
    end

    % add path for tesslation code
    dirpath=strcat(externalPath,filesep,'MyCrustOpen070909');
    if exist(dirpath,'dir') ~= 7   % should not happen as folder is part of BW
        fprintf('error: MyCrustOpen070909 folder is missing...\n');
    else
        addpath(dirpath);
    end   
    
    % add paths for diffusionTools and SimDs

    % Check if SPM8 available...
    SPM_VERSION = 0;
    if contains(which('spm'),'spm8')
        SPM_VERSION = 8;
        fprintf('found SPM8 in path... spatial normalization is enabled\n'); 
    elseif contains(which('spm'),'spm12')
        SPM_VERSION = 12;
        fprintf('found SPM12 in path... spatial normalization is enabled\n'); 

        % need to add the path to "OldNorm" ...
        SPM_PATH=spm('dir');
%         spm_defaults; % make sure the old.defaults structure exists?
        oldNormPath = strcat(SPM_PATH,filesep,'toolbox/OldNorm');
        addpath(oldNormPath);
    else
        if contains(which('spm'),'spm2')
            fprintf('( **** BrainWave no longer supports SPM2.  Please update to SPM8 or SPM12 ***)\n'); 
        end        
    end

    if SPM_VERSION == 0
        fprintf('Cannot find installation of SPM8 or SPM12, SPM spatial normalization is disabled\n'); 
    end

    %
    button_text = [0.6,0.25,0.1];
    button_fontSize = 10;
    button_fontWt = 'bold';

    menu=figure('Name', 'BrainWave Toolbox','Position',[200 200 600 600],...
                'menubar','none','numbertitle','off', 'Color','white', 'CloseRequestFcn',@QUIT_CALLBACK);
    if ispc
        movegui(menu,'center');
    end
    
    logo=imread('BRAINWAVE_LOGO_2.png');
    axes('parent',menu,'position',[0.1 0.02 0.9 0.75]);                  
    bh = image(logo);
    set(bh,'AlphaData',0.3);
    axis off;
    buttonHeight = 0.08;
    buttonWidth = 0.33;

    uicontrol('Style','text','FontSize', 14,'FontWeight',button_fontWt,'Units','Normalized',...
        'Position',[0.1 0.87 buttonWidth buttonHeight],'BackgroundColor','white','ForegroundColor',button_text,'string','MEG Analysis');

    uicontrol('Style','text','FontSize', 14,'FontWeight',button_fontWt,'Units','Normalized',...
        'Position',[0.55 0.87 buttonWidth buttonHeight],'BackgroundColor','white','ForegroundColor',button_text,'string','MRI Analysis');

    %%% MEG modules %%%

    importData = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.78 buttonWidth buttonHeight],'String','Import MEG','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@IMPORT_DATA_CALLBACK);
   
    dipolePlot = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.64 buttonWidth buttonHeight],'String','DataPlot / Dipole Fit','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@DIPOLE_PLOT_CALLBACK);

    singleSubject =  uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.5 buttonWidth buttonHeight],'String','Beamforming (Individual)','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@SINGLE_SUBJECT_CALLBACK);

    groupAnalysis = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.36 buttonWidth buttonHeight],'String','Beamforming (Group)','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@GROUP_IMAGE_CALLBACK);

    megSim = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.1 0.22 buttonWidth buttonHeight],'String','MEG Simulation','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@SIMDS_CALLBACK);


   
    %%% MRI modules %%%
    mriImport = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.55 0.78 buttonWidth buttonHeight],'String','Import MRI','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@MRI_IMPORT_CALLBACK);

    mriViewer = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.55 0.64 buttonWidth buttonHeight],'String','MRI Viewer','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@MRI_VIEWER_CALLBACK);

    surfaceViewer = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.55 0.5 buttonWidth buttonHeight],'String','Surface Viewer','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@SURFACE_VIEWER_CALLBACK);

    DTI_preprocess = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.55 0.36 buttonWidth buttonHeight],'String','DTI Analysis (FSL)','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@DTI_PREPROCESSOR_CALLBACK);     
    
    % DTI requires FSL
    if ispc
        set(DTI_preprocess,'enable','off');
    end
    
    %%%%%
%     
%     quit = uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
%         [0.35 0.15 0.25 buttonHeight],'String','Quit','HorizontalAlignment','Center',...
%         'ForegroundColor',button_text,'Callback',@QUIT_CALLBACK);

    if ~ismac && isunix
        set(importData,'BackgroundColor','white');
        set(dipolePlot,'BackgroundColor','white');
        set(singleSubject,'BackgroundColor','white');
        set(groupAnalysis,'BackgroundColor','white');
        set(megSim,'BackgroundColor','white');
        
        set(mriImport,'BackgroundColor','white');
        set(mriViewer,'BackgroundColor','white');
        set(surfaceViewer,'BackgroundColor','white');
        set(DTI_preprocess,'BackgroundColor','white');
    end


    % File Menu
    FILE_MENU=uimenu('Label','File');
    uimenu(FILE_MENU,'label','Open Study...','Callback',@OPEN_STUDY_CALLBACK);
    uimenu(FILE_MENU,'label','Open ImageSet...','Callback',@OPEN_IMAGESET_CALLBACK);
    uimenu(FILE_MENU,'label','Open VS plot...','separator','on','Callback',@OPEN_VS_CALLBACK);
    uimenu(FILE_MENU,'label','Open TFR plot...','Callback',@OPEN_TFR_CALLBACK);
    uimenu(FILE_MENU,'label','Quit BrainWave','separator','on','Callback',@QUIT_CALLBACK);

    TOOLS_MENU=uimenu('Label','Tools');
    uimenu(TOOLS_MENU,'label','Create VS Plots...','Callback',@GROUP_VS_CALLBACK);
    uimenu(TOOLS_MENU,'label','Combine CTF Datasets...','separator','on','Callback',@COMBINE_CALLBACK);
    uimenu(TOOLS_MENU,'label','Concatenate CTF Datasets...','Callback',@CONCAT_CALLBACK);
    uimenu(TOOLS_MENU,'label','Average/Permute Volumes...','separator','on','Callback',@PERMUTE_CALLBACK);
    
    HELP_MENU=uimenu('Label','Help');
    uimenu(HELP_MENU,'label','BrainWave User Manual','Callback',@BW_GUIDE_CALLBACK);
    uimenu(HELP_MENU,'label','DTI Preprocessor User Manual','Callback',@DTI_GUIDE_CALLBACK);
    uimenu(HELP_MENU,'label','About Brainwave','separator','on','Callback',@ABOUT_MENU_CALLBACK);

    
    function BW_GUIDE_CALLBACK(~,~)
        file = sprintf('%s%sBrainwave_v3.5_Documentation_8August2018.pdf', HELP_PATH,filesep);
        if ispc
            winopen(file);
        elseif ~ismac && isunix 
            cmd = sprintf('evince %s', file);
            system(cmd);
        else
            open(file);  
        end            
    end
    
    function DTI_GUIDE_CALLBACK(~,~)        
        file = sprintf('%s%sDTI_Pre-processor_User_Guide.pdf', HELP_PATH,filesep);
        if ispc
            winopen(file);
        elseif ~ismac && isunix 
            cmd = sprintf('evince %s', file);
            system(cmd);
        else
            open(file);  
        end
    end


    function OPEN_STUDY_CALLBACK(~,~)
        [name,path,~] = uigetfile({'*STUDY.mat','BrainWave Study (*STUDY.mat)';'*.mat','All files (*.mat)'},'Select Study ...');
        if isequal(name,0)
            return;
        end
        studyFileFull = fullfile(path,name);

        bw_group_images(studyFileFull);

    end    

    function OPEN_IMAGESET_CALLBACK(~,~)
        bw_mip_plot_4D;   
    end

    function OPEN_VS_CALLBACK(~,~)
        [name,path,~] = uigetfile('*.mat','Select Name for VS file:');
        if isequal(name,0)
            return;
        end
        infile = fullfile(path,name);


        t = load(infile);

        % read old format...(needs testing)
        if isfield(t,'VS_ARRAY')
            VS_ARRAY = t.VS_ARRAY;
            params = t.params;
        else
            fprintf('This does not appear to be a BrainWave VS data file\n');
            return;
        end

        bw_VSplot(VS_ARRAY,params);
    end    


    function OPEN_TFR_CALLBACK(~,~)
        [name,path,~] = uigetfile('*.mat','Select Name for TFR file:');
        if isequal(name,0)
            return;
        end
        infile = fullfile(path,name);


        t = load(infile);

        % read old format...(needs testing)
        if isfield(t,'data')
            TFR_ARRAY = {t.data};
        elseif isfield(t,'TFR_ARRAY')
            TFR_ARRAY = t.TFR_ARRAY;
        else
            fprintf('This does not appear to be a BrainWave Time-Frequency data file\n');
            return;
        end

        bw_plot_tfr(TFR_ARRAY, 0, 'Group Average',name(1:end-4));

    end   

    % old group analysis -- remove?
    function PERMUTE_CALLBACK(~,~)
        bw_group_analysis;
    end

    function GROUP_VS_CALLBACK(~,~)
        bw_plot_dialog;
    end

    function COMBINE_CALLBACK(~,~)    
        startPath = pwd;
        bw_combine_datasets(startPath);
    end

    function CONCAT_CALLBACK(~,~)    
        startPath = pwd;
        bw_concatenate_datasets(startPath);
    end

    function ABOUT_MENU_CALLBACK(~,~)       
       bw_about;       
    end

    % BUTTON callbacks 
    % changed to save parent handles for quiting 

    
    %%%%%%%%%%%%%% MEG modules %%%%%%%%%%%%%

    function IMPORT_DATA_CALLBACK(~,~)       
        bw_import_data;
        fig_handles(end+1) = gcf;
    end

    function DIPOLE_PLOT_CALLBACK(~,~)
        bw_dipoleFitGUI();
        fig_handles(end+1) = gcf;
    end
        
    function SINGLE_SUBJECT_CALLBACK(~,~)       
        bw_single_subject_analysis;
        fig_handles(end+1) = gcf;
    end

    function GROUP_IMAGE_CALLBACK(~,~)       
        bw_group_images([]);
        fig_handles(end+1) = gcf;
    end

    function SIMDS_CALLBACK(~,~)       
        SimDs;
        fig_handles(end+1) = gcf;
    end


    %%%%%%%%%%%%%% MRI modules %%%%%%%%%%%%%

    function MRI_IMPORT_CALLBACK(~,~)    
        [~, mriName] = bw_importMRI;     
        if ~isempty(mriName)
            bw_MRIViewer(mriName);
            fig_handles(end+1) = gcf;
        end
    end
    
    function MRI_VIEWER_CALLBACK(~,~)       
        bw_MRIViewer;
        fig_handles(end+1) = gcf;
    end

    function SURFACE_VIEWER_CALLBACK(~,~)       
        dt_meshViewer;
        fig_handles(end+1) = gcf;
    end

    function DTI_PREPROCESSOR_CALLBACK(~,~)  
        fprintf('** running untested beta version...**\n');
        DTI_preprocessor;
        fig_handles(end+1) = gcf;
    end

    function QUIT_CALLBACK(~,~)   
        response = questdlg('Quit Brainwave?','BrainWave','Yes','No','No');
        if strcmp(response,'Yes')    
            delete(menu);
            if ~isempty(fig_handles)
                % remove invalid handles (window was already closed)
                idx = find(~ishandle(fig_handles));
                fig_handles(idx) = [];
                close(fig_handles);
            end
        end       
    end
       
end
