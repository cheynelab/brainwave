function bw_start
%
%   function bw_start
%
%   DESCRIPTION: Creates the BrainWave's main GUI. 
%   (c) D. Cheyne, 2011. All rights reserved. 
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   June, 2012, Version 2.0
%   
%   This is now main menu to define globals and launch other modules
%
%
%  Last update Sept 18, 2014, Version 3.0 beta
%
%  GLOBALS DEFINED HERE

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

BW_VERSION = '4.0beta (Dec 2021)';

result = license('test','signal_toolbox');
if result == 1
    HAS_SIGNAL_PROCESSING = true;
else
    HAS_SIGNAL_PROCESSING = false;
    fprintf('Signal processing toolbox not found. Some feature may not be available\n');
end    

tpath=which('bw_start');
BW_PATH=tpath(1:end-10);
addpath(BW_PATH);
% 
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

% Check if SPM8 available...
SPM_VERSION = 0;
if ~isempty(strfind(which('spm'),'spm8'))
    SPM_VERSION = 8;
    fprintf('found SPM8 in path... spatial normalization is enabled\n'); 
elseif ~isempty(strfind(which('spm'),'spm12'))
    SPM_VERSION = 12;
    fprintf('found SPM12 in path... spatial normalization is enabled\n'); 
    % need to add the path to "OldNorm" ...
    SPM_PATH=spm('dir');
    spm_defaults; % make sure the old.defaults structure exists?
    oldNormPath = strcat(SPM_PATH,filesep,'toolbox/OldNorm');
    addpath(oldNormPath);

else
    if ~isempty(strfind(which('spm'),'spm2'))
        fprintf('( **** BrainWave no longer supports SPM2.  Please update to SPM8 or SPM12 ***)\n'); 
    end        
end

if SPM_VERSION == 0
    fprintf('Cannot find installation of SPM8 or SPM12, spatial normalization is disabled\n'); 
end

%
scrnsizes=get(0,'MonitorPosition');
button_text = [0.6,0.25,0.1];
button_bkgnd = [0.9,0.9,0.9];
button_fontSize = 12;
button_fontWt = 'bold';

menu=figure('Name', 'BrainWave - Main Menu', 'Units','normalized','Position',[0.4 0.4 0.18 0.38],... % D.C. decreased size a bit...
            'menubar','none','numbertitle','off', 'Color','white', 'CloseRequestFcn',@QUIT_CALLBACK);
if ispc
    movegui(menu,'center');
end
logo=imread('BRAINWAVE_LOGO_2.png');
axes('parent',menu,'position',[0.1 0.02 0.9 0.75]);                  
bh = image(logo);
set(bh,'AlphaData',0.3);
axis off;

if ismac
    IMPORT_DATA=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.3 0.83 0.4 0.09],'String','Import MEG','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@IMPORT_DATA_CALLBACK);

    IMPORT_MRI=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.3 0.7 0.4 0.09],'String','MRI Viewer','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@IMPORT_MRI_CALLBACK);
    
    SINGLE_SUBJECT_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.51 0.6 0.09],'String','Single Subject Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@SINGLE_SUBJECT_CALLBACK);
    
    GROUP_IMAGE_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.38 0.6 0.09],'String','Group Image Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@GROUP_IMAGE_CALLBACK);
    
    GROUP_VS_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.25 0.6 0.09],'String','Group VS Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@GROUP_VS_CALLBACK);

    QUIT_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.35 0.08 0.3 0.09],'String','Quit','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@QUIT_CALLBACK);

elseif isunix 
    
    IMPORT_DATA=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.3 0.83 0.4 0.09],'String','Import MEG','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'BackgroundColor','white','Callback',@IMPORT_DATA_CALLBACK);
    
    IMPORT_MRI=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.3 0.7 0.4 0.09],'String','MRI Viewer','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'BackgroundColor','white','Callback',@IMPORT_MRI_CALLBACK);
    
    SINGLE_SUBJECT_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.51 0.6 0.09],'String','Single Subject Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'BackgroundColor','white','Callback',@SINGLE_SUBJECT_CALLBACK);
    
    GROUP_IMAGE_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.38 0.6 0.09],'String','Group Image Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'BackgroundColor','white','Callback',@GROUP_IMAGE_CALLBACK);
    
    GROUP_VS_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.25 0.6 0.09],'String','Group VS Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'BackgroundColor','white','Callback',@GROUP_VS_CALLBACK);

    QUIT_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.35 0.08 0.3 0.09],'String','Quit','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'BackgroundColor','white','Callback',@QUIT_CALLBACK);
else
    
    IMPORT_DATA=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.25 0.83 0.5 0.09],'String','Import MEG','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@IMPORT_DATA_CALLBACK);
    
    IMPORT_MRI=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.25 0.7 0.5 0.09],'String','MRI Viewer','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@IMPORT_MRI_CALLBACK);
    
    SINGLE_SUBJECT_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.51 0.6 0.09],'String','Single Subject Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@SINGLE_SUBJECT_CALLBACK);
    
    GROUP_IMAGE_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.38 0.6 0.09],'String','Group Image Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@GROUP_IMAGE_CALLBACK);
    
    GROUP_VS_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.2 0.25 0.6 0.09],'String','Group VS Analysis','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@GROUP_VS_CALLBACK);

    QUIT_BUTTON=uicontrol('Style','PushButton','FontSize',button_fontSize,'FontWeight',button_fontWt,'Units','Normalized','Position',...
        [0.35 0.08 0.3 0.09],'String','Quit','HorizontalAlignment','Center',...
        'ForegroundColor',button_text,'Callback',@QUIT_CALLBACK);
    
end

% File Menu
FILE_MENU=uimenu('Label','File');
    uimenu(FILE_MENU,'label','Open Study...','Callback',@OPEN_STUDY_CALLBACK);
    uimenu(FILE_MENU,'label','Open ImageSet...','separator','on','Callback',@OPEN_IMAGESET_CALLBACK);
%     uimenu(FILE_MENU,'label','Open Volumetric ImageSet...','Callback',@OPEN_IMAGESET_CALLBACK);
%     uimenu(FILE_MENU,'label','Open Surface ImageSet...','Callback',@OPEN_SURFACE_IMAGESET_CALLBACK);
    uimenu(FILE_MENU,'label','Open VS plot...','separator','on','Callback',@OPEN_VS_CALLBACK);
    uimenu(FILE_MENU,'label','Open TFR plot...','Callback',@OPEN_TFR_CALLBACK);
    uimenu(FILE_MENU,'label','About Brainwave','separator','on','Callback',@ABOUT_MENU_CALLBACK);

TOOLS_MENU=uimenu('Label','Tools');
    uimenu(TOOLS_MENU,'label','Average/Permute Volumes...','Callback',@PERMUTE_CALLBACK);
    uimenu(TOOLS_MENU,'label','Combine CTF Datasets...','separator','on','Callback',@COMBINE_CALLBACK);

    function OPEN_STUDY_CALLBACK(src,evt)
        [name,path,FilterIndex] = uigetfile({'*STUDY.mat','BrainWave Study (*STUDY.mat)';'*.mat','All files (*.mat)'},'Select Study ...');
        if isequal(name,0)
            return;
        end
        studyFileFull = fullfile(path,name);
        
        bw_group_images(studyFileFull);
        
        end    
    
    function OPEN_IMAGESET_CALLBACK(src,evt)
        [name,path,FilterIndex] = uigetfile({'*VOLUME_IMAGES.mat','VOLUMETRIC IMAGESET (*VOLUME_IMAGES.mat)';
            '*SURFACE_IMAGES.mat','SURFACE IMAGESET (*SURFACE_IMAGES.mat)'; '*.mat','All files (*.mat)'},'Select Imageset to load...');
        if isequal(name,0)
            return;
        end
            infile = fullfile(path,name);
            t = load(infile);
            
            % check image type and open appropriate viewer
            % note we have to cd to the parent directory of the imageset
            % directory (not the .mat file itself) i.e., where the datasets
            % should reside.
            % this is not automatically done by the plot routine itself
            % as this breaks saving single subject imagesets that are saved
            % in the ANALYSIS folders...
            if strcmp(t.imageType, 'Volume')
                cd(path)
                cd ..
                bw_mip_plot_4D(infile);
            elseif strcmp(t.imageType,'Surface')
                cd(path)
                cd ..
                bw_surface_plot_4D(infile);
            else
                fprintf('Unknown file type\n');
            end
        end

%     function OPEN_IMAGESET_CALLBACK(src,evt)
%         bw_mip_plot_4D;
%     end
% 
%     function OPEN_SURFACE_IMAGESET_CALLBACK(src,evt)
%         bw_surface_plot_4D;
%     end

   function OPEN_VS_CALLBACK(src,evt)
        [name,path,FilterIndex] = uigetfile('*.mat','Select Name for VS file:');
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
               
%         bw_plot_vs(VS_ARRAY,params.vs_parameters,groupLabel);
        bw_VSplot(VS_ARRAY,params);
    end    


    function OPEN_TFR_CALLBACK(src,evt)
        [name,path,FilterIndex] = uigetfile('*.mat','Select Name for TFR file:');
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

    function QUIT_CALLBACK(src,evt)   

       if size(get(0,'children'),1) > 1
           response = bw_warning_dialog('Warning: Exiting BrainWave will close all current windows. Proceed?');
           if response == 1           
               delete(menu);
               close all;
               disp('exiting Brainwave...')
           end       
       else
           delete(menu);
           disp('exiting Brainwave...')
       end           
    end

    function COMBINE_CALLBACK(src,evt)        
                
        numFiles = 0;
        fileList = {};
        while true
            % to select using uigetdir           
            file = uigetdir(pwd,'Add a dataset to combine (or cancel to continue)');  
            if isequal(file,0)
                break;
            end

            numFiles = numFiles + 1;
            fileList{numFiles} = file;
            
        end
        saveName = fullfile(pwd,'untitled');          
        [dsName,dsPath,FilterIndex] = uiputfile('*.ds','Select Name for combined dataset:',saveName);
        if isequal(dsName,0)
            return;
        end
        saveName = fullfile(dsPath,dsName);   
        
        if exist(saveName,'dir')
            s = sprintf('The dataset %s already exists! Overwrite?', saveName);
            response = bw_warning_dialog(s);
            if response == 0
                return;
            end
        end
                        
        bw_combineDs(fileList, saveName);
                
    end

    function ABOUT_MENU_CALLBACK(src,evt)       
       bw_about;       
    end

    % old group analysis
    function PERMUTE_CALLBACK(src,evt)
        bw_group_analysis;
    end

    % BUTTON callbacks
    function IMPORT_DATA_CALLBACK(src,evt)       
        bw_import_data;
    end

    function IMPORT_MRI_CALLBACK(src,evt)       
        bw_MRIViewer;
    end

    function SINGLE_SUBJECT_CALLBACK(src,evt)       
        bw_single_subject_analysis;
    end

    function GROUP_IMAGE_CALLBACK(src,evt)       
        bw_group_images([]);
    end

    function GROUP_VS_CALLBACK(src,evt)
        bw_plot_dialog();
    end




end




