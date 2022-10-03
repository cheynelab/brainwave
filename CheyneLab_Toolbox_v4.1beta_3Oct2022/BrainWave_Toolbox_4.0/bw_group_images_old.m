function bw_group_images
%
%   function bw_group_images
%
%   DESCRIPTION: Creates a GUI that allows users to generate images from a
%   list of datasets for group averaging etc.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%
scrnsizes=get(0,'MonitorPosition');

%% Initialize Variables

global defaultPrefsFile

list={};
listfile = '';
selectedfilenum='';


batchJobs.enabled = false;
batchJobs.numJobs = 0;
batchJobs.processes = {};

prefs = bw_checkPrefs;
beam_params =  prefs.beamformer_parameters;
spm_options = prefs.spm_options;

% list option not available yet..
if strcmp(beam_params.beam.use, 'ERB_LIST')
    fprintf('group analysis does not support list mode .. setting to default range...\n');
    beam_params.beam.use = 'ERB';
end

f=figure('Name', 'BrainWave - Group Image Analysis', 'Position', [scrnsizes(1,4)/6 scrnsizes(1,4)/2  850 580],...
            'menubar','none','numbertitle','off', 'Color','white','CloseRequestFcn',@QUIT_MENU_CALLBACK);
            

%% Controls

include_title=uicontrol('style','text','units','normalized','position',...
    [0.03 0.92 0.15 0.05],'string','Datasets:','background','white','HorizontalAlignment','left',...
    'foregroundcolor','blue','fontsize',12);

list_file_text=uicontrol('style','text','units','normalized','position',...
    [0.05 0.05 0.5 0.02],'string',listfile,'background','white','HorizontalAlignment','left',...
    'foregroundcolor','blue','fontsize',10);

MULTI_DS_LISTBOX=uicontrol('style','listbox','units','normalized','position',...
    [0.03 0.5 0.65 0.35],'string',list,'fontsize',10,'max',10000,'background','white');

add_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.03 0.87 0.18 0.05],'string','Add Dataset (s)','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@add_button_callback);

delete_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.24 0.87 0.18 0.05],'string','Delete Dataset','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@delete_button_callback);

clear_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.5 0.87 0.15 0.05],'string','Clear List','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@clear_button_callback);

VIEW_DATA_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
    [0.73 0.9 0.18 0.06],'string','View Average','background','white',...
    'foregroundcolor',[0.8,0.4,0.1],'callback',@view_data_callback);

MULTI_SET_PARAMS_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
    [0.73 0.8 0.18 0.06],'string','Data Parameters','background','white',...
    'foregroundcolor','black','callback',@set_data_params_callback);

MULTI_SET_IMAGE_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
    [0.73 0.7 0.18 0.06],'string','Image Options','background','white',...
    'foregroundcolor','black','callback',@set_image_params_callback);

MULTI_DS_PLOT_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
    [0.7 0.58 0.24 0.06],'string','Generate Group Images','background','white',...
    'foregroundcolor',[0.8,0.4,0.1],'callback',@plot_images_callback);

    
% beamformer controls

uicontrol('style','text','units','normalized','position',...
    [0.05 0.43 0.2 0.05],'string','Select Beamformer','background','white','HorizontalAlignment','center',...
    'fontsize',11,'foregroundcolor','blue','fontweight','bold');
manual_box=annotation('rectangle',[0.02 0.03 0.96 0.435],'EdgeColor','blue');

ERB_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.03 0.348 0.2 0.05],'HorizontalAlignment','Left','String','Event Related:','FontWeight','b','Background','White');

DIFF_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.03 0.24 0.05 0.05],'HorizontalAlignment','Left','String','SAM:','FontWeight','b','Background','White');

RADIO_ERB=uicontrol('style','radiobutton','units','normalized','position',...
    [0.18 0.355 0.1 0.05],'string','','backgroundcolor','white','callback',@RADIO_ERB_CALLBACK);

RADIO_Z=uicontrol('style','radiobutton','units','normalized','position',...
    [0.18 0.24 0.15 0.05],'string',' Pseudo-Z','backgroundcolor','white','callback',@RADIO_Z_CALLBACK);

RADIO_T=uicontrol('style','radiobutton','units','normalized','position',...
    [0.18 0.18 0.15 0.05],'string',' Pseudo-T','backgroundcolor','white','callback',@RADIO_T_CALLBACK);

RADIO_F=uicontrol('style','radiobutton','units','normalized','position',...
    [0.18 0.12 0.15 0.05],'string',' Pseudo-F','backgroundcolor','white','callback',@RADIO_F_CALLBACK);

LATENCY_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.35 0.348 0.2 0.05],'HorizontalAlignment','Left','String','Latency (s):','FontWeight','b','Background','White');

LAT_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.48 0.35 0.08 0.05],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');
START_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.53 0.35 0.07 0.07],'String',beam_params.beam.latencyStart,'BackgroundColor','White','Callback',...
    @PLOT_BEAMFORMER_START_LAT_EDIT_CALLBACK);

LAT_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.61 0.35 0.08 0.05],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
END_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.65 0.35 0.07 0.07],'String',beam_params.beam.latencyEnd,'BackgroundColor','White','Callback',...
    @PLOT_BEAMFORMER_END_LAT_EDIT_CALLBACK);

LAT_STEPSIZE_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.73 0.36 0.04 0.06],'HorizontalAlignment','Left','String','Step Size:','BackgroundColor','White');
STEPSIZE_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.78 0.35 0.07 0.07],'String',beam_params.beam.step,'BackgroundColor',...
    'White','Callback',@PLOT_BEAMFORMER_STEP_LAT_EDIT_CALLBACK);


ACTIVEWINDOW_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.35 0.2 0.12 0.1],'HorizontalAlignment','Left','String','Active Window (s):','FontWeight','b','Background','White');

ACTIVE_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.48 0.23 0.08 0.05],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');
ACTIVE_START_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.53 0.23 0.07 0.07],'String',beam_params.beam.activeStart,'BackgroundColor','White','Callback',...
    @ACTIVE_START_EDIT_CALLBACK);

ACTIVE_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.61 0.23 0.08 0.05],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
ACTIVE_END_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.65 0.23 0.07 0.07],'String',beam_params.beam.activeEnd,'BackgroundColor','White','Callback',...
    @ACTIVE_END_EDIT_CALLBACK);

ACTIVE_STEPSIZE_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.73 0.24 0.04 0.06],'HorizontalAlignment','Left','String','Step Size:','BackgroundColor','White');
ACTIVE_STEP_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.78 0.23 0.07 0.07],'String',beam_params.beam.active_step,'BackgroundColor',...
    'White','Callback',@ACTIVE_STEP_LAT_EDIT_CALLBACK);

ACTIVE_NO_STEP_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.85 0.24 0.05 0.06],'String','No. Steps:','BackgroundColor','White');
ACTIVE_NO_STEP_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.9 0.23 0.07 0.07],'String',beam_params.beam.no_step,'BackgroundColor',...
    'White','Callback',@ACTIVE_NO_STEP_EDIT_CALLBACK);

BASELINEWINDOW_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.35 0.08 0.12 0.1],'HorizontalAlignment','Left','String','Baseline Window (s):','FontWeight','b','Background','White');

BASELINE_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.48 0.1 0.08 0.05],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');
BASELINE_START_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.53 0.1 0.07 0.07],'String',beam_params.beam.baselineStart,'BackgroundColor','White','Callback',...
    @BASELINE_START_EDIT_CALLBACK);

BASELINE_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.61 0.1 0.08 0.05],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
BASELINE_END_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.65 0.1 0.07 0.07],'String',beam_params.beam.baselineEnd,'BackgroundColor','White','Callback',...
    @BASELINE_END_EDIT_CALLBACK);


FILE_MENU=uimenu('Label','File');

uimenu(FILE_MENU,'label','Open List File...','Accelerator','O', 'Callback',@LIST_LOAD_BUTTON_CALLBACK);
SAVE_MENU = uimenu(FILE_MENU,'label','Save List File...','Accelerator','S', 'Callback',@SAVE_LIST_BUTTON_CALLBACK);
uimenu(FILE_MENU,'label','Close','Callback',@QUIT_MENU_CALLBACK,'Accelerator','W','separator','on');


BATCH_MENU=uimenu('Label','Batch');
    START_BATCH=uimenu(BATCH_MENU,'label','Open New Batch','Callback',@START_BATCH_CALLBACK);
    STOP_BATCH=uimenu(BATCH_MENU,'label','Close Batch','Callback',@STOP_BATCH_CALLBACK);
    RUN_BATCH=uimenu(BATCH_MENU,'label','Run Batch...','separator','on','Callback',@RUN_BATCH_CALLBACK);
 

set(STOP_BATCH,'enable','off')            
set(RUN_BATCH,'enable','off')            

set(MULTI_SET_PARAMS_BUTTON,'enable','off')            
set(MULTI_SET_IMAGE_BUTTON,'enable','off')            
set(MULTI_DS_PLOT_BUTTON,'enable','off')            
set(SAVE_MENU,'enable','off') 

updateRadios;


    function MULTI_DS_LISTBOX_CALLBACK(src,evt)
        selectedfilenum=get(src,'value');
    end

    function add_button_callback(src,evt)
                
        dir_list = uigetfile_n_dir(pwd,'Select CTF Datasets...');
        
        if isempty(dir_list)
            return;
        end
        if isempty(list)
            list = dir_list;
        else       
            [rows numInList] = size(list);
            for i=1:size(dir_list,2)
                dsname = dir_list{:,i};
                list{:,numInList+i}=dsname;
            end
        end
        
        % these will be absolute paths so don't need to set CWD !

        set(MULTI_DS_LISTBOX,'string',list)
        set(MULTI_DS_LISTBOX,'enable','on')

        if ~isempty(list)

            set(MULTI_SET_PARAMS_BUTTON,'enable','on')            
            set(MULTI_SET_IMAGE_BUTTON,'enable','on')            
            set(MULTI_DS_PLOT_BUTTON,'enable','on')            
            set(SAVE_MENU,'enable','on')            
        end        

    end


    function delete_button_callback(src,evt)
    
        if isempty(list)
            return;
        end
        selectedfilenum = get(MULTI_DS_LISTBOX,'value');
        list(:,selectedfilenum) = []; 
        selectedfilenum = 1;
                
        set(MULTI_DS_LISTBOX,'string',list);
        set(MULTI_DS_LISTBOX,'value',selectedfilenum); 

        if isempty(list)
            set(MULTI_SET_PARAMS_BUTTON,'enable','off')            
            set(MULTI_SET_IMAGE_BUTTON,'enable','off')            
            set(MULTI_DS_PLOT_BUTTON,'enable','off')            
            set(SAVE_MENU,'enable','off')            
        end
    end

    function clear_button_callback(src,evt)
        list = [];
        set(MULTI_DS_LISTBOX,'string',list);       
        set(MULTI_SET_PARAMS_BUTTON,'enable','off')            
        set(MULTI_SET_IMAGE_BUTTON,'enable','off')            
        set(MULTI_DS_PLOT_BUTTON,'enable','off')            
        set(SAVE_MENU,'enable','off')        
    end


    function SAVE_LIST_BUTTON_CALLBACK(src,evt)
       
        if isempty(list)
           return;
        end   
        
        [name,path,FilterIndex] = uiputfile('*.list','Select Name for list file:');
        if isequal(name,0)
            return;
        end

        listFileName = fullfile(path,name);
        filesToSave = char(list);

        fprintf('Saving list as %s\n', listFileName);
        fid = fopen(listFileName,'w');
        for i=1:size(filesToSave,1)
            file = filesToSave(i,:);
            fprintf(fid,'%s\n',  file);
        end
        fclose(fid);
        
        listfile = listFileName;
        s = sprintf('(List file: %s)',listfile);
        set(list_file_text,'string',s)            
        
    end

    function LIST_LOAD_BUTTON_CALLBACK(src,evt)
        [name path garbaged]=uigetfile('*.list','Select list file of datasets for group analysis');
        if isequal(name,0)
            return;
        end
        
        % new - CWD to path of list file in case of relative file paths
        %
        cd(path)
        fprintf('setting current working directory to %s\n',path);
        
        listfile = fullfile(path,name);
        fID=fopen(listfile);
        count=1;
        list={};
        while ~feof(fID)
            file = fgetl(fID);
            if ~isempty(file)
                list{count}=file;
                count=count+1;
            end
        end
        fclose(fID);
        
        
        
        set(MULTI_DS_LISTBOX,'value',1);  % always point to first file!
        set(MULTI_DS_LISTBOX,'string',list)
        set(MULTI_DS_LISTBOX,'enable','on')

        if ~isempty(list)
            
            dsName = char(list{1,1});
            init_ds_params(dsName);

            set(MULTI_SET_PARAMS_BUTTON,'enable','on')            
            set(MULTI_SET_IMAGE_BUTTON,'enable','on')            
            set(MULTI_DS_PLOT_BUTTON,'enable','on')            
            set(SAVE_MENU,'enable','on')     
            
            listfile = name;
            s = sprintf('(List file: %s)',listfile);
            set(list_file_text,'string',s)            
      
        end
    end

    function PLOT_BEAMFORMER_START_LAT_EDIT_CALLBACK(src,evt)
        beam_params.beam.latencyStart=str2double(get(src,'String'));
    end

    function PLOT_BEAMFORMER_END_LAT_EDIT_CALLBACK(src,evt)
        beam_params.beam.latencyEnd=str2double(get(src,'String'));
    end

    function PLOT_BEAMFORMER_STEP_LAT_EDIT_CALLBACK(src,evt)
        beam_params.beam.step=str2double(get(src,'String'));
    end

    function BASELINE_START_EDIT_CALLBACK(src,evt)
        beam_params.beam.baselineStart=str2double(get(src,'String'));
    end
    
    function BASELINE_END_EDIT_CALLBACK(src,evt)
        beam_params.beam.baselineEnd=str2double(get(src,'String'));
    end

    function ACTIVE_START_EDIT_CALLBACK(src,evt)
        beam_params.beam.activeStart=str2double(get(src,'String'));
    end
    
    function ACTIVE_END_EDIT_CALLBACK(src,evt)
        beam_params.beam.activeEnd=str2double(get(src,'String'));
    end

    function ACTIVE_STEP_LAT_EDIT_CALLBACK(src,evt)
        beam_params.beam.active_step=str2double(get(src,'string'));
    end

    function ACTIVE_NO_STEP_EDIT_CALLBACK(src,evt)
        beam_params.beam.no_step=str2double(get(src,'string'));
    end

    function RADIO_ERB_CALLBACK(src,evt)
        beam_params.beam.use='ERB';
        updateRadios;
    end

    function RADIO_Z_CALLBACK(src,evt)
        beam_params.beam.use='Z';
        updateRadios;
    end

    function RADIO_T_CALLBACK(src,evt)
        beam_params.beam.use='T';
        updateRadios;
    end

    function RADIO_F_CALLBACK(src,evt)
        beam_params.beam.use='F';
        updateRadios;
    end

    function set_image_params_callback(src,evt)
        
        % open using selected - e.g., to import mesh etc...
        if isempty(list)
            return;
        end
        selectedfilenum = get(MULTI_DS_LISTBOX,'value');
        
        if isempty(selectedfilenum)
            fprintf('Must select on dataset in list\n');
            return;
        end
        dsName = char(list{1,selectedfilenum});
        
        [beam_params spm_options] = bw_set_image_options(dsName, beam_params, spm_options);
          
    end

    function view_data_callback(src,evt)
        if isempty(list)
            return;
        end
        selectedfilenum = get(MULTI_DS_LISTBOX,'value');
        
        if isempty(selectedfilenum)
            fprintf('Must select on dataset in list\n');
            return;
        end
        dsName = char(list{1,selectedfilenum});

        bw_plot_data(dsName, beam_params);
    
    end

    function plot_images_callback(src,evt)
        if isempty(list)
            return;
        end
        
        if batchJobs.enabled
            ok = bw_warning_dialog('Add to batch?');
            if ok
                [fname,pathname,filterindex]=uiputfile('*', 'Enter name for Group image:');   
                if isequal(fname,0)
                    return;
                end   
                groupPreFix = fullfile(pathname,fname);
                fprintf('adding group image job %s to batch process...\n', groupPreFix);
                
                % make sure user doesn't overwrite group images
                if  batchJobs.numJobs > 0
                    for i=1:batchJobs.numJobs
                        if strcmp( batchJobs.processes{i}.groupPreFix, groupPreFix)
                            errordlg('Error: Duplicate group image name. Please choose another', 'Batch Processing');
                            return;
                        end
                    end
                end
                
                batchJobs.numJobs = batchJobs.numJobs + 1;
                batchJobs.processes{batchJobs.numJobs}.groupPreFix = groupPreFix;
                batchJobs.processes{batchJobs.numJobs}.list = list;             
                batchJobs.processes{batchJobs.numJobs}.beam_params = beam_params;
                batchJobs.processes{batchJobs.numJobs}.spm_options = spm_options;
                s = sprintf('Close Batch (%d jobs)', batchJobs.numJobs);
                set(STOP_BATCH,'label',s);               
            end
        else
            [fname,pathname,filterindex]=uiputfile('*', 'Enter name for SPM averages:'); %modified by zhengkai   
            if isequal(fname,0)
                return;
            end   
            groupPreFix = fullfile(pathname,fname);
            
            generate_group_images(groupPreFix, list, beam_params, spm_options);
        end
    end

    function set_data_params_callback(src,evt)
       % open using selected - e.g., to import mesh etc...
        if isempty(list)
            return;
        end
        selectedfilenum = get(MULTI_DS_LISTBOX,'value');
        
        if isempty(selectedfilenum)
            fprintf('Must select on dataset in list\n');
            return;
        end
        dsName = char(list{1,selectedfilenum});
        
        beam_params = bw_set_data_parameters(beam_params, dsName);
    end
    

use_spm_radio = uicontrol('Style','radio','Units','Normalized',...
    'HorizontalAlignment','Left','Position',[0.7 0.48 0.14 0.05],'val',~beam_params.useVoxFile,'String','SPM Volume',...
        'BackgroundColor','White', 'Callback',@USE_SPM_CALLBACK); 

use_vox_radio = uicontrol('Style','radio','Units','Normalized',...
    'HorizontalAlignment','Left','Position',[0.83 0.48 0.08 0.05],'val',beam_params.useVoxFile,'String','Surface',...
        'BackgroundColor','White', 'Callback',@USE_VOX_CALLBACK);


    function USE_SPM_CALLBACK(src,evt)
        set(use_vox_radio,'value', 0);
        set(use_spm_radio,'value', 1);    
        beam_params.useVoxFile = 0;       
    end
    
    function USE_VOX_CALLBACK(src,evt)
        set(use_vox_radio, 'value', 1);
        set(use_spm_radio, 'value', 0);    
        beam_params.useVoxFile = 1;       
    end
    
    function updateRadios

        if strcmp(beam_params.beam.use,'ERB')
            set(RADIO_ERB,'value',1)
            set(RADIO_Z,'value',0)
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',0)
            set(LATENCY_LABEL,'enable','on')
            set(LAT_START_LABEL,'enable','on')
            set(LAT_END_LABEL,'enable','on')
            set(START_LAT_EDIT,'enable','on')
            set(END_LAT_EDIT,'enable','on')
            set(LAT_STEPSIZE_LABEL,'enable','on')

            set(STEPSIZE_EDIT,'enable','on')
            set(ACTIVEWINDOW_LABEL,'enable','off')
            set(ACTIVE_START_EDIT,'enable','off')
            set(ACTIVE_START_LABEL,'enable','off')
            set(ACTIVE_END_EDIT,'enable','off')
            set(ACTIVE_END_LABEL,'enable','off')
            set(ACTIVE_STEP_LAT_EDIT,'enable','off')
            set(ACTIVE_STEPSIZE_LABEL,'enable','off')
            set(ACTIVE_NO_STEP_LABEL,'enable','off')
            set(ACTIVE_NO_STEP_EDIT,'enable','off')
            set(BASELINEWINDOW_LABEL,'enable','off')
            set(BASELINE_START_EDIT,'enable','off')
            set(BASELINE_START_LABEL,'enable','off')
            set(BASELINE_END_EDIT,'enable','off')
            set(BASELINE_END_LABEL,'enable','off')       
        else
            set(LATENCY_LABEL,'enable','off')
            set(LAT_START_LABEL,'enable','off')
            set(LAT_END_LABEL,'enable','off')
            set(START_LAT_EDIT,'enable','off')
            set(END_LAT_EDIT,'enable','off')
            set(LAT_STEPSIZE_LABEL,'enable','off')
            set(STEPSIZE_EDIT,'enable','off')
            set(ACTIVEWINDOW_LABEL,'enable','on')
            set(ACTIVE_START_EDIT,'enable','on')
            set(ACTIVE_START_LABEL,'enable','on')
            set(ACTIVE_END_EDIT,'enable','on')
            set(ACTIVE_END_LABEL,'enable','off')
            set(ACTIVE_STEP_LAT_EDIT,'enable','on')
            set(ACTIVE_STEPSIZE_LABEL,'enable','on')
            set(ACTIVE_NO_STEP_LABEL,'enable','on')
            set(ACTIVE_NO_STEP_EDIT,'enable','on')
            set(BASELINEWINDOW_LABEL,'enable','on')
            set(BASELINE_START_EDIT,'enable','on')
            set(BASELINE_START_LABEL,'enable','on')
            set(BASELINE_END_EDIT,'enable','on')
            set(BASELINE_END_LABEL,'enable','on')       
        end
            
        if strcmp(beam_params.beam.use,'Z')
            set(RADIO_ERB,'value',0)
            set(RADIO_Z,'value',1)
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',0)
            set(BASELINEWINDOW_LABEL,'enable','off')
            set(BASELINE_START_EDIT,'enable','off')
            set(BASELINE_START_LABEL,'enable','off')
            set(BASELINE_END_EDIT,'enable','off')
            set(BASELINE_END_LABEL,'enable','off')       
        elseif strcmp(beam_params.beam.use,'T')
            set(RADIO_ERB,'value',0)
            set(RADIO_Z,'value',0)
            set(RADIO_T,'value',1)
            set(RADIO_F,'value',0)
        elseif strcmp(beam_params.beam.use,'F')
            set(RADIO_ERB,'value',0)
            set(RADIO_Z,'value',0)
            set(RADIO_T,'value',0)
            set(RADIO_F,'value',1)
        end
        
    end

    function init_ds_params(dsName)

        ctf_params=bw_CTFGetParams(dsName);

        ctfmin = ctf_params(12); % in s
        ctfmax = ctf_params(13); % in s

        if (beam_params.covWindow(1) == 0 && beam_params.covWindow(2) == 0)
            beam_params.covWindow(1) = ctfmin;
            beam_params.covWindow(2) = ctfmax;
        end
        if (beam_params.baseline(1) == 0 && beam_params.baseline(2) == 0)
            beam_params.baseline(1) = ctfmin;
            beam_params.baseline(2) = ctfmax;
        end
        
        if (beam_params.covWindow(1) < ctfmin), beam_params.covWindow(1) = ctfmin; end;
        if (beam_params.covWindow(2) > ctfmax), beam_params.covWindow(2) = ctfmax; end;
        if (beam_params.baseline(1) < ctfmin), beam_params.baseline(1) = ctfmin; end;
        if (beam_params.baseline(2) > ctfmax), beam_params.baseline(2) = ctfmax; end;
 

    end

    function QUIT_MENU_CALLBACK(src,evt)       
       
        response = bw_warning_dialog('Save beamformer parameters as defaults?');
        if response == 1          
           fprintf('saving current settings to file %s\n', defaultPrefsFile)
           t=load(defaultPrefsFile);
           settings = t.settings; 
           settings.beamparams = beam_params;
           settings.spmoptions = spm_options;
           save(defaultPrefsFile,'settings')
       end       
       delete(f);
    end


    % batch setup
    function START_BATCH_CALLBACK(src,evt)
        batchJobs.enabled = true;
        batchJobs.numJobs = 0;
        batchJobs.processes = {};
       
        set(START_BATCH,'enable','off')            
        set(STOP_BATCH,'enable','on')                
        set(STOP_BATCH,'label','Close Batch');               
    end

    function STOP_BATCH_CALLBACK(src,evt)
        batchJobs.enabled = false;
        if batchJobs.numJobs > 0
            set(RUN_BATCH,'enable','on')        
            set(STOP_BATCH,'enable','off')            
            set(START_BATCH,'enable','off')            
        else
            set(START_BATCH,'enable','on')        
            set(STOP_BATCH,'enable','off')            
            set(RUN_BATCH,'enable','off')            
        end            
    end

    function RUN_BATCH_CALLBACK(src,evt)
        if isempty(batchJobs)
            return;
        end
        numJobs = batchJobs.numJobs;
        s = sprintf('%d group images will be generated.  Do you want to run these now?', numJobs);
        ok = bw_warning_dialog(s);
          
        if ok
            for i=1:numJobs
                fprintf('\n\n*********** Running job %d ***********\n\n', i);
                groupPreFix = batchJobs.processes{i}.groupPreFix;
                list = batchJobs.processes{i}.list;
                beam_params = batchJobs.processes{i}.beam_params;
                spm_options = batchJobs.processes{i}.spm_options;
                plotAll = batchJobs.processes{i}.plotAll;
                generate_group_images(groupPreFix, list, beam_params, spm_options);
            end
            
            fprintf('\n\n*********** finished batch jobs ***********\n\n', i);
            
            batchJobs.enabled = false;
            batchJobs.numJobs = 0;
            batchJobs.processes = {};
            set(START_BATCH,'enable','on')            
            set(RUN_BATCH,'enable','off')        
            set(STOP_BATCH,'enable','off')   
            set(STOP_BATCH,'label','Close Batch');              
        end
        
    end

end

function generate_group_images(groupPreFix, list, params, spm_options)

 
    numSubjects = size(list,2);
   
    groupVoxFile = []; % temp...
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % new for 2.5
    % to eliminate list of list etc 
    % save struct in .mat file for organizing group images...
    % also save averages etc in directory
    
    [path name ext] = bw_fileparts(groupPreFix);
    preFix = fullfile(name,ext);
    groupDir = groupPreFix;
    mkdir(groupDir);
    
    imageset.no_subjects = numSubjects;
    
    % save parameters and options that were used to generate this average
    imageset.params = params;
    imageset.spm_options = spm_options;
       
    wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wbh,'canceling',0)
       
    % first generate images for all subjects and timepoints and save in
    % individual files in subject directories
    for n=1:numSubjects
                
        if getappdata(wbh,'canceling')
            delete(wbh);   
            fprintf('*** cancelled ***\n');
            return;
        end
        waitbar(n/numSubjects,wbh,sprintf('generating images for subject %d',n));
     
        dsName = deblank( list{1,n} );             
        [ds_path, ds_name, subject_ID, mriDir, mri_filename] = bw_parse_ds_filename(dsName);          
        fprintf('processing file -> %s ...\n', ds_name);      
        
        imageset.dsName{n} = ds_name;
        
        imageList = bw_make_beamformer(dsName, params); 
                  
        if params.useVoxFile   
                
            % need to average vtk files...for now set to subject 1....
            voxFile = fullfile(mriDir, params.voxFile);                             
            imageset.voxfiles{n} = voxFile;
            imageset.imageType = 'Surface';
            
            % need to check is CIVET mesh ??
            imageset.isNormalized = false;
            imageset.imageList{n} = char(imageList);
            numLatencies = size(imageList,1);   % same for each ...       
        else  
            % generate SPM normalized images...
                if isempty(mri_filename)
                    fprintf('Could not locate mri file for this dataset...\n');
                    delete(wbh);
                    return;
                end                        
                imageset.mriName{n} = mri_filename;     
                imageset.isNormalized = true;
                imageset.imageType = 'Volume';

                fprintf('Normalizing images...\n');      
                normalized_imageList = bw_normalize_images(mri_filename, imageList, spm_options);             
                imageset.imageList{n} = char(normalized_imageList);
                numLatencies = size(normalized_imageList,1);   % same for each ...
       end
        
        if isempty(imageList)
            delete(wbh); 
            return;     % bw_make_beamformer possibly returned error..
        end
       
        % imageList contains a list of images at all latencies for this subject
        % the filenames are also in the correct temporal order
        
        % need to build a N subject X M latency table ...
    end
    
    imageset.no_images = numLatencies;
    
    delete(wbh); 
     
    % generate grand averages and save in named directory 
    
    % have to image across subjects for each latency 
    % by parsing the subject x latency image lists
    
    for k=1:numLatencies

        for j=1:numSubjects
             slist = char( imageset.imageList(j) );
             tlist{j} = slist(k,:);
        end
        aveList = deblank(tlist');
        name = char(aveList(1,:));
        [path basename ext] = bw_fileparts(name);
        
        % need unique name for average   
        if params.useVoxFile
            aveName = sprintf('%s%s%s_%s.txt', groupDir,filesep,preFix,basename);        
        else
            aveName = sprintf('%s%s%s_%s.nii', groupDir,filesep,preFix,basename);
        end
        aveName = deblank(aveName);
        fprintf('generating average -->%s\n', aveName);
        
        bw_average_images(aveList, aveName);  % average without plotting        
        
        % save average names for plotting...
        imageset.averageList{k} = aveName;
    end

    % save image set info - this should be all that is needed to plot
    % images independently of # of latecies or files...
    imagesetName = sprintf('%s%s%s_IMAGES.mat', groupDir,filesep,preFix);

    fprintf('Saving image set information in %s\n', imagesetName);
    save(imagesetName, '-struct', 'imageset');

    if params.useVoxFile
        bw_surface_plot_4D(imagesetName);  
    else
        bw_mip_plot_4D(imagesetName);
    end
    
    
end


