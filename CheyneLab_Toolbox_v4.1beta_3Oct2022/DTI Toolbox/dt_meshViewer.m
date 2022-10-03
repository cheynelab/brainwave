%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function dt_meshViewer([meshFile], [overlayFiles])
%
%   input options:
%   meshFile:       BW generated .mat file of FS or CIVET surfaces
%   overlayFiles:   cellstr array of .nii format normalized source images 
%
% GUI to create and view cortical surface meshes created by 
% FreeSurfer or CIVET that are co-registered with MEG data
%
% - importing FS and CIVET meshes requires co-registered MRI .nii volume processed with BrainWave
% - options for interpolating custom overlays in standard (MNI) space
%   onto surfaces including volumetric source images (.nii) 
% - also includes parcellation atlases (AAL, JuBrain) for creating DTI masks
%
% version 1.0
% (c) D. Cheyne, October 2021 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function dt_meshViewer(meshFile, overlayFiles)

    global DT_PATH;
    global g_peak
    global addPeakFunction
    global PLOT_WINDOW_OPEN
    
    tpath=which('dt_meshViewer');
    DT_PATH=tpath(1:end-16);
    
    niftiPath = sprintf('%s%sexternal%sNIfTI', DT_PATH, filesep,filesep);
    dicm2niiPath = sprintf('%s%sexternal%sdicm2nii', DT_PATH, filesep,filesep);
    addpath(niftiPath);
    addpath(dicm2niiPath);
    
    darkbrainColor = [0.6 0.55 0.55];
    lightBrainColor = [0.8 0.75 0.75];
    
    showCurvature = 0;
    showThickness = 0;
    hemisphere = 0;
    
    vertices = [];
    faces = [];
    vertexColors = [];
    
    overlay = []; % vertex data
    overlay_threshold = 0.2;
    overlay_data = [];   
    transparency = 1.0;
    
    fsl_vertices = [];
    fsl_faces = [];
    fsl_transparency = 0.3;

    dti_volume = [];
    dti_pts = [];
    dti_vals = [];
    dti_max = 0.0;
    dti_threshold = 0.0;
    dti_voxel_size = 1.0;
    
    selectedOverlay = 0;
    overlay_files = {};
    selectedPolarity = 3;
    
    selectedVertex = [];
    autoScaleData = 1;
    g_scale_max = 1.0;
    movie_playing = 0;
    
    roi_data = {};
    selectedROI= 0;
    
    meshes = [];
    mesh = [];
    meshNames = [];
    selected_mesh = 1;
    RAS_to_MEG = [];
      
    save_movie = 0;
    cropMovie = 0;
    
    xmin =-12;
    xmax = 12;
    ymin = -12;
    ymax = 12;
    zmin = -8;    
    zmax = 16;  
    
    %%%%%
    fh = figure('Color','white','name','Surface Viewer','numberTitle','off','menubar','none','Position',[25 800 1200 850]);
    if ispc
        movegui(fh,'center')
    end
       
    cmap=(jet);
    rows = size(cmap,1);
    mid = floor(rows/2);
    cmap(mid-1,1:3) = lightBrainColor;
    cmap(mid,1:3) = darkbrainColor;
    cmap(mid+1,1:3) = lightBrainColor;
    
    % create normalized colour scale with cutoff for brain color
    colormap(cmap)
    % create colour array w/o brain colours
    colourMap = cmap;
    colourMap(mid-1:mid+1,:) = [];
 
    scaleCutoff_p  = (mid+1)/ rows;  % normalized colour scale cutoff
    scaleCutoff_n = (mid-2) / rows;    

    % File Menu
    FILE_MENU = uimenu('Label','File');
    uimenu(FILE_MENU,'label','Load Surfaces ...','Callback',@LOAD_MESH_CALLBACK);    
    TEMPLATE_MENU = uimenu(FILE_MENU,'label','Load Template');  
    uimenu(TEMPLATE_MENU,'Label','Freesurfer (fsaverage)', 'Callback',@LOAD_FSAVERAGE_CALLBACK);
    uimenu(TEMPLATE_MENU,'Label','MNI Colin-27 (CH2)', 'Callback',@LOAD_TEMPLATE_CALLBACK);
    uimenu(FILE_MENU,'label','Import Surfaces ...','separator','on','Callback',@IMPORT_MESH_CALLBACK);    
    uimenu(FILE_MENU,'label','Close','Callback','closereq','Accelerator','W','separator','on');    

    FILE_TEXT = uicontrol('style','text','units', 'normalized',...
        'position',[0.02, 0.97 0.7 0.03 ],'String','File: none', 'FontSize',11, ...
        'HorizontalAlignment','left','BackGroundColor', 'white');
    SURFACE_TEXT = uicontrol('style','text','units', 'normalized',...
        'position',[0.02, 0.945 0.7 0.03 ],'String','Surface: none', 'FontSize',11, ...
        'HorizontalAlignment','left','BackGroundColor', 'white');   
    
    CURSOR_TEXT = uicontrol('style','text','units', 'normalized',...
        'position',[0.02 0.74 0.22 0.2 ],'String','', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');
  
    % make a custom colorbar    
    bot = 0.3;
    height = 0.5 / size(colourMap,1);  
    MIN_TEXT = uicontrol('style','text','units', 'normalized','visible','off',...
        'position',[0.9 0.3 0.03 0.02],'String','', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');

    for k=1:size(colourMap,1)
        c_bar(k) = annotation('rectangle',[0.94 bot 0.025 height],'FaceColor',colourMap(k,1:3),'visible','off');
        bot = bot+height;
    end
   
    cropRect = [0.25 0.25 0.55 0.6];
    movieRect = [];     
    
    ZERO_TEXT = uicontrol('style','text','units', 'normalized','visible','off',...
        'position',[0.9 0.54 0.03 0.02],'String','0.0', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');
    
    MAX_TEXT = uicontrol('style','text','units', 'normalized','visible','off',...
        'position',[0.9 0.785 0.03 0.02],'String','', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');
    
    THRESH_SLIDER = uicontrol('style','slider','units', 'normalized','visible','off',...
        'position',[0.8 0.17 0.18 0.02],'min',0,'max',1.0,...
        'Value',overlay_threshold, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@slider_Callback);  
    
    THRESH_TEXT = uicontrol('style','text','units', 'normalized','visible','off',...
        'position',[0.8 0.215 0.1 0.02],'String','Threshold (%) =', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');
    THRESH_EDIT = uicontrol('style','edit','units', 'normalized','visible','off',...
        'position',[0.9 0.2 0.07 0.04],'String',num2str(overlay_threshold),...
        'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@threshEditCallback);
    SLIDE_TEXT1 = uicontrol('style','text','units', 'normalized','visible','off',...
        'position',[0.96 0.15 0.08 0.02],'String','max', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');
    SLIDE_TEXT2 = uicontrol('style','text','units', 'normalized','visible','off',...
        'position',[0.8 0.15 0.08 0.02],'String','min', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');   
    
    MAX_EDIT_TEXT = uicontrol('style','text','units', 'normalized','visible','off',...
        'position',[0.83 0.835 0.08 0.02],'String','Maximum =', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');
    MAX_EDIT = uicontrol('style','edit','units', 'normalized','visible','off','enable','off',...
        'position',[0.9 0.82 0.07 0.04],'String',num2str(g_scale_max),...
        'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@maxEditCallback);
    AUTO_SCALE_CHECK = uicontrol('style','checkbox','units', 'normalized','visible','off',...
        'BackGroundColor','white','foregroundcolor','black','position',[0.9 0.86 0.12 0.04],....
        'String','Autoscale','value',autoScaleData, 'FontSize',11,'callback',@autoScaleCallback);
    
    % buttons   
    uicontrol('style','pushbutton','units', 'normalized',...
        'position',[0.02 0.74 0.06 0.03],'String','Find MNI',...
        'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@gotoPeakCallback);
    uicontrol('style','pushbutton','units', 'normalized',...
        'position',[0.02 0.7 0.06 0.03],'String','Find Max',...
        'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@findMaxCallback);  
    uicontrol('style','pushbutton','units', 'normalized',...
        'position',[0.02 0.66 0.06 0.03],'String','Find Min',...
        'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@findMinCallback);
    uicontrol('style','pushbutton','units', 'normalized',...
        'position',[0.02 0.62 0.06 0.03],'String','Plot VS',...
        'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@plotVSCallback);
   
    % sliders
    
    sl(1) = uicontrol('style','text','units', 'normalized',...
        'position',[0.02 0.515 0.15 0.03],'String','Brain Transparency',...
        'FontSize',11,'HorizontalAlignment','left','BackGroundColor', 'white');  
    sl(2) = uicontrol('style','slider','units', 'normalized',...
        'position',[0.02 0.5 0.10 0.02],'min',0,'max',1.0,...
        'Value',transparency, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@transparency_slider_Callback);      

    sl(3)  = uicontrol('style','text','units', 'normalized',...
        'position',[0.02 0.465 0.10 0.03],'String','X Range',...
        'FontSize',11,'HorizontalAlignment','left','BackGroundColor', 'white');  
    sl(4)  = uicontrol('style','slider','units', 'normalized',...
        'position',[0.02 0.45 0.10 0.02],'min',xmin,'max',xmax,...
        'Value',xmin, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@x1_slider_Callback);      
    sl(5)  = uicontrol('style','slider','units', 'normalized',...
        'position',[0.02 0.43 0.10 0.02],'min',xmin,'max',xmax,...
        'Value',xmax, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@x2_slider_Callback);      

    sl(6)  = uicontrol('style','text','units', 'normalized',...
        'position',[0.02 0.395 0.10 0.03],'String','Y Range',...
        'FontSize',11,'HorizontalAlignment','left','BackGroundColor', 'white');  
    sl(7)  = uicontrol('style','slider','units', 'normalized',...
        'position',[0.02 0.38 0.10 0.02],'min',ymin,'max',ymax,...
        'Value',ymin, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@y1_slider_Callback);      
    sl(8)  = uicontrol('style','slider','units', 'normalized',...
        'position',[0.02 0.36 0.10 0.02],'min',ymin,'max',ymax,...
        'Value',ymax, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@y2_slider_Callback);      
       
    sl(9)  = uicontrol('style','text','units', 'normalized',...
        'position',[0.02 0.325 0.10 0.03],'String','Z Range',...
        'FontSize',11,'HorizontalAlignment','left','BackGroundColor', 'white');  
    sl(10)  = uicontrol('style','slider','units', 'normalized',...
        'position',[0.02 0.31 0.10 0.02],'min',zmin,'max',zmax,...
        'Value',zmin, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@z1_slider_Callback);      
    sl(11)  = uicontrol('style','slider','units', 'normalized',...
        'position',[0.02 0.29 0.10 0.02],'min',zmin,'max',zmax,...
        'Value',zmax, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@z2_slider_Callback);      
 
   sl(12)  = uicontrol('style','text','units', 'normalized',...
        'position',[0.02 0.245 0.10 0.03],'String','DTI Threshold (%)','visible','off',...
        'FontSize',11,'HorizontalAlignment','left','BackGroundColor', 'white');  
   sl(13)  = uicontrol('style','slider','units', 'normalized','visible','off',...
        'position',[0.02 0.23 0.10 0.02],'min',0,'max',1.0,...
        'Value',dti_threshold, 'sliderStep', [0.001 0.01],'BackGroundColor','white','callback',@dti_slider_Callback);      
    
   sl(14) = uicontrol('style','text','units', 'normalized',...
        'position',[0.02 0.565 0.15 0.03],'String','Skin Transparency','visible','off',...
        'FontSize',11,'HorizontalAlignment','left','BackGroundColor', 'white');  
   sl(15) = uicontrol('style','slider','units', 'normalized','visible','off',...
        'position',[0.02 0.55 0.10 0.02],'min',0,'max',1.0,...
        'Value',fsl_transparency, 'sliderStep', [0.01 0.01],'BackGroundColor','white','callback',@fsl_transparency_slider_Callback);      
    
   sl(16)  = uicontrol('style','edit','units', 'normalized','visible','off',...
        'position',[0.13 0.23 0.04 0.03],'min',0,'max',1.0,...
        'string','0.0', 'BackGroundColor','white','callback',@dti_edit_Callback);  
   sl(17)  = uicontrol('style','text','units', 'normalized','visible','off',...
        'position',[0.02 0.19 0.15 0.03],'min',0,'max',1.0,'FontSize',11,'HorizontalAlignment','left',...
        'string','Volume:', 'BackGroundColor','white');  
  
%     set(sl(:),'visible','off');

    % list boxes

    
    uicontrol('style','text','units', 'normalized',...
        'position',[0.02 0.16 0.08 0.03],'String','OVERLAYS',...
        'FontSize',12,'Fontweight','bold','HorizontalAlignment','left','BackGroundColor', 'white');
    
    OVERLAY_LIST = uicontrol('style','listbox','units', 'normalized',...
        'position',[0.02, 0.02 0.25 0.14 ],'String',{}, 'FontSize',11,...
        'HorizontalAlignment','right','BackGroundColor', 'white', 'Callback',@select_overlay_callback);   
  
    MOVIE_BUTTON = uicontrol('style','pushbutton','units', 'normalized',...
        'position',[0.28 0.13 0.07 0.03],'String','Play Movie',...
        'BackGroundColor','white','foregroundcolor','blue','FontSize',10,'callback',@movieCallback);
    
    uicontrol('style','checkbox','units', 'normalized',...
        'BackGroundColor','white','foregroundcolor','black','position',[0.28 0.08 0.1 0.04],...
        'String','Save Movie','value',save_movie, 'FontSize',11,'callback',@saveMovieCallback);
    uicontrol('style','checkbox','units', 'normalized',...
        'BackGroundColor','white','foregroundcolor','black','position',[0.28 0.04 0.1 0.04],...
        'String','Crop Movie','value',cropMovie, 'FontSize',11,'callback',@brainOnlyCallback);

        
    uicontrol('style','text','units', 'normalized',...
        'position',[0.4 0.16 0.08 0.03],'String','ROIs',...
        'FontSize',12, 'Fontweight','bold','HorizontalAlignment','left','BackGroundColor', 'white');
    
    ROI_LIST = uicontrol('style','listbox','units', 'normalized',...
        'position',[0.4, 0.02 0.22 0.14 ],'String',{}, 'FontSize',11,'min',1,'max',1000,...
        'HorizontalAlignment','left','BackGroundColor', 'white', 'Callback',@select_roi_callback);       
 
    ROI_TEXT = uicontrol('style','text','units', 'normalized',...
        'position',[0.64 0.015 0.24 0.15],'String','', 'FontSize',11, 'HorizontalAlignment','left','BackGroundColor', 'white');
    
    
    % MENUS
    
    MESH_MENU = uimenu('Label','Surface'); % gets built when loading mesh file
    
    OVERLAY_MENU=uimenu('Label','Overlays');   
    ADD_OVERLAY_MENU = uimenu(OVERLAY_MENU,'label','Add Overlays');   
    uimenu(ADD_OVERLAY_MENU,'label','Load SAM/ERB Volumes (w*.nii)...','Callback',@LOAD_ERB_CALLBACK);    
    uimenu(ADD_OVERLAY_MENU,'label','Load Vertex Data (*.txt)...','Callback',@LOAD_VERTEX_DATA_CALLBACK);      
    uimenu(ADD_OVERLAY_MENU,'label','Add Skin Overlay (*.vtk)...','separator','on','Callback',@LOAD_VTK_MESH_CALLBACK);      
    uimenu(OVERLAY_MENU,'label','Delete Overlay', 'callback', @delete_overlay_callback);   
    uimenu(OVERLAY_MENU,'label','Delete All Overlays', 'callback', @delete_all_overlays_callback);   
    uimenu(OVERLAY_MENU,'label','Hide Overlays','separator','on','Callback',@CLEAR_OVERLAY_CALLBACK);                 
    uimenu(OVERLAY_MENU,'label','Save Overlay As Mask...','separator','on','Callback',@SAVE_OVERLAY_CALLBACK);    

    
    ROI_MENU=uimenu('Label','ROIs');   
    ADD_ROI_MENU = uimenu(ROI_MENU,'label','Add ROI');   
    uimenu(ADD_ROI_MENU,'label','Parcellation Atlases...','Callback',@LOAD_ATLAS_CALLBACK);    
    uimenu(ADD_ROI_MENU,'label','Region Growing ...', 'Callback',@REGION_GROWING_CALLBACK);      
    uimenu(ROI_MENU,'label','Delete ROI','callback', @delete_roi_callback);   
    uimenu(ROI_MENU,'label','Delete All ROIs','callback', @delete_all_roi_callback);   
    uimenu(ROI_MENU,'label','Save ROI As Mask...','separator','on','Callback',@SAVE_OVERLAY_CALLBACK);    
   
    DTI_MENU=uimenu('Label','DTI');   
    uimenu(DTI_MENU,'label','Add DTI Volume...','Callback',@LOAD_DTI_CALLBACK);    
    uimenu(DTI_MENU,'label','Delete DTI Volumes','Callback',@delete_dti_callback);    
    
    VIEW_MENU=uimenu('Label','View Options');
    ORIENT_MENU = uimenu(VIEW_MENU,'label', 'Orientation');
    uimenu(ORIENT_MENU,'label','Top','Callback',@set_orientation_callback);
    uimenu(ORIENT_MENU,'label','Left','Callback',@set_orientation_callback);
    uimenu(ORIENT_MENU,'label','Right','Callback',@set_orientation_callback);
    uimenu(ORIENT_MENU,'label','Front','Callback',@set_orientation_callback);
    uimenu(ORIENT_MENU,'label','Back','Callback',@set_orientation_callback);
    HEMI_MENU = uimenu(VIEW_MENU,'label', 'Hemisphere');
    uimenu(HEMI_MENU,'label','Left','Callback',@hemisphere_select_callback);
    uimenu(HEMI_MENU,'label','Right','Callback',@hemisphere_select_callback);
    uimenu(HEMI_MENU,'label','Both','checked','on','Callback',@hemisphere_select_callback);    
    SHADING_MENU = uimenu(VIEW_MENU,'label','Shading'); 
    uimenu(SHADING_MENU,'label','Flat','checked','on','Callback',@show_flat_callback);
    uimenu(SHADING_MENU,'label','Interpolated','Callback',@show_interp_callback);
    uimenu(SHADING_MENU,'label','Faceted','Callback',@show_faceted_callback);
    LIGHTING_MENU = uimenu(VIEW_MENU,'label','Lighting'); 
    uimenu(LIGHTING_MENU,'label','Gouraud','checked','on','Callback',@light_gouraud_callback);
    uimenu(LIGHTING_MENU,'label','Flat','Callback',@light_flat_callback);

    SELECT_POLARITY_MENU = uimenu(VIEW_MENU,'label','Overlay Polarity','separator','on');   
    uimenu(SELECT_POLARITY_MENU,'label','Positive Data Only','Callback',@select_polarity_callback);    
    uimenu(SELECT_POLARITY_MENU,'label','Negative Data Only','Callback',@select_polarity_callback);    
    uimenu(SELECT_POLARITY_MENU,'label','Positive and Negative','Callback',@select_polarity_callback);    

    uimenu(VIEW_MENU,'label','Show Curvature','separator','on','Callback',@show_curvature_callback);
    uimenu(VIEW_MENU,'label','Show Cortical Thickness','Callback',@show_thickness_callback);    

    ph = [];    
    ph = patch('Vertices',[], 'Faces', [] );

    % overlay patch
    ph2 = [];    
    ph2 = patch('Vertices',[], 'Faces', [] );
    ph2.Clipping = 'off';    
    
    
    shading flat      
    lighting gouraud
    
    cl=camlight('left');
    set(cl,'Color',[0.6 0.6 0.6]);
    cr=camlight('right');
    set(cr,'Color',[0.6 0.6 0.6]);
    ax = gca;
    
    axis off
    axis vis3d
    axis equal
    set(ax,'CameraViewAngle',7,'View',[160, 30]); 
    axtoolbar('Visible', 'on');
    axtoolbar('default');
    
    caxis([0 1]);
    xlim([xmin xmax]);
    ylim([ymin ymax]);
    zlim([zmin zmax]);   
    
    h = datacursormode(fh);
    set(h,'enable','on','UpdateFcn',@UpdateCursors);
    h.removeAllDataCursors;

    h = rotate3d;
    h.Enable = 'on';
    
    h.ActionPostCallback = @reset_lighting_callback;
    % suppress El/Az readout
    h.ActionPreCallback = @rotate3d_ActionPreCallback; 
        function rotate3d_ActionPreCallback(v,~,~)
            hm = uigetmodemanager(v);
            hm.CurrentMode.ModeStateData.textBoxText.Visible = 'off';
        end
   
    if exist('meshFile','var')
        if ~isempty(meshFile)       % if passed empty variable load template.
            loadMesh(meshFile);  
            s = sprintf('File: %s', meshFile);
            set(FILE_TEXT,'string',s);       
        end
    end
   
    if exist('overlayFiles','var')
        if isempty(meshFile)
            LOAD_FSAVERAGE_CALLBACK;    % if no meshfile passed use template
        end      
        load_overlay_files(overlayFiles)   
    end
    
    hold all;
    
    % end initialization
    %%%%%%%%%%%%%%%%%%%%%%%%%
    
        function LOAD_MESH_CALLBACK(~,~)
            [filename, pathname, ~]=uigetfile('*.mat','Select BrainWave Surface File ...');
            if isequal(filename,0)
                return;
            end
            meshFile = [pathname filename];
            loadMesh(meshFile);          
            s = sprintf('File: %s', meshFile);
            set(FILE_TEXT,'string',s);     
        end
    
        function LOAD_TEMPLATE_CALLBACK(~,~)
            meshFile = sprintf('%s%stemplates%sCH2%sCH2_MRI%sFS_SURFACES.mat',DT_PATH,filesep,filesep,filesep,filesep);
            loadMesh(meshFile);      
            s = sprintf('Template: Colin-27');
            set(FILE_TEXT,'string',s);     
        end   
    
        function LOAD_FSAVERAGE_CALLBACK(~,~)
            meshFile = sprintf('%s%stemplates%sfsaverage%sfsaverage6%sFS_SURFACES.mat',DT_PATH,filesep,filesep,filesep,filesep);
            loadMesh(meshFile);          
            s = sprintf('Template: fsaverage6');
            set(FILE_TEXT,'string',s);     
        end     
    
        function loadMesh(file)
            
            if ~isempty(mesh)
                r = questdlg('This will clear all current data. Proceed?');
                if ~strcmp(r,'Yes') == 1
                    return;
                end
            end
            
            % check for correct .mat file structure
            t = load(meshFile);   
            if ~isstruct(t)
                errordlg('This does not appear to be a valid BrainWave surface file\n');
                return;
            end  
            fnames = fieldnames(t);
            test = t.(char(fnames(1)));
            if ~isfield(test,'vertices')
                errordlg('This does not appear to be a valid BrainWave surface file\n');
                return;
            end        
            
            meshes = t;
            clear t;

            vertices = [];
            faces = [];
            
            if ~isempty(fsl_vertices)
                fsl_vertices = [];
                fsl_faces = [];   
                set(ph2,'Vertices',[],'Faces',[]);
            end
                      
            overlay = []; % vertex data
            roi.vertices = [];
            
            meshFile = file;      
            meshNames = fieldnames(meshes);
            numMeshes = length(meshNames);
            selected_mesh = 1;                       
            mesh = meshes.(char(meshNames(selected_mesh)));
            
            RAS_to_MEG = inv(mesh.MEG_to_RAS);
            
            g_peak = [];
            
            % rebuild mesh menu
            items = get(MESH_MENU,'Children');
            if ~isempty(items)
                delete(items);
            end            
            for j=1:numMeshes
                tmenu = uimenu(MESH_MENU,'Label',char(meshNames(j)),'Callback',@mesh_menu_callback);        
                if j == 1
                    set(tmenu,'Checked','on');
                end
            end      
                        
            s = sprintf('Surface: %s', char(meshNames(selected_mesh)));
            set(SURFACE_TEXT,'string',s);   
            
            overlay_data = [];
            roi_data = {};
            selectedOverlay = 0;
            selectedROI= 0;
            overlay_files = {};
            
            set(OVERLAY_LIST,'string','');
            set(ROI_LIST,'string',{});
            
            updateROIText([]);
            updateSliderText;
           
            drawMesh;
            reset_lighting_callback;  
            
            cropMesh;

        end
        
        function IMPORT_MESH_CALLBACK(~,~)                                    
            meshFile = dt_import_surfaces;               
            if ~isempty(meshFile)
                loadMesh(meshFile)
                s = sprintf('File: %s', meshFile);
                set(FILE_TEXT,'string',s);     
            end           
        end
    
        function LOAD_VTK_MESH_CALLBACK(~,~)
            [filename, pathname, ~]=uigetfile('*.vtk','Select VTK Mesh File ...');
            if isequal(filename,0)
                return;
            end
            vtkFile = [pathname filename];
            
            [~, mdata] = bw_readMeshFile(vtkFile);
            fprintf('read total of %d vertices and % d faces from %s...\n', ...
                size(mdata.vertices,1), size(mdata.faces,1), vtkFile);

            t_vertices = mdata.vertices;       
            fsl_faces = mdata.faces + 1;
            
            % need to know how to scale to voxels?
            % assume is 1mm per voxel for now..
                      
%             fprintf('rescaling mesh from mm to voxels\n');
%             vertices = vertices ./mmPerVoxel;
% 
%             % convert mesh from LAS back to RAS. According to Marc's notes 
%             % FSL voxels are indexed from 0 to 255
%             %

            t_vertices(:,1) = 255 - t_vertices(:,1);   
             
            % convert to MEG coordinates for drawing
            
            fsl_vertices = [t_vertices ones(size(t_vertices,1),1)] * RAS_to_MEG;
            fsl_vertices(:,4) = [];
            
            drawMesh;          
            reset_lighting_callback;  
            
            set(sl(14:15),'visible','on');

        end
     
        %%%%%%%%%%%%%% Overlays %%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
        function LOAD_VERTEX_DATA_CALLBACK(~,~)        
            [names, pathname, ~]=uigetfile('*.txt','Select image files...', 'MultiSelect','on');            
            if isequal(names,0)
                return;
            end                      
            names = cellstr(names);   % force single file to be cellstr
            filenames = strcat(pathname,names);     % prepends path to all instances           
            load_overlay_files(filenames);           
        end
    
        function LOAD_ERB_CALLBACK(~,~)        
            [names, pathname, ~]=uigetfile('w*.nii','Select Normalized ERB/SAM image...', 'MultiSelect','on');            
            if isequal(names,0)
                return;
            end                      
            names = cellstr(names);   % force single file to be cellstr
            filenames = strcat(pathname,names);      % prepends path to all instances
            load_overlay_files(filenames);           
        end
    
    
        function SAVE_OVERLAY_CALLBACK(~,~)
            
            if isempty(overlay)
                fprintf('No overlay data to save...\n');
                return;
            end
            
            
            % GUI to get patch order 
            voxelSize = 1; 
            imageSize = [256 256 256];
            maskValue = 255;
            coordFlag = 2;
            inflationFactor = 0;
            input = inputdlg({'Image Voxel Size (mm)'; 'Image dimensions (voxels)'; 'Mask Inflation Factor (voxels)';'Mask Value (integer)';...
                'Coordinate System (1 = MNI, 2 = RAS)'},'Save Overlay Volume',[1 50; 1 50; 1 50; 1 50; 1 50],...
                {num2str(voxelSize), num2str(imageSize),num2str(inflationFactor),num2str(maskValue),num2str(coordFlag)});
            if isempty(input)
                return;
            end   
            voxelSize = round( str2double(input{1}) );
            imageSize =  str2num(input{2});
            inflationFactor = round(str2double(input{3}));
            maskValue = str2double(input{4});
            coordFlag = round(str2double(input{5}));
            
            [filename, pathname, ~]=uiputfile('*.nii','Select File Name for Volume ...');
            if isequal(filename,0)
                return;
            end           
            overlayFile = [pathname filename];
            
            % get overlay vertices
            idx = find(overlay > overlay_threshold * g_scale_max);
            if coordFlag == 1
                voxels = round(mesh.normalized_vertices(idx,1:3));  
            else
                voxels = round(mesh.mri_vertices(idx,1:3));
            end
            
            % inflate mask      
            if inflationFactor > 0
                % inflate by one voxel and repeat to inflate the inflated
                % voxels by addition one voxel, eliminating duplicates
                for j=1:inflationFactor
                    newVox = [];
                    for k=1:size(voxels,1)               
                        newVox(end+1,1:3) = [voxels(k,1)+1 voxels(k,2) voxels(k,3)];
                        newVox(end+1,1:3) = [voxels(k,1)-1 voxels(k,2) voxels(k,3)];
                        newVox(end+1,1:3) = [voxels(k,1) voxels(k,2)+1 voxels(k,3)];
                        newVox(end+1,1:3) = [voxels(k,1) voxels(k,2)-1 voxels(k,3)];
                        newVox(end+1,1:3) = [voxels(k,1) voxels(k,2) voxels(k,3)+1];
                        newVox(end+1,1:3) = [voxels(k,1) voxels(k,2) voxels(k,3)-1];
                    end
                    allVox = [voxels; newVox];
                    voxels = unique(allVox,'rows');
                end
            end
            
            if coordFlag == 1              
                dt_make_MNI_mask(overlayFile, voxels, maskValue, voxelSize);
            else
                dt_make_RAS_mask(overlayFile, voxels,maskValue, voxelSize, imageSize);
            end
            
        end
      
       function load_overlay_files(overlayFiles)
                           
            filenames = cellstr(overlayFiles);   % forces single file to be cellstr      
            
            if ~isempty(overlay_data)
                r = questdlg('Add to current overlays or Replace?','Load Overlays','Add','Replace','Add');
                if strcmp(r,'Replace')
                    overlay_data = [];
                    overlay = [];
                    set(OVERLAY_LIST,'string','');
                    selectedOverlay = 0;
                    set(OVERLAY_LIST, 'value',1);
                    overlay_files = {};
                end
            end           
            
            % check file type
            s = char(filenames(1));
            [~,~,ext] = fileparts(s);

            if strcmp(ext,'.nii')
                for j=1:numel(filenames)
                    load_nii_image(char(filenames(j)));
                end                
            elseif strcmp(ext,'.txt')
                for j=1:numel(filenames)
                    load_ascii_image(char(filenames(j)));
                end                               
            else
                fprintf('unknown file type\n');
                return;
            end
        end
    
        function load_ascii_image(txtFile)    
          
            fid1 = fopen(txtFile,'r');
            if (fid1 == -1)
                fprintf('failed to open file <%s>\n',txtFile);
                return;
            end
            C = textscan(fid1,'%f');
            fclose(fid1);
            overlay=cell2mat(C);  
            
            % remove any nans
            overlay(find(isnan(overlay))) = 0.0;
            
            % add to overlay list - use short names
            overlay_data(:,end+1) = overlay;
            overlay_files(end+1) = cellstr(txtFile);
            selectedOverlay = size(overlay_data,2);
                                   
            list = get(OVERLAY_LIST,'string');
            [~,n,e] = fileparts(txtFile);
            list{end+1} = [n e];
            set(OVERLAY_LIST,'string',list);
            set(OVERLAY_LIST,'value',selectedOverlay);
                        
            drawMesh;
        end
    
        function load_nii_image(niiFile)
            % load normalized image - in MNI coordinates. 
            nii = load_nii(niiFile);
            if isempty(nii)
               return;
            end                  
            fprintf('Interpolating normalized source image onto surface...\n' );
                                              
            % have to get vertices in RAS for the volume being passed to interp3.
            % normalized SAM images should already be in RAS coordinates
            dims = nii.hdr.dime.dim(2:4);      
            pixdim = nii.hdr.dime.pixdim(2:4); 
            origin = [nii.hdr.hist.srow_x(4) nii.hdr.hist.srow_y(4) nii.hdr.hist.srow_z(4)];
            % check for flipped axes and compute negative (RAS) origin. 
            if origin(1) > 0
                origin(1) = origin(1) - (dims(1)-1) * pixdim(1); % subtract one for zero voxel
            end
            if origin(2) > 0
                origin(2) = origin(2) - (dims(2)-1) * pixdim(2);
            end
            if origin(3) > 0
                origin(3) = origin(3) - (dims(3)-1) * pixdim(3);
            end
            
            pixdim = [nii.hdr.dime.pixdim(2) nii.hdr.dime.pixdim(3) nii.hdr.dime.pixdim(4)];
            
            % interpolation points have to be in same coordinate space
            Xcoord = double(mesh.normalized_vertices(:,1)');
            Ycoord = double(mesh.normalized_vertices(:,2)');
            Zcoord = double(mesh.normalized_vertices(:,3)');
            
            Xcoord = ((Xcoord - origin(1) ) / pixdim(1)) + 1;  
            Ycoord = ((Ycoord - origin(2) ) / pixdim(2)) + 1;
            Zcoord = ((Zcoord - origin(3) ) / pixdim(3)) + 1; 
            
            % interpolate volumetric image (Z) onto the MNI mesh vertices using trilinear interpolation
            % need to reverse X and Y coords as per Matlab documentation for interp3
            % Vq = interp3(V,Xq,Yq,Zq) assumes X=1:N, Y=1:M, Z=1:P  where [M,N,P]=SIZE(V).
            
            if exist('trilinear','file')
                overlay = trilinear(nii.img, Ycoord, Xcoord, Zcoord )';       
            else
                fprintf('trilinear mex function not found. Using Matlab interp3 builtin function\n');
                overlay = interp3(nii.img, Ycoord, Xcoord, Zcoord,'linear',0 )';
            end
            
            % remove any nans
            overlay(find(isnan(overlay))) = 0.0;
            
            % add to overlay list - use short names
            overlay_data(:,end+1) = overlay;
            overlay_files(end+1) = cellstr(niiFile);
            selectedOverlay = size(overlay_data,2);
                                   
            list = get(OVERLAY_LIST,'string');
            [~,n,e] = fileparts(niiFile);
            list{end+1} = [n e];
            set(OVERLAY_LIST,'string',list);
            set(OVERLAY_LIST,'value',selectedOverlay);
                        
            drawMesh;
            
        end
          
        %%%%%%%%%%%%%%% DTI %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    
        function LOAD_DTI_CALLBACK(~,~)       
            
            r = '';
            if ~isempty(dti_pts)
                r = questdlg('Replace or add to current DTI overlay?','Surface Viewer','Replace','Add','Cancel','Replace');
                if strcmp(r,'Cancel')
                    return;
                end
                if strcmp(r,'Replace')
                    set(dti_pts,'visible','off');  % delete doesn't seem to erase               
                    dti_pts = [];
                    dti_volume = [];
                end

            end
            
            [filename, pathname, ~]=uigetfile('*.nii','Select DTI NIfTI File...');            
            if isequal(filename,0)
                return;
            end
            dtiFile = [pathname filename];
            
            % load NIfTI overlay file - assumes this is in the same MRI volume as the mesh file! 
            fprintf('Reading NIfTI file %s...\n', dtiFile);            
            nii = load_nii(dtiFile);
            if isempty(nii)
               return;
            end
                  
            % only read non-zero voxels
            idx = find(nii.img > 0.0);
            vals = single(nii.img(idx));
            
            % get dti tract pixel volume in mm^3
            dti_voxel_size = nii.hdr.dime.pixdim(1) * nii.hdr.dime.pixdim(2) * nii.hdr.dime.pixdim(3);
            
            [x, y, z] = ind2sub(size(nii.img),idx);
            pts = [x y z];
            
            ras_pts = [pts ones(size(pts,1),1)] * RAS_to_MEG;
            ras_pts(:,4) = [];
                         
            clear nii;
            
            hold on
            
            fprintf('plotting dti volume ...\n');
            
            if strcmp(r,'Add')
                dti_volume = [dti_volume; ras_pts];
                dti_vals = [dti_vals; vals];
            else
                dti_volume = ras_pts;
                dti_vals = vals;
            end
            
            if ishandle(dti_pts)
                set(dti_pts,'visible','off');  % delete doesn't seem to erase         
            end
            
            % threshold dti
            cutoff = dti_threshold * dti_max;           
            idx = find(dti_vals > cutoff);
          
            dti_pts = scatter3(dti_volume(:,1),dti_volume(:,2),dti_volume(:,3),40, 'blue', 'filled','square'); 
            
            dti_max = max(dti_vals);
                
            vol = dti_voxel_size * numel(idx);
            s = sprintf('Tract Volume = %.2f mm%s)', vol, char(179));
            set(sl(17),'string', s);

            hold off

            set(sl(12:13),'visible','on');
            set(sl(16:17),'visible','on');
                       
        end
    
        function dti_slider_Callback(src,~)
            
            dti_threshold = get(src,'value');
            
            if isempty(dti_volume) 
                return;
            end
            
            % threshold dti
            cutoff = dti_threshold * dti_max;           
            idx = find(dti_vals > cutoff);
            fprintf('setting DTI threshold to %.1f\n', cutoff);
            
            s = sprintf('%.2f', dti_threshold * 100);
            set(sl(16),'string',s);
            
            hold on;
            set(dti_pts,'XData',dti_volume(idx,1),'YData',dti_volume(idx,2),'ZData',dti_volume(idx,3));                        
                        
            hold off;
            
            vol = dti_voxel_size * numel(idx);
            s = sprintf('Tract Volume = %.2f mm%s', vol, char(179));
            set(sl(17),'string', s);
            
        end
    
        function dti_edit_Callback(src,~)
            
            val = str2double(get(src,'string'));
            
            if val < 0 || val > 100
                set(src,'string',num2str(dti_threshold * 100));
                return;
            end
            
            dti_threshold = val * 0.01;
            
            % threshold dti
            cutoff = dti_threshold * dti_max;           
            fprintf('setting DTI threshold to %.1f\n', cutoff);
            
            set(sl(16),'string',dti_threshold * 100);
            idx = find(dti_vals > cutoff);
            
            hold on;
            set(dti_pts,'XData',dti_volume(idx,1),'YData',dti_volume(idx,2),'ZData',dti_volume(idx,3));                        
            
            vol = dti_voxel_size * numel(idx);
            s = sprintf('Tract Volume = %.2f mm%s)', vol, char(179));
            set(sl(17),'string', s);
            
            hold off;
            
        end  
    
        function delete_dti_callback(~,~)          
            if ishandle(dti_pts)
                set(dti_pts,'visible','off');  % delete doesn't seem to erase               
                dti_pts = [];
                dti_volume = [];
                drawMesh;
%                 set(sl(:),'visible','off');
            end
        end
     
    
        %%%%%%%%%%%%%%% ROIs %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
      
        function REGION_GROWING_CALLBACK(~,~)
 
            if isempty(selectedVertex)
                warndlg('Use cursor to select a seed vertex ...');
                return;
            end
                        
            % GUI to get patch order 
            patchOrder = 5; 
            input = inputdlg('Select Neighborhood Order','Patch Parameters',[1 35], {num2str(patchOrder)});
            if isempty(input)
                return;
            end
          
            patchOrder = str2double(input{1});
            
            % function uses MEG vertices in cm!
            [patch_vertices, nfaces, area] = dt_compute_patch_from_vertex(mesh, selectedVertex, patchOrder);
            seed = round(mesh.normalized_vertices(selectedVertex,:));
            fprintf('patchOrder %d, # vertices = %d, # triangles = %d, area = %g cm^2\n',...
                patchOrder, size(patch_vertices,1), size(nfaces,1), area);       
                
            if ~isempty(patch_vertices)  
                roi.vertices = patch_vertices;
                
                name = sprintf('Patch (order=%d, seed=%d %d %d)', patchOrder, seed);
                roi.name = name;                              
                roi.centroid = seed;    
                roi.center = seed;  
                                
                [~, roi.area] = computeROIArea(roi.vertices);
                % centroid is already on cortex
                roi.volume = roi.area;
                                 
                %  set to uniform scale 
                roi.overlay = ones(size(roi.vertices,1),1);
                roi.vertex = selectedVertex;
                
                % add roi to list
                roi_data{end+1} = roi;
                
                list = get(ROI_LIST,'string');
                list{end+1} = roi.name;
                set(ROI_LIST,'string',list);
                selectedROI = numel(list);
                set(ROI_LIST,'value',selectedROI);
                
                % set overlay to roi
                % set threshold to zero
                overlay = zeros(size(vertices,1),1);
                overlay(roi.vertices) = roi.overlay;      
                g_scale_max = 1.0;
                overlay_threshold = 0.0;
                set(THRESH_SLIDER,'value', overlay_threshold);
                updateCursorText;
                
                updateROIText(roi);       
                setCursor(selectedVertex);
                drawMesh;           
            end

        end  
 
        function LOAD_ATLAS_CALLBACK(~,~)
            
            % select atlas regions             
            [voxel_list, voxelSize, labels, atlasName] = dt_getAtlasRegionDlg;
            if isempty(voxel_list)
                return;
            end
            
            for j=1:numel(voxel_list)
                name = sprintf('%s (%s)',atlasName, char(labels(j)));          
                mni_voxels = voxel_list{j};
                add_ROI(mni_voxels, voxelSize, name, 1);
            end
            
        end    
        function add_ROI(mni_voxels, voxelSize, name, interpolate)
            
            if isempty(mni_voxels)
                return;
            end
            
            roi = [];
            
            if ~exist('interpolate','var')
                interpolate = 1;        
            end
            
            if (interpolate == 1)
                % interpolate selected atlas voxels onto surface
                % 1. create a mask volume of selected atlas voxels
                %    ** use same voxel resolution as original atlas 
                fprintf('Interpolating ROI onto cortical surface ...\n');
                origin = [-90 -126 -90];    % BB large enough to include all atlas voxels - use even numbers!
                dims(1) = round( abs(origin(1)) * 2 / voxelSize) + 1;
                dims(2) = round( abs(origin(2)) * 2 / voxelSize) + 1;
                dims(3) = round( abs(origin(3)) * 2 / voxelSize) + 1;         

                % 2. convert mni coords to voxels
                Vol = zeros(dims);
                v = (mni_voxels - repmat(origin,size(mni_voxels,1),1));
                voxels = round( v / voxelSize) + 1;  % add one to save in matlab array

                idx = sub2ind(size(Vol),voxels(:,1), voxels(:,2), voxels(:,3));       
                Vol(idx) = 1.0;          

                % interpolation points have to be in same coordinate space
                % we already have mesh in MNI coordinates - need to convert to voxels
                Xcoord = double(mesh.normalized_vertices(:,1)');
                Ycoord = double(mesh.normalized_vertices(:,2)');
                Zcoord = double(mesh.normalized_vertices(:,3)');

                Xcoord = ((Xcoord - origin(1) ) / voxelSize) + 1; % add 1 to shift to base 1 array indexing  
                Ycoord = ((Ycoord - origin(2) ) / voxelSize) + 1;
                Zcoord = ((Zcoord - origin(3) ) / voxelSize) + 1;            

                % 3.  interpolate volume onto surface ...
                if exist('trilinear','file')
                    data = trilinear(Vol, Ycoord, Xcoord, Zcoord )';       
                 else
                    fprintf('trilinear mex function not found. Using Matlab interp3 builtin function\n');
                    data = interp3(Vol, Ycoord, Xcoord, Zcoord,'linear',0 )';
                end

                % 4. remove any nans and set non-zero vertices to ROI vertices 
                data(isnan(data)) = 0.0;
                idx = find(data > 0.0);
                roi.vertices = idx;     
            else
                % intersection method
                fprintf('Computing intersection of ROI with cortical surface ...\n');
                verts = round(mesh.normalized_vertices);
                voxels = round(mni_voxels);
                tidx = ismember(verts,voxels,'rows');
                idx = find(tidx);
                roi.vertices = double(idx);
                clear verts
                clear voxels              
            end      
           
            if ~isempty(mni_voxels) 
                roi.name = name;                              
                roi.centroid = mean(mni_voxels,1);       % set to centroid of ROI, not surface center
                                
                roi.volume = size(mni_voxels,1) * (voxelSize * 0.1)^3;
                [~, roi.area] = computeROIArea(roi.vertices);
                
                % project centroid onto cortex
                distances = vecnorm(mesh.normalized_vertices' - repmat(roi.centroid, mesh.numVertices,1)');
                [~, vertex] = min(distances);
                roi.center = mesh.normalized_vertices(vertex,1:3);  
                 
                % weight value by distance of vertices to center            
%                 distances = vecnorm(mesh.normalized_vertices(roi.vertices,:)' - repmat(roi.center, size(roi.vertices,1),1)');
%                 roi.overlay = distances;
%                 roi.overlay = 1 - (distances / max(distances));
                
                % otherwise set to uniform scale 
                roi.overlay = ones(size(roi.vertices,1),1);
                roi.vertex = vertex;
                
                % add roi to list
                roi_data{end+1} = roi;
                
                list = get(ROI_LIST,'string');
                list{end+1} = roi.name;
                set(ROI_LIST,'string',list);
                selectedROI = numel(list);
                set(ROI_LIST,'value',selectedROI);
                
                % set overlay to roi
                % set threshold to zero
                overlay = zeros(size(vertices,1),1);
                overlay(roi.vertices) = roi.overlay;      
                g_scale_max = 1.0;
                overlay_threshold = 0.0;
                set(THRESH_SLIDER,'value', overlay_threshold);
                updateCursorText;
                
                updateROIText(roi);       
                setCursor(vertex);
            end
            
            drawMesh;           
        end
    
        %%%%%%%%%%%%%% GUI controls %%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
                
        function mesh_menu_callback(src,~)            
            item = get(src,'position');
            if item == selected_mesh
                return;
            end
            selected_mesh = item;    
            
            % uncheck all menus
            set(get(MESH_MENU,'Children'),'Checked','off');
            set(src,'Checked','on');         
            mesh = meshes.(char(meshNames(selected_mesh)));   
            s = sprintf('Surface: %s', char(meshNames(selected_mesh)));
            set(SURFACE_TEXT,'string',s);   

            % since overlays are interpolated onto a specific surface have to
            % reinterpolate them when changing meshes
            if ~isempty(overlay_data) || ~ isempty(overlay_files)  
                
                % delete overlays and reload 
                overlay_data = [];
                overlay = [];
                set(OVERLAY_LIST,'string','');
                selectedOverlay = 0;
                set(OVERLAY_LIST, 'value',1);  
                
                % need to reset overlay_files as it will get added
                saveList = overlay_files;
                load_overlay_files(overlay_files);   
                overlay_files = saveList;
            end
            
            if ~ isempty(roi_data)              
                r = questdlg('This will clear all current ROIs. Continue?');
                if strcmp(r,'Yes') == 0
                    return;
                end
                roi_data = {};
                updateROIText([]);
                overlay = [];
                set(ROI_LIST, 'value',1);
                set(ROI_LIST,'string', {});

            end
            cropMesh;
            drawMesh;        
        end
    
        function hemisphere_select_callback(src, ~)           
            hemisphere = get(src,'position');
            items = get(HEMI_MENU,'Children');
            set(items,'Checked','off');
            % correct for reversed menu position 
            x = [3 2 1];
            set(items(x(hemisphere)),'checked','on');
            drawMesh;
         
        end
    
        function set_orientation_callback(src,~)
            item = get(src,'position');
            switch item
                case 1
                    set(gca,'View',[-90 90]);
                case 2
                    set(gca,'View',[180 0]);
                case 3
                    set(gca,'View',[0 0]);
                case 4
                    set(gca,'View',[90 0]);
                case 5
                    set(gca,'View',[-90 0]);
            end
            reset_lighting_callback;
        end
    
        function show_interp_callback(src, ~)      
            shading(gca,'interp');       
            set(get(SHADING_MENU,'Children'),'Checked','off');
            set(src,'Checked','on');        
        end

        function show_flat_callback(src, ~)      
            shading(gca,'flat');       
            set(get(SHADING_MENU,'Children'),'Checked','off');
            set(src,'Checked','on');        
        end

        function light_flat_callback(src, ~)      
            lighting(gca,'flat');       
            set(get(LIGHTING_MENU,'Children'),'Checked','off');
            set(src,'Checked','on');        
        end

        function light_gouraud_callback(src, ~)      
            lighting(gca,'gouraud');       
            set(get(LIGHTING_MENU,'Children'),'Checked','off');
            set(src,'Checked','on');        
        end
    
    
        function show_faceted_callback(src, ~)      
            shading(gca,'faceted');       
            set(get(SHADING_MENU,'Children'),'Checked','off');
            set(src,'Checked','on');        
        end
   
    
        function show_curvature_callback(src, ~)
            showCurvature = ~showCurvature;        
            if showCurvature
                set(src,'Checked','on');   
            else
                set(src,'Checked','off');   
            end
            
            drawMesh;
        end

        function show_thickness_callback(src,~)                 
            showThickness = ~showThickness;        
            if showThickness
                set(src,'Checked','on');   
            else
                overlay = [];
                set(src,'Checked','off');   
            end            
            drawMesh;           
        end
            
        function select_overlay_callback(src,~)
            selectedOverlay = get(src,'value');
            overlay = overlay_data(:,selectedOverlay);        
            updateCursorText;
            drawMesh;        
        end   
    
        function select_polarity_callback(src,~)
            selectedPolarity = get(src,'position');
            items = get(SELECT_POLARITY_MENU,'Children');
            set(items,'Checked','off');
            set(src,'Checked','on');
            drawMesh;        
        end       

    
        function CLEAR_OVERLAY_CALLBACK(~,~)
            overlay = [];
            updateSliderText;
            drawMesh;
            
        end 
    
        function delete_all_overlays_callback(~,~)
            if isempty(overlay_data)
                return;
            end
            r = questdlg('Delete all overlays?');
            if strcmp(r,'Yes')
                overlay_data = [];
                overlay = [];
                set(OVERLAY_LIST,'string','');
                selectedOverlay = 0;
                set(OVERLAY_LIST, 'value',1);
                overlay_files = {};
                
                drawMesh;
                
            end        
        end 
    
        function delete_overlay_callback(~,~)
            if isempty(overlay_data)   
                return;
            end
            list = get(OVERLAY_LIST,'string');
            s = sprintf('Delete overlay %s?',char(list(selectedOverlay)) );
            r = questdlg(s);
            if strcmp(r,'Yes')
                overlay_data(:,selectedOverlay) = [];
                list(selectedOverlay,:) = [];
                overlay_files(selectedOverlay) = [];              
                if isempty(overlay_data)  
                    overlay = [];
                else
                    if selectedOverlay > 1
                        selectedOverlay = selectedOverlay - 1;
                    end
                    set(OVERLAY_LIST, 'value',selectedOverlay);
                    overlay = overlay_data(:,selectedOverlay);
                end
                set(OVERLAY_LIST,'string', list);
                   
                drawMesh;
            end
            
        end 
   
        function select_roi_callback(src,~)
            if isempty(roi_data)
                return;
            end
            verts = [];
            selectedROI = get(src,'value');
            for j=1:length(selectedROI)
                roi = roi_data{selectedROI(j)};  
                verts = [verts; roi.vertices];
            end
            overlay = zeros(size(vertices,1),1);
            overlay(verts) = 1.0;            
            
            updateROIText(roi);
            drawMesh;  
            setCursor(roi.vertex);
           
        end
    

        function delete_roi_callback(~,~)
                            
            if isempty(roi_data)   
                return;
            end
            selectedROI = get(ROI_LIST,'value');
            r = questdlg('Delete selected ROIs?');
            if strcmp(r,'Yes')
                roi_data(:,selectedROI) = [];
                list = get(ROI_LIST,'string');
                list(selectedROI) = [];
                set(ROI_LIST, 'value',1);
                set(ROI_LIST,'string', list);
                if isempty(roi_data)
                    updateROIText([]);
                    overlay = [];
                else
                    roi = roi_data{1};  
                    overlay = zeros(size(vertices,1),1);
                    overlay(roi.vertices) = 1.0;            
                    updateROIText(roi);
                end
                drawMesh;
            end
            
        end 
    
        function delete_all_roi_callback(~,~)
                            
            if isempty(roi_data)   
                return;
            end
            
            r = questdlg('Delete all ROIs?');
            if strcmp(r,'Yes')
                roi_data = [];
                set(ROI_LIST, 'value',1);
                set(ROI_LIST,'string', '');
                updateROIText([]);
                overlay = [];
                drawMesh;
            end           
        end
    
        function reset_lighting_callback(~, ~)            
            if exist('cl','var')              
               delete(cl);
            end         
            if exist('cr','var')
                delete(cr);
            end
            cl=camlight('left');
            set(cl,'Color',[0.5 0.5 0.5]);
            cr=camlight('right');
            set(cr,'Color',[0.5 0.5 0.5]);
                
            material([0.3 0.7 0.4]);        % less shiny than default
       
        end
   
   
        function slider_Callback(src,~)  
            val = get(src,'value');
            overlay_threshold = val;      
            s = sprintf('%0.1f',overlay_threshold);
            set(THRESH_EDIT,'string',s);

            drawMesh;
           
        end
   
        function threshEditCallback(src,~)
            % in percent...
            s = get(src,'string');
            val = abs(str2double(s));
            if val > 100
                val = 100.0; 
                s = sprintf('%0.1f',val);
                set(THRESH_EDIT,'value', val);
            end
            if val < 0.0
                val = 0.0; 
                s = sprintf('%0.1f',val);
                set(THRESH_EDIT,'value', val);
            end
            overlay_threshold = val / 100.0;
            % slider is normalized 0 - 1
            set(THRESH_SLIDER,'value', overlay_threshold);

            drawMesh;           
        end
   
        function maxEditCallback(src,~)
           s = get(src,'string');
           val = abs(str2double(s));
           g_scale_max = val;     
           
           drawMesh;           
        end  
   
        function  autoScaleCallback(src,~) 
           autoScaleData = get(src,'value'); 
           
           if autoScaleData
               set(MAX_EDIT,'enable','off');
           else
               set(MAX_EDIT,'enable','on');
           end
               
           drawMesh;
        end   
    
        function saveMovieCallback(src,~)
           save_movie = get(src,'value');
        end
   
        function brainOnlyCallback(src,~)
            cropMovie = get(src,'value');
            if cropMovie        
                rect(1:2) = cropRect(1:2) - 0.01;
                rect(3:4) = cropRect(3:4) + 0.02;
                movieRect = annotation('rectangle',rect,'color','red','visible','on');
             else
                if ~isempty(movieRect)
                    delete(movieRect);
                end
            end
               
        end
      
        function fsl_transparency_slider_Callback(src,~)
            val = get(src,'value');
            fsl_transparency = val;      
            set(ph2,'faceAlpha',fsl_transparency);
        end
    
        function transparency_slider_Callback(src,~)  
            val = get(src,'value');
            transparency = val;      
            set(ph,'faceAlpha',transparency);
        end
   
        function x1_slider_Callback(src,~)
            xmin = get(src,'value');
            cropMesh;
        end
    
        function x2_slider_Callback(src,~)
            xmax = get(src,'value');
            cropMesh;
        end
  
        function y1_slider_Callback(src,~)
            ymin = get(src,'value');
            cropMesh;
        end
    
        function y2_slider_Callback(src,~)
            ymax = get(src,'value');
            cropMesh;
        end
    
    
        function z1_slider_Callback(src,~)
            zmin = get(src,'value');
            cropMesh;
        end
    
        function z2_slider_Callback(src,~)
            zmax = get(src,'value');
            cropMesh;
        end
    

        function cropMesh
            
            if isempty(meshes)
                return;
            end
            
            % reload original mesh
            mesh = meshes.(char(meshNames(selected_mesh)));   
            
            v = mesh.vertices;  % plot in native (MEG) space
            f = mesh.faces + 1;  % shift face indices to base 1 array indexing
            
            % image cropping

            fidx = [];
           
            % get indices of visible faces 
            for k=1:mesh.numLeftFaces
               if   all( v(f(k),1) < xmax ) && all( v(f(k),1) > xmin) && ....
                    all( v(f(k),2) < ymax ) && all( v(f(k),2) > ymin) && ...
                    all( v(f(k),3) < zmax ) && all( v(f(k),3) > zmin)
                   fidx(end+1) = k;
               end
            end
            fleft = f(fidx,:);
           
            fidx = [];
            for k=mesh.numLeftFaces+1: mesh.numFaces
               if   all( v(f(k),1) < xmax ) && all( v(f(k),1) > xmin) && ....
                    all( v(f(k),2) < ymax ) && all( v(f(k),2) > ymin) && ...
                    all( v(f(k),3) < zmax ) && all( v(f(k),3) > zmin)
                   fidx(end+1) = k;
               end
            end
            fright = f(fidx,:);
            
            % correct number of left and right faces
            mesh.numLeftFaces = size(fleft,1);   
            mesh.numRightFaces = size(fright,1);
            mesh.numFaces = mesh.numLeftFaces + mesh.numRightFaces;
            
            fnew = [fleft; fright];
            mesh.faces = fnew - 1;
            
            drawMesh;
        end
   
       function drawMesh()

            lightGrey = scaleCutoff_p - (1/size(cmap,1)) * 0.8;     
            darkGrey = 0.5 - (1/size(cmap,1)) * 0.8;   
            vertexColors = ones(1,size(mesh.vertices,1)) * lightGrey;

            vertices = mesh.vertices;  % plot in native (MEG) space
            faces = mesh.faces;
            faces = faces + 1;  % shift face indices to base 1 array indexing

            if showCurvature
                if isfield(mesh,{'curv'})                    
                    idx_s = find( mesh.curv > 0.0);
                    idx_g = find( mesh.curv < 0.0);
                    vertexColors(idx_s) = darkGrey; 
                    vertexColors(idx_g) = lightGrey;   
                end                
            end
                   
            if showThickness
                % make sure CT does not have negative values.
                idx = find(mesh.thickness < 0.0);
                mesh.thickness(idx) = 0.0;           
                overlay = mesh.thickness;  % overwrite overlay
            end
            
            if ~isempty(overlay)   
                plotData = overlay;     % don't overwrite
                
                % select polarity before scaling
                if selectedPolarity == 1
                    plotData(find(plotData < 0.0)) = 0.0;
                elseif selectedPolarity == 2
                    plotData(find(plotData > 0.0 )) = 0.0;
                end                       
                
                if autoScaleData
                    tmax = max(plotData);
                    tmin = min(plotData);
                    % set to largest pos/neg value if autoscaling
                    if tmin < 0 && abs(tmin) > tmax 
                        tmax = abs(tmin);
                    end
                else
                    tmax = g_scale_max;     % use current scale max...
                end
                g_scale_max = tmax;
                
                % get indices for above threshold data (pos and neg)
                threshold = overlay_threshold * g_scale_max;   % threshold in real units     
                plot_idx = find( abs(plotData) > threshold);
                           
                normData = plotData;
                
                % scale negative data from 0 to scaleCutoff_n
                idx = find(plotData < 0);
                if ~isempty(idx)
                    % normalize data 0 to +/- 1
                    normData(idx) = plotData(idx) ./ g_scale_max; 
                    % clip data to max range
                    tidx = find(normData < -1);
                    normData(tidx) = -1; 
                    
                    scaleRange = scaleCutoff_n;
                    % scale data to neg range and shift to zero
                    normData(idx) = normData(idx) * scaleRange + scaleCutoff_n; 
                end
                
                % scale positive data from scaleCutoff_p to 1.0
                idx = find(plotData >= 0);
                if ~isempty(idx)
                    % normalize data 0 to 1
                    normData(idx) = plotData(idx) ./ g_scale_max;                    
                    % clip data to max range
                    tidx = find(normData > 1);
                    normData(tidx) = 1;     
                    scaleRange = scaleCutoff_n;
                    % scale to pos range and shift to scaleCutoff_p
                    normData(idx) = normData(idx) * scaleRange + scaleCutoff_p;    
                end
                
                vertexColors(plot_idx) = normData(plot_idx);
                
                updateSliderText;

            end
            
            % prevent axes from auto resizing
            x_lim = xlim;
            y_lim = ylim;
            z_lim = zlim;
            
            hold on
            if ~isempty(fsl_vertices) 
                fprintf('plotting overlay mesh...\n');               
                set(ph2, 'Vertices', fsl_vertices,'Faces',fsl_faces);    
                set(ph2,'FaceAlpha',fsl_transparency, 'FaceColor',[223/255 206/255 166/255]);
            end
            
            % only need to change face list to select portion of mesh to display
           
            if hemisphere == 1
                f = faces(1:mesh.numLeftFaces,:);
            elseif hemisphere == 2
                f = faces(mesh.numLeftFaces+1:end,:);
            else
                f = faces;
            end           
            
            set(ph, 'Vertices',vertices,'Faces',f,'cdata',vertexColors);
    
            xlim(x_lim);
            ylim(y_lim);
            zlim(z_lim);
            
            hold off
       end
 
        % cursor routines
        
        function  gotoPeakCallback(~,~) 
            if ~isempty(selectedVertex)
                currentPeak = mesh.normalized_vertices(selectedVertex,1:3);
            else
                currentPeak = [0 0 0];
            end
            
            s1 = sprintf('%.2f', currentPeak(1));
            s2 = sprintf('%.2f', currentPeak(2));
            s3 = sprintf('%.2f', currentPeak(3));
            input = inputdlg({'X (mm)'; 'Y (mm)'; 'Z (mm)'},'Select MNI Voxel',[1 50; 1 50; 1 50], {s1; s2; s3} );         
            if isempty(input)
                return;
            end
            
            seedCoords =[ str2double(input{1}) str2double(input{2}) str2double(input{3}) ];
            
            distances = vecnorm(mesh.normalized_vertices' - repmat(seedCoords, mesh.numVertices,1)');

            [mindist, vertex] = min(distances);
    
            fprintf('Closest vertex = %g %g %g (vertex %d, distance = %g mm)\n', ...
                    mesh.normalized_vertices(vertex,1:3), vertex, mindist);                     
            setCursor(vertex);
            
        end
        
        function  findMaxCallback(~,~) 
            if isempty(overlay)
                return;
            end            
            [~, vertex] = max(overlay);   
            setCursor(vertex);
        end
    
        function  findMinCallback(~,~) 
            if isempty(overlay)
                return;
            end         
            [~, vertex] = min(overlay);   
            setCursor(vertex);     
        end  
  
        function  plotVSCallback(~,~) 
            if isempty(selectedVertex)
                return;
            end
            megCoord = mesh.meg_vertices(selectedVertex,1:3);           
            megNormal = mesh.normals(selectedVertex,1:3);
            
            s = sprintf('Plot virtual sensor at MEG coordinate %.2f %.2f %.2f (vertex %d)?\n', megCoord, selectedVertex);                     
            r = questdlg(s,'VS Plot','Yes','No','Yes');
            if strcmp(r,'No')
                return;
            end
            
            % load dataset
            dsName = uigetdir('*.ds','Select a dataset for virtual sensor calculation');
            if isequal(dsName,0)
                return;
            end      
            VS_DATA.dsList{1} = dsName;
            VS_DATA.covDsList{1} = dsName;
            VS_DATA.voxelList(1,1:3) = megCoord;
            VS_DATA.orientationList(1,1:3) = megNormal;
            VS_DATA.condLabel = 'none';
            
            if PLOT_WINDOW_OPEN
                r = questdlg('Add to existing plot?','Plot VS','Yes','No','Yes');
                if strcmp(r,'No')
                    bw_plot_dialog(VS_DATA, []);   
                else
                    g_peak.voxel = VS_DATA.voxelList(1,1:3);
                    g_peak.dsName = VS_DATA.dsList{1};                
                    g_peak.covDsName = VS_DATA.covDsList{1};               
                    g_peak.normal = megNormal;
                    feval(addPeakFunction)                
                end         
            else    
                bw_plot_dialog(VS_DATA, []);
            end  

        end    
    
    
    
        function  movieCallback(~,~) 
            if size(overlay_data,2) < 2
                return;
            end
            % cancel current movie if playing
            if movie_playing
                movie_playing = 0;
                set(MOVIE_BUTTON,'string','Play Movie');
                return;
            end
            playMovie;
            
        end      

        function playMovie 
            frame_count = 0;
            movie_playing = 1;
            set(MOVIE_BUTTON,'string','Stop Movie');
  
            if (cropMovie)
                % scale frame rect to movieRect in pixels
                w = [fh.Position(3) fh.Position(4) fh.Position(3) fh.Position(4)];          
                rect = cropRect .* w;  
            else
                rect = [0 0 fh.Position(3) fh.Position(4)]; % entire window
            end
            
            for j=1:size(overlay_data,2)              
                selectedOverlay = j;
                overlay = overlay_data(:,selectedOverlay);
                set(OVERLAY_LIST,'value',j);
                drawMesh;
                drawnow;
                M(j)=getframe(gcf, rect);
                frame_count = frame_count+1;
                if movie_playing == 0      % if cancelled
                    break;
                end               
            end   
            movie_playing = 0;
            set(MOVIE_BUTTON,'string','Play Movie');
 
            if save_movie && frame_count > 0                          
                [mname, path, filterIndex] = uiputfile( ...
                {'*.mp4','MPEG-4 Movie (*.mp4)'; ...
                '*.avi','AVI Movie (*.avi)'; ...
                '*.gif','Animated GIF (*.gif)'},...
                'Save as','untitled');
                if isequal(mname,0) || isequal(path,0)
                    return;
                end
                movie_name = fullfile(path, mname);
                if filterIndex < 3
                    if filterIndex == 1
                        vidObj = VideoWriter(movie_name, 'MPEG-4');
                    else
                        vidObj = VideoWriter(movie_name, 'Uncompressed AVI');
                    end 
                    input = inputdlg('Select Frame Rate','Frame rate (fps)',[1 35], {'30'});
                    if isempty(input)
                        return;
                    end
                        
                    vidObj.FrameRate = round(str2double(input{1}));
                    
                    open(vidObj);
                    for j = 1:frame_count
                       % Write each frame to the file.
                       writeVideo(vidObj,M(j).cdata);
                    end            
                    close(vidObj);
                else
                    for j=1:frame_count
                        [RGB, ~] = frame2im( M(1,j) );
                        [X_ind, map] = rgb2ind(RGB,256);              
                        if j==1
                            imwrite(X_ind, map, movie_name,'gif','LoopCount',65535,'DelayTime',0)
                        else
                            imwrite(X_ind, map, movie_name,'gif','WriteMode','append','DelayTime',0)
                        end
                    end                
                end      

            end        
        end
    
        function setCursor(vertex)
            
            peakCoords = vertices(vertex,1:3);            
            % place datatip at peak 
            ch = datacursormode(fh);
            ch.removeAllDataCursors;

            hTarget = handle(ph);
            hDatatip = ch.createDatatip(hTarget);           
            set(hDatatip,'position', peakCoords);               

            % problem - if peak not visible datatip will land in
            % wrong place and invoke callback. Solution, erase
            % dataTip if position changes (i.e., peak not visible)
            newpos = get(hDatatip,'position');
            dist = abs(sum(peakCoords - newpos));
            if dist > 1e-3
                ch.removeAllDataCursors;
            end
            selectedVertex = vertex;             
            updateCursorText;   

        end
    
        function [newText, position] = UpdateCursors(src,evt)
            position = get(evt,'Position');
            set(src,'MarkerSize',8)
            selectedVertex = find(position(1) == vertices(:,1) & position(2) == vertices(:,2)  & position(3) == vertices(:,3));
            newText = '';
            updateCursorText;
        end
    
        function  updateCursorText
            if isempty(selectedVertex)
                set(CURSOR_TEXT,'String','');
                return;
            end
            
            max_Talairach_SR = 4;   % search radius for talairach gray matter labels
         
            ras_point = mesh.mri_vertices(selectedVertex,1:3);
            mni_point = mesh.normalized_vertices(selectedVertex,1:3);
            meg_point = mesh.meg_vertices(selectedVertex,1:3);
            
            s = sprintf('Cursor: \n');
            s = sprintf('%sVertex: %d of %d\n', s,selectedVertex, size(vertices,1));
            s = sprintf('%sMEG (cm):  %.2f,   %.2f,   %.2f\n',s, meg_point);   
            s = sprintf('%sRAS (voxels):  %d,   %d,   %d\n',s, round(ras_point));
            s = sprintf('%sMNI (mm):  %d,   %d,   %d\n',s, round(mni_point));

            tal_point = round(mni2tal(mni_point));

            [~, ~, s3, ~, s5, ~] = dt_get_tal_label(tal_point, max_Talairach_SR);
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
            
            s = sprintf('%sTalairach (mm):  %d,   %d,   %d\n',s, tal_point);             
            s = sprintf('%sBA: %s\n',s, label);
                
            s = sprintf('%sCortical Thickness = %.2f mm\n',s, mesh.thickness(selectedVertex));
            
            if ~isempty(overlay)                  
                mag = overlay(selectedVertex);     
                s = sprintf('%sMagnitude = %.2f',s, mag);
            end
            
            set(CURSOR_TEXT,'String',s);
        
        end
    
        function  updateSliderText
            
            if isempty(overlay)
                set(AUTO_SCALE_CHECK,'visible','off');
                set(MAX_TEXT,'visible','off');              
                set(MIN_TEXT,'visible','off');
                set(ZERO_TEXT,'visible','off');
                set(THRESH_EDIT,'visible','off');
                set(THRESH_TEXT,'visible','off');
                set(MAX_EDIT,'visible','off');
                set(MAX_EDIT_TEXT,'visible','off');
                set(THRESH_SLIDER,'visible','off');                
                set(SLIDE_TEXT1,'visible','off');                
                set(SLIDE_TEXT2,'visible','off');                
                set(c_bar(1:end),'visible','off')            
                return;             
            end      
            
            set(AUTO_SCALE_CHECK,'visible','on');
            set(MAX_TEXT,'visible','on');              
            set(MIN_TEXT,'visible','on');
            set(ZERO_TEXT,'visible','on');
            set(THRESH_EDIT,'visible','on');            
            set(THRESH_TEXT,'visible','on');
            set(MAX_EDIT,'visible','on');
            set(MAX_EDIT_TEXT,'visible','on');
            set(THRESH_SLIDER,'visible','on');                
            set(SLIDE_TEXT1,'visible','on');                
            set(SLIDE_TEXT2,'visible','on');                
            set(c_bar(1:end),'visible','on')
            
            s = sprintf('%.2f',g_scale_max);
            set(MAX_TEXT,'string',s); 
            s = sprintf('%.2f', -g_scale_max);
            set(MIN_TEXT,'string',s);    
            s = sprintf('%.1f',overlay_threshold * 100);
            set(THRESH_EDIT,'string', s);     
            s = sprintf('%.2f',g_scale_max);
            set(MAX_EDIT,'string',s); 
           
        end
    
        % computes area using MEG vertices in cm!
        function [Nfaces, total_area] = computeROIArea(ROI_vertices)
               
            Nfaces = 0;
            total_area = 0.0;
            roi_faces = [];
            
            % get all faces that include at least one ROI_vertex
            
            [a, ~] = ismember(faces, ROI_vertices);
            [roi_faces, ~] = find(a);

            % ** to be compatible with region growing surface area
            % we want to include only faces inside the boundary
            % i.e., exclude any face if any of its vertices is not an ROI
            % vertex
            exclude = [];
            for i=1:length(roi_faces)
                idx = faces(roi_faces(i),1:3)';
                if any(~ismember(idx,ROI_vertices))
                    exclude(end+1) = i;
                end
            end
            roi_faces(exclude) = [];   
            
            roi_faces = unique(roi_faces,'rows');  

            Nfaces = size(roi_faces,1);
            total_area = 0.0;
                      
            for j=1:size(roi_faces,1)
                idx = faces(roi_faces(j),:);
                verts = mesh.meg_vertices(idx,:);
                v1 = verts(1,:);
                v2 = verts(2,:);
                v3 = verts(3,:);
                a = v1-v2;
                c = v1-v3;       
                area = norm(cross(a,c)) * 0.5;
                total_area = total_area + area;
            end      
        end
    
        function  updateROIText(roi)
    
            if isempty(roi)
                set(ROI_TEXT,'String','');
                return;
            end            
            s = sprintf('Selected ROI:\n');
            s = sprintf('%sCentroid : (%d %d %d)\n',s, round(roi.centroid));
            s = sprintf('%sVolume: %.2f cm%s\n',s, roi.volume,char(179));
            s = sprintf('%sCortical Area: %.2f cm%s\n',s, roi.area,char(178));
            s = sprintf('%sCortical Center: (%d %d %d)\n',s, round(roi.center));        
            set(ROI_TEXT,'String',s);
            
        end
   
   
end
