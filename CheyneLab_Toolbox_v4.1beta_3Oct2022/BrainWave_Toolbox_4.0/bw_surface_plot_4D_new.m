%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_surface_plot_4D(file)
%
% routine to plot data on cortical meshes for BrainWave using Matlab
%
%
% Version 1.0
% Dec, 2013
%
%
% written by D. Cheyne and C. Jobst
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function bw_surface_plot_4D(file, init_thresh)

global g_current_peak;
global g_current_normal;
global g_current_Ds;

global addPeakFunction
global PEAK_WINDOW_OPEN
global BW_PATH;

if ~exist('file','var')
    file = openFile;
%     if isempty(file)
%         return;
%     end
end

%%%%%%%%%%%%%%%%%%
% globals
%%%%%%%%%%%%%%%%%%

% Create View
topview = [-90 90];
leftview = [180 0];
rightview = [0 0];
bottomview = [90 -90];

oldbrainColor = [0.64 0.6 0.6];
brainColor = [0.7 0.65 0.65];
lightBrainColor = [0.9 0.85 0.85];
vertexColors = []; % Anton 2021/05/21 - initializing vertexColors earlier
button_orange = [0.8 0.4 0.1];

IMAGE_NO = 1;
SUBJECT_NO = 1;
FILE_LIST = [];
NUM_SUBJECTS = 1;

currentfilename = '';
imageset = [];

vertices = [];
mni_vertices = [];
meg_vertices = [];
faces = [];

surface = [];

% NEW
overlayData = [];

hemisphereIndex = 1;
shadingIndex = 1;
show_Tal = 1;
hide_Controls = 0;
show_Inflated = 0;


DATA_SOURCE_MENU = [];
isPlaying = false;
AUTO_SCALE = false;

currentDataMax = 0.0;
currentDataMin = 0.0;

imagesetPath = [];
imagesetName = [];

selectedVertex = [];
cursorMode = 0;

global_max = 0.0;
global_min = 0.0;
threshold = 0.0;
        
peakVertices = [];
peakSR = 2.0;  % cm

max_Talairach_SR = 5;   % search radius for talairach gray matter labels

%%%%%%%%%%%%%%%
% plot figure %
%%%%%%%%%%%%%%%

fh = figure('Name', 'BrainWave - 4D Surface Plot', 'menubar','none','Color','white',...
    'numbertitle','off','units','normalized','position',[0.2 0.2 0.5 0.65]);%'Position',[25 800 800 650]);
if ispc
    movegui(fh,'center');
end
FILE_MENU=uimenu('Label','File');
OPEN_IMAGESET=uimenu(FILE_MENU,'Label','Open Imageset ...','Accelerator','O','Callback',@open_imageset_callback);
SAVE_IMAGESET=uimenu(FILE_MENU,'Label','Save Imageset ...','Accelerator','S','separator','on','Callback',@save_imageset_callback);
SAVE_MOVIE_AVI_MENU=uimenu(FILE_MENU,'Label','Create Movie ...','Callback',...
    @saveMovie_Callback,'Accelerator','M','enable','on','separator','on');
SAVE_BITMAP_MENU = uimenu(FILE_MENU,'label','Export image...','Callback',@saveBitMap);
LOAD_DATA_MENU = uimenu(FILE_MENU,'label','Import data...','separator', 'on','Callback',@load_data_callback);
CLEAR_OVELAY_MENU = uimenu(FILE_MENU, 'label', 'Clear Overlay...', 'Callback', @clear_overlay_callback);
uimenu(FILE_MENU,'label','Preferences...','Callback',@prefs_Callback, 'separator', 'on');
uimenu(FILE_MENU,'label','Close','Callback','closereq','Accelerator','W','separator','on');

% add options menu after
OPTIONS_MENU=uimenu('Label','Options');

SHADING_MENU = uimenu(OPTIONS_MENU,'label','Shading');
INTERP_MENU = uimenu(SHADING_MENU,'label','Interpolated','checked','on','Callback',@show_interp_callback);
FLAT_MENU = uimenu(SHADING_MENU,'label','No interpolation','Callback',@show_flat_callback);
FACET_MENU = uimenu(SHADING_MENU,'label','Faceted','Callback',@show_faceted_callback);

COORD_MENU = uimenu(OPTIONS_MENU,'label','Template Coordinates');
TAL_MENU = uimenu(COORD_MENU,'label','Talairach','checked','on','callback',@show_tal_callback);
MNI_MENU = uimenu(COORD_MENU,'label','MNI','callback',@show_mni_callback);

SHOW_CONTROLS_MENU = uimenu(OPTIONS_MENU,'label','Hide Controls','Callback',@show_controls_callback);
RESET_DISPLAY_MENU = uimenu(OPTIONS_MENU,'label','Reset Camera Light','separator','on','Callback',@resetShading_Callback);

%%%%%%%%%%%%%%%%%%%%%%%%%%
% controls and callbacks %
%%%%%%%%%%%%%%%%%%%%%%%%%%

FILE_NAME_TEXT=uicontrol('style','text','fontsize',11, 'FontUnits', 'normalized','units','normalized','HorizontalAlignment','left',...
    'position',[0.3 0.97 0.6 0.025],'string','','BackgroundColor','white','foregroundcolor','blue','fontweight','b');

SUBJECT_LABEL=uicontrol('style','text','fontsize',11,'FontUnits', 'normalized','units','normalized','HorizontalAlignment','left',...
    'position',[0.3 0.94 0.4 0.025],'string','','BackgroundColor','white','foregroundcolor','blue','fontweight','b');

% NEW
OVERLAY_LABEL=uicontrol('style', 'text', 'fontsize',11,'FontUnits', 'normalized','units','normalized','HorizontalAlignment','left',...
    'position',[0.3 0.91 0.4 0.025],'string','','BackgroundColor','white','foregroundcolor','blue','fontweight', 'b');

CURSOR_TEXT = uicontrol('style','text','units', 'normalized',...
    'position',[0.72 0.0 0.25 0.15 ],'String','', 'FontSize',...
    11, 'HorizontalAlignment','left','BackGroundColor', 'white');

LATENCY_TEXT = uicontrol('style','text','units', 'normalized',...
    'position',[0.05 0.05 0.5 0.03 ],'String','', 'FontSize',...
    12, 'HorizontalAlignment','left','BackGroundColor', 'white', 'visible', 'off');

LATENCY_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.09 0.0 0.53 0.05],'min',1,'max',2,'Value',1,...
    'sliderStep', [1 1],'BackGroundColor','white','ForeGroundColor',...
    'white','callback',@latency_Callback, 'visible', 'off');
  
latStr = '';
LATENCY_EDIT = uicontrol('style','edit','units', 'normalized',...
    'position',[0.025 0.00 0.06 0.05],'String',latStr,...
	'BackGroundColor','white','TooltipString','Enter Latency',...
    'FontSize', 12,'callback',@latencyEdit_Callback, 'visible', 'off');

tstr = sprintf('Threshold: ');
THRESHOLD_TEXT = uicontrol('style','text','units', 'normalized',...
    'position',[0.05 0.12 0.1 0.04 ],'String',tstr, 'FontSize',...
    12, 'HorizontalAlignment','left','BackGroundColor', 'white');

threshStr = sprintf('%.2f', threshold);
THRESH_EDIT = uicontrol('style','edit','units', 'normalized',...
    'position',[0.14 0.13 0.08 0.035],'String',threshStr,...
    'BackGroundColor','white','TooltipString','Enter Threshold',...
    'FontSize', 12,'callback',@threshEdit_Callback);

THRESHOLD_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.05 0.08 0.3 0.05],'min',0.0,'max',1.0,'Value',threshold,...
    'sliderStep', [0.01 0.01],...% take small steps. 
    'BackGroundColor','white','ForeGroundColor',...
    'white','callback',@threshold_slider_Callback);

maxStr = sprintf('%.2f', global_max);
MAX_EDIT = uicontrol('style','edit','units', 'normalized',...
    'position',[0.87 0.3 0.08 0.05],'String',maxStr,'BackGroundColor',...
    'white','TooltipString','Enter Threshold','FontSize', 12,...
    'callback',@maxEdit_Callback);

AUTO_SCALE_TOGGLE = uicontrol('style','checkbox','units', 'normalized',...
    'position',[0.87 0.25 0.12 0.05],'String','Autoscale',...
    'BackGroundColor','white','FontSize', 10,'Value',...
    AUTO_SCALE,'callback',@autoScale_Callback);


PLOT_BUTTON = uicontrol('style','pushbutton','units', 'normalized',...
    'position',[0.87 0.12 0.08 0.04],'String','Plot VS','visible','off',...
    'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@PLOT_VS_CALLBACK);

FIND_PEAKS_BUTTON = uicontrol('style','pushbutton','units', 'normalized',...
    'position',[0.02 0.41 0.09 0.04],'String','Find Peaks',...
    'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@UPDATE_PEAKS_CALLBACK);

PEAK_LIST = uicontrol('style', 'listbox', 'units',...
    'normalized','position', [0.02 0.2 0.2 0.2],'Background',...
    'White', 'FontSize', 10,'string','','visible','on','callback',...
    @peak_list_callback);

SR_TEXT = uicontrol('style','text','units', 'normalized',...
    'position',[0.115 0.41 0.06 0.04 ],'String','min. dist    (cm)', 'FontSize',...
    12, 'HorizontalAlignment','left','BackGroundColor', 'white');

SR_EDIT = uicontrol('style','edit','units', 'normalized',...
    'position',[0.18 0.41 0.04 0.04],'String',peakSR,'BackGroundColor',...
    'white','TooltipString','Enter Threshold','FontSize', 12,...
    'callback',@SREdit_Callback);

% Movie Button

MOVIE_RADIO = uicontrol('style','pushbutton','units', 'normalized',...
    'position',[0.63 0.025 0.08 0.03],'String','LOOP','FontWeight','bold','FontSize',12,...
    'HorizontalAlignment','left','callback',@movie_Callback, 'visible', 'off');

HEMISPHERE_OPTIONS_TEXT = uicontrol('style','text','fontsize',11,'units','normalized','position',...
    [0.028 0.6 0.13 0.03],'string','HEMISPHERE:','HorizontalAlignment','left','BackgroundColor','white','foregroundcolor','blue','fontweight','b');

%[0.028 0.615 0.13 0.03]
HEMISPHERE_OPTION_DROPDOWN=uicontrol(fh,'style','popupmenu','String','BOTH|LEFT|RIGHT',... %% Must stay here for first loadData to read 'val'
    'units','normalized','Position',[0.028 0.57 0.13 0.03],'FontSize',11,...
    'BackGroundColor','white','callback',@hemisphereViewDropdown_Callback);

SHOW_INFLATED_CHECK = uicontrol('style','checkbox','units', 'normalized',...
    'position',[0.03 0.51 0.13 0.04 ],'String','View Inflated', 'FontSize',12, 'value',0,...
    'BackGroundColor','white','HorizontalAlignment','left','callback',@showInflated_Callback);

   function load_data_callback(src, evt)
        
        [filename, pathname]=uigetfile(...
            {'*.txt','ASCII Overlay file (*.txt)'; '*.thickness', 'Freesurfer Binary Overlay File (*.thickness)';...
             '*.mat', 'Surface File (*.mat)';'*', 'Any File'},'Select file(s)...', 'Multiselect', 'on');
        if isequal(filename,0) || isequal(pathname,0)
            file = [];
            return;
        end
        file = fullfile(pathname,filename);  

        
        % load both left and right thickness files
        if isequal(class(filename), 'cell') 
            
            % takes maximum of 2 overlay files (riht and left)
            if size(filename,2) > 2
                fprintf('Number of overlay files chosen is not logical (%g)\n', size(filename,2));
            end
            
            % surface must be open already to display overlays on
            if isempty(surface)
                    fprintf('No surface loaded\n');
                    return;
            end
            
            lmesh = [];
            rmesh = [];
            
            % FS thickness files (lh.thickness and rh.thickness)
            if strcmp(filename{1}((end-8):end), 'thickness') && strcmp(filename{2}((end-8):end), 'thickness')

                for i=1:2
                    if strcmp(filename{i}, 'lh.thickness')
                        [~, lmesh] = bw_readMeshFile(file{i});

                    elseif strcmp(filename{i}, 'rh.thickness')
                        [~, rmesh] = bw_readMeshFile(file{i});
                    end
                end
                if ~isempty(lmesh) && ~isempty(rmesh)
                    overlayData = [lmesh.curv; rmesh.curv];
                else
                    fprintf('Thickness files were not successfully read\n');
                    return;
                end
                
            % CIVET thickness files (*_right.txt and *_left.txt)
            elseif strcmp(filename{1}((end-2):end), 'txt')

                for i=1:2
                    if strcmp(filename{i}((end-7):end), 'left.txt')
                        lmesh = load(file{i});

                    elseif strcmp(filename{i}((end-8):end), 'right.txt')
                        rmesh = load(file{i});
                    end
                end
                if ~isempty(lmesh) && ~isempty(rmesh)
                    overlayData = [lmesh; rmesh];
                else
                    fprintf('Thickness files were not successfully read\n');
                    return;
                end
                
            % no other file types are recognized
            else
                fprintf('Could not recognize input\n');
                return;
            end
            
            % set overlay label
            [~, n, e] = fileparts(filename{1});
            [~, na, ex] = fileparts(filename{2});
            label = sprintf('Overlay: %s%s, %s%s',n, e, na, ex);
            set(OVERLAY_LABEL, 'string', label);
  
        % load individual file
        else

            [p n e] = fileparts(file);
            
            % load overlay file
            if strcmp(e, '.txt') || strcmp(e, '.thickness')
                
                % surface must be open already to display overlays on
                if isempty(surface)
                    fprintf('No surface loaded\n');
                    return;
                end
                
                % read file
                if strcmp(e, '.txt')
                    overlayData = load(file);
                else
                    [~, meshData] = bw_readMeshFile(file);
                    overlayData = meshData.curv;
                end
                
                % set overlay label
                label = sprintf('Overlay: %s%s', n, e);
                set(OVERLAY_LABEL, 'string', label);
             
            % load surface file
            elseif strcmp(e, '.mat')
                
                % read file
                surfaceFile = file;
                surface = load(surfaceFile);

                % if data is already loaded, make sure number of vertices
                % match
                if ~isempty(overlayData) || ~isempty(FILE_LIST)
                    if size(vertexColors,1)~=surface.numVertices
                        fprintf('Failed Load: Surface vertices (%d) do not match number of data vertices (%d)\n', surface.numVertices, size(vertexColors,1));
                        return;
                    end   
                    
                % if no data loaded, show surface in gray
                else
                    global_max = 1;
                    global_min = -1;
                    colormap(gray);
                    
                    % set surface file label
                    [p n e] = fileparts(surfaceFile);
                    label = sprintf('Surface: %s%s', n, e);
                    set(SUBJECT_LABEL, 'string', label);
                    initColorScale;
                    
                end
                
                if isempty(surface.inflated_vertices)
                    show_Inflated = false;
                    set(SHOW_INFLATED_CHECK,'value',0);       
                    set(SHOW_INFLATED_CHECK,'enable','off');       
                else
                    set(SHOW_INFLATED_CHECK,'enable','on');       
                end
                
                % draw surface
                initSurface;  
                loadData;
                drawPatch(vertices, faces, vertexColors);
                updateDisplay;
                
                % end of function for loading surface
                return;
            end
        end
        
        % for overlays:
        
        % make sure patch already created
        if ~exist('ph', 'var')
            return;
        end
        
        % make sure the number of vertices in the overlay data matches that
        % of the surface (current vertexColors)
        if ~all(size(overlayData)==size(vertexColors))
            fprintf('Failed overlay: Overlay vertices (%d) do not match number of surface vertices (%d)\n', size(overlayData,1), size(vertexColors,1));
            set(OVERLAY_LABEL, 'string', '');
            return;
        end
        
        % set color of vertex faces to overlay data
        set(ph, 'facevertexcdata', overlayData(:));
        
        % set up color scale
        global_min = min(overlayData);
        global_max = max(overlayData);
        currentDataMax = global_max;
        currentDataMin = global_min;
        initColorScale;       
        checking_autoscale;
        
        % set up threshold slider for overlay data
        threshold = 0.2 * global_max;  % same default as mip plot ?
        threshStr = sprintf('%.2f', threshold);
        set(THRESH_EDIT,'string',threshStr);
        set(THRESHOLD_SLIDER,'max',global_max);
        set(THRESHOLD_SLIDER,'value',threshold);
        
   end

    function clear_overlay_callback(src,evt)
        if isempty(overlayData)
            return;
        end
        
        overlayData = [];
        vertexColors = [];
        set(OVERLAY_LABEL, 'string', '');
        global_min = -1;
        global_max = 1;
        
        if ~isempty(FILE_LIST)
            initMax;
        else
            colormap(gray)
        end
           
        loadData;
        initColorScale;
        drawPatch(vertices, faces, vertexColors);
        
        checking_autoscale;
        
        threshold = 0.2 * global_max;  % same default as mip plot ?
        threshStr = sprintf('%.2f', threshold);
        set(THRESH_EDIT,'string',threshStr);
        set(THRESHOLD_SLIDER,'max',global_max);
        set(THRESHOLD_SLIDER,'value',threshold);
        updateDisplay;
        
        set(OVERLAY_LABEL, 'string', '');
    end

   function show_interp_callback(src, evt)      
       shadingIndex = 1;
       shading(gca,'interp');       
       set(get(SHADING_MENU,'Children'),'Checked','off');
       set(src,'Checked','on');        
   end

   function show_flat_callback(src, evt)      
       shadingIndex = 2;
       shading(gca,'flat');       
       set(get(SHADING_MENU,'Children'),'Checked','off');
       set(src,'Checked','on');        
   end

   function show_faceted_callback(src, evt)      
       shadingIndex = 3;
       shading(gca,'faceted');       
       set(get(SHADING_MENU,'Children'),'Checked','off');
       set(src,'Checked','on');        
   end

   function show_controls_callback(src, evt)
         if hide_Controls
                
             hide_Controls = false;
             set(SHOW_CONTROLS_MENU,'label','Hide Controls');
             
         else
             hide_Controls = true;
             set(SHOW_CONTROLS_MENU,'label','Show Controls');
         end
         
         setBackground(hide_Controls);
        
   end

     function show_tal_callback(src, evt)
        show_Tal = true;       
        
        h = datacursormode(fh);

        set(get(COORD_MENU,'Children'),'Checked','off');
        set(src,'Checked','on');        
     end
     
     function show_mni_callback(src, evt)    
        show_Tal = false; 
        h = datacursormode(fh);

        set(get(COORD_MENU,'Children'),'Checked','off');
        set(src,'Checked','on');               
     end
     
    function saveBitMap(src,evt)

        % adapted from mip_plot...                 
        [filename, pathname, filterIndex] = uiputfile( ...
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
        
        [PATHSTR,NAME,EXT] = bw_fileparts(saveName);
        
        if (strcmp(EXT,'.eps'))
            saveas(fh, saveName, 'epsc');
        elseif (strcmp(EXT,'.jpg'))
            saveas(fh, saveName, 'jpg');
        elseif (strcmp(EXT,'.png'))
            saveas(fh, saveName, 'png');
        elseif (strcmp(EXT,'.tif'))
            saveas(fh, saveName, 'tif');
        elseif (strcmp(EXT,'.bmp'))
            print(fh, '-dbmp', [saveName]);
        elseif (strcmp(EXT,'.pdf'))
            saveas(fh, saveName, 'pdf');
        end
        
    end


% % POSITION OPTION # 2
% MOVIE_RADIO = uicontrol('style','pushbutton','units', 'normalized',...
%     'position',[0.6 0.05 0.1 0.03],'String','LOOP','FontWeight','bold','FontSize',12,...
%     'HorizontalAlignment','left','callback',@movie_Callback); %[0.024 0.53 0.14 0.03]

% if opening new plot from main menu
    function file = openFile
        
        [filename, pathname]=uigetfile(...
            {'*_SURFACE_IMAGES.mat','SURFACE IMAGE SET (*_SURFACE_IMAGES.mat)'; ...
            '*.mat','All files (*.mat)'},...
            'Select file(s)...');
        if isequal(filename,0) || isequal(pathname,0)
            file = [];
            return;
        end
        
        file = fullfile(pathname,filename);
    end

% position colorbar
cb = colorbar;

set(get(cb,'YLabel'),'String','Magnitude', 'fontsize', 11,'VerticalAlignment', 'middle'); % Gives Colourbar title

set(cb,'Position' , [0.88 0.36 0.03 0.33]);

% lighting_features;
shading interp
lighting gouraud


cl=camlight('left');
set(cl,'Color',[0.53 0.52 0.52]);
cr=camlight('right');
set(cr,'Color',[0.53 0.52 0.52]);

ax = gca;
set(ax,'View',topview);

currentView = topview;

axis off
axis equal
axis vis3d

hold off;
cameratoolbar(fh,'setmode', 'orbit'); % continuous orbit rotation
cl1=light('Parent',ax,...
    'Position',[0 0 -1], 'Color',[0.54 0.55 0.55]); % lightsource from bottom

if ~isempty(file)

    % Load images
    loadImageSet(file);

    initMax; %% get a global max value for all latencies

    % overwrite threshold if passed...
    if exist('init_thresh','var')
        threshold = init_thresh;  
        threshStr = sprintf('%.2f', threshold);
        set(THRESH_EDIT,'string',threshStr);
    end

    loadData; %% initialize threshold , calls loadData ! 

    % hold on;
    % 
    % % for now need to force pointer type to arrow - must be way to turn off change to circle ?
    % set(fh,'WindowButtonMotionFcn',@cursorMotionCallback, 'WindowButtonDownFcn', @buttonDownCallback )
    %     function cursorMotionCallback(src, evt)
    %         if cursorMode == 0
    %             set(fh,'Pointer','arrow');
    %         end
    %     end

    % Draw images
    % Draw DEFAULT patch

    ph = patch('Vertices',vertices, 'Faces', faces, 'EdgeColor', 'k','facevertexcdata', vertexColors(:) );      

    initColorScale;
    
    updateDisplay;

    initColorScale;
end

% ** turn on opengl for faster drawing ! 
set(fh,'renderer','opengl','Visible','on')

    function latency_Callback(src, evt)
        
        if isPlaying
            return;      % if incrementing during movie loop
        end
        
        newVal = get(src,'Value');
        IMAGE_NO = round(newVal);
        
        checking_autoscale;
        loadData;
        updateDisplay;
        
    end

    function loadImageSet(file)
        
%         % load initial data starts here -- need to make function to re-load
%         [path, name, ext] = bw_fileparts(file);
%         cd(path);
%         cd('..')
        fprintf('Setting current directory to %s\n', pwd);
        %                
        [imagesetPath, imagesetName, EXT] = bw_fileparts(file);

        if (strcmp(EXT,'.mat') == 0)
            fprintf('Unknown file type\n');
            return;
        end       
        
        overlayData = [];
        set(OVERLAY_LABEL, 'string', '');
        imageset = load(file);
        NUM_SUBJECTS = imageset.no_subjects;
        set(FILE_NAME_TEXT,'string',[imagesetName EXT]);

        SUBJECT_NO = 1;
        FILE_LIST = deblank(char(imageset.imageList(SUBJECT_NO)));
        s = sprintf('Subject: %s', char(imageset.dsName(SUBJECT_NO)));
        set(SUBJECT_LABEL,'String',s);
            
        surfaceFile = char(imageset.surfaceFiles(SUBJECT_NO));

        if NUM_SUBJECTS > 1

            % add data menu for multiple subjects
            
            if isempty(DATA_SOURCE_MENU)
                DATA_SOURCE_MENU = uimenu('Label','Data');
            else
                delete(DATA_SOURCE_MENU);
                DATA_SOURCE_MENU = uimenu('Label','Data');
            end
            
            for i=1:NUM_SUBJECTS
                uimenu_call = ['uimenu_action = ''' char(imageset.dsName{i}) '''; uimenu_control;'];
                if i==1
                    uimenu(DATA_SOURCE_MENU,'Label',char(imageset.dsName{i}),'checked','on','Callback',@data_menu_callback); 
                else
                    uimenu(DATA_SOURCE_MENU,'Label',char(imageset.dsName{i}),'Callback',@data_menu_callback); 
                end
            end       
            
            if imageset.isNormalized && ~isempty(imageset.averageSurface)

                % add average menu if data is averagable.    
                set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');
                uimenu_call = ['uimenu_action = ''' 'Average' '''; uimenu_control;'];
                    uimenu(DATA_SOURCE_MENU,'Label','Average','Checked','on',...
                'separator','on','Callback',@data_menu_callback);                
                
                uimenu_call = ['uimenu_action = ''' 'Permute images...' '''; uimenu_control;'];
                uimenu(DATA_SOURCE_MENU,'Label','Permute images...','Checked','off',...
                    'separator','on','Callback',@permute_callback);        

            
            
                SUBJECT_NO = 0;  % display averaged images
                FILE_LIST = deblank(char(imageset.averageList));
                set(SUBJECT_LABEL,'String','Group Average');
                
                surfaceFile = char(imageset.averageSurface);
            end        
        else
           % *** if overlay on template (3D plot from glass brain)
           % have to check if it is an average to disable plot VS button
            s = char(imageset.dsName{1});
            if ~exist(s,'file')
                set(PLOT_BUTTON,'enable','off');
            end
        end

        surface = load(surfaceFile);
        
        if isempty(surface.inflated_vertices)
            show_Inflated = false;
            set(SHOW_INFLATED_CHECK,'value',0);       
            set(SHOW_INFLATED_CHECK,'enable','off');       
        else
            set(SHOW_INFLATED_CHECK,'enable','on');       
        end
        
        initSurface;                               
        
        set(HEMISPHERE_OPTION_DROPDOWN,'Value',1)
               
        vertexColors = [];

        % load first image...
        IMAGE_NO = 1;
        currentfilename = char( FILE_LIST(IMAGE_NO,:) );
        numFiles = size(FILE_LIST,1);
        
        numFiles = size(FILE_LIST,1);
        if (numFiles > 1)
            set(LATENCY_SLIDER,'visible','on');
            set(LATENCY_EDIT,'visible','on');
            step(1) = 1/(numFiles-1);
            % make single step - fix for no scroll arrows on OS X Lion
            step(2) = 1/(numFiles-1);
            % step(2) = 4/(numFiles-1);
            set(LATENCY_SLIDER,'max',numFiles,'Value',1,'sliderStep',step);
            set(MOVIE_RADIO,'visible','on');
        else
            set(LATENCY_SLIDER,'visible','off');
            set(LATENCY_SLIDER,'visible','off');
            set(LATENCY_EDIT,'visible','off');
            set(MOVIE_RADIO,'visible','off');
            
        end
               
    end

    function [surfaceFile] = data_menu_callback(src,evt)
        
        idx = get(src,'position');
        
        if idx == NUM_SUBJECTS + 1
            
            if imageset.isNormalized
            
                SUBJECT_NO = 0;
                FILE_LIST = char(imageset.averageList);
                set(SUBJECT_LABEL,'String','Group Average');

                surfaceFile = char(imageset.averageSurface);  
                surface = load(surfaceFile);      
            end
            
        else
            SUBJECT_NO = idx;
            FILE_LIST = char(imageset.imageList(SUBJECT_NO));
            
            s = sprintf('Subject: %s', char(imageset.dsName(SUBJECT_NO)));
            set(SUBJECT_LABEL,'String',s);
            
            surfaceFile = char(imageset.surfaceFiles(SUBJECT_NO));                    
            surface = load(surfaceFile);                                 
        end
        
        % uncheck all menus
        set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');
        set(src,'Checked','on');        

        initSurface;                   
        loadData;
        drawPatch(vertices, faces, vertexColors);
        updateDisplay;

        
    end

   function permute_callback(src,evt)  
      
        for i=1:imageset.no_subjects
            tlist = char(imageset.imageList(i));
            perm_list{i} = tlist(IMAGE_NO,:);
        end
        
        % set perm parameters here...
         
        [result perm_options] = bw_get_perm_options(imageset.no_subjects, false);
        
        if (result == 0)
            return;
        end
        
        [latency lattext] = getLatencyFromFileName(currentfilename);
        if ~isnan(latency)
            label = sprintf('time=%g_ms_P=%g', latency, perm_options.alpha);
        else
            label = lattext;
        end
            
        imagePrefix= sprintf('%s%s%s_%s',imagesetPath, filesep,imagesetName, label);
        tname = strcat(imagePrefix,'.mat');
        
        [thresholded_ave, thresh] = bw_permute_surface_images(perm_list', imagePrefix, perm_options);
        
        if isempty(thresholded_ave)
            return;
        end
        
        % create imageset for thresholded image
        t_imageset.no_subjects = 1;
        t_imageset.no_images= 1;
        t_imageset.imageType = 'Surface';
        t_imageset.isNormalized = 0;        % to suppress loading of average
        
        t_imageset.globalMax = max(thresholded_ave);
        t_imageset.globalMin = min(thresholded_ave);
        t_imageset.imageType = 'Surface';
        t_imageset.dsName = {'Average Permuted'};

        % viewer not configured to view _only) an average..
        t_imageset.surfaceFiles{1} = imageset.averageSurface;
        
        t_imageset.averageSurface = [];
        t_imageset.imageList = {thresholded_ave};
        save(tname,'-struct','t_imageset');
        
        
        bw_surface_plot_4D(tname, thresh);  % add option to pass threshold! 
        
        
    end

    function initSurface
        
        if show_Inflated
            currentVertices = surface.inflated_vertices;
        else
            currentVertices = surface.vertices;
        end
        
        % update vertex lists for coordinate mappping
        
        if hemisphereIndex == 1  % Display BOTH Hemispheres
            vertices = currentVertices;
            meg_vertices = surface.vertices;
            if ~isempty(surface.normalized_vertices)
                mni_vertices = surface.normalized_vertices;
            end
            faces =  surface.faces + 1;
            
        elseif hemisphereIndex == 2  % Display LEFT Hemisphere
            vertices = currentVertices(1:surface.numLeftVertices,:);
            meg_vertices = surface.vertices(1:surface.numLeftVertices,:);
            if ~isempty(surface.normalized_vertices)
                mni_vertices = surface.normalized_vertices(1:surface.numLeftVertices,:);
            end
            faces =  surface.faces(1:surface.numLeftFaces,:) + 1;
        
        elseif hemisphereIndex == 3  % Display RIGHT Hemisphere
            vertices = currentVertices(surface.numLeftVertices+1:end,:);
            meg_vertices = surface.vertices(surface.numLeftVertices+1:end,:);
            if ~isempty(surface.normalized_vertices)
                mni_vertices = surface.normalized_vertices(surface.numLeftVertices+1:end,:);
            end
            faces =  surface.faces(surface.numLeftFaces+1:end,:) + 1;
            offset=surface.numLeftVertices;
            faces = faces - offset;   % correct indexes for second half of array
        end    
        
    
    end

    function threshold_slider_Callback(src, evt)
        threshold=get(src,'Value');
        loadData;
        updateDisplay;
        tstr=sprintf('%.2f',threshold);
        set(THRESH_EDIT,'String',tstr);
    end
  
    function latencyEdit_Callback(src,evt)
        latStr = get(src, 'String');
        latency = str2double(latStr);
      
        lat_pattern = 'Latency =';
        if regexp(tstr,lat_pattern)
          
            num_files = size(FILE_LIST);
            for k=1:num_files(1)
              
                [cur_lat, ~] = getLatencyFromFileName(FILE_LIST(k,:));
                % find latency of interest, or round up to next closest
                if ~isnan(cur_lat)
                    if (latency <= cur_lat) || ((k==num_files(1)) && (latency > cur_lat)) 
                        IMAGE_NO=k;
                        latency = cur_lat;
                        break;
                    end
                end
            end

            loadData;
            set(LATENCY_SLIDER,'value',IMAGE_NO);
            updateDisplay;

            %plot latency label
            tstr = sprintf('Latency = %6.0f ms', latency);
            set(LATENCY_TEXT,'String',tstr);
          
            latStr = sprintf('%6.0f',latency);
            set(LATENCY_EDIT, 'String',latStr);
            checking_autoscale;
        end
        
    end
  
    function maxEdit_Callback(src, evt)
                
        s = get(src,'String');
        cmax = str2double(s);
        
        if global_min < 0.0
            cmin = -cmax;
        else
            cmin = 0.0;
        end        
        caxis([cmin cmax]);
       
        loadData;
        updateDisplay;
        
    end

    function threshEdit_Callback(src, evt)
        s = get(src,'String');
        
        maxthresh = get(THRESHOLD_SLIDER,'Max');
        threshold = str2double(s);
        if threshold > maxthresh
            threshold = maxthresh;
            threshStr = sprintf('%.2f', threshold);
            set(src,'String',threshStr);
        end
        if threshold < 0
            threshold = 0;
            threshStr = sprintf('%.2f', threshold);
            set(src,'String',threshStr);
        end
        set(THRESHOLD_SLIDER,'value',threshold);
        loadData;
        updateDisplay;
        
    end

    function autoScale_Callback(src, evt)
        
        
        AUTO_SCALE = get(src,'Value');
        
        if AUTO_SCALE
            set(MAX_EDIT,'enable','off');
        else
            set(MAX_EDIT,'enable','on');
            amin = global_min;
            amax = global_max;
            maxStr = sprintf('%.2f', global_max);
            set(MAX_EDIT,'String',maxStr);
            caxis([amin amax]);
            set(cb,'YLim',[amin amax]);
                              
        end
        checking_autoscale;
        loadData;
        updateDisplay;
        
    end


    function checking_autoscale
        
        % set to the current image maximum value
        % note this must be done independently of thresholding        
        if ~AUTO_SCALE
            return;
        end
                    
        maxStr = sprintf('%.2f', currentDataMax);
        set(MAX_EDIT,'String',maxStr);

        amax = currentDataMax;
        amin = currentDataMin;

        caxis([amin amax]);
        set(cb,'YLim',[amin amax]);

        % only warn if threshold is above the current scale max
        cur_thresh=str2double(get(THRESH_EDIT,'String'));
        if cur_thresh > amax                
            fprintf('warning...threshold exceeds current image range\n');
        end        

        
    end

    function showInflated_Callback(src,evt)
        show_Inflated = get(SHOW_INFLATED_CHECK,'value');
 
        loadData;
        initSurface;
        drawPatch(vertices, faces, vertexColors);
        updateDisplay;        
        
    end

    function resetView
        set(cl,'Visible','off');
        set(cr,'Visible','off');
        set(cl1,'Visible','off');
        set(ax,'View',topview);
        set(VIEW_OPTION_DROPDOWN,'Value',1,'String','TOP|LEFT|RIGHT|BOTTOM')
        shading interp
        lighting gouraud
        cl=camlight('right');
        set(cl,'Color',[0.53 0.52 0.52]);
        cr=camlight('left');
        set(cr,'Color',[0.53 0.52 0.52]);
        cl1=light('Parent',ax,'Position',[0 0 1],'Color',[0.54 0.55 0.55]); % light from top
    end

    function hemisphereViewDropdown_Callback(src,evt)
        hemisphereIndex = get(src,'value');
        resetView;
        initSurface;
        loadData;
        drawPatch(vertices, faces, vertexColors);
        updateDisplay;        
        
    end        

    function resetShading_Callback(src,evt)
        set(cl,'Visible','off');
        set(cr,'Visible','off');
        set(cl1,'Visible','off');
        shading interp
        lighting gouraud
        cl=camlight('right');
        set(cl,'Color',[0.53 0.52 0.52]);
        cr=camlight('left');
        set(cr,'Color',[0.53 0.52 0.52]);
        cl1=light('Parent',ax,'Position',[0 0 1],'Color',[0.54 0.55 0.55]); % light from top
        drawPatch(vertices, faces, vertexColors);
    end

% Original settings
    function orig_settings
        set(ZOOM_ON_RADIO,'Enable','on');
        set(CURSOR_RADIO,'Enable','on');
        set(MOVIE_RADIO,'Enable','on');
        set(PAN_ON_RADIO,'Enable','on');
        set(ROTATE_RADIO,'Enable','on');
    end

% Add Continuous Rotation
ROTATE_RADIO = uicontrol('style','radio','units', 'normalized',...
    'position',[0.03 0.88 0.13 0.04 ],'String','ROTATE','FontSize',12,'value',1,...
    'HorizontalAlignment','left','BackGroundColor', 'white','callback',@rotate_Callback);

    function rotate_Callback(src, evt)
        zoom off;
        pan off;
        
        selectedVertex = [];
        cursorMode = 0;
        h = datacursormode(fh);
        h.removeAllDataCursors;
        
        updateCursorText;
        
        set(src,'value',1);
        set(ZOOM_ON_RADIO,'value',0);
        set(CURSOR_RADIO, 'value',0);
        set(MOVIE_RADIO,'value',0);
        set(PAN_ON_RADIO,'value',0);
        set(ZOOM_ON_RADIO,'Enable','on');
        set(PAN_ON_RADIO,'Enable','on');
        cameratoolbar(fh,'setmode', 'orbit','style','local'); % Reset spin
    end

% Add Zoom
ZOOM_ON_RADIO = uicontrol('style','radio','units', 'normalized',...
    'position',[0.03 0.83 0.13 0.04 ],'String','ZOOM', 'FontSize',12, 'value',0,...
    'HorizontalAlignment','left','BackGroundColor', 'white', 'callback',@zoom_on_Callback);

    function zoom_on_Callback(src, evt)
        zoom on;
        pan off;
        
        datacursormode off       
        selectedVertex = [];
        cursorMode = 0;
        h = datacursormode(fh);
        h.removeAllDataCursors;
        
        updateCursorText;
        
        set(src,'value',1);
        set(ROTATE_RADIO,'value',0);
        set(CURSOR_RADIO, 'value',0);
        set(MOVIE_RADIO, 'value',0);
        set(PAN_ON_RADIO,'value',0);
        set(ZOOM_ON_RADIO,'Enable','on');
        set(PAN_ON_RADIO,'Enable','on');
    end

% Add Cursor
CURSOR_RADIO = uicontrol('style','radio','units', 'normalized',...
    'position',[0.03 0.78 0.13 0.04 ],'String','CURSOR','FontSize',12,'value',0,...
    'HorizontalAlignment','left','BackGroundColor', 'white', 'callback',@cursor_Callback);

    function cursor_Callback(src,evt)
        zoom off;
        pan off;
        set(src,'value',1);
        set(ROTATE_RADIO,'value',0);
        set(ZOOM_ON_RADIO,'value',0);
        set(MOVIE_RADIO, 'value',0);
        set(PAN_ON_RADIO,'value',0);
        set(ZOOM_ON_RADIO,'Enable','on');
        set(PAN_ON_RADIO,'Enable','on');
        cursorMode = 1;
        
        h = datacursormode(fh);
        set(h,'enable','on','UpdateFcn',@UpdateCursors);
    
    end
% Pan option (X-Y plane)
PAN_ON_RADIO = uicontrol('style','radio','units', 'normalized',...
    'position',[0.03 0.73 0.13 0.04],'String','PAN (x-y)', 'FontSize',12, 'value',0,...
    'HorizontalAlignment','left','BackGroundColor', 'white', 'callback',@pan_on_Callback);

    function pan_on_Callback(src, evt)
        zoom off;
        pan on;
        datacursormode off
        selectedVertex = [];
        cursorMode = 0;
        h = datacursormode(fh);
        h.removeAllDataCursors;
        updateCursorText;

        set(src,'value',1);
        set(ROTATE_RADIO,'value',0);
        set(CURSOR_RADIO, 'value',0);
        set(ZOOM_ON_RADIO,'value',0);
    end

    function SREdit_Callback(src, evt)
                
        s = get(src,'String');
        peakSR = str2double(s);
        updatePeaks
        
    end

    function peak_list_callback(src, evt)

        if isempty(peakVertices)
            return;
        end
        
        row = get(src,'value');
        selectedVertex = peakVertices(row);
        
        % place datatip at peak 
        h = datacursormode(fh);
        h.removeAllDataCursors;
       
        meg_voxel = meg_vertices(selectedVertex,1:3);
        voxel = vertices(selectedVertex,1:3);
        
        hTarget = handle(ph);
        
        hDatatip = h.createDatatip(hTarget);
        set(hDatatip,'position', voxel);     

        s = sprintf('x=%.2f, y=%.2f, z=%.2f', meg_voxel);
        set(hDatatip, 'MarkerSize',10,'string', s);

        % problem: setting datatip invokese callback which causes wrong position to be set
        % this also causes selectedVertex to be incorrect...
        selectedVertex = peakVertices(row);
        updateCursorText
        
    end

    function UPDATE_PEAKS_CALLBACK( src, evt)
        updatePeaks
    end

        
    function updatePeaks

        if isempty(vertexColors)
            return;
        end
        
        h = datacursormode(fh);
        h.removeAllDataCursors;
                
        % get first peak to start
        
        vertexValues = abs(vertexColors);
        
        % if we are viewing inflated, have to re-apply threshold 
        idx = find(vertexValues < threshold);
        vertexValues(idx) = 0.0;
        
        peakVertices = [];
                
        count = 1;
        while 1
                
            tic

            [value, idx] = max(vertexValues);
            
            if value == 0
                % found all peaks
                fprintf('found all peaks...\n');
                break;
            end
            
            mni_voxel = mni_vertices(idx,1:3);
            meg_voxel = meg_vertices(idx,1:3);
            meg_orient = surface.normals(idx,1:3);
            mag = vertexColors(idx);

            fprintf('Found peak: x=%.2f, y=%.2f, z=%.2f, normal:( %.2f, %.2f, %.2f), Magnitude=%.2f (Vertex: %d)\n',meg_voxel, meg_orient, mag, idx);          
            
            % set all vertices in SR around this peak to zero
            xmax = meg_vertices(idx,1) + peakSR;
            xmin = meg_vertices(idx,1) - peakSR;
            ymax = meg_vertices(idx,2) + peakSR;
            ymin = meg_vertices(idx,2) - peakSR;
            zmax = meg_vertices(idx,3) + peakSR;
            zmin = meg_vertices(idx,3) - peakSR;
            
            zidx = find( meg_vertices(:,1) < xmax & meg_vertices(:,1) > xmin & ...
                meg_vertices(:,2) < ymax & meg_vertices(:,2) > ymin & ...
                meg_vertices(:,3) < zmax & meg_vertices(:,3) > zmin);
            
            vertexValues(zidx) = 0.0;
            
            peakVertices(count) = idx;
            count = count+1;
            
        end
        
        % update cursor to first peak found
        if isempty(peakVertices)
            set(PEAK_LIST,'string','');
            return;
        end
                 
        
        matrix_s = [];
        for j=1: length(peakVertices)
            idx = peakVertices(j);
            meg_voxel = meg_vertices(idx,1:3);
            s = sprintf('%8.2f   %8.2f   %8.2f\n', meg_voxel);
            if j==1
                matrix_s= str2mat(s);
            else
                matrix_s= str2mat(matrix_s,s);
            end
        end
        set(PEAK_LIST,'string', cellstr(matrix_s));
        set(PEAK_LIST,'value',1);
       
        selectedVertex = peakVertices(1);
                    
        % place datatip a first peak
        h = datacursormode(fh);        
        h.removeAllDataCursors;
        
        meg_voxel = meg_vertices(selectedVertex,1:3);
        vertex = vertices(selectedVertex,1:3); % position should correspond to plot vertices
        hTarget = handle(ph);
        hDatatip = h.createDatatip(hTarget);
        set(hDatatip,'position', vertex);     
        s = sprintf('x=%.2f, y=%.2f, z=%.2f', meg_voxel);
        set(hDatatip, 'MarkerSize',10,'string', s);

        % problem: setting datatip invokese callback which causes wrong position to be set
        % this also causes selectedVertex to be incorrect...
        selectedVertex = peakVertices(1);
        
        updateCursorText;

    end

    function PLOT_VS_CALLBACK( src, evt)
        
        if isempty(selectedVertex)
            return;
        end
        
        % get correct vertex if only displaying right hem.
        if hemisphereIndex == 3
            vertex = selectedVertex + surface.numLeftVertices;
        else
            vertex = selectedVertex;
        end
                    
        voxelList = [];
        normalList = [];
        if SUBJECT_NO == 0
            subjectsToPlot = NUM_SUBJECTS;
        else
            subjectsToPlot = 1;
        end
        
        % new plotting method...
        for k=1:subjectsToPlot  
            if SUBJECT_NO > 0
                thisSubject = SUBJECT_NO;
            else
                thisSubject = k;
            end              
            dsName = char(imageset.dsName(thisSubject));      

            fprintf('getting voxel coordinates and normals for subject %s...\n', dsName );
            surfaceFile = char(imageset.surfaceFiles(thisSubject));                    
            tsurf = load(surfaceFile);  
            
            VS_DATA1.dsList{k} = dsName;
            VS_DATA1.condLabel = imageset.cond1Label;
            VS_DATA1.covDsList{k} = char(imageset.covDsName(thisSubject)); 
            VS_DATA1.voxelList(k,1:3) = double( tsurf.vertices(vertex,1:3) );
            VS_DATA1.orientationList(k,1:3) = double( tsurf.normals(vertex,1:3) );
            
            % for contrasts pass second dataset / cov for plotting
            if imageset.params.beamformer_parameters.contrastImage
                VS_DATA2.dsList{k} = char(imageset.contrastDsName(thisSubject));
                VS_DATA2.condLabel = imageset.cond2Label;
                VS_DATA2.covDsList{k} = char(imageset.covDsName(thisSubject)); 
                % voxel and orientation are the same for both conditions
                VS_DATA2.voxelList(k,1:3) = double( tsurf.vertices(vertex,1:3) );
                VS_DATA2.orientationList = double( tsurf.normals(vertex,1:3) );
             else
                VS_DATA2 = [];
            end
        end
        
        bw_plot_dialog(VS_DATA1, VS_DATA2, imageset.params);      
        
    end


    function  updateCursorText
%         if isempty(selectedVertex) || cursorMode == 0
        if isempty(selectedVertex)
            set(CURSOR_TEXT,'String','');
            set(PLOT_BUTTON,'visible','off');
            return;
        end
        
        mni_point = mni_vertices(selectedVertex,1:3);
        meg_point = meg_vertices(selectedVertex,1:3);
        mag = vertexColors(selectedVertex);
        
        s = sprintf('MEG (cm):\n%.2f,   %.2f,   %.2f\nMagnitude = %.2f (Vertex: %d)',meg_point, mag, selectedVertex);   
  
        if ~isempty(mni_vertices)
            if ~show_Tal
                s = sprintf('%s\n\nMNI (mm):\n%d,   %d,   %d',s, round(mni_point));
            else
                
                tal_point = round(bw_mni2tal(mni_point));

                [s1 s2 s3 s4 s5 dist] = bw_get_tal_label(tal_point, max_Talairach_SR);
                if (tal_point(1) < 0)
                    hemStr = 'L';
                elseif (tal_point(1) > 0 )
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

                s = sprintf('%s\n\nTalairach (mm):\n%d,   %d,   %d\n%s',s, tal_point,label);
            end 
        end       
        
        set(CURSOR_TEXT,'String',s);
        set(PLOT_BUTTON,'visible','on');
        
    end
    
    function [newText, position] = UpdateCursors(src,evt)
        
        % get cursorMode object of figure
        newText = '';
        position = get(evt,'Position');
        selectedVertex = find(position(1) == vertices(:,1) & position(2) == vertices(:,2)  & position(3) == vertices(:,3));
        updateCursorText;

    end

    function movie_Callback(src,evt)
        
        if ~isPlaying
            set(src,'string','STOP');
            set(LATENCY_EDIT,'visible','off');
            doMovieLoop;
            set(LATENCY_EDIT,'visible','on');
        else
            set(src,'string','LOOP');
            isPlaying = false;
        end
        
    end

    function doMovieLoop
        
        [original_latency garbage PLOT_SAM]=getLatencyFromFileName(currentfilename);        
        isPlaying = true;        
        k = IMAGE_NO;
        
        while (1)    
            if ~isPlaying   % gets reset on button press
                break;
            end           
            IMAGE_NO=k;           
            M(k)=getframe(fh);
            loadData;            
            if k == size(FILE_LIST,1);
                k = 1;
            else
                k = k + 1;
            end         
            updateDisplay; % fixes zeroing error at first loop frame when loop resets
            set(LATENCY_SLIDER,'value',k);
        end
        
        % just stop at last frame ...
    end


   function open_imageset_callback(src, evt)
        file = openFile;
        if isempty(file)
            return;
        end
        
        loadImageSet(file);
        initMax;
        loadData;
        drawPatch(vertices, faces, vertexColors);

        initColorScale;
        updateDisplay;      
   end

   function save_imageset_callback(src, evt)
        if isempty(imageset)
            fprintf('Cannot save imageset. No imageset loaded\n');
            return;
        end
       
        [name, path, filterIndex] = uiputfile('*','Select Name for image data:','*');
        if isequal(name,0)
            return;
        end
          
        outDir = fullfile(path,name);
        outFile = strcat(name,'_SURFACE_IMAGES.mat');
        mkdir(outDir);

        imagesetName = sprintf('%s%s%s',outDir,filesep,outFile);
        
        fprintf('Saving image data to file %s\n', imagesetName);
                  
        save(imagesetName,'-struct','imageset');                     
        
   end

% Save movie
    function saveMovie_Callback(src, evt)
        
        if isempty(imageset)
            fprintf('Cannot create movie. Imageset not loaded\n');
            return;
        end
        
        [original_latency garbage]=getLatencyFromFileName(currentfilename);
        
        [mname, path, filterIndex] = uiputfile( ...
            {'*.avi','AVI Movie (*.avi)'; ...
            '*.gif','Animated GIF (*.gif)'},...
            'Save as','untitled');
        if isequal(mname,0) || isequal(path,0)
            return;
        end
        
        movie_name = fullfile(path, mname);
        
        if (filterIndex == 1)
            saveMovie('avi', movie_name);
        elseif (filterIndex == 2)
            saveMovie('gif', movie_name);
        end
        
        updateDisplay;
        if ~isnan(original_latency)
            original_tstr=sprintf('Latency = %6.0f ms',original_latency);
            set(LATENCY_TEXT,'String',original_tstr)
            latStr = sprintf('%6.0f',original_latency);
            set(LATENCY_EDIT,'string',latStr);
        end
        
    end

    function saveMovie(format, movie_name)
        
        % remember current state
        save_image_no = IMAGE_NO;
        save_hide_Controls = hide_Controls;
        hide_Controls = 1;
        setBackground(hide_Controls);
        updateDisplay; 

        
        for k=1:size(FILE_LIST,1)
           
            IMAGE_NO=k;
            loadData;
            updateDisplay; 
            M(k)=getframe(fh);
            
        end
        
        fprintf('saving movie in file %s\n', movie_name);
        if strcmp(format,'avi')
            movie2avi(M,movie_name)
        else
            for i=1:size(FILE_LIST,1)
                [RGB, ~] = frame2im( M(1,i) );
                [X_ind, map] = rgb2ind(RGB,256);              
%                 X_ind=rgb2ind( M(1,i).cdata);  % syntax obsolete
                if i==1
                    imwrite(X_ind, map, movie_name,'gif','LoopCount',65535,'DelayTime',0)
                else
                    imwrite(X_ind, map, movie_name,'gif','WriteMode','append','DelayTime',0)
                end
            end
        end
        fprintf('...done\n');
        
        % restore previous settings
        IMAGE_NO=save_image_no; % resets back to current frame (set to 1 to reset to first frame of epoch)
        hide_Controls = save_hide_Controls;       
        setBackground(hide_Controls);
        updateDisplay;
                
    end

% Change FOV
VIEW_OPTION_DROPDOWN=uicontrol(fh,'style','popupmenu','String','TOP|LEFT|RIGHT|BOTTOM',...
    'units','normalized','Position',[0.028 0.65 0.13 0.03],'FontSize',11,...
    'BackGroundColor','white','callback',@viewDropdown_Callback);

    function viewDropdown_Callback(src,evt)
        val = get (src,'Value');
        if val == 1
            set(cl,'Visible','off');
            set(cr,'Visible','off');
            set(cl1,'Visible','off');
            set(ax,'View',topview);
            resetLighting;
            updateDisplay;
        elseif val == 2
            set(cl,'Visible','off');
            set(cr,'Visible','off');
            set(cl1,'Visible','off');
            set(ax,'View',leftview);
            resetLighting;
            updateDisplay;
        elseif val == 3
            set(cl,'Visible','off');
            set(cr,'Visible','off');
            set(cl1,'Visible','off');
            set(ax,'View',rightview);
            resetLighting;
            updateDisplay;
        elseif val == 4
            set(cl,'Visible','off');
            set(cr,'Visible','off');
            set(cl1,'Visible','off');
            set(ax,'View',bottomview);
            resetLighting;
            updateDisplay;
        end
        
        function resetLighting
            shading interp
            lighting gouraud
            cl=camlight('right');
            set(cl,'Color',[0.53 0.52 0.52]);
            cr=camlight('left');
            set(cr,'Color',[0.53 0.52 0.52]);
            cl1=light('Parent',ax,'Position',[0 0 1],'Color',[0.54 0.55 0.55]); % light from top
        end
    end



% Add box
CONTROL_BOX = annotation('rectangle',[0.02 0.5 0.14 0.44],'EdgeColor','blue','FaceColor','white');%[0.02 0.57 0.14 0.38]

% Add text to GUI
% CONTROL_OPTIONS_TEXT = uicontrol('style','text','fontsize',11,'units','normalized','position',...
%     [0.03 0.92 0.13 0.04],'string','Options:','HorizontalAlignment','left','BackgroundColor','white','foregroundcolor','blue','fontweight','b');

VIEW_OPTIONS_TEXT = uicontrol('style','text','fontsize',11,'units','normalized','position',...
    [0.03 0.69 0.1 0.02],'string','VIEW ANGLE:','HorizontalAlignment','left','BackgroundColor','white','foregroundcolor','blue','fontweight','b');

%%%%%%%%%%%%%%%%%%
% FUNCTIONS LIST %
%%%%%%%%%%%%%%%%%%

   % use to set background also for Movie loop *** ? 
    function setBackground( hideControls )
         if hideControls
            % turn off controls, set background to black...
            
            set(LATENCY_TEXT,'foregroundColor','white');
            set(LATENCY_TEXT,'backgroundColor','black');

            set(FILE_NAME_TEXT,'visible','off');
            set(THRESHOLD_TEXT,'visible','off');
            set(THRESHOLD_SLIDER,'visible','off');
            set(THRESH_EDIT,'visible','off');
            set(MAX_EDIT,'visible','off');
            set(AUTO_SCALE_TOGGLE,'visible','off');
            set(HEMISPHERE_OPTION_DROPDOWN,'visible','off');
            set(HEMISPHERE_OPTIONS_TEXT,'visible','off');
            set(SUBJECT_LABEL,'visible','off');
            set(OVERLAY_LABEL, 'visible', 'off');
            set(VIEW_OPTIONS_TEXT,'visible','off');
            set(VIEW_OPTION_DROPDOWN,'visible','off');
            set(PAN_ON_RADIO,'visible','off');
            set(CURSOR_RADIO,'visible','off');
            set(ROTATE_RADIO,'visible','off');
            set(ZOOM_ON_RADIO,'visible','off');
            set(SHOW_INFLATED_CHECK,'visible','off');
 
            
            set(CONTROL_BOX,'visible','off');
            set(CURSOR_TEXT,'visible','off');
            set(PLOT_BUTTON,'visible','off');
            set(FIND_PEAKS_BUTTON,'visible','off');
            set(PEAK_LIST,'visible','off');
            set(SR_TEXT,'visible','off');
            set(SR_EDIT,'visible','off');

            if size(FILE_LIST,1) > 1
                set(LATENCY_SLIDER,'visible','off');
                set(LATENCY_EDIT,'visible','off');
                set(MOVIE_RADIO,'visible','off');
            end
            
            set(fh,'color','black')
            set(get(cb,'YLabel'),'color','white')
            set(cb,'YColor','white')
            
         else
            set(LATENCY_TEXT,'foregroundColor','black');
            set(LATENCY_TEXT,'backgroundColor','white');
            
            set(FILE_NAME_TEXT,'visible','on');
            set(THRESHOLD_TEXT,'visible','on');
            set(THRESH_EDIT,'visible','on');
            set(THRESHOLD_SLIDER,'visible','on');
            set(MAX_EDIT,'visible','on');
            set(AUTO_SCALE_TOGGLE,'visible','on');
            set(HEMISPHERE_OPTION_DROPDOWN,'visible','on');
            set(HEMISPHERE_OPTIONS_TEXT,'visible','on');
            set(SUBJECT_LABEL,'visible','on');
            set(VIEW_OPTIONS_TEXT,'visible','on');
            set(VIEW_OPTION_DROPDOWN,'visible','on');
            set(PAN_ON_RADIO,'visible','on');
            set(CURSOR_RADIO,'visible','on');
            set(ROTATE_RADIO,'visible','on');
            set(ZOOM_ON_RADIO,'visible','on');
            set(SHOW_INFLATED_CHECK,'visible','on');
            set(CONTROL_BOX,'visible','on');
            
            set(CONTROL_BOX,'visible','on');
%             set(PLOT_BUTTON,'visible','on');
            set(CURSOR_TEXT,'visible','on');
            set(FIND_PEAKS_BUTTON,'visible','on');
            set(PEAK_LIST,'visible','on');
            set(SR_TEXT,'visible','on');
            set(SR_EDIT,'visible','on');
            
            if size(FILE_LIST,1) > 1
                set(LATENCY_SLIDER,'visible','on');
                set(LATENCY_EDIT,'visible','on');
                set(MOVIE_RADIO,'visible','on');
            end
            
            set(fh,'color','white')
            set(get(cb,'YLabel'),'color','black')
            set(cb,'YColor','black')
         end
    end

    function initMax
   
        fprintf('Initializing data range ...\n');
        
        % save initial IMAGE_NO
        old_IMAGE_NO = IMAGE_NO;
        
        global_min = 0.0;
        global_max = 0.0;
        % have to do for all subjects !! 
        if isfield(imageset,{'global_max', 'global_min'})
            global_max = imageset.global_max;
            global_min = imageset.global_min;
        else
            count = 1;
            for k=1:NUM_SUBJECTS 
                FILE_LIST = deblank(char(imageset.imageList(k )));
                for j=1:size(FILE_LIST,1)
                    IMAGE_NO=j; 
                    loadData;
                    image_max(count) = max( vertexColors );
                    image_min(count) = min( vertexColors );
                    count = count + 1;
                end
            end
            if max(image_max) > global_max
                global_max = max(image_max);
            end
            if min(image_min) < global_min
                global_min = min(image_min);
            end
        end
       
        % reset image num
        IMAGE_NO = old_IMAGE_NO;
        FILE_LIST = deblank(char(imageset.imageList(1)));
        
        if global_min >= 0.0
            global_min = 0.0;  % positive only values -> unipolar scale
        else
            % apply symmetric bipolar scale
            global_max = max(abs([global_max global_min]));
            global_min = -global_max;
        end
        
        threshold = 0.2 * global_max;  % same default as mip plot ?
        threshStr = sprintf('%.2f', threshold);
        set(THRESH_EDIT,'string',threshStr);
        set(THRESHOLD_SLIDER,'max',global_max);
        set(THRESHOLD_SLIDER,'value',threshold);
        
        set(gca,'CLim',[global_min global_max])
 
    end

    function initColorScale
        
        % Rearrange Colourbar to separate positive/negative peaks
        if global_min < 0.0
            cmap=(jet);
            rows = size(cmap,1);
            mid = floor(rows/2);
            cmap(mid-1,1:3) = lightBrainColor;
            cmap(mid,1:3) = brainColor;
            cmap(mid+1,1:3) = brainColor;
            cmap(mid+2,1:3) = lightBrainColor;
        else
            cmap=flipud(hot); 
            cmap(1,1:3) = brainColor;
            cmap(2,1:3) = lightBrainColor;          
        end          
        colormap(cmap);
        caxis([global_min global_max]);
        set(cb,'YLim',[global_min global_max]);
        
        maxStr = sprintf('%.2f', global_max);
        set(MAX_EDIT,'String',maxStr);

        
    end

    function loadData
        
        if ~isempty(overlayData)
            vertexColors=overlayData;
        elseif ~isempty(FILE_LIST)
            currentfilename = deblank(char(FILE_LIST(IMAGE_NO,:)));
        
            fid1 = fopen(currentfilename,'r');
            if (fid1 == -1)
                fprintf('failed to open file <%s>\n',currentfilename);
                return;
            end
            C = textscan(fid1,'%f');
            fclose(fid1);

            vertexColors=cell2mat(C);
        
        else
            vertexColors=zeros((surface.numLeftVertices + surface.numRightVertices), 1);
        end
        
        % adjust vertexColor list to match left/right hemisphere display size
        
        val=get(HEMISPHERE_OPTION_DROPDOWN,'Value');
                    
        % if value is greater than 1 must have both hemispheres
        % else keep all data...
        hasCurvData=isfield(surface,{'curv'});
        if hasCurvData
            if ~isempty(surface.curv)
                curv_indices = surface.curv;
            else
                hasCurvData = 0;
            end
        end
        
        if val == 2 % LEFT
            vertexColors=vertexColors(1:surface.numLeftVertices);
            if hasCurvData
                if ~isempty(surface.curv)
                    curv_indices = surface.curv(1:surface.numLeftVertices);
                else
                    hasCurvData = 0;
                end
            end
        elseif val == 3 % RIGHT
            vertexColors=vertexColors(surface.numLeftVertices+1:end);
            if hasCurvData
                if ~isempty(surface.curv)
                    curv_indices = surface.curv(surface.numLeftVertices+1:end);
                else
                    hasCurvData = 0;
                end
            end
        end
                               
        % get current image range prior to applying threshold
        % only used  for autoscaling...
        
        mx = max(vertexColors);   
        mn = min(vertexColors);
        % for bivalent data, apply symmetric scale
        if mn < 0.0
            if abs(mn) > mx 
                mx = abs(mn);
            else
                mn = -mx;
            end
        else
            mn = 0.0;
        end
        currentDataMax = mx;          
        currentDataMin = mn;           
        % threshold data...
        
        cur_max_scale = str2double(get(MAX_EDIT,'String'));
        if global_min < 0.0
            scale_cutoff = (cur_max_scale / 32.0) * 2.0;
        else
            scale_cutoff = (cur_max_scale / 64.0) * 2.0;          
        end
        
        % since currently user can set threshold right down to zero have to
        % set all values that are below the min color range on the colormap
        % to be below threshold so they don't print as brain color
        
        idx = find( abs( vertexColors ) < scale_cutoff );
        vertexColors(idx) = 0.0;
        
        if show_Inflated && hasCurvData                       
            idx_s = find( abs( vertexColors ) < threshold & curv_indices > 0.0);
            idx_g = find( abs( vertexColors ) < threshold & curv_indices < 0.0);
            % set below threshold values to one of two curvature shadings
            vertexColors(idx_s) = 0.0;                  % sets to first color  (dark gray)
            vertexColors(idx_g) = scale_cutoff * 0.75;  % sets to second color (light gray)
        else
            idx = find( abs( vertexColors ) < threshold );
            vertexColors(idx) = 0.0;
        end
    end

    function updateDisplay
               
        set(ph, 'facevertexcdata', vertexColors(:) );
        
        % plot latency label
        [latency lattext] = getLatencyFromFileName(currentfilename);
        if ~isnan(latency)
            tstr = sprintf('Latency = %6.0f ms', latency);
            set(LATENCY_TEXT,'String',tstr);
            latStr = sprintf('%6.0f',latency);
            set(LATENCY_EDIT,'string',latStr);
        elseif ~isempty(lattext)
            tstr = sprintf('%s',lattext);
            set(LATENCY_TEXT,'String',tstr)
        end        
        checking_autoscale;
        
        % lighting_features;
        if shadingIndex == 1
            shading interp
        elseif shadingIndex == 2
            shading flat
        else    
            shading faceted
        end


    end

    function drawPatch(vertices, faces, vertexColors)
        
        % Redraw surface for each selected subject
        % remember view
        
        if exist('ph','var')
            delete(ph)
        end
               
        ph = patch('Vertices',vertices, 'Faces', faces, 'EdgeColor', 'k','facevertexcdata', vertexColors(:));

        % lighting_features;
        if shadingIndex == 1
            shading interp
        elseif shadingIndex == 2
            shading flat
        else    
            shading faceted
        end

        lighting gouraud
        
        axis off
        axis equal
        axis vis3d
        hold off;
        
    end

   function prefs_Callback(src, evt)

        scrsz=get(0,'ScreenSize');
        f2=figure('Name', 'Preferences', 'Position', [(scrsz(3)-500)/2 (scrsz(4)-250)/2 500 250],...
            'menubar','none','numbertitle','off', 'color','white');

        SR_text = uicontrol('style','text','units','normalized','position',[0.08 0.66 0.45 0.2],'horizontalalignment','left',...
            'string','Talairach Search Radius (mm): ','fontsize',12,'backgroundColor','white','FontWeight','normal');

        SR_value = uicontrol('style','edit','units','normalized','position',...
            [0.47 0.75 0.1 0.12],'String', max_Talairach_SR,...
            'FontSize', 12,'backgroundColor','white');

%         template_text = uicontrol('style','text','units','normalized','position',[0.08 0.45 0.45 0.2],'horizontalalignment','left',...
%             'string','Template MRI File: ','fontsize',12,'backgroundColor','white','FontWeight','normal');
% 
%         template_name = uicontrol('style','edit','units','normalized','position',...
%             [0.32 0.55 0.5 0.12],'String', template_MRI_Name,...
%             'FontSize', 12,'backgroundColor','white');
% 
%         template_Button = uicontrol('style','pushbutton','units','normalized','position',...
%             [0.85 0.55 0.1 0.12],'String', 'Select',...
%             'FontSize', 12,'backgroundColor','white', 'callback', @templateButtonCallback);

        SAVE_BUTTON = uicontrol('Units','Normalized','Position',[0.8 0.05 0.12 0.12],'String','OK',...
            'FontSize',12,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@save_callback);

        CANCEL_BUTTON = uicontrol('Units','Normalized','Position',[0.6 0.05 0.12 0.12],'String','Cancel',...
            'FontSize',12,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@cancel_callback);


        function save_callback(src, evt) 
                max_Talairach_SR = str2double(get(SR_value,'string'));
%                 template_MRI_Name = get(template_name,'string');
                uiresume(f2);        
                close(f2);            
        end

        function templateButtonCallback(src, evt) 
            template_path=strcat(BW_PATH,filesep,'template_MRI/');
            [filename, pathname]=uigetfile({'*_SURFACE.mat','BrainWave Surface (*_SURFACE.mat)'},...
                'Select template file...', template_path);
            if isequal(filename,0) || isequal(pathname,0)
                file = [];
                return;
            end
            set(template_name,'string',filename);
        end

        function cancel_callback(src, evt)
            uiresume(f2);        
            close(f2); 
        end

        uiwait(f2);

        updateCursorText;

   end

end

% helper function from mip_plot_4D
function [latency windowtxt PLOT_SAM] = getLatencyFromFileName(filename)

[garbage,NAME,EXT] = bw_fileparts(filename);

latency = NaN;
windowtxt=[];

s1 = strfind(NAME,'time=');
if ~isempty(s1)
    PLOT_SAM = 0; %% ADDED BY CECILIA - flags that a SAM image was made for pos/neg toggle option
    timeStr = NAME(s1+5:end);
    multiplicand = 1000;
    idx = strfind(timeStr,'_');     % strip off appended text (e.g., _AVE)
    if ~isempty(idx) 
      if strcmp(timeStr(idx:idx+2),'_ms')   % if time already in ms, do not change units
        multiplicand = 1;
      end
      timeStr = timeStr(1:idx-1);
    end
    latency = str2double(timeStr);
    latency = latency * multiplicand;       % return latency in ms 
else
    PLOT_SAM = 1; %% ADDED BY CECILIA - flags that a SAM image was made for pos/neg toggle option
    s1=strfind(NAME,'A=');
    s2=strfind(NAME,'B=');
    len = 2;
    len_2 = 2;
    if isempty(s1)
        s1=strfind(NAME,'active=');
        s2=strfind(NAME,'baseline=');
        len = 7;
        len_2 = 9;
    end
    
    % correct version from Zhengkai
    if ~isempty(s1)
        if isempty(s2)
            w = NAME(s1+len:end);
            tend = strfind(w,'_');
            w = w(1:tend(2)-1);
            windowtxt = sprintf('active=%s',w);
        else
            w = NAME(s1+len:end);
            tend = strfind(w,',');
            w = w(1:tend-1);
            windowtxt = sprintf('active=%s',w);
            w = NAME(s2+len_2:end);
            tend = strfind(w,'_');
            w = w(1:tend(2)-1);
            windowtxt = sprintf('%s, baseline =%s',windowtxt, w);
        end
    end
    
end
end