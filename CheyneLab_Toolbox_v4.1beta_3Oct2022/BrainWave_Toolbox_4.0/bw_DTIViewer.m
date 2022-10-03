%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_DTIViewer(dtiFile)
%
%   Module for viewing DTI files
%
%   written by Merron Woodbury, 2012 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_DTIViewer(dtiFile, overlayFile)

% global variables
global BW_PATH;

mmPerVoxel = 0;
File = [];
dti_nii = [];

% cross hairs
orange = [0.8,0.4,0.1];
sag_hor=[];
sag_ver=[];
cor_hor=[];
cor_ver=[];
axi_hor=[];
axi_ver=[];

% image views
sagaxis=[];
coraxis=[];
axiaxis=[];

% coordinates/dimensions of current data
max_dim=256;
oldcoords=[1 1 1];
slice1 = 1;
slice2 = 1;
slice3 = 1;
slice1_RAS = 1;
slice2_RAS = 1;
slice3_RAS = 1;
slice1_big_RAS = 1;
slice2_big_RAS = 1;
slice3_big_RAS = 1;
slice_dim = [max_dim/2-1  max_dim/2-1 max_dim/2-1];

img_display = zeros(max_dim,max_dim,max_dim);
image_size = size(img_display);

% overlay variables
dti_overlay = [];
img_display_top =  zeros(max_dim,max_dim,max_dim);
dti_overlay_RGB = false;
dti_overlay_lines = false;
dti_overlay_RGBlines = false;
modDTIImage = false;

% display variables
maxBrightness = 3.0;
contrast_value = 0.4*maxBrightness;

%adding nifti functions folder to path
template_path=strcat(BW_PATH,filesep,'template_MRI/');
if exist(template_path,'dir') ~= 7   % should not happen as folder is part of BW
    fprintf('error: template MRI folder is missing...\n');
else
    addpath(template_path);
end
dirpath=spm('dir');
addpath(genpath(dirpath));

% open dialog window
scrsz = get(0,'ScreenSize');
f=figure('Name', 'DTI Viewer', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
    'menubar','none','numbertitle','off', 'Color','white',...
    'WindowButtonUpFcn',@clickcursor);
if ispc
    movegui(f,'center');
end
subplot(2,2,1); imagesc(zeros(max_dim,max_dim)); axis off;
subplot(2,2,2); imagesc(zeros(max_dim,max_dim)); axis off;
subplot(2,2,3); imagesc(zeros(max_dim,max_dim)); axis off;

hmap = colormap(hot(128));
gmap = colormap(gray(128));
cmap = [gmap; hmap];

% menus
FILE_MENU=uimenu('Label','File');
OPEN_DTI = uimenu(FILE_MENU, 'label', 'Open DTI file...', 'callback', @open_DTI_Callback);
OPEN_DTI_OVERLAY = uimenu(FILE_MENU, 'label', 'Add DTI overlay...', 'enable', 'off', 'callback', @open_dtiOverlayCallback);
CLEAR_OVERLAY = uimenu(FILE_MENU,'label','Clear Overlays','enable','off','callback',@clear_overlayCallback);
CLOSE_WINDOW = uimenu(FILE_MENU,'label','Close','Callback',@my_closereq,'Accelerator','W','separator','on');

OVERLAY_MENU = uimenu('Label', 'Overlay');
DTI_OVERLAY_OPT = uimenu(OVERLAY_MENU, 'label', 'DTI Overlay Display Options.,,');
DTI_LINES = uimenu(DTI_OVERLAY_OPT, 'label', 'Lines', 'Checked', 'off', 'callback', @dti_display_linesCallback);
DTI_RGB = uimenu(DTI_OVERLAY_OPT, 'label', 'RGB', 'Checked', 'off', 'callback', @dti_display_RGBCallback);
DTI_LINESRGB = uimenu(DTI_OVERLAY_OPT, 'label', 'Lines (RGB)', 'Checked', 'off','callback', @dti_display_linesRGBCallback);

% file labels
WORKSPACE_TEXT_TITLE = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.15 0.957 0.8 0.03],'String','DTI File:','HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');
WORKSPACE_TEXT_TITLE2 = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.15 0.942 0.8 0.028],'String','Overlay File:','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','Red', 'enable','off');


% slice sliders (scaled to dimensions of currently loaded data)
SAGITTAL_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.64 0.51 0.2 0.02],'min',1,'max',(slice_dim(1)-1),...
    'Value',slice1, 'sliderStep', [1 1]/(slice_dim(1)-2),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@sagittal_slider_Callback);

uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.575 0.55 0.2 0.02],'String','A','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.7 0.55 0.2 0.02],'String','P','HorizontalAlignment','right',...6
    'BackgroundColor','White','ForegroundColor','red');

slice1_str = sprintf('Slice %d/%d', slice1_RAS, slice_dim(1)-1);
SLICE1_EDIT = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.68 0.55 0.2 0.02],'String', slice1_str,'HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');

sagittal_left=uicontrol('style','text','units','normalized','position',[0.59 0.48 0.04 0.05],...
    'string','Left','fontsize',10,'background','white');

sagittal_right=uicontrol('style','text','units','normalized','position',[0.85 0.48 0.04 0.05],...
    'string','Right','fontsize',10,'background','white');
    function sagittal_slider_Callback(src,evt)
        slice1 = round(get(src,'Value'));
        slice1_RAS = round(get(src,'Value'))-1;
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        oldcoords(1)= round(get(src,'Value'));
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
    end


CORONAL_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.19 0.51 0.2 0.02],'min',1,'max',(slice_dim(2)-1),...
    'Value',slice2, 'sliderStep', [1 1]/(slice_dim(2)-2),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@coronal_slider_Callback);

uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.135 0.55 0.2 0.02],'String','L','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.26 0.55 0.2 0.02],'String','R','HorizontalAlignment','right',...
    'BackgroundColor','White','ForegroundColor','red');

slice2_str = sprintf('Slice %d/%d', slice2_RAS, slice_dim(2)-1);
SLICE2_EDIT = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.24 0.55 0.2 0.02],'String', slice2_str,'HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');

coronal_left=uicontrol('style','text','units','normalized','position',[0.105 0.48 0.08 0.05],...
    'string','Anterior','fontsize',10,'background','white');

coronal_right=uicontrol('style','text','units','normalized','position',[0.4 0.48 0.08 0.05],...
    'string','Posterior','fontsize',10,'background','white');


    function coronal_slider_Callback(src,evt)
        slice2 = round(get(src,'Value'));
        slice2_RAS = slice_dim(2)-round(get(src,'Value'));
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        oldcoords(2)= round(get(src,'Value'));
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));

    end

AXIS_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.19 0.04 0.2 0.02],'min',1,'max',(slice_dim(3)-1),...
    'Value',slice3, 'sliderStep', [1 1]/(slice_dim(3)-2),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@axis_slider_Callback);

uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.135 0.08 0.2 0.02],'String','L','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.26 0.08 0.2 0.02],'String','R','HorizontalAlignment','right',...
    'BackgroundColor','White','ForegroundColor','red');

slice3_str = sprintf('Slice %d/%d', slice3_RAS, slice_dim(3)-1);
SLICE3_EDIT = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
        [0.24 0.08 0.2 0.02],'String', slice3_str,'HorizontalAlignment','left',...
        'BackgroundColor','White', 'enable','off');

axis_left=uicontrol('style','text','units','normalized','position',[0.105 0.04 0.08 0.02],...
    'string','Superior','fontsize',10,'background','white');

axis_right=uicontrol('style','text','units','normalized','position',[0.39 0.04 0.08 0.02],...
    'string','Inferior','fontsize',10,'background','white');


    function axis_slider_Callback(src,evt)
        slice3 = round(get(src,'Value'));
        slice3_RAS = slice_dim(3)-round(get(src,'Value'));
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT, 'String', sliceStr3);
        oldcoords(3)= round(get(src,'Value'));
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));       
    end

% contrast slider
CONTRAST_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.05 0.11 0.06 0.34],'min',0.0,'max',maxBrightness,...
    'Value',contrast_value, 'sliderStep', [0.03 0.03],'BackGroundColor',[0.9 0.9 0.9],'callback',@contrast_slider_Callback);

uicontrol('style','text','units','normalized','position',[0.05 0.42 0.03 0.02],...
    'string','Max','fontsize',10,'FontWeight','normal','background','white', 'horizontalalignment','left');

uicontrol('style','text','units','normalized','position',[0.05 0.11 0.03 0.02],...
    'string','Min','fontsize',10,'FontWeight','normal','background','white','horizontalalignment','left');

uicontrol('style','text','units','normalized','position',[0.05 0.09 0.1 0.02],...
    'string','Brightness','fontsize',10,'FontWeight','normal','background','white','horizontalalignment','left');

    function contrast_slider_Callback(src, evt)
        contrast_value = get(src,'Value');
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
    end

set(DTI_OVERLAY_OPT, 'enable', 'off');

%% ================================== File Menu Callbacks ================================== %%

    function open_DTI_Callback(src, evt)

        [fileName, filePath, filterIndex] = uigetfile('*.nii','NIfTI file(*.nii)',...
            'Select a NIfTI DTI file');
        
        if isequal(fileName,0) || isequal(filePath,0)
            return;
        end
                
        File = fullfile(filePath, fileName);

        dti_overlay = [];
        
        openDTI(File);
        
        if ~isempty(dti_nii)
         
            set(OVERLAY_MENU,'enable','on');
            set(OPEN_DTI_OVERLAY, 'enable', 'on');
            set(CLEAR_OVERLAY, 'enable', 'off');
            
        end
    end

    % I/O to open a preprocessed DTI nifti file (e.g. dti_FA.nii)
    function openDTI(file) 
        
        [filePath,filename,EXT] = fileparts(file);
       
        dti_nii = load_nii(file);
        fprintf('Reading DTI file %s, Voxel dimensions: %g %g %g\n',...
            file, dti_nii.hdr.dime.pixdim(2), dti_nii.hdr.dime.pixdim(3), dti_nii.hdr.dime.pixdim(4));
        
        % pad image with black wherever dimensions differ
        if ((dti_nii.hdr.dime.dim(2) ~= dti_nii.hdr.dime.dim(3)) || (dti_nii.hdr.dime.dim(2) ~= dti_nii.hdr.dime.dim(4)) || dti_nii.hdr.dime.dim(3) ~= dti_nii.hdr.dime.dim(4))
            dti_nii.img = resizeImg(dti_nii.img);
            dti_nii.hdr.dime.dim(2) = size(dti_nii.img, 1);
            dti_nii.hdr.dime.dim(3) = size(dti_nii.img, 2);
            dti_nii.hdr.dime.dim(4) = size(dti_nii.img, 3);
        end
        
        max_dim = max(dti_nii.hdr.dime.dim(2), max(dti_nii.hdr.dime.dim(3), dti_nii.hdr.dime.dim(4)));    
        mmPerVoxel = dti_nii.hdr.dime.pixdim(2);
        img1 = dti_nii.img;        
        img_RAS=img1;
        
        % flip z direction RAS -> RAI
        img2 = flipdim(img_RAS,3);
        
        % flip y direction RAI -> RPI
        img = flipdim(img2,2);
        
        if(dti_nii.hdr.dime.datatype==2)
            img_display=uint8(img);
        else
            maxVal = max(max(max(img)));
            maxVal = double(maxVal);
            scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
            img_display = scaleTo8bit* img; 
            img_display = uint8(img_display);
        end
        
        slice1 = round(dti_nii.hdr.dime.dim(2)/2);
        slice2 = round(dti_nii.hdr.dime.dim(3)/2);
        slice3 = round(dti_nii.hdr.dime.dim(4)/2);
        slice1_RAS = slice1 - 1;
        slice2_RAS = slice2 - 1;
        slice3_RAS = slice3 - 1;
        oldcoords=[slice1 slice2 slice3];
        slice_dim = [dti_nii.hdr.dime.dim(2) dti_nii.hdr.dime.dim(3) dti_nii.hdr.dime.dim(4)];
        
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        
        clickcursor;
        
        % update file label
        tstr=sprintf('DTI File: %s', file);
        set(WORKSPACE_TEXT_TITLE,'string', tstr, 'enable','on','units','normalized','fontname','lucinda');
        
        % update slice slider information (scale to current data dimensions)
        set(SLICE1_EDIT, 'visible', 'on');
        set(SLICE2_EDIT, 'visible', 'on');
        set(SLICE3_EDIT, 'visible', 'on');
    
        slice3_str = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT, 'String', slice3_str);
        slice1_str = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT, 'String', slice1_str);
        slice2_str = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT, 'String', slice2_str);
        
        set(AXIS_SLIDER, 'max', slice_dim(3));
        set(CORONAL_SLIDER, 'max', slice_dim(2));
        set(SAGITTAL_SLIDER, 'max', slice_dim(1));
        
        set(AXIS_SLIDER, 'value', slice3_RAS);
        set(CORONAL_SLIDER, 'value', slice2_RAS);
        set(SAGITTAL_SLIDER, 'value', slice1_RAS);
    end

    % pad image with uneven dimensions
    function new_img = resizeImg(old_img)
        vox_x = size(old_img,1);
        vox_y = size(old_img,2);
        vox_z = size(old_img,3);

        maxDim = max(vox_x, max(vox_y, vox_z));

        fprintf('padding image data (%d x %d x %d) to %g x %g x %g\n', vox_x, vox_y, vox_z, maxDim, maxDim, maxDim);
        new_img = zeros(maxDim,maxDim,maxDim);
        for k=1:vox_z
            for j=1:vox_y
                for i=1:vox_x
                    new_img(i+round((maxDim-vox_x)/2),j+round((maxDim-vox_y)/2),round(k+(maxDim-vox_z)/2)) = old_img(i,j,k);
                end
            end
        end
        
        
    end
  
    function open_dtiOverlayCallback(src, evt)
        
        [overlayName, overlayPath, overlayIndex] = uigetfile(...
                {'*.nii','DTI Vector file (*.nii)'},...            
                'Select DTI Vector file');
        
        if isequal(overlayName, 0) 
            return; 
        end
     
        overlayFile = fullfile(overlayPath, overlayName);

        loadDTIOverlay(overlayFile)
        
    end

    % I/O to open a preprocessed DTI nifti file (e.g. dti_V1.nii)
    function loadDTIOverlay(file)
        
        nii = load_nii(file);

        if size(nii.img, 4) == 3
            dti_overlay.x = nii;
            dti_overlay.x.img = nii.img(:, :, :, 1);
            dti_overlay.y = nii;
            dti_overlay.y.img = nii.img(:, :, :, 2);
            dti_overlay.z = nii;
            dti_overlay.z.img = nii.img(:, :, :, 3);
        else
            fprintf('overlay image is not 3-vector (%d)\n', size(nii.img, 4));
            return;
        end
        
        fprintf('Reading DTI Overlay file %s, Voxel dimensions: %g %g %g\n',...
            file, nii.hdr.dime.pixdim(2), nii.hdr.dime.pixdim(3), nii.hdr.dime.pixdim(4));
        
        % resize if necessary (pad to largest of dimensions)
        if (dti_overlay.x.hdr.dime.dim(2) < max_dim || dti_overlay.x.hdr.dime.dim(3) < max_dim || dti_overlay.x.hdr.dime.dim(4) < max_dim)
            dti_overlay.x.img = resizeImg(dti_overlay.x.img);
            dti_overlay.x.hdr.dime.dim(2) = size(dti_overlay.x.img, 1);
            dti_overlay.x.hdr.dime.dim(3) = size(dti_overlay.x.img, 2);
            dti_overlay.x.hdr.dime.dim(4) = size(dti_overlay.x.img, 3);
        end
        if (dti_overlay.y.hdr.dime.dim(2) < max_dim|| dti_overlay.y.hdr.dime.dim(3) < max_dim || dti_overlay.y.hdr.dime.dim(4) < max_dim)
            dti_overlay.y.img = resizeImg(dti_overlay.y.img);
            dti_overlay.y.hdr.dime.dim(2) = size(dti_overlay.y.img, 1);
            dti_overlay.y.hdr.dime.dim(3) = size(dti_overlay.y.img, 2);
            dti_overlay.y.hdr.dime.dim(4) = size(dti_overlay.y.img, 3);
        end
        if (dti_overlay.z.hdr.dime.dim(2) < max_dim || dti_overlay.z.hdr.dime.dim(3) < max_dim || dti_overlay.z.hdr.dime.dim(4) < max_dim)
            dti_overlay.z.img = resizeImg(dti_overlay.z.img);
            dti_overlay.z.hdr.dime.dim(2) = size(dti_overlay.z.img, 1);
            dti_overlay.z.hdr.dime.dim(3) = size(dti_overlay.z.img, 2);
            dti_overlay.z.hdr.dime.dim(4) = size(dti_overlay.z.img, 3);
        end
        
        % ONLY VIEW x DIMENSION of vector as default--- CHANGE ?
        img_RAS=dti_overlay.x.img;
        
        % flip z direction RAS -> RAI
        img2 = flipdim(img_RAS,3);
        
        % flip y direction RAI -> RPI
        img = flipdim(img2,2);
        
        if(dti_overlay.x.hdr.dime.datatype==2)
            img_display_top=uint8(img);
        else
            maxVal = max(max(max(img)));
            maxVal = double(maxVal);
            scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
            img_display_top = scaleTo8bit* img; 
            img_display_top = uint8(img_display_top);
        end

        % change oldcoords to be middle of image
        slice1 = round(dti_overlay.x.hdr.dime.dim(2)/2);
        slice2 = round(dti_overlay.x.hdr.dime.dim(3)/2);
        slice3 = round(dti_overlay.x.hdr.dime.dim(4)/2);
        slice1_RAS = slice1 - 1;
        slice2_RAS = slice_dim(2) - slice2;
        slice3_RAS = slice_dim(3) - slice3;
        oldcoords=[slice1 slice2 slice3];
        
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        
        clickcursor;
        
        tstr=sprintf('DTI Overlay File: %s',file);
        set(WORKSPACE_TEXT_TITLE2, 'string', tstr, 'enable','on','units','normalized','fontname','lucinda');
        set(CLEAR_OVERLAY,'enable','on');
        set(DTI_OVERLAY_OPT, 'enable', 'on');
    end

    function clear_overlayCallback(src, evt)
        dti_overlay = [];
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
    
        tstr=sprintf('DTI Overlay File: ');
        set(WORKSPACE_TEXT_TITLE2,'string', tstr, 'enable','on','units','normalized','fontname','lucinda');
        
        set(CLEAR_OVERLAY,'enable','off');
        set(OPEN_DTI_OVERLAY, 'enable', 'on');
        set(DTI_OVERLAY_OPT, 'enable', 'off');
    end

    function my_closereq(src,evt)
        delete(gcf);
    end

%% ================================== Overlay Display Functions ================================== %%

    function dti_display_linesCallback(src,evt)
        
        if (isempty(dti_overlay))
            return;
        end
        if strcmp(DTI_LINES.Checked, 'on')
            set(DTI_LINES, 'Checked', 'off');
            dti_overlay_lines = false;
            sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
            cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
            axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
            return;
        end
        set(DTI_LINES, 'Checked', 'on');
        set(DTI_LINESRGB, 'Checked', 'off');
        set(DTI_RGB, 'Checked', 'off');
        
        dti_overlay_lines = true;
        dti_overlay_RGB = false;
        dti_overlay_RGBlines = false;
        
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        
        fprintf('Displaying DTI overlay in lines (one per voxel)\n');
        
    end

    function dti_display_RGBCallback(src,evt)
        
        if strcmp(DTI_RGB.Checked, 'on')
            set(DTI_RGB, 'Checked', 'off');
            dti_overlay_RGB = false;
            sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
            cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
            axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
            return;
        end
        
        % determine whether to modulate transparency of overlay based on
        % underlying image
        answer = modulationOption();
        if ~isempty(answer) && answer == 1
            modDTIImage = true;
            fprintf('Modulating RGB overlay by underlying image\n');
        elseif ~isempty(answer) && answer == 0
            modDTIImage = false;
        end
        
        set(DTI_RGB, 'Checked', 'on');
        set(DTI_LINESRGB, 'Checked', 'off'); 
        set(DTI_LINES, 'Checked', 'off');
        
        dti_overlay_RGB = true;
        dti_overlay_lines = false;
        dti_overlay_RGBlines =  false;
        
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        
    end

     % Offer option to modulate RGB by underlying DTI file (dialog)
    function answer = modulationOption()
        
        scrsz=get(0,'ScreenSize');
        f3=figure('Name', 'Modulation Option', 'Position', [(scrsz(3)-500)/2 (scrsz(4)-500)/2 500 200],...
            'menubar','none','numbertitle','off','Color','white');
        
        text = uicontrol('style','text','units','normalized','position',[0.25 0.6 0.5 0.3],...
            'string','Modulate DTI overlay by underlying image?','fontsize',15,'background','white');

        YES_BUTTON = uicontrol('Units','Normalized','Position',[0.10 0.2 0.3 0.25],'String','YES',...
            'FontSize',12,'ForegroundColor','black', 'BackgroundColor', 'white', 'Callback',@yes_callback);

        function yes_callback(src, evt) 
            answer = 1;
            uiresume(gcf);
        end
        
        NO_BUTTON = uicontrol('Units','Normalized','Position',[0.60 0.2 0.3 0.25],'String','NO',...
            'FontSize',12,'ForegroundColor',...
            'black','Callback',@no_callback);
        
         function no_callback(src, evt) 
             answer = 0;
             uiresume(gcf);
         end
         
         uiwait(gcf);
         close(f3);
    end

    function dti_display_linesRGBCallback(src,evt)
        
        if strcmp(DTI_LINESRGB.Checked, 'on')
            set(DTI_LINESRGB, 'Checked', 'off');
            %dti_overlay_RGB = false;
            sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
            cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
            axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
            return;
        end
        set(DTI_LINESRGB, 'Checked', 'on');
        set(DTI_RGB, 'Checked', 'off');
        set(DTI_LINES, 'Checked', 'off');
        dti_overlay_RGB = false;
        dti_overlay_lines = false;
        dti_overlay_RGBlines = true;
        
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        
    end

%% ================================== Image Display Functions ================================== %%

    function clickcursor(src,evt)
        persistent chk
        if isempty(chk)
            chk = 1;
            pause(0.3); %Add a delay to distinguish single click from a double click
            if chk == 1
                posit = round(get(gca,'currentpoint'));
                if posit(1,2) <= image_size(1) && posit(1,1) <= image_size(1) && posit(1,2) >= 0 && posit(1,1) >=0
                    switch gca
                        case sagaxis
                            oldcoords=[oldcoords(1),posit(1,1),posit(1,2)];
                        case coraxis
                            oldcoords=[posit(1,1),oldcoords(2),posit(1,2)];
                        case axiaxis
                            oldcoords=[posit(1,1),posit(1,2),oldcoords(3)];
                        otherwise
                            %nothing
                    end
                     
                    
                    slice1=oldcoords(1);
                    slice1_RAS=oldcoords(1)-1;
                    sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
                    set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
                    set(SAGITTAL_SLIDER,'Value', oldcoords(1));
                    slice2=oldcoords(2);
                    slice2_RAS=slice_dim(2)-oldcoords(2);
                    sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
                    set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
                    set(CORONAL_SLIDER,'Value', oldcoords(2));
                    slice3=oldcoords(3);
                    slice3_RAS=slice_dim(3)-oldcoords(3);
                    sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
                    set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
                    set(AXIS_SLIDER,'Value', oldcoords(3));

                    sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
                    cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
                    axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
                    
                end
                chk = [];
            end
           
        else
            chk = [];
             posit = round(get(gca,'currentpoint'));
             if posit(1,2) <= image_size(1) && posit(1,1) <= image_size(1) && posit(1,2) >= 0 && posit(1,1) >=0
                 switch gca
                     case sagaxis                         
                         sagaxis_big_view; 
                         
                     case coraxis
                         coraxis_big_view;
                         
                     case axiaxis
                         axiaxis_big_view;
                         
                    otherwise
                        %nothing
                 end
            end
        end
    end

    function sag_view(s,c,a)
        sagaxis=subplot(2,2,2);

        mdata = rot90(fliplr(squeeze(img_display(s,:,:))));      
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127; 
        
        imagesc(mdata,[0 127]);
        colormap(gmap);
        
        if ~isempty(dti_overlay)
            
            if (dti_overlay_RGB == true )
                
                hold on;
                
                % calculate vector colors (for each voxel)
                dti_colour_top = zeros(slice_dim(2), slice_dim(3), 3);
                for z_vox=1:slice_dim(3)
                    for y_vox=1:slice_dim(2)
                        
                          dti_colour_top(y_vox, z_vox, 1) = uint8(abs(dti_overlay.x.img(s, y_vox, z_vox))*255);
                          dti_colour_top(y_vox, z_vox, 2) = uint8(abs(dti_overlay.y.img(s, y_vox, z_vox))*255);
                          dti_colour_top(y_vox, z_vox, 3) = uint8(abs(dti_overlay.z.img(s, y_vox, z_vox))*255);
                        
                    end
                end
                
                % flip z direction RAS -> RAI
                img2 = flipdim(dti_colour_top,2);
                
                % flip y direction RAI -> RPI
                dti_colour_top = flipdim(img2,1);

                if(dti_overlay.x.hdr.dime.datatype==2)
                    dti_colour_top=uint8(dti_colour_top);
                else
                    maxVal = max(max(max(dti_colour_top)));
                    maxVal = double(maxVal);
                    scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                    dti_colour_top = scaleTo8bit*dti_colour_top; 
                    dti_colour_top = uint8(dti_colour_top);
                end
                
                % display vector colors
                o_data = rot90(fliplr(squeeze(dti_colour_top(:,:,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data);
                
                % if chose to modulate based on base image, alter
                % transparency according to underlying image (mdata)
                if modDTIImage
                    set(im, 'AlphaData', mdata);
                end
                
                hold off;
                
            elseif (dti_overlay_lines == true)
                
                % each voxel has 100x100 pixels (allow plotting of one line
                % per voxel)
                F = griddedInterpolant(double(mdata));
                [sx, sy, sz] = size(mdata);
                xq = (0:1/100:sx)';
                yq = (0:1/100:sy)';
                vq = uint8(F({xq,yq}));
                fprintf('resized image from %d x %d to %g x %g\n', size(mdata,1), size(mdata,2), size(vq,1), size(vq,2));
                mdata = vq;
                image_size = size(mdata);
                
                imagesc(mdata,[0 127]);
                colormap(gmap);
                
                hold on;

                % calculate and plot a line for each voxel
                for z_vox=0:slice_dim(3)-1
                    for y_vox=0:slice_dim(2)-1

                        % scale vectors to half of voxel display size
                        yVec = dti_overlay.y.img(s, y_vox+1, z_vox+1)*50;
                        zVec = dti_overlay.z.img(s, y_vox+1, z_vox+1)*50;

                        if (yVec ~= 0 || zVec ~= 0)
                            
                            % flip z and y dimensions
                            y_vox_new = slice_dim(2) - y_vox;
                            z_vox_new = slice_dim(3) - z_vox;
                            coords = [y_vox_new z_vox_new];
                            coords = coords*100+50;
                            
                            % line has slope determined by vectors and runs
                            % through middle of voxel's pixel space
                            y_pos1 = coords(1) - yVec;
                            y_pos2 = coords(1) + yVec;
                            z_pos1 = coords(2) - zVec;
                            z_pos2 = coords(2) + zVec;
                            
                            line([y_pos1, y_pos2], [z_pos1, z_pos2], 'color', 'y');
                        end

                    end
                end

                fprintf('Drew lines\n');
                hold off;
            else
                hold on;
                
                o_data = rot90(fliplr(squeeze(img_display_top(s,:,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data,[0 127]);
                
                % allow base image to show through wherever overlay is
                % black
                mask = o_data > 0;
                set(im, 'AlphaData', mask);
                
                hold off;
            end
            
        end
        
        axis off;
        sag_hor=line(1:size(mdata,1),a*(ones(size(mdata,1))),'color',orange);
        sag_ver=line(c*(ones(size(mdata,2))),1:size(mdata,2),'color',orange);

    end

    function cor_view(s,c,a)
        
        coraxis=subplot(2,2,1);
        
        mdata = rot90(fliplr(squeeze(img_display(:,c,:))));      
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;  
        
        imagesc(mdata,[0 127]);
        colormap(gmap);
        
        if ~isempty(dti_overlay)
            
            if (dti_overlay_RGB == true )
                hold on;
                
                % calculate vector colors (for each voxel)
                dti_colour_top = zeros(slice_dim(1), slice_dim(3), 3);
                for z_vox=1:slice_dim(3)
                    for x_vox=1:slice_dim(1)

                          dti_colour_top(x_vox, z_vox, 1) = uint8(abs(dti_overlay.x.img(x_vox, c, z_vox))*255);
                          dti_colour_top(x_vox, z_vox, 2) = uint8(abs(dti_overlay.y.img(x_vox, c, z_vox))*255);
                          dti_colour_top(x_vox, z_vox, 3) = uint8(abs(dti_overlay.z.img(x_vox, c, z_vox))*255);
                    end
                end
                
                % flip z direction RAS -> RAI 
                dti_colour_top = flipdim(dti_colour_top,2);

                if(dti_overlay.x.hdr.dime.datatype==2)
                    dti_colour_top=uint8(dti_colour_top);
                else
                    maxVal = max(max(max(dti_colour_top)));
                    maxVal = double(maxVal);
                    scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                    dti_colour_top = scaleTo8bit*dti_colour_top; 
                    dti_colour_top = uint8(dti_colour_top);
                end
                
                %display vector colors
                o_data = rot90(fliplr(squeeze(dti_colour_top(:,:,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data);
                
                if modDTIImage
                    set(im, 'AlphaData', mdata);
                end
                
                hold off;
                
            elseif (dti_overlay_lines == true)
                
                % each voxel has 100x100 pixels
                F = griddedInterpolant(double(mdata));
                [sx, sy, sz] = size(mdata);
                xq = (0:1/100:sx)';
                yq = (0:1/100:sy)';
                vq = uint8(F({xq,yq}));
                fprintf('resized image from %d x %d to %g x %g\n', size(mdata,1), size(mdata,2), size(vq,1), size(vq,2));
                mdata = vq;
                image_size = size(mdata);
                
                imagesc(mdata,[0 127]);
                colormap(gmap);
                
                hold on;

                % calculate line for each voxel
                for z_vox=0:slice_dim(3)-1
                    for x_vox=0:slice_dim(1)-1

                        % scale vectors to 1/2 voxel display area (100x100
                        % pixels)
                        zVec = dti_overlay.z.img(x_vox+1, c, z_vox+1)*50;
                        xVec = dti_overlay.x.img(x_vox+1, c, z_vox+1)*50;

                        if (zVec ~= 0 || xVec ~= 0)
                            
                            % flip z dimension
                            z_vox_new = slice_dim(2) - z_vox;
                            coords = [x_vox z_vox_new];
                            coords = coords*100+50;
                            
                            % line has slope according to vectors and runs
                            % through middle of voxel space
                            x_pos1 = coords(1) - xVec;
                            x_pos2 = coords(1) + xVec;
                            z_pos1 = coords(2) - zVec;
                            z_pos2 = coords(2) + zVec;
                            
                            line([x_pos1, x_pos2], [z_pos1, z_pos2], 'color', 'y');
                        end

                    end
                end

                fprintf('Drew lines\n');
                hold off;
            else
            
                hold on;
                o_data = rot90(fliplr(squeeze(img_display_top(:,c,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data,[0 127]);
                
                % allow underlying image to show wherever overlay is black
                mask = o_data > 0;
                set(im, 'AlphaData', mask);
                
                hold off;
            end
            
        end
        
        axis off;
        cor_hor=line(1:size(mdata,1),a*(ones(size(mdata,1))),'color',orange);
        cor_ver=line(s*(ones(size(mdata,2))),1:size(mdata,2),'color',orange);

    end

    function axi_view(s,c,a)
        axiaxis=subplot(2,2,3);

        mdata = rot90(fliplr(squeeze(img_display(:,:,a))));      
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;

        imagesc(mdata,[0 127]);
        colormap(gmap);
        
        if ~isempty(dti_overlay)

            if (dti_overlay_RGB == true)
                hold on;
                
                % calculate vector colors (for each voxel)
                dti_colour_top = zeros(slice_dim(1), slice_dim(2), 3);
                for y_vox=1:slice_dim(2)
                    for x_vox=1:slice_dim(1)

                          dti_colour_top(x_vox, y_vox, 1) = uint8(abs(dti_overlay.x.img(x_vox, y_vox, a))*255);
                          dti_colour_top(x_vox, y_vox, 2) = uint8(abs(dti_overlay.y.img(x_vox, y_vox, a))*255);
                          dti_colour_top(x_vox, y_vox, 3) = uint8(abs(dti_overlay.z.img(x_vox, y_vox, a))*255);
                    end
                end

                % flip y direction RAS -> RPS
                img = flipdim(dti_colour_top,2);

                if(dti_overlay.x.hdr.dime.datatype==2)
                    dti_colour_top=uint8(img);
                else
                    maxVal = max(max(max(img)));
                    maxVal = double(maxVal);
                    scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                    img_scaled = scaleTo8bit*img; 
                    dti_colour_top = uint8(img_scaled);
                end
                
                % display vector colors
                o_data = rot90(fliplr(squeeze(dti_colour_top(:,:,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data);
                
                if modDTIImage
                    set(im, 'AlphaData', mdata);
                end
                
                hold off;
                
            elseif (dti_overlay_lines == true)
                
                % each voxel has 100x100 pixels
                F = griddedInterpolant(double(mdata));
                [sx, sy, sz] = size(mdata);
                xq = (0:1/100:sx)';
                yq = (0:1/100:sy)';
                vq = uint8(F({xq,yq}));
                fprintf('resized image from %d x %d to %g x %g\n', size(mdata,1), size(mdata,1), size(vq,1), size(vq,2));
                mdata = vq;
                image_size = size(mdata);
                
                imagesc(mdata,[0 127]);
                colormap(gmap);
                
                hold on;

                % calculate line for each voxel
                for y_vox=0:slice_dim(2)-1
                    for x_vox=0:slice_dim(1)-1

                        % scale vectors to 1/2 voxel space
                        yVec = dti_overlay.y.img(x_vox+1, y_vox+1, a)*50;
                        xVec = dti_overlay.x.img(x_vox+1, y_vox+1, a)*50;

                        if (yVec ~= 0 || xVec ~= 0)
                            
                            % flip y dimension
                            y_vox_new = slice_dim(2) - y_vox;
                            coords = [x_vox y_vox_new];
                            coords = coords*100+50;
                            
                            % line has slope according to vectors and runs
                            % through middle of voxel space
                            x_pos1 = coords(1) - xVec;
                            x_pos2 = coords(1) + xVec;
                            y_pos1 = coords(2) - yVec;
                            y_pos2 = coords(2) + yVec;
                            
                            line([x_pos1, x_pos2], [y_pos1, y_pos2], 'color', 'y');
                        end

                    end
                end

                fprintf('Drew lines\n');
                hold off;
            else
                hold on;
                o_data = rot90(fliplr(squeeze(img_display_top(:,:,a))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data,[0 127]);
                
                % allow underlying image to show through where overlay is
                % black
                mask = o_data > 0;
                set(im, 'AlphaData', mask);
                hold off;
            end
            
        end
        
        axis off;
        axi_hor=line(1:size(mdata,1),c*(ones(size(mdata,1))),'color',orange);
        axi_ver=line(s*(ones(size(mdata,2))),1:size(mdata,2),'color',orange);

    end

    % big view windows
    function sagaxis_big_view
        oldcoords_big = oldcoords;
        slice1_big_RAS = oldcoords_big(1)-1;
        scrsz = get(0,'ScreenSize');
        f_big=figure('Name', 'DTI Viewer Sagittal', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@clickcursor_big);
        sag_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        SAGITTAL_SLIDER_BIG = uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(1)-1,...
            'Value',slice1, 'sliderStep', [1 1]/(slice_dim(1)-2),'BackGroundColor',[0.9 0.9 0.9],'callback',@sagittal_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.4 0.08 0.05 0.02],'String','Left','HorizontalAlignment','left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.05 0.02],'String','Right','HorizontalAlignment','right',...
            'BackgroundColor','White','ForegroundColor','red');
        SLICE1_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String','Slice: 127/255','HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');
        sliceStr1 = sprintf('Slice: %d/%d', slice1_big_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT_BIG,'String',sliceStr1, 'enable','on');
        function sagittal_slider_big_Callback(src,evt)
            slice1_big = round(get(src,'Value'));
            slice1_big_RAS = round(get(src,'Value'))-1;
            sliceStr1 = sprintf('Slice: %d/%d', slice1_big_RAS, slice_dim(1)-1);
            set(SLICE1_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(1)= round(get(src,'Value'));
            sag_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.15 0.03 0.25 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.2 0.03 0.25 0.02],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1)-1;
        cor_RAS = slice_dim(2)-oldcoords_big(2);
        axi_RAS = slice_dim(3)-oldcoords_big(3);

        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
        function clickcursor_big(src,evt)
            posit = round(get(gca,'currentpoint'));
            if posit(1,2) <= size(img_display,1) && posit(1,1) <= size(img_display,1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[oldcoords_big(1),posit(1,1),posit(1,2)];
                sag_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
                sag_RAS = oldcoords_big(1)-1;
                cor_RAS = slice_dim(2)-oldcoords_big(2);
                axi_RAS = slice_dim(3)-oldcoords_big(3);
               
            end
        end
    end
    
    function coraxis_big_view
        oldcoords_big = oldcoords;
        slice2_big_RAS = slice_dim(2)-oldcoords_big(2);
        scrsz = get(0,'ScreenSize');
        f_big=figure('Name', 'DTI Viewer Coronal', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@clickcursor_big);
        cor_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        CORONAL_SLIDER_BIG = uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(2)-1,...
            'Value',slice3, 'sliderStep', [1 1]/(slice_dim(2)-2),'BackGroundColor',[0.9 0.9 0.9],'callback',@coronal_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.38 0.08 0.06 0.02],'String','Anterior','HorizontalAlignment','Left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.08 0.02],'String','Posterior','HorizontalAlignment','Right',...
            'BackgroundColor','White','ForegroundColor','red');
        sliceStr1 = sprintf('Slice: %d/%d', slice2_big_RAS, slice_dim(2)-1);
        SLICE2_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');
        
        set(SLICE2_EDIT_BIG,'String',sliceStr1, 'enable','on');
        function coronal_slider_big_Callback(src,evt)
            slice2_big = round(get(src,'Value'));
            slice2_big_RAS = slice_dim(2)-round(get(src,'Value'));
            sliceStr1 = sprintf('Slice: %d/%d', slice2_big_RAS, slice_dim(2)-1);
            set(SLICE2_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(2)= round(get(src,'Value'));
            cor_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.15 0.03 0.25 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.2 0.03 0.24 0.02],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1)-1;
        cor_RAS = slice_dim(2)-oldcoords_big(2);
        axi_RAS = slice_dim(3)-oldcoords_big(3);

        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
        function clickcursor_big(src,evt)
            posit = round(get(gca,'currentpoint'));
            if posit(1,2) <= size(img_display,1) && posit(1,1) <= size(img_display,1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[posit(1,1),oldcoords_big(2), posit(1,2)];
                cor_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
                sag_RAS = oldcoords_big(1)-1;
                cor_RAS = slice_dim(2)-oldcoords_big(2);
                axi_RAS = slice_dim(3)-oldcoords_big(3);
            end
        end
    end

    function axiaxis_big_view
        oldcoords_big = oldcoords;
        slice3_big_RAS = slice_dim(3)-oldcoords_big(3);
        scrsz = get(0,'ScreenSize');
        f_big=figure('Name', 'DTI Viewer Axial', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@clickcursor_big);
        axi_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        AXI_SLIDER_BIG = uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(3)-1,...
            'Value',slice3, 'sliderStep', [1 1]/(slice_dim(3)-2),'BackGroundColor',[0.9 0.9 0.9],'callback',@axial_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.38 0.08 0.06 0.02],'String','Superior','HorizontalAlignment','Left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.08 0.02],'String','Inferior','HorizontalAlignment','Right',...
            'BackgroundColor','White','ForegroundColor','red');
        sliceStr1 = sprintf('Slice: %d/%d', slice3_big_RAS, slice_dim(3)-1);
        SLICE3_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');
        
        set(SLICE3_EDIT_BIG,'String',sliceStr1, 'enable','on');
        function axial_slider_big_Callback(src,evt)
            slice3_big = round(get(src,'Value'));
            slice3_big_RAS = slice_dim(3)-round(get(src,'Value'));
            sliceStr1 = sprintf('Slice: %d/%d', slice3_big_RAS, slice_dim(3)-1);
            set(SLICE3_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(3)= round(get(src,'Value'));
            axi_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.15 0.03 0.25 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.2 0.03 0.24 0.02],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1)-1;
        cor_RAS = slice_dim(2)-oldcoords_big(2);
        axi_RAS = slice_dim(3)-oldcoords_big(3);
        
        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
        function clickcursor_big(src,evt)
            posit = round(get(gca,'currentpoint'));
            if posit(1,2) <= size(img_display,1) && posit(1,1) <= size(img_display,1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[posit(1,1),posit(1,2),oldcoords_big(3)];
                axi_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
                sag_RAS = oldcoords_big(1)-1;
                cor_RAS = slice_dim(2)-oldcoords_big(2);
                axi_RAS = slice_dim(3)-oldcoords_big(3);
            end
        end
    end

    % big view image display
    function axi_view_big(s,c,a)
        
        mdata = rot90(fliplr(squeeze(img_display(:,:,a))));      
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;  
        
        imagesc(mdata,[0 127]);
        colormap(gmap);
        
        if ~isempty(dti_overlay)
            

            if (dti_overlay_RGB == true)
                hold on;
                
                % 1) calculate vector colors (for each voxel)
                dti_colour_top = zeros(slice_dim(1), slice_dim(2), 3);
                for y_vox=1:slice_dim(2)
                    for x_vox=1:slice_dim(1)

                          dti_colour_top(x_vox, y_vox, 1) = uint8(abs(dti_overlay.x.img(x_vox, y_vox, a))*255);
                          dti_colour_top(x_vox, y_vox, 2) = uint8(abs(dti_overlay.y.img(x_vox, y_vox, a))*255);
                          dti_colour_top(x_vox, y_vox, 3) = uint8(abs(dti_overlay.z.img(x_vox, y_vox, a))*255);
                    end
                end

                % 2) flip y direction RAS -> RPS
                img = flipdim(dti_colour_top,2);

                if(dti_overlay.x.hdr.dime.datatype==2)
                    dti_colour_top=uint8(img);
                else
                    maxVal = max(max(max(img)));
                    maxVal = double(maxVal);
                    scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                    img_scaled = scaleTo8bit*img; 
                    dti_colour_top = uint8(img_scaled);
                end
                
                % 3) display vector colors
                
                o_data = rot90(fliplr(squeeze(dti_colour_top(:,:,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data);
                
                if modDTIImage
                    set(im, 'AlphaData', mdata);
                end
                
                hold off;
                
            elseif (dti_overlay_lines == true)
                hold on;
                
                % each voxel is 100x100x100 pixels (for ploting line)
                line_img = zeros(slice_dim(1)*8, slice_dim(2)*8, 'uint8');
                

                xDim = dti_overlay.y.hdr.dime.pixdim(2);
                yDim = dti_overlay.y.hdr.dime.pixdim(3);
                zDim = dti_overlay.y.hdr.dime.pixdim(4);

                minDim = min(xDim, min(yDim, zDim));

                % calculate line for each voxel
                for y_vox=0:slice_dim(2)-1
                    for x_vox=0:slice_dim(1)-1

                        % slice1_RAS okay to use here? have to translate/rotate?
                        yVec = dti_overlay.y.img(x_vox+1, y_vox+1, a)*50;
                        xVec = dti_overlay.x.img(x_vox+1, y_vox+1, a)*50;

                        if (yVec ~= 0 || xVec ~= 0)
                            
                            % flip y dimension
                            y_vox_new = slice_dim(2) - y_vox;
                            coords = [x_vox y_vox_new];
                            coords = coords*100+50;
                            
                            x_pos1 = coords(1) - xVec;
                            x_pos2 = coords(1) + xVec;
                            y_pos1 = coords(2) - yVec;
                            y_pos2 = coords(2) + yVec;
                            
                            line([x_pos1, x_pos2], [y_pos1, y_pos2], 'color', 'y');
                        end

                    end
                end

                %imagesc(line_img,[0 127]);
                fprintf('Drew lines\n');
                hold off;
            else
                hold on;
                o_data = rot90(fliplr(squeeze(img_display_top(:,:,a))));      
                o_data = o_data * contrast_value;

                im = imagesc(o_data,[0 127]);
                mask = o_data > 0;
                set(im, 'AlphaData', mask);
                hold off;
            end
            
        end
        
        axis off;
        axi_hor=line(1:size(img_display,1),c*(ones(size(img_display,1))),'color',orange);
        axi_ver=line(s*(ones(size(img_display,3))),1:size(img_display,3),'color',orange);
    end

    function sag_view_big(s,c,a)
        
        mdata = rot90(fliplr(squeeze(img_display(s,:,:))));      
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127;  
        
        imagesc(mdata,[0 127]);
        colormap(gmap);
        
        if ~isempty(dti_overlay)
            
            if (dti_overlay_RGB == true )
                hold on;
                
                % 1) calculate vector colors (for each voxel)
                dti_colour_top = zeros(slice_dim(2), slice_dim(3), 3);
                for z_vox=1:slice_dim(3)
                    for y_vox=1:slice_dim(2)
                        
                          dti_colour_top(y_vox, z_vox, 1) = uint8(abs(dti_overlay.x.img(s, y_vox, z_vox))*255);
                          dti_colour_top(y_vox, z_vox, 2) = uint8(abs(dti_overlay.y.img(s, y_vox, z_vox))*255);
                          dti_colour_top(y_vox, z_vox, 3) = uint8(abs(dti_overlay.z.img(s, y_vox, z_vox))*255);
                        
                    end
                end

                % 2) do appropriate modifications to image to prep display
                
                % flip z direction RAS -> RAI
                img2 = flipdim(dti_colour_top,2);
                
                % flip y direction RAI -> RPI
                dti_colour_top = flipdim(img2,1);

                if(dti_overlay.x.hdr.dime.datatype==2)
                    dti_colour_top=uint8(dti_colour_top);
                else
                    maxVal = max(max(max(dti_colour_top)));
                    maxVal = double(maxVal);
                    scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                    dti_colour_top = scaleTo8bit*dti_colour_top; 
                    dti_colour_top = uint8(dti_colour_top);
                end
                
                % 3) display vector colors
                
                o_data = rot90(fliplr(squeeze(dti_colour_top(:,:,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data);
                
                if modDTIImage
                    set(im, 'AlphaData', mdata);
                end
                
                hold off;
            else
                hold on;
                
                o_data = rot90(fliplr(squeeze(img_display_top(s,:,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data,[0 127]);
                mask = o_data > 0;
                set(im, 'AlphaData', mask);
                hold off;
            end
            
        end
        
        axis off;
        sag_hor=line(1:size(img_display,2),a*(ones(size(img_display,2))),'color',orange);
        sag_ver=line(c*(ones(size(img_display,3))),1:size(img_display,3),'color',orange);
    end

    function cor_view_big(s,c,a)
        
        mdata = rot90(fliplr(squeeze(img_display(:,c,:))));      
        mdata = mdata * contrast_value;
        idx = find(mdata > 127);
        mdata(idx) = 127; 
        
        imagesc(mdata,[0 127]);
        colormap(gmap);
        
        if ~isempty(dti_overlay)
            
            if (dti_overlay_RGB == true )
                hold on;
                
                % 1) calculate vector colors (for each voxel)
                dti_colour_top = zeros(slice_dim(1), slice_dim(3), 3);
                for z_vox=1:slice_dim(3)
                    for x_vox=1:slice_dim(1)

                          dti_colour_top(x_vox, z_vox, 1) = uint8(abs(dti_overlay.x.img(x_vox, c, z_vox))*255);
                          dti_colour_top(x_vox, z_vox, 2) = uint8(abs(dti_overlay.y.img(x_vox, c, z_vox))*255);
                          dti_colour_top(x_vox, z_vox, 3) = uint8(abs(dti_overlay.z.img(x_vox, c, z_vox))*255);
                    end
                end

                % 2) do appropriate modifications to image to prep display
                
                % flip z direction RAS -> RAI 
                dti_colour_top = flipdim(dti_colour_top,2);

                if(dti_overlay.x.hdr.dime.datatype==2)
                    dti_colour_top=uint8(dti_colour_top);
                else
                    maxVal = max(max(max(dti_colour_top)));
                    maxVal = double(maxVal);
                    scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                    dti_colour_top = scaleTo8bit*dti_colour_top; 
                    dti_colour_top = uint8(dti_colour_top);
                end
                
                % 3) display vector colors
                
                o_data = rot90(fliplr(squeeze(dti_colour_top(:,:,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data);
                
                if modDTIImage
                    set(im, 'AlphaData', mdata);
                end
                
                hold off;
            else
            
                hold on;
                o_data = rot90(fliplr(squeeze(img_display_top(:,c,:))));      
                o_data = o_data * contrast_value;
                im = imagesc(o_data,[0 127]);
                mask = o_data > 0;
                set(im, 'AlphaData', mask);
                hold off;
            end
            
        end
        
        axis off;
        cor_hor=line(1:size(img_display,1),a*(ones(size(img_display,1))),'color',orange);
        cor_ver=line(s*(ones(size(img_display,3))),1:size(img_display,3),'color',orange);
    end

    if exist('dtiFile','var')
        openDTI(dtiFile);
        if ~isempty(dti_nii)
            set(OVERLAY_MENU,'enable','on');
        end
    end

    if exist('dti_overlay','var')
        loadDTIOverlay(overlayFile);
    end
end