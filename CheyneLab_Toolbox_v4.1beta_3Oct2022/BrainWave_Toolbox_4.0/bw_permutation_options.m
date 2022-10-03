function perm_options = bw_get_permutation_options
%       BW_GROUP_ANALYSIS 
%
%   function bw_group_analysis (list, list2)
%
%   DESCRIPTION: Creates a GUI that allows users to select which list of
%   normalized images from the overall list (list) to grand average or run 
%   a permutation test.  
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   --VERSION 1.3--
% 
% Rewritten version: - now has two lists for two conditions, input is through
% buttons on interface - added ROI option for permutation etc...  
% D. Cheyne, July 2011
%
%
scrnsizes=get(0,'MonitorPosition');

%% Initialize Variables

displaycheck=0;
alpha=0.05;
maxperm=2048;
makeContrasts = 0;

numinlist=0;
numinlist2 = 0;

useROI = 0;
xmin = -75;
xmax = 75;
ymin = -112;
ymax = 75;
zmin = -50;
zmax = 85;

list = '';
list2 = '';
subj_list = '';


batchJobs.enabled = false;
batchJobs.numJobs = 0;
batchJobs.processes = {};

   
f=figure('Name', 'BrainWave - Group Image Analysis', 'Position', [scrnsizes(1,4)/6 scrnsizes(1,4)/2  1200 470],...
            'menubar','none','numbertitle','off', 'Color','white');

%% Controls

include_title=uicontrol('style','text','units','normalized','position',...
    [0.03 0.88 0.3 0.06],'string','Image files (Condition A):','background','white','HorizontalAlignment','left',...
    'foregroundcolor','blue','fontsize',12);

include_listbox=uicontrol('style','listbox','units','normalized','position',...
    [0.03 0.38 0.45 0.43],'string',list,'fontsize',10,'max',10000,'background','white');

load_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.03 0.83 0.1 0.05],'string','Read list','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@load_button_callback);

add_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.15 0.83 0.1 0.05],'string','Add File(s)','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@add_button_callback);

delete_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.28 0.83 0.08 0.05],'string','Delete File','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@delete_button_callback);

clear_button=uicontrol('style','pushbutton','units','normalized','position',...
    [0.4 0.83 0.08 0.05],'string','Clear List','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@clear_button_callback);


create_diff_check=uicontrol('style','checkbox','units','normalized','position',...
    [0.5 0.95 0.3 0.06],'string','Create Contrast Images:','value',makeContrasts,...
    'background','white','callback',@create_diff_check_callback);

% AminusB_radio=uicontrol('style','checkbox','units','normalized','position',...
%     [0.67 0.95 0.3 0.06],'string','(Cond A > Cond B):','value',pos_contrast,...
%     'background','white','callback',@AminusB_callback);
% 
% BminusA_radio=uicontrol('style','checkbox','units','normalized','position',...
%     [0.8 0.95 0.3 0.06],'string','(Cond B > Cond A):','value',neg_contrast,...
%     'background','white','callback',@BminusA_callback);


include_title2=uicontrol('style','text','units','normalized','position',...
    [0.5 0.88 0.3 0.06],'string','Image files (Condition B):','background','white','HorizontalAlignment','left',...
    'foregroundcolor','blue','fontsize',12);

include_listbox2=uicontrol('style','listbox','units','normalized','position',...
    [0.5 0.38 0.45 0.43],'string',list,'fontsize',10,'max',10000,'background','white');

load_button2=uicontrol('style','pushbutton','units','normalized','position',...
    [0.5 0.83 0.1 0.05],'string','Read list','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@load_button2_callback);

add_button2=uicontrol('style','pushbutton','units','normalized','position',...
    [0.63 0.83 0.1 0.05],'string','Add File(s)','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@add_button2_callback);

delete_button2=uicontrol('style','pushbutton','units','normalized','position',...
    [0.76 0.83 0.08 0.05],'string','Delete File','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@delete_button2_callback);

clear_button2=uicontrol('style','pushbutton','units','normalized','position',...
    [0.87 0.83 0.08 0.05],'string','Clear List','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@clear_button2_callback);

manual_average=uicontrol('style','pushbutton','units','normalized','position',...
    [0.08 0.1525 0.1 0.095],'string','Average','background','white',...
    'foregroundcolor',[0.8,0.4,0.1],'callback',@manual_average_callback);

manual_permute=uicontrol('style','pushbutton','units','normalized','position',...
    [0.24 0.1525 0.15 0.095],'string','Permute and Average','background','white',...
    'foregroundcolor',[0.8,0.4,0.1],'callback',@manual_permute_callback);



display_image=uicontrol('style','checkbox','units','normalized','position',...
    [0.5 0.25 0.14 0.06],'string','Plot individual images','value',displaycheck,...
    'background','white','callback',@display_image_callback);

alpha_text=uicontrol('style','text','units','normalized','position',...
    [0.68 0.22 0.05 0.07],'string','Alpha:','background','white');

alpha_number=uicontrol('style','edit','units','normalized','position',...
    [0.74 0.23 0.04 0.09],'string',alpha,'fontsize',10,'backgroundcolor',...
    'white','callback',@alpha_number_callback);

max_perm_text=uicontrol('style','text','units','normalized','position',...
    [0.79 0.22 0.13 0.07],'string','No. of Permutations:','background','white');
max_perm_number=uicontrol('style','edit','units','normalized','position',...
    [0.91 0.23 0.04 0.09],'string',maxperm,'fontsize',10,'backgroundcolor',...
    'white','callback',@max_perm_number_callback);

options_title=uicontrol('style','text','units','normalized','position',...
    [0.48 0.3 0.06 0.07],'string','Options:','background','white',...
    'foregroundcolor','blue');

use_ROI_check=uicontrol('style','checkbox','units','normalized','position',...
    [0.5 0.18 0.2 0.06],'string','Use ROI (MNI coords in mm):','value',useROI,...
    'background','white','callback',@useROI_callback);

% X
uicontrol('style','text','units','normalized','position',...
    [0.5 0.07 0.05 0.07],'string','X=','background','white');

ROI_XMIN=uicontrol('style','edit','units','normalized','position',...
    [0.54 0.08 0.04 0.09],'string',xmin,'fontsize',10,'backgroundcolor',...
    'white','enable', 'off','callback',@xmin_callback);
uicontrol('style','text','units','normalized','position',...
    [0.59 0.07 0.01 0.07],'string','to','background','white');
ROI_XMAX=uicontrol('style','edit','units','normalized','position',...
    [0.61 0.08 0.04 0.09],'string',xmax,'fontsize',10,'backgroundcolor',...
    'white','enable', 'off','callback',@xmax_callback);

% Y
uicontrol('style','text','units','normalized','position',...
    [0.65 0.07 0.05 0.07],'string','Y=','background','white');

ROI_YMIN=uicontrol('style','edit','units','normalized','position',...
    [0.69 0.08 0.04 0.09],'string',ymin,'fontsize',10,'backgroundcolor',...
    'white','enable', 'off','callback',@ymin_callback);
uicontrol('style','text','units','normalized','position',...
    [0.74 0.07 0.01 0.07],'string','to','background','white');
ROI_YMAX=uicontrol('style','edit','units','normalized','position',...
    [0.76 0.08 0.04 0.09],'string',ymax,'fontsize',10,'backgroundcolor',...
    'white','enable', 'off','callback',@ymax_callback);
% Z

uicontrol('style','text','units','normalized','position',...
    [0.8 0.07 0.05 0.07],'string','Z=','background','white');

ROI_ZMIN=uicontrol('style','edit','units','normalized','position',...
    [0.84 0.08 0.04 0.09],'string',zmin,'fontsize',10,'backgroundcolor',...
    'white','enable', 'off','callback',@zmin_callback);
uicontrol('style','text','units','normalized','position',...
    [0.89 0.07 0.01 0.07],'string','to','background','white');
ROI_ZMAX=uicontrol('style','edit','units','normalized','position',...
    [0.91 0.08 0.04 0.09],'string',zmax,'fontsize',10,'backgroundcolor',...
    'white','enable', 'off','callback',@zmax_callback);

set(manual_permute,'enable','off')
set(manual_average,'enable','off')
set(load_button2,'enable','off')
set(add_button2,'enable','off')
set(delete_button2,'enable','off')
set(clear_button2,'enable','off')
set(include_title2,'enable','off')
set(include_listbox2,'enable','off')
% set(AminusB_radio,'enable','off');
% set(BminusA_radio,'enable','off');


%% Boxes

manual_box=annotation('rectangle',[0.03 0.05 0.4 0.3],'EdgeColor','blue');

options_box=annotation('rectangle',[0.47 0.05 0.5 0.3],'EdgeColor','blue');

FILE_MENU=uimenu('Label','File');
% uimenu(FILE_MENU,'label','Load list...','Callback',@openList_Callback);
% uimenu(FILE_MENU,'label','Add File...','Accelerator', 'A','Callback',@addFile_Callback);
uimenu(FILE_MENU,'label','Close','Callback','closereq','Accelerator','W');


BATCH_MENU=uimenu('Label','Batch');
    START_BATCH=uimenu(BATCH_MENU,'label','Open New Batch','Callback',@START_BATCH_CALLBACK);
    STOP_BATCH=uimenu(BATCH_MENU,'label','Close Batch','Callback',@STOP_BATCH_CALLBACK);
    RUN_BATCH=uimenu(BATCH_MENU,'label','Run Batch...','separator','on','Callback',@RUN_BATCH_CALLBACK);
 

set(STOP_BATCH,'enable','off')            
set(RUN_BATCH,'enable','off')            

%% Callbacks

    function load_button_callback(src, evt)
       [filename pathname xxx]=uigetfile('*.list','Select text file containing normalized image filenames');
       if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        listFile = fullfile(pathname,filename);
        
        newlist = bw_read_list_file(listFile);
        list = [list; newlist];         %% append to list
        
        if ~isempty(list)
            set(include_listbox,'string',list);
            [numinlist garbage]=size(get(include_listbox,'string'));
            checkPermCount;
        end
       
        % new - CWD to path of list file in case of relative file paths
        %
        cd(pathname)
        fprintf('setting current working directory to %s\n',pathname);


    end

    function add_button_callback(src, evt)
       [filename pathname xxx]=uigetfile({'w*.nii','normalized NIfTI (w*.nii)'; ...
           '*.nii','NIfTI (*.nii)';...
           'w*.img','normalized Analyze (w*.img)';'*.svl','CTF SAM Volume (*.svl)'},'Select a normalized image file', 'Multiselect','on');
       if isequal(filename,0) || isequal(pathname,0) 
            return;
       end    
       
       filelist = cellstr(filename); % if only select one file it is not returned as cellstr
       [rows numFiles]  = size(filelist);
       
       for i=1:numFiles
           newFile = fullfile(pathname,filelist{i}) ; 
           list = [list; cellstr(newFile)];         %% append to list
       end
       
       if ~isempty(list)
            set(include_listbox,'string',list);
            [numinlist garbage]=size(get(include_listbox,'string'));
            
            % incremeent permutations 
            maxperm = numinlist^2;
            if maxperm > 2048
                maxperm = 2048;
            end
            set(max_perm_number,'string',maxperm);
            
            checkPermCount;
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
        checkPermCount;
    end

    function clear_button_callback(src,evt)
        list = {};
        numinlist = 0;
        set(include_listbox,'string','');
        set(manual_permute,'enable','off')
        set(manual_average,'enable','off')
        maxperm = 1024;  % reset default
        set(max_perm_number,'string',maxperm);
        alpha = 0.05;
        set(alpha_number,'string',alpha);
    end


    function load_button2_callback(src, evt)
       [filename pathname xxx]=uigetfile('*.list','Select text file containing normalized image filenames');
       if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        listFile = fullfile(pathname,filename);
        
        newlist = bw_read_list_file(listFile);
        list2 = [list2; newlist];         %% append to list
        
        if ~isempty(list2)
            set(include_listbox2,'string',list2);
            [numinlist2 garbage]=size(get(include_listbox2,'string'));
            checkPermCount;
       end

    end

    function add_button2_callback(src, evt)
       [filename pathname xxx]=uigetfile({'w*.nii','normalized NIfTI (w*.nii)'; ...
           '*.nii','NIfTI (*.nii)';...
           'w*.img','normalized Analyze (w*.img)'},'Select a normalized image file', 'Multiselect','on');
       if isequal(filename,0) || isequal(pathname,0)
            return;
       end
       
       filelist = cellstr(filename); % if only select one file it is not returned as cellstr
       [rows numFiles]  = size(filelist);
       
       for i=1:numFiles
           newFile = fullfile(pathname,filelist{i}) ; 
           list2 = [list2; cellstr(newFile)];         %% append to list
       end
        
        if ~isempty(list2)
            set(include_listbox2,'string',list2);
            [numinlist2 garbage]=size(get(include_listbox2,'string'));
            checkPermCount;
       end

    end

    function delete_button2_callback(src,evt)
        if isempty(list2)
            return;
        end
        selecteditem = get(include_listbox2,'value');
        list2(selecteditem,:) = []; 
        selecteditem = 1;
                
        set(include_listbox2,'string',list2);
        set(include_listbox2,'value',selecteditem); 
        checkPermCount;
    end


    function clear_button2_callback(src,evt)
        list2 = [];
        numinlist2 = 0;
        set(include_listbox2,'string','')
        set(manual_permute,'enable','off')
        set(manual_average,'enable','off')
        maxperm = 2048;  % reset default
        set(max_perm_number,'string',maxperm);
        alpha = 0.05;
        set(alpha_number,'string',alpha);
    end

    function manual_average_callback(src,evt)        
        make_images(true);
    end


    function manual_permute_callback(src,evt)
        make_images(false);
    end

    function display_image_callback(src,evt)
        displaycheck=get(src,'value');
    end


    function create_diff_check_callback(src,evt)
        makeContrasts=get(src,'value');
        if makeContrasts
            set(load_button2,'enable','on')
            set(add_button2,'enable','on')
            set(delete_button2,'enable','on')
            set(clear_button2,'enable','on')
            set(include_title2,'enable','on')
            set(include_listbox2,'enable','on')
%             set(AminusB_radio,'enable','on');
%             set(BminusA_radio,'enable','on');
        else
            set(load_button2,'enable','off')
            set(add_button2,'enable','off')
            set(delete_button2,'enable','off')
            set(clear_button2,'enable','off')
            set(include_title2,'enable','off')
            set(include_listbox2,'enable','off')
%             set(AminusB_radio,'enable','off');
%             set(BminusA_radio,'enable','off');
        end
    end

%     function AminusB_callback(src,evt)
%         pos_contrast = get(AminusB_radio,'value');
%     end
%     function BminusA_callback(src,evt)
%         neg_contrast = get(BminusA_radio,'value');
%      end
        

    function useROI_callback(src,evt)
        useROI=get(src,'value');
        if useROI
            set(ROI_XMIN,'enable','on');
            set(ROI_XMAX,'enable','on');
            set(ROI_YMIN,'enable','on');
            set(ROI_YMAX,'enable','on');
            set(ROI_ZMIN,'enable','on');
            set(ROI_ZMAX,'enable','on');
        else
            set(ROI_XMIN,'enable','off');
            set(ROI_XMAX,'enable','off');
            set(ROI_YMIN,'enable','off');
            set(ROI_YMAX,'enable','off');
            set(ROI_ZMIN,'enable','off');
            set(ROI_ZMAX,'enable','off');
        end    
    end

    function xmin_callback(src,evt)
        xmin=str2num(get(src,'string'));
    end
    function xmax_callback(src,evt)
        xmax=str2num(get(src,'string'));
    end
   function ymin_callback(src,evt)
        ymin=str2num(get(src,'string'));
    end
    function ymax_callback(src,evt)
        ymax=str2num(get(src,'string'));
    end
   function zmin_callback(src,evt)
        zmin=str2num(get(src,'string'));
    end
    function zmax_callback(src,evt)
        zmax=str2num(get(src,'string'));
    end

    function clear_callback(src,evt)
        list = [];
        numinlist = 0;
        set(include_listbox,'string','');
        list2 = [];
        numinlist2 = 0;
        set(include_listbox2,'string','')
        set(manual_permute,'enable','off')
        set(manual_average,'enable','off')
        maxperm = 1024;  % reset default
        set(max_perm_number,'string',maxperm);
        alpha = 0.05;
        set(alpha_number,'string',alpha);
    end


    function alpha_number_callback(src,evt)       
        t=str2num(get(src,'string'));
        if (1/maxperm) > t
            fprintf('Insufficient number of permutations for that alpha level ...\n');
            set(alpha_number,'string',alpha);
            return;
        end
        alpha = t;
        checkPermCount;
    end

    function max_perm_number_callback(src,evt)
        maxperm=str2num(get(src,'string'));
        if maxperm > 2^numinlist
            maxperm=2^numinlist;
            set(max_perm_number,'string',maxperm);
        end
        if (1/maxperm) > alpha
            set(manual_permute,'enable','off')
        else
            set(manual_permute,'enable','on')
        end
    end

    function cancel_callback(src,evt)
        close(f)
    end

    function make_images(averageOnly)

        if batchJobs.enabled
            ok = bw_warning_dialog('Add to batch?');
            if ok
                [parentfile, parentpath, ~] = uigetfile('*_IMAGES.mat','Pick original group imageset from which normalized images were chosen:');
                if ~isequal(parentfile,0)
                  file_prefix = strrep(parentfile, '.mat','_');
                else
                  file_prefix = '';
                end
                
                [filename,pathname,filterindex]=uiputfile('*','Enter filename for Group Image:');
                if isequal(filename,0)
                    return;
                end
                filename = sprintf('%s%s', file_prefix, filename);
                averageName=fullfile(pathname,filename);

                images=get(include_listbox,'string');      
                if makeContrasts
                    images2=get(include_listbox2,'string');
                else
                    images2 = [];
                end

                if useROI
                    roi = [xmin xmax ymin ymax zmin zmax];
                else
                    roi = [];
                end

                p = alpha;
                maxp = maxperm;
                                  
                plotAll = displaycheck;


                fprintf('adding group average job %s to batch process...\n', averageName);

                % make sure user doesn't overwrite group images
                if  batchJobs.numJobs > 0
                    for i=1:batchJobs.numJobs
                        if strcmp( batchJobs.processes{i}.averageName, averageName)
                            errordlg('Error: Duplicate group image name. Please choose another', 'Batch Processing');
                            return;
                        end
                    end
                end

                batchJobs.numJobs = batchJobs.numJobs + 1;
                batchJobs.processes{batchJobs.numJobs}.averageName = averageName;
                batchJobs.processes{batchJobs.numJobs}.images = images;             
                batchJobs.processes{batchJobs.numJobs}.images2 = images2;             
                batchJobs.processes{batchJobs.numJobs}.roi = roi;
                batchJobs.processes{batchJobs.numJobs}.p = p; 
                batchJobs.processes{batchJobs.numJobs}.maxp = maxp; 
                batchJobs.processes{batchJobs.numJobs}.plotAll = plotAll; 
                batchJobs.processes{batchJobs.numJobs}.averageOnly = averageOnly; 

                s = sprintf('Close Batch (%d jobs)', batchJobs.numJobs);
                set(STOP_BATCH,'label',s);      

            end
        else
            [parentfile, parentpath, ~] = uigetfile('*_IMAGES.mat','Pick original group imageset from which normalized images were chosen:');
            if ~isequal(parentfile,0)
               file_prefix = strrep(parentfile, '.mat','_');
            else
               file_prefix = '';
            end
            
            [filename,pathname,filterindex]=uiputfile('*','Enter filename for Group Image:');
            if isequal(filename,0)
                return;
            end
            filename = sprintf('%s%s', file_prefix, filename);
            averageName=fullfile(pathname,filename);

            images=get(include_listbox,'string');      
            if makeContrasts
                images2=get(include_listbox2,'string');
            else
                images2 = [];
            end

            if useROI
                roi = [xmin xmax ymin ymax zmin zmax];
            else
                roi = [];
            end

            p = alpha;
            maxp = maxperm;
            plotAll = displaycheck;

            generate_groupImages(averageName, images, images2, roi, p, maxp, plotAll, averageOnly);
        end
    end


    function checkPermCount
        
        maxperm=str2num(get(max_perm_number,'string'));
        if maxperm > 2^numinlist
            maxperm=2^numinlist;
            set(max_perm_number,'string',maxperm);
        end
        
        if (1/maxperm) > alpha
            set(manual_permute,'enable','off')
        else
            set(manual_permute,'enable','on')
        end
        
        if numinlist == 0
            set(manual_permute,'enable','off')
            set(manual_average,'enable','off')
        else
            set(manual_permute,'enable','on')
            set(manual_average,'enable','on')
        end
        
        if makeContrasts ~= 0
            if (numinlist2 < numinlist)
                maxperm=str2num(get(max_perm_number,'string'));
                if maxperm > 2^numinlist2
                    maxperm=2^numinlist2;
                    set(max_perm_number,'string',maxperm);
                end
                
                if (1/maxperm) > alpha
                    set(manual_permute,'enable','off')
                else
                    set(manual_permute,'enable','on')
                end
            end
%             if numinlist ~= numinlist2
%                 set(manual_permute,'enable','off')
%                 set(manual_average,'enable','off')
%             end
            
        end

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
        s = sprintf('%d permutations will be generated.  Do you want to run these now?', numJobs);
        ok = bw_warning_dialog(s);
          
        if ok
            for i=1:numJobs
                fprintf('\n\n*********** Running job %d ***********\n\n', i);
                averageName = batchJobs.processes{i}.averageName;
                images = batchJobs.processes{i}.images;
                images2 = batchJobs.processes{i}.images2;
                roi = batchJobs.processes{i}.roi;
                p = batchJobs.processes{i}.p;
                maxp = batchJobs.processes{i}.maxp;
                plotAll = batchJobs.processes{i}.plotAll;
                averageOnly = batchJobs.processes{i}.averageOnly;

                generate_groupImages(averageName, images, images2, roi, p, maxp, plotAll, averageOnly);
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


function generate_groupImages(averageName, images, images2, roi, permAlpha, permMax, plotImages, averageOnly)
    
    numimages=size(images);
    numimages2=size(images2);

    if ~isempty(images2)
        makeDiff = true;
    else
        makeDiff = false;
    end
   
    if makeDiff && (numimages(1) ~= numimages2(1))
        fprintf('Lists must contain an equal number or images to create contrasts...\n')
        return;
    end
    
    [PATHSTR,NAME1,EXT] = bw_fileparts( char(images(1,:)));
  
    if ~strcmp(EXT,'.svl') && ~strcmp(EXT,'.nii')
        fprintf('Images must be in either NIfTI (.nii) or CTF SVL (.svl) format...\n');  
        return;
    end
    
    % check for SVL file type
    if strcmp(EXT,'.svl')
        
        if (makeDiff || ~averageOnly )        
            fprintf('*** Contrasts and permutations not currently supported for svl files.... ***\n');  
            return;
        end
        
        fprintf('***Warning: Group averaging non template normalized SAM volume (.svl) images.\n');
        fprintf('   Averaging across subjects may not produce valid results... ***\n');  
       %  make a list of the files to be averaged 
        listName = strcat(averageName,'.list');
        fid=fopen(listName,'w');
        for n=1:numimages(1,1)         
            file = char(images(n,:));
            fprintf(fid,'%s\n', file);
            % if plot individual images selected
            if plotImages
                bw_mip_plot_4D(file);
            end
        end
        fclose(fid);
       
        outfilename = strrep(listName,'.list','.svl');
        
        bw_averageSvlFiles(listName,outfilename);
        bw_mip_plot_4D(outfilename);
        return;   
    
    end
    

    % new in 2.4 - can make both contrasts at once
       
    % if no contrast
    if ~makeDiff
        listName = strcat(averageName,'.list');
        fid=fopen(listName,'w');
        for n=1:numimages(1,1)         
            file = char(images(n,:));
            fprintf(fid,'%s\n', file);
            % if plot individual images selected
            if plotImages
                bw_mip_plot_4D(file);
            end
        end
        fclose(fid);

        if (averageOnly)
            bw_grand_average_image_files(listName);
        else    
            if ~isempty(roi)
                fprintf('Using bounding box ...%d %d %d %d %d %d\n', roi);
            else
                roi = [];
            end

            % Dec 2011: if making difference images (contrast) the permute
            % routine was modified to only show the positive sig. values  This 
            % caused a problem if permuting a single condition for differential 
            % images that had ONLY negative sig values. Changed routine code to
            % optionally include neg sign. values in this case.
 
            showNeg = true;
            bw_permute_image_files(listName, permAlpha, permMax, roi, showNeg)
        end
        
        return;
    end
    
    
    fprintf('Creating contrasts...\n')   
    for k=1:2        
        if k==1
            fprintf('Creating positive contrasts ....\n');    
            listName = strcat(averageName,'_A-B.list');
        elseif k==2
            fprintf('Creating negative contrasts ....\n');    
            listName = strcat(averageName,'_B-A.list');
        else
            continue;
        end
        
        fid=fopen(listName,'w');

        for n=1:numimages(1,1)         
            file = char(images(n,:));
                fileA = file;
                fileB = char(images2(n,:));

            % create diff name .....
            [PATHSTR,NAME1,EXT] = bw_fileparts(fileA);
            [PATHSTR,NAME2,EXT] = bw_fileparts(fileB);
            if k==2
                file = sprintf('subj_%d_%s-%s%s', n, NAME2, NAME1, EXT);
                bw_make_contrast_image(fileB, fileA, file); 
            else
                file = sprintf('subj_%d_%s-%s%s', n, NAME1, NAME2, EXT);
                bw_make_contrast_image(fileA, fileB, file); 
            end
            fprintf(fid,'%s\n', file);

            % if plot individual images selected
            if plotImages
                bw_mip_plot_4D(file);
            end
        end

        fclose(fid);

        if (averageOnly)
            bw_grand_average_image_files(listName);
        else    
            if ~isempty(roi)
                fprintf('Using bounding box ...%d %d %d %d %d %d\n', roi);
            else
                roi = [];
            end
            showNeg = false;  % note we display both pos and neg contrasts as positive scale.
            bw_permute_image_files(listName, permAlpha, permMax, roi, showNeg)
        end
    end
    
end