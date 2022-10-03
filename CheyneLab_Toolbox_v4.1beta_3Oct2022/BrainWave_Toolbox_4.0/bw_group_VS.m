function bw_group_VS
%       BW_GROUP_VS 
%
%   function bw_group_vs
%
%   DESCRIPTION: Creates a GUI that allows users to make aveages of virtual
%   sensors or TFR plots using lists of voxels in both MEG and Talairach
%   coordinates
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%
scrnsizes=get(0,'MonitorPosition');

%% Initialize Variables
global defaultPrefsFile

useNormal = 1;
computeRMS = 0;
list = {};
vListFile1 = '';
numFiles = 0;
% plotAll = 0;
% isTal = false;
coordType = 1;
initialized = true;


prefs = bw_checkPrefs;

beam_params =  prefs.beamformer_parameters;
vs_options = prefs.vs_options;
tfr_params = prefs.tfr_parameters;

f=figure('Name', 'BrainWave - Group Virtual Sensor Analysis', 'Position', [scrnsizes(1,4)/6 scrnsizes(1,4)/2  730 500],...
            'menubar','none','numbertitle','off', 'Color','white','CloseRequestFcn',@quit_callback );
    
if ~exist('beam_params','var')
    [beam_params vs_options tfr_params] = bw_setDefaultParameters;
    initialized = false;
end
   
%% Controls

include_title=uicontrol('style','text','units','normalized','position',...
    [0.03 0.92 0.5 0.05],'string','Virtual Sensor Parameters:','background','white','HorizontalAlignment','left',...
    'foregroundcolor','blue','fontsize',12);

include_listbox=uicontrol('style','listbox','units','normalized','position',...
    [0.03 0.38 0.9 0.41],'string',list,'fontsize',10,'max',10000,'background','white');

list_file_text=uicontrol('style','text','units','normalized','position',...
    [0.03 0.8 0.9 0.03],'string',vListFile1,'background','white','HorizontalAlignment','left',...
    'foregroundcolor','blue','fontsize',10);

num_files_text=uicontrol('style','text','units','normalized','position',...
    [0.82 0.8 0.9 0.03],'string','','background','white','HorizontalAlignment','left',...
    'foregroundcolor','blue','fontsize',10);

read_ds_list_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.25 0.85 0.2 0.06],'string','Switch datasets','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@read_ds_list_button_callback);

add_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.03 0.85 0.2 0.06],'string','Add VS','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@add_button_callback);

edit_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.65 0.85 0.1 0.06],'string','Edit','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@edit_button_callback);

delete_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.5 0.85 0.1 0.06],'string','Delete','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@delete_button_callback);

clear_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.78 0.85 0.15 0.06],'string','Clear List','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@clear_button_callback);

no_fixed_button = uicontrol('Style','checkbox','FontSize',12,'Units','Normalized',...
    'HorizontalAlignment','Left','Position',...
        [0.08 0.12 0.3 0.05],'val',useNormal,'String','Use orientations',...
        'BackgroundColor','White', 'Callback',@NO_FIXED_CALLBACK);

computeRMS_button = uicontrol('Style','checkbox','FontSize',12,'Units','Normalized',...
    'HorizontalAlignment','Left','Position',...
        [0.32 0.12 0.3 0.05],'val',computeRMS,'String','compute RMS',...
        'BackgroundColor','White', 'Callback',@COMPUTE_RMS_CALLBACK);

% plot_all_button = uicontrol('Style','checkbox','FontSize',12,'Units','Normalized',...
%     'HorizontalAlignment','Left','Position',...
%         [0.08 0.06 0.2 0.05],'val',plotAll,'String','Plot all waveforms',...
%         'BackgroundColor','White', 'Callback',@PLOT_ALL_CALLBACK);

average_vs=uicontrol('style','pushbutton','units','normalized','position',...
    [0.06 0.21 0.18 0.09],'string','Plot Average VS','background','white',...
    'foregroundcolor',[0.8,0.4,0.1],'callback',@average_vs_callback);

average_tfr=uicontrol('style','pushbutton','units','normalized','position',...
    [0.25 0.21 0.18 0.09],'string','Plot Average TFR','background','white',...
    'foregroundcolor',[0.8,0.4,0.1],'callback',@average_tfr_callback);

generate_vlist_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.47 0.21 0.23 0.09],'string','Convert to MEG Coords','background','white',...
    'foregroundcolor',[0.8,0.4,0.1],'callback',@generate_vlist_callback);

set_data_params_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.73 0.26 0.18 0.07],'string','Data Parameters','background','white',...
    'foregroundcolor','black','callback',@set_data_params_callback);

set_vs_params_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.73 0.16 0.18 0.07],'string','VS Options','background','white',...
    'foregroundcolor','black','callback',@set_vs_params_callback);

set_tfr_params_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.73 0.06 0.18 0.07],'string','TFR Options','background','white',...
    'foregroundcolor','black','callback',@set_tfr_params_callback);

coord_menu = uicontrol('Style', 'popup','units','normalized','background','white','Position', [0.6 0.92 0.3 0.06],...
    'String', 'MEG Coordinates|Talairach Coordinates|MNI Coordinates','Callback', @coord_menu_callback);

% MEG_radio=uicontrol('style','radio','units','normalized','position',...
%     [0.5 0.92 0.3 0.06],'string','MEG Coordinates','value',~isTal,...
%     'background','white','callback',@MEG_radio_callback);
% 
% Tal_radio=uicontrol('style','radio','units','normalized','position',...
%     [0.7 0.92 0.3 0.06],'string','Talaraich Coordinates:','value',isTal,...
%     'background','white','callback',@Tal_radio_callback);

set(average_tfr,'enable','off')
set(average_vs,'enable','off')

set(set_vs_params_button,'enable','off')
set(set_tfr_params_button,'enable','off')
set(set_data_params_button,'enable','off')
set(average_vs,'enable','off')
set(average_tfr,'enable','off')
set(generate_vlist_button,'enable','off')


%% Boxes

manual_box=annotation('rectangle',[0.04 0.03 0.9 0.32],'EdgeColor','blue');

% options_box=annotation('rectangle',[0.47 0.05 0.5 0.3],'EdgeColor','blue');

FILE_MENU=uimenu('Label','File');

uimenu(FILE_MENU,'label','Open List File...','Accelerator','O', 'Callback',@load_button_callback);
uimenu(FILE_MENU,'label','Save List File...','Accelerator','S','Callback', @save_button_callback);
uimenu(FILE_MENU,'label','Save Raw Data...','separator','on','Callback',@save_raw_callback);
uimenu(FILE_MENU,'label','Close','Accelerator','W','separator','on','Callback',@quit_callback);

%% Callbacks

    function quit_callback(src,evt)       
       
        response = bw_warning_dialog('Save current parameters as defaults?');
        if response == 1          
           fprintf('saving current settings to file %s\n', defaultPrefsFile)
           t=load(defaultPrefsFile);
           settings = t.settings; 
           settings.beamparams = beam_params;
           settings.vsoptions = vs_options;
           settings.tfrparams = tfr_params;
           save(defaultPrefsFile,'settings')
       end       
       delete(f);
    end


    function load_button_callback(src, evt)
        [filename pathname idx]=uigetfile({'*.vlist','Voxel list (*.vlist)';'*.tlist','Talairach list (*.tlist)';
            '*.mlist','MNI list (*.mlist)';'*.list','Dataset list (*.list)';'*.vox','Vox File (*.vox)'},...
            'Select list file containing virtual sensor parameters');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        
        listFile = fullfile(pathname,filename);
 
        if idx == 5
            fprintf('Converting Vox File coordinates to voxel list...\n');
            coordType = 1;
            % convert vox file to vlist
            fid = fopen(listFile,'r');
            numVoxels = fscanf(fid, '%d',1);
            voxels = fscanf(fid,'%lf',[6 numVoxels])';
            % for now assume .vox file is in ANALYSIS directory
            % go two directories up to get dsName      
            a = strfind(pathname, filesep);
            dsName = pathname(1:a(end-1)-1);      
            a = strfind(dsName, filesep);
            if ~isempty(a)
                dsName = dsName(a(end)+1:end);
            end
  
             for i=1:numVoxels
                s = sprintf('%s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f', dsName, voxels(i,:) );
                list(i,:) = cellstr(s);
            end
            fclose(fid);
                   
            set(include_listbox,'string',list);
 
          	vListFile1 = '';
            set(list_file_text, 'string',vListFile1);
            fprintf('...done\n');
            
            numFiles = size(list,1);
            s = sprintf('# voxels = %d',numFiles);
            set(num_files_text, 'string',s);
            
            initialize_data;
         
        else       
            list = bw_read_list_file(listFile);

            if ~isempty(list)
                set(include_listbox,'string',list);
                [numinlist garbage]=size(get(include_listbox,'string'));
                set(average_vs,'enable','on')
                set(average_tfr,'enable','on')

                % new - CWD to path of list file in case of relative file paths
                %
                cd(pathname)
                fprintf('setting current working directory to %s\n',pathname);

                vListFile1 = listFile;
                set(list_file_text, 'string',vListFile1);

                numFiles = size(list,1);
                s = sprintf('# voxels = %d',numFiles);
                set(num_files_text, 'string',s);
                
                
                initialize_data;
            end

            if idx < 4
                coordType = idx; 
            end

            if idx == 4
                for i=1:size(list,1)
                    str = char(list(i,:));
                    c = 0;
                    %thisVoxel = str2double( c(1:3) );
                    if coordType == 1
                        %normal = str2double( c(4:6))';
                        s = sprintf('%s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f', char(list(i)), c, c, c, c, c, c);
                    else
                        s = sprintf('%s    %6.1f %6.1f %6.1f', char(list(i)), c, c, c);
                    end
                    list(i,:) = cellstr(s);

                    set(include_listbox,'string',list);
                end
            end
        end
        
        set(coord_menu,'value',coordType);
        
        if coordType > 1
            set(no_fixed_button,'enable','off'); 
            set(generate_vlist_button,'enable','on')
        else
            set(no_fixed_button,'enable','on');
            set(generate_vlist_button,'enable','off')
        end        
        
    end

    function read_ds_list_button_callback(src, evt)
        
        if isempty(list)
            return;
        end
        
        [filename pathname xxx]=uigetfile('*.list','Select .list file of alternate datasets');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        
        listFile = fullfile(pathname,filename);      
        newList = bw_read_list_file(listFile);
        
        if size(newList) ~= size(list,1)
            fprintf('dataset list must contain same number of datasets as vlist\n');
            return;
        end   
            
        for i=1:size(list,1)
            str = char(list(i,:));
            a = strread(str,'%s','delimiter',' ');
            thisVoxel = str2double( a(2:4))';
            if coordType == 1
                normal = str2double( a(5:7))';       
                s = sprintf('%s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f', char(newList(i)), thisVoxel, normal);    
            else
                s = sprintf('%s    %6.1f %6.1f %6.1f', char(newList(i)), thisVoxel);    
            end
            list(i,:) = cellstr(s); 
            
            set(include_listbox,'string',list);
        end
    end

    function save_button_callback(src, evt)
        
        if isempty(list)
            return;
        end
        
        if coordType == 3
            ext = {'*.mlist','MNI list (*.mlist)'};
        elseif coordType == 2 
            ext = {'*.tlist','Talairach list (*.tlist)'};
        else
            ext = {'*.vlist','Voxel list (*.vlist)'};
        end
        
        [filename pathname xxx]=uiputfile(ext,'Save voxel list file as...');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
                    
        saveName = fullfile(pathname, filename);
        fprintf('Saving voxel parameters in file %s\n', saveName);
        fid = fopen(saveName,'w');
             
        for i=1:size(list,1)
            str = char(list(i,:));
            a = strread(str,'%s','delimiter',' ');
            dsName = a(1);
            thisVoxel = str2double( a(2:4))';
            if coordType == 1
                normal = str2double( a(5:7))';       
                s = sprintf('%s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f', char(dsName), thisVoxel, normal);    
            else
                s = sprintf('%s    %6.1f %6.1f %6.1f', char(dsName), thisVoxel);                    
            end         
            fprintf(fid,'%s\n', s);           
        end
        
        
        fclose(fid);
 
        vListFile1 = saveName;        
        set(list_file_text, 'string',vListFile1);

        numFiles = size(list,1);
        s = sprintf('# voxels = %d',numFiles);
        set(num_files_text, 'string',s);

        
    end

    function add_button_callback(src, evt)
        
        if ~isempty(list)
            init_pars = char(list(end,:));
        else
            init_pars = [];
        end
        
        [pars allFlag] = vsParamsDlg(init_pars, coordType);
        
        if ~isempty(pars)
            list  = [list; pars];
            list = cellstr(list);
            set(include_listbox,'string',list);
            initialize_data;         
        end
        
    end


    function clear_button_callback(src,evt)
        list = [];
        set(include_listbox,'string',list);       
        initialize_data;
        vListFile1 = '';
    end

    function edit_button_callback(src,evt)
        if isempty(list)
            return;
        end
        selecteditem = get(include_listbox,'value');
        oldpars = char(list(selecteditem,:)); 
        
        % pars is char string
        [pars allFlag] = vsParamsDlg(oldpars, coordType);
              
        if ~isempty(pars)
            list(selecteditem,:) = cellstr(pars);
%             list(selecteditem,:) = pars;
            set(include_listbox,'string',list);

            if allFlag
                for j=1:size(list,1)
                    str = char(list(j,:));
                    a = strread(str,'%s','delimiter',' ');
                    dsName = char(a(1));
                    a = strread(pars,'%s','delimiter',' ');
                    vox = str2double( a(2:4))';
                    if coordType == 1
                        ori = str2double( a(5:7))';
                        s = sprintf('%s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f', dsName, vox, ori);    
                        list(j,:) = cellstr(s);
                    else
                        s = sprintf('%s    %6.1f %6.1f %6.1f', dsName, vox);    
                        list(j,:) = cellstr(s);
                    end                    
                end 
                set(include_listbox,'string',list);

            end
        end
        
        
    end

    function delete_button_callback(src,evt)
        if isempty(list)
            return;
        end
        selecteditem = get(include_listbox,'value');
        list(selecteditem,:) = []; 

        selecteditem = 1;
                
        set(include_listbox,'string',list);
        set(include_listbox,'value',selecteditem); 
        
        vListFile1 = '';
        set(list_file_text, 'string',vListFile1);

        numFiles = size(list,1);
        s = sprintf('# voxels = %d',numFiles);
        set(num_files_text, 'string',s);
        
    end


    function initialize_data   
        
        if ~isempty(list)
            % need to set / check limits for data windows
            str = char(list(1,:));
            a = strread(str,'%s','delimiter',' ');
            dsName = a(1);
            fullName = char(strcat(pwd,filesep,char(dsName)));    
            
            if ~exist(fullName,'file');
                fprintf('***Cannot find dataset %s - unable to set data parameters...\n', fullName);
                return;
            end
            
            ctf_params=bw_CTFGetParams(fullName);
            ctfmin = ctf_params(12); % in s
            ctfmax = ctf_params(13); % in s
            
            if (beam_params.covWindow(1) == 0 && beam_params.covWindow(2) == 0)
                beam_params.covWindow(1) = ctfmin; 
                beam_params.covWindow(2) = ctfmax; 
            end;
            if (tfr_params.baseline(1) == 0 && tfr_params.baseline(2) == 0)
                tfr_params.baseline(1) = ctfmin; 
                tfr_params.baseline(2) = ctfmax;
            end;
            if (beam_params.covWindow(2) > ctfmax), beam_params.covWindow(2) = ctfmax; end;
            if (beam_params.covWindow(1) < ctfmin), beam_params.covWindow(1) = ctfmin; end;
            if (beam_params.covWindow(2) > ctfmax), beam_params.covWindow(2) = ctfmax; end;
            if (beam_params.baseline(1) < ctfmin), beam_params.baseline(1) = ctfmin; end;
            if (beam_params.baseline(2) > ctfmax), beam_params.baseline(2) = ctfmax; end;
            if (tfr_params.baseline(1) < ctfmin), tfr_params.baseline(1) = ctfmin; end;
            if (tfr_params.baseline(2) > ctfmax), tfr_params.baseline(2) = ctfmax; end;    


            set(set_vs_params_button,'enable','on')
            set(set_tfr_params_button,'enable','on')
            set(set_data_params_button,'enable','on')
            set(average_vs,'enable','on')
            set(average_tfr,'enable','on')
        else
            set(set_vs_params_button,'enable','off')
            set(set_tfr_params_button,'enable','off')
            set(set_data_params_button,'enable','off')
            set(average_vs,'enable','off')
            set(average_tfr,'enable','off')
        end
        
        
    end

    function set_vs_params_callback(src,evt)
        vs_options = bw_set_vs_options(vs_options);
    end

    function set_tfr_params_callback(src,evt)
        if ~isempty(list)
            str = char(list(1,:));
            a = strread(str,'%s','delimiter',' ');
            dsName = a(1);
            fullName = char(strcat(pwd,filesep,char(dsName)));
            tfr_params = bw_set_tfr_parameters(tfr_params, fullName);
        end
    end

    function set_data_params_callback(src,evt)
        if ~isempty(list)
            str = char(list(1,:));
            a = strread(str,'%s','delimiter',' ');
            dsName = a(1);
            fullName = char(strcat(pwd,filesep,char(dsName)));

            beam_params = bw_set_data_parameters(beam_params, fullName);
        end
    end


    function coord_menu_callback(src,evt)
        coordType = get(src,'Value');
        
        if coordType == 1
            set(no_fixed_button,'enable','on'); 
            set(include_listbox,'string',list);
            set(generate_vlist_button,'enable','off')           
        else 
            set(no_fixed_button,'enable','off');    
            set(generate_vlist_button,'enable','on')
            if isempty(list)
                return;
            end

            for i=1:size(list,1)
                str = char(list(i,:));
                a = strread(str,'%s','delimiter',' ');
                dsName = a(1);
                thisVoxel = str2double( a(2:4))';
                s = sprintf('%s    %6.1f %6.1f %6.1f ', char(dsName), thisVoxel);    
                t_list(i,:) = cellstr(s);          
                set(include_listbox,'string',t_list);
            end      
        end      
    end


    function NO_FIXED_CALLBACK(src,evt)
        val = get(src,'val');
        useNormal = val;  
    end

    function COMPUTE_RMS_CALLBACK(src,evt)
        val = get(src,'val');
        computeRMS = val;  
    end

%     function PLOT_ALL_CALLBACK(src,evt)
%         val = get(src,'val');
%         plotAll = val;  
%     end

    function save_raw_callback(src,evt)
        if isempty(list)
            return;
        end
        
        [~,defName,~] = bw_fileparts(vListFile1);
        
        [name,path,idx] = uiputfile({'*.mat','MAT-file (*.mat)';'*','ASCII files (Directory)';},...
                    'Select output name virtual sensor data ...',defName);
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
        
        wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wbh,'canceling',0)
       
        tic;
        for j=1:size(list,1)
            if getappdata(wbh,'canceling')
                delete(wbh);   
                fprintf('*** cancelled ***\n');
                return;
            end
            waitbar(j/size(list,1),wbh,sprintf('generating virtual sensor %d',j));
            
            str = char(list(j,:));
            a = strread(str,'%s','delimiter',' ');
            dsName = char(a(1));
            thisVoxel = str2double( a(2:4))';
            fullName = char(strcat(pwd,filesep,dsName));
            fprintf('\nProcessing file -->%s\n', fullName);
  
            if coordType > 1
                if coordType == 3
                    thisVoxel = bw_mni2tal(thisVoxel);
                end
                thisVoxel = bw_Tal2MEG( fullName, thisVoxel, beam_params, vs_options );
                normal = [1 0 0];
                useThisNormal = 0;
            else
                normal = str2double( a(5:7))';
                useThisNormal = useNormal;
            end   
                    
            % get raw data...
            fprintf('computing single trial data ...\n');
            
            % override some parameters...
            params = beam_params;        
            params.rms = 0;
            vs_options.saveSingleTrials = 1;
            
            [timeVec vs_data_raw comnorm] = bw_make_vs(fullName, thisVoxel, normal, useThisNormal, params, vs_options);
            
            [samples trials] = size(vs_data_raw);
            
            % store all data in one matfile 
            %
            % format:
            % vsdata.timeVec = 1D array of latencies (nsamples x 1)
            % vsdata.voxels = 2D array of voxel coords (nvoxels x 6)
            % vsdata.trials = 3D array of vs data (nvoxels x ntrials x nsamples)
           
            if saveMatFile
                vsdata.timeVec = timeVec;
                voxel = [thisVoxel comnorm'];
                vsdata.voxel(j,1:6) = voxel;
                vsdata.trial(j,1:trials,1:samples) = single(vs_data_raw');    % save as single precision - reduces file size by 50%       
            else
                outFile = sprintf('%s%s%s_voxel_%4.2f_%4.2f_%4.2f.raw', ...
                    path, filesep, char(dsName), thisVoxel(1), thisVoxel(2), thisVoxel(3));
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

    function generate_vlist_callback(src,evt)
  
        if isempty(list)
            return;
        end
        
        [name,pathname,filterindex]=uiputfile('*.vlist','Enter filename for vlist file...:');
        if isequal(name,0)
            return;
        end
        vfile = fullfile(pathname, name);
        
        fprintf('Saving MEG coordinates in voxel list file %s\n', vfile);         

        fid = fopen(vfile,'w');          
        numSubjects = size(list,1);
        
        wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wbh,'canceling',0)

        for j=1:numSubjects            
            if getappdata(wbh,'canceling')
                delete(wbh);   
                fprintf('*** cancelled ***\n');
                return;
            end           
            waitbar(j/size(list,1),wbh,sprintf('generating virtual sensor %d',j));            
            
            str = char(list(j,:));
            a = strread(str,'%s','delimiter',' ');
            dsName = char(a(1));
            thisVoxel = str2double( a(2:4))';

            fullName = char(strcat(pwd,filesep,dsName));
            if coordType == 3
                thisVoxel = bw_mni2tal(thisVoxel);
            end
            thisVoxel = bw_Tal2MEG( fullName, thisVoxel, beam_params, vs_options );
            normal = [1 0 0];
            useThisNormal = false;
            saveSingleTrials = 0;
            % need to generate data to get optimized orientation...
            [thisTimeVec vs_data comnorm] = bw_make_vs(fullName, thisVoxel, normal, useThisNormal, beam_params, vs_options);
            fprintf(fid,'%s   %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f\n', dsName, thisVoxel, comnorm);
                  
            clear vs_data;
            clear thisTimeVec;
            
        end
        delete(wbh);        
        
        fclose(fid);
        
        % load new vlist
        
        coordType = 1;
        set(coord_menu,'value',coordType);
        
        list = bw_read_list_file(vfile);
        set(include_listbox,'string',list);

        % new - CWD to path of list file in case of relative file paths
        %
        cd(pathname)
        fprintf('setting current working directory to %s\n',pathname);

        vListFile1 = vfile;
        set(list_file_text, 'string',vListFile1);
        numFiles = size(list,1);
        s = sprintf('# voxels = %d',numFiles);
        set(num_files_text, 'string',s);

        initialize_data;
        
        set(no_fixed_button,'enable','on');
        set(generate_vlist_button,'enable','off')              
        
    end



    % Major change in Version 2.2 

    % now returns an array of TFR structs and do averaging in the plot
    % window - eliminates problem of recomputing std err etc
                        
    function average_tfr_callback(src,evt)
  
        if isempty(list)
            return;
        end  
                            
        if ~beam_params.filterData || beam_params.filter(1) == 0
            fprintf('Must specify hi-pass filter for time-frequency plot\n');
            return;
        end
        
        wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wbh,'canceling',0)
               
        % generate TFRs for all subjects
        % 
        numSubjects = size(list,1);
        for j=1:numSubjects
            
            if getappdata(wbh,'canceling')
                delete(wbh);  
                fprintf('*** cancelled ***\n');
                return;
            end
            waitbar(j/numSubjects,wbh,sprintf('generating virtual sensor %d',j));
            
            
            str = char(list(j,:));
            a = strread(str,'%s','delimiter',' ');
            dsName = char(a(1));
            thisVoxel = str2double( a(2:4))';

            fullName = char(strcat(pwd,filesep,dsName));
            fprintf('\nProcessing file -->%s\n', dsName);
            fprintf('Generating virtual sensor for dataset %s, MEG coord [%g %g %g] ...\n', fullName, thisVoxel);           

            if coordType > 1
                if coordType == 3
                    thisVoxel = bw_mni2tal(thisVoxel);
                end
                thisVoxel = bw_Tal2MEG( fullName, thisVoxel, beam_params, vs_options );
                normal = [1 0 0];
                useThisNormal = false;
            else
                normal = str2double( a(5:7))';
                useThisNormal = useNormal;
            end
            
            [TFR_DATA comnorm] = bw_make_tfr(fullName, thisVoxel, normal, useThisNormal, beam_params, vs_options, tfr_params);            
  
            if j==1
                timeVec = TFR_DATA.timeVec;
            else
                % in case datasets had different sample rates interpolate using first file's time base...
                if ~isequal(TFR_DATA.timeVec,timeVec)
                    fprintf('warning: time base of %s differs from first file ... interpolating TFR\n',fullName);               
                    ttemp = TFR_DATA.timeVec';
                    resampleTFR = interp1(ttemp, TFR_DATA.TFR', timeVec);  % interp1 intepolates columns
                    resamplePLF = interp1(ttemp, TFR_DATA.PLF', timeVec);  % interp1 intepolates columns
                    resampleMEAN = interp1(ttemp, TFR_DATA.MEAN', timeVec);  % interp1 intepolates columns

                    TFR_DATA.TFR = resampleTFR';
                    TFR_DATA.PLF = resamplePLF';
                    TFR_DATA.MEAN = resampleMEAN';
                    TFR_DATA.timeVec = timeVec;

                    clear resampleTFR;
                    clear resamplePLF;
                    clear resampleMEAN;
                end
            end

            if vs_options.rms
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(rms)', dsName, thisVoxel);
            else
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(%.3f_%.3f_%.3f)', dsName, thisVoxel, comnorm);
            end
            TFR_DATA.dsName = dsName;
            TFR_DATA.plotLabel = plotLabel;
        
            TFR_ARRAY{j} = TFR_DATA;
             
        end    
        
        delete(wbh);

        % plot TFR
        
        bw_plot_tfr(TFR_ARRAY, 0, vListFile1);
              
    end 

   function average_vs_callback(src,evt)

        if isempty(list)
            return;
        end
                
        wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
        setappdata(wbh,'canceling',0)
        
        for j=1:size(list,1)
            if getappdata(wbh,'canceling')
                delete(wbh);   
                fprintf('*** cancelled ***\n');
                return;
            end
            waitbar(j/size(list,1),wbh,sprintf('generating virtual sensor %d',j));
            
            str = char(list(j,:));
            a = strread(str,'%s','delimiter',' ');
            dsName = char(a(1));
            thisVoxel = str2double( a(2:4))';
            
            fullName = char(strcat(pwd,filesep,dsName));
            fprintf('\nProcessing file -->%s\n', dsName);
            fprintf('Generating virtual sensor for dataset %s, MEG coord [%g %g %g] ...\n', fullName, thisVoxel);   
            
            if coordType > 1
                if coordType == 3
                    thisVoxel = bw_mni2tal(thisVoxel);
                end
                thisVoxel = bw_Tal2MEG( fullName, thisVoxel, beam_params, vs_options );
                normal = [1 0 0];
                useThisNormal = 0;
            else
                normal = str2double( a(5:7))';
                useThisNormal = useNormal;
            end
            
            options = vs_options;
            
            if computeRMS
                options.rms = 1;
            else
                options.rms = 0;
            end          
                        
            [thisTimeVec vs_data comnorm] = bw_make_vs(fullName, thisVoxel, normal, useThisNormal, beam_params, options);
                   
            if isempty(vs_data)
                fprintf('*** Error occurred computing virtual sensor...exiting ***\n');
                delete(wbh);
                return;
            end
            
            if j==1
                timeVec = thisTimeVec;
            else
                % if datasets have different sample rates, interpolate using first file's time base...
                if ~isequal(thisTimeVec,timeVec)
                    fprintf('warning: time base of %s differs from first file ... interpolating\n',dsName);
                    ytemp = vs_data';
                    ttemp = thisTimeVec';
                    vs_data = interp1(ttemp, ytemp, timeVec);
                end          
            end
            
            VS_DATA.dsName = fullName;
            VS_DATA.voxel = thisVoxel;
            VS_DATA.normal = comnorm';
            VS_DATA.timeVec = timeVec;
            VS_DATA.vs_data = vs_data;    
            VS_DATA.filter = beam_params.filter;    
            if beam_params.useBaselineWindow
                VS_DATA.baseline = beam_params.baseline;   
            else
                VS_DATA.baseline = [timeVec(1) timeVec(end)];   
            end
            
            if vs_options.rms
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(rms)', dsName, thisVoxel);
            else
                plotLabel = sprintf('%s_voxel_%.1f_%.1f_%.1f_(%.3f_%.3f_%.3f)', dsName, thisVoxel, comnorm);
            end
            VS_DATA.plotLabel = plotLabel;    
            
            VS_ARRAY{j} = VS_DATA; 
            
        end
        
        bw_plot_vs(VS_ARRAY, vs_options, vListFile1);
        
        
        delete(wbh);
        
     
    end

end


function [parsString applyAll] = vsParamsDlg(init_pars, coordType )

    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Enter VS parameters','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 800 200]);
    
    dsName = '*.ds';
    pos = [1 0 0];
    ori = [1 0 0];
    if ~isempty(init_pars)
        a = strread(init_pars,'%s','delimiter',' ');
        dsName = char(a(1));
        pos = str2double( a(2:4))';        
        if coordType == 1
            ori = str2double( a(5:7))';
        end        
    end
        
    parsString = '';
    applyAll = false;
    
   
    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.78 0.6 0.15 0.22],'string','OK','BackgroundColor',[0.99,0.64,0.3],...
        'FontSize',12,'ForegroundColor','black','FontWeight','b','callback',@ok_callback);

    cancel=uicontrol('style','pushbutton','units','normalized','position',...
        [0.78 0.25 0.15 0.22],'string','Cancel','BackgroundColor','white','FontSize',13,...
        'ForegroundColor','black','callback',@cancel_callback);

    title1=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.7 0.3 0.1],'String','Dataset:    ','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black');  

    if coordType == 3    
        unitStr = 'MNI coords (mm)';
    elseif coordType == 2
        unitStr = 'Talairach coords (mm)';
    else
        unitStr = 'MEG coords (cm)';
    end
    
    title2=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.35 0.7 0.2 0.1],'String',unitStr,'FontSize',12,...
       'BackGroundColor','white','foregroundcolor','black'); 

    title3=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.55 0.7 0.12 0.1],'String','Orientation','FontSize',12,...
       'BackGroundColor','white','foregroundcolor','black'); 

    dsNameEdit=uicontrol('style','edit','units','normalized','position',...
          [0.05 0.4 0.28 0.2],'String', dsName, 'FontSize', 12,'horizontalalignment','left',...
          'BackGroundColor','white');

    posXEdit=uicontrol('style','edit','units','normalized','position',...
          [0.35 0.4 0.06 0.2],'String', pos(1), 'FontSize', 12,...
              'BackGroundColor','white');    
    posYEdit=uicontrol('style','edit','units','normalized','position',...
          [0.42 0.4 0.06 0.2],'String', pos(2), 'FontSize', 12,...
              'BackGroundColor','white');    
    posZEdit=uicontrol('style','edit','units','normalized','position',...
          [0.48 0.4 0.06 0.2],'String', pos(3), 'FontSize', 12,...
              'BackGroundColor','white');    
       
    oriXEdit=uicontrol('style','edit','units','normalized','position',...
          [0.55 0.4 0.07 0.2],'String', ori(1), 'FontSize', 12,...
              'BackGroundColor','white');    
    oriYEdit=uicontrol('style','edit','units','normalized','position',...
          [0.62 0.4 0.07 0.2],'String', ori(2), 'FontSize', 12,...
              'BackGroundColor','white');    
    oriZEdit=uicontrol('style','edit','units','normalized','position',...
          [0.7 0.4 0.07 0.2],'String', ori(3), 'FontSize', 12,...
              'BackGroundColor','white'); 
  
          
    plot_all_button = uicontrol('Style','checkbox','FontSize',12,'Units','Normalized',...
    'HorizontalAlignment','Left','Position',...
        [0.35 0.2 0.25 0.08],'val',applyAll,'String','Apply to all datasets...',...
        'BackgroundColor','White', 'Callback',@APPLY_ALL_CALLBACK);
          
          
    if coordType > 1
        set(oriXEdit,'enable','off');
        set(oriYEdit,'enable','off');
        set(oriZEdit,'enable','off');
        set(title3,'enable','off');
    end
          
    function ok_callback(src,evt)
        % update params
        dsName=get(dsNameEdit,'String');
       
        string_value=get(posXEdit,'String');
        pos(1)=str2double(string_value);  
        string_value=get(posYEdit,'String');
        pos(2)=str2double(string_value);  
        string_value=get(posZEdit,'String');
        pos(3)=str2double(string_value);  
        
        string_value=get(oriXEdit,'String');
        ori(1)=str2double(string_value);  
        string_value=get(oriYEdit,'String');
        ori(2)=str2double(string_value);  
        string_value=get(oriZEdit,'String');
        ori(3)=str2double(string_value);  
        
        if coordType == 1
            parsString = sprintf('%s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f', dsName, pos, ori);
        else
            parsString = sprintf('%s    %6.1f %6.1f %6.1f', dsName, pos);
        end
        
        uiresume(gcf);
    end

    function cancel_callback(src,evt)
        uiresume(gcf); 
    end

    function APPLY_ALL_CALLBACK(src,evt)
        val = get(src,'val');
        applyAll = val;  
    end
    

    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
end
