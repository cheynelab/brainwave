%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function bw_mip_plot_4D(file, init_threshold)
%   bw_mip_plot_4D(file, init_threshold)
%
%   DESCRIPTION: Creates a GUI with glass brain plots from beamformer 
%   images of standard and normalized data. It can plot both .svl images as 
%   well as normalized analyze (w*.img) images, as single files or from a 
%   text (.txt) based list file. It also has lots of interactive features 
%   such as a cursor (double click to select any point on the images), peak 
%   labels and being able to save files as movies.
% 
% (c) D. Cheyne, August 2010. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%   major rewrite for Version 4.0  Jan, 2022
%   - added dragable cursors, new overlay options, eliminated unused variables
%
%
%   D. Cheyne revised July 2011,
%   - added option to pass an specified threshold for popping up e.g.,
%   thresholded images  
%
% revised Sept, 2010 
%
% release version 3.3
% D. Cheyne
% made several changes
% fixed cursor drawing, adjusted origin slightly
% made image parameters a struct for easier reading
% changed view behaviour to open another window for normalized view
%
%   --VERSION 3.3--
% Last Revised by zhengkai on 21/12/2011
% Changes: fileSep definition used for universal operating systems.
% 
% Last Revised by N.v.L. on 07/07/2010
% Major Changes: now passes the mri file selected in bw_start to
% bw_mriview.
%
% Revised by N.v.L. on 06/07/2010
% Major Changes: Got rid of all the plot VS stuff and moved the logo.
%
% Revised by N.v.L. on 23/06/2010
% Major Changes: Changed help file and cleaned the function up a bit. Added
% in the mri view.
%
%
% Revised by N.v.L. on 31/05/2010
% Major Changes: Now displays logo in GUI.
%
% Revised by N.v.L. on 28/05/2010
% Major Changes: When no coordinate is shown in images, the coordinate list
% will now be blank (and disabled). Got rid of all global variables except
% "global_voxel" which is an acceptable because users are warned to
% click the coordinates -every time- they wish to plot a virtual sensor,
% regardless of how many windows are open. Also instead of going from
% not visible to visible, the "vs parameters" and "plot vs" buttons now
% become enabled and or disabled. Will now grab and play a movie of everything 
% if you selected "Option:Save as movie" and will display in red letters 
% what it's doing, save the movie as avi file (with the threshold value included) and finally return to where 
% it was before so that you may continue using the GUI. Did some
% colour/font changes. the GUI displays an error message when attempting to
% plot vs with normalized data.
%
% Revised by N.v.L. on 26/05/2010
% Major Changes: moved most of the options around and added in labels for
% threshold slider. I also fixed it so that the "maximum edit" goes back to
% the total maximum when "autoscale" is unchecked. Made it so that title to
% "maximum =" changes between "Overall maximum" and "Image maximum"
% depending on whether auto scale is checked or not. When on "overall
% maximum" it now says at what time this maximum is. There is now a
% select/scroll box for the peak coordinates and a button to click that'll
% allow you to plot the coordinates you -select- to be plotted using
% bw_make_vs_mex. Fixed update problem for max. Added in a new input called
% "vs_parameters" and a corresponding button which will allow the user to
% change the parameters for plotting a vs.
% 
% Revised by N.v.L. on 17/05/2010
% Major Changes: Changed help file.
%
% Written by D. Cheyne on --/01/2010 for Hospital for Sick Children
%
% shared (global to this window) image parameters    
%
% Feb 2022 - major rewrite for Version 4.0
%

global g_peak
global addPeakFunction
global PLOT_WINDOW_OPEN

global BW_PATH;

t = load('spm2_grid.mat');
spm2_grid = t.spm2_grid;

% init global vars
PAR.XYZ = [];
PAR.DIM = [];
PAR.RES = [];
PAR.SPM_ORIGIN = [];
PAR.ZDATA = [];
PAR.IS_NORMALIZED = false;
PAR.HAS_NEG = false;
PAR.DATA_MAX = 1;
PAR.THRESH = 0;
PAR.SHOW_PEAKS = false;
PAR.AUTO_SCALE = false;
PAR.PLOT_NEG = false;
PAR.MAX_PEAKS = 20; % limit peak search to avoid hanging..
PAR.PEAK_SR = 10;  % search radius in mm

thresholdPercent = 0.25;

% all shared variables have to be initialized...
% GUI params (don't need to be passed)
IMAGE_NO = 1;
SUBJECT_NO = 1;
FILE_LIST = [];  
NUM_SUBJECTS = 1;


imageset = [];

currentfilename = ''; 
LIST_PEAK_SCROLL=[];
LIST_PEAK_TEXT = [];
CURRENT_PEAK = [];
PLOT_PEAK = [];
useSearchRadius = 0;

coordtype = 1;
   
dataset='';
filename='';
pathname='';
imagesetName = '';
imagesetPath = '';


params = [];
sampleRate = [];
dataRange = [];
isPlaying = 0;


% ** new cursor routines
cursorPosition = [0 -10 50];       % cursor position in mm (x,y,z)
% cursor handles
sagCursorV = [];
sagCursorH = [];
corCursorV = [];
corCursorH = [];
axiCursorV = [];
axiCursorH = [];

% axes handles for each plot
corAxes = 0;        
sagAxes = 0;
axiAxes = 0;

xstart = 0;
ystart = 0;
zstart = 0;
xend = 0; 
yend = 0;
zend = 0;


max_Talairach_SR = 5;   % search radius for talairach gray matter labels
template_MRI_Name = 'ch2_SURFACE.mat';

% open figure window

tstr = sprintf('BrainWave - 4D Image Viewer');

scrnsizes=get(0,'MonitorPosition');
    
% persistent counter to move figure
persistent figcount;

if isempty(figcount)
    figcount = 0;
else
    figcount = figcount+1;
end

% tile windows
width = 900;
height = 700;
start = round(0.05 * scrnsizes(1,3));
bottom_start = round(0.08 * scrnsizes(1,4));

inc = figcount * 0.015 * scrnsizes(1,3);
left = start+inc;
bottom = bottom_start + inc;

if ( (left + width) > scrnsizes(1,3) || (bottom + height) > scrnsizes(1,4)) 
    figcount = 0;
    left = start;
    bottom = bottom_start;
end

hMainFigure=figure('Name', tstr, 'Position',...
        [left,bottom,width,height],'menubar','none','numbertitle','off',...
        'Color','white','WindowButtonUpFcn',@stopdrag,'WindowButtonDownFcn',@buttondown, 'CloseRequestFcn',@closeGUI);

if ispc
    movegui(hMainFigure,'center');
end


% create menus

FILE_MENU=uimenu('Label','File');
uimenu(FILE_MENU,'label','Load Imageset ...','Accelerator','O','Callback',@loadImageSetCallback);

uimenu(FILE_MENU,'label','Save Images...','separator', 'on','Accelerator','S','Callback',@save_images_Callback);
SAVE_THRESHOLDED_IMAGE_MENU=uimenu(FILE_MENU,'label','Save Thresholded Image...','Callback',@save_thresholded_image_Callback);

uimenu(FILE_MENU,'label','Save Image List...','Callback',@save_image_list_Callback,'separator', 'on');
uimenu(FILE_MENU,'label','Save Figure...','Callback',@save_Callback);
SAVE_MOVIE_AVI_MENU=uimenu(FILE_MENU,'Label','Save as Movie ...','Callback',@saveMovie_Callback,'Accelerator','M');

uimenu(FILE_MENU,'label','Overlay Images on MRI...','Callback',@openOverlay_Callback, 'separator', 'on');
render_menu = uimenu(FILE_MENU,'label','Overlay Images on Surface');
uimenu(render_menu,'label','fsaverage','Callback',@plotSurfaceImage);
uimenu(render_menu,'label','Surfaces File...','Callback',@plotSurfaceImage);

uimenu(FILE_MENU,'label','Show Data Parameters...','Callback',@showParameters_callback,'separator', 'on');

uimenu(FILE_MENU,'label','Preferences...','Callback',@prefs_Callback, 'separator', 'on');
uimenu(FILE_MENU,'label','Print','Callback',@print_Callback,'Accelerator','P', 'separator', 'on');
uimenu(FILE_MENU,'label','Close','Callback','closereq','Accelerator','W','separator', 'on');
    
DATA_SOURCE_MENU = uimenu('Label','Data Source');

% create controls
    
% if no files passed open dialog

LIST_LABEL = uicontrol('style','text','units', 'normalized',...
	'position',[0.15 0.95 0.8 0.03 ],'FontUnits','normalized',...%'FontSize',9,
    'HorizontalAlignment','left','BackGroundColor','white',...
    'ForegroundColor','blue','FontWeight','b');

SUBJECT_LABEL = uicontrol('style','text','units', 'normalized',...
	'position',[0.15 0.92 0.8 0.03 ],'FontUnits','normalized',...%'FontSize',9,
    'HorizontalAlignment','left','BackGroundColor','white',...
    'ForegroundColor','blue','FontWeight','b');

LATENCY_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.13 0.01 0.3 0.04],'min',1,'max',2,'Value',1,...
    'sliderStep', [1 3],'BackGroundColor','white','ForeGroundColor',...
    'white','callback',@latency_Callback);

latStr = '';
LATENCY_TEXT = uicontrol('style','text','units', 'normalized',...
    'position',[0.13 0.05 0.8 0.04 ],'FontSize',...
    12, 'HorizontalAlignment','left','BackGroundColor', 'white', 'string',latStr);

LOOP_BUTTON = uicontrol('style','pushbutton','units', 'normalized',...
    'position',[0.44 0.025 0.06 0.03],'String','LOOP','FontWeight','bold','FontSize',12,...
    'HorizontalAlignment','left','callback',@loop_Callback);

threshStr = sprintf('%.2f', thresholdPercent);
THRESH_EDIT = uicontrol('style','edit','units', 'normalized',...
    'position',[0.056 0.48 0.06 0.05],'String',threshStr,...
	'BackGroundColor','white','FontSize', 12,'callback',@threshEdit_Callback);
    
THRESH_TITLE=uicontrol('style','text','units', 'normalized',...
    'position',[0.054 0.53 0.1 0.03],'String','Threshold:',...
    'FontSize', 12, 'HorizontalAlignment','left','BackGroundColor','white');

% make slider steps small - fix for no scroll arrows on OS X Lion
THRESH_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.01 0.35 0.04 0.35],'min',0,'max',1.0,...
    'Value',thresholdPercent, 'sliderStep', [0.01 0.05],'BackGroundColor',...
    'white','callback',@slider_Callback);

ZERO_LABEL=uicontrol('style','text','units', 'normalized',...
    'position',[0.051 0.34 0.04 0.03],'String', '0.0','FontSize',...
    11,'BackgroundColor','white');

MAX_PERCENT_LABEL=uicontrol('style','text','units', 'normalized',...
    'position',[0.051 0.67 0.05 0.03],'String', '100 %','FontSize',...
    11,'BackgroundColor','white');

maxStr = sprintf('%.2f', PAR.DATA_MAX);
MAX_EDIT = uicontrol('style','edit','units', 'normalized',...
    'position',[0.9 0.52 0.06 0.04],'String',maxStr,'BackGroundColor',...
    'white','TooltipString','Enter Threshold','FontSize', 12,...
    'callback',@maxEdit_Callback);
    
MAX_TITLE = uicontrol('style','text','units', 'normalized',...
    'position',[0.73 0.5 0.16 0.05],'String','Max. =',...
    'FontSize', 11, 'HorizontalAlignment','right', 'BackGroundColor',...
    'white');
    
AUTO_SCALE_TOGGLE = uicontrol('style','checkbox','units', 'normalized',...
    'position',[0.9 0.47 0.12 0.05],'String','Autoscale',...
    'BackGroundColor','white','FontSize', 10,'Value',...
    PAR.AUTO_SCALE,'callback',@autoScale_Callback);

PLOT_POS_RADIO = uicontrol('style','radio','units', 'normalized',...
    'position',[0.56 0.48 0.14 0.05],'String','Plot positive',...
    'BackGroundColor','white','FontSize', 10,'Value', ~PAR.PLOT_NEG,...
    'callback',@posToggle_Callback);

PLOT_NEG_RADIO = uicontrol('style','radio','units', 'normalized',...
    'position',[0.66 0.48 0.14 0.05],'String','Plot negative',...
    'BackGroundColor','white','FontSize', 10,'Value', PAR.PLOT_NEG,...
    'callback',@negToggle_Callback);

        
uicontrol('style','text','units', 'normalized',...
    'position',[0.56 0.43 1.0 0.04 ],'FontSize', 12,...
    'HorizontalAlignment','left','BackGroundColor', 'white', 'string','Cursor:');
s = sprintf('Coordinates = %d %d %d cm', round(cursorPosition));
CURSOR_TEXT = uicontrol('style','text','units', 'normalized',...
    'position',[0.56 0.39 1.0 0.04 ],'FontSize', 12,...
    'HorizontalAlignment','left','BackGroundColor', 'white', 'string','');

BA_TEXT = uicontrol('style','text','units', 'normalized',...
    'position',[0.56 0.36 1.0 0.04 ],'FontSize', 12,...
    'HorizontalAlignment','left','BackGroundColor', 'white', 'string','');

MAG_TEXT = uicontrol('style','text','units', 'normalized',...
    'position',[0.56 0.33 1.0 0.04 ],'FontSize', 12,...
    'HorizontalAlignment','left','BackGroundColor', 'white', 'string','');

SHOW_PEAK_DROPDOWN = uicontrol('style','popup','units','normalized',...
    'position',[0.65 0.42 0.2 0.05],'String','CTF Coords (cm)',...
    'Backgroundcolor','white','fontsize',11,'value',1,...
    'callback',@peakDropdown_Callback);

PLOT_PEAK = uicontrol('style', 'PushButton', 'units',...
    'normalized','position', [0.56 0.29 0.18 0.045],...
    'FontSize', 10,'string','Plot Virtual Sensor','ForegroundColor','blue',...
    'callback',@plot_peak_callback);

SHOW_PEAK_TOGGLE = uicontrol('style','checkbox','units', 'normalized',...
    'position',[0.56 0.22 0.1 0.05],'String','Find peaks',...
    'BackGroundColor','white','FontSize', 10,'Value',PAR.SHOW_PEAKS,...
    'callback',@peakToggle_Callback);

USE_SR_TOGGLE = uicontrol('style','checkbox','units', 'normalized',...
    'position',[0.75 0.29 0.18 0.05],'String','Use Search Radius',...
    'BackGroundColor','white','FontSize', 10,'Value',useSearchRadius,...
    'callback',@useSRToggle_Callback);

LIST_PEAK_TEXT = uicontrol('style', 'text','units','normalized','String','X     Y      Z     Mag.',...
    'horizontalAlignment','left','position', [0.57 0.2 0.35 0.03],...
    'FontSize',10,'BackgroundColor','white');

LIST_PEAK_SCROLL = uicontrol('style', 'listbox', 'units',...
    'normalized','position', [0.56 0.03 0.42 0.15],'Background',...
    'White', 'FontSize', 10,'string','','callback',@peak_scroll_callback);

function closeGUI(src,~)
	temp=get(src,'position');
	oldfigcount=temp(1)/0.1/scrnsizes(1,3)-1;
	figcount=oldfigcount;
	delete(hMainFigure);
end

function loadImageSetCallback(~,~)
    [filename, pathname]=uigetfile(...
        {'*IMAGES.mat','IMAGESET (*IMAGES.mat)'},...
        'Select file(s)...');
    if isequal(filename,0)
        return;
    end

    file = fullfile(pathname, filename);
    loadImageSet(file);

end

 
if ~exist('file','var')
    loadImageSetCallback;
else
    loadImageSet(file);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% menu callbacks             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    function prefs_Callback(~, ~)
        
        scrsz=get(0,'ScreenSize');
        f2=figure('Name', 'Preferences', 'Position', [(scrsz(3)-500)/2 (scrsz(4)-250)/2 600 300],...
            'menubar','none','numbertitle','off', 'color','white');
        
        uicontrol('style','text','units','normalized','position',[0.08 0.75 0.5 0.2],'horizontalalignment','left',...
            'string','Grey Matter Search Radius (mm): ','fontsize',12,'backgroundColor','white','FontWeight','normal');
        
        SR_value = uicontrol('style','edit','units','normalized','position',...
            [0.6 0.85 0.1 0.12],'String', max_Talairach_SR,...
            'FontSize', 12,'backgroundColor','white');


        uicontrol('style','text','units','normalized','position',[0.08 0.55 0.5 0.2],'horizontalalignment','left',...
            'string','Minimum Separation between Peaks (mm): ','fontsize',12,'backgroundColor','white','FontWeight','normal');
        
        uicontrol('style','edit','units','normalized','position',...
            [0.6 0.65 0.1 0.12],'String', PAR.PEAK_SR,...
            'FontSize', 12,'backgroundColor','white');     
 
        uicontrol('style','text','units','normalized','position',[0.08 0.35 0.5 0.2],'horizontalalignment','left',...
            'string','Maximum Number of Peaks: ','fontsize',12,'backgroundColor','white','FontWeight','normal');
        
        MAX_PEAK_value = uicontrol('style','edit','units','normalized','position',...
            [0.6 0.45 0.1 0.12],'String', PAR.MAX_PEAKS,...
            'FontSize', 12,'backgroundColor','white');     
        
        
        
        uicontrol('style','text','units','normalized','position',[0.08 0.15 0.5 0.2],'horizontalalignment','left',...
            'string','Template MRI File: ','fontsize',12,'backgroundColor','white','FontWeight','normal');
        
        template_name = uicontrol('style','edit','units','normalized','position',...
            [0.32 0.25 0.5 0.12],'String', template_MRI_Name,...
            'FontSize', 12,'backgroundColor','white');
        
        uicontrol('style','pushbutton','units','normalized','position',...
            [0.85 0.25 0.1 0.12],'String', 'Select',...
            'FontSize', 12,'backgroundColor','white', 'callback', @templateButtonCallback);
        
        uicontrol('Units','Normalized','Position',[0.8 0.05 0.12 0.12],'String','OK',...
            'FontSize',12,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@save_callback);
          
        uicontrol('Units','Normalized','Position',[0.6 0.05 0.12 0.12],'String','Cancel',...
            'FontSize',12,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@cancel_callback);

                
        function save_callback(~, ~) 
                max_Talairach_SR = str2double(get(SR_value,'string'));
                PAR.MAX_PEAKS = str2double(get(MAX_PEAK_value,'string'));
                template_MRI_Name = get(template_name,'string');
                uiresume(f2);        
                close(f2);            
        end
        
        function templateButtonCallback(~, ~) 
            template_path=strcat(BW_PATH,filesep,'template_MRI/');
            [filename, pathname]=uigetfile({'*_SURFACE.mat','BrainWave Surface (*_SURFACE.mat)'},...
                'Select template file...', template_path);
            if isequal(filename,0) || isequal(pathname,0)
                file = [];
                return;
            end
            set(template_name,'string',filename);
        end

        function cancel_callback(~, ~)
            uiresume(f2);        
            close(f2); 
        end
        
        uiwait(f2);
        
        updateDisplay;
              
    end


   function loadImageSet(file)
       
        imageset = [];
        params = bw_setDefaultParameters;
         
        [imagesetPath, imagesetName, ext] = bw_fileparts(file);
        imagesetNameShort = strcat(imagesetName,ext);
        s = sprintf('%s', imagesetNameShort);
        set(LIST_LABEL,'String',s);

        imageset = load(file);

        NUM_SUBJECTS = imageset.no_subjects;

        % display average
        if NUM_SUBJECTS > 1
            SUBJECT_NO = 0;
            FILE_LIST = char(imageset.averageList);
        else
            SUBJECT_NO = 1;
            FILE_LIST = char(imageset.imageList(SUBJECT_NO));
        end           

        numFiles = size(FILE_LIST,1);
            
        % reset params
        PAR.XYZ = [];
        PAR.DIM = [];
        PAR.RES = [];
        PAR.SPM_ORIGIN = [];
        PAR.ZDATA = [];
        PAR.IS_NORMALIZED = false;
        PAR.HAS_NEG = false;
        PAR.DATA_MAX = 1;
        PAR.THRESH = 0;
        PAR.SHOW_PEAKS = false;
        PAR.AUTO_SCALE = false;
        PAR.PLOT_NEG = false;

        IMAGE_NO = 1;
        currentfilename = ''; 

        g_peak = [];
         
        set(SHOW_PEAK_TOGGLE,'Value',0);
                
        dataset='';
        filename='';
        pathname='';          
        
        % override autothreshold..
        if exist('init_threshold','var')
            INIT_THRESH = init_threshold;
        else  
            INIT_THRESH = 0; 
        end
        
        tempList = FILE_LIST; % initData re-sorts list
        
        % init variables - also allocates memory for ZDATA
        [FILE_LIST, negOnly] = initData(tempList, PAR.PLOT_NEG, INIT_THRESH);

        if ~PAR.IS_NORMALIZED
            coordtype = 0;
            set(SHOW_PEAK_DROPDOWN,'String','CTF Coords (cm)','value',1); % for svl fix type 
            set(render_menu,'enable','off');
            set(SAVE_THRESHOLDED_IMAGE_MENU,'enable','off');
            set(USE_SR_TOGGLE,'enable','off');
        else
            coordtype = 2;
            set(SHOW_PEAK_DROPDOWN,'String','MNI Coords (mm) | Talairach Coords (mm) ','value',coordtype);
            set(render_menu,'enable','on');
            set(SAVE_THRESHOLDED_IMAGE_MENU,'enable','on');
            set(USE_SR_TOGGLE,'enable','on');
        end
                              
        if negOnly
            PAR.PLOT_NEG = true;
            set(PLOT_NEG_RADIO,'value',1);
            set(PLOT_POS_RADIO,'value',0);            
        end
        
        currentfilename = loadImageData(FILE_LIST, IMAGE_NO, PAR.PLOT_NEG);
                      
        if (numFiles > 1)
            set(LOOP_BUTTON,'visible','on')
            set(LATENCY_SLIDER,'visible','on');
            numFiles = size(FILE_LIST,1);
            step(1) = 1/(numFiles-1);
            % make single step - fix for no scroll arrows on OS X Lion
            step(2) = 1/(numFiles-1);
            % step(2) = 4/(numFiles-1);
            set(LATENCY_SLIDER,'max',numFiles,'Value',1,'sliderStep',step);
            set(SAVE_MOVIE_AVI_MENU,'enable','on');
        else
            set(LOOP_BUTTON,'visible','off')
            set(LATENCY_SLIDER,'visible','off');
            set(SAVE_MOVIE_AVI_MENU,'enable','off');
        end
        
        PAR.THRESH = PAR.DATA_MAX * thresholdPercent;
        set(THRESH_SLIDER,'max',1.0, 'Value', thresholdPercent );
        
        threshStr = sprintf('%.2f', thresholdPercent * 100.0 );
        set(THRESH_EDIT,'String',threshStr);
        
        PAR.AUTO_SCALE = false;
        set(AUTO_SCALE_TOGGLE,'Value',PAR.AUTO_SCALE);
        
        
        maxStr = sprintf('%.2f', PAR.DATA_MAX);
        set(MAX_EDIT,'String',maxStr);
        
        if ~PAR.HAS_NEG
            set(PLOT_NEG_RADIO,'enable','off');
        else
            set(PLOT_NEG_RADIO,'enable','on');
        end

        
        %plot latency label
        [~, label] = bw_get_latency_from_filename(currentfilename);
        set(LATENCY_TEXT,'string',label);
        
        if ~contains(currentfilename,'ANALYSIS')
            currentfilename=[pathname,currentfilename];
        end
        
        set(LIST_PEAK_SCROLL,'Value',1);

        % build data menu
        if exist('DATA_SOURCE_MENU','var')
            delete(DATA_SOURCE_MENU);
            clear DATA_SOURCE_MENU;
        end
        
        DATA_SOURCE_MENU = uimenu('Label','Data');
        for i=1:NUM_SUBJECTS
            if imageset.params.beamformer_parameters.contrastImage
                s = sprintf('%s-%s',char(imageset.dsName{i}), char(imageset.contrastDsName{i}) );
            else
                s = sprintf('%s', char(imageset.dsName(i)));
            end
            uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','on','Callback',@data_menu_callback); 
        end

        if (NUM_SUBJECTS > 1)
            % uncheck all existing menus
            set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');

            uimenu(DATA_SOURCE_MENU,'Label','Group Average','Checked','on',...
                'separator','on','Callback',@data_menu_callback);        

            uimenu(DATA_SOURCE_MENU,'Label','Permute images...','Checked','off',...
                'separator','on','Callback',@permute_callback);        
            set(SUBJECT_LABEL,'String','Group Average');
        else
            if imageset.params.beamformer_parameters.contrastImage
                s = sprintf('Dataset:  %s-%s',char(imageset.dsName{SUBJECT_NO}), char(imageset.contrastDsName{SUBJECT_NO}) );
            else
                s = sprintf('Dataset:  %s', char(imageset.dsName(SUBJECT_NO)));
            end
            set(SUBJECT_LABEL,'String',s);
        end            

        % set default plot options
        dsName = char(imageset.dsName(1));

        params = bw_setDefaultParameters(dsName);
        params.vs_parameters.rms = imageset.params.vs_parameters.rms;
        params = imageset.params;
        header = bw_CTFGetHeader(dsName);            
        sampleRate = header.sampleRate;
        dataRange = [header.epochMinTime header.epochMaxTime];
        clear header;

           
        updateDisplay;
        drawCursors;
        
    end


   function data_menu_callback(src,~)      

       idx = get(src,'position');

        if idx == NUM_SUBJECTS + 1
            SUBJECT_NO = 0;
            FILE_LIST = char(imageset.averageList);
            set(SUBJECT_LABEL,'String','Group Average');
        else
            SUBJECT_NO = idx;
            FILE_LIST = char(imageset.imageList(SUBJECT_NO));
            if imageset.params.beamformer_parameters.contrastImage
                s = sprintf('Dataset:  %s-%s',char(imageset.dsName{SUBJECT_NO}), char(imageset.contrastDsName{SUBJECT_NO}) );
            else
                s = sprintf('Dataset:  %s', char(imageset.dsName(SUBJECT_NO)));
            end
            set(SUBJECT_LABEL,'String',s);
        end
 
        currentfilename = loadImageData(FILE_LIST, IMAGE_NO, PAR.PLOT_NEG);
        dataset=currentfilename(1,1:(find(currentfilename=='A')-2));
        
        if idx < NUM_SUBJECTS + 1
            [~, name, ext] = bw_fileparts(char(currentfilename));
            s = sprintf('File:  %s', strcat(name,ext));
%             set(IMAGE_LABEL,'String',s);
        end
        
        % update image
 
        % uncheck all menus
        set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');
        set(src,'Checked','on');

        if SUBJECT_NO == 0
            set(PLOT_PEAK,'String','Plot Group VS')
        else
            set(PLOT_PEAK,'String','Plot Virtual Sensor')
       end 
        
        updateDisplay;

   end

   function permute_callback(~,~)  
      
        for i=1:imageset.no_subjects
            tlist = char(imageset.imageList(i));
            perm_list{i} = tlist(IMAGE_NO,:);
        end
        
        % set perm parameters here...
         
        [result, perm_options] = bw_get_perm_options(imageset.no_subjects);
        
        if (result == 0)
            return;
        end
        
        [~, label] = bw_get_latency_from_filename(currentfilename);
            
        imagePrefix= sprintf('%s%s%s_%s',imagesetPath, filesep,imagesetName, label);
        
        bw_permute_images(perm_list', imagePrefix, perm_options);

   end

   function save_image_list_Callback(~,~)  
        if isempty(imageset)
           return;
        end

        [name,path,~] = uiputfile('*.list','Select Name for image list:','');
        if isequal(name,0)
            return;
        end   
        fname = fullfile(path,name);
        
        fid = fopen(fname,'w');
        
        for i=1:imageset.no_subjects
            tlist = char(imageset.imageList(i));
            image_name = tlist(IMAGE_NO,:);
            fprintf(fid,'%s\n',image_name);
        end
        
        fclose(fid);
        
          
   end
   
   function showParameters_callback(~,~)  
       
        if isempty(imageset)
           return;
        end
        
        % need a dsName for dialog - parameters are same for all subjects
        dsName = char(imageset.dsName(1));
        
        bw_set_data_parameters(params.beamformer_parameters, dsName,dsName);

   end


   function save_images_Callback(~,~)  
       
        if isempty(imageset)
           return;
        end
        
        defName = '*';
        [name,path,~] = uiputfile('*','Select Name for imageset:',defName);
        if isequal(name,0)
            return;
        end

        outDir = fullfile(path,name);
        outFile = strcat(name,'_VOLUME_IMAGES.mat');
        mkdir(outDir);

        outFileName = sprintf('%s%s%s',outDir,filesep,outFile);
        
        fprintf('Saving image data to file %s\n', outFileName);
                  
        save(outFileName,'-struct','imageset');             
               
   end

   function save_thresholded_image_Callback(~, ~)
       
        [filename, pathname, filterIndex] = uiputfile( ...
        {'*.nii','NIfTI file (*.nii)'; ...
        '*.img','Analyze file - LAS (*.hdr,*.img)'; ...
        '*.img','Analyze file - RAS (*.hdr,*.img)'}, ...
            'Save as','untitled');
                
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        saveName = fullfile(pathname, filename);
        
        fprintf('Saving thresholded image as %s\n', saveName);
     
        tempname = char( FILE_LIST(IMAGE_NO,:) );      
        [image, ~] = bw_read_SPM_file(tempname);
        
        zeroVoxels = find(abs(image.img) < PAR.THRESH);   
        image.img(zeroVoxels) = NaN;

        
        [~, filePrefix, ext] = fileparts(saveName);        
        if strcmp(ext,'.nii')
            save_nii(image,saveName);
        elseif strcmp(ext,'.img')
            
            % create an Analyze header
            hdr = image.hdr;
            avw.hdr = bw_create_spm_header; 

            % copy the relevant structures
            avw.hdr.dime.dim = hdr.dime.dim;
            avw.hdr.dime.pixdim = hdr.dime.pixdim;
            avw.hdr.dime.datatype = hdr.dime.datatype;
            avw.hdr.dime.bitpix = hdr.dime.bitpix;
            avw.hdr.dime.glmin = hdr.dime.glmin;
            avw.hdr.dime.glmax = hdr.dime.glmax;

            avw.hdr.hist.descrip = hdr.hist.descrip;
            avw.hdr.hist.originator = hdr.hist.originator;
            
            avw.fileprefix = filePrefix;
            if filterIndex == 2
                fprintf('flipping image to LAS orientation\n');
                avw.img = flipdim(image.img,1);
            else
                avw.img = image.img;
            end   
            bw_write_spm_analyze(avw, avw.fileprefix);
        end           
        
    end

    function save_Callback(~, ~)
        [filename, pathname, ~] = uiputfile( ...
            {'*.eps','Postscript file (*.eps)';...
             '*.jpg','JPEG image(*.jpg)';...
             '*.tif','TIFF image, uncompressed (*.tif)';...
            '*.png','Portable Network Graphics (*.png)';...
            '*.bmp','Bitmap image (*.bmp)';...
            '*.pdf','Portable Document File (*.pdf)'}, ...
            'Save as','untitled');
        
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
        saveName = fullfile(pathname, filename);
        
        [~,~,EXT] = bw_fileparts(saveName);
        
        
        set(LATENCY_SLIDER,'visible','off');
        set(THRESH_SLIDER,'visible','off');
        updateDisplay;
        
       
        if (strcmp(EXT,'.eps'))
            saveas(hMainFigure, saveName, 'epsc');
        elseif (strcmp(EXT,'.jpg'))
            saveas(hMainFigure, saveName, 'jpg');
        elseif (strcmp(EXT,'.png'))
            saveas(hMainFigure, saveName, 'png');
        elseif (strcmp(EXT,'.tif'))
            saveas(hMainFigure, saveName, 'tif');
        elseif (strcmp(EXT,'.bmp'))
            print(hMainFigure, '-dbmp', [saveName]);
        elseif (strcmp(EXT,'.pdf'))
            saveas(hMainFigure, saveName, 'pdf');
        end
        
        set(LATENCY_SLIDER,'visible','on');
        set(THRESH_SLIDER,'visible','on');
        updateDisplay;
        
    end

    function print_Callback(~, ~)
        printdlg('-crossplatform', hMainFigure);
    end


    function saveMovie_Callback(~, ~)      

        [mname, path, filterIndex] = uiputfile( ...
        {'*.avi','AVI Movie (*.avi)'; ...
        '*.gif','Animated GIF (*.gif)'},...
            'Save as','untitled');     
        if isequal(mname,0) || isequal(path,0)
           return;
        end
                
        movie_name = fullfile(path, mname);
        
        if (filterIndex == 1)
            playMovie(FILE_LIST, PAR,'avi', movie_name);
        elseif (filterIndex == 2)
            playMovie(FILE_LIST, PAR,'gif', movie_name);
        end
        
        updateDisplay;
        
    end

% needs to be un-indented?
    function playMovie(FILE_LIST, PAR, format, movie_name)
        
        set(LATENCY_SLIDER,'visible','off')
        set(LOOP_BUTTON,'visible','off')
        set(PLOT_NEG_RADIO,'visible','off')
        set(PLOT_POS_RADIO,'visible','off')
        set(AUTO_SCALE_TOGGLE,'visible','off')
        set(SHOW_PEAK_TOGGLE,'visible','off')
        set(SHOW_PEAK_DROPDOWN,'visible','off')
        set(MAX_EDIT,'visible','off')
        set(THRESH_TITLE,'visible','off')
        set(THRESH_SLIDER,'visible','off')
        set(ZERO_LABEL,'visible','off')
        set(MAX_PERCENT_LABEL,'visible','off')
        set(THRESH_EDIT,'visible','off')
        set(MAX_TITLE,'visible','off')
        set(LIST_PEAK_SCROLL,'visible','off')
        set(LIST_PEAK_TEXT,'visible','off')
        set(PLOT_PEAK,'visible','off')
        set(SUBJECT_LABEL,'visible','off');
        set(LIST_LABEL,'visible','off')
        
        drawImage; 
        pause(0.02); 
        
        for k=1:size(FILE_LIST,1)
            IMAGE_NO = k;
            
            currentfilename = loadImageData(FILE_LIST, IMAGE_NO, PAR.PLOT_NEG);
           
            drawImage; 
            pause(0.02); 
            
            rect = get(hMainFigure, 'position'); 
            rect(1:2) = [0 0]; 
            M(k)=getframe(hMainFigure, rect); 
        end
                
        if strcmp(format,'avi')
            movie2avi(M,movie_name)
        else
            %movie_name_gif=strcat(currentfilename(1,1:(find(currentfilename=='z'))),'_threshhold_',thresh_value,'.gif');
            for i=1:size(FILE_LIST,1)
                X_ind=rgb2gray(M(1,i).cdata);
                if i==1
                    imwrite(X_ind,movie_name,'gif','LoopCount',65535,'DelayTime',0)
                else
                    imwrite(X_ind,movie_name,'gif','WriteMode','append','DelayTime',0)
                end
            end
            
        end
        
        set(LATENCY_SLIDER,'visible','on')
        set(LOOP_BUTTON,'visible','on')
        set(PLOT_NEG_RADIO,'visible','on')
        set(PLOT_POS_RADIO,'visible','on')        
        set(AUTO_SCALE_TOGGLE,'visible','on')
        set(SHOW_PEAK_TOGGLE,'visible','on')
        set(SHOW_PEAK_DROPDOWN,'visible','on')
        set(MAX_EDIT,'visible','on')
        set(THRESH_TITLE,'visible','on')
        set(THRESH_SLIDER,'visible','on')
        set(ZERO_LABEL,'visible','on')
        set(MAX_PERCENT_LABEL,'visible','on')
        set(THRESH_EDIT,'visible','on')
        set(MAX_TITLE,'visible','on')
        set(LIST_PEAK_SCROLL,'visible','on')
        set(LIST_PEAK_TEXT,'visible','on')
        set(LIST_LABEL,'visible','on')
        set(SUBJECT_LABEL,'visible','on'); % ADDED

    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % control callbacks          %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    function latency_Callback(src, ~)
        newVal = get(src,'Value');
        IMAGE_NO = round(newVal);
        
        currentfilename = loadImageData(FILE_LIST, IMAGE_NO, PAR.PLOT_NEG);
        dataset=currentfilename(1,1:(find(currentfilename=='A')-2));
        
        % verbose mode...
%         fprintf('Reading file: %s \n', currentfilename);
        
        % update image
        updateDisplay;
        
        %plot latency label
        [~, label] = bw_get_latency_from_filename(currentfilename);
        set(LATENCY_TEXT,'string',label);

        checking_autoscale;
    end
  
    function loop_Callback(src,~)
        
        if ~isPlaying
            set(src,'string','STOP');
            doMovieLoop;
            set(src,'string','LOOP');
            isPlaying = false;
        else
            set(src,'string','LOOP');
            isPlaying = false;
        end
        
    end

    function doMovieLoop
               
         isPlaying = true;        

         for k=1:size(FILE_LIST,1)

            if ~isPlaying
                break;   % cancelled
            end

            IMAGE_NO = k;
            currentfilename = loadImageData(FILE_LIST, IMAGE_NO, PAR.PLOT_NEG);
            
            %plot latency label
            [~, label] = bw_get_latency_from_filename(currentfilename);
            set(LATENCY_TEXT,'string',label);
            
            set(LATENCY_SLIDER,'value',IMAGE_NO);

            drawImage;
            drawnow 
%             M(k)=getframe(hMainFigure);    % this seems to be required to force draw update

         end
    end

    function maxEdit_Callback(src, ~)
        s = get(src,'String');
        PAR.DATA_MAX = str2double(s);
        
        % adjust current threshold to new data max
        thresholdPercent = get(THRESH_SLIDER,'value');
        PAR.THRESH = thresholdPercent * PAR.DATA_MAX ;
        
        updateDisplay;        
    end

    function checking_autoscale
        if PAR.AUTO_SCALE
            currentMax = max(max(max(PAR.ZDATA)));
            maxStr = sprintf('%.2f', currentMax);
            set(MAX_EDIT,'String',maxStr);
            
            set(MAX_TITLE,'String','  Max. =');
        else
            maxStr = sprintf('%.2f', PAR.DATA_MAX);
            set(MAX_EDIT,'String',maxStr);
            set(MAX_TITLE,'String','Max. =');
        end
    end

    % threshold slider now normalized 0 to 1.0
    
    function slider_Callback(src, ~)
        threshPercent = get(src,'value');
        PAR.THRESH = threshPercent * PAR.DATA_MAX;
        s = sprintf('%.1f', threshPercent * 100);
        set(THRESH_EDIT,'string',s);
        
        updateDisplay;
    end    
    
    function threshEdit_Callback(src, ~)
        s = get(src,'string');
        threshPercent = str2double(s) / 100;
        
        if threshPercent < 0
            threshPercent = 0;
            s = sprintf('%.1lf', threshPercent * 100);
            set(src,'string',s);
        end
        if threshPercent > 1
            threshPercent = 1;
            s = sprintf('%.1lf', threshPercent * 100);
            set(src,'string',s);
        end       
        PAR.THRESH = threshPercent * PAR.DATA_MAX;
        
        set(THRESH_SLIDER, 'value', threshPercent);
        updateDisplay;
    end


  function useSRToggle_Callback(src, ~)
        useSearchRadius = get(src,'Value');
    end

    function peakToggle_Callback(src, ~)
        PAR.SHOW_PEAKS = get(src,'Value');
        if (PAR.SHOW_PEAKS == 0)
            set(LIST_PEAK_SCROLL,'enable','off');
        else        
            set(LIST_PEAK_SCROLL,'enable','on');
            if SUBJECT_NO == 0
                set(PLOT_PEAK,'String','Plot Group VS')
            else
                set(PLOT_PEAK,'String','Plot Virtual Sensor')
            end          
        end
        
        updateDisplay;
    end

    function peakDropdown_Callback(src,~)
        if ~PAR.IS_NORMALIZED 
            return;
        end        
        coordtype = get(src,'value');        
        if PAR.SHOW_PEAKS
            updateDisplay;
            drawCursors;
        end
    end

    function peak_scroll_callback(src, ~)
        selected_row=get(src,'value');
        
        temp_list = getPeakList(PAR);
        
        if isempty(temp_list)
            CURRENT_PEAK = [];
        else
            CURRENT_PEAK = temp_list(selected_row,1:3);
        end
        
        clear temp_list;
        
        if ~isempty(CURRENT_PEAK)
            cursorPosition = CURRENT_PEAK;
            if ~PAR.IS_NORMALIZED
                cursorPosition = cursorPosition * 10.0;
            end
            drawCursors;
        end
    end

    function negToggle_Callback(~, ~)
        PAR.PLOT_NEG = 1;
        set(PLOT_NEG_RADIO,'value',1);
        set(PLOT_POS_RADIO,'value',0);
        
        currentfilename = loadImageData(FILE_LIST, IMAGE_NO, PAR.PLOT_NEG);
        updateDisplay;
    end

    function posToggle_Callback(~, ~)
        PAR.PLOT_NEG = 0;
        set(PLOT_NEG_RADIO,'value',0);
        set(PLOT_POS_RADIO,'value',1);
        
        currentfilename = loadImageData(FILE_LIST, IMAGE_NO, PAR.PLOT_NEG);
        updateDisplay;
        
    end

    function autoScale_Callback(src, ~)
        PAR.AUTO_SCALE = get(src,'Value');
        updateDisplay;
        checking_autoscale;
    end


    function updateDisplay
        drawImage;
    end

    function plot_peak_callback(~, ~)
                
        if isempty(CURRENT_PEAK)
            fprintf('Select peak to plot\n');
            return;
        end
 
        peak_voxel = CURRENT_PEAK;
        
        % provide option to unwarp w or w/o search radius
        % now possible with non-normalized coordinates 
        if useSearchRadius            
            [useSR, searchRadius] = getTalSearchOption(params.vs_parameters.useSR, params.vs_parameters.searchRadius);            
            if isempty(useSR)
                return;
            else
                params.vs_parameters.useSR = useSR;
                params.vs_parameters.searchRadius = searchRadius;
            end
        end
                
        if SUBJECT_NO == 0
            subjectsToPlot = NUM_SUBJECTS;
        else
            subjectsToPlot = 1;         % displaying average or single subject
        end
                   
        plotCount = 1;
        for k=1:subjectsToPlot  
            if SUBJECT_NO > 0
                thisSubject = SUBJECT_NO;
            else
                thisSubject = k;
            end  
            
            dsName = char(imageset.dsName(thisSubject));      

            % if not already displaying in CTF coordinates,
            % provide option to unwarp w or w/o search radius
            if PAR.IS_NORMALIZED
                tlist = char(imageset.imageList(thisSubject));
                normalizedImage = deblank(tlist(IMAGE_NO,:));                
                mni_voxel = peak_voxel;  
                
                % * new in 3.2 separated peak search and unwarping - now searches normalized image for peak... 
                if params.vs_parameters.useSR
                    mni_voxel = bw_peak_search(normalizedImage, peak_voxel, params.vs_parameters.searchRadius);
                end
                
                % new mni to ctf conversion - just pass sn3d mat filename
                [~, ~, ~, ~,mri_name] = bw_parse_ds_filename(dsName);               
                bb = params.beamformer_parameters.boundingBox;        
                appendStr = sprintf('_resl_%g_%g_%g_%g_%g_%g_sn3d.mat', bb(1), bb(2),bb(3),bb(4),bb(5),bb(6));
                sn3dmat_file = strrep(mri_name,'.nii',appendStr);
                
                voxel = bw_mni2ctf(sn3dmat_file,mni_voxel);
            else
                voxel = peak_voxel;
            end                 
            
            % build filename lists to pass to plot dialog
            VS_DATA1.dsList{plotCount} = dsName;    
            
            % create a label for this plot
            s = sprintf('%s (%.1f,%.1f,%.1f)',dsName,voxel);
            VS_DATA1.labelList{plotCount} = s;
           
            if imageset.params.beamformer_parameters.covarianceType > 0
                VS_DATA1.covDsList{plotCount} = char(imageset.covDsName(thisSubject)); 
            else
                VS_DATA1.covDsList{plotCount} = dsName; 
            end
            VS_DATA1.voxelList(plotCount,1:3) = voxel;           
            plotCount = plotCount + 1;
            
            % if contrast add the same peak to the list for contrast dataset
            if imageset.params.beamformer_parameters.contrastImage
                dsName = char(imageset.contrastDsName(thisSubject));      
                VS_DATA1.dsList{plotCount} = dsName;
                     
                s = sprintf('%s (%.1f,%.1f,%.1f)',dsName,voxel);
                VS_DATA1.labelList{plotCount} = s;

                if imageset.params.beamformer_parameters.covarianceType > 0
                    VS_DATA1.covDsList{plotCount} = char(imageset.covDsName(thisSubject)); 
                else
                    VS_DATA1.covDsList{plotCount} = dsName; 
                end
                VS_DATA1.voxelList(plotCount,1:3) = voxel;
                plotCount = plotCount + 1;
            end
        end
        
        VS_DATA1.condLabel = imageset.cond1Label;       % need to pass label for contrast?
        VS_DATA1.orientationList = [];                 
        if PLOT_WINDOW_OPEN
            r = questdlg('Add to existing plot?','Plot VS','Yes','No','Yes');
            if strcmp(r,'No')
                bw_plot_dialog(VS_DATA1, params);   
            else
                for k=1:size(VS_DATA1.voxelList,1)
                    g_peak.voxel = VS_DATA1.voxelList(k,1:3);
                    g_peak.dsName = VS_DATA1.dsList{k};                
                    g_peak.covDsName = VS_DATA1.covDsList{k};               
                    g_peak.normal = [1 0 0];  % for volumes normal is undefined
                    g_peak.label = VS_DATA1.labelList{k};
                   feval(addPeakFunction)         
                end
            end         
        else    
            bw_plot_dialog(VS_DATA1, params);
        end  
    end

    % new version moved external routines to have local scope

    function openOverlay_Callback(~, ~)

        if SUBJECT_NO == 0
            errordlg('Need to select single subject for MRI overlay...');
            return;  
        end
        
        dsName = char(imageset.dsName(SUBJECT_NO));
        [~, ~, ~, ~, mri_filename] = bw_parse_ds_filename(dsName); % need MRI folder path

        if ~exist(mri_filename,'file')
            fprintf('Could not locate  MRI file for this subject [%s]\n', mri_filename);
            return;
        end
        
        if size(FILE_LIST,1) > 1       
            r = questdlg('Overlay all images?','Overlay Images','All images','Current Image Only','All images');
            if strcmp(r,'All images')
                overlay_list = FILE_LIST;
            else
                overlay_list = strtrim( char( FILE_LIST(IMAGE_NO,:) ) );
            end
        else
            overlay_list = strtrim( char( FILE_LIST(IMAGE_NO,:) ) );
        end
        
        overlayFiles = cellstr(overlay_list);

        bw_MRIViewer(mri_filename, overlayFiles);
    end
  
    function plotSurfaceImage(src, ~)
        
        if ~PAR.IS_NORMALIZED
             return;
        end          
        item = get(src,'position');

        if item == 1
            meshFile = [];  % for now passing empty mesh loads fsaverage template
        elseif item == 2
            if SUBJECT_NO == 0
                errordlg('Need to select single subject images for cortical surface overlay');
                return;  
            end
            dsName = char(imageset.dsName(SUBJECT_NO));
            [~, ~, ~, mri_path,~] = bw_parse_ds_filename(dsName); % need MRI folder path        if exist(mri_filename,'file')
            
            [filename, pathname]=uigetfile({'*_SURFACES.mat','BrainWave Surface (*_SURFACES.mat)'},...
                'Select surface file...', mri_path);
            if isequal(filename,0) || isequal(pathname,0)
                return;
            end 
            meshFile = fullfile(pathname, filename);
        end
        if size(FILE_LIST,1) > 1       
            r = questdlg('Overlay all images?','Overlay Images','All images','Current Image Only','All images');
            if strcmp(r,'All images')
                overlay_list = FILE_LIST;
            else
                overlay_list = strtrim( char( FILE_LIST(IMAGE_NO,:) ) );
            end
        else
            overlay_list = strtrim( char( FILE_LIST(IMAGE_NO,:) ) );
        end            
        dt_meshViewer(meshFile,overlay_list);   
        
    end

    function drawImage
             
        Z = PAR.ZDATA;  % don't overwrite unthresholded copy of data

        data_threshold = PAR.THRESH;

        if (PAR.AUTO_SCALE)
            maxScale = max(max(max(Z)));
        else
            maxScale = PAR.DATA_MAX;
        end

        nonSigVoxels = (Z < data_threshold);
        Z(nonSigVoxels) = NaN;

        Xvoxels = PAR.XYZ(1,:);
        Yvoxels = PAR.XYZ(2,:);
        Zvoxels = PAR.XYZ(3,:);
        min_x = min(Xvoxels);
        max_x = max(Xvoxels);
        min_y = min(Yvoxels);
        max_y = max(Yvoxels);
        min_z = min(Zvoxels);
        max_z = max(Zvoxels);

        % D. Cheyne - Feb, 2012 - origin was based on approx. to default 
        % bounding box and didn't shift properly with different bounding boxes.  
        % for svl images.  
        
        % For normalized it should be the true SPM origin since the image and 
        % the overlay grid match 
        % for svl it X and Y origins have to be true zero voxel of image not just the midpoint.
        % for Z it has to be 75 mm from top of image

        if (PAR.IS_NORMALIZED)
            origin = PAR.SPM_ORIGIN;
        else      
            ratio = min_x / (max_x - min_x);
            x_origin = PAR.DIM(1) * abs(ratio);     % voxel corresponding to zero.
            origin(1) = ceil(x_origin);

            ratio = min_y / (max_y - min_y);
            y_origin = PAR.DIM(2) * abs(ratio);
            origin(2) = ceil(y_origin);
            
            z_origin = (max_z - 75) / PAR.RES(3);    
            origin(3) = round(z_origin);
        end
        
        % load spm96 grid masks
        if (PAR.IS_NORMALIZED)
            overlayGrid = spm2_grid;
        else
            bwGridplaceholder=load('bwGrid.mat','bwGrid');
            overlayGrid=bwGridplaceholder.bwGrid;
        end
        
        % spm like color scale;
        colormap(flipdim(colormap('hot'),1));

        grid_value = maxScale * 0.4; % SPM2 orange

        % starting origin of grid bounding box in mm
        xstart = overlayGrid.bbox(1);
        ystart = overlayGrid.bbox(3);
        zstart = overlayGrid.bbox(5);
        xend = overlayGrid.bbox(2);
        yend = overlayGrid.bbox(4);
        zend = overlayGrid.bbox(6);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %       sagittal projection            %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % get SPM array
        grid = overlayGrid.sagittal * grid_value;
        [ny.sag, nx.sag] = size(grid);

        % compute MIP projection
        sagittal_proj = zeros(PAR.DIM(3),PAR.DIM(2));
        for i=1:PAR.DIM(3)
            for j=1:PAR.DIM(2)
                vec = Z(:,j,i);
                sagittal_proj(i,j) = max(vec);
            end
        end
        sagittal_proj = flipud(sagittal_proj);


        % have to interpolate projection to 1 mm spm grid array
        image_array = zeros(ny.sag, nx.sag);      
        for i=1:ny.sag
            zc = (i-1) + zstart;                    % get coord in mm
            zvox = (zc / PAR.RES(3)) + origin(3);   % closest image voxel
            xcoord = round(zvox);
            for j=1:nx.sag
                yc = (j-1) + ystart;  % tal coord in mm
                yvox = (yc / PAR.RES(2)) + origin(2);
                ycoord = round(yvox);

                if (xcoord < 1 || xcoord > size(sagittal_proj,1)); continue; end
                if (ycoord < 1 || ycoord > size(sagittal_proj,2)); continue; end
                image_array(i,j) = sagittal_proj(xcoord,ycoord);
            end
        end

        imsag = max(grid,image_array);

        subplot(2,2,1);
        imagesc(imsag, [0 maxScale]);
        axis off;

       % have to draw cursor each time to maintain handles
        sagAxes=gca;
        if PAR.IS_NORMALIZED
            xvox = cursorPosition(2) - ystart;
            yvox = zend - cursorPosition(3);
        else
            xvox = yend + cursorPosition(1);
            yvox = zend - cursorPosition(3);
        end
        
        x = [xvox xvox];
        y = ylim;
        sagCursorV = line(x,y,'LineWidth',1);   
        x = xlim;
        y = [yvox yvox];
        sagCursorH = line(x,y,'LineWidth',1);
       
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %     coronal projection               %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % get SPM array
        grid = overlayGrid.coronal * grid_value;
        [ny.cor, nx.cor] = size(grid);

        % compute MIP projection
        coronal_proj = zeros(PAR.DIM(3),PAR.DIM(1));
        for i=1:PAR.DIM(3)
            for j=1:PAR.DIM(1)
                vec = Z(j,:,i);
                coronal_proj(i,j) = max(vec);
            end
        end
        coronal_proj = flipud(coronal_proj);

        % have to interpolate projection to 1 mm spm grid array
        image_array = zeros(ny.cor, nx.cor);
        for i=1:ny.cor
            zc = (i-1) + zstart;    % tal coord in mm
            zvox = (zc / PAR.RES(3)) + origin(3);  % closest image voxel
            xcoord = round(zvox);
            for j=1:nx.cor
                xc = (j-1) + xstart;  % tal coord in mm
                xvox = (xc / PAR.RES(1)) + origin(1);
                ycoord = round(xvox);

                if (xcoord < 1 || xcoord > size(coronal_proj,1)); continue; end
                if (ycoord < 1 || ycoord > size(coronal_proj,2)); continue; end
                image_array(i,j) = coronal_proj(xcoord,ycoord);
            end
        end

        imcor = max(grid,image_array);

        subplot(2,2,2);
        imagesc(imcor, [0 maxScale]);

        axis off;

        % show colourbar in this quadrant
        if PAR.IS_NORMALIZED
            bar=colorbar;
        else
            pos = get(gca,'Position'); % Save axes position
            bar=colorbar('location','eastoutside'); % Make a colourbar
            set(bar,'Position',[pos(1)+pos(3)+0.01 pos(2) 0.03 pos(4)]) % Specifies
            % position of colourbar; Put colorbar where we want it.
        end
        set(get(bar,'YLabel'),'String','Magnitude', 'fontsize', 11,...
            'VerticalAlignment', 'middle'); % Gives Colourbar title

        % draw cursor
        corAxes=gca;
        if PAR.IS_NORMALIZED
            xvox = cursorPosition(1) + xend;
            yvox = zend - cursorPosition(3);
        else          
            xvox = xend - cursorPosition(2);
            yvox = zend - cursorPosition(3);
        end
        
        x = [xvox xvox];
        y = ylim;
        corCursorV = line(x,y,'LineWidth',1);       
        x = xlim;
        y = [yvox yvox];
        corCursorH= line(x,y,'LineWidth',1);
               
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %   axial projection                   %%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % get SPM array
        grid = overlayGrid.axial * grid_value;
        [ny.axi, nx.axi] = size(grid);

        % compute MIP projection
        % axial projection
        axial_proj = zeros(PAR.DIM(2),PAR.DIM(1));
        for i=1:PAR.DIM(2)
            for j=1:PAR.DIM(1)
                vec = Z(j,i,:);
                axial_proj(i,j) = max(vec);
            end
        end
        axial_proj = rot90(axial_proj);
        axial_proj = flipud(axial_proj);

        % have to interpolate projection to 1 mm spm grid array
        image_array = zeros(ny.axi, nx.axi);
        for i=1:ny.axi
            xc = (i-1) + xstart;    % tal coord in mm
            xvox = (xc / PAR.RES(1)) + origin(1);  % closest image voxel
            xcoord = round(xvox);
            for j=1:nx.axi
                yc = (j-1) + ystart;  % tal coord in mm
                yvox = (yc / PAR.RES(2)) + origin(2);
                ycoord = round(yvox);

                if (xcoord < 1 || xcoord > size(axial_proj,1)); continue; end
                if (ycoord < 1 || ycoord > size(axial_proj,2)); continue; end
                image_array(i,j) = axial_proj(xcoord,ycoord);
            end
        end

        imaxi = max(grid,image_array);

        subplot(2,2,3);
        imagesc(imaxi, [0 maxScale]);
        axis off;

        % draw cursor
        axiAxes=gca;
        if PAR.IS_NORMALIZED
            xvox = cursorPosition(2) - ystart;
            yvox = xend + cursorPosition(1);
        else
            xvox = yend + cursorPosition(1);
            yvox = xend - cursorPosition(2);
        end
        
        x = [xvox xvox];
        y = ylim;
        axiCursorV = line(x,y,'LineWidth',1);       
        x = xlim;
        y = [yvox yvox];
        axiCursorH= line(x,y,'LineWidth',1);
        
        if PAR.SHOW_PEAKS
            drawPeaks(PAR);
        end
        
           
        %%%%%%%%%%%%%%%%%

    end  % drawImage


    % update drawing while cursor being dragged
    function drawCursors   
        
        % update sagittal cursors        
        if PAR.IS_NORMALIZED
            xvox = cursorPosition(2) - ystart;
            yvox = zend - cursorPosition(3);
        else
            xvox = yend + cursorPosition(1);
            yvox = zend - cursorPosition(3);
        end
        x = [xvox xvox];
        y = get(sagAxes,'ylim');      
        set(sagCursorV,'XData',x,'YData',y);
        x = get(sagAxes,'xlim');      
        y = [yvox yvox];
        set(sagCursorH,'XData',x,'YData',y);                     
        
        % coronal cursors
        if PAR.IS_NORMALIZED
            xvox = cursorPosition(1) + xend;
            yvox = zend - cursorPosition(3);
        else
            xvox = xend - cursorPosition(2);
            yvox = zend - cursorPosition(3);
        end

        x = [xvox xvox];
        y = get(corAxes,'ylim');      
        set(corCursorV,'XData',x,'YData',y);
        x = get(corAxes,'xlim');      
        y = [yvox yvox];
        set(corCursorH,'XData',x,'YData',y);  
        
        
         % axial cursors
        
        if PAR.IS_NORMALIZED
            xvox = cursorPosition(2) - ystart;
            yvox = xend + cursorPosition(1);
        else
            xvox = yend + cursorPosition(1);
            yvox = xend - cursorPosition(2); 
        end
        
        x = [xvox xvox];
        y = get(axiAxes,'ylim');      
        set(axiCursorV,'XData',x,'YData',y);
        x = get(axiAxes,'xlim');
        y = [yvox yvox];
        set(axiCursorH,'XData',x,'YData',y);  
             
        mag = 0.0;
        if PAR.IS_NORMALIZED
            xvoxel = round( (cursorPosition(1) - xstart) / PAR.RES(1) ) + 1;
            yvoxel = round( (cursorPosition(2) - ystart)/  PAR.RES(2) ) + 1;
            zvoxel = round( (cursorPosition(3) - zstart) / PAR.RES(3) ) + 1;
            if xvoxel > 0 && xvoxel < size(PAR.ZDATA,1) && yvoxel > 0 && yvoxel < size(PAR.ZDATA,2) && zvoxel > 0 && zvoxel < size(PAR.ZDATA,3)
                mag = PAR.ZDATA(xvoxel,yvoxel,zvoxel);
            end
            label = '';
            if coordtype == 1
                pos = round(cursorPosition);
                s = sprintf('Coordinates: x = %d   y = %d  z = %d', pos);
            elseif coordtype == 2
                pos = round(bw_mni2tal(cursorPosition));
                s = sprintf('Coordinates: x = %d   y = %d  z = %d', pos);
                label = getTalairachLabel(pos);
            end
            
            set(CURSOR_TEXT, 'string',s);      
            s = sprintf('Brain Area: %s', label);
            set(BA_TEXT, 'string',s);  
            
            s = sprintf('Magnitude: %.2f', mag);
            set(MAG_TEXT, 'string',s);      
            CURRENT_PEAK = round(cursorPosition);
        else
            % recover svl origin from voxel value
            svlOrigin(1) = -(PAR.SPM_ORIGIN(2)-1) * PAR.RES(1);
            svlOrigin(2) = (PAR.SPM_ORIGIN(1)-1) * PAR.RES(2);
            svlOrigin(3) = -(PAR.SPM_ORIGIN(3)-1) * PAR.RES(3);
            % Z image stored as LAS and x and y flipped...
            yvoxel = round( (cursorPosition(1) - svlOrigin(1) ) / PAR.RES(1) )  + 1; 
            xvoxel = round( (svlOrigin(2) - cursorPosition(2) )/  PAR.RES(2) ) + 1;      
            zvoxel = round( (cursorPosition(3) - svlOrigin(3) ) / PAR.RES(3) ) + 1;
            if xvoxel > 0 && xvoxel < size(PAR.ZDATA,1) && yvoxel > 0 && yvoxel < size(PAR.ZDATA,2) && zvoxel > 0 && zvoxel < size(PAR.ZDATA,3)
                mag = PAR.ZDATA(xvoxel,yvoxel,zvoxel);
            end
            s = sprintf('Coordinates: x = %.2f   y = %.2f  z = %.2f', cursorPosition * 0.1);
            set(CURSOR_TEXT, 'string',s);      
            set(BA_TEXT, 'string','Brain Area:');  
            s = sprintf('Magnitude:    %.2f', mag);
            set(MAG_TEXT, 'string',s);      
            CURRENT_PEAK = cursorPosition * 0.1;
            
        end                            
    end
        
    function updateCursorPosition(ax, mousecoord)
        switch ax
           case sagAxes
                if PAR.IS_NORMALIZED
                    cursorPosition(2) = mousecoord(1,1) + ystart;
                    cursorPosition(3) = zend - mousecoord(1,2);
                else
                    cursorPosition(1) = mousecoord(1,1) - yend;
                    cursorPosition(3) = zend - mousecoord(1,2);
                end
            case corAxes
                if PAR.IS_NORMALIZED
                    cursorPosition(1) = mousecoord(1,1) - xend;
                    cursorPosition(3) = zend - mousecoord(1,2);
                else
                    cursorPosition(2) = xend - mousecoord(1,1);
                    cursorPosition(3) = zend - mousecoord(1,2);
                end
            case axiAxes
                if PAR.IS_NORMALIZED
                    cursorPosition(1) = mousecoord(1,2) - xend;
                    cursorPosition(2) = mousecoord(1,1) + ystart;
                else
                    cursorPosition(1) = mousecoord(1,1) - yend;
                    cursorPosition(2) = xend - mousecoord(1,2);
                end
        end
        drawCursors;        
    end

    function buttondown(~,~)         
        ax = gca;
        mousecoord = get(ax,'currentpoint');
        xbounds = get(ax,'xlim');
        ybounds = get(ax,'ylim');     
        if mousecoord(1,1) > xbounds(2) || mousecoord(1,1) < xbounds(1) || mousecoord(1,2) > ybounds(2)
            return;
        end   
        
        updateCursorPosition(ax,mousecoord);     
        set(hMainFigure,'WindowButtonMotionFcn',{@dragCursor,ax}) % need to explicitly pass the axis handle to the motion callback   
         
    end

    % button down function - drag cursor
    function dragCursor(~,~, ax)
        mousecoord = get(ax,'currentpoint');
        xbounds = get(ax,'xlim');
        ybounds = get(ax,'ylim');     
        if mousecoord(1,1) > xbounds(2) || mousecoord(1,1) < xbounds(1) || mousecoord(1,2) > ybounds(2) || mousecoord(1,2) < ybounds(1)
            return;
        end   
        updateCursorPosition(ax,mousecoord);                  
    end

    % on button up event set motion event back to no callback 
    function stopdrag(~,~)
        set(hMainFigure,'WindowButtonMotionFcn','');
    end    



    function filename = loadImageData(FILE_LIST, IMAGE_NO, PLOT_NEG)

        filename = strtrim( char( FILE_LIST(IMAGE_NO,:) ) );

        [~,~,EXT] = bw_fileparts(filename);

        if (strncmp(EXT,'.img',4) || strncmp(EXT,'.nii',4))
            [avw, ~] = bw_read_SPM_file(filename);
            PAR.ZDATA = avw.img;
        elseif (strncmp(EXT,'.svl',4))
            % read svl
            svl = bw_readSvlFile(filename);
            PAR.ZDATA = svl.Img;  % image is x, y, z

            PAR.ZDATA = permute(PAR.ZDATA, [2 3 1]); % RAS
            PAR.ZDATA = flipdim(PAR.ZDATA, 1); % left -> right (LAS)
        else
            fprintf('invalid file type in loadImageData\n');
            return;
        end

        if (PLOT_NEG)
            % remove positive voxels and rectify  
            posVoxels = find(PAR.ZDATA > 0.0);
            PAR.ZDATA(posVoxels) = NaN;
            PAR.ZDATA = abs(PAR.ZDATA);
        else
            % remove negative voxels
            negVoxels = find(PAR.ZDATA < 0.0);
            PAR.ZDATA(negVoxels) = NaN;
        end


    end
 
    function [FILE_LIST, negOnly] = initData(tempList, ~, INIT_THRESH)

        % this re-sort filenames to temporal order
        % this may not be necessary with new code....
        
        numFiles = size(tempList,1);
        latencies = zeros(numFiles,1);
        fprintf('initializing %d image(s)...\n',numFiles);

        for i=1:numFiles
            thisFile = char( tempList(i,:) );
            [t, ~] = bw_get_latency_from_filename(thisFile);
            if ~isnan(t)
                latencies(i) = t;
            end
        end

        if ~isempty(latencies)
            tlist = [(1:1:numFiles)' latencies];
            slist = sortrows(tlist,2);
            idx = round(slist(:,1));
            for i=1:numFiles
                FILE_LIST(i,:) = tempList(idx(i),:);
            end
        end

        % set parameters based on first image in list
        % will assume others are same resolution etc....
        thisFile = deblank(char( FILE_LIST(1,:) ));

        [~,~,EXT] = fileparts(thisFile);


        PAR.IS_NORMALIZED = false;

        if (strncmp(EXT,'.img',4) || strncmp(EXT,'.nii',4))


            [avw, ~] = bw_read_SPM_file(thisFile);
            PAR.ZDATA = avw.img;

            hdr = avw.hdr;

            PAR.DIM(1) = int32(hdr.dime.dim(2));
            PAR.DIM(2) = int32(hdr.dime.dim(3));
            PAR.DIM(3) = int32(hdr.dime.dim(4));
            PAR.RES(1) = double(hdr.dime.pixdim(2));
            PAR.RES(2) = double(hdr.dime.pixdim(3));
            PAR.RES(3) = double(hdr.dime.pixdim(4));

            PAR.SPM_ORIGIN(1) = hdr.hist.originator(1);
            PAR.SPM_ORIGIN(2) = hdr.hist.originator(2);
            PAR.SPM_ORIGIN(3) = hdr.hist.originator(3);

            PAR.IS_NORMALIZED = true;

            if (PAR.SPM_ORIGIN(1) == 0 && PAR.SPM_ORIGIN(2) == 0 && PAR.SPM_ORIGIN(3) == 0)
                fprintf('***  SPM origin is zero - input must be SPM normalized image ***\n');
                return;
            end

        elseif (strncmp(EXT,'.svl',4))
            % read svl
            svl = bw_readSvlFile(thisFile);

            PAR.ZDATA = svl.Img;  % image is x, y, z

            PAR.ZDATA = permute(PAR.ZDATA, [2 3 1]); % RAS
            PAR.ZDATA = flipdim(PAR.ZDATA, 1); % left -> right
            xyz = size(PAR.ZDATA);

            PAR.DIM(1) = xyz(1);
            PAR.DIM(2) = xyz(2);
            PAR.DIM(3) = xyz(3);
            PAR.RES(1) = svl.mmPerVoxel;
            PAR.RES(2) = svl.mmPerVoxel;
            PAR.RES(3) = svl.mmPerVoxel;

            % assign approximate origin to SPM
            % get ctf origin in mm
            % the CTF origin in RAS voxels as formerly stored in the analyze header:
            % note that svl struct bb is in cm!

            % xOriginVox = ymax / svlResolution;
            % yOriginVox = -xmin / svlResolution;
            % zOriginVox = -zmin / svlResolution;

            PAR.SPM_ORIGIN(1) = ((svl.bb(4) * 10) / svl.mmPerVoxel) + 1;
            PAR.SPM_ORIGIN(2) = ((-svl.bb(1) * 10) / svl.mmPerVoxel) + 1;
            PAR.SPM_ORIGIN(3) = ((-svl.bb(5) * 10) / svl.mmPerVoxel) + 1;

            PAR.IS_NORMALIZED = false;

        else
            fprintf('invalid file type in initData\n');
            return;
        end

        % init data array
        PAR.ZDATA = zeros(PAR.DIM(1), PAR.DIM(2), PAR.DIM(3) );

        % get global maximum across all files and check temporal order is
        % correct
        PAR.HAS_NEG = false;
        PAR.DATA_MIN = 1e12;
        PAR.DATA_MAX = -1e12;
        negOnly = false;

        for i=1:numFiles

            thisFile = strtrim(char( FILE_LIST(i,:) ));

            [~,~,EXT] = bw_fileparts(thisFile);

            if (strncmp(EXT,'.img',4) || strncmp(EXT,'.nii',4))
                [avw, ~] = bw_read_SPM_file(thisFile);
                PAR.ZDATA = avw.img;
            elseif (strncmp(EXT,'.svl',4))
                svl = bw_readSvlFile(thisFile);
                PAR.ZDATA = svl.Img;  % image is x, y, z
            else
                fprintf('invalid file type in initData function\n');
                return;
            end

            minVal = min(min(min(PAR.ZDATA)));
            if minVal < PAR.DATA_MIN
                PAR.DATA_MIN = minVal;
            end

            maxVal = max(max(max(PAR.ZDATA)));
            if maxVal > PAR.DATA_MAX
                PAR.DATA_MAX = maxVal;
            end
        end

        if PAR.DATA_MIN >= 0
             PAR.HAS_NEG = false;
        else
            PAR.HAS_NEG = true;
            if PAR.DATA_MAX < 0
                fprintf('*** Image has only negative values - setting display to show negative values ...***\n');
                negOnly = true;
                PAR.DATA_MAX = abs(PAR.DATA_MIN);
            else
                fprintf('Image has negative values ... use Plot negative to display ...\n');    
                if abs(PAR.DATA_MIN) > PAR.DATA_MAX
                    PAR.DATA_MAX = abs(PAR.DATA_MIN);
                end
            end
        end

        if INIT_THRESH == 0
            PAR.THRESH = PAR.DATA_MAX * 0.4;
        else
            PAR.THRESH = INIT_THRESH;
        end

        numVoxels = PAR.DIM(1) * PAR.DIM(2) * PAR.DIM(3);

        % build voxel lattice once to save time
        % correction April 2012 - version 1.7 
        % the calculations below was causing fractional origin to be truncated to
        % integer math!  Now corresponds exactly to peak location in SPM and
        % MRIcron

        PAR.XYZ = zeros(3,numVoxels);
        count = 1;
        for i=1:PAR.DIM(3)
            z = (double(i)- double(PAR.SPM_ORIGIN(3))) * PAR.RES(3);
            for j=1:PAR.DIM(2)
                y = (double(j)-double(PAR.SPM_ORIGIN(2))) * PAR.RES(2);
                for k=1:PAR.DIM(1)
                    x = (double(k) - double(PAR.SPM_ORIGIN(1))) * PAR.RES(1);
                    PAR.XYZ(1,count) = x;
                    PAR.XYZ(2,count) = y;
                    PAR.XYZ(3,count) = z;
                    count = count + 1;
                end
            end
        end

        PAR.XYZ = round(PAR.XYZ);


    end
    function drawPeaks( PAR )
        
        peaks = getPeakList(PAR);

        if isempty(peaks)
            set(LIST_PEAK_SCROLL,'string','');
            return;
        else
        
        matrix_s=[];
          
          for k=1:size(peaks,1)
            switch coordtype
              case 0
                header = sprintf('X             Y             Z          Mag.\n\n');
                s = sprintf('%8.2f   %8.2f   %8.2f   %8.2f \n', peaks(k,1:4) );
              case 1
                header = sprintf('X             Y              Z      Mag.\n\n');
                coords = round(peaks(k,1:3));
                s = sprintf('%6d   %6d   %6d     %8.2f \n', coords, peaks(k,4) );
              case 2
                header = sprintf('X             Y              Z         Mag.      Brain Location\n\n');
                original_coords = peaks(k,1:3);
                label = sprintf('');
                
                coords = bw_mni2tal(original_coords);
                coords = round(coords);
                zvalue = peaks(k,4);
                
                [~, ~, s3, ~, s5, ~] = bw_get_tal_label(coords, max_Talairach_SR);
                if (coords(1) < 0)
                  hemStr = 'L';
                elseif (coords(1) > 0 )
                  hemStr = 'R';
                else
                  hemStr = ' ';
                end
                
                % if BA returned show as wellvoxList
                if (strncmp(s5,'Brodmann area', 13))
                  BAstr = s5(15:17);
                  label = sprintf('%s %s, BA %s', hemStr, s3, BAstr);
                  
                else
                  label = sprintf('%s %s', hemStr,  s3);
                end
                
                s = sprintf('%6d   %6d   %6d     %8.2f      %s\n',...
                  coords(1), coords(2), coords(3), zvalue, label);
            end
            if k==1
              matrix_s= char(s);
            else
              matrix_s= char(matrix_s,s);
            end
            
          end
          
          set(LIST_PEAK_TEXT,'string',header);
          
          % check if current peak disappears from list..
          selected_row = get(LIST_PEAK_SCROLL,'Value');
          num_rows = size(peaks,1);
          
          if (selected_row > num_rows )
            selected_row = num_rows;
            set(LIST_PEAK_SCROLL,'Value',num_rows);
          end
          
          t=cellstr(matrix_s);
          set(LIST_PEAK_SCROLL,'string',t);
          
        end
    end

    function label = getTalairachLabel(mni_coords)
        
       tal_coords = bw_mni2tal(mni_coords);
       [~, ~, s3, ~, s5, ~] = bw_get_tal_label(round(tal_coords), max_Talairach_SR);
        if (tal_coords(1) < 0)
            hemStr = 'L';
        elseif (tal_coords(1) > 0 )
            hemStr = 'R';
        else
            hemStr = ' ';
        end

        % if BA returned show as well 
        if (strncmp(s5,'Brodmann area', 13))
          BAstr = s5(15:17);
          label = sprintf('%s %s, BA %s', hemStr, s3, BAstr);                  
        else
          label = sprintf('%s %s', hemStr,  s3);
        end

    end

end

% return peaks in either voxel (MNI) or CTF coords
function [peaks] = getPeakList(PAR)

    ZZ = PAR.ZDATA(:)';         % expand to 1D arrays for all
    voxList = [PAR.XYZ(1,:); PAR.XYZ(2,:); PAR.XYZ(3,:); ZZ]';
    
    % new peak finding restricts number of peaks to search for avoid hanging ...
    peaks = bw_find_peaks(voxList, PAR.THRESH, PAR.PEAK_SR, PAR.MAX_PEAKS);

    if isempty(peaks)
        return;
    end

    peaks = sortrows(peaks,-4);  % * note redundant if using bw_find_peaks2

    if ~PAR.IS_NORMALIZED
        % convert to CTF cm
        voxels = peaks;
        for i=1:size(peaks,1)
            peaks(i,1) = voxels(i,2) * 0.1;  % reverse x and y axis
            peaks(i,2) = -voxels(i,1) * 0.1;
            peaks(i,3) = voxels(i,3) * 0.1;
        end
        clear voxels;
    end

    if ( PAR.PLOT_NEG )
        peaks(:,4) = peaks(:,4) * -1.0;
    end

end


function [useSR, searchRadius] = getTalSearchOption(useSR, searchRadius)

    
    scrnsizes=get(0,'MonitorPosition');
    dh=figure('color','white','name','Peak Search Options ...','numbertitle','off','menubar','none',...
        'CloseRequestFcn',@cancel_callback,'position',[300 (scrnsizes(1,4)-300) 600 230]);

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.1 0.2 0.18],'string','OK','fontweight','bold',...
        'foregroundcolor','black','callback',@ok_callback);
 
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.4 0.1 0.2 0.18],'string','Cancel','foregroundcolor','black','callback',@cancel_callback);    
  
    % user has option to change MNI coordinates
    
       
    RADIO_EXACT=uicontrol('style','radiobutton','units','normalized','position',[0.05 0.6 0.3 0.2],'BackgroundColor','White',...
        'string','Use exact coordinates','fontsize',12,'value', ~useSR, 'callback',@RADIO_EXACT_CALLBACK);
    
    RADIO_SEARCH=uicontrol('style','radiobutton','units','normalized','position',[0.05 0.4 0.4 0.2],'BackgroundColor','White',...
        'string','Find largest peak within a','fontsize',12,'value', useSR, 'callback',@RADIO_SEARCH_CALLBACK);

    SR_EDIT=uicontrol('Style','Edit','Units','Normalized','Position',...
        [0.35 0.4 0.1 0.2],'fontsize',12,'String',num2str(searchRadius),'BackgroundColor','White');    
   
    SR_TEXT = uicontrol('Style','text','Units','Normalized','HorizontalAlignment','Left','Position',...
        [0.48 0.34 0.25 0.2],'String','millimeter search radius','fontsize',12,'BackgroundColor','White');
  
    function RADIO_EXACT_CALLBACK(src,~)
        useSR = 0;
        set(src,'value',1);
        set(RADIO_SEARCH,'value',0);
        set(SR_EDIT,'enable','off');
        set(SR_TEXT,'enable','off');
    end    

    function RADIO_SEARCH_CALLBACK(src,~)
        useSR = 1;
        set(src,'value',1);
        set(RADIO_EXACT,'value',0);
        set(SR_EDIT,'enable','on');
        set(SR_TEXT,'enable','on');
    end

    function ok_callback(~,~)
        if useSR
            s = get(SR_EDIT,'string');
            searchRadius = str2double(s);      % D. Cheyne corrrected typo - July 2015
        end
        uiresume(gcf);
        delete(dh);
    end  

    function cancel_callback(~,~)
        useSR = [];
        searchRadius = [];     
        uiresume(gcf);
        delete(dh);
    end    
    
    uiwait(gcf);

end


