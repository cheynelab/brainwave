function bw_import_data
%       BW_IMPORT_DATA
%
%   function bw_import_data
%
%   DESCRIPTION: creates a GUI that allows users to to import Yokogawa,
%   CTF, and (in the future) other datasets to convert to CTF datasets.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
%
% Revised July 2011 - D. Cheyne
%
% - reorganized dialog
% - modfied to read CTF data 
%
%  revised Jan, 2012.
%  added new features for release 1.6 
%  now uses new Yokogawa library.
%
%
%    Version 2.0 - June, 2012.
%
%    Version 2.2 - November, 2012       - includes Paul Ferrari's code
%                                         for getting trigger information
%                                         from Neuromag data and creating a
%                                         MarkerFile.
%
%    Verson 3.3  - December, 2016       - major changes to importing of
%                                         data and batch processing. 
%
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

global BW_PATH;

%setting figure size depending on screen size
scrnsizes=get(0,'MonitorPosition');

fh=figure('Name', 'Import MEG Data', 'Position', [scrnsizes(1,3)/6 scrnsizes(1,4)/2 1500 1000],...
            'menubar','none','numbertitle','off', 'Color','white');
if ispc
    movegui(fh,'center');
end
% Values That Need to be Initialized for Everything
    %color
orange = [0.6,0.25,0.1];

loadfull='';

% some global parameters
    
data_params.sampleRate=0;
data_params.numSamples=0;
data_params.numSensors=0;
data_params.totalSamples = 0;

channelNames = [];
latencyList=[];
eventFile ='';
eventName ='';

validFlags=[];
badTrialFlags=[];

twStart=0.0;
twEnd=1.0;

currentTrialNo = 1;
selectedChannels = [1];
useSelectedChannels = 0;


singleEpochStart = 0.0;
singleEpochEnd = 1.0;
numEpochs = 1;

minSep = 0.0;
useMinSep = 0;
    
dataType = '';
    
%channel select button
validChan=[];
bcpos=[];

epochFlag=0;
filterData=0;

useExtraSamples=1;

removeOffset=0;
plotBad = 0;

exclude_BadTrials = 0;  % peak to peak 
peakThreshold = 2.5e-12;    % default = 2.5 pT

exclude_Resets = 0;
resetThreshold = 2e-13;  % 1st derivative exceeds 0.2 pT

exclude_HeadMotion = 0;
motionThreshold = 0.5;     % default = 8 mm
useMeanHeadPosition = 0;
epochsValid = 0;

bandpass = [0 40];
save_average = 0;
hasCHL = 0;
latencyCorrection = 0.0;
downSample = 1;
sampleRates = [];
rates = cellstr('-------');

deidentifyData = false;

fid_pts_dewar = [];

batchJobs.enabled = false;
batchJobs.numJobs = 0;
batchJobs.processes = {};

dsList = {};
saveDsName = [];
conditionName = [];
subjectID = '001';

useSubID = true;
useRunID = true;
useEventName = true;
savePath = '';

lineFilterData = 0;
lineFilterFreq = 60;
lineFilterWidth = 3;  % fixed width in mex function.

channelMenuIndex = 1;

exclude_BadChannels = 0;
channelRejectThreshold = 0.90;
       
gradient = 0;
gradientStr = {'none',...
                'Synthetic 1st gradient',...
                'Synthetic 2nd gradient',...
                'Synthetic 3rd gradient',...
                'Synthetic 3rd gradient + adaptive'};

motionData = [];
menu_select = 1; % Anton 2021/08/19 - made menu_select a global variable because after my modifications to scanTrials, we needed a way to know which dataset is currently selected in the dropdown.

% Menu
filemenu=uimenu('label','File');
uimenu(filemenu,'label','Load CTF Datasets...','accelerator','O','callback',@load_datasets_callback)
uimenu(filemenu,'label','Load Parameters...','accelerator','L','callback',@load_params_callback)
importMenu = uimenu(filemenu,'label','Import MEG data','separator','on');
uimenu(importMenu,'label','Import Neuromag/MEGIN data...','callback',@import_fif_data_callback)
uimenu(importMenu,'label','Import KIT data...','callback',@import_kit_data_callback)

uimenu(filemenu,'label','Save parameters...','accelerator','S','separator','on','callback',@save_params_callback)
uimenu(filemenu,'label','Concatenate Datasets...','separator','on','callback',@concatenate_filemenu_callback)
uimenu(filemenu,'label','Combine Datasets...','callback',@combine_filemenu_callback)
uimenu(filemenu,'label','Close','accelerator','W','separator','on','callback',@quit_filemenu_callback)

BATCH_MENU=uimenu('Label','Batch');
START_BATCH=uimenu(BATCH_MENU,'label','Open New Batch','Callback',@START_BATCH_CALLBACK);
STOP_BATCH=uimenu(BATCH_MENU,'label','Close Batch','enable','off','Callback',@STOP_BATCH_CALLBACK);
RUN_BATCH=uimenu(BATCH_MENU,'label','Run Batch...','separator','on','enable','off','Callback',@RUN_BATCH_CALLBACK); 
CANCEL_BATCH=uimenu(BATCH_MENU,'label','Cancel Batch...','enable','off','Callback',@CANCEL_BATCH_CALLBACK); 

    function quit_filemenu_callback(~,~)
        close(fh);
    end

    function combine_filemenu_callback(~,~)        
        bw_combine_datasets(pwd);         
    end

    function concatenate_filemenu_callback(~,~)        
        bw_concatenate_datasets(pwd);         
    end

% Printed Info
uicontrol('style','text','units','normalized','position',[0.03 0.95 0.15 0.04],...
        'String','Data Parameters','ForegroundColor','blue','FontSize', 11,...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');
    
annotation('rectangle','position',[0.01 0.41 0.4 0.57],'edgecolor','blue');
    
textFontSize = 10;

uicontrol('style','text','units','normalized','position',[0.02 0.935 0.15 0.03],...
    'String','Current Directory:','HorizontalAlignment','left','fontsize',textFontSize,'fontweight','bold','BackgroundColor','white');
dsPathText = uicontrol('style','text','units','normalized','position',[0.1 0.935 0.25 0.03],...
    'String',pwd,'HorizontalAlignment','left','fontsize',textFontSize,'BackgroundColor','white');


uicontrol('style','text','units','normalized','position',[0.02 0.895 0.06 0.03],...
    'String','Dataset:','HorizontalAlignment','left','fontsize',textFontSize,'fontweight','bold','BackgroundColor','white');
dsList_popup = uicontrol('style','popup','units','normalized',...
    'position',[0.1 0.90 0.25 0.03],'String', 'Select Datasets...', 'Backgroundcolor','white','fontsize',textFontSize,...
    'value',1,'callback',@dsList_popup_callback);

        function dsList_popup_callback(src,~)
            if isempty(dsList)
                fileList = uigetdir2(pwd,'Select dataset(s) to import...');  
                if isempty(fileList)
                    return;
                end
                load_datasets(fileList);
            else
                if size(dsList,2) == 1
                    return;
                end
                
                menu_select=get(src,'value');
                loadCTFData(menu_select);  
            end
        end


uicontrol('style','text','units','normalized','position',[0.02 0.86 0.15 0.03],...
    'String','Save Directory:','HorizontalAlignment','left','fontsize',textFontSize,'fontweight','bold','BackgroundColor','white');
savePathText=uicontrol('style','text','units','normalized','position',[0.1 0.86 0.3 0.03],...
    'String',pwd,'HorizontalAlignment','left','fontsize',textFontSize,'BackgroundColor','white');

saveDsName_text=uicontrol('style','text','units','normalized','position',[0.02 0.825 0.1 0.03],...
    'String','Save As:','HorizontalAlignment','left','fontsize',textFontSize,'fontweight','bold',...
    'BackgroundColor','white');  
saveDsName_edit=uicontrol('style','edit','units','normalized','position',[0.1 0.835 0.28 0.025],...
    'String',saveDsName,'HorizontalAlignment','left','fontsize',textFontSize,'fontweight','bold','BackgroundColor','white');

uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.3 0.80 0.08 0.025],...
    'string','Save Dir...','Foregroundcolor','black','backgroundcolor','white','callback',@changeDir_callback);
    function changeDir_callback(~,~)
        t = uigetdir;
        if t~=0
            savePath = t;
            set(savePathText,'string',savePath);
        end
    end

uicontrol('style','text','units','normalized','position',[0.02 0.785 0.1 0.03],...
    'String','Auto Fill:','HorizontalAlignment','left','fontsize',textFontSize,'fontweight','bold',...
    'BackgroundColor','white');     
    
uicontrol('style','checkbox','units','normalized','position',[0.08 0.795 0.08 0.03],...
    'String','Subject ID','value', useSubID,'HorizontalAlignment','left','fontsize',textFontSize,'BackgroundColor','white','callback',@autoFill_callback);
    function autoFill_callback(src,~)
        useSubID = get(src,'value');
        if useSubID
            set(subIDText,'enable','off');
            set(subID_edit,'enable','off');
        else
            set(subIDText,'enable','on');
            set(subID_edit,'enable','on');
        end      
        update_saveName;
    end    

useRunIDCheck=uicontrol('style','checkbox','units','normalized','position',[0.16 0.795 0.08 0.03],...
    'String','Run ID','value', useRunID,'HorizontalAlignment','left','fontsize',textFontSize,'BackgroundColor','white','callback',@useRunID_callback);
    function useRunID_callback(src,~)
        useRunID = get(src,'value');
        update_saveName;
    end    

useEventNameCheck=uicontrol('style','checkbox','units','normalized','position',[0.22 0.795 0.06 0.03],...
    'String','Event Name','value', useEventName,'HorizontalAlignment','left','fontsize',textFontSize,'BackgroundColor','white','callback',@useEventName_callback);
    function useEventName_callback(src,~)
        useEventName = get(src,'value');
        update_saveName;
    end    

subIDText=uicontrol('style','text','units','normalized','position',[0.02 0.75 0.08 0.03],...
    'String','Subject ID:','HorizontalAlignment','left','fontsize',textFontSize,'enable','off',...
    'BackgroundColor','white');

subID_edit=uicontrol('style','edit','units','normalized','position',[0.08 0.76 0.04 0.025],'enable','off',...
    'String',subjectID,'HorizontalAlignment','left','fontsize',textFontSize,'BackgroundColor','white','callback',@subID_edit_callback);
    function subID_edit_callback(~,~)
        update_saveName;
    end

condNameText=uicontrol('style','text','units','normalized','position',[0.15 0.75 0.06 0.03],...
    'String','Label:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white');

condName_edit=uicontrol('style','edit','units','normalized','position',[0.18 0.76 0.2 0.025],...
    'String',conditionName,'HorizontalAlignment','left','fontsize',textFontSize,'BackgroundColor','white','callback',@conditionName_edit_callback);
    function conditionName_edit_callback(~,~)
%         conditionName = get(condName_edit,'string');
        update_saveName;
    end

function saveName = build_saveName(subject_ID, tag1, tag2, tag3)

    saveName = subject_ID;

    if ~isempty(tag1) 
        saveName = sprintf('%s_%s',saveName, tag1);
    end

    if ~isempty(tag2)
        saveName = sprintf('%s_%s',saveName, tag2);
    end

    if ~isempty(tag3)
        saveName = sprintf('%s_%s',saveName, tag3);
    end

    saveName = strcat(saveName,'.ds');
end

function saveName = getSaveName(dsName)         

    if useSubID       
       [~, name, ~] = fileparts(dsName);
        idx = find(name == '_');
        if ~isempty(idx)
            subID = name(1:idx(1)-1);
        else
            subID = [];
        end
    else
        subID = get(subID_edit,'string');
        if isempty(subID)
            warndlg('Need to enter a valid subject ID before saving...');
        end
    end

    % last part of recorded name is DatasetID (run no etc..)
    if useRunID       
        [~, name, ~] = fileparts(dsName);
        idx = find(name == '_');
        if ~isempty(idx)
            runID = name(idx(end)+1:end);
        else
            runID = [];
        end
    else
        runID = [];
    end

    if useEventName
        eventLabel = eventName;
    else
        eventLabel = [];
    end

    conditionName = get(condName_edit,'string');

    saveName = build_saveName(subID, runID, eventLabel, conditionName);       

end

function update_saveName        
    saveDsName = getSaveName(loadfull);    
    set(saveDsName_edit, 'string',saveDsName);        
end

% data_type=uicontrol('style','text','units','normalized','position',[0.02 0.750 0.37 0.04],...
%     'String','DataType:','HorizontalAlignment','left','fontsize',textFontSize,...
%     'BackgroundColor','white');
uicontrol('style','text','units','normalized','position',[0.02 0.695 0.37 0.04],...
    'String','Collection Parameters:','HorizontalAlignment','left','fontsize',textFontSize,'fontweight','bold',...
    'BackgroundColor','white');
no_channels=uicontrol('style','text','units','normalized','position',[0.02 0.675 0.37 0.04],...
    'String','MEG Channels:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white');
total_channels=uicontrol('style','text','units','normalized','position',[0.02 0.650 0.37 0.04],...
    'String','Total Channels:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white');
low_pass=uicontrol('style','text','units','normalized','position',[0.02 0.625 0.37 0.04],...
    'String','Low Pass:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white'); 
high_pass=uicontrol('style','text','units','normalized','position',[0.02 0.600 0.37 0.04],...
    'String','High Pass:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white'); 
sample_rate=uicontrol('style','text','units','normalized','position',[0.02 0.575 0.37 0.04],...
    'String','Sample Rate:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white');
total_samples=uicontrol('style','text','units','normalized','position',[0.02 0.550 0.35 0.04],...
    'String','Total samples:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white'); 
noise_red=uicontrol('style','text','units','normalized','position',[0.02 0.525 0.35 0.04],...
    'String','Noise Reduction:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white'); 
chl_data=uicontrol('style','text','units','normalized','position',[0.02 0.500 0.35 0.04],...
    'String','Continuous Head Localization:','HorizontalAlignment','left','fontsize',textFontSize,...
    'BackgroundColor','white'); 

   % fiducial title
Fid_text = uicontrol('style','text','units','normalized','position',[0.02 0.47 0.3 0.04],...
    'String','Fiducials in Device Coordinates (cm):','HorizontalAlignment','left','fontsize',textFontSize,'fontweight','bold',...
    'BackgroundColor','white');
nasion_txt = uicontrol('style','text','units','normalized','fontname','lucinda','position',[0.02 0.450 0.35 0.04],...
    'String','Nasion:','HorizontalAlignment','left',...%'fontsize',textFontSize,...
    'BackgroundColor','white');
left_ear_txt = uicontrol('style','text','units','normalized','fontname','lucinda','position',[0.02 0.425 0.35 0.04],...
    'String','Left Ear:','HorizontalAlignment','left',...%'fontsize',textFontSize,...
    'BackgroundColor','white');
right_ear_txt= uicontrol('style','text','units','normalized','fontname','lucinda','position',[0.02 0.400 0.35 0.04],...
    'String','Right Ear:','HorizontalAlignment','left',...%'fontsize',textFontSize,...
    'BackgroundColor','white');

%

createButton =  uicontrol('style','pushbutton','units','normalized','position',[0.02 0.03 0.1 0.05],...
        'enable','off','string','Create Datasets','Foregroundcolor',orange,'backgroundcolor','white','callback',@create_ds_callback);

addToBatchButton =  uicontrol('style','pushbutton','units','normalized','position',[0.14 0.03 0.07 0.05],...
        'enable','off','string','Add to Batch','Foregroundcolor',orange,'backgroundcolor','white','enable','off','callback',@add_to_batch_callback);
   
function import_fif_data_callback(~,~)

    fileList = uigetdir2(pwd,'Select dataset(s) to import...');  
    if isempty(fileList)
        return;
    end

    numFiles = size(fileList,2);

    s = sprintf('Convert %d datasets to CTF format?', numFiles);           
    response = questdlg(s,'BrainWave','Yes','No','Yes');
    if strcmp(response,'No')    
        return;
    end

    wbh = waitbar(0,'Converting datasets...');

    for j=1:numFiles
        datafile = char(fileList{j});
        [loadpath, name, ext] = bw_fileparts(datafile);

        s = sprintf('Converting Elekta-Neuromag dataset %d of %d', j, numFiles);
        waitbar(j/numFiles,wbh,s);
        % check if we can convert fiff files...
        if ismac
            fprintf('Linux OS required to run fiff2ctf conversion program...\n');
            return;
        elseif isunix
            fiffPath = sprintf('%s%s%s%s%s',BW_PATH,'external',filesep,'linux',filesep);
        else
            fprintf('Linux OS required to run fiff2ctf conversion program...\n');
            return;
        end

        dsName = strrep(strcat(name,ext),'.fif','.ds');           
        tempDir = strrep(datafile, '.fif','_tempDir');
        tempFile = sprintf('%s%s%s', tempDir,filesep,dsName);

        cmd = sprintf('%sfiff2ctf %s %s',fiffPath,datafile,tempDir);
        system(cmd);

        if ~exist(tempFile,'dir')
            fprintf('Cannot find <%s> Conversion may have failed...', tempFile) 
            return;
        end

        cmd = sprintf('mv %s %s', tempFile, loadpath);
        system(cmd);
        cmd = sprintf('rmdir %s', tempDir);
        system(cmd);

        datafile = strrep(datafile,'.fif','.ds');
        newDsList(j) = cellstr(datafile);

        % from Paul Ferrari
        % create MarkerFile here from the Neuromag STIM channels
        trig = bw_getNMTriggers(datafile);
        bw_write_MarkerFile(datafile,trig);                
    end

    delete(wbh);

    load_datasets(newDsList);

end

function import_kit_data_callback(~,~)

    % v. 4.1 - use multiple file select dialog to avoid confusion due to
    % different KIT file naming conventions.

    [conFile, markerFile, evtFile] = import_KIT_files;

    if isempty(conFile) || isempty(markerFile)
        errordlg('Insufficient data files specified...');
        return;
    end

    wbh = waitbar(0,'Converting dataset...');
    s = sprintf('Converting Yokagawa-KIT dataset...');     
    success = con2ctf(conFile, markerFile, evtFile);
    delete(wbh);
    if success == -1 
        errordlg('KIT conversion failed...');
        return;
    end

    dsName = strrep(conFile,'.con','.ds');      
    newDsList(1) = cellstr(dsName);

    load_datasets(newDsList);

end

% multiselect CTF datasets 
function load_datasets_callback(~,~)
    fileList = uigetdir2(pwd,'Select CTF datasets...');  
    if isempty(fileList)
        return;
    end
    load_datasets(fileList)
end


function load_datasets( fileList )

    dsList = fileList;

    % separate path and names for popup menu only
    for k=1:size(fileList,2)
        s = char(fileList(k));

        % D. Cheyne for multi Ds processing datasets must have 
        % same set of MEG channels
        [channelNames, ~, ~] = bw_CTFGetSensors(s, 0); 
        if k > 1
           idx = strcmp(channelNames, oldChannelNames);
           if idx == 0
               beep
               s = sprintf('MEG channel names for dataset %s do not match previous datasets. Channels must match for batch processing', s);
               errordlg(s);
               return;
           end
        end
        oldChannelNames = channelNames;

        [dsPath, name, ext] = bw_fileparts(s);
        dsNames(k) = cellstr([name ext]);
    end

    set(dsPathText,'string',dsPath);
    set(dsList_popup,'string',dsNames);
    set(dsList_popup,'value',1);
    latencyCorrection = 0.0;
    set(latency_correct_edit,'string',latencyCorrection);
    
    loadCTFData(1);

end

function loadCTFData(dataset_no)

    loadfull = char(dsList(:,dataset_no));
    loadDsFile(loadfull);
    
    % try to load previously selected eventFile and marker       
    if ~isempty(eventFile) && ~isempty(eventName)                  
        loadlatfull = sprintf('%s%s%s',loadfull,filesep, eventFile);
        fprintf('Loading event %s from file %s\n', eventName, loadlatfull);
        if exist(loadlatfull,'file')
            % assume trial number is always 1 for raw data...
            [~, latencyList] = bw_getCTFMarkerLatencies( loadlatfull, eventName );                   
            fprintf('Read %d events from %s..\n', size(latencyList,1), loadlatfull);
        else
            fprintf('** Event %s from file %s does not exist for this dataset *** \n', eventName, loadlatfull);
            latencyList = [];
            eventName = [];
            eventFile = [];
        end
    end

    % reset bad trial flags AND latency correction
    badTrialFlags = zeros(1,size(latencyList,1));


    updateLatencies;

    drawTrial;

end

function loadDsFile(datafile)


    set(useRunIDCheck,'enable','on');
    set(useEventNameCheck,'enable','on');
    set(condNameText,'enable','on');
    set(condName_edit,'enable','on');
    set(saveDsName_text,'visible','on');
    set(saveDsName_edit,'visible','on');            
    set(saveDsName_text,'enable','on');
    set(saveDsName_edit,'enable','on');            

    loadfull=datafile;
    fprintf('Loading dataset %s...\n', loadfull);

    % version 2.5, replaced GetParams with getHeader...

    header = bw_CTFGetHeader(loadfull);

    % check if current valid channel list is valid :)

    if size(validChan,1) == 0 || size(validChan,1) ~= header.numChannels
        validChan=ones(header.numChannels,1);
    end

    % set global params used by other functions 
    data_params.sampleRate = header.sampleRate;
    data_params.numSamples = header.numSamples;
    data_params.numSensors = header.numSensors;
    data_params.totalSamples = header.numSamples;

    [longNames, ~, ~] = bw_CTFGetSensors(loadfull, 0);

    % D.Cheyne - temporary fix if continuous data has negative start time
    % may cause problems switching between datasets...
    if header.epochMinTime < 0.0
      fprintf('*** Dataset has negative start time (%.5f seconds). Setting latency correction to add %.5f seconds to adjust ***\n',...
          header.epochMinTime, -header.epochMinTime);
      latencyCorrection = -header.epochMinTime;
      set(latency_correct_edit,'string',latencyCorrection);
    end


    % truncate MEG channel names if they have dash - allows for longer
    % than 5 character names in CTF datasets....
    channelNames = bw_truncateSensorNames(longNames);

    % get all channel names to look for CHL channels
    labels = bw_CTFGetChannelLabels(loadfull);
    idx = find( strncmp('HLC',cellstr(labels),3) );
    if ~isempty(idx)
        hasCHL = true;
        set(chl_data,'string','Continuous Head Localization: Yes');
    else
        hasCHL = false;
        set(chl_data,'string','Continuous Head Localization: No');
    end

    numTrials=header.numTrials;

    if (numTrials > 1)                
        fprintf('This does not appear to be a CTF continuous data file\n');
        return;
    end

    % print header information
    dataType='CTF';

    tstr = sprintf('MEG channels: %g',header.numSensors);
    set(no_channels,'string',tstr);
    tstr = sprintf('Total channels: %g',header.numChannels);
    set(total_channels,'string',tstr);

    data_params.lowPass = header.lowPass;
    data_params.highPass = header.highPass; 
    gradient = header.gradientOrder;
    
    s=sprintf('Low Pass: %g Hz',data_params.lowPass);
    set(low_pass,'string',s);   
    s=sprintf('High Pass: %g Hz',data_params.highPass);
    set(high_pass,'string',s);   

    tstr = sprintf('Sample Rate: %g samples /s',header.sampleRate);
    set(sample_rate,'string',tstr);
    tstr = sprintf('Total samples: %d (%.4f seconds)',data_params.totalSamples, (data_params.totalSamples / header.sampleRate));
    set(total_samples,'string',tstr);

    tstr = sprintf('Noise Reduction: %s', char(gradientStr(gradient+1)) );
    set(noise_red,'string',tstr);

    % get fids in dewar coords.

    [~, fid_pts_dewar] = bw_readHeadCoilFile(loadfull);

    s = sprintf('Fiducials in Device Coordinates (cm)');
    set(Fid_text, 'string', s, 'foregroundcolor','black');
    s = sprintf('Nasion:        X = %8.4f    Y = %8.4f     Z = %8.4f', fid_pts_dewar.na(1:3) );
    set(nasion_txt,'string',s, 'foregroundcolor', 'black');
    s = sprintf('Left ear:     X = %8.4f    Y = %8.4f     Z = %8.4f', fid_pts_dewar.le(1:3) );
    set(left_ear_txt,'string',s, 'foregroundcolor', 'black');
    s = sprintf('Right Ear :     X = %8.4f    Y = %8.4f     Z = %8.4f', fid_pts_dewar.re(1:3));
    set(right_ear_txt,'string',s, 'foregroundcolor', 'black');            

    set(eventMarkerButton,'enable','on');
    set(sample_popup,'enable','on');

    clear header;
    update_saveName;        

    set(createButton,'enable','on');
    set(chanSelectButton,'enable','on');

    if hasCHL
        set(head_motion_check, 'enable','on');
        set(motionThreshold_edit, 'enable','on');
        set(use_mean_position_check, 'enable','on');
        set(headMotionPlot_button, 'enable','on');
    else
        set(head_motion_check, 'enable','off');
        set(motionThreshold_edit, 'enable','off');
        set(use_mean_position_check, 'enable','off');
        set(headMotionPlot_button, 'enable','off');
    end           


    currentTrialNo = 1;  
    updateSamples;        

end

% Data Selection
uicontrol('style','text','units','normalized','position',[0.45 0.95 0.13 0.04],...
        'String','Epoch Selection','FontSize',11,'ForegroundColor','blue',...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');

    %surrounding rectangle    
annotation('rectangle','position',[0.42 0.6 0.565 0.38],'edgecolor','blue');  

   
    %all data radio
all_data=uicontrol('style','radio','units','normalized','position',[0.46 0.9 0.15 0.04],...
    'string','Single Epoch','fontsize',12,'backgroundcolor','white','value',~epochFlag,...
    'callback',@all_data_callback);

    function all_data_callback(~,~)
        epochFlag=0;        
        currentTrialNo = 1;
        latencyList = [];
        
        updateEpochFields;
        updateLatencies;      
        drawTrial;
        
    end
    %epoch data radio

uicontrol('style','text','units','normalized','position',[0.57 0.89 0.08 0.04],...
    'string','Start (s):','fontsize',12,'backgroundcolor','white','horizontalalignment','left');
single_epoch_start=uicontrol('style','edit','units','normalized','position',[0.61 0.9 0.055 0.04],...
    'string',singleEpochStart,'FontSize', 12, 'BackGroundColor','white','callback',@single_start_callback);

uicontrol('style','text','units','normalized','position',[0.7 0.89 0.08 0.04],...
    'string','End (s):','fontsize',12,'backgroundcolor','white','horizontalalignment','left');
single_epoch_end=uicontrol('style','edit','units','normalized','position',[0.74 0.9 0.055 0.04],...
    'string',singleEpochEnd,'FontSize', 12, 'BackGroundColor','white','callback',@single_end_callback);

    function single_start_callback(src,~)
        singleEpochStart = str2double(get(src,'String'));    
        drawTrial;
    end

    function single_end_callback(src,~)
        singleEpochEnd = str2double(get(src,'String'));        
        drawTrial;
    end

epoch_data=uicontrol('style','radio','units','normalized','position',[0.46 0.84 0.15 0.04],...
    'string','Multiple Epochs','fontsize',12,'backgroundcolor','white','value',epochFlag,...
    'callback',@epoch_data_callback);

    function epoch_data_callback(~,~)
        epochFlag=1;
        updateEpochFields;
    end
            
    function updateEpochFields
        
        if epochFlag
            set(all_data,'value',~epochFlag)
            set(epoch_data,'value',epochFlag)
            set(single_epoch_start,'enable','off');
            set(single_epoch_end,'enable','off');
            set(lat_text,'enable','on')
            set(lat_box,'enable','on')
            set(tw_title,'enable','on')
            set(tw_start_text,'enable','on')
            set(tw_start,'enable','on')
            set(tw_end_text,'enable','on')
            set(tw_end,'enable','on')
            set(tw_ol_check,'enable','on')   
            set(tw_ol_check,'value',useMinSep)   
            if useMinSep
                set(tw_ol,'enable','on')
                set(tw_ol,'value',minSep);
            end
            set(load_lat,'enable','on')
            set(save_average_check,'enable','on');
            set(delete_button,'enable','on');
            set(correct_txt,'enable','on');
            set(latency_correct_edit,'enable','on');
        else
            set(epoch_data,'value',epochFlag)
            set(all_data,'value',~epochFlag)
            set(single_epoch_start,'enable','on');
            set(single_epoch_end,'enable','on');

            set(lat_text,'enable','off')
            set(lat_box,'enable','off')
            set(tw_title,'enable','off')
            set(tw_start_text,'enable','off')
            set(tw_start,'enable','off')
            set(tw_end_text,'enable','off')
            set(tw_end,'enable','off')
            set(tw_ol,'enable','off')
            set(tw_ol_check,'enable','off')
            set(load_lat,'enable','off')
            set(save_average_check,'enable','off');
            set(delete_button,'enable','off');
            set(correct_txt,'enable','off');
            set(latency_correct_edit,'enable','off');
        end
    end
            
%latencies

latency_file_label = uicontrol('style','text','units','normalized',...
    'position',[0.53 0.77 0.4 0.04],'String','Event: none','FontSize',11,'ForegroundColor','blue',...
        'HorizontalAlignment','left','BackGroundColor', 'white');

lat_text=uicontrol('style','text','units','normalized','Position',...
    [0.53 0.75 0.15 0.04],'String','Latencies','FontSize',11,'HorizontalAlignment','Left',...
    'BackgroundColor','white');

lat_box=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized','Position',...
    [0.53 0.63 0.12 0.14],'String',latencyList,'HorizontalAlignment','Center',...
    'BackgroundColor','white','callback',@lat_box_callback);

uicontrol('style','text','units','normalized','Position',...
    [0.53 0.605 0.15 0.02],'String','( ** = excluded epochs )','FontSize',10,'HorizontalAlignment','Left',...
    'BackgroundColor','white');

%epoch time windows
tw_title=uicontrol('style','text','units','normalized','position',...
    [0.72 0.75 0.1 0.04],'String','Epoch Window:','FontSize',11,'HorizontalAlignment','left',...
    'BackgroundColor','white');

tw_start_text=uicontrol('style','text','units','normalized','position',[0.72 0.725 0.1 0.035],...
    'string','Start (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
tw_start=uicontrol('style','edit','units','normalized','position',[0.88 0.73 0.055 0.035],...
    'string',twStart,'FontSize', 11, 'BackGroundColor','white','value',twStart,...
    'callback',@tw_start_callback);
    function tw_start_callback(src,~)
        twStart=str2double(get(src,'string'));
        updateLatencies;
        drawTrial;
    end

tw_end_text=uicontrol('style','text','units','normalized','position',[0.72 0.685 0.1 0.035],...
    'string','End (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
tw_end=uicontrol('style','edit','units','normalized','position',[0.88 0.69 0.055 0.035],...
    'string',twEnd,'FontSize', 11, 'BackGroundColor','white','value',twEnd,...
    'callback',@tw_end_callback);
    function tw_end_callback(src,~)
        twEnd=str2double(get(src,'string'));
        updateLatencies;
        drawTrial;
    end

tw_ol=uicontrol('style','edit','units','normalized','position',[0.88 0.65 0.058 0.035],'enable','off',...
    'string',minSep,'FontSize', 11, 'BackGroundColor','white','callback',@tw_ol_callback);
    function tw_ol_callback(src,~)
        minSep=str2double(get(src,'string'));
        updateLatencies;
        drawTrial;
    end

    function tw_ol_check_callback(src,~)
        useMinSep=get(src,'value');
        if useMinSep
           % set(tw_ol_text,'enable','on')
            set(tw_ol,'enable','on')
        else
           % set(tw_ol_text,'enable','off')
            set(tw_ol,'enable','off')
        end
        updateLatencies;
    end

correct_txt=uicontrol('style','text','units','normalized','position',[0.72 0.62 0.18 0.02],...
    'string','Latency Correction (s):','backgroundcolor','white','FontSize',11,'horizontalalignment','left');
latency_correct_edit=uicontrol('style','edit','units','normalized','position',[0.88 0.61 0.058 0.035],...
    'string',latencyCorrection,'FontSize', 11, 'BackGroundColor','white','callback',@latency_correction_callback);

    function latency_correction_callback(src,~)
        latencyCorrection = str2double(get(src,'String'));
        fprintf('*** will add offset of  %.5f seconds to all latencies during epoching...\n', latencyCorrection);
        drawTrial;
    end

tw_ol_check=uicontrol('style','checkbox','units','normalized','position',[0.72 0.65 0.14 0.035],...
    'string','Min. Separation (s):','backgroundcolor','white','value',useMinSep,'FontSize',11,'callback',@tw_ol_check_callback);

delete_button=uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.43 0.63 0.08 0.04],...
    'string','Delete Event','Foregroundcolor','blue','backgroundcolor','white','callback',@delete_callback);
    function delete_callback(~,~)
        idx = get(lat_box,'value');
        if isempty(idx)
            return;
        end
        time = latencyList(idx);
        s = sprintf('Delete event at latency t = %.4f seconds?', time);
        response = questdlg(s,'BrainWave','Yes','No','Yes');
        if strcmp(response,'Yes')           
            latencyList(idx) = []; 
            if currentTrialNo > size(latencyList,2)
                currentTrialNo = currentTrialNo - 1;
            end
            updateLatencies;
            drawTrial;
        end
        
    end

% launch event Marking tool
eventMarkerButton=uicontrol('style','pushbutton','units','normalized','position',[0.73 0.84 0.12 0.04],...
    'string','Create Marker Events','Foregroundcolor',orange,'enable','off','backgroundcolor','white','callback',@event_marker_callback);

    function event_marker_callback(~,~)
        [~,~,EXT] = fileparts(loadfull);

        if strcmp(EXT,'.ds')
            bw_eventMarker(loadfull);
        else
            fprintf('Event Marker requires CTF data format...\n');
        end
    end

%load latencies from default MarkerFile.mrk

load_lat=uicontrol('style','pushbutton','units','normalized','position',[0.57 0.84 0.12 0.04],...
    'string','Load Marker Latencies','Foregroundcolor','blue','backgroundcolor','white','callback',@load_lat_callback);
    function load_lat_callback(~,~)
        
        if isempty(dataType)
            errordlg('Must load valid MEG data ...');
            return;         
        end
        
        markerFileName = strcat(loadfull,filesep,'MarkerFile.mrk');
        
        if ~exist(markerFileName,'file')
            errordlg('No MarkerFile.mrk file found for this datasaet. Use Create Marker Events to create or import event latencies from other formats.');
            return;
        end
        
        [~,name,ext] = fileparts(markerFileName);
        eventFile = [name ext];  
        
        [newList, eventName] = bw_readCTFMarkers( markerFileName );        % GUI to select a CTF Marker

        if isempty(newList)
             fprintf('No events selected...\n');
             return;
        end

        fprintf('Read %d events from %s..\n', size(newList,1), markerFileName);

        if ~isempty(latencyList)
            reply = questdlg('Replace existing latencies or add to list?','Read Marker File','Replace', 'Add', 'Cancel','Replace');
            if strcmp(reply,'Cancel')
                return;
            end
            if strcmp(reply,'Add')
                latencyList = sort([latencyList; newList]);
            else
                latencyList = newList;
            end                              
        else
            latencyList = newList;
        end    

        % update badTrials flags
        numEvents = size(latencyList,1);
        badTrialFlags = zeros(1,numEvents);

        updateLatencies;

        update_saveName

        drawTrial;
    end

  
% % options
uicontrol('style','text','units','normalized','position',[0.45 0.55 0.12 0.04],...
        'String','Pre-processing','FontSize',11,'ForegroundColor','blue',...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');

filter_data_check = uicontrol('style','checkbox','units','normalized','position',[0.44 0.51 0.1 0.05],...
    'string','Filter data','value', filterData,'FontSize',12,'backgroundcolor','white','callback',@filter_data_callback);
    function filter_data_callback(src,~)
        filterData=get(src,'value');
        if lineFilterData || filterData
            set(filt_hi_pass_txt,'enable','on');
            set(filt_low_pass_txt,'enable','on');
            set(filt_hi_pass,'enable','on');
            set(filt_low_pass,'enable','on');
            set(extra_samples_check,'enable','on');
            
        else
            set(filt_hi_pass_txt,'enable','off');
            set(filt_low_pass_txt,'enable','off');
            set(filt_hi_pass,'enable','off');
            set(filt_low_pass,'enable','off');
            set(extra_samples_check,'enable','off');
        end
        
        updateSamples;
        drawTrial;
    end

filt_hi_pass_txt=uicontrol('style','text','units','normalized','position',[0.52 0.50 0.12 0.04],'enable','off',...
    'string','Highpass (Hz):','backgroundcolor','white','horizontalalignment','left');
filt_hi_pass=uicontrol('style','edit','units','normalized','position',[0.57 0.515 0.04 0.04],'enable','off',...
    'FontSize', 11, 'BackGroundColor','white','string',bandpass(1),...
    'callback',@filter_hipass_callback);
    function filter_hipass_callback(src,~)
        bandpass(1)=str2double(get(src,'string'));
        updateSamples;
        drawTrial;
    end

filt_low_pass_txt=uicontrol('style','text','units','normalized','position',[0.63 0.50 0.12 0.04],'enable','off',...
    'string','Lowpass (Hz):','backgroundcolor','white','horizontalalignment','left');
filt_low_pass=uicontrol('style','edit','units','normalized','position',[0.68 0.515 0.04 0.04],'enable','off',...
    'FontSize', 11, 'BackGroundColor','white','string',bandpass(2),...
    'callback',@filter_lowpass_callback);
    function filter_lowpass_callback(src,~)
        bandpass(2)=str2double(get(src,'string'));
        if bandpass(2) > data_params.sampleRate / 2
            fprintf('Selected lowpass filter setting is too high for sample rate...');
            bandpass(2) = data_params.sampleRate / 2;
            set(src,'string',bandpass(2));
        end
        updateSamples;
        drawTrial;
    end

extra_samples_check = uicontrol('style','checkbox','units','normalized','fontname','lucinda','position',[0.73 0.51 0.15 0.05],'enable','off',...
    'string','Expand filter window','value', useExtraSamples,'backgroundcolor','white','callback',@extra_samples_callback); %,'FontSize',11
    function extra_samples_callback(src,~)
        useExtraSamples=get(src,'value');
        updateLatencies;
        drawTrial;
    end

lineFilter_data_check = uicontrol('style','checkbox','units','normalized','position',[0.44 0.465 0.1 0.05],...
    'string','Filter powerline','value', lineFilterData,'FontSize',12,'backgroundcolor','white','callback',@lineFilter_data_callback);
    function lineFilter_data_callback(src,~)
        lineFilterData = get(src,'value');
        if lineFilterData || filterData
            set(extra_samples_check,'enable','on');
            set(radio_60Hz,'enable','on');
            set(radio_50Hz,'enable','on');
            
        else
            set(extra_samples_check,'enable','off');
            set(radio_60Hz,'enable','off');
            set(radio_50Hz,'enable','off');
        end
        
        updateSamples;
        drawTrial;
    end

if lineFilterFreq == 60
    val = 1;
else
    val = 0;
end
radio_60Hz = uicontrol('style','radio','units','normalized','fontname','lucinda','position',[0.55 0.465 0.06 0.05],'enable','off',...
    'string','60 Hz','value', val,'backgroundcolor','white','callback',@radio60Hz_callback); %,'FontSize',11
    function radio60Hz_callback(~,~)
        lineFilterFreq = 60.0;
        set(radio_50Hz,'value',0);
        drawTrial;
    end

if lineFilterFreq == 50
    val = 1;
else
    val = 0;
end
radio_50Hz = uicontrol('style','radio','units','normalized','fontname','lucinda','position',[0.6 0.465 0.06 0.05],'enable','off',...
    'string','50 Hz','value', val,'backgroundcolor','white','callback',@radio50Hz_callback); %,'FontSize',11
    function radio50Hz_callback(~,~)
        lineFilterFreq = 50.0;
        set(radio_60Hz,'value',0);
        drawTrial;
    end

uicontrol('style','text','units','normalized','position',[0.44 0.415 0.1 0.035],...
    'string','Sample Rate:','backgroundcolor','white','FontSize',12,'horizontalalignment','left');

sample_popup = uicontrol('style','popup','units','normalized',...
    'position',[0.53 0.405 0.12 0.05],'String', rates, 'Backgroundcolor','white','fontsize',12,...
    'value',1,'callback',@sample_popup_callback);

        function sample_popup_callback(src,~)
            menu_select=get(src,'value');
            downSample = menu_select;
            if downSample > 1
                fprintf('epoched data will be downsampled by factor of %d\n', downSample);
            end
            drawTrial;
        end

chanSelectButton = uicontrol('style','pushbutton','units','normalized','position',[0.85 0.515 0.1 0.04],...
    'enable','off','string','Edit Channels','Foregroundcolor',orange,'backgroundcolor',...
    'white','callback',@channel_selector_callback);
    
    function channel_selector_callback(~,~)

        bcpos = find(validChan==0);  % pass existing bad channel indices to dialog

        [bcpos, channelMenuIndex] = bw_select_data(loadfull,bcpos, channelMenuIndex);
        
        % new in 3.3 - removed line that was resettting the bad channels flags
        
        % moved check for CTF bad channels to here - since we don't
        % want to automatically check every time when switching datasets in
        % batch mode
        badChanFile = sprintf('%s%s%s', loadfull, filesep, 'BadChannels');
        if exist(badChanFile,'file')
            t = importdata(badChanFile);
            numBad = size(t,1);     % in case empty BadChannels file...
            if numBad > 0                 
                response = questdlg(s,'BrainWave','Yes','No','Yes');
                if strcmp(response,'Yes')
                    validChan=ones(size(channelNames,1),1);
                    A = cellstr(channelNames);
                    for i=1:numBad
                        s = char(t{i});
                        idx = find( strcmp(deblank(s),A) == 1);                      
                        fprintf('Setting channel %s to bad\n', channelNames(idx,:));
                        bcpos(i) = idx;
                        validChan(idx) = 0;
                    end
                    tstr=sprintf('MEG Channels: %d (%d excluded)',data_params.numSensors-numBad, numBad);
                    set(no_channels,'string',tstr); 
                end
            end
        end

        % set validChan to list returned by channel selector
        % bcpos is vector of indices into the complete channel list for bad channels
        %
        validChan = ones(data_params.numSensors,1);
        validChan(bcpos,1)=0;                   % set bad channel indices to zero
        numBad = length(bcpos);       
        
        if numBad > 0
            t=sprintf('MEG Channels: %d (%d excluded)',data_params.numSensors-numBad, numBad); 
        else
            t=sprintf('MEG Channels: %d ',data_params.numSensors); 
        end
        set(no_channels,'string',t); 
        
        updateLatencies;
        drawTrial;
    
    end

use_mean_position_check = uicontrol('style','checkbox','units','normalized','fontname','lucinda','position',[0.68 0.425 0.15 0.04],...
    'string','Use mean head position','value',useMeanHeadPosition,'enable','off',...
    'backgroundcolor','white','callback',@use_mean_callback);%'FontSize',11

    function use_mean_callback(src,~)            
        useMeanHeadPosition=get(src,'value');
        if useMeanHeadPosition
            set(updateHeadPos_Button,'enable','on')
        else
            set(updateHeadPos_Button,'enable','off')
            updateHeadPosition;   % set back to original
        end    
    end

updateHeadPos_Button = uicontrol('style','pushbutton','units','normalized','position',[0.78 0.43 0.05 0.03],...
    'enable','off','string','Update','Foregroundcolor',orange,'backgroundcolor',...
    'white','callback',@updateHeadPos_Callback);

    function updateHeadPos_Callback(~,~)                   
       updateHeadPosition;   % get new head position
    end


%surrounding rectangle    
annotation('rectangle','position',[0.42 0.41 0.565 0.17],'edgecolor','blue');  


save_average_check = uicontrol('style','checkbox','units','normalized','position',[0.23 0.04 0.1 0.03],...
    'string','Save Average','value',save_average,'FontSize',11,'backgroundcolor','white','callback',@save_average_callback);

    function save_average_callback(src,~)
        save_average=get(src,'value');
    end

deidentify_check = uicontrol('style','checkbox','units','normalized','position',[0.3 0.04 0.1 0.03],...
    'string','De-identify Data','value',deidentifyData,'FontSize',11,'backgroundcolor','white','callback',@deidentify_callback);

    function deidentify_callback(src,~)
        deidentifyData=get(src,'value');
    end


% plot window

uicontrol('style','text','units','normalized','position',[0.45 0.36 0.08 0.04],...
        'String','Preview','FontSize',11,'ForegroundColor','blue',...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');
   
preview_text=uicontrol('style','text','units','normalized','fontsize',11,'position',...
    [0.6 0.35 0.35 0.03],'string','','Foregroundcolor','black','horizontalAlignment','left','backgroundcolor','white');

uicontrol('style','pushbutton','units','normalized','fontsize',10,'position',[0.43 0.05 0.08 0.035],...
    'string','Select All','Foregroundcolor','blue','backgroundcolor','white','callback',@select_all_callback);
    
    function select_all_callback(~,~)
        if isempty(channelNames)
            return;
        end
        selectedChannels = 1:1:size(channelNames,1);    
        set(channel_box,'value',selectedChannels);
        
        drawTrial;
    end

trialInc =uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.88 0.03 0.08 0.03],...
    'string','Trial >','Foregroundcolor','blue','backgroundcolor','white','callback',@trial_inc_callback);
trialDec =uicontrol('style','pushbutton','units','normalized','fontsize',11,'position',[0.58 0.03 0.08 0.03],...
    'string','< Trial','Foregroundcolor','blue','backgroundcolor','white','callback',@trial_dec_callback);

uicontrol('style','checkbox','units','normalized','position',[0.43 0.35 0.12 0.02],...
    'string','Remove offset','value', removeOffset,'FontSize',11,'backgroundcolor','white','callback',@remove_offset_callback);
    function remove_offset_callback(src,~)
        removeOffset=get(src,'value');
        drawTrial;
    end

uicontrol('style','checkbox','units','normalized','position',[0.43 0.325 0.12 0.02],...
    'string','Show Bad Channels','value', plotBad,'FontSize',11,'backgroundcolor','white','callback',@plot_bad_callback);
    function plot_bad_callback(src,~)
        plotBad=get(src,'value');
        drawTrial;
    end

uicontrol('style','text','units','normalized','position',[0.43 0.275 0.1 0.04],...
        'String','MEG Channel','FontSize',10,'ForegroundColor','black','HorizontalAlignment','left','BackGroundColor', 'white');

channel_box=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized','Position',...
    [0.43 0.1 0.075 0.2],'String',latencyList,'HorizontalAlignment','Center','min',1,'max',1000,...
    'BackgroundColor','white', 'callback',@channel_box_callback);

%surrounding rectangle    
annotation('rectangle','position',[0.42 0.02 0.565 0.37],'edgecolor','blue');  

%%%%%%%%
% artifact rejection

uicontrol('style','text','units','normalized','position',[0.03 0.36 0.15 0.04],...
        'String','Epoch Rejection','FontSize',11,'ForegroundColor','blue',...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');
      
uicontrol('style','text','units','normalized','fontname','lucinda','position',[0.04 0.335 0.27 0.04],...
  'String','Exclude epoch if...','HorizontalAlignment','left',...%'fontsize',textFontSize,...
  'BackgroundColor','white');
    
peakToPeak_check = uicontrol('style','checkbox','units','normalized','fontname','lucinda','position',[0.06 0.32 0.27 0.04],...
    'string','Peak-peak amplitude exceeds','value',exclude_BadTrials,'backgroundcolor','white','callback',@peakToPeak_callback);%,'FontSize',11
    function peakToPeak_callback(src,~)
        exclude_BadTrials=get(src,'value');   
        if exclude_BadTrials
            epochsValid = 0;
        end
    end

peakThreshold_edit=uicontrol('style','edit','units','normalized','position',[0.2 0.325 0.04 0.035],...
    'FontSize', 11, 'BackGroundColor','white','string',peakThreshold * 1e12,'callback',@peakThreshold_callback);
    function peakThreshold_callback(src,~)
        peakThreshold = str2double(get(src,'string')) * 1e-12;
        if exclude_BadTrials
            epochsValid = 0;
        end
    end
uicontrol('style','text','units','normalized','position',[0.25 0.31 0.06 0.04],...
        'String','pT','fontname','lucinda','ForegroundColor','black','HorizontalAlignment','left','BackGroundColor', 'white');
 
reset_check = uicontrol('style','checkbox','units','normalized','fontname','lucinda','position',[0.06 0.27 0.27 0.04],...
    'string','Amplitude step (reset) exceeds','value',exclude_Resets,'backgroundcolor','white','callback',@reset_callback);%,'FontSize',11
    function reset_callback(src,~)
        exclude_Resets=get(src,'value');   
        if exclude_Resets
            epochsValid = 0;
        end
    end

resetThreshold_edit=uicontrol('style','edit','units','normalized','position',[0.2 0.275 0.04 0.035],...
    'FontSize', 11, 'BackGroundColor','white','string',resetThreshold *1e12,'callback',@resetThreshold_callback);
    function resetThreshold_callback(src,~)
        resetThreshold = str2double(get(src,'string')) * 1e-12; % in Tesla
        if exclude_Resets
            epochsValid = 0;
        end
    end
uicontrol('style','text','units','normalized','position',[0.25 0.26 0.06 0.04],...
        'String','pT','fontname','lucinda','ForegroundColor','black','HorizontalAlignment','left','BackGroundColor', 'white');    


head_motion_check = uicontrol('style','checkbox','units','normalized','fontname','lucinda','position',[0.06 0.22 0.27 0.04],...
    'string','Mean sensor motion exceeds','value',exclude_HeadMotion,'backgroundcolor','white','callback',@head_motion_callback);%,'FontSize',11
    function head_motion_callback(src,~)
        exclude_HeadMotion = get(src,'value');    
        if exclude_HeadMotion
            epochsValid = 0;
        end
    end

motionThreshold_edit=uicontrol('style','edit','units','normalized','position',[0.2 0.225 0.04 0.035],...
    'FontSize', 11, 'BackGroundColor','white','string',motionThreshold,'callback',@motionThreshold_callback);
    function motionThreshold_callback(src,~)
        motionThreshold = str2double(get(src,'string')); % in cm
        if exclude_HeadMotion
            epochsValid = 0;
        end
    end
uicontrol('style','text','units','normalized','position',[0.25 0.21 0.07 0.04],...
        'String','cm','fontname','lucinda','ForegroundColor','black','HorizontalAlignment','left','BackGroundColor', 'white');

    
bad_channel_check = uicontrol('style','checkbox','units','normalized','fontname','lucinda','position',[0.02 0.17 0.27 0.04],...
    'string','Exclude Channel if number of trials rejected exceeds','value',exclude_BadChannels,'backgroundcolor','white','callback',@bad_channel_callback);%,'FontSize',11
    function bad_channel_callback(src,~)
        exclude_BadChannels = get(src,'value');    
        if exclude_BadChannels
            epochsValid = 0;
        end
    end
    
s = sprintf('%.1f',channelRejectThreshold*100);
badChannel_edit=uicontrol('style','edit','units','normalized','position',[0.23 0.175 0.04 0.035],...
    'FontSize', 11, 'BackGroundColor','white','string',s,'callback',@badChannelThreshold_callback);
    function badChannelThreshold_callback(src,~)
        channelRejectThreshold = str2double(get(src,'string')) * 0.01; % in cm
        if exclude_BadChannels
            epochsValid = 0;
        end
    end

uicontrol('style','text','units','normalized','position',[0.28 0.16 0.07 0.04],...
        'String','percent','fontname','lucinda','ForegroundColor','black','HorizontalAlignment','left','BackGroundColor', 'white');

function updateSamples

    % get allowable sample rates
    % allow sample rates that are greater than 3 times bandwidth
    bandwidth = data_params.lowPass;
    if filterData
        % if filtering data allow additional sample rates
        % ignore low-pass filter setting if it set to a value higher than on-line filter
        if bandpass(2) < data_params.lowPass
            bandwidth = bandpass(2);
        end
    end

    rates = {};
    count = 1;
    % add sample rates to menu until below cutoff (3 * bandwidth)
    while (1)
        fs = data_params.sampleRate / double(count);           
        if fs < bandwidth * 3.0
            break;
        end
        s = sprintf('%g Samples/s', fs );
        sampleRates(count) = fs;
        rates(count) = cellstr(s);
        count = count+1;
    end

    if downSample > size(rates,2)
        downSample = size(rates,2);
        set(sample_popup,'value',downSample);
    end
    set(sample_popup,'String',rates);

end


function clearSettings
    set(trialInc,'enable','off');
    set(trialDec,'enable','off');

    epochFlag=0;

    set(epoch_data,'value',epochFlag)
    set(all_data,'value',~epochFlag)
    set(single_epoch_start,'enable','on');
    set(single_epoch_end,'enable','on');

    set(lat_text,'enable','off')
    set(lat_box,'enable','off')
    set(tw_title,'enable','off')
    set(tw_start_text,'enable','off')
    set(tw_start,'enable','off')
    set(tw_end_text,'enable','off')
    set(tw_end,'enable','off')
    set(tw_ol,'enable','off')
    set(tw_ol_check,'enable','off')
    set(load_lat,'enable','off')
    set(save_average_check,'enable','off');

    set(delete_button,'enable','off');
    set(correct_txt,'enable','off');
    set(latency_correct_edit,'enable','off');

    currentTrialNo = 1;
    latencyList = [];

end


selected_only_check = uicontrol('style','checkbox','units','normalized','position',[0.2 0.12 0.15 0.04],...
    'string','Scan selected channels only','value',useSelectedChannels,...
    'FontSize',11,'backgroundcolor','white','callback',@selected_only_callback);

    function selected_only_callback(src,~)
        useSelectedChannels=get(src,'value');        
    end

uicontrol('style','pushbutton','units','normalized','fontsize',10,'position',[0.03 0.12 0.08 0.035],...
    'string','Scan Epochs','Foregroundcolor','blue','backgroundcolor','white','callback',@scanTrials_callback);
    
    function scanTrials_callback(~,~)
        
        if ~epochFlag || isempty(latencyList)
            return;
        end
        
        % make sure we have current threshold in standard units (Tesla and
        % meters)
        
        resetThreshold = str2double(get(resetThreshold_edit,'string')) * 1e-12;
        peakThreshold = str2double(get(peakThreshold_edit,'string')) * 1e-12;
        motionThreshold = str2double(get(motionThreshold_edit,'string'));  % keep in cm

        checkData(0);       
        drawTrial;
        
    end

uicontrol('style','pushbutton','units','normalized','fontsize',10,'position',[0.13 0.12 0.05 0.035],...
    'string','Reset','Foregroundcolor','blue','backgroundcolor','white','callback',@undo_trials_callback);
    
    function undo_trials_callback(~,~)

        if isempty(find(badTrialFlags == 1))
            fprintf('No epochs are excluded...\n');  
            return;
        end
            
        s = sprintf('Undo exclude bad epochs?\n');
        response = questdlg(s,'BrainWave','Yes','No','Yes');
        if strcmp(response,'Yes')
            badTrialFlags = zeros(1,size(latencyList,1));
            updateLatencies;
            drawTrial;
        end
                
    end


function checkData(autoMode)

    epochsValid = 1;
    
    if ~epochFlag 
        return;
    end
    
%     if ~exclude_BadTrials && ~exclude_HeadMotion && ~exclude_Resets
%         return;
%     end
    
    fprintf('Scanning data ...\n', peakThreshold * 1e12);
    if exclude_BadTrials
        fprintf('Excluding epochs with peak-to-peak noise greater than %g picoTesla ...\n', peakThreshold * 1e12);
    end

    if exclude_Resets
        fprintf('Excluding epochs with resets (1st derivative = %g picoTesla ...\n', resetThreshold * 1e12);
    end

    if exclude_HeadMotion  
        fprintf('Excluding epochs with mean sensor motion greater than %g cm ... \n', motionThreshold);
    end
    
    if exclude_BadChannels
        fprintf('Excluding Channels if number of trials rejected exceeds %g percent ... \n', channelRejectThreshold*100.0);
    end

    numTrials = size(latencyList,1);
    numChannels = size(channelNames,1);

    if ~autoMode && ~isempty(find(badTrialFlags == 1))
        s = sprintf('Clear current rejected epochs?\n');
        response = questdlg(s,'BrainWave','Yes','No','Yes');
        if strcmp(response,'Yes')
            badTrialFlags = zeros(numTrials,1);
            updateLatencies;
        end        
    else
        badTrialFlags = zeros(numTrials,1);
    end
    
    [badTrialCount, badChannelCount, badChannelList] = scanTrials;
   
    if badTrialCount > 0
        
        % check if re-scanning is required due to bad channels 
        if badChannelCount > 0 && exclude_BadChannels == 1
            if autoMode
                % exclude the bad channels and rescan the data
                fprintf('Excluding %d bad channels and re-scanning\n', badChannelCount);
                
                newBad = [badChannelList'; bcpos];    % add to existing bad channels    
                bcpos = newBad;                       
                validChan(bcpos) = 0;
                
                % rescan data
                badTrialFlags = zeros(numTrials,1);
                [badTrialCount, badChannelCount, ~] = scanTrials;
                if badChannelCount > 0
                    epochsValid = 0;        % something went wrong ... 
                    return;
                end
            else           
                beep;
                % interactive mode if not doing batch allow user to edit or
                % reject bad channels
                s = sprintf('%d channels exceeded %g%% of trials rejected', badChannelCount, channelRejectThreshold*100.0);
                response = questdlg(s,'BrainWave','Yes','No','Yes');      
                if strcmp(response,'Yes')      
                    newBad = [badChannelList'; bcpos];    % keep existing bad channels 
                    [newBad, menuSelect, valid] = bw_select_data(loadfull,newBad, 0);                
                    if valid
                        bcpos = newBad;    % keep existing bad channels 
                        validChan(bcpos) = 0;
                        channelMenuIndex = menuSelect;
                    end

                end    
            end
        end      
        fprintf(' ** %d epoch(s) excluded (%.2f %% of total) **\n', badTrialCount, (badTrialCount/numTrials)*100.0);
        
        if badTrialCount == numTrials
            fprintf('Warning: all epochs excluded...\n');
        else
            if useMeanHeadPosition && ~autoMode
                updateHeadPosition;  % only if pre-scanning data update the mean head position after trial rejection
            end
        end
        
    else
        fprintf('No epochs excluded...\n');
    end  
    
    % updates GUI latency list only 
    updateLatencies;
    
end

function [badTrialCount, badChannelCount, badChannelList] = scanTrials


    numTrials = size(latencyList,1);
    numChannels = size(channelNames,1);
    
    badChannelTable = zeros(size(channelNames,1), numTrials);
    
    sampleRate = data_params.sampleRate;

    epochWindow = [twStart twEnd];
    timeVec = epochWindow(1):1/sampleRate:epochWindow(2);
    epochSamples = length(timeVec);

    badTrialCount = 0;
    badChannelCount = 0;
    badChannelList = [];
 
    fprintf('Scanning epochs...\n');
    wbh = waitbar(0,'1','Name','Scanning epochs...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wbh,'canceling',0)

    headOrigin = (fid_pts_dewar.le + fid_pts_dewar.re) /2.0;
    
    % change in 3.6 D. Cheyne
    % now compute head and sensor motion if CHL is available and save
    % results even if not doing trial rejection
    
    % need mean head position for all epochs
    if hasCHL   

        % get positions of first coil - primary sensors only
        %                              
        [~, positions, ~] = bw_CTFGetSensors(loadfull, 0);

        % we need sensor positions in dewar coordinates as
        % an independent frame of reference = coilPos_dewar 
        % we also save all positions for default head coordinates = coilPos_head
        % 
        dewar2head = bw_getAffineVox2CTF(fid_pts_dewar.na, fid_pts_dewar.le, fid_pts_dewar.re, 1.0);
        head2dewar = inv(dewar2head);      
        numSensors = size(positions,1);   
        coilPos_head = [positions ones(numSensors,1)];
        coilPos_dewar = coilPos_head * head2dewar;

        % if using mean head position, retransform coilPos_head to
        % be relative to the current mean head position, otherwise
        % motion check is relative to original (fiducial
        if useMeanHeadPosition   
            [Na, Le, Re] = updateHeadPosition;          
            % get transformation to mean head position fiducials
            dewar2head = bw_getAffineVox2CTF(Na.mean, Le.mean, Re.mean, 1.0);
            % convert positions to mean head pos
            coilPos_head = coilPos_dewar * dewar2head;                 
            headOrigin = (Le.mean + Re.mean) /2.0;
        end
        % structure to hold motion data to save with epoched data
        motionData.units = 'cm';
        motionData.meanHeadMotion = 0.0;
        motionData.meanSensorMotion = 0.0;
        motionData.headMotion = [];
        motionData.sensorMotion = [];
        motionData.motionThreshold = motionThreshold;
        motionData.useMeanHeadPosition = useMeanHeadPosition;
        motionData.motionTrialsRejected = 0;
    end
    
    % filter expanded epoch to minimize end effects - was not
    % applied in version 3.2
    extraSamples = 0;
    if (filterData || lineFilterData) && useExtraSamples
        extraSamples = round(epochSamples/2);
        epochSamples = epochSamples + (extraSamples * 2);
    end                 

    channelRejectNo = round(numTrials * channelRejectThreshold);
       
    % scan the data ...
    for i=1:numTrials

        s = sprintf('Scanning epoch %d of %d', i, numTrials);
        waitbar(i/numTrials,wbh,s);

        if getappdata(wbh,'canceling')
            delete(wbh);   
            fprintf('*** trial scan cancelled ***\n');
            return;
        end

        latency = latencyList(i) + latencyCorrection;

        %%%% bug fix vers3.0beta wasn't checking for out of range at beginning of data
        startSample = round( (latency+epochWindow(1)) * sampleRate ) - extraSamples;

        if (startSample < 0) || (startSample + epochSamples > data_params.totalSamples)
            fprintf('... warning epoch %d out of range\n', i);
            continue;
        end
        %%%%

        % get segment of data...
        [~,~,EXT] = fileparts(loadfull);
        if strcmp(EXT,'.con')
            tmp_data = getYkgwData(loadfull, startSample, epochSamples);    
        elseif strcmp(EXT,'.ds')
            % transpose since bw_getCTFData returns [nsamples x nchannels]                
            tmp_data = bw_getCTFData(loadfull, startSample, epochSamples)';
        end

        if hasCHL                    
            % get head position for this trial              
            [thisNa, thisLe, thisRe] = bw_getCTFHeadPosition(loadfull, startSample, epochSamples );
            
            % add tracking of head origin for each trial
            thisHeadOrigin = (thisLe + thisRe) /2;
            headMotion = norm( headOrigin - thisHeadOrigin );
        end       
       
        sensorMotion = 0.0;               
        channelCount = 0;
        isBadTrial = 0;

        for j=1:size(channelNames,1)
            if useSelectedChannels && isempty(find( selectedChannels==j,1) )
                continue;
            end                

            % don't check bad channels!     
            if validChan(j) == 0
                continue;
            end

            trial = tmp_data(j,:);
            if filterData
                % just filter segment without extra samples for now...
                y = bw_filter(trial, data_params.sampleRate, bandpass); 
                trial = y;                   
            end

            if lineFilterData == 1   
                f1 = -lineFilterWidth;
                f2 = lineFilterWidth;
                for n=1:4   % remove fundamental and 1st 3 harmonics
                    f1 = f1 + lineFilterFreq;
                    f2 = f2 + lineFilterFreq;
                    if f2 < data_params.sampleRate / 2.0;
                        % just filter segment without extra samples for now...
                        y = bw_filter(trial, data_params.sampleRate, [f1 f2],4,1,1); 
                        trial = y;                   
                    end
                end
            end

            % truncate extra samples before checking for artifacts
            trial = trial(1+extraSamples:end-extraSamples);

            % bug fix, this wasn't removing offset from trial array  in 3.1 !! 
            if removeOffset
                offset = mean( trial );
                trial = trial - offset;
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % check for peak to peak artifacts

            if exclude_BadTrials
                peakToPeak = abs( max(trial) - min(trial) );
                if (peakToPeak > peakThreshold)
                    badTrialFlags(i) = 1;   
                    fprintf('peak-to-peak threshold exceeded in channel %s (epoch %d, p-p = %g picoTesla)\n', channelNames(j,:), i, peakToPeak*1e12);
                    isBadTrial = 1;
                end

                % look for flat channels in Neuromag data...
                if (peakToPeak == 0)
                    badTrialFlags(i) = 1;   
                    fprintf('** excluding flat channel %s (epoch %d, p-p  value = %g picoTesla)\n', channelNames(j,:), i, peakToPeak*1e12);
                    isBadTrial = 1;
                end

            end

            % look for resets as large jump within one time
            % sample
            if exclude_Resets && ~isBadTrial
                peakDiff = max(abs( diff(trial)) );
                if (peakDiff > resetThreshold)
                    badTrialFlags(i) = 1;   
                    fprintf('** Reset detected in channel %s (epoch %d, max diff = %g picoTesla)\n', channelNames(j,:), i, peakDiff *1e12);
                    isBadTrial = 1;
                end                  
            end

            % keep track of how many trials are rejected for each
            % channel - applies to p-p check only

            if isBadTrial
                badChannelTable(j,i) = 1;  % sets this(channel,trial) = bad
            end


            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % compute movement for this channel 
            % relative to original head position

            % new in 3.4 - don't include this trial in motion check if this trial
            % is going to be excluded
            if hasCHL && ~isBadTrial

                % get this channel position in dewar coords and
                % transform to the current head position                       
                dewarPos = coilPos_dewar(j,:);                       
                dewar2head = bw_getAffineVox2CTF(thisNa, thisLe, thisRe, 1.0);
                thisHeadPos = dewarPos * dewar2head;
                rmsErr = norm( thisHeadPos(1:3) - coilPos_head(j,1:3));

                % sum RMS sensor motion
                sensorMotion = sensorMotion + rmsErr;
                % 3.4 - this should be inside this loop since trial
                % may now be skipped
                channelCount = channelCount + 1;  % number of channels that have been checked for head motion

            end

        end % for j channels

        if hasCHL && ~isBadTrial
            sensorMotion = sensorMotion / channelCount; % average sensor motion over channels
            if exclude_HeadMotion && sensorMotion > motionThreshold  
                badTrialFlags(i) = 1;   
                fprintf('mean sensor movement threshold exceeded: for epoch %d, mean sensor motion = %g cm, head Motion (origin) = %g cm\n', i, sensorMotion, headMotion);
                motionData.motionTrialsRejected = motionData.motionTrialsRejected + 1;
            else
                % save motion data for non-rejected trials to be saved with data
                motionData.sensorMotion(end+1) = sensorMotion;
                motionData.headMotion(end+1) = headMotion;
                motionData.meanSensorMotion = motionData.meanSensorMotion + sensorMotion;        
                motionData.meanHeadMotion = motionData.meanHeadMotion + headMotion;        
            end
        end


    end % for i trials
    
    % correct mean motion for number of non-rejected trials
    if hasCHL
        motionData.meanHeadMotion = motionData.meanHeadMotion / length(motionData.headMotion);
        motionData.meanSensorMotion = motionData.meanSensorMotion / length(motionData.sensorMotion);
    
        fprintf('mean sensor motion = %g cm\n', motionData.meanSensorMotion) 
        fprintf('mean head origin movement =  %g cm\n', motionData.meanHeadMotion) 
    end
    
    delete(wbh);

    clear tmp_data;

    idx = find(badTrialFlags == 1);
    badTrialCount = length(idx);
    
    if badTrialCount > 0
        % check for bad channels
        badChannelCount = 0; 
        for j=1:numChannels 
            idx = find(badChannelTable(j,:) == 1);            
            if length(idx) > channelRejectNo
                badChannelCount = badChannelCount + 1;
                badChannelList(badChannelCount) = j;
            end
        end
    end      

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Anton Hung, August 2021: The next 500 lines are all related to the new
% function, bw_headMotionPlot. This provides the option of seeing a visual
% of the subjects' head movement over the duration of the study prior to
% creating epoched datasets. The following functions are largely 
% duplicated from the original scan_trials with a few modifications. Doing
% this rather than editing the original functions make it so that there is 
% no interference with the existing functionality of the "Create Datasets" 
% button.

% Pressing the "Plot Head Motion" button calls headMotionPlot_callback
% headMotionPlot_callback calls headMotionPlot_checkData
% headMotionPlot_checkData calls headMotionPlot_scanTrials
% headMotionPlot_scanTrials makes data structures to be used in bw_headMotionPlot.

% 5 data structures, latencyArray, headMotionArray, sensorMotionArray,
% badTrialsArray and namesArray are the most important part of
% headMotionPlot_scanTrials. These structures contain the subjects' data,
% where every row is one subject and the number of columns equals the
% number of epochs. These 5 data structures are passed on to
% bw_HeadMotionPlot.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

headMotionPlot_button=uicontrol('style','pushbutton','units','normalized','fontsize',10,'position',[0.28 0.225 0.08 0.03],...
    'string','Plot Head Motion','Foregroundcolor',orange,'backgroundcolor','white','callback',@headMotionPlot_callback);
    
    function headMotionPlot_callback(~,~)

        if ~epochFlag || isempty(latencyList)
            return;
        end

        % make sure we have current threshold in standard units (Tesla and
        % meters)

        resetThreshold = str2double(get(resetThreshold_edit,'string')) * 1e-12;
        peakThreshold = str2double(get(peakThreshold_edit,'string')) * 1e-12;
        motionThreshold = str2double(get(motionThreshold_edit,'string'));  % keep in cm

        headMotionPlot_checkData(0);       
        drawTrial;

    end
    
    
function headMotionPlot_checkData(autoMode)
% copied from original checkData function, except that this calls
% headMotionPlot_scanTrials instead of scanTrials
    epochsValid = 1;
    
    if ~epochFlag 
        return;
    end
    
    fprintf('Scanning data ...\n');
    if exclude_BadTrials
        fprintf('Excluding epochs with peak-to-peak noise greater than %g picoTesla ...\n', peakThreshold * 1e12);
    end

    if exclude_Resets
        fprintf('Excluding epochs with resets (1st derivative = %g picoTesla ...\n', resetThreshold * 1e12);
    end

    if exclude_HeadMotion  
        fprintf('Excluding epochs with mean sensor motion greater than %g cm ... \n', motionThreshold);
    end
    
    if exclude_BadChannels
        fprintf('Excluding Channels if number of trials rejected exceeds %g percent ... \n', channelRejectThreshold*100.0);
    end

    numTrials = size(latencyList,1);
    numChannels = size(channelNames,1);

    if ~autoMode && ~isempty(find(badTrialFlags == 1))
        s = sprintf('Clear current rejected epochs?\n');
        response = questdlg(s,'BrainWave','Yes','No','Yes');
        if strcmp(response,'Yes')
            badTrialFlags = zeros(numTrials,1);
            updateLatencies;
        end        
    else
        badTrialFlags = zeros(numTrials,1);
    end
    
    [badTrialCount, badChannelCount, badChannelList] = headMotionPlot_scanTrials;
   
    if badTrialCount > 0
        
        % check if re-scanning is required due to bad channels 
        if badChannelCount > 0 && exclude_BadChannels == 1
            if autoMode
                % exclude the bad channels and rescan the data
                fprintf('Excluding %d bad channels and re-scanning\n', badChannelCount);
                
                newBad = [badChannelList'; bcpos];    % add to existing bad channels    
                bcpos = newBad;                       
                validChan(bcpos) = 0;
                
                % rescan data
                badTrialFlags = zeros(numTrials,1);
                [badTrialCount, badChannelCount, ~] = headMotionPlot_scanTrials;
                if badChannelCount > 0
                    epochsValid = 0;        % something went wrong ... 
                    return;
                end
            else           
                beep;
                % interactive mode if not doing batch allow user to edit or
                % reject bad channels
                s = sprintf('%d channels exceeded %g%% of trials rejected', badChannelCount, channelRejectThreshold*100.0);
                response = questdlg(s,'BrainWave', 'Edit Channels', 'Ignore','Ignore');
                if strcmp(response,'Edit Channels')
                    newBad = [badChannelList'; bcpos];    % keep existing bad channels 
                    [newBad, menuSelect, valid] = bw_select_data(loadfull,newBad, 0);                
                    if valid
                        bcpos = newBad;    % keep existing bad channels 
                        validChan(bcpos) = 0;
                        channelMenuIndex = menuSelect;
                    end

                end    
            end
        end      
        fprintf(' ** %d epoch(s) excluded (%.2f %% of total) **\n', badTrialCount, (badTrialCount/numTrials)*100.0);
        
        if badTrialCount == numTrials
            fprintf('Warning: all epochs excluded...\n');
        else
            if useMeanHeadPosition && ~autoMode
                updateHeadPosition;  % only if pre-scanning data update the mean head position after trial rejection
            end
        end
        
    else
        fprintf('No epochs excluded...\n');
    end  
    
    % updates GUI latency list only 
    updateLatencies;
    
end    

function [badTrialCount, badChannelCount, badChannelList] = headMotionPlot_scanTrials
    
    % 2021/08/17 - Anton: added a feature that makes a plot and histogram to show head motion. 
    % Changes:
    % enclosed original scanTrails code in a for loop because we need to 
    % update head motion data for all subjects one at a time (unlike scanTrials, 
    % this function has the option to iterate through each of the selected datasets)
    
    numDatasets = size(dsList, 2);
    largestNumTrials = size(latencyList,1);

    plotAll = 0;
    
    % gives the option to just scan the selected subject instead of going
    % through all of them because it can take time. If no, response = 0 and
    % the for loop breaks after one iteration
    if numDatasets > 1
        response = questdlg('Plot head motion for all datasets?',...
            'Head Motion','Plot All','Plot Selected','Cancel','Plot Selected');
        if strcmp(response,'Cancel')
            return;
        end
        if strcmp(response,'Plot All')
            plotAll = 1;
        end        
    end
        
    % because all the data is stored in matrices, but not all subjects
    % have an equal number of epochs, we are finding the largest number
    % of trials to preallocate enough space
    if plotAll == 1
        for k=1:numDatasets
            loadCTFData(k);
            numTrials = size(latencyList,1);
            if numTrials > largestNumTrials
                largestNumTrials = numTrials;
            end
        end
        
        % the data that will eventually be passed to the new function include:
        % latencies, head motion, sensor motion, bad trials, and the dataset
        % names. All except for the names are stored in matrices where each row
        % is one subject. A cell array stores the names.
        latencyArray = NaN([numDatasets, largestNumTrials]);
        headMotionArray = NaN([numDatasets, largestNumTrials]);
        sensorMotionArray = NaN([numDatasets, largestNumTrials]);
        badTrialArray = zeros([numDatasets, largestNumTrials]);
        namesArray = cell([1,numDatasets]);
        
    else
        latencyArray = NaN([1, largestNumTrials]);
        headMotionArray = NaN([1, largestNumTrials]);
        sensorMotionArray = NaN([1, largestNumTrials]);
        badTrialArray = zeros([1, largestNumTrials]);
        namesArray = cell([1,1]);
    end
    
    for k=1:numDatasets
        if plotAll == 1
            loadCTFData(k); % if the user wants to plot all subjects, than iterate through each one one-by-one
        else
            loadCTFData(menu_select); % if the user only wants one subject, this is tracked in the global variable "menu_select"
        end
        
        headMotionList = NaN([1,largestNumTrials]); % these arrays store all values of movement regardless of rejection because all of them should be included in the plots.
        sensorMotionList = NaN([1,largestNumTrials]);

        numTrials = size(latencyList,1);
        numChannels = size(channelNames,1);

        badChannelTable = zeros(size(channelNames,1), numTrials);

        sampleRate = data_params.sampleRate;

        epochWindow = [twStart twEnd];
        timeVec = epochWindow(1):1/sampleRate:epochWindow(2);
        epochSamples = length(timeVec);

        badTrialCount = 0;
        badChannelCount = 0;
        badChannelList = [];

        fprintf('Scanning epochs...\n');
        wbh = waitbar(0,'1','Name','Scanning epochs...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wbh,'canceling',0)

        headOrigin = (fid_pts_dewar.le + fid_pts_dewar.re) /2.0;

        % change in 3.6 D. Cheyne
        % now compute head and sensor motion if CHL is available and save
        % results even if not doing trial rejection

        % need mean head position for all epochs
        if hasCHL   

            % get positions of first coil - primary sensors only
            %                              
            [~, positions, ~] = bw_CTFGetSensors(loadfull, 0);

            % we need sensor positions in dewar coordinates as
            % an independent frame of reference = coilPos_dewar 
            % we also save all positions for default head coordinates = coilPos_head
            % 
            dewar2head = bw_getAffineVox2CTF(fid_pts_dewar.na, fid_pts_dewar.le, fid_pts_dewar.re, 1.0);
            head2dewar = inv(dewar2head);      
            numSensors = size(positions,1);   
            coilPos_head = [positions ones(numSensors,1)];
            coilPos_dewar = coilPos_head * head2dewar;

            % if using mean head position, retransform coilPos_head to
            % be relative to the current mean head position, otherwise
            % motion check is relative to original (fiducial
            if useMeanHeadPosition   
                [Na, Le, Re] = updateHeadPosition;          
                % get transformation to mean head position fiducials
                dewar2head = bw_getAffineVox2CTF(Na.mean, Le.mean, Re.mean, 1.0);
                % convert positions to mean head pos
                coilPos_head = coilPos_dewar * dewar2head;                 
                headOrigin = (Le.mean + Re.mean) /2.0;
            end
            % structure to hold motion data to save with epoched data
            motionData.units = 'cm';
            motionData.meanHeadMotion = 0.0;
            motionData.meanSensorMotion = 0.0;
            motionData.headMotion = [];
            motionData.sensorMotion = [];
            motionData.motionThreshold = motionThreshold;
            motionData.useMeanHeadPosition = useMeanHeadPosition;
            motionData.motionTrialsRejected = 0;
        end

        % filter expanded epoch to minimize end effects - was not
        % applied in version 3.2
        extraSamples = 0;
        if (filterData || lineFilterData) && useExtraSamples
            extraSamples = round(epochSamples/2);
            epochSamples = epochSamples + (extraSamples * 2);
        end                 

        channelRejectNo = round(numTrials * channelRejectThreshold);

        % scan the data ...
        for i=1:numTrials

            s = sprintf('Scanning epoch %d of %d', i, numTrials);
            waitbar(i/numTrials,wbh,s);

            if getappdata(wbh,'canceling')
                delete(wbh);   
                fprintf('*** trial scan cancelled ***\n');
                return;
            end

            latency = latencyList(i) + latencyCorrection;

            %%%% bug fix vers3.0beta wasn't checking for out of range at beginning of data
            startSample = round( (latency+epochWindow(1)) * sampleRate ) - extraSamples;

            if (startSample < 0) || (startSample + epochSamples > data_params.totalSamples)
                fprintf('... warning epoch %d out of range\n', i);
                continue;
            end
            %%%%

            % get segment of data...
            [~,NAME,EXT] = fileparts(loadfull);
            if strcmp(EXT,'.con')
                tmp_data = getYkgwData(loadfull, startSample, epochSamples);    
            elseif strcmp(EXT,'.ds')
                % transpose since bw_getCTFData returns [nsamples x nchannels]                
                tmp_data = bw_getCTFData(loadfull, startSample, epochSamples)';
            end

            if hasCHL                    
                % get head position for this trial              
                [thisNa, thisLe, thisRe] = bw_getCTFHeadPosition(loadfull, startSample, epochSamples );

                % add tracking of head origin for each trial
                thisHeadOrigin = (thisLe + thisRe) /2;
                headMotion = norm( headOrigin - thisHeadOrigin );
            end       

            sensorMotion = 0.0;               
            channelCount = 0;
            isBadTrial = 0;
            
            allSensorMotion = 0.0; % Anton - initialising variables to be appended to the head motion arrays regardless of whether they were rejected
            allHeadMotion = headMotion;
            allChannelCount = 0;
            

            for j=1:size(channelNames,1)
                if useSelectedChannels && isempty(find( selectedChannels==j,1) )
                    continue;
                end                

                % don't check bad channels!     
                if validChan(j) == 0
                    continue;
                end

                trial = tmp_data(j,:);
                if filterData
                    % just filter segment without extra samples for now...
                    y = bw_filter(trial, data_params.sampleRate, bandpass); 
                    trial = y;                   
                end

                if lineFilterData == 1   
                    f1 = -lineFilterWidth;
                    f2 = lineFilterWidth;
                    for n=1:4   % remove fundamental and 1st 3 harmonics
                        f1 = f1 + lineFilterFreq;
                        f2 = f2 + lineFilterFreq;
                        if f2 < data_params.sampleRate / 2.0
                            % just filter segment without extra samples for now...
                            y = bw_filter(trial, data_params.sampleRate, [f1 f2],4,1,1); 
                            trial = y;                   
                        end
                    end
                end

                % truncate extra samples before checking for artifacts
                trial = trial(1+extraSamples:end-extraSamples);

                % bug fix, this wasn't removing offset from trial array  in 3.1 !! 
                if removeOffset
                    offset = mean( trial );
                    trial = trial - offset;
                end

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % check for peak to peak artifacts

                if exclude_BadTrials
                    peakToPeak = abs( max(trial) - min(trial) );
                    if (peakToPeak > peakThreshold)
                        badTrialFlags(i) = 1;   
                        fprintf('peak-to-peak threshold exceeded in channel %s (epoch %d, p-p = %g picoTesla)\n', channelNames(j,:), i, peakToPeak*1e12);
                        isBadTrial = 1;
                    end

                    % look for flat channels in Neuromag data...
                    if (peakToPeak == 0)
                        badTrialFlags(i) = 1;   
                        fprintf('** excluding flat channel %s (epoch %d, p-p  value = %g picoTesla)\n', channelNames(j,:), i, peakToPeak*1e12);
                        isBadTrial = 1;
                    end

                end

                % look for resets as large jump within one time
                % sample
                if exclude_Resets && ~isBadTrial
                    peakDiff = max(abs( diff(trial)) );
                    if (peakDiff > resetThreshold)
                        badTrialFlags(i) = 1;   
                        fprintf('** Reset detected in channel %s (epoch %d, max diff = %g picoTesla)\n', channelNames(j,:), i, peakDiff *1e12);
                        isBadTrial = 1;
                    end                  
                end

                % keep track of how many trials are rejected for each
                % channel - applies to p-p check only

                if isBadTrial
                    badChannelTable(j,i) = 1;  % sets this(channel,trial) = bad
                end


                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % compute movement for this channel 
                % relative to original head position

                % new in 3.4 - don't include this trial in motion check if this trial
                % is going to be excluded
                if hasCHL % Anton - moved && ~isBadTrial a few lines down because we want to update allSensorMotion and allChannelCount even if they are bad trials

                    % get this channel position in dewar coords and
                    % transform to the current head position                       
                    dewarPos = coilPos_dewar(j,:);                       
                    dewar2head = bw_getAffineVox2CTF(thisNa, thisLe, thisRe, 1.0);
                    thisHeadPos = dewarPos * dewar2head;
                    rmsErr = norm( thisHeadPos(1:3) - coilPos_head(j,1:3));

                    if ~isBadTrial % Anton
                    
                    % sum RMS sensor motion
                    sensorMotion = sensorMotion + rmsErr;
                    % 3.4 - this should be inside this loop since trial
                    % may now be skipped
                    channelCount = channelCount + 1;  % number of channels that have been checked for head motion
                    
                    end
                    allSensorMotion = allSensorMotion + rmsErr; % Anton - copied the same calculation above, except these are read even if the trial is bad.
                    allChannelCount = allChannelCount + 1;
                    
                end

            end % for j channels

            if hasCHL % Anton - Appending the motion values to arrays even if trials are bad
                allSensorMotion = allSensorMotion / allChannelCount;
                sensorMotionList(i) = allSensorMotion;
                headMotionList(i) = allHeadMotion;
            end
                
            if hasCHL && ~isBadTrial
                sensorMotion = sensorMotion / channelCount; % average sensor motion over channels
                if exclude_HeadMotion && sensorMotion > motionThreshold  
                    badTrialFlags(i) = 1;   
                    fprintf('mean sensor movement threshold exceeded: for epoch %d, mean sensor motion = %g cm, head Motion (origin) = %g cm\n', i, sensorMotion, headMotion);
                    motionData.motionTrialsRejected = motionData.motionTrialsRejected + 1;
                else
                    % save motion data for non-rejected trials to be saved with data
                    motionData.sensorMotion(end+1) = sensorMotion;
                    motionData.headMotion(end+1) = headMotion;
                    motionData.meanSensorMotion = motionData.meanSensorMotion + sensorMotion;        
                    motionData.meanHeadMotion = motionData.meanHeadMotion + headMotion;        
                end
            end


        end % for i trials

        % correct mean motion for number of non-rejected trials
        motionData.meanHeadMotion = motionData.meanHeadMotion / length(motionData.headMotion);
        motionData.meanSensorMotion = motionData.meanSensorMotion / length(motionData.sensorMotion);

        fprintf('mean sensor motion = %g cm\n', motionData.meanSensorMotion) 
        fprintf('mean head origin movement =  %g cm\n', motionData.meanHeadMotion) 

        delete(wbh);

        clear tmp_data;

        idx = find(badTrialFlags == 1);
        badTrialCount = length(idx);

        if badTrialCount > 0
            % check for bad channels
            badChannelCount = 0; 
            for j=1:numChannels 
                idx = find(badChannelTable(j,:) == 1);            
                if length(idx) > channelRejectNo
                    badChannelCount = badChannelCount + 1;
                    badChannelList(badChannelCount) = j;
                end
            end
        end
        
        % Add each subject's data to the growing matrix of all the
        % subjects' data
        latencyArray(k,1:numTrials) = latencyList;
        headMotionArray(k,1:end) = headMotionList;
        sensorMotionArray(k,1:end) = sensorMotionList;
        badTrialArray(k,1:numTrials) = badTrialFlags;
        namesArray{k} = NAME;
        
        if plotAll == 0
            break
        end
    end
    
    % Anton - added new function, showHeadMotionPlot to plot a time series and histogram representing a subject's head motion data
    bw_headMotionPlot(latencyArray,headMotionArray,sensorMotionArray,badTrialArray,namesArray,motionData.motionThreshold);
    
    % After running the headMotionPlot function, the currently loaded
    % dataset will be the last one in the list, regardless of what is
    % actually selected in the dropdown. To prevent the user from having to
    % manually reselect their desired dataset, this will ensure that the
    % one they previously selected is reloaded automatically.
    loadCTFData(menu_select); 
end 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Anton Hung, August 2021: End of headMotionPlot code in bw_import_data.
% There is an additional (new) file called bw_headMotionPlot which creates 
% the figures.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
function [Na, Le, Re] = updateHeadPosition

    if useMeanHeadPosition && hasCHL
        [Na, Le, Re] = getMeanHeadPosition;
        fprintf('Computed Fiducials in Device Coordinates (cm) - mean over epochs\n');
        fprintf('Nasion (mean)  X = %8.4f    Y = %8.4f     Z = %8.4f\n', Na.mean(1:3) );
        fprintf('Nasion (s.d)   X = %8.4f    Y = %8.4f     Z = %8.4f\n', Na.std(1:3) );
        fprintf('Nasion (range) X = %8.4f    Y = %8.4f     Z = %8.4f (rms = %8.4f)\n\n', Na.range(1:3), norm(Na.range) );

        fprintf('Left Ear (mean)  X = %8.4f    Y = %8.4f     Z = %8.4f\n', Le.mean(1:3) );
        fprintf('Left Ear (s.d)   X = %8.4f    Y = %8.4f     Z = %8.4f\n', Le.std(1:3) );
        fprintf('Left Ear (range) X = %8.4f    Y = %8.4f     Z = %8.4f (rms = %8.4f)\n\n', Le.range(1:3), norm(Le.range) );

        fprintf('Right Ear (mean)  X = %8.4f    Y = %8.4f     Z = %8.4f\n', Re.mean(1:3) );
        fprintf('Right Ear (s.d)   X = %8.4f    Y = %8.4f     Z = %8.4f\n', Re.std(1:3) );
        fprintf('Right Ear (range) X = %8.4f    Y = %8.4f     Z = %8.4f (rms = %8.4f)\n\n', Re.range(1:3), norm(Re.range) );

        % update dialog text
        s = sprintf('Fiducials in Device Coordinates (cm) - mean over epochs');
        set(Fid_text, 'string', s, 'foregroundcolor','black');
        s = sprintf('Nasion:        X = %8.4f    Y = %8.4f     Z = %8.4f', Na.mean(1:3) );
        set(nasion_txt,'string',s,'foregroundcolor','red');
        s = sprintf('Left ear:     X = %8.4f    Y = %8.4f     Z = %8.4f', Le.mean(1:3) );
        set(left_ear_txt,'string',s, 'foregroundcolor','red');
        s = sprintf('Right Ear :     X = %8.4f    Y = %8.4f     Z = %8.4f', Re.mean(1:3));
        set(right_ear_txt,'string',s, 'foregroundcolor','red');  
    else
        Na = fid_pts_dewar.na;
        Le = fid_pts_dewar.le;
        Re = fid_pts_dewar.re;
        
        % update dialog
        s = sprintf('Fiducials in Device Coordinates (cm)');
        set(Fid_text, 'string', s, 'foregroundcolor','black');
        s = sprintf('Nasion:        X = %8.4f    Y = %8.4f     Z = %8.4f', fid_pts_dewar.na(1:3) );
        set(nasion_txt,'string',s,'foregroundcolor','black');
        s = sprintf('Left ear:     X = %8.4f    Y = %8.4f     Z = %8.4f', fid_pts_dewar.le(1:3) );
        set(left_ear_txt,'string',s, 'foregroundcolor','black');
        s = sprintf('Right Ear :     X = %8.4f    Y = %8.4f     Z = %8.4f', fid_pts_dewar.re(1:3));
        set(right_ear_txt,'string',s, 'foregroundcolor','black');  
    end

end


%surrounding rectangle    
annotation('rectangle','position',[0.01 0.09 0.4 0.3],'edgecolor','blue');  

    % set initial state
clearSettings;
    
 
function trial_inc_callback(~,~)
    if ~epochFlag
        return;
    end
    if (currentTrialNo < size(latencyList,1))         
        currentTrialNo = currentTrialNo + 1;
        drawTrial;
    end
end

function trial_dec_callback(~,~)
    if (currentTrialNo > 1)         
        currentTrialNo = currentTrialNo - 1;
        drawTrial;
    end
end

function channel_box_callback(~,~)
    selectedChannels = get(channel_box,'value');
    drawTrial;
end

function lat_box_callback(~,~)
    currentTrialNo = get(lat_box,'value');
    drawTrial;
end

function drawTrial      

    set(0,'CurrentFigure',fh); % make sure we plot to correct window when wait bar is up...

    subplot('Position',[0.57 0.1 0.38 0.25]);
    cla;
    if epochFlag && isempty(latencyList) 
        % clear old plot 
        return;
    end        

    if currentTrialNo > size(latencyList,1) 
        currentTrialNo = 1;
    end

    %subplot(3,2,6);

    trial = [];

    sampleRate = data_params.sampleRate;

    if ~epochFlag
        singleEpochStart = str2double(get(single_epoch_start,'String'));
        singleEpochEnd = str2double(get(single_epoch_end,'String'));
        duration = singleEpochEnd - singleEpochStart;
        epochWindow = [0 duration];
        timeVec = epochWindow(1):1/sampleRate:epochWindow(2);
        epochSamples = length(timeVec);

        latency = singleEpochStart;
        startSample = round( latency * sampleRate );

    else
        epochWindow = [twStart twEnd];
        timeVec = epochWindow(1):1/sampleRate:epochWindow(2);
        epochSamples = length(timeVec);

        latency = latencyList(currentTrialNo) + latencyCorrection;
        startSample = round( (latency+epochWindow(1)) * sampleRate );

        set(lat_box,'value',currentTrialNo);
    end   


    % filter expanded epoch to minimize end effects
    extraSamples = 0;
    if (filterData || lineFilterData) && useExtraSamples
        extraSamples = round(epochSamples/2);
        startSample = startSample - extraSamples;
        epochSamples = epochSamples + (extraSamples * 2);
    end

    % update label even if we don't draw trial...
    
    % get resampled trial samples
    tvec = timeVec(1:downSample:end);
    numRealSamples = length(tvec);
    
    s = sprintf('Epoch: %d: Epoch latency  = %.4f seconds', currentTrialNo, latency);
    set(preview_text,'String',s);


    % check boundary  - out of range trials have been set 
    % to invalid but we can't draw them!  
    if startSample < 0 || startSample + epochSamples > data_params.numSamples
        fprintf('Epoch %d exceeds trial boundaries...\n', currentTrialNo);
        return;             
    end

    if ( epochWindow(2) <= epochWindow(1) )
        fprintf('Epoch end time must be greater than epoch start time...\n');
        return;
    end

    % get segment of data...
    numChannelsToPlot = size(selectedChannels,2);

    plot_data = zeros(numChannelsToPlot, size(timeVec,2));

    % transpose since bw_getCTFData returns [nsamples x nchannels]
    tmp_data = bw_getCTFData(loadfull, startSample, epochSamples)';

    % filter data
    if filterData
        for k=1:numChannelsToPlot
            trial = tmp_data(selectedChannels(k),:);
            y = bw_filter(trial, data_params.sampleRate, bandpass); 
            tmp_data(selectedChannels(k),:) = y;                   
        end       
    end

    if lineFilterData == 1   
        f1 = -lineFilterWidth;
        f2 = lineFilterWidth;
        for j=1:4   % remove fundamental and 1st 3 harmonics
            f1 = f1 + lineFilterFreq;
            f2 = f2 + lineFilterFreq;
            if f2 < data_params.sampleRate / 2.0
                for k=1:numChannelsToPlot
                    trial = tmp_data(selectedChannels(k),:);
                    y = bw_filter(trial, data_params.sampleRate, [f1 f2],4,1,1); 
                    tmp_data(selectedChannels(k),:) = y;                   
                end   
            end
        end
    end

    if removeOffset
       for k=1:numChannelsToPlot
            offset = mean( tmp_data(selectedChannels(k),:) );
            tmp_data(selectedChannels(k),:) = tmp_data(selectedChannels(k),:) - offset;                  
       end
    end


    hold on;
    for k=1:numChannelsToPlot
        channelNo = selectedChannels(k);

        if validChan(channelNo) == 0 && ~plotBad
            continue;
        end

        % truncate trial to boundaries and scale to picoTesla
        plot_data = tmp_data(channelNo,1+extraSamples:end-extraSamples) * 1.0e12;            

        pcol = 'blue';
        if (epochFlag && validFlags(currentTrialNo) == 0) || validChan(channelNo) == 0
            pcol = 'red';             
        end           

        plot(timeVec(1:downSample:end), plot_data(1:downSample:end), 'color',pcol);
    end
    hold off;

    xlabel('Time (sec)');
    ylabel('picoTesla');

%     clear tmp_data;

end

function load_params_callback(~,~)

   if isempty(dsList) 
       return;
   end

   [name,path,~] = uigetfile('*.mat','Select parameter file:');
    if isequal(name,0)
        return;
    end
    filename = fullfile(path,name);      

    epoch_params = load(filename);

    epochFlag = epoch_params.epochFlag;
    latencyCorrection = epoch_params.latencyCorrection;
    useMinSep = epoch_params.useMinSep;
    minSep = epoch_params.minSep;
    twStart = epoch_params.epochWindow(1);
    twEnd = epoch_params.epochWindow(2);

    eventFile = epoch_params.eventFile;
    eventName = epoch_params.eventName;

    % preprocesssing
    filterData = epoch_params.filterData;
    lineFilterData = epoch_params.lineFilterData;
    lineFilterFreq = epoch_params.lineFilterFreq;
    bandpass = epoch_params.bandpass;
    useExtraSamples = epoch_params.useExtraSamples;
    removeOffset = epoch_params.removeOffset;
    downSample = epoch_params.downSample;

    % needed to automatically scan trials      
    useMeanHeadPosition = epoch_params.useMeanHeadPosition;
    exclude_HeadMotion = epoch_params.exclude_HeadMotion;
    motionThreshold = epoch_params.motionThreshold;  
    exclude_BadTrials = epoch_params.exclude_BadTrials;
    peakThreshold = epoch_params.peakThreshold;
    exclude_Resets = epoch_params.exclude_Resets;
    resetThreshold = epoch_params.resetThreshold;
    
    exclude_BadChannels = epoch_params.exclude_BadChannels;
    channelRejectThreshold = epoch_params.channelRejectThreshold;

    useSelectedChannels = epoch_params.useSelectedChannels;
    selectedChannels = epoch_params.selectedChannels;  

    save_average = epoch_params.save_average;
    deidentifyData = epoch_params.deidentifyData;
    channelNames = epoch_params.channelNames;
    validChan = epoch_params.validChan;

    % update GUI

    set(tw_start,'string',twStart);
    set(tw_end,'string',twEnd);
    set(latency_correct_edit,'string',latencyCorrection);
    set(filter_data_check,'value',filterData);
    if filterData || lineFilterData
        set(filt_hi_pass,'enable','on');
        set(filt_low_pass,'enable','on');
        set(extra_samples_check,'enable','on');

    else
        set(filt_hi_pass,'enable','off');
        set(filt_low_pass,'enable','off');
        set(extra_samples_check,'enable','off');
    end

    set(filt_hi_pass,'string',bandpass(1) );
    set(filt_low_pass,'string',bandpass(2) );
    set(extra_samples_check,'value',useExtraSamples );
    set(lineFilter_data_check, 'value',lineFilterData);
    if lineFilterFreq == 60 
        set(radio_60Hz,'value',1);
        set(radio_50Hz,'value',0);
    else
        set(radio_60Hz,'value',0);
        set(radio_50Hz,'value',1);
    end


    set(selected_only_check, 'value',useSelectedChannels);
    set(channel_box, 'value',selectedChannels);

    set(save_average_check,'value',save_average );
    set(deidentify_check,'value',deidentifyData );

    % epoch rejection
    set(peakToPeak_check,'value',exclude_BadTrials );
    set(reset_check,'value',exclude_Resets );
    set(head_motion_check,'value',exclude_HeadMotion );
    set(use_mean_position_check,'value',useMeanHeadPosition );
    set(peakThreshold_edit,'string',peakThreshold * 1e12 );
    set(resetThreshold_edit,'string',resetThreshold * 1e12 );
    set(motionThreshold_edit,'string',motionThreshold );
    set(bad_channel_check,'value',exclude_BadChannels );
    set(badChannel_edit,'string',channelRejectThreshold * 100.0);

    updateEpochFields;

    % set sample rate popup
    updateSamples;  % updates sampleRates
    sampleRate = data_params.sampleRate / downSample;

    idx = find(sampleRate == sampleRates);
    if ~isempty(idx)
        set(sample_popup,'value',idx)
    end

    loadCTFData(1);


end

function save_params_callback(~,~)

    [name,path,~] = uiputfile('*.mat','Save current epoch parameters in file:');
    if isequal(name,0)
        return;
    end
    saveName = fullfile(path,name);      
    epoch_params = getCurrentParams;

    save(saveName, '-struct', 'epoch_params');

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create dataset
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% new version - put all epoching params into struct for batch processing

    function create_ds_callback(~,~)
         
        numDatasets = size(dsList,2);
                   
        if isempty(savePath)
           savePath = get(savePathText,'string');
        end
        saveNameFull = strcat(savePath,filesep,saveDsName);
        
        if numDatasets == 1
            s = sprintf('Create dataset %s ?', saveNameFull);
            response = questdlg(s,'BrainWave','Yes','No','Yes');
            if strcmp(response,'No')
                return;
            end
            epoch_params = getCurrentParams;       
            createDataset(loadfull, saveNameFull, epoch_params);
        else
            s = sprintf('Generate %d datasets with these parameters?', numDatasets);
            response = questdlg(s,'BrainWave','Yes','No','Yes');
            if strcmp(response,'No')
                return;
            else                
                % check that files won't be overwritten...
                for k=1:numDatasets
                    dsName = char(dsList(:,k));
                    saveName = getSaveName(dsName);
                    if k > 1
                        if strcmp(saveName,oldSaveName) == 1
                            beep;
                            errordlg('There are duplicate output file names (files will be overwritten) ... ');
                            return;
                        end
                    end
                    oldSaveName = saveName;
                end
                              
                wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
                setappdata(wbh,'canceling',0)
                for k=1:numDatasets
                    if getappdata(wbh,'canceling')
                        delete(wbh);   
                        fprintf('*** cancelled ***\n');
                        return;
                    end                         
                    loadCTFData(k);     % should load new event file and update save name...
                    epoch_params = getCurrentParams;   % ** important ** 3.2 bug fix .. have to reset params list after reading new file     
                    set(dsList_popup,'value',k);
                    waitbar(k/numDatasets,wbh,sprintf('generating data for dataset %d...', k) );
                    
                    saveNameFull = strcat(savePath,filesep,saveDsName);              
                    createDataset(loadfull, saveNameFull, epoch_params);                    
                end
                delete(wbh);
                
            end
        end        
        
    end
 
    function add_to_batch_callback(~,~)
    
        if ~batchJobs.enabled
            return;
        end
        
        numDatasets = size(dsList,2);
        
        s = sprintf('Add %d datasets with current epoching parameters to batch', numDatasets);
        response = questdlg(s,'BrainWave','Yes','No','Yes');
        if strcmp(response,'No')
            return;
        end
       
        if isempty(savePath)
           savePath = get(savePathText,'string');
        end
        
        % check that files won't be overwritten...
        for k=1:numDatasets
            dsName = char(dsList(:,k));
            saveName = getSaveName(dsName);
            saveNameFull = strcat(savePath,filesep,saveName);

            saveList(k) = cellstr(saveNameFull);
            
            if k > 1
                if strcmp(saveNameFull,oldSaveName) == 1
                    beep;
                    errordlg('There are duplicate output file names (files will be overwritten) ... ');
                    return;
                end
                
                % ** should check here with all save names in batch....??
            end            
            oldSaveName = saveNameFull;
        end
         
        epoch_params = getCurrentParams;       
 
        fprintf('Added %d datasets to batch job # %d\n', numDatasets, batchJobs.numJobs+1);
        batchJobs.numJobs = batchJobs.numJobs + 1;
        batchJobs.processes{batchJobs.numJobs}.saveList = saveList;
        batchJobs.processes{batchJobs.numJobs}.rawList = dsList;                      
        batchJobs.processes{batchJobs.numJobs}.epoch_params = epoch_params;

        s = sprintf('Close Batch (%d jobs)', batchJobs.numJobs);
        set(STOP_BATCH,'label',s);           
        
    end

 function params = getCurrentParams

    params = [];

    epoch_params.epochFlag = epochFlag;
    if ~epochFlag

        epoch_params.singleEpochStart = str2double(get(single_epoch_start,'String'));
        epoch_params.singleEpochEnd = str2double(get(single_epoch_end,'String'));

        maxTime = data_params.numSamples / data_params.sampleRate;
        minTime = 0;

        % convert start end to latency, epoch times..
        duration = singleEpochEnd - singleEpochStart;

        if (duration < 0) 
            fprintf('Epoch end time must be greater than start time...\n');
            return;
        end     
        if (singleEpochStart < minTime) 
            fprintf('Start time must be greater than zero\n');
            return;
        end  

        if (singleEpochEnd > maxTime) 
            fprintf('Epoch end time exceeds data range..\n');
            return;
        end  


        epoch_params.validLat = singleEpochStart;
        epoch_params.epochWindow = [0 duration];
        epoch_params.eventFile = [];
        epoch_params.eventName = [];
        epoch_params.latencyList = []; 

    else
        epoch_params.eventFile = eventFile;
        epoch_params.eventName = eventName;

        epoch_params.epochWindow = [twStart twEnd];
        epoch_params.latencyList = latencyList; 

        if latencyCorrection ~= 0.0
            fprintf('*** adjusting all latencies by offset of %.5f seconds *** \n', latencyCorrection);
        end

        epoch_params.latencyCorrection = latencyCorrection;
        epoch_params.minSep = minSep;
        epoch_params.useMinSep = useMinSep;

    end

    if filterData
        if bandpass(2) > data_params.sampleRate / 2
            fprintf('Selected lowpass filter setting is too high for sample rate...');
            return;
        end
    end

    epoch_params.filterData = filterData;
    epoch_params.bandpass = bandpass;            
    epoch_params.lineFilterData = lineFilterData;
    epoch_params.lineFilterFreq = lineFilterFreq;
    epoch_params.removeOffset = removeOffset;
    epoch_params.downSample = downSample;
    epoch_params.useExtraSamples = useExtraSamples;

    epoch_params.save_average = save_average;
    epoch_params.deidentifyData = deidentifyData;
    epoch_params.useMeanHeadPosition = useMeanHeadPosition;
    epoch_params.fid_pts_dewar = fid_pts_dewar;
    epoch_params.channelNames = channelNames;
    epoch_params.validChan = validChan;

    % add automatic scan trials for batch mode      
    epoch_params.exclude_BadTrials = exclude_BadTrials;
    epoch_params.exclude_HeadMotion = exclude_HeadMotion;
    epoch_params.exclude_Resets = exclude_Resets; %% bug fix
    
    epoch_params.exclude_BadChannels = exclude_BadChannels;
    epoch_params.channelRejectThreshold = channelRejectThreshold;

    epoch_params.data_params = data_params;
    epoch_params.useSelectedChannels = useSelectedChannels;
    epoch_params.selectedChannels = selectedChannels;
    epoch_params.peakThreshold = peakThreshold;
    epoch_params.resetThreshold = resetThreshold;
    epoch_params.motionThreshold = motionThreshold;

    params = epoch_params;  % return valid list

 end

function createDataset(raw_dataName, saveName, epoch_params)

    % need to set all params that scanTrials uses without loading data
    data_params = epoch_params.data_params;

    twStart = epoch_params.epochWindow(1);
    twEnd = epoch_params.epochWindow(2);

    loadfull = raw_dataName;
    channelNames = epoch_params.channelNames;
    validChan = epoch_params.validChan;     
    useSelectedChannels = epoch_params.useSelectedChannels;
    selectedChannels = epoch_params.selectedChannels;

    exclude_BadTrials = epoch_params.exclude_BadTrials;
    peakThreshold = epoch_params.peakThreshold;
    resetThreshold = epoch_params.resetThreshold;
    exclude_HeadMotion = epoch_params.exclude_HeadMotion;
    useMeanHeadPosition = epoch_params.useMeanHeadPosition;
    exclude_Resets = epoch_params.exclude_Resets;
    exclude_BadChannels = epoch_params.exclude_BadChannels;
    channelRejectThreshold = epoch_params.channelRejectThreshold;
    
    fid_pts_dewar = epoch_params.fid_pts_dewar;
    motionThreshold = epoch_params.motionThreshold; 

    lineFilterData = epoch_params.lineFilterData;
    filterData = epoch_params.filterData;
    bandpass = epoch_params.bandpass;            
    useExtraSamples = epoch_params.useExtraSamples;
    downSample = epoch_params.downSample;

    % set all trials good to suppress clear request 

    epochFlag = epoch_params.epochFlag;

    if ~epochFlag
        numEvents = 1;
        numTrials = 1;
        numTrialsRejected = 0;
        badTrialFlags = zeros(numEvents,1);  
        validLat = epoch_params.validLat;
    else
        numEvents = size(epoch_params.latencyList,1);
        badTrialFlags = zeros(numEvents,1);  
        latencyList = epoch_params.latencyList;
        latencyCorrection = epoch_params.latencyCorrection;
        useMinSep = epoch_params.useMinSep;
        minSep = epoch_params.minSep;        

        % sets valid flags so out-of-range etc trials are not scanned
        updateLatencies; 

%         if epoch_params.exclude_BadTrials || epoch_params.exclude_HeadMotion || epoch_params.exclude_Resets
            checkData(1);  % scan data in auto mode
%         end

        % get only valid latencies
        idx = find(validFlags == 1);
        validLat = latencyList(idx) + latencyCorrection;

        % get updated number of trials saved and number rejected      
        numTrials = size(validLat,1);
        idx = find(badTrialFlags == 1);
        numTrialsRejected = length(idx);

        if numTrials < 1
            fprintf('No valid trials to save...\n');
            return;
        end

    end


    if filterData
        filterBW = bandpass;
    else
        filterBW = [];
    end

    % channel selection - revised for auto bad channel detection 
    % for CTF data must pass a cellstr array of badchannel names
    % (rather that list of validchan indices)
    % Version 3.5 - validChan variable may have changed during checkData()
    idx = find(validChan == 0);
    if ~isempty(idx)
        numChannels = length(validChan) - length(idx);
        badChannels = cellstr(epoch_params.channelNames(idx,:));
    else
        numChannels = length(validChan);
        badChannels = {};
    end                      

    if ~lineFilterData 
        lineFilter = 0.0;
    else
        lineFilter = lineFilterFreq;
    end

    % update gui and epoch...

    drawTrial;

    
    fprintf('\n*** Epoching data (%d channels, %d trials) ***\n',numChannels, numTrials);
         
    errorFlag = bw_epochDs(raw_dataName, saveName, validLat, badChannels, epoch_params.epochWindow, ...
        filterBW, lineFilter, epoch_params.downSample, epoch_params.save_average, epoch_params.useExtraSamples, epoch_params.deidentifyData);
    
    if errorFlag == 0
        if epoch_params.useMeanHeadPosition && hasCHL
            % update sensor geometry in saved dataset to reflect mean head position
            [Na, Le, Re] = updateHeadPosition;  % get mean fiducials - only valid when useMean enabled

            % apply new head position to new dataset      
            bw_CTFChangeHeadPos(saveName, Na.mean, Le.mean, Re.mean); 

            epoch_params.headPosition = [Na, Le, Re]; % Anton 2021/06/16 - adding head position to epoch parameters
        end              
        
        % write a modified MarkerFile 
        markerFileName = strcat(loadfull,filesep,'MarkerFile.mrk');

        if exist(markerFileName,'file') & validLat > 1

            fprintf('writing modified marker information to %s\n', saveName);
            [markerNames, markerData] = bw_readCTFMarkerFile( markerFileName );

            trig = [];
            count = 0;
            for k=1:numel(markerData)
                markerName = markerNames{k};
                markerTimes = markerData{k};
                % ** make sure marker latencies match validLat which are "corrected" 
                markerLatencies = markerTimes(:,2) + latencyCorrection; 
                
                % for each trial check and marker latency
                % check if is in epoch window and write new relative
                % latency for that trial                
                trials = [];
                latencies = [];
                for trial=1:numel(validLat)  % for this trial
                    for j=1:numel(markerLatencies)      % check all event marker times
                        t = markerLatencies(j) - validLat(trial); % convert to latency relative to time zero
                        if (t > epoch_params.epochWindow(1) & t < epoch_params.epochWindow(2))
                            trials(end+1) = trial-1;  % CTF trial numbering in Markerfile.mrk start at zero!
                            latencies(end+1) = t;
                        end
                    end
                end               

                if ~isempty(trials)
                    count = count + 1;
                    trig(count).ch_name = markerName;
                    trig(count).trials = trials;
                    trig(count).latencies = latencies;
                end

            end   
            newMarkerName = bw_writeNewMarkerFile(saveName, trig);
            excelFile = strrep(newMarkerName,'.mrk','.csv');
            bw_markerFile2Excel(newMarkerName, excelFile)

        end       

        trialLatName = sprintf('%s%s%s',saveName,filesep,'epoch_latencies.txt');
        fprintf('Saving epoch latencies in %s \n', trialLatName);

        [fid, errMsg] = fopen(trialLatName, 'w');
        if fid == -1
            fprintf('*** Error opening file %s [%s] ***\n', trialLatName, errMsg);
        else
            fprintf(fid,'%.5f\n', validLat);
            fclose(fid);  

            % don't try to save .mat file if file open failed
            epochName = sprintf('%s%s%s',saveName,filesep,'epoch_parameters.mat');
            fprintf('Saving epoching parameters in %s \n', epochName);            
            epoch_params.numTrials = numTrials;
            epoch_params.numTrialsRejected = numTrialsRejected;
            save(epochName, '-struct', 'epoch_params');
            
            % save motion checking data
            if hasCHL && ~isempty(motionData)
                motionName = sprintf('%s%s%s',saveName,filesep,'head_motion.mat');
                fprintf('Saving head motion data in %s \n', motionName);            
                save(motionName, '-struct', 'motionData');
            end
            
        end
        
    else
        fprintf('*** Error occurred epoching dataset %s ***\n', raw_dataName);
    end
    
    % set channel list back to original selection
    % this will only be different if auto detecting bad channels...
    validChan = epoch_params.validChan;  


end  % epoch data..

    % batch setup
    function START_BATCH_CALLBACK(~,~)
        
        s = sprintf('Start a new batch job?');
        response = questdlg(s,'BrainWave','Yes','No','Yes');      
        if strcmp(response,'No')      
            return;
        end
        
        batchJobs.enabled = true;
        batchJobs.numJobs = 0;
        batchJobs.processes = {};
       
        set(addToBatchButton,'enable','on')  
        set(createButton,'enable','off')  
                
        set(START_BATCH,'enable','off')            
        set(STOP_BATCH,'enable','on')                
        set(STOP_BATCH,'label','Close Batch');               
        set(CANCEL_BATCH,'enable','off')            
    end

    function STOP_BATCH_CALLBACK(~,~)
        
        if batchJobs.numJobs > 0         
            s = sprintf('Stop adding to current batch?');
            response = questdlg(s,'BrainWave','Yes','No','Yes');      
            if strcmp(response,'No')      
                return;
            end
            
            batchJobs.enabled = false;
            set(addToBatchButton,'enable','off')  
            set(createButton,'enable','on')  
            set(STOP_BATCH,'enable','off')            
            set(START_BATCH,'enable','off')            
            set(RUN_BATCH,'enable','on')        
            set(CANCEL_BATCH,'enable','on')        
            
            numJobs = batchJobs.numJobs;
            s = sprintf('%d jobs in batch.  Do you want to run these now?', numJobs);
            response = questdlg(s,'BrainWave','Yes','No','Yes');      
            if strcmp(response,'Yes')             
               executeBatch
            end
        else
            set(addToBatchButton,'enable','off')  
            set(createButton,'enable','on')  
            set(START_BATCH,'enable','on')        
            set(STOP_BATCH,'enable','off')            
            set(RUN_BATCH,'enable','off')            
            set(CANCEL_BATCH,'enable','off')            
        end            
    end

    function CANCEL_BATCH_CALLBACK(~,~)
        if ~isempty(batchJobs)
            numJobs = batchJobs.numJobs;
            s = sprintf('Cancel %d batch jobs?', numJobs);
            response = questdlg(s,'BrainWave','Yes','No','Yes');      
            if strcmp(response,'No')      
                return;
            end

            batchJobs.enabled = false;
            batchJobs.numJobs = 0;
            batchJobs.processes = {};
            set(addToBatchButton,'enable','off')  
            set(createButton,'enable','on')  
            set(START_BATCH,'enable','on')            
            set(RUN_BATCH,'enable','off')        
            set(STOP_BATCH,'enable','off')   
            set(STOP_BATCH,'label','Close Batch');                  
            set(CANCEL_BATCH,'enable','off')            
            
        end       
    end

    function RUN_BATCH_CALLBACK(~,~)

        if isempty(batchJobs)
            return;
        end
        
        numJobs = batchJobs.numJobs;
        s = sprintf('%d jobs in batch.  Do you want to run these now?', numJobs);
        response = questdlg(s,'BrainWave','Yes','No','Yes');      
        if strcmp(response,'No')      
            return;
        end   
        executeBatch;
    end

    function executeBatch
        
        if isempty(batchJobs)
            return;
        end

          % first check that somes files won't be overwritten...
         totalCount = 1;
         numJobs = batchJobs.numJobs;
         for i=1:numJobs
            saveList = batchJobs.processes{i}.saveList;
            for k=1:size(saveList,2)              
                saveName = char(saveList(:,k));
                if totalCount > 1
                    if strcmp(saveName,oldSaveName) == 1
                        beep;
                        errordlg('There are duplicate output file names (files will be overwritten) ... ');
                        return;
                    end
                else
                    oldSaveName = saveName;
                end
            end
         end
        % end check...

        tic
        for i=1:numJobs
            fprintf('\n\n*********** Running job %d ***********\n\n', i);

            dsList = batchJobs.processes{i}.rawList;
            saveList = batchJobs.processes{i}.saveList;
            epoch_params = batchJobs.processes{i}.epoch_params;

            numFiles = size(dsList,2);

            for k=1:numFiles
                dsName = char(dsList(:,k));
                saveDsName = char(saveList(:,k));
                set(dsList_popup,'value',k);
                % ** D. Cheyne bug fix for batch mode - have to set the
                % correct eventName and file for this list and then 
                % load the data to update the event list!
                eventFile = epoch_params.eventFile;     %new v3.4
                eventName = epoch_params.eventName;     %new v3.4
                loadCTFData(k);                         %new v3.4
                % although latencyList is now correct, createDataset
                % will still try to read latencies from epoch_params
                epoch_params.latencyList = latencyList;
                createDataset(dsName, saveDsName, epoch_params);                    
            end            

        end

        fprintf('\n\n*********** finished batch jobs ***********\n\n', i);
        toc

        batchJobs.enabled = false;
        batchJobs.numJobs = 0;
        batchJobs.processes = {};
        set(START_BATCH,'enable','on')            
        set(RUN_BATCH,'enable','off')        
        set(STOP_BATCH,'enable','off')   
        set(STOP_BATCH,'label','Close Batch');              
        set(CANCEL_BATCH,'enable','off')            
    end
        
    


function [Na, Le, Re] = getMeanHeadPosition

    fprintf('Calculating mean head position...\n');   
    Na.mean = [0 0 0];
    Na.std = [0 0 0];
    Na.range = [0 0 0];

    Le.mean = [0 0 0];
    Le.std = [0 0 0];
    Le.range = [0 0 0];

    Re.mean = [0 0 0];
    Re.std = [0 0 0];
    Re.range = [0 0 0];   
    % include option to get mean head position for a single epoch
    if ~epochFlag
        singleEpochStart = str2double(get(single_epoch_start,'String'));
        singleEpochEnd = str2double(get(single_epoch_end,'String'));

        maxTime = data_params.numSamples / data_params.sampleRate;
        minTime = 0;
        if (singleEpochStart < minTime) 
            fprintf('** Start time must be greater than zero\n');
            return;
        end  

        if (singleEpochEnd > maxTime) 
            fprintf('** Epoch end time exceeds data range..\n');
            return;
        end  

        startSample = round( singleEpochStart * data_params.sampleRate );
        endSample = round( singleEpochEnd * data_params.sampleRate );
        epochSamples = endSample - startSample + 1;               

        [na, le, re] = bw_getCTFHeadPosition(loadfull, startSample, epochSamples );

        Na.mean = na;
        Le.mean = le;
        Re.mean = re;

    else
        if isempty(latencyList)
            fprintf('Cannot update head position... no epochs defined...\n');
            return;
        end

        numTrials = size(latencyList,1);
        N = zeros(numTrials,3);
        L = zeros(numTrials,3);
        R = zeros(numTrials,3);       

        epochWindow = [twStart twEnd];
        timeVec = epochWindow(1):1/data_params.sampleRate:epochWindow(2);
        epochSamples = length(timeVec);

        wbh = waitbar(0,'Computing mean head position...');

        trialCount = 0;
        for i=1:numTrials

            % exclude bad trials - BUG fix Ver3.0beta 
            % was not checking validFlags for out of range trials
            if badTrialFlags(i) == 1 || validFlags(i) == 0
                fprintf('Excluding epoch %d...\n', i);
                continue;
            end

            s = sprintf('Updating head position .. epoch %d of %d', i, numTrials);
            waitbar(i/numTrials,wbh,s);

            latency = latencyList(i) + latencyCorrection;
            startSample = round( (latency+epochWindow(1)) * data_params.sampleRate );

            if (startSample + epochSamples > data_params.totalSamples)
                fprintf('... warning epoch %d exceeded data range\n', i);
                continue;
            end

            if (startSample < 1)
                fprintf('... negative start sample for epoch %d \n', i);
                continue;
            end

            [na, le, re] = bw_getCTFHeadPosition(loadfull, startSample, epochSamples );

            trialCount = trialCount + 1;

            N(trialCount,1:3) = na;
            L(trialCount,1:3) = le;
            R(trialCount,1:3) = re;


        end

        % delete empty cells
        
        N = N(1:trialCount,:);
        L = L(1:trialCount,:);
        R = R(1:trialCount,:);

        Na.mean = mean(N,1);
        Na.std = std(N,1);
        Na.range = max(N) -  min(N);
        
        Le.mean = mean(L,1);
        Le.std = std(L,1);
        Le.range = max(L) - min(L);

        Re.mean = mean(R,1);
        Re.std = std(R,1);
        Re.range = max(R) - min(R);                     

        delete(wbh);      

    end

end

function updateLatencies

    strvrsn={};
    for n=1:size(channelNames,1)
        if validChan(n) == 1
            strvrsn{n,1}=sprintf('%s', channelNames(n,:));
        else
            strvrsn{n,1}=sprintf('**%s',channelNames(n,:));
        end            
        set(channel_box,'String',strvrsn);
        
    end
    
    if ~epochFlag
        return;
    end
    
    % update epoch windows..
        
    % set all valid
    validFlags = ones(size(latencyList,1),1);
    
    % must check for windows beyond data boundaries            
    maxTime = data_params.numSamples / data_params.sampleRate;
    minTime = 0;
    
    eEnd = twEnd;
    eStart = twStart;
    
    % if filter on the valid window epochs are larger...
    % ** bug fix in version 2.21 was not calculating this correctly
    
    if (filterData || lineFilterData) && useExtraSamples
        preFilterTime  = (twEnd - twStart) / 2.0;
        eEnd = eEnd + preFilterTime;
        eStart = eStart - preFilterTime;
    end
             
    % check for out of bounds
    for n=1:size(latencyList,1)
        latency = latencyList(n,1) + latencyCorrection;
        endTime = latency + eEnd;
        startTime = latency + eStart;
        if (startTime < minTime) || (endTime > maxTime)
            fprintf('trial %d exceds trial boundary\n', n);
            validFlags(n) = 0;
        end
    end

    % check for trial overlap
    if useMinSep
        for n=1:size(latencyList,1)-1
            latency = latencyList(n,1) + latencyCorrection;
            latency2 = latencyList(n+1,1) + latencyCorrection;
            if (latency + twEnd + minSep) >= (latency2 + twStart)
                validFlags(n) = 0;
                validFlags(n+1) = 0;
            end
        end
    end

    % check for bad trials 
    if exclude_BadTrials || exclude_HeadMotion || exclude_Resets
        for n=1:size(latencyList,1)
            if badTrialFlags(n) == 1
                validFlags(n) = 0;
            end
        end
    end
    
   strvrsn={};

    % build list
    totalEpochs = size(latencyList,1);
    currentTrialNo = totalEpochs;
    for n=1:totalEpochs
        if validFlags(n) == 1
            strvrsn{n,1}=sprintf('%.5f', latencyList(n,1));
            if currentTrialNo == totalEpochs
                currentTrialNo = n;
            end
        else
            strvrsn{n,1}=sprintf('**%.5f',latencyList(n,1));
        end
    end
    set(lat_box,'string',strvrsn);
    % always plot a good trial
    set(lat_box,'value',currentTrialNo);

    idx = find(validFlags == 1);
    numEpochs = size(idx,1);
    tstr = sprintf('Epoch Latencies (%d of %d)', numEpochs, totalEpochs);
    set(lat_text,'string',tstr);
   
    s = sprintf('Event: (%s, %s)',eventFile, eventName );
    set(latency_file_label,'String',s);

    set(trialInc,'enable','on');
    set(trialDec,'enable','on');
    
end

function [conFile, markerFile, eventFile] = import_KIT_files

    conFile = [];
    markerFile = [];
    eventFile = [];

    d = figure('Position',[500 800 1000 300],'Name','Import KIT Data', ...
        'numberTitle','off','menubar','none');
      
    if ispc
        movegui(d,'center')
    end
    
    uicontrol('Style','text',...
        'fontsize',12,...
        'HorizontalAlignment','left',...
        'units', 'normalized',...
        'Position',[0.02 0.77 0.4 0.1],...
        'String','Select KIT continuous data file (e.g., 123_3_09_2022_B1.con)');

    con_edit = uicontrol('Style','edit',...
        'fontsize',10,...
        'units', 'normalized',...
        'HorizontalAlignment','left',...
        'Position',[0.02 0.7 0.75 0.1],...
        'String','');

    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'units', 'normalized',...
        'Position',[0.8 0.7 0.15 0.1],...
        'String','Browse',...
        'Callback',@select_con_callback);  
      
    uicontrol('Style','text',...
        'fontsize',12,...
        'HorizontalAlignment','left',...
        'units', 'normalized',...
        'Position',[0.02 0.57 0.4 0.1],...
        'String','Select Marker file for co-registration (e.g., 123_3_09_2022_ini.mrk):');
 
    marker_edit = uicontrol('Style','edit',...
        'fontsize',10,...
        'units', 'normalized',...
        'HorizontalAlignment','left',...
        'Position',[0.02 0.5 0.75 0.1],...
        'String','');
    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'units', 'normalized',...
        'Position',[0.8 0.5 0.15 0.1],...
        'String','Browse',...
        'Callback',@select_marker_callback);              
    
    uicontrol('Style','text',...
        'fontsize',12,...
        'HorizontalAlignment','left',...
        'units', 'normalized',...
        'Position',[0.02 0.37 0.4 0.1],...
        'String','Optional: Select event file (.evt) containing trigger events:');
    
    event_edit = uicontrol('Style','edit',...
        'fontsize',10,...
        'units', 'normalized',...
        'HorizontalAlignment','left',...
        'Position',[0.02 0.3 0.75 0.1],...
        'String','');    
   
    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'units', 'normalized',...
        'Position',[0.8 0.3 0.15 0.1],...
        'String','Browse',...
        'Callback',@select_event_callback);          
    
    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'foregroundColor','blue',...
        'units', 'normalized',...
        'Position',[0.75 0.1 0.2 0.1],...
        'String','Import',...
        'Callback',@OK_callback);  
      
    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'units', 'normalized',...
        'Position',[0.5 0.1 0.2 0.1],...
        'String','Cancel',...
        'Callback','delete(gcf)') 
    
    function OK_callback(~,~)
        % get from text box in case user typed in
        conFile = get(con_edit,'string');
        markerFile = get(marker_edit,'string');        
        eventFile = get(event_edit,'string');
        
        delete(gcf)
    end
    
    function select_con_callback(~,~)
        s =uigetfile('*.con','Select KIT .con file ...');
        if isequal(s,0)
            return;
        end    

        set(con_edit,'string',s);      
        
     end

    function select_marker_callback(~,~)
        s =uigetfile('*.mrk','Select KIT .con file ...');
        if isequal(s,0)
            return;
        end    
        set(marker_edit,'string',s);
    end

    function select_event_callback(~,~)    
        s =uigetfile('*.evt','Select KIT .con file ...');
        if isequal(s,0)
            return;
        end 
        set(event_edit,'string',s);      
    end


    % make modal   
    
    
    uiwait(d);
    
end

end