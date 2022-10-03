function bw_group_images (inputFile)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   function bw_group_images
%
%   DESCRIPTION: Creates a GUI that allows users to generate images from a
%   list of datasets for group averaging etc.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
% 
% updated Dec, 2015  D. Cheyne
%
% Version 4.0 March 2022 - removed surface based group imaging
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


scrnsizes=get(0,'MonitorPosition');

global BW_VERSION

batchJobs.enabled = false;
batchJobs.numJobs = 0;
batchJobs.processes = {};

% get prefs from study structure instead...

% removed this since prefs saved with Study can be used instead

% prefs = bw_checkPrefs;
% params.beamformer_parameters =  prefs.beamformer_parameters;
% params.spm_options = prefs.params.spm_options;

% [params.beamformer_parameters, vs_options, tfr_options] = bw_setDefaultParameters;  
% *** bug fix in version 3.0beta release ***
params = bw_setDefaultParameters;

currentStudyFile = '';
currentStudyDir = '';
study = [];
study.no_conditions = 0;
condition1 = 1;
condition2 = 1;
covCondition= 1;
conditionType = 1;

selectedDataset = '';

changes_saved = true;
displayResults = true;

f=figure('Name', 'BrainWave - Group Image Analysis', 'Position', [scrnsizes(1,4)/6 scrnsizes(1,4)/2  1250 800],...
            'menubar','none','numbertitle','off', 'Color','white','CloseRequestFcn',@QUIT_MENU_CALLBACK);
if ispc
    movegui(f,'center');
end
FILE_MENU=uimenu('Label','File');
uimenu(FILE_MENU,'label','New Study...','Accelerator','N', 'Callback',@NEW_STUDY_BUTTON_CALLBACK);
uimenu(FILE_MENU,'label','Open Study...','Accelerator','O', 'Callback',@OPEN_STUDY_BUTTON_CALLBACK);

SAVE_STUDY_BUTTON = uimenu(FILE_MENU,'label','Save Study','Accelerator','S',...
    'separator','on','Callback',@SAVE_STUDY_BUTTON_CALLBACK);
SAVE_STUDY_AS_BUTTON = uimenu(FILE_MENU,'label','Save Study As...','Callback',@SAVE_STUDY_AS_BUTTON_CALLBACK);

ADD_CONDITION_BUTTON = uimenu(FILE_MENU,'label','Add Condition...','Accelerator','A','separator','on', 'Callback',@add_condition_callback);
REMOVE_CONDITION_BUTTON = uimenu(FILE_MENU,'label','Remove Condition...','Accelerator','D', 'Callback',@remove_condition_callback);
COMBINE_CONDITION_BUTTON = uimenu(FILE_MENU,'label','Combine Conditions...','Accelerator','C', 'Callback',@combine_condition_callback);
uimenu(FILE_MENU,'label','Copy Head Models...','Accelerator','H','separator','on', 'Callback',@copyHeadModels_callback);

uimenu(FILE_MENU,'label','Close','Callback',@QUIT_MENU_CALLBACK,'Accelerator','W','separator','on');

BATCH_MENU=uimenu('Label','Batch');
START_BATCH=uimenu(BATCH_MENU,'label','Open New Batch','Callback',@START_BATCH_CALLBACK);
STOP_BATCH=uimenu(BATCH_MENU,'label','Close Batch','Callback',@STOP_BATCH_CALLBACK);
RUN_BATCH=uimenu(BATCH_MENU,'label','Run Batch...','separator','on','Callback',@RUN_BATCH_CALLBACK); 

IMAGESETS_MENU=uimenu('Label','ImageSets');    
set(IMAGESETS_MENU,'enable','off');

% list option not available yet..
if strcmp(params.beamformer_parameters.beam.use, 'ERB_LIST')
    fprintf('group analysis does not support list mode .. setting to default range...\n');
    params.beamformer_parameters.beam.use = 'ERB';
end

uicontrol('style','text','units','normalized','position',...
    [0.03 0.925 0.12 0.05],'string','Select Condition:','background','white','HorizontalAlignment','left',...
    'foregroundcolor','black','fontsize',12,'fontweight','bold');
CONDITION1_LISTBOX=uicontrol('style','listbox','units','normalized','position',...
    [0.03 0.62 0.28 0.32],'string','','fontsize',11,'background','white','callback',@condition1_callback);
CONDITION1_DROP_DOWN=uicontrol('style','popup','units','normalized','position',...
    [0.17 0.93 0.14 0.05],'string',{'None'},'background','white',...
    'foregroundcolor','blue','fontsize',12,'callback',@condition1_dropdown_callback);

uicontrol('style','checkbox','units','normalized','position',...
    [0.35 0.94 0.12 0.05],'string','Contrast with:','background','white','value',params.beamformer_parameters.contrastImage,...
    'fontsize',12,'fontweight','bold','callback',@contrast_check_callback);
CONDITION2_LISTBOX=uicontrol('style','listbox','units','normalized','enable','off','position',...
    [0.35 0.62 0.28 0.32],'string','','fontsize',11,'max',10000,'background','white','callback',@condition2_callback);
CONDITION2_DROP_DOWN=uicontrol('style','popup','units','normalized','position',...
    [0.49 0.93 0.14 0.05],'string',{'None'},'background','white','enable','off',...
    'foregroundcolor','blue','fontsize',12,'callback',@condition2_dropdown_callback);

COV_CONDITION_TITLE = uicontrol('style','text','units','normalized','position',...
    [0.68 0.925 0.15 0.05],'string','Covariance Condition:','background','white','HorizontalAlignment','left',...
    'foregroundcolor','black','fontsize',12,'fontweight','bold');
COV_LISTBOX=uicontrol('style','listbox','units','normalized','position',...
    [0.68 0.62 0.29 0.32],'string','','fontsize',11,'max',10000,'background','white','callback',@cov_callback);
COV_DROP_DOWN=uicontrol('style','popup','units','normalized','position',...
    [0.83 0.93 0.14 0.05],'string',{'None'},'background','white',...
    'foregroundcolor','blue','fontsize',12,'callback',@cov_dropdown_callback);

    function contrast_check_callback(src,~)
        val = get(src,'value');
        if val
            conditionType = 3;
            params.beamformer_parameters.contrastImage = 1;
            set(CONDITION2_DROP_DOWN,'enable','on');
            set(CONDITION2_LISTBOX,'enable','on');
        else
            conditionType = 1;
            params.beamformer_parameters.contrastImage = 0;
            set(CONDITION2_DROP_DOWN,'enable','off');
            set(CONDITION2_LISTBOX,'enable','off');
        end
    end

ADD1_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.03 0.58 0.09 0.025],...
    'string','Add datasets','callback',@ADD1_BUTTON_CALLBACK);
DELETE1_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.13 0.58 0.09 0.026],...
    'string','Remove datasets','callback',@DELETE1_BUTTON_CALLBACK);

DATASET_NUM_TEXT = uicontrol('style','text','units','normalized','position',...
    [0.23 0.58 0.05 0.03],'string','(n = 0)','background','white','fontsize',12);

GENERATE_IMAGES_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
    [0.72 0.1 0.2 0.07],'string','Generate Group Images',...
    'foregroundcolor',[0.8,0.4,0.1],'callback',@plot_images_callback);

if isunix && ~ismac
    set(ADD1_BUTTON,'Backgroundcolor','white');
    set(DELETE1_BUTTON,'Backgroundcolor','white');
    set(GENERATE_IMAGES_BUTTON,'Backgroundcolor','white');
end

uicontrol('style','checkbox','units','normalized','position',...
   [0.72 0.02 0.12 0.05],'string','Display Results','fontsize',12,'value',displayResults,...
   'Backgroundcolor','white','callback',@display_results_callback);

% beamformer controls
uicontrol('style','text','units','normalized','position',...
    [0.05 0.5 0.2 0.05],'string','Latency / Time Windows','background','white','HorizontalAlignment','center',...
    'fontsize',11,'foregroundcolor','blue','fontweight','bold');
annotation('rectangle',[0.02 0.25 0.96 0.29],'EdgeColor','blue');

uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.05 0.45 0.2 0.05],'HorizontalAlignment','Left','String','ERB:','FontWeight','b','Background','White');

RADIO_ERB=uicontrol('style','radiobutton','units','normalized','position',...
    [0.12 0.46 0.1 0.05],'string','','backgroundcolor','white','callback',@RADIO_ERB_CALLBACK);

LATENCY_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.34 0.45 0.2 0.05],'HorizontalAlignment','Left','String','Latency (s):','FontWeight','b','Background','White');

LAT_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.48 0.45 0.08 0.05],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');
START_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.53 0.46 0.07 0.05],'String',params.beamformer_parameters.beam.latencyStart,'BackgroundColor','White','Callback',...
    @PLOT_BEAMFORMER_START_LAT_EDIT_CALLBACK);

LAT_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.61 0.45 0.08 0.05],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
END_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.65 0.46 0.07 0.05],'String',params.beamformer_parameters.beam.latencyEnd,'BackgroundColor','White','Callback',...
    @PLOT_BEAMFORMER_END_LAT_EDIT_CALLBACK);

LAT_STEPSIZE_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.73 0.45 0.04 0.06],'HorizontalAlignment','Left','String','Step Size:','BackgroundColor','White');
STEPSIZE_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.78 0.46 0.07 0.05],'String',params.beamformer_parameters.beam.step,'BackgroundColor',...
    'White','Callback',@PLOT_BEAMFORMER_STEP_LAT_EDIT_CALLBACK);

uicontrol('style','check', 'units', 'normalized','position',[0.86 0.46 0.12 0.05],...
        'Background','white','String','compute mean','FontSize', 10,'Value', params.beamformer_parameters.mean,'callback',@mean_check_callback);

uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.05 0.375 0.05 0.05],'HorizontalAlignment','Left','String','SAM:','FontWeight','b','Background','White');

RADIO_Z=uicontrol('style','radiobutton','units','normalized','position',...
    [0.12 0.39 0.15 0.05],'string',' Pseudo-Z','backgroundcolor','white','callback',@RADIO_Z_CALLBACK);

RADIO_T=uicontrol('style','radiobutton','units','normalized','position',...
    [0.12 0.33 0.15 0.05],'string',' Pseudo-T','backgroundcolor','white','callback',@RADIO_T_CALLBACK);

RADIO_F=uicontrol('style','radiobutton','units','normalized','position',...
    [0.22 0.33 0.15 0.05],'string',' Pseudo-F','backgroundcolor','white','callback',@RADIO_F_CALLBACK);

ACTIVEWINDOW_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.34 0.38 0.14 0.05],'HorizontalAlignment','Left','String','Active Window (s):','FontWeight','b','Background','White');

ACTIVE_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.48 0.38 0.08 0.05],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');

ACTIVE_START_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.53 0.39 0.07 0.05],'String',params.beamformer_parameters.beam.activeStart,'BackgroundColor','White','Callback',...
    @ACTIVE_START_EDIT_CALLBACK);

ACTIVE_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.61 0.38 0.08 0.05],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
ACTIVE_END_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.65 0.39 0.07 0.05],'String',params.beamformer_parameters.beam.activeEnd,'BackgroundColor','White','Callback',...
    @ACTIVE_END_EDIT_CALLBACK);

ACTIVE_STEPSIZE_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.73 0.38 0.04 0.06],'HorizontalAlignment','Left','String','Step Size:','BackgroundColor','White');
ACTIVE_STEP_LAT_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.78 0.39 0.07 0.05],'String',params.beamformer_parameters.beam.active_step,'BackgroundColor',...
    'White','Callback',@ACTIVE_STEP_LAT_EDIT_CALLBACK);

ACTIVE_NO_STEP_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.85 0.38 0.03 0.06],'String','No. Steps:','BackgroundColor','White');
ACTIVE_NO_STEP_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.9 0.39 0.07 0.05],'String',params.beamformer_parameters.beam.no_step,'BackgroundColor',...
    'White','Callback',@ACTIVE_NO_STEP_EDIT_CALLBACK);

BASELINEWINDOW_LABEL=uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',...
    [0.34 0.32 0.14 0.05],'HorizontalAlignment','Left','String','Baseline Window (s):','FontWeight','b','Background','White');

BASELINE_START_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.48 0.32 0.08 0.05],'HorizontalAlignment','Left','String','Start:','BackgroundColor','White');
BASELINE_START_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.53 0.33 0.07 0.05],'String',params.beamformer_parameters.beam.baselineStart,'BackgroundColor','White','Callback',...
    @BASELINE_START_EDIT_CALLBACK);

BASELINE_END_LABEL=uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.61 0.32 0.08 0.05],'HorizontalAlignment','Left','String','End:','BackgroundColor','White');
BASELINE_END_EDIT=uicontrol('Style','Edit','FontSize',10,'Units','Normalized','Position',...
    [0.65 0.33 0.07 0.05],'String',params.beamformer_parameters.beam.baselineEnd,'BackgroundColor','White','Callback',...
    @BASELINE_END_EDIT_CALLBACK);

% version 4.0 - for now removed surface options for group averaging - this
% can be done elsewhere
uicontrol('Style','radiobutton','FontSize',10,'Units','Normalized','Position',...
    [0.05 0.14 0.2 0.04],'String','Volume (MNI coordinates)','HorizontalAlignment','Center',...
    'BackgroundColor','White','value',1,'Callback',@VOLUME_RADIO_CALLBACK);

uicontrol('Style','PushButton','FontSize',10,'Units','Normalized','Position',...
    [0.2 0.13 0.14 0.05],'String','Image Options...','HorizontalAlignment','Center',...
    'Callback',@set_image_params_callback);

SET_PARAMS_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
    [0.36 0.13 0.14 0.05],'string','Data Parameters',...
    'foregroundcolor','black','callback',@set_data_params_callback);
if isunix && ~ismac
    set(SET_PARAMS_BUTTON,'Backgroundcolor','white');
end

uicontrol('style','text','fontsize',11,'units','normalized','position',...
    [0.03 0.21 0.12 0.02],'string','Image Parameters','BackgroundColor','white','foregroundcolor','blue','fontweight','b');
annotation('rectangle',[0.02 0.03 0.55 0.19],'EdgeColor','blue');

set(STOP_BATCH,'enable','off')            
set(RUN_BATCH,'enable','off')            

set(SAVE_STUDY_BUTTON, 'enable','off');
set(SAVE_STUDY_AS_BUTTON, 'enable','off');
set(ADD_CONDITION_BUTTON, 'enable','off');
set(REMOVE_CONDITION_BUTTON, 'enable','off');
set(COMBINE_CONDITION_BUTTON, 'enable','off');

set(SET_PARAMS_BUTTON,'enable','off')            
set(GENERATE_IMAGES_BUTTON,'enable','off')            

set(ADD1_BUTTON,'enable','off')            
set(DELETE1_BUTTON,'enable','off')            

updateRadios;

if exist(inputFile,'file')      
    open_Study(inputFile);
end

    function NEW_STUDY_BUTTON_CALLBACK(~,~)
       
        if changes_saved == false
            s = sprintf('Open new study without saving changes?');     
            response = questdlg(s,'BrainWave','Yes','Cancel','Yes');
            if strcmp(response,'Cancel')
                return;
            end
        end
        
        [name, path,~] = uiputfile('new_STUDY.mat','Select Name for Study:','new_STUDY.mat');
        if isequal(name,0)
            return;
        end

        currentStudyFile = fullfile(path,name);
        currentStudyDir = path;
        cd(currentStudyDir);
        
        [~, studyName, ~] = fileparts(currentStudyFile);
        studyName = strrep(studyName,'_STUDY','');
        
        study.name = studyName;
        study.originalPath = currentStudyFile;
        study.conditions = [];
        study.conditionNames = [];
        study.no_conditions = 0;
        study.imagesets = [];
        
        prompt = {'Condition 1:','Condition 2:','Condition 3:','Condition 4:','Condition 5:',...
            'Condition 6:','Condition 7:','Condition 8:','Condition 9:','Condition 10'};
        title = 'Enter Labels for up to 10 Conditions ';
        dims = [1 100];
        definput = {'','','','','','','','','',''};
        input = inputdlg(prompt,title,dims,definput);
        
        for k=1:size(input,1)
            name = char(input{k});
            if ~isempty(name)
                study.no_conditions = study.no_conditions + 1;
                study.conditionNames{k} = name;
                study.conditions{k} = [];  % datasets for this condition
            end
        end
        
        % use current parameters
        params = bw_setDefaultParameters;     
        study.params = params;
        study.version = BW_VERSION;

        set(CONDITION1_DROP_DOWN, 'string',study.conditionNames);
        set(CONDITION1_LISTBOX, 'string','');
        set(CONDITION2_DROP_DOWN, 'string',study.conditionNames);
        set(CONDITION2_LISTBOX, 'string','');
        set(CONDITION2_LISTBOX, 'string','');
        set(COV_DROP_DOWN,'string',study.conditionNames); 
        set(COV_LISTBOX, 'string','');
        
        save(currentStudyFile, '-struct', 'study');
        set(SAVE_STUDY_BUTTON,'enable','on');
        set(SAVE_STUDY_AS_BUTTON,'enable','on');
        set(ADD_CONDITION_BUTTON, 'enable','on');
        set(REMOVE_CONDITION_BUTTON, 'enable','on');
        set(COMBINE_CONDITION_BUTTON, 'enable','on');
        set(CONDITION1_DROP_DOWN, 'enable','on');
        set(CONDITION1_LISTBOX, 'enable','on');            
     
        
        set(SET_PARAMS_BUTTON,'enable','on')            
        set(GENERATE_IMAGES_BUTTON,'enable','on')            
        set(ADD1_BUTTON,'enable','on')            
        set(DELETE1_BUTTON,'enable','on')     
        
        s = sprintf('BrainWave - Group Image Analysis [%s]',study.name); 
        set(f,'Name',s);
        covCondition= 1;
        conditionType = 1;
        
        updateRadios
        s = sprintf('(n = 0)');       
        set(DATASET_NUM_TEXT,'string',s);          
    end

    function ADD1_BUTTON_CALLBACK(~,~)
         if isempty(study)
            return;
         end
        
        [s, ~, ~] = fileparts( currentStudyFile );       
        dsList = uigetdir2(s, 'Choose datasets for this condition...');
        
        if ~isempty(dsList) 
            s = cellfun(@removeFilePath, dsList,'UniformOutput',false);
            cond = get(CONDITION1_DROP_DOWN,'value');
            dsNames = study.conditions{cond};
            dsNames = [dsNames s];
            dsNames = sort(dsNames);
            study.conditions{cond} = dsNames;
            set(CONDITION1_LISTBOX,'string',dsNames );    
            changes_saved = false;
        end
       
        s = sprintf('(n = %d)',numel(dsNames));       
        set(DATASET_NUM_TEXT,'string',s);
    end

    function DELETE1_BUTTON_CALLBACK(~,~)
        if isempty(study)
            return;
        end
        if isempty(CONDITION1_LISTBOX)
            return;
        end
        selectedRow = get(CONDITION1_LISTBOX,'value');
        cond = get(CONDITION1_DROP_DOWN,'value');
        dsNames = study.conditions{cond};
        
        s = sprintf('Delete dataset [%s] from this condition?', char(dsNames(selectedRow)) );     
        response = questdlg(s,'BrainWave','Yes','Cancel','Yes');
        if strcmp(response,'Cancel')
            return;
        end
        dsNames(selectedRow) = [];
        study.conditions{cond} = dsNames;
        set(CONDITION1_LISTBOX,'string',  dsNames );    
        set(CONDITION1_LISTBOX,'value',  1 );    
        changes_saved = false;

        s = sprintf('(n = %d)',numel(dsNames));       
        set(DATASET_NUM_TEXT,'string',s);     
   end

    function SAVE_STUDY_BUTTON_CALLBACK(~,~)     
        if isempty(study)
            return;
        end
        save_changes;       
    end

   function SAVE_STUDY_AS_BUTTON_CALLBACK(~,~)
       
        [name,path,~] = uiputfile('new_STUDY.mat','Select Name for Study:', currentStudyFile);
        if isequal(name,0)
            return;
        end
        currentStudyFile = fullfile(path,name);
       
        fprintf('Saving study information to %s\n', currentStudyFile);
        save_changes;        

        [~, studyName, ~] = fileparts(currentStudyFile);
        studyName = strrep(studyName,'_STUDY','');       
        study.name = studyName;
              
        s = sprintf('BrainWave - Group Image Analysis [%s]',study.name); 
        set(f,'Name',s);
   end

   function save_changes
        study.params = params;
        
        fprintf('Saving study information to %s\n', currentStudyFile);
        save(currentStudyFile, '-struct', 'study');
        changes_saved = true;       
   end


   function OPEN_STUDY_BUTTON_CALLBACK(~,~)
       
       if changes_saved == false
            response = questdlg('Open new study without saving changes?','BrainWave','Yes','Cancel','Yes');
            if strcmp(response,'Cancel')
                return;
            end                
       end
       
       [name, path, ~]=uigetfile({'*_STUDY.mat', 'GROUP STUDY (*_STUDY.mat)'},'Select a STUDY');
        if isequal(name,0)
            return;
        end
        
        filename = fullfile(path,name);
        
        open_Study(filename);
               
   end

   function open_Study(studyFileFull)
        
        currentStudyFile = studyFileFull;
        [currentStudyDir, ~, ~] = fileparts(studyFileFull);
        
        study = load(currentStudyFile);
        
        response = questdlg('Load the previously saved settings?','BrainWave','Use Previous','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end                 
        
        if strcmp(response,'Use Previous') 
            % update old study formats using version number
            if ~isfield(study,'version')
                fprintf('updating Study ...\n');
                study.version = BW_VERSION;
                study.imagesets = [];
                old_params = study.params;
                study.params = bw_setDefaultParameters;
                study.params.beamformer_parameters = old_params;          
                changes_saved = false;
            else
                params = study.params;
            end
        else
            params = bw_setDefaultParameters;
        end
            
        % overwrite defaults - always use cov or baseline lists
        params.beamformer_parameters.multiDsSAM = 0;
        params.beamformer_parameters.covarianceType = 2;
        
        
        set(SAVE_STUDY_BUTTON,'enable','on');
        set(SAVE_STUDY_AS_BUTTON,'enable','on');
        set(ADD_CONDITION_BUTTON, 'enable','on');
        set(REMOVE_CONDITION_BUTTON, 'enable','on');
        set(COMBINE_CONDITION_BUTTON, 'enable','on');
        set(CONDITION1_DROP_DOWN, 'enable','on');
        set(CONDITION1_LISTBOX, 'enable','on');        
        
        % initiale to first condition....
        set(CONDITION1_DROP_DOWN,'string',study.conditionNames);
        set(CONDITION2_DROP_DOWN,'string',study.conditionNames);
        set(COV_DROP_DOWN,'string',study.conditionNames); 
        
        % new - CWD to path of list file in case of relative file paths
        %
        cd(currentStudyDir)
        fprintf('setting current working directory to %s\n',currentStudyDir);
               
        condition1 = 1;      
        set(CONDITION1_DROP_DOWN,'value',condition1 );   
        dsNames = study.conditions{condition1};
        
        set(COV_DROP_DOWN,'value',condition1 );    
        set(CONDITION2_DROP_DOWN,'value',condition1);   
                  
        % update list boxes unless datasets haven't been added yet
        if ~isempty(dsNames)
            set(CONDITION1_LISTBOX,'string',dsNames );
            set(COV_LISTBOX,'string',dsNames );      
            set(CONDITION2_LISTBOX,'string',dsNames );
            s = sprintf('(n = %d)',numel(dsNames));       
            set(DATASET_NUM_TEXT,'string',s);   
            selectedDataset = fullfile(char(currentStudyDir), char(dsNames(1)) );
        end
                        
        set(SET_PARAMS_BUTTON,'enable','on')            
        set(GENERATE_IMAGES_BUTTON,'enable','on')            
         
        set(ADD1_BUTTON,'enable','on')            
        set(DELETE1_BUTTON,'enable','on')            
        s = sprintf('BrainWave - Group Image Analysis [%s]',study.name); 
        set(f,'Name',s);
         
        % reset radios to default
        covCondition= 1;
        conditionType = 1;

        set(ACTIVE_START_EDIT,'string', params.beamformer_parameters.beam.activeStart);
        set(ACTIVE_END_EDIT,'string', params.beamformer_parameters.beam.activeEnd);
        set(ACTIVE_STEP_LAT_EDIT,'string', params.beamformer_parameters.beam.active_step);
        set(ACTIVE_NO_STEP_EDIT,'string', params.beamformer_parameters.beam.no_step);
        set(BASELINE_START_EDIT,'string', params.beamformer_parameters.beam.baselineStart);
        set(BASELINE_END_EDIT,'string', params.beamformer_parameters.beam.baselineEnd);

        updateRadios;

        updateImageListMenu;
 
   end

    function remove_condition_callback(~,~)
     
        [condName, condIdx, ~] = bw_getConditionList('Select Condition to delete', currentStudyFile);
        
        if isempty(condName)
            return;
        end
        study.conditions(condIdx) = [];
        study.conditionNames(condIdx) = [];
        study.no_conditions = study.no_conditions - 1;
        changes_saved = false;

        % update lists
        set(CONDITION1_DROP_DOWN,'string', study.conditionNames);                
        set(CONDITION2_DROP_DOWN,'string', study.conditionNames);        
        set(COV_DROP_DOWN,'string', study.conditionNames);  
        save_changes;       
                       
    end

    function add_condition_callback(~,~)
               
        [s, ~, ~] = fileparts( currentStudyFile );
        if isempty(s)
            return;
        end
        
        dsList = uigetdir2(s, 'Choose datasets for this condition...');
        if isempty(dsList)
            return;
        end
        
        for k=1:size(dsList,2)
            s = char(dsList{k});
            [~, dsNames{k}, ext] = fileparts(s);
            dsNames{k} = strcat(dsNames{k}, ext);
        end

        conditionName = getConditionName();
        
        if isempty(conditionName)
            return;
        end     
        
        study.no_conditions = study.no_conditions + 1;
        
        study.conditions{study.no_conditions} = dsNames;
        study.conditionNames{study.no_conditions} = conditionName;
        
        set(CONDITION1_LISTBOX,'string',study.conditions{study.no_conditions} );
        set(CONDITION1_LISTBOX,'value',1);
        
        selectedDataset = fullfile(char(currentStudyDir), char(dsNames(1)) );

        % update lists
        set(CONDITION1_DROP_DOWN,'string', study.conditionNames);            
        set(CONDITION2_DROP_DOWN,'string', study.conditionNames);        
        set(COV_DROP_DOWN,'string', study.conditionNames);              
        set(CONDITION1_DROP_DOWN,'value', study.no_conditions);      
        
        set(SET_PARAMS_BUTTON,'enable','on')            
        set(GENERATE_IMAGES_BUTTON,'enable','on')        
        changes_saved = false;

        
    end

    function combine_condition_callback(~,~)
                      
        response = questdlg('Combine two conditions?','BrainWave','Yes','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end  
        
        [condName1, condIdx1, ~] = bw_getConditionList('Select Condition 1 ...', currentStudyFile);
        [~, condIdx2, ~] = bw_getConditionList('Select Condition 2 ...', currentStudyFile);
        
        if isempty(condName1)
            return;
        end
        
        conditionName = getConditionName();
        
        if isempty(conditionName)
            return;
        end
        
        % combine Datasets  

        dsList1 =  study.conditions{condIdx1};
        dsList2 =  study.conditions{condIdx2};  

        for j=1:size(dsList1,2)
            dsName1  = deblank( dsList1{1,j} );
            [~, name1, ~] = fileparts(dsName1);
            idx = strfind(name1,'_');
            subject_ID1 = name1(1:idx-1);
            basename1 = name1(idx+1:end);

            dsName2  = deblank( dsList2{1,j} );
            [~, name2, ~] = fileparts(dsName2);
            idx = strfind(name2,'_');
            subject_ID2 = name2(1:idx-1);
            basename2 = name2(idx+1:end);
            
            if strcmp(subject_ID1,subject_ID2) == 0
                errordlg('Subject ID does not match ... check condition lists');
                return;
            end
            combinedDsName = sprintf('%s_%s+%s.ds', subject_ID1,basename1,basename2);
            
            % check if combined ds exists already
            if exist(combinedDsName) == 7
                s = sprintf('dataset %s already exists...', combinedDsName);
                errordlg(s);
                return;
            else
                fprintf('***********************************************************************************\n');
                fprintf('creating combined dataset --> %s for for common weights covariance calculation...\n\n', combinedDsName);
                bw_combineDs({dsName1, dsName2}, combinedDsName);
                % D. Cheyne 3.4 copy any head models from the first
                % dataset to the combined dataset, assuming these are always same subject. 
                bw_copyHeadModels(dsName1,combinedDsName);
            end  
            dsNames{j} = combinedDsName;
            
        end
                       
        study.no_conditions = study.no_conditions + 1;
        
        study.conditions{study.no_conditions} = dsNames;
        study.conditionNames{study.no_conditions} = conditionName;
        
        set(CONDITION1_LISTBOX,'string',study.conditions{study.no_conditions} );
        set(CONDITION1_LISTBOX,'value',1);
        
        % update lists
        set(CONDITION1_DROP_DOWN,'string', study.conditionNames);            
        set(CONDITION2_DROP_DOWN,'string', study.conditionNames);        
        set(COV_DROP_DOWN,'string', study.conditionNames);  
    
        changes_saved = false;                   
    end

    function copyHeadModels_callback(~,~)
        
        response = questdlg('Copy Head Models from one condition to another?','BrainWave','Yes','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end        
        
        [condName1, condIdx1, ~] = bw_getConditionList('Select Condition to copy head models from...', currentStudyFile);
        [~, condIdx2, ~] = bw_getConditionList('Select Condition to copy head models to ...', currentStudyFile);
        
        if isempty(condName1)
            return;
        end

        dsList1 =  study.conditions{condIdx1};
        dsList2 =  study.conditions{condIdx2};  
        
        if size(dsList1,2) ~= size(dsList2,2)
            beep
            errordlg('Conditions contain different numbers of subjects...');
            return;
        end

        for j=1:size(dsList1,2)
            dsName1  = deblank( dsList1{1,j} );
            [~, ~, subject_ID1, ~, ~] = bw_parse_ds_filename(dsName1);
            dsName2  = deblank( dsList2{1,j} );
            [~, ~, subject_ID2, ~, ~] = bw_parse_ds_filename(dsName2);
            if strcmp(subject_ID1,subject_ID2) == 1
                fprintf('Copying head models from %s to %s...\n', dsName1, dsName2);
                bw_copyHeadModels(dsName1, dsName2);
            else
                errordlg('Subject ID does not match. Head models not copied');
            end
        end
                       
        
    end

    function condition1_dropdown_callback(src,~)
        if study.no_conditions == 0
            return;
        end
        condition1 = get(src,'value');
        if isempty(study.conditions{condition1})
            set(CONDITION1_LISTBOX,'string', '');  
            s = sprintf('n = 0');       
            set(DATASET_NUM_TEXT,'string',s);
            return;
        end
        names = study.conditions{condition1};
        set(CONDITION1_LISTBOX,'string', names);  
        set(CONDITION1_LISTBOX,'value',1);
        dsName = names(1);
        selectedDataset = fullfile(char(currentStudyDir), char(dsName));
              
        s = sprintf('n = %d',numel(names));       
        set(DATASET_NUM_TEXT,'string',s);
    end

    function condition1_callback(src,~)
        names = get(src,'string');
        dsName = names(get(src,'value'));
        selectedDataset = fullfile(char(currentStudyDir), char(dsName));
    end

    function condition2_dropdown_callback(src,~)
        if study.no_conditions == 0
            return;
        end
        condition2 = get(src,'value');
        if isempty(study.conditions{condition2})
            set(CONDITION2_LISTBOX,'string', '');  
            s = sprintf('n = 0');       
            set(DATASET_NUM_TEXT,'string',s);
            return;
        end
        names = study.conditions{condition2};
        set(CONDITION2_LISTBOX,'string', names);  
        set(CONDITION2_LISTBOX,'value',1);
    end

    function condition2_callback(src,~)
        names = get(src,'string');
        dsName = names(get(src,'value'));
        selectedDataset = fullfile(char(currentStudyDir), char(dsName));
    end

   function cov_dropdown_callback(src,~)
        if study.no_conditions == 0
            return;
        end
        covCondition = get(src,'value');     
        if isempty(study.conditions{covCondition})
            set(COV_LISTBOX,'string', '');  
            s = sprintf('n = 0');       
            set(DATASET_NUM_TEXT,'string',s);
            return;
        end
        names = study.conditions{covCondition};
        set(COV_LISTBOX,'string', names);  
        set(COV_LISTBOX,'value',1);
    end

    function cov_callback(~,~)
        % for now no action applied to selected cov ds
    end

    function display_results_callback(src,~)
        displayResults = get(src,'Value');
    end

    function clear_imagesets_callback(~,~)
        if isempty(study.imagesets)
            return;
        end  

        response = questdlg('Clear list of imagesets for this study?','BrainWave','Yes','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end        
       
        study.imagesets = [];
        changes_saved = false; 
        updateImageListMenu;
    end

    function plot_imagesets_callback(src,~)
        imagesetName = get(src,'label');
        t = load(imagesetName);
        if strcmp(t.imageType, 'Volume')
            bw_mip_plot_4D(imagesetName);
        end
        clear t;
    end

    function updateImageListMenu
            
        if exist('IMAGESETS_MENU','var')
            delete(IMAGESETS_MENU);
            clear IMAGESETS_MENU;
        end
        IMAGESETS_MENU = uimenu('Label','ImageSets');


        if ~isempty(study.imagesets)     
            for k=1:size(study.imagesets,2)
                s = sprintf('%s',char(study.imagesets{k}) ); 
                uimenu(IMAGESETS_MENU,'Label',s,'Callback',@plot_imagesets_callback);              
            end
        end
        % append clear list menu item..
        uimenu(IMAGESETS_MENU,'Label','Clear List','separator','on','Callback',@clear_imagesets_callback); 
        
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % beamformer params controls...
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    function PLOT_BEAMFORMER_START_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.latencyStart=str2double(get(src,'String'));
    end

    function PLOT_BEAMFORMER_END_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.latencyEnd=str2double(get(src,'String'));
    end

    function PLOT_BEAMFORMER_STEP_LAT_EDIT_CALLBACK(src,~)
        params.beamformer_parameters.beam.step=str2double(get(src,'String'));
    end

    function mean_check_callback(src,~)
       params.beamformer_parameters.mean=get(src,'Value');
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

    function RADIO_ERB_CALLBACK(~,~)
        if study.no_conditions == 0
            return;
        end
        params.beamformer_parameters.beam.use='ERB';
        updateRadios;
    end

    function RADIO_Z_CALLBACK(~,~)
        if study.no_conditions == 0
            return;
        end
        params.beamformer_parameters.beam.use='Z';
        updateRadios;
    end

    function RADIO_T_CALLBACK(~,~)
        if study.no_conditions == 0
            return;
        end
        params.beamformer_parameters.beam.use='T';
        updateRadios;
    end

    function RADIO_F_CALLBACK(~,~)
        if study.no_conditions == 0
            return;
        end
        params.beamformer_parameters.beam.use='F';
        updateRadios;
    end

    function set_image_params_callback(~,~)
        
        % open using selected - e.g., to import mesh etc...
        if isempty(study)
            return;
        end
        
        if isempty(selectedDataset)
            errordlg('No dataset selected');
            return;
        end
        
        params = bw_set_image_options(char(selectedDataset), params);
    end


    function plot_images_callback(~,~)
        if isempty(study)
            return;
        end
        
        if study.no_conditions == 0
            return;
        end
        
        if batchJobs.enabled
            response = questdlg('Add to batch?','BrainWave','Yes','Cancel','Cancel');
            if strcmp(response,'Cancel')
                return;
            end  
        end
       
        % get datasets for single condition image, or contrast 
                   
        if conditionType == 1 
            list1 =  study.conditions{condition1};    
            cond1Label =  study.conditionNames{condition1};                           
            list2 = [];
            cond2Label =  '';
            params.beamformer_parameters.contrastImage = 0;
        elseif conditionType == 3
            if condition1 == condition2
                errordlg('Cannot create this contrast: Condition 1 and Condition 2 are the same!');
                return;
            end         
            list1 =  study.conditions{condition1};    
            cond1Label =  study.conditionNames{condition1};
            list2 =  study.conditions{condition2};                
            cond2Label =  study.conditionNames{condition2};
            params.beamformer_parameters.contrastImage = 1;
        end
        
        covList = study.conditions{covCondition};
        params.beamformer_parameters.multiDsSAM;      
        % check that conditions are compatible. 
        
        subjectNum = numel(list1);
        if subjectNum ~= numel(covList)
            errordlg('Number of subjects in covariance condition does not match');
            return;
        end
        if conditionType == 3
            if subjectNum ~= numel(list2)
                errordlg('Number of subjects in contrast condition does not match');
                return;
            end
        end
        
        
        for k=1:numel(list1)
            [~, ~, subj_ID, ~, ~] = bw_parse_ds_filename(char(list1(k)) );
            [~, ~, cov_ID, ~, ~] = bw_parse_ds_filename(char(covList(k)) );
            if ~strcmp(subj_ID,cov_ID)
                s = sprintf('Subject dataset ID and Covariance subject ID do not match (line %d)', k);
                errordlg(s);
                return;
            end
            
            if conditionType == 3
                [~, ~, contrast_ID, ~, ~] = bw_parse_ds_filename(char(list2(k)) );
                if ~strcmp(subj_ID,contrast_ID)
                    s = sprintf('Subject dataset ID and Contrast subject ID do not match (line %d)', k);
                    errordlg(s);
                    return;
                end
            end 
        end
        
        % get name for this imageset...
        defName = '*';
        [fname,pathname,~]=uiputfile('*','Enter name for group images:',defName);   
        if isequal(fname,0)
            return;
        end   
        groupPreFix = fullfile(pathname,fname);        
        
        if batchJobs.enabled
            fprintf('adding group image job %s to batch process...\n', groupPreFix);                
            % make sure each job has unique name 
            if  batchJobs.numJobs > 0
                for i=1:batchJobs.numJobs
                    if strcmp( batchJobs.processes{i}.groupPreFix, groupPreFix)
                        errordlg('Error: Duplicate group image name. Please choose another', 'Batch Processing');
                        return;
                    end
                end
            end
        end

        % Version 4.0   - always use covariance condition for cov list
        %               - if SAM always use the covariance condition for
        %               baseline (can be same or different....)
        % *** 

        
        
        if batchJobs.enabled
            batchJobs.numJobs = batchJobs.numJobs + 1;
            batchJobs.processes{batchJobs.numJobs}.groupPreFix = groupPreFix;
            batchJobs.processes{batchJobs.numJobs}.list1 = list1;             
            batchJobs.processes{batchJobs.numJobs}.list2 = list2;             
            batchJobs.processes{batchJobs.numJobs}.covList = covList;             
            batchJobs.processes{batchJobs.numJobs}.params = params;

            s = sprintf('Close Batch (%d jobs)', batchJobs.numJobs);
            set(STOP_BATCH,'label',s);                 
        else
            % create images now ...
            
            imagesetName = bw_generate_group_images(groupPreFix, list1, list2, covList, params, cond1Label, cond2Label);
            
            if isempty(imagesetName)
                return;
            end
            % need to save local path name to find mat file
            idx = findstr(filesep,imagesetName);
            fname = imagesetName(idx(end-1)+1:end);
            study.imagesets = [study.imagesets {fname}];
            
            save_changes;
            updateImageListMenu;
            
            % plot results
            if displayResults 
                bw_mip_plot_4D(imagesetName);        
            end

        end
    end

    % batch setup
    function START_BATCH_CALLBACK(~,~)
        batchJobs.enabled = true;
        batchJobs.numJobs = 0;
        batchJobs.processes = {};
       
        set(START_BATCH,'enable','off')            
        set(STOP_BATCH,'enable','on')                
        set(STOP_BATCH,'label','Close Batch');               
    end

    function STOP_BATCH_CALLBACK(~,~)
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

    function RUN_BATCH_CALLBACK(~,~)
        if isempty(batchJobs)
            return;
        end
        numJobs = batchJobs.numJobs;
        s = sprintf('%d group images will be generated.  Do you want to run these now?', numJobs);
        response = questdlg(s,'BrainWave','Yes','Cancel','Cancel');
        if strcmp(response,'Cancel')
            return;
        end        
                 
        for i=1:numJobs
            fprintf('\n\n*********** Running job %d ***********\n\n', i);
            groupPreFix = batchJobs.processes{i}.groupPreFix;
            list1 = batchJobs.processes{i}.list1;
            list2 = batchJobs.processes{i}.list2;
            covList = batchJobs.processes{i}.covList;
            params = batchJobs.processes{i}.params;
            imagesetName = bw_generate_group_images(groupPreFix, list1, list2, covList, params);                           
            if isempty(imagesetName)
                continue;
            end

            % need to save local path name to find mat file
            idx = findstr('/',imagesetName);
            fname = imagesetName(idx(end-1)+1:end);
            study.imagesets = [study.imagesets {fname}];          
            save_changes;
            updateImageListMenu;

            if displayResults      
                bw_mip_plot_4D(imagesetName);
            end
        end

        fprintf('\n\n*********** finished batch jobs ***********\n\n');

        batchJobs.enabled = false;
        batchJobs.numJobs = 0;
        batchJobs.processes = {};
        set(START_BATCH,'enable','on')            
        set(RUN_BATCH,'enable','off')        
        set(STOP_BATCH,'enable','off')   
        set(STOP_BATCH,'label','Close Batch');              

        
    end


    function set_data_params_callback(~,~)
       % open using selected - e.g., to import mesh etc...
        if isempty(study)
            return;
        end
                
        if isempty(selectedDataset)
            errordlg('No dataset selected');
            return;
        end
        
        dsName = char(selectedDataset);
        if params.beamformer_parameters.covarianceType == 2
            idx = get(CONDITION1_LISTBOX,'value');
            covList =  study.conditions{covCondition};
            covDsName = deblank( covList{1,idx} );
            covDs = fullfile(char(currentStudyDir), char(covDsName));
            params.beamformer_parameters = bw_set_data_parameters(params.beamformer_parameters, dsName, covDs );
        else           
            params.beamformer_parameters = bw_set_data_parameters(params.beamformer_parameters, dsName, dsName );
        end
    end

    function VOLUME_RADIO_CALLBACK(src,~)
       params.beamformer_parameters.useVoxFile = 0;
       set(src,'value',1);
    end
    
    function updateRadios

        if strcmp(params.beamformer_parameters.beam.use,'ERB')
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
            set(COV_CONDITION_TITLE,'string','Covariance Condition:');      
            set(COV_CONDITION_TITLE,'enable','on');
            set(COV_DROP_DOWN,'enable','on');
            set(COV_LISTBOX,'enable','on');
            
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

            set(COV_CONDITION_TITLE,'string','Baseline Condition:');      
          
            if strcmp(params.beamformer_parameters.beam.use,'Z')
                set(RADIO_Z,'value',1)
                set(RADIO_T,'value',0)
                set(RADIO_F,'value',0)
                set(BASELINEWINDOW_LABEL,'enable','off')
                set(BASELINE_START_EDIT,'enable','off')
                set(BASELINE_START_LABEL,'enable','off')
                set(BASELINE_END_EDIT,'enable','off')
                
                set(COV_CONDITION_TITLE,'enable','off');
                set(COV_DROP_DOWN,'enable','off');
                set(COV_LISTBOX,'enable','off');
                
            elseif strcmp(params.beamformer_parameters.beam.use,'T')
                set(RADIO_Z,'value',0)
                set(RADIO_T,'value',1)
                set(RADIO_F,'value',0)
                
                set(COV_CONDITION_TITLE,'enable','on');
                set(COV_DROP_DOWN,'enable','on');
                set(COV_LISTBOX,'enable','on');
                
            elseif strcmp(params.beamformer_parameters.beam.use,'F')
                set(RADIO_Z,'value',0)
                set(RADIO_T,'value',0)
                set(RADIO_F,'value',1)
                
                set(COV_CONDITION_TITLE,'enable','on');
                set(COV_DROP_DOWN,'enable','on');
                set(COV_LISTBOX,'enable','on');
                
            end
            set(RADIO_ERB,'value',0)

        end   
        
    end

    function QUIT_MENU_CALLBACK(~,~)       
 
        if changes_saved == false 
            response = questdlg('Exit without saving changes to condition list?','BrainWave','Yes','Cancel','Cancel');
            if strcmp(response,'Cancel')
                return;
            end                   
        end
                
        delete(f);
    end
end

% helper functions


function filename = removeFilePath(str)
    [~,n,e] = fileparts(str);
    filename = [n e];       
end
    
function  conditionName = getConditionName

    conditionName = [];
    
    fg=figure('color','white','name','New Study','numbertitle','off','menubar','none','position',[100,900, 400 150]);
    if ispc
        movegui(fg,'center')
    end
    uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
         'position',[0.05 0.7 0.6 0.2],'String','Enter Name for this condition:','Backgroundcolor','white','fontsize',13);

    COND_NAME = uicontrol('style','edit','units','normalized','HorizontalAlignment','Left',...
         'position',[0.05 0.25 0.6 0.3],'String','','Backgroundcolor','white','fontsize',13);
    
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.25 0.2 0.3],'string','OK','backgroundcolor','white','callback',@ok_callback);
    
    function ok_callback(~,~)    
        conditionName = get(COND_NAME,'string');
        uiresume(gcf);
    end
    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);     
    
end



