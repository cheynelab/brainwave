%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function DTI_preprocessor
%
%   Module for basic DTI data pre-processing: brain extraction, artifact 
%   correction, bedpostx, registration, diffusion tensor fitting, binary
%   mask creation, and probabilistic tractography.
%
%   written by Merron Woodbury, 2019
%   
%   Version 1.1 - October, 2019
%
%   Version 1.2 - December, 2019 - made independent of BrainWave
%
%   Version 1.3 - May, 2022 - D. Cheyne - modifications for new toolbox                                    
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function DTI_preprocessor

% ======================== Global variables ============================= %

ds_folder = [];
bvecs_file = [];
bvals_file = [];
original_file = [];

blip1_file = [];

unzip_folder = [];

bet_file = [];

acqparams_file = [];
index_file = [];
corrected_file = [];

std_ref_file = [];
mri_ref_file = [];

bedpostx_dir = [];
reg_dir = [];

loaded_files = [];
files = {};

bet_file_prefix = 'nodif_brain';
fvalue = 0.5;
b0_vol_num = 0;
head_center = [0 0 0];
use_fid = 0; 

topup_opt = 1;
b0_images_name = 'multi_directions_b0';
topup_prefix = 'topup_output';
corr_file_prefix = 'data';
shell_check_opt = 0;
slm_linear = 0;

dti_file_prefix = 'dti';
dti_folder_name = 'dti';
dti_reg_mri = 0;
dti_reg_std = 0;

num_fibres = 2;
ard_weight = 1;
burnin_period = 1000;
num_jumps = 1250;
sample_every = 25;

mask_name = 'mask';
marker = 1;
drawing = 0;
markersize = 2;
prev = [];
up = 0;

prob_folder = 'tract1';
axi_tract_proj = [];
cor_tract_proj = [];
sag_tract_proj = [];

max_dim = 256;
slice_dim = [max_dim max_dim max_dim];
slice1_RAS = round(max_dim/2)-1;
slice2_RAS = round(max_dim/2)-1;
slice3_RAS = round(max_dim/2)-1;
oldcoords = [slice1_RAS slice2_RAS slice3_RAS];

axi_subplot = [0.54 0.12 0.18 0.36];
cor_subplot = [0.54 0.56 0.18 0.36];
sag_subplot = [0.76 0.56 0.18 0.36];

overlayAlpha = 1.0;

% Display mode:
% 0 - Nothing (regular display)
% 1 - show BET outline mask in yellow
% 2 - show drawing in red ontop of background
% 3 - display mask image ([0 1])
% 4 - show svl image overlaid in warm tones
% 5 - display tractography image overlaid in warm tones
% 6 - display projected tractography image
% 7 - show DTI vectors modulated by diffusion space image
% 8 - show DTI vectors modulated by diffusion space image ontop of MRI
display_mode = 0;

img_display = zeros(max_dim, max_dim, max_dim);
mask = zeros(max_dim, max_dim, max_dim);
vox_img_display = [];
dti_colour_top = [];
tract_colour_top = [];
overlay_img = [];

axiaxis = [];
coraxis = [];
sagaxis = [];

data_nii = [];
dti_v1_overlay = [];
dti_fa_overlay = [];
max_volumes = 1;

isPlaying = false;

maxBrightness = 3.0;
contrast_value = 0.4*maxBrightness;

na_RAS = [0 0 0];
le_RAS = [0 0 0];
re_RAS = [0 0 0];
mmPerVoxel = 1;

button_text = [0.6,0.25,0.1];
orange = [0.8,0.4,0.1];
light_blue = [0.6 0.65 1];

axi_hor = [];
axi_ver = [];
cor_hor = [];
cor_ver = [];
sag_hor = [];
sag_ver = [];

% ========================= FSL set-up ================================== %

% get FSL directory
fsldir = getenv('FSLDIR');
if isempty(fsldir)
    response = warning_dialog('Cannot find FSL directory. Would you like to look for it?');      
    if response
        fsldir = uigetdir;
        setenv('FSLDIR', char(fsldir));
        fsldir = getenv('FSLDIR');
    else
        return;
    end
    if ~exist(fsldir,'dir')
        fprintf('Error:  FSL does not seem to be installed and configured on this computer. Exiting...\n');
        return;
    elseif isequal(fsldir, 0)
        return;
    end
end

setenv('FSLOUTPUTTYPE', 'NIFTI_GZ');

fsldirmpath = sprintf('%s/etc/matlab',fsldir);
path(path, fsldirmpath);
setenv('PATH', [getenv('PATH') strcat(':', fsldir, '/bin')]);

% get FSL version number
fslVerFile = [fsldir,'/etc/fslversion'];
FSLVer = load(fslVerFile);     
if FSLVer < 6
    fprintf('You are running FSL version %g. FSL version 6 or higher recommended ...\n', FSLVer);
    return;
end

fid = fopen(fslVerFile);       
FSLVerTxt = fscanf(fid,'%s');
fclose(fid);
fprintf('Using FSL version %s in %s ...\n', FSLVerTxt, fsldir);

% ============================ Window =================================== %

% open dialog window
scrsz = get(0,'ScreenSize');

f=figure('Name', 'DTI Pre-processor', 'Position', [(scrsz(3)-1800)/2 (scrsz(4)-900)/2 1800 900],...
    'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@stopdrag,'WindowButtonDownFcn',@buttondown);

if ispc
    movegui(f,'center');
end

% colormaps (for overlays)
omap = [linspace(0.8,1,128)', linspace(0.3,0.5,128)', zeros(128,1)];
rmap = [linspace(0.6,1,128)', linspace(0.05,0.2,128)', linspace(0.05,0.2,128)'];
cymap = [linspace(0.05,0.2,128)', linspace(0.4,0.8,128)', linspace(0.4,0.8, 128)'];
bmap = [zeros(128,1), linspace(0.1,0.5,128)', linspace(0.6,1,128)'];
grmap = [zeros(128,1), linspace(0.3,0.6,128)', linspace(0.05,0.3,128)'];
purmap = [linspace(0.2,0.6,128)', linspace(0.1,0.5,128)', linspace(0.3,0.7,128)'];
hmap = colormap(hot(128));
pmap = colormap(parula(128));
gmap = colormap(gray(128));
tmap = [gmap; pmap];
cmap = [gmap; hmap];
overlay_cmaps = [gmap; hmap; bmap; cymap; purmap; rmap; omap];
overlay_tmaps = [gmap; pmap; rmap; purmap; bmap; cymap; grmap];

% menus
FILE_MENU=uimenu('Label','File');

uimenu(FILE_MENU, 'label', 'Import Diffusion files from DICOM ...', 'callback', @import_DTI_dataset);

% uimenu(FILE_MENU, 'label', 'Load Dataset files ...', 'separator', 'on','callback', @select_DTI_dataset);
LOAD_MENU = uimenu(FILE_MENU, 'label', 'Load Processed files ...', 'separator', 'on');
uimenu(LOAD_MENU, 'label', 'Select Diffusion Data file...', 'enable', 'on', 'callback', @load_data_file_callback);
load_bvecs = uimenu(LOAD_MENU, 'label', 'Select Bvecs file...', 'enable', 'off', 'callback', @load_bvecs_file);
load_bvals = uimenu(LOAD_MENU, 'label', 'Select Bvals file...', 'enable', 'off','callback', @load_bvals_file);
load_bet = uimenu(LOAD_MENU, 'label', 'Select BET overlay file...', 'enable', 'off','callback', @load_bet_callback);
uimenu(LOAD_MENU, 'label', 'Select Corrected Diffusion file...', 'callback', @load_corrected_file_callback);
load_b0 = uimenu(FILE_MENU, 'label', 'Select B0 files...', 'enable', 'off','callback', @load_b0_file);
uimenu(FILE_MENU,'label','Close','Callback','closereq','Accelerator','W','separator','on');    

LOAD_MENU=uimenu('Label','Load');
uimenu(LOAD_MENU, 'label', 'Load Volume...', 'callback', @load_volume_callback);
uimenu(LOAD_MENU, 'label', 'Load Tractography...', 'callback', @load_tract_file);
uimenu(LOAD_MENU, 'label', 'Load DTI Images...', 'callback', @load_dtifit_file);
ADD_OVERLAY = uimenu(LOAD_MENU, 'label', 'Add overlay...', 'separator', 'on', 'callback', @add_overlay);
uimenu(LOAD_MENU, 'label', 'Clear overlays', 'callback', @clear_overlay);

EXTRACT_MENU=uimenu('label', 'Extract');
uimenu(EXTRACT_MENU, 'label', 'Extract Volume...', 'callback', @extract_volume_callback);
uimenu(EXTRACT_MENU, 'label', 'Merge Volumes...', 'callback', @merge_volumes_callback);

% Dataset Files Display
WORKSPACE_TEXT_TITLE = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.05 0.92 0.4 0.02],'String','Diffusion File:','HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');
WORKSPACE_TEXT_TITLE2 = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.05 0.89 0.4 0.02],'String','BVecs File:','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','Black', 'enable','off');
WORKSPACE_TEXT_TITLE3 = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.05 0.86 0.4 0.02],'String','BVals File:','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','Black', 'enable','off');
WORKSPACE_TEXT_TITLE5 = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.05 0.83 0.42 0.02],'String','B0 Files:','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','black', 'enable','off');
WORKSPACE_TEXT_TITLE4 = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.05 0.8 0.4 0.02],'String','Diffusion File (corrected):','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','Black', 'enable','off');

Dataset_Dir = uicontrol('style','text','units','normalized','position',[0.04 0.95 0.2 0.02],...
        'String','Dataset Files','ForegroundColor','blue','FontSize', 11,...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');
annotation('rectangle','position',[0.03 0.79 0.45 0.17],'edgecolor','blue');


% ================== Pre-processing Steps section ======================= %

uicontrol('style','text','units','normalized','position',[0.04 0.76 0.1 0.02],...
        'String','Pre-processing Steps','ForegroundColor','blue','FontSize', 11,...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');
annotation('rectangle','position',[0.03 0.41 0.45 0.36],'edgecolor','blue');

    
% 1) BET
BET_BUTTON=uicontrol('Style','PushButton','Units','Normalized','Position', [0.05 0.7 0.08 0.04], 'callback', @bet_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor', button_text, 'String', 'BET', 'enable', 'off');
fvalue_text = uicontrol('style','text','units','normalized','position',[0.25 0.71 0.05 0.02],'enable', 'off',...
        'String','F Value:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
fvalue_edit = uicontrol('style','edit','units','normalized','position',[0.28 0.71 0.03 0.03],'String', num2str(fvalue),...
        'FontSize', 11, 'BackGroundColor','white', 'enable', 'off', 'callback',@fvalue_edit_callback);
    function fvalue_edit_callback(src,~)
                fvalue = str2double(get(src, 'String'));
    end    
b0_volume_text = uicontrol('style','text','units','normalized','position',[0.15 0.71 0.05 0.02],...
    'string','B0 Volume Num:','fontsize',11,'background','white','horizontalalignment','left','enable', 'off');
b0_volume_edit = uicontrol('style','edit','units','normalized','position',...
    [0.21 0.71 0.02 0.03],'String', '0',...
    'FontSize', 11, 'BackGroundColor','white', 'enable', 'off', 'callback',@b0_edit_callback);
    function b0_edit_callback(src,~)
            b0_vol_num = int8(str2double(get(src, 'String')));
    end

% head center used in BET
headCenter_txt = uicontrol('style','text','units','normalized','position',[0.15 0.67 0.08 0.02],...
    'string','Head Center (voxels)','fontsize',10,'background','white','horizontalalignment','left','enable', 'off');
headCenter_edit1 = uicontrol('style','edit','units','normalized','position',...
    [0.21 0.67 0.02 0.03],'String', head_center(1),...
    'FontSize', 10, 'BackGroundColor','white','enable', 'off');
headCenter_edit2 = uicontrol('style','edit','units','normalized','position',...
    [0.24 0.67 0.02 0.03],'String', head_center(2),...
    'FontSize', 10, 'BackGroundColor','white','enable', 'off');
headCenter_edit3 = uicontrol('style','edit','units','normalized','position',...
    [0.27 0.67 0.02 0.03],'String', head_center(3),...
    'FontSize', 10, 'BackGroundColor','white','enable', 'off');

BVALS_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.32 0.71 0.06 0.03], 'callback', @bvals_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor','blue', 'String', 'View Bvals', 'enable', 'off');
    function bvals_callback(~,~)
        
        bvals = load(bvals_file);
        fig2=figure('Name', 'B Values', 'Position', [(scrsz(3)-600)/2 (scrsz(4)-200)/2 600 200],...
            'menubar','none','numbertitle','off', 'Color','white',...
            'WindowButtonUpFcn',@buttondown);
        uitable(fig2, 'Data', bvals, 'Position', [0 0 600 200], 'ColumnName', {0:size(bvals, 2)-1}, 'RowName', {'b'});
        
    end
CHECK_BVECS_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.32 0.675 0.06 0.03],'callback', @check_bvecs_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor','blue', 'String', 'View Bvecs', 'enable', 'off');  
    function check_bvecs_callback(~,~)
        bvecs = load(bvecs_file); 
        figure('Name', 'Bvecs Viewer (use cursor to rotate)', 'position', [(scrsz(3)-100)/2 (scrsz(4)-500)/2 500 500],...
            'menubar','none','numbertitle','off', 'Color','white', 'WindowButtonUpFcn',@buttondown);
        % plot end points of b-vectors
        plot3(bvecs(1,:),bvecs(2,:),bvecs(3,:),'*r');
        axis([-1 1 -1 1 -1 1]);
        axis vis3d;
        rotate3d; 
    end

ACQ_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.4 0.71 0.06 0.03], 'callback', @acq_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor','blue', 'String', 'Acq Params', 'enable', 'off');
    function acq_callback(~,~)       
        make_acqparams;      
    end

INDEX_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.4 0.675 0.06 0.03], 'callback', @index_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor','blue', 'String', 'Index File', 'enable', 'off');
    function index_callback(~,~)       
        make_index;      
    end

    function set_enable_bet(instr)
            set(BET_BUTTON, 'enable', instr);
            set(fvalue_text, 'enable', instr);
            set(fvalue_edit, 'enable', instr);
            set(b0_volume_text, 'enable', instr);
            set(b0_volume_edit, 'enable', instr);
            set(headCenter_txt, 'enable', instr);
            set(headCenter_edit1, 'enable', instr);
            set(headCenter_edit2, 'enable', instr);
            set(headCenter_edit3, 'enable', instr);
            set(BVALS_BUTTON, 'enable', instr);
            set(CHECK_BVECS_BUTTON, 'enable', instr);
            set(ACQ_BUTTON, 'enable', instr);
            set(INDEX_BUTTON, 'enable', instr);
    end


% 2) Artifact Correction
ART_CORRECT_BUTTON=uicontrol('Style','pushbutton','Units','Normalized','Position', [0.05 0.61 0.08 0.04], 'callback', @eddy_correct_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor',button_text, 'String', 'Artifact Correction', 'enable', 'off');
TOPUP_BOX = uicontrol('Style', 'checkbox', 'units', 'normalized','Position', [0.15 0.625 0.1 0.02], ...
    'Value', topup_opt, 'fontsize', 11, 'FontWeight', 'normal','background','white',...
    'horizontalalignment','left', 'enable', 'off', 'string', 'Multiple PE directions','callback', @topup_opt_callback);
    function topup_opt_callback(src,~)
        topup_opt = get(src, 'Value');
    end

SHELL_CHECK_BOX = uicontrol('Style', 'checkbox', 'units', 'normalized','Position', [0.255 0.625 0.12 0.02], ...
    'Value', ~shell_check_opt, 'fontsize', 11, 'FontWeight', 'normal','background','white',...
    'horizontalalignment','left', 'String', 'Bypass Shell Checking', 'enable', 'off','callback', @shell_check_callback);
    function shell_check_callback(src, ~)
       shell_check_opt = 1 - get(src, 'Value'); 
    end 

SLM_CHECK_BOX = uicontrol('Style', 'checkbox', 'units', 'normalized','Position', [0.37 0.625 0.08 0.02], ...
    'Value', slm_linear, 'fontsize', 11, 'FontWeight', 'normal','background','white',...
    'horizontalalignment','left', 'String', 'Linear slm', 'enable', 'off','callback', @slm_check_callback);
    function slm_check_callback(src,~)
        slm_linear = get(src, 'value');
    end

    function set_enable_eddy(instr)
            set(ART_CORRECT_BUTTON, 'enable', instr);
            
            % FSL Version restrictions
            if FSLVer > 5.0 || (FSLVer==5.0 && (str2double(FSLVerTxt(5:end))>10))
                
                % topup available for 6.0.0 and greater
                if FSLVer >= 6.0
                    set(TOPUP_BOX, 'enable', instr);
                end
                
                % eddy available for 5.0.11 and greater
                set(SHELL_CHECK_BOX, 'enable', instr);
                set(SLM_CHECK_BOX, 'enable', instr);
            end
            
    end
    
% 3) Bedpostx
BEDPOST_BUTTON=uicontrol('Style','PushButton','Units','Normalized','Position', [0.05 0.53 0.08 0.04],'callback', @bedpostx_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor',button_text, 'String', 'BedpostX', 'enable', 'off');
fibres_text = uicontrol('style','text','units','normalized','position',[0.15 0.54 0.08 0.02],'enable', 'off',...
        'String','Fibres per voxel:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
fibres_edit = uicontrol('style','edit','units','normalized','position',...
        [0.23 0.54 0.03 0.03],'String', num_fibres,'FontSize', 11, 'BackGroundColor','white', 'enable', 'off',...
        'callback',@fibres_edit_callback);
    function fibres_edit_callback(src,~)
        num_fibres = round(str2double(get(src, 'String')));
    end
weight_text = uicontrol('style','text','units','normalized','position',[0.15 0.5 0.08 0.02],'enable', 'off',...
        'String','ARD Weight:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
weight_edit = uicontrol('style','edit','units','normalized','position',...
        [0.23 0.5 0.03 0.03],'String', ard_weight,'FontSize', 11, 'BackGroundColor','white', 'enable', 'off',...
        'callback',@weight_edit_callback);
    function weight_edit_callback(src,~)
        ard_weight = round(str2double(get(src, 'String')));
    end
burnin_text = uicontrol('style','text','units','normalized','position',[0.37 0.5 0.08 0.02],'enable', 'off',...
        'String','Burnin period:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
burnin_edit = uicontrol('style','edit','units','normalized','position',...
        [0.43 0.5 0.03 0.03],'String', burnin_period,'FontSize', 11, 'BackGroundColor','white', 'enable', 'off',...
        'callback',@burnin_edit_callback);
    function burnin_edit_callback(src,~)
        burnin_period = round(str2double(get(src, 'String')));
    end
jumps_text = uicontrol('style','text','units','normalized','position',[0.27 0.54 0.06 0.02],'enable', 'off',...
        'String','Num. jumps:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
jumps_edit = uicontrol('style','edit','units','normalized','position',...
        [0.33 0.54 0.03 0.03],'String', num_jumps,'FontSize', 11, 'BackGroundColor','white', 'enable', 'off',...
        'callback',@jumps_edit_callback);
    function jumps_edit_callback(src,~)
         num_jumps = round(str2double(get(src, 'String')));
    end
sample_text = uicontrol('style','text','units','normalized','position',[0.27 0.5 0.06 0.02],'enable', 'off',...
        'String','Sample every:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
sample_edit = uicontrol('style','edit','units','normalized','position',...
        [0.33 0.5 0.03 0.03],'String', sample_every,'FontSize', 11, 'BackGroundColor','white', 'enable', 'off',...
        'callback',@sample_edit_callback);
    function sample_edit_callback(src,~)
        sample_every = round(str2double(get(src, 'String')));
    end

FOLDER_SETUP_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.37 0.54 0.08 0.03],'callback', @check_folder_callback, ...
        'HorizontalAlignment','Center', 'FontSize', 11, 'ForegroundColor','blue', 'String', 'Verify Dataset', 'enable', 'off');
    function check_folder_callback(~,~)
        verify_datasest;      
    end

    function bedpostx_ready = verify_datasest
        bedpostx_ready = 1;
        str = cell(4,1);
        cur_cell = 1;
        
        % check 4D data is named 'data.nii.gz'
        if ~exist(fullfile(ds_folder, 'data.nii.gz'), 'file')
            str(cur_cell) = {sprintf('Subject directory must contain 4D data file named "data.nii.gz"\n')};
            bedpostx_ready = 0;
            cur_cell = cur_cell + 1;
        end
        
        % check bvecs and bvals are named appropriately
        if ~exist(fullfile(ds_folder, 'bvecs'), 'file')
            str(cur_cell) = {sprintf('Subject directory must contain b vector file named "bvecs" (no extension)\n')};
            bedpostx_ready = 0;
            cur_cell = cur_cell + 1;
        end
        
        if ~exist(fullfile(ds_folder, 'bvals'), 'file')
            str(cur_cell) = {sprintf('Subject directory must contain b value file named "bvals" (no extension)\n')};
            bedpostx_ready = 0;
            cur_cell = cur_cell + 1;
        end
        
        % check brain mask is named appropriately
        if ~exist(fullfile(ds_folder, 'nodif_brain_mask.nii.gz'), 'file')
            str(cur_cell) = {sprintf('Subject directory must contain brain mask file named "nodif_brain_mask.nii.gz"\n')};
            bedpostx_ready = 0;
        end
        
        if bedpostx_ready
            fprintf('Subject directory (%s) is ready for bedpostx call\n', ds_folder);
            set(BEDPOST_BUTTON, 'enable', 'on');
        else
            bedpostx_warnings(str);
        end
        
    end
   
    % warning with file naming discrepances
    function bedpostx_warnings(str)
        scrnsizes=get(0,'MonitorPosition');
        fg=figure('Name', 'BrainWave - Alert', 'Position', [(scrnsizes(3)-600)/2 (scrnsizes(4)-300)/2 600 300],...
            'menubar','none','numbertitle','off', 'Color','white');

        uicontrol('style','text','fontsize',10,'Units','Normalized','Position',...
            [0.05 0.85 0.9 0.1],'String',char(str{1}),'BackgroundColor','White','HorizontalAlignment','left');
        uicontrol('style','text','fontsize',10,'Units','Normalized','Position',...
            [0.05 0.75 0.9 0.1],'String',char(str{2}),'BackgroundColor','White','HorizontalAlignment','left');
        uicontrol('style','text','fontsize',10,'Units','Normalized','Position',...
            [0.05 0.65 0.9 0.1],'String',char(str{3}),'BackgroundColor','White','HorizontalAlignment','left');
         uicontrol('style','text','fontsize',10,'Units','Normalized','Position',...
            [0.05 0.55 0.9 0.1],'String',char(str{4}),'BackgroundColor','White','HorizontalAlignment','left');
        
        %buttons
        uicontrol('style','pushbutton','fontsize',10,'units','normalized','position',...
            [0.7 0.1 0.2 0.15],'string','Okay','Backgroundcolor','white','foregroundcolor',[0.8,0.4,0.1],'callback',@yes_button_callback);

            function yes_button_callback(~,~)
                uiresume(gcf);
            end   
        uiwait(gcf);

        if ishandle(fg)
            close(fg);   
        end
    end

    function set_enable_bedpostx(instr)
            set(fibres_text, 'enable', instr);
            set(weight_text, 'enable', instr);
            set(burnin_text, 'enable', instr);
            set(jumps_text, 'enable', instr);
            set(sample_text, 'enable', instr);
            set(fibres_edit, 'enable', instr);
            set(weight_edit, 'enable', instr);
            set(burnin_edit, 'enable', instr);
            set(jumps_edit, 'enable', instr);
            set(sample_edit, 'enable', instr);
            set(FOLDER_SETUP_BUTTON, 'enable', instr);            
    end

RUN_ALL_BUTTON=uicontrol('Style','PushButton','Units','Normalized','Position', [0.05 0.43 0.08 0.04],'callback', @run_all_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor',button_text, 'String', 'Run All','enable','off');
    function run_all_callback(~,~)
        run_eddy_correct;
        run_bedpost;
    end
    
%%%%  Analysis section

SELECT_BEDPOST_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.05 0.33 0.08 0.04],'callback', @load_bedpostx_folder, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor',button_text, 'String', 'Select Bedpost folder','enable', 'off');
    
BEDPOST_FOLDER_TXT = uicontrol('style','text','units','normalized','position',[0.15 0.34 0.28 0.03],...
        'String',bedpostx_dir,'FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');

    
REGISTRATION_BUTTON=uicontrol('Style','PushButton','Units','Normalized','Position', [0.05 0.26 0.08 0.04],'callback', @register_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor',button_text, 'String', 'Update Registration', 'enable', 'off');
    
select_std_txt = uicontrol('style','text','units','normalized','position',[0.15 0.27 0.13 0.03],'enable', 'off',...
        'String','Standard Space Reference:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
select_std_label = uicontrol('style','text','units','normalized','position',[0.15 0.24 0.13 0.03],'enable', 'off',...
        'String','none','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
select_std_ref = uicontrol('style','pushbutton','units','normalized','HorizontalAlignment','Center',...
    'position',[0.23 0.275 0.05 0.03],'String', 'Select', 'fontsize',11,'enable','off', 'callback',@select_std_callback);  

    function select_std_callback(~,~)

        defPath = fullfile(fsldir, 'data', 'standard');
        [filename, pathname] = uigetfile({'*.nii.gz','Standard Space Reference (*.nii.gz)'},...
            'Select Standard Space Reference', defPath);
        if isequal(filename,0) || isequal(pathname, 0)
            return;
        end
        std_ref_file = fullfile(pathname, filename);
        std_ref_file = getUnzipped(std_ref_file);
        [~, n, ~] = fileparts(std_ref_file);
 
        dti_reg_std = 1;
        
        % add reference file to Viewer
        display_mode = 0;
        loadData(std_ref_file);
        
        l = size(files,2);
        files(l+1) = {n};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        loaded_files{size(loaded_files,1)+1, 1} = 0;
        loaded_files{size(loaded_files,1), 2} = {std_ref_file};
        [~,n,e] = fileparts(std_ref_file);
        set(select_std_label,'string',[n e]);
        set(REGISTRATION_BUTTON,'enable','on');
        
    end

select_mri_txt = uicontrol('style','text','units','normalized','position',[0.3 0.27 0.13 0.03],'enable', 'off',...
        'String','Structural Space Reference:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
select_mri_label = uicontrol('style','text','units','normalized','position',[0.3 0.24 0.13 0.03],'enable', 'off',...
        'String','none','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
select_mri_ref = uicontrol('style','pushbutton','units','normalized','HorizontalAlignment','Center',...
    'position',[0.38 0.275 0.05 0.03],'String', 'Select', 'fontsize',11,'enable','off', 'callback',@select_ref_callback);  


    function select_ref_callback(~,~)

        [filename, pathname] = uigetfile({'*.nii','Structural Space Reference (*.nii)'},...
            'Select Structural Space Reference');
        if isequal(filename,0) || isequal(pathname, 0)
            return;
        end
        mri_ref_file = fullfile(pathname, filename);
        
        % if selecting an anatomical image from another directory suggest make local copy           
        [p,~,~] = fileparts(mri_ref_file);
        if ~isempty(p) && ~isempty(ds_folder)
            if ~strcmp(p,ds_folder)
                s = sprintf('Create local copy of the reference image file %s?', mri_ref_file);
                r = questdlg(s,'DTI Analysis','Yes','No','Yes');
                if strcmp(r,'Yes')
                    command = sprintf('cp %s %s', mri_ref_file, ds_folder);  % won't be called from windows...
                    system(command);
                    mri_ref_file = strcat(ds_folder, filesep, filename);                    
                end    
            end
        end
        
        [~, n, ~] = fileparts(mri_ref_file);
        
        mri_nii = load_nii(mri_ref_file);       
        if isempty(mri_nii)
            return;
        end  
                            
        % must use isotropic, NIfTI MRI file
        if  ((mri_nii.hdr.dime.pixdim(2) ~= mri_nii.hdr.dime.pixdim(3)) ) && ((mri_nii.hdr.dime.pixdim(2) ~= mri_nii.hdr.dime.pixdim(4)) )
            fprintf('This file is not isotropic. Use MRIViewer to import file and extract surfaces...\n');
            clear mri_nii;
            return;
        end
        
        clear mri_nii;

        dti_reg_mri = 1;
        
        % add reference file to Viewer
        
        display_mode = 0;
        loadData(mri_ref_file);
    
        l = size(files,2);
        files(l+1) = {n};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        loaded_files{size(loaded_files,1)+1, 1} = 0;
        loaded_files{size(loaded_files,1), 2} = {mri_ref_file};
        [~,n,e] = fileparts(mri_ref_file);
        set(select_mri_label,'string',[n e]);
        
        set(REGISTRATION_BUTTON,'enable','on');
        
    end

% ========================= DICOM import  ==================================== %


    % D. Cheyne - moved file inputs here, revised import procedure. 
    
    
    function [dicom_dir, ds_dir, blip1_dir] = select_dicom_files
        
        ds_dir = [];
        dicom_dir = [];
        blip1_dir = [];
        
        d = figure('Position',[500 800 600 300],'Name','Import DICOM Files', ...
            'numberTitle','off','menubar','none');
        if ispc
            movegui(d,'center')
        end
        
        uicontrol('Style','text',...
            'fontsize',12,...
            'HorizontalAlignment','left',...
            'units', 'normalized',...
            'Position',[0.02 0.8 0.6 0.1],...
            'String','Select Subject Directory for DTI output (required):');

        output_edit = uicontrol('Style','edit',...
            'fontsize',10,...
            'units', 'normalized',...
            'HorizontalAlignment','left',...
            'Position',[0.02 0.73 0.75 0.1],...
            'String','');

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.8 0.73 0.15 0.1],...
            'String','Select',...
            'Callback',@select_output_callback);      
     
   
        uicontrol('Style','text',...
            'fontsize',12,...
            'HorizontalAlignment','left',...
            'units', 'normalized',...
            'Position',[0.02 0.6 0.6 0.1],...
            'String','Select DICOM directory containing diffusion data (required):');

        dti_edit = uicontrol('Style','edit',...
            'fontsize',10,...
            'units', 'normalized',...
            'HorizontalAlignment','left',...
            'Position',[0.02 0.53 0.75 0.1],...
            'String','');

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.8 0.53 0.15 0.1],...
            'String','Select',...
            'Callback',@select_dti_callback);                 
        
        uicontrol('Style','text',...
            'fontsize',12,...
            'HorizontalAlignment','left',...
            'units', 'normalized',...
            'Position',[0.02 0.4 0.8 0.1],...
            'String','Select DICOM directory containing B0 (preBlip) image for PE correction:');

        blip1_edit = uicontrol('Style','edit',...
            'fontsize',10,...
            'units', 'normalized',...
            'HorizontalAlignment','left',...
            'Position',[0.02 0.33 0.75 0.1],...
            'String','');

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.8 0.33 0.15 0.1],...
            'String','Select',...
            'Callback',@select_blip1_callback);                                
        
        
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
            'Callback','delete(gcf)');

        function select_dti_callback(~,~)
                s = uigetdir('*','Select DTI DICOM directory...');
                if s == 0
                    return;
                end             
                set(dti_edit,'string',s);
        end
        
        function select_blip1_callback(~,~)
                s = uigetdir('*','Select DICOM directory...');
                if s == 0
                    return;
                end             
                set(blip1_edit,'string',s);
        end
        
        function select_output_callback(~,~)
            s = uigetdir('*','Select Output directory...');
            if s == 0
                return;
            end    
            set(output_edit,'string',s); 
        end           
           
        function OK_callback(~,~)
            % get from text box in case user typed in
            dicom_dir = get(dti_edit,'string');           
            ds_dir = get(output_edit,'string');         
            s = get(blip1_edit,'string');  
            if ~isempty(s)
                blip1_dir = s;
            end
            delete(d)
        end
              
        % make modal
        uiwait(d);
    end
        
    function [basefile, dtifile, eigenfile] = select_dti_files
        
        basefile = [];
        dtifile = [];
        eigenfile = [];
        
        d = figure('Position',[500 800 900 300],'Name','Import DICOM Files', ...
            'numberTitle','off','menubar','none');
        if ispc
            movegui(d,'center')
        end
        
        uicontrol('Style','text',...
            'fontsize',12,...
            'HorizontalAlignment','left',...
            'units', 'normalized',...
            'Position',[0.02 0.8 0.6 0.1],...
            'String','Optional: Anatomical Reference to overlay image (e.g., bet.nii).');

        basefile_edit = uicontrol('Style','edit',...
            'fontsize',10,...
            'units', 'normalized',...
            'HorizontalAlignment','left',...
            'Position',[0.02 0.73 0.75 0.1],...
            'String','');

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.8 0.73 0.15 0.1],...
            'String','Select',...
            'Callback',@select_basefile_callback);      
     
        uicontrol('Style','text',...
            'fontsize',12,...
            'HorizontalAlignment','left',...
            'units', 'normalized',...
            'Position',[0.02 0.6 0.6 0.1],...
            'String','Optional: Diffusion image to modulate Eigenvector image (e.g.,dti_FA_str.nii.gz, dti_MD_str.nii.gz)');

        dtifile_edit = uicontrol('Style','edit',...
            'fontsize',10,...
            'units', 'normalized',...
            'HorizontalAlignment','left',...
            'Position',[0.02 0.53 0.75 0.1],...
            'String','');

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.8 0.53 0.15 0.1],...
            'String','Select',...
            'Callback',@select_dtifile_callback);                 
        
        uicontrol('Style','text',...
            'fontsize',12,...
            'HorizontalAlignment','left',...
            'units', 'normalized',...
            'Position',[0.02 0.4 0.8 0.1],...
            'String','Select DTI Eigenvector file (e.g., dti_V1_str.nii.gz):');

        eigenfile_edit = uicontrol('Style','edit',...
            'fontsize',10,...
            'units', 'normalized',...
            'HorizontalAlignment','left',...
            'Position',[0.02 0.33 0.75 0.1],...
            'String','');

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.8 0.33 0.15 0.1],...
            'String','Select',...
            'Callback',@select_eigenfile_callback);                                
        
        
        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'foregroundColor','blue',...
            'units', 'normalized',...
            'Position',[0.75 0.1 0.2 0.1],...
            'String','Load',...
            'Callback',@OK_callback);  

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.5 0.1 0.2 0.1],...
            'String','Cancel',...
            'Callback','delete(gcf)');

        function select_basefile_callback(~,~)
            [name, filepath] = uigetfile({'*.nii', 'Select base file (*.nii)'});
            if isequal(name, 0)
                return;
            end         
            basefile = fullfile(filepath, name);              
            set(basefile_edit,'string',basefile);
        end
        
        function select_dtifile_callback(~,~)
            [name, filepath] = uigetfile({'*.nii.gz', 'Select dti fit output file (*.nii)'});
            if isequal(name, 0)
                return;
            end         
            dtifile = fullfile(filepath, name);              
            set(dtifile_edit,'string',dtifile);
        end
        
        function select_eigenfile_callback(~,~)
            [name, filepath] = uigetfile({'*.nii.gz', 'Select dti eigenvector (*.nii)'});
            if isequal(name, 0)
                return;
            end         
            eigenfile = fullfile(filepath, name);              
            set(eigenfile_edit,'string',eigenfile);
        end           

        function OK_callback(~,~)
            % get from text box in case user typed in
            basefile = get(basefile_edit,'string');           
            dtifile = get(dtifile_edit,'string');         
            eigenfile = get(eigenfile_edit,'string');         
            delete(d)
        end
              
        % make modal
        uiwait(d);
    end

    function [basefile, tractfile] = select_tract_files
        
        basefile = [];
        tractfile = [];
        
        d = figure('Position',[500 800 900 300],'Name','Import DICOM Files', ...
            'numberTitle','off','menubar','none');
        if ispc
            movegui(d,'center')
        end
        
        uicontrol('Style','text',...
            'fontsize',12,...
            'HorizontalAlignment','left',...
            'units', 'normalized',...
            'Position',[0.02 0.8 0.6 0.1],...
            'String','Optional: Anatomical Reference to overlay image (e.g., bet.nii).');

        basefile_edit = uicontrol('Style','edit',...
            'fontsize',10,...
            'units', 'normalized',...
            'HorizontalAlignment','left',...
            'Position',[0.02 0.73 0.75 0.1],...
            'String','');

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.8 0.73 0.15 0.1],...
            'String','Select',...
            'Callback',@select_basefile_callback);      
     
        uicontrol('Style','text',...
            'fontsize',12,...
            'HorizontalAlignment','left',...
            'units', 'normalized',...
            'Position',[0.02 0.6 0.6 0.1],...
            'String','Select Tractography file (e.g.,fdt_paths.nii)');

        tractfile_edit = uicontrol('Style','edit',...
            'fontsize',10,...
            'units', 'normalized',...
            'HorizontalAlignment','left',...
            'Position',[0.02 0.53 0.75 0.1],...
            'String','');

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.8 0.53 0.15 0.1],...
            'String','Select',...
            'Callback',@select_tractfile_callback);                 
        
        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'foregroundColor','blue',...
            'units', 'normalized',...
            'Position',[0.75 0.1 0.2 0.1],...
            'String','Load',...
            'Callback',@OK_callback);  

        uicontrol('Style','pushbutton',...
            'fontsize',12,...
            'units', 'normalized',...
            'Position',[0.5 0.1 0.2 0.1],...
            'String','Cancel',...
            'Callback','delete(gcf)');

        function select_basefile_callback(~,~)
            [name, filepath] = uigetfile({'*.nii', 'Select base file (*.nii)'});
            if isequal(name, 0)
                return;
            end         
            basefile = fullfile(filepath, name);              
            set(basefile_edit,'string',basefile);
        end
        
        
        function select_tractfile_callback(~,~)
            [name, filepath] = uigetfile({'*.nii', 'Select tractography file (*.nii)'});
            if isequal(name, 0)
                return;
            end         
            tractfile = fullfile(filepath, name);              
            set(tractfile_edit,'string',tractfile);
        end           

        function OK_callback(~,~)
            % get from text box in case user typed in
            basefile = get(basefile_edit,'string');           
            tractfile = get(tractfile_edit,'string');         
            delete(d)
        end
              
        % make modal
        uiwait(d);
    end
    

    % D. Cheyne - new import routine assuming dicm2nii can convert DICOM
    % and save in 4D NifTI image.  New version of dicom2nii should retrieve 
    % necessary paramaters. 

    function import_DTI_dataset(~,~)
        
        [dicom_folder, ds_folder, blip1_folder] = select_dicom_files;
       
        if isempty(dicom_folder) || isempty(ds_folder)
            return;
        end
        
        bvecs_file = [];
        bvals_file = [];
        original_file = []; 
        acqparams_file = [];
        index_file = [];
        
        wbh = waitbar(0,'Converting DICOM to NIfTI ...');

        waitbar(0.25,wbh);
       
        fprintf('--> converting DICOM images in %s to NIfTI format using dicm2nii ...\n', dicom_folder);
             
        dicm2nii(dicom_folder, ds_folder, 'nii');       
        
        % dicm2nii doesn't  return the .nii file name we have
        % to look in the created folder to see if it exists
        filemask = strcat(ds_folder,filesep, '*.nii');
        t = dir(filemask);   
        delete(wbh);  
        
        if isempty(t)
            beep;
            errordlg('dicm2nii failed...');
            return;
        end       
        % get the diffusion NifTI file name ...
        fname = t.name;
        original_file = fullfile(ds_folder, fname);
        
        % get num diffusion volumes
        nii = load_nii(original_file);
        num_volumes = size(nii.img,4);
        
        % get head center for bet
        dim = nii.hdr.dime.dim;
        head_center(1) = round(dim(2) / 2);
        head_center(2) = round(dim(3) / 2);
        head_center(3) = round(dim(4) / 2);
                
        set(headCenter_edit1,'string',num2str(head_center(1)));
        set(headCenter_edit2,'string',num2str(head_center(2)));
        set(headCenter_edit3,'string',num2str(head_center(3)));
        
        clear nii;
        
        fprintf('saved %d volumes in %s ... \n', num_volumes, original_file );      
        
        % now get readout time and unwarp (phase encoding) direction from matfile
        filemask = strcat(ds_folder,filesep, '*.mat');
        t = dir(filemask);
        if ~isempty(t)
            fname = t.name;
            dcmMatFile = fullfile(ds_folder, fname);        
            if ~isempty(dcmMatFile)   
                acq_params(1,:) = getAcqParams(dcmMatFile);
            else                       
                fprintf('WARNING: ** Could not get phase encoding direction and readout time from dicom Header file **');
            end       
        else
            fprintf('WARNING: ** Could not get phase encoding direction and readout time from dicom Header file **');
        end
        
        %  convert blip files in their own folder
        if ~isempty(blip1_folder)
            wbh = waitbar(0,'Converting DICOM to NIfTI ...');
            waitbar(0.25,wbh);
            fprintf('--> converting DICOM images in %s to NIfTI format using dicm2nii ...\n', blip1_folder);
            dicm2nii(blip1_folder, blip1_folder, 'nii');       
            
            delete(wbh);
            
            % get blip file names from converted directory 
            filemask = strcat(blip1_folder,filesep, '*.nii');
            t = dir(filemask);   
            if ~isempty(t)
                fname = t.name;           
            	tfile = sprintf('%s%s%s',blip1_folder, filesep, fname);
                copyfile(tfile,ds_folder);
            	blip1_file = fullfile(ds_folder, fname);
            end

            filemask = strcat(blip1_folder,filesep, '*.mat');
            t = dir(filemask);
            if ~isempty(t)
                fname = t.name;
                dcmMatFile = fullfile(blip1_folder, fname);
                if ~isempty(dcmMatFile)   
                    acq_params(2,:) = getAcqParams(dcmMatFile);
                else                       
                    fprintf('WARNING: ** Could not get phase encoding direction and readout time from dicom Header file **');
                end       
            else
                fprintf('WARNING: ** Could not get phase encoding direction and readout time from dicom Header file **');
            end
        end
        
        if ~isempty(acq_params)

            acqparams_file = fullfile(ds_folder, 'acqparams.txt');           
            fprintf('writing acquisition parameters to %s ... \n', acqparams_file );
            fp = fopen(acqparams_file, 'w');
            
            for k=1:size(acq_params,1)
                fprintf(fp, '%d  %d  %d  %0.4f\n', acq_params(k,:)) ;
            end
            fclose(fp);           
            
            index_file = fullfile(ds_folder, 'index.txt');
            fprintf('writing index file %s ... \n', index_file );
            fp = fopen(index_file, 'w');
            for j=1:num_volumes
                fprintf(fp, '1\n');
            end
            fclose(fp);
        end    
        
        
        % get the bvec and bvals files and make name compatible for
        % bedpostx
        filemask = strcat(ds_folder,filesep, '*.bvec');
        t = dir(filemask);     
        if ~isempty(t)
            fname = t.name;
            tfile = fullfile(ds_folder, fname);
            bvecs_file = fullfile(ds_folder, 'bvecs'); % required name
            if ~strcmp(tfile, bvecs_file)
                copyfile(tfile,bvecs_file);
            end
                       
            fprintf('saved b-vectors in %s ... \n', bvecs_file );
        end
        
        filemask = strcat(ds_folder,filesep, '*.bval');
        t = dir(filemask);     
        if ~isempty(t)
            fname = t.name;
            tfile = fullfile(ds_folder, fname);
            bvals_file = fullfile(ds_folder, 'bvals'); % required name
            if ~strcmp(tfile, bvals_file)
                copyfile(tfile,bvals_file);
            end
            fprintf('saved b-values in %s ... \n', bvals_file );
        end        
       
        
        % set dataset label
        
        file_str = sprintf('Dataset Files (%s)', ds_folder);
        set(Dataset_Dir,'string',file_str);
        file_str = sprintf('Diffusion File: %s', original_file);
        set(WORKSPACE_TEXT_TITLE, 'String', file_str);   
        file_str = sprintf('Diffusion File (corrected): ');
        set(WORKSPACE_TEXT_TITLE4, 'String', file_str);          
        file_str = sprintf('BVecs File: %s', bvecs_file);
        set(WORKSPACE_TEXT_TITLE2, 'String', file_str);
        file_str = sprintf('BVals File: %s', bvals_file);
        set(WORKSPACE_TEXT_TITLE3, 'String', file_str);
        
        if ~isempty(blip1_file)
            s = sprintf('B0 Files: %s', blip1_file);  
            set(WORKSPACE_TEXT_TITLE5, 'String', s);     
            set(WORKSPACE_TEXT_TITLE5, 'enable', 'on');          
        end
        
        set(WORKSPACE_TEXT_TITLE, 'enable', 'on');
        set(WORKSPACE_TEXT_TITLE2, 'enable', 'on');
        set(WORKSPACE_TEXT_TITLE3, 'enable', 'on');
        set(WORKSPACE_TEXT_TITLE4, 'enable', 'on');          
              
        % enable processing 

        display_mode = 0;
        loadData(original_file);
        
        files = {};
        files(1) = {'Original Data'};
        set(FILE_LISTBOX, 'value', 1);
        set(FILE_LISTBOX, 'String', files);

        loaded_files{1,1} = display_mode;
        loaded_files{1,2} = {original_file};
        
        oldcoords = [round(max_dim/2)-1 round(max_dim/2)-1 round(max_dim/2)-1];
        slice1_RAS = oldcoords(1);
        slice2_RAS = oldcoords(2);
        slice3_RAS = oldcoords(3);
        
        % if rest of dataset has been loaded, allow 1st step
        if ~isempty(ds_folder) && ~isempty(bvecs_file) && ~isempty(bvals_file) 
            
            set_enable_bet('on');
            set_enable_eddy('off');
            set_enable_dtifit('on');
            set_enable_bedpostx('off');
            set(BEDPOST_BUTTON, 'enable', 'off');
            set_enable_register('off');
            set_enable_mask('on');
            set_enable_probtrackx('on');

        end 
        
    end

    function params = getAcqParams(matFile)
        
        params = [];
        readout_time = [];
        pe = [];
        
        if ~isempty(matFile)   
            fprintf('Reading Phase encoding direction and readout time from %s...\n', matFile);
            mat_hdr = load(matFile);
            mat_hdr = struct2cell(mat_hdr.h);
            mat_hdr = mat_hdr{1};
            mat_fields = fieldnames(mat_hdr);
            
            mini_hdr = rmfield(mat_hdr, mat_fields(find(cellfun( @isempty, strfind( mat_fields, 'UnwarpDirection')))));
        
            if size(fieldnames(mini_hdr)) == 1
                pe_dir = mini_hdr.UnwarpDirection;
                if strcmp(pe_dir, '-y')
                    pe = [0 -1 0];
                elseif strcmp(pe_dir, 'y')
                    pe = [0 1 0];
                elseif strcmp(pe_dir, '-x')
                    pe = [-1 0 0];
                elseif strcmp(pe_dir, 'x')
                    pe = [1 0 0];
                elseif strcmp(pe_dir, '-z')
                    pe = [0 0 -1];
                elseif strcmp(pe_dir, 'z')
                    pe = [0 0 1];
                end                         
            end
            
            mini_hdr = rmfield(mat_hdr, mat_fields(find(cellfun( @isempty, strfind( mat_fields, 'ReadoutSeconds')))));
            if size(fieldnames(mini_hdr)) == 1
                readout_time = mini_hdr.ReadoutSeconds;
            end      
            
            if isempty(pe)
                beep;
                fprintf('*** Warning: failed to get phase encode directions from %s. Setting to zero ***\n', matFile);
                pe = [0 0 0];
            end
            if isempty(readout_time)
                beep;
                fprintf('*** Warning: failed to get directions from %s. Setting to zero *** \n', matFile);
                readout_time = 0.0;
            end    
            
            params = [pe readout_time];
        else
            fprintf('Could not open %s...\n', matFile);
        end
    end

    % load data file
    function load_data_file_callback(~,~)
        % display original image
        [name, filepath] = uigetfile({'*.nii', 'Select data file (*.nii)'; '*.nii', 'Select data file (*.nii)'}, 'Select Diffusion file');
        if (isequal(name, 0)) || (isequal(filepath, 0))
             return;
        end
        file = fullfile(filepath, name);
        load_data_file(file);
    end

    function load_data_file( file )
        
        original_file = file;
        
        [ds_folder,~,~] = fileparts(original_file);
        
        str = sprintf('Diffusion File: %s', original_file);
        set(WORKSPACE_TEXT_TITLE, 'string', str);
        
        str = sprintf('Dataset Files: (%s)', ds_folder);
        set(Dataset_Dir, 'string', str);
       
        display_mode = 0;
        loadData(original_file);
        
        cd(ds_folder);
        
        files = {};
        files(1) = {'Original Data'};
        set(FILE_LISTBOX, 'value', 1);
        set(FILE_LISTBOX, 'String', files);

        loaded_files{1,1} = display_mode;
        loaded_files{1,2} = {original_file};
        
        oldcoords = [round(max_dim/2)-1 round(max_dim/2)-1 round(max_dim/2)-1];
        slice1_RAS = oldcoords(1);
        slice2_RAS = oldcoords(2);
        slice3_RAS = oldcoords(3);
        
        % reset head center for BET
        % note that displayed image has been padded to isotropic but have
        % to pass BET the head center in voxels for the non-padded image.
        nii = load_nii(original_file);
        dim = nii.hdr.dime.dim;
        head_center(1) = round(dim(2) / 2);
        head_center(2) = round(dim(3) / 2);
        head_center(3) = round(dim(4) / 2);
        clear nii;
        
        set(headCenter_edit1,'string',num2str(head_center(1)));
        set(headCenter_edit2,'string',num2str(head_center(2)));
        set(headCenter_edit3,'string',num2str(head_center(3)));
        
        set(WORKSPACE_TEXT_TITLE, 'enable', 'on');
        set(WORKSPACE_TEXT_TITLE4, 'enable', 'on');
        set(load_bvecs, 'enable','on');
        set(load_bvals, 'enable','on');
        set(load_b0, 'enable','on');
        set(load_bet, 'enable','on');

        % check for other files 

        tfile = sprintf('%s%sacqparams.txt', ds_folder, filesep);        
        if exist(tfile,'file')
            acqparams_file = tfile;            
        end       
        tfile = sprintf('%s%sindex.txt', ds_folder, filesep);        
        if exist(tfile,'file')
            index_file = tfile;            
        end      
        
        tfile = sprintf('%s%sbvecs', ds_folder, filesep);        
        if exist(tfile,'file')
            bvecs_file = tfile;            
            bvec_str = sprintf('BVecs File: %s', bvecs_file);
            set(WORKSPACE_TEXT_TITLE2, 'String', bvec_str);
            set(WORKSPACE_TEXT_TITLE2, 'enable', 'on');
        end
        tfile = sprintf('%s%sbvals', ds_folder, filesep);        
        if exist(tfile,'file')
            bvals_file = tfile;            
            bval_str = sprintf('BVals File: %s', bvals_file);
            set(WORKSPACE_TEXT_TITLE3, 'String', bval_str);
            set(WORKSPACE_TEXT_TITLE3, 'enable', 'on');
        end  
             
        % check if BET was aleady run
        tfile = sprintf('%s%sunzipped%snodif_brain_overlay.nii', ds_folder,filesep,filesep);
        if exist(tfile,'file')
            bet_file = tfile;
            loadData(bet_file);
            load_bet_file;
            set_enable_bet('off');
        else
            set_enable_bet('on');
        end
        
        % if rest of dataset has been loaded, allow 1st step
        if ~isempty(ds_folder) && ~isempty(bvecs_file) && ~isempty(bvals_file)
            set_enable_eddy('off');
            set_enable_bedpostx('off');
            set(BEDPOST_BUTTON, 'enable', 'off');
            set_enable_register('off');
            set_enable_mask('on');

        end
        
        % if rest of dataset has been loaded, allow 1st step
        if ~isempty(ds_folder) && ~isempty(bvecs_file) && ~isempty(bvals_file)
            set_enable_eddy('off');
            set_enable_bedpostx('off');
            set(BEDPOST_BUTTON, 'enable', 'off');
            set_enable_register('off');
            set_enable_mask('on');

        end
        
        % check if artifact correct has been run. 
        tfile = strcat(ds_folder,filesep,'unzipped',filesep,'data.nii');
        if exist(tfile,'file')  
            s = sprintf('Load existing artifact corrected file %s?', tfile);
            r = questdlg(s,'DTI Analysis','Yes','No','Yes');
            if strcmp(r,'Yes')
                load_corrected_file(tfile);
            end
        end
      
        % check if artifact correct has been run. 
        tdir = strcat(ds_folder,'.bedpostX');
        if exist(tdir,'dir')  
            s = sprintf('Load existing Bedpost folder %s?', tdir);
            r = questdlg(s,'DTI Analysis','Yes','No','Yes');
            if strcmp(r,'Yes')
                bedpostx_dir = tdir;
                % set steps to after bedpostX
                set_enable_bet('off');
                set_enable_eddy('off');
                set_enable_bedpostx('off');
                set_enable_register('on');
                set_enable_mask('on');
                set(BEDPOST_BUTTON, 'enable', 'off');
                set(RUN_ALL_BUTTON, 'enable', 'off');      

                set(BEDPOST_FOLDER_TXT, 'string',bedpostx_dir);
            end
        end
        
    end

    % load bvecs file
    function load_bvecs_file(~, ~)
    
        if isempty(ds_folder)
          fprintf('Must select dataset folder\n');
          return;
        end
      
        % user selects bvecs files 
        [name, filepath] = uigetfile({'*.*', 'Select Bvecs file (*.*)'}, 'Could not find Bvecs file: Select Bvecs file');
        if (isequal(name, 0)) || (isequal(filepath, 0)) 
            return;
        end
        if ~strcmp(filepath(1:end-1), ds_folder)
            fprintf('Bvecs file must be in subject dataset folder\n');
            return;
        end
        bvecs_file = fullfile(filepath, name);
        
        bvec_str = sprintf('BVecs File: %s', bvecs_file);
        set(WORKSPACE_TEXT_TITLE2, 'String', bvec_str);
        set(WORKSPACE_TEXT_TITLE2, 'enable', 'on');
      
        % if rest of dataset has been loaded, allow 1st step
        if ~isempty(ds_folder) && ~isempty(original_file) && ~isempty(bvals_file)
            set_enable_bet('on');
            set_enable_eddy('off');
            set_enable_bedpostx('off');      
        end
    end
  
    % load bvals file
    function load_bvals_file(~,~)
  
        if isempty(ds_folder)
          fprintf('Must select dataset folder\n');
          return;
        end
      
        % user selects bvals files 
        [name, filepath] = uigetfile({'*.*', 'Select Bvals file (*.*)'}, 'Could not find Bvals file: Select Bvals file');
        if (isequal(name, 0)) || (isequal(filepath, 0))
            return;
        end
         if ~strcmp(filepath(1:end-1), ds_folder)
            fprintf('Bvals file must be in subject dataset folder\n');
            return;
        end
        bvals_file = fullfile(filepath, name);
        
        bval_str = sprintf('BVals File: %s', bvals_file);
        set(WORKSPACE_TEXT_TITLE3, 'String', bval_str);
        set(WORKSPACE_TEXT_TITLE3, 'enable', 'on');
        
         % if rest of dataset has been loaded, allow 1st step
        if ~isempty(ds_folder) && ~isempty(original_file) && ~isempty(bvecs_file)
            set_enable_bet('on');
            set_enable_eddy('off');
            set_enable_bedpostx('off');
           
        end
    end
  
    % load bvals file
    function load_b0_file(~,~)
  
        if isempty(ds_folder)
          fprintf('Must select dataset folder\n');
          return;
        end
      
        % user selects bvals files 
        [name, filepath] = uigetfile({'*.*', 'Select B0 file (*.*)'}, 'Could not find Bvals file: Select Bvals file');
        if (isequal(name, 0)) || (isequal(filepath, 0))
            return;
        end
        if ~strcmp(filepath(1:end-1), ds_folder)
            fprintf('B0 file must be in subject dataset folder\n');
            return;
        end
        blip1_file = fullfile(filepath, name);
        
        bval_str = sprintf('B0 File: %s', blip1_file);
        set(WORKSPACE_TEXT_TITLE5, 'String', bval_str);
        set(WORKSPACE_TEXT_TITLE5, 'enable', 'on');
        
         % if rest of dataset has been loaded, allow 1st step
        if ~isempty(ds_folder) && ~isempty(original_file) && ~isempty(bvecs_file) 
            set_enable_bet('on');
            set_enable_eddy('off');
            set_enable_bedpostx('off');
           
        end
    end

    % load artifact corrected file
    function load_corrected_file_callback(~,~)
        
        defpath = sprintf('%s%sunzipped%sdata.nii',ds_folder,filesep,filesep);
        [name, filepath] = uigetfile({'*.nii', 'Select data file (*.nii)'}, 'Select Corrected Diffusion file',defpath);
        if (isequal(name, 0)) || (isequal(filepath, 0))
             return;
        end
        
        file = fullfile(filepath,name);
        
        load_corrected_file(file);
    end

    function load_corrected_file(file)
            
        corrected_file = file;
                
        str = sprintf('Diffusion File (corrected): %s', corrected_file);
        set(WORKSPACE_TEXT_TITLE4, 'string', str);
        set(WORKSPACE_TEXT_TITLE4, 'enable', 'on');
        
        % display corrected images
        
        display_mode = 0;
        loadData(corrected_file);
        
        l = size(files,2);
        files(l+1) = {'Eddy Corrected Data'};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        
        loaded_files{size(loaded_files,1)+1,1} = display_mode;
        loaded_files{size(loaded_files,1),2} = {corrected_file};
        
        set_enable_eddy('off');
        set_enable_bedpostx('on');
        set_enable_mask('on');  
        
        % if file setup OK enable bedpost button
        bedpostx_ready = verify_datasest;
        if bedpostx_ready
            set(BEDPOST_BUTTON,'enable','on');
            set(SELECT_BEDPOST_BUTTON,'enable', 'on');
        end
        
    end

    % load bet overlay file
    function load_bet_callback(~,~)
        [name, filepath] = uigetfile({'*.nii', 'Select data file (*.nii)'}, 'Select nodif BET overlay file');
        if (isequal(name, 0)) || (isequal(filepath, 0))
             return;
        end
        bet_file = fullfile(filepath, name);     
        load_bet_file;
        
    end

    % load bet overlay file
    function load_bet_file
        
        if isempty(bet_file)
            return;
        end
        
        % display corrected images
        fprintf('Loading BET outline..\n');
        
        display_mode = 1;
        
        loadData(bet_file);

        l = size(files,2);
        files(l+1) = {'BET'};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        
        loaded_files{size(loaded_files,1)+1,1} = display_mode;
        loaded_files{size(loaded_files,1),2} = {bet_file};

        
    end

    % return unzipped nifti file
    function file = getUnzipped(orig_file)

        % check file exists
        if ~exist(orig_file, 'file')
            fprintf('Attempt to open file that does not exist %s\n', orig_file);
            return;
        end
        
        [fpath, ~, fext] = fileparts(orig_file);
        
        if strcmp(fext, '.gz')
            
            % unzip in zipped path if no dataset selected
            if isempty(ds_folder)
                file = char(gunzip(orig_file, fpath));

            % unzip in unzip folder if dataset selected (avoid duplicate
            % issues)
            else
                if isempty(unzip_folder)
                    unzip_folder = fullfile(ds_folder,'unzipped');
                end
                if ~exist(unzip_folder, 'dir')
                    status = mkdir(unzip_folder);
                    if ~status
                        fprintf('Failed to make %s directory for unzipped files\n', unzip_folder);
                        return;
                    end
                end

                file = char(gunzip(orig_file, unzip_folder));
            end
            
        else
            file = orig_file;
        end
        
    end

    % load a nifti file into viewer
    function load_volume_callback(~,~)

        [name, filepath] = uigetfile({'*.nii', 'Select file (*.nii)';'*.nii.gz', 'Select file (*.nii.gz)'}, 'Select file');
        if (isequal(name, 0)) || (isequal(filepath, 0))
             return;
        end
        
        file = fullfile(filepath, name);
        file = getUnzipped(file);
        [~, n, ~] = fileparts(file);

        display_mode = 0;
        loadData(file);
        
        l = size(files,2);
        files(l+1) = {n};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        
        loaded_files{size(loaded_files,1)+1,1} = display_mode;
        loaded_files{size(loaded_files,1),2} = {file};
        
        oldcoords = [round(max_dim/2)-1 round(max_dim/2)-1 round(max_dim/2)-1];
        slice1_RAS = oldcoords(1);
        slice2_RAS = oldcoords(2);
        slice3_RAS = oldcoords(3);
        
    end

   % load bedpostx folder
    function load_bedpostx_folder(~, ~)
         
        % select dataset folder
        bedpostx_dir = uigetdir('', 'Select Subject''s BedpostX folder');
        if bedpostx_dir == 0
            return;
        end
        [p, n] = fileparts( bedpostx_dir );
        
        ds_folder = fullfile(p, n);
        ds_str = sprintf('Dataset Files (%s)', p);
        set(Dataset_Dir, 'String', ds_str);      
                
        % set steps to after bedpostX
        set_enable_bet('off');
        set_enable_eddy('off');
        set_enable_bedpostx('off');
        set_enable_register('on');
        set_enable_mask('on');
        set(BEDPOST_BUTTON, 'enable', 'off');
        set(RUN_ALL_BUTTON, 'enable', 'off');      
        
        set(BEDPOST_FOLDER_TXT, 'string',bedpostx_dir);

    end

    % function for user to make acquisition params file
    function result = make_acqparams
        
        % load if acquisition parameter file already made (import DICOM)
        if ~isempty(acqparams_file)
            data = load(acqparams_file);
            if size(data, 2)~=4
                fprintf('Cannot load acqparams.txt: file must have 4 columns (PE x, y, z, and readout time)\n');
                return;
            end
            
        % load default values
        else
            data = [0 0 0 1.00; 0 0 0 1.00];
            acqparams_file = fullfile(ds_folder, 'acqparams.txt');
        end
        
        fig2=figure('Name', 'Aquisition Parameters', 'Position', [(scrsz(3)-500)/2 (scrsz(4)-80)/2 500 80],...
            'menubar','none','numbertitle','off', 'Color','white',...
            'WindowButtonUpFcn',@buttondown, 'CloseRequestFcn', @acq_close);
        
        t = uitable(fig2, 'Data', data, 'Position', [0 0 500 80], 'ColumnName', {'x', 'y', 'z', 'Readout time (s)'}, 'ColumnEditable', true(1,4));
        uicontrol('Style','PushButton','Units','Normalized','Position', [0.75 0.1 0.2 0.4],'callback', @save_callback, ...
            'HorizontalAlignment','Center','BackGroundColor',...
            'white', 'FontSize', 11, 'ForegroundColor','green', 'String', 'SAVE'); 
        uicontrol('Style','PushButton','Units','Normalized','Position', [0.75 0.55 0.2 0.4],'callback', @load_callback, ...
            'HorizontalAlignment','Center','BackGroundColor',...
            'white', 'FontSize', 11, 'ForegroundColor','blue', 'String', 'LOAD');
        
        % load selected acquisition parameters file into table
        function load_callback(~,~)
            [filename, filepath] = uigetfile({'*.txt', 'Acquisition Parameters File (*.txt)'; '*.txt', 'Acquisition Parameters File (*.txt)'}, 'Select Acquisition Parameters File');
            if isequal(filename, 0) || isequal(filepath,0)
                delete(wbh);
                return;
            end
            file = fullfile(filepath, filename);
            acqp = load(file);
            
            if size(acqp, 2)~=4
                fprintf('Acquisition Parameters File must have 4 columns (PE x, y, z, and readout time)\n');
                return;
            end
            
            set(t, 'Data', acqp);
        end
        
        % save current table as acquisition parameters file
        function save_callback(~,~)
            
            data = get(t, 'Data');
            if all(data(1,1:3) == 0)
                fprintf('Must set at least one phase-encoding direction\n');
                return;
            end
            
            file = fopen(acqparams_file, 'w');
            for i=1:size(data, 1)
                if data(i, 1:3) == [0 0 0]
                    break;
                end
                for j=1:size(data, 2)
                    fprintf(file, '%g ', data(i, j));
                end
                fprintf(file, '\n');
            end
            fclose(file);
            result = 1;
            uiresume(gcf);
            delete(fig2);
        end

        % if close before saving, indicate that was unsuccessful
        function acq_close(~,~)
            result = 0;
            uiresume(gcf);
            delete(fig2);
        end
      
        uiwait(gcf);
    end

    % function for user to make index file
    function result = make_index
       
        % get total number of volumes in diffusion data
        bvals = load(bvals_file);
        num_vol = size(bvals,2);
            
        % load index file if already exists (imported DICOM)
        if ~isempty(index_file)
            data=load(index_file);
            data = data';
            
        % load default values
        else
            data = ones(num_vol,1)';
            index_file = fullfile(ds_folder, 'index.txt');
        end
        
        fig2=figure('Name', 'Index File', 'Position', [(scrsz(3)-600)/2 (scrsz(4)-150)/2 600 150],...
            'menubar','none','numbertitle','off', 'Color','white',...
            'WindowButtonUpFcn',@buttondown, 'CloseRequestFcn', @index_close);
        aqp_data = load(acqparams_file);
        uitable(fig2, 'Data', aqp_data, 'Position', [0 90 400 60], 'ColumnName', {'x', 'y', 'z', 'Readout time (s)'}, 'RowName', {'index 1', 'index 2'});
        uicontrol('Style','PushButton','Units','Normalized','Position', [0.75 0.51 0.2 0.2],'callback', @save_callback, ...
            'HorizontalAlignment','Center','BackGroundColor',...
            'white', 'FontSize', 11, 'ForegroundColor','green', 'String', 'SAVE'); 
        uicontrol('Style','PushButton','Units','Normalized','Position', [0.75 0.73 0.2 0.2],'callback', @load_callback, ...
            'HorizontalAlignment','Center','BackGroundColor',...
            'white', 'FontSize', 11, 'ForegroundColor','blue', 'String', 'LOAD');
        
        t = uitable(fig2, 'Data', data, 'Position', [0 0 600 60], 'ColumnName', 0:num_vol-1, 'ColumnEditable', true(1,num_vol), 'RowName', 'index');
        uicontrol('style','text','units','normalized','position',[0.01 0.4 0.4 0.1],'enable', 'off',...
        'String','DW Volumes','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
        
        % load previously created index file into table
        function load_callback(~,~)
            [filename, filepath] = uigetfile({'*.txt', 'Index File (*.txt)'; '*.txt', 'Index File (*.txt)'}, 'Select Index File');
            if isequal(filename, 0) || isequal(filepath,0)
                delete(wbh);
                return;
            end
            file = fullfile(filepath, filename);
            idx = load(file);
            idx = idx';
            
            % index file must have same number columns as there are volumes
            if size(idx, 2)~=num_vol
                fprintf('Index File must have as many columns as there are volumes (%d)\n', num_vol);
                return;
            end
            
            set(t, 'Data', idx);
        end
        
        % save table as index file
        function save_callback(~,~)
            
            data = get(t, 'Data');
            
            file = fopen(index_file, 'w');
            for i=1:size(data, 2)
                fprintf(file, '%g\n', data(i));
            end
            fclose(file);
            result = 1;
            uiresume(gcf);
            delete(fig2);
        end
        
        % if close before saving, indicate unsuccessful
        function index_close(~,~)
            result = 0;
            uiresume(gcf);
            delete(fig2);
        end

        uiwait(gcf);
        
    end

% ============================ end import data files ============================== %

% ====================== Pre-Processing Functions ======================= %

    % run FSL's bet
    function bet_callback(~,~)

        wbh = waitbar(0,'Running FSL brain extraction ...');

        waitbar(0.25,wbh);
        
        % grab b0 volume from original data
        b0_file_prefix = char(fullfile(ds_folder, 'nodif'));
        command = sprintf('%s %s %s %g 1', fullfile(fsldir, 'bin', 'fslroi'), original_file, b0_file_prefix, b0_vol_num);
        b0_volume_file = strcat(b0_file_prefix, '.nii.gz'); 
        fprintf('Running FSL version %g fslroi to extract b=0 volume...\n%s\n', FSLVer, command);
        
        % call fslroi to extract b0
        [status, ~] = system(command, '-echo');
        if status ~= 0
            fprintf('Error executing %s/bin/fslroi\n', fsldir);
            delete(wbh);
            return;
        end

        if ~exist(b0_volume_file, 'file')
            fprintf('%s was not created\n', b0_volume_file);
            delete(wbh);
            return;
        end
        
        waitbar(0.5,wbh);
            
        head_center(1) = round(str2double(get(headCenter_edit1,'string')));
        head_center(2) = round(str2double(get(headCenter_edit2,'string')));
        head_center(3) = round(str2double(get(headCenter_edit3,'string')));
        command = sprintf('%s %s %s -c %d %d %d -m -o -s', fullfile(fsldir, 'bin', 'bet'), b0_volume_file, char(fullfile(ds_folder,bet_file_prefix)), head_center);      
               
        % if f-value is not default (0.5), include in bet call
        if ( fvalue ~= 0.5 )
            str = sprintf(' -f %3.2f', fvalue);
            command = strcat(command, str);
        end
        
        fprintf('Running FSL version %g brain extraction ...\n%s\n', FSLVer, command);
        if use_fid
            fprintf('Initializing with head origin (%g %g %g cm) = (RAS voxels %d %d %d)...\n', headCenter, origin);
        end
        
        % call bet on b0 volume
        [status, ~] = system(command, '-echo');
        if status ~= 0
            fprintf('Error executing %s/bin/bet\n', fsldir);
            delete(wbh);
            return;
        end

        waitbar(1,wbh);

        delete(wbh);
        
        fprintf('Loading BET outline..\n');
        
        % show brain outline (in yellow)
        zipped_file = char(fullfile(ds_folder, strcat(bet_file_prefix,'_overlay.nii.gz')));
        file = getUnzipped(zipped_file);

        bet_file = char(file);
        load_bet_file;
        
        % set up next step (Artifact Correction)
        set_enable_eddy('on');
        set_enable_bedpostx('on');
        set(BEDPOST_BUTTON,'enable','on');
        set(RUN_ALL_BUTTON,'enable','on');        
        
        set(VOLUME_EDIT, 'String', '0');
        set(LOOP_BUTTON, 'enable', 'off');       
    end

    % artifact correction
    function eddy_correct_callback(~,~)

        % if not generated during import need to create these files..
        if isempty(acqparams_file)  
            result = make_acqparams;
            if ~result
              return;
            end
        end
        if isempty(index_file)
            result = make_index;
            if ~result
                return;
            end
        end
        
        r = questdlg('Run Eddy Correction? (this will take a few hours)','DTI Analysis', 'Yes','No','No');
        if strcmp(r,'No')
            return;
        end
        
        run_eddy_correct;
    end

    function run_eddy_correct
            
        wbh = waitbar(0,'Running FSL artifact correction ...');

        waitbar(0.25,wbh); 
        
        % TOPUP (integrated into eddy correction as of 6.0)
        if topup_opt && FSLVer >= 6.0
            r = run_topup;
            waitbar(0.5,wbh);
            if ~r
                delete(wbh);
                return;
            end
        end
        
        % EDDY correction
        r = run_eddy;
        if ~r
            delete(wbh);
            return;
        end
        waitbar(0.75,wbh);   

        % get corrected diffusion data 
        % - unzipped file cannot be in same directory as zipped for bedpostx...
        
        zipped_file = char(fullfile(ds_folder, strcat(corr_file_prefix,'.nii.gz')));
        file = getUnzipped(zipped_file);
        if ~exist(file, 'file')
            s = sprintf('Could not find file %s', file);
            errordlg(s)
            delete(wbh);
            return;
        end
                              
        corrected_file = char(file);                                     
        waitbar(1,wbh);  
        
        delete(wbh);
        
        % display corrected images
        display_mode = 0;
        loadData(corrected_file);
        
        l = size(files,2);
        files(l+1) = {'Eddy Corrected Data'};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        
        loaded_files{size(loaded_files,1)+1,1} = display_mode;
        loaded_files{size(loaded_files,1),2} = {corrected_file};
        
        set_enable_eddy('off');
        set_enable_bedpostx('on');
        set_enable_mask('on');
                
        % if file setup OK enable bedpost button
        bedpostx_ready = verify_datasest;
        if bedpostx_ready
            set(BEDPOST_BUTTON,'enable','on');
        end
             
    end

    % run FSL's topup
    function result = run_topup
        
        result = 1;
        
        if isempty(blip1_file)
            % select set of b=0 images with different PE directions
            select_str = sprintf('Select b0 image(s) with different phase-encoding directions than nodif (vol %g)', b0_vol_num);
            [b0_names, b0_paths] = uigetfile({'*.nii', 'Select b0 image(s) (*.nii)'}, select_str);
            if isequal(b0_names,0) || isequal(b0_paths, 0)
                result = 0;
                return;
            end
        else
            b0_paths = ds_folder;
            if ~isempty(blip1_file)
                [b0_paths,n,e] = fileparts(blip1_file);
                b0_names{1} = [n e];
            end 
        end
     
        % select configuration document
        % look for default else prompt.
        cur_folder = pwd;
        default = fullfile(fsldir, 'etc', 'flirtsch');
        config_file = fullfile(default,'b02b0.cnf');
        if ~exist(config_file,'file')
            cd(default);
            [config_name, config_path] = uigetfile({'b02b0.cnf', 'Default ASCII Configuration File (*.cnf)'; '*.cnf', 'ASCII Configuration File (*.cnf)'}, 'Select ASCII Configuration File (topup parameters)');
            if isequal(config_name,0) || isequal(config_path, 0)
                result = 0;
                return;
            end
            config_file = fullfile(config_path, config_name);
            cd(cur_folder);
        end
        
        % merge b=0 images using fslmerge
        input_files = fullfile(ds_folder, 'nodif');
        if isequal(class(b0_names), 'cell')
            for i=1:size(b0_names, 2)
                input_files = sprintf('%s %s', input_files, fullfile(b0_paths, char(b0_names(i))));
            end
        else
            input_files = sprintf('%s %s', input_files, fullfile(b0_paths, b0_names));
        end

        imain_file = fullfile(ds_folder, b0_images_name);
        command = sprintf('%s -t %s %s', fullfile(fsldir, 'bin', 'fslmerge'), imain_file, input_files);
        fprintf('Running FSL version %g fslmerge...\n%s\n', FSLVer, command);

        tic
        
        [status, ~] = system(command, '-echo');
        if status ~= 0
            fprintf('Error executing %s/bin/fslmerge\n', fsldir);
            result = 0;
            return;
        end

        % run topup from command line 
        command = sprintf('%s --imain=%s --datain=%s --config=%s --out=%s --iout=%s --fout=%s',...
            fullfile(fsldir, 'bin', 'topup'), imain_file, acqparams_file, config_file, fullfile(ds_folder, topup_prefix), fullfile(ds_folder, strcat(topup_prefix, '_iout')), fullfile(ds_folder, strcat(topup_prefix, '_fout')));
        fprintf('Running FSL version %g topup (susceptibility-induced field correction) ...\n%s\n', FSLVer, command);

        [status, result] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/topup\n', fsldir);
             result = 0;
            return;
        end

        toc
    end

    % run FSL's eddy_correct or eddy
    function result = run_eddy
        
        result = 1;        

        tic
        % include topup output name if topup was run (adds
        % susceptibility artifact correction)
        if topup_opt
            command = sprintf('%s --imain=%s --mask=%s --acqp=%s --index=%s --bvecs=%s --bvals=%s --topup=%s --out=%s',...
                fullfile(fsldir, 'bin', 'eddy'), original_file, char(fullfile(ds_folder, strcat(bet_file_prefix, '_mask.nii'))), acqparams_file, index_file, bvecs_file, bvals_file, fullfile(ds_folder, topup_prefix), fullfile(ds_folder, corr_file_prefix));
        else
            command = sprintf('%s --imain=%s --mask=%s --acqp=%s --index=%s --bvecs=%s --bvals=%s --out=%s',...
                fullfile(fsldir, 'bin', 'eddy'), original_file, char(fullfile(ds_folder, strcat(bet_file_prefix, '_mask.nii'))), acqparams_file, index_file, bvecs_file, bvals_file, fullfile(ds_folder, corr_file_prefix));
        end

        % skip checking if data is shelled
        if ~shell_check_opt
            command = strcat(command, ' --data_is_shelled');
        end
        if slm_linear
            command = strcat(command, ' --slm=linear'); 
        end

        fprintf('Running FSL version %g eddy correction ...\n%s\n', FSLVer, command);

        [status, result] = system(command, '-echo');          
        if status ~= 0
            fprintf('Error executing %s/bin/eddy\n', fsldir);
            result = 0;
            return;
        end
                   
        toc
        
    end



% ============================ Set controls ============================== %


    function set_enable_register(instr)
        set(select_std_ref, 'enable', instr);
        set(select_std_label, 'enable', instr);
        set(select_std_txt, 'enable', instr);
        set(select_mri_txt, 'enable', instr);        
        set(select_mri_label, 'enable', instr);
        set(select_mri_ref, 'enable', instr);
    end

annotation('textarrow', [0.09 0.09], [0.69 0.66], 'Color', 'blue');
annotation('textarrow', [0.09 0.09], [0.6 0.58], 'Color', 'blue');
annotation('textarrow', [0.09 0.09], [0.52 0.48], 'Color', 'blue');

% back button
% BACK_BUTTON=uicontrol('Style','PushButton','Units','Normalized','Position', [0.4 0.33 0.08 0.04],'callback', @back_callback, ...
%         'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor','red', 'String', 'BACK', 'enable', 'off');   
% 
% =========================== Analysis Section ============================== %

uicontrol('style','text','units','normalized','position',[0.04 0.38 0.08 0.02],...
        'String','Analysis','ForegroundColor','blue','FontSize', 11,...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');
annotation('rectangle','position',[0.03 0.03 0.45 0.36],'edgecolor','blue');


% DTIFIT
DTIFIT_BUTTON=uicontrol('Style','PushButton','Units','Normalized','Position', [0.05 0.18 0.08 0.04],'callback', @dtifit_callback, ...
        'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor',button_text, 'String', 'DTI Fit', 'enable', 'off');  
dti_folder_text = uicontrol('style','text','units','normalized','position',[0.15 0.19 0.08 0.02],'enable', 'off',...
        'String','DTI Output Dir:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white');
dti_folder_edit = uicontrol('style','edit','units','normalized','position',[0.2 0.19 0.08 0.03],'String', dti_folder_name,...
        'FontSize', 11, 'BackGroundColor','white', 'enable', 'off','HorizontalAlignment','left', 'callback',@dtiFolder_edit_callback);
    function dtiFolder_edit_callback(src,~)
        dti_folder_name = get(src, 'String');
        dti_file_prefix = dti_folder_name;
    end    
    
    function set_enable_dtifit(instr)
        set(DTIFIT_BUTTON, 'enable', instr);
        set(dti_folder_text, 'enable', instr);
        set(dti_folder_edit, 'enable', instr);
    end
    
% Mask Creation


LOAD_MASK_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.76 0.17 0.05 0.04],'callback', @load_mask_callback, ...
        'HorizontalAlignment','Center', 'FontSize', 11, 'ForegroundColor','blue', 'String', 'Load Mask');
    
SAVE_MASK_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.76 0.22 0.05 0.04],'callback', @save_mask_callback, ...
        'HorizontalAlignment','Center', 'FontSize', 11, 'ForegroundColor','blue', 'String', 'Save Mask', 'enable', 'off');
mask_name_text = uicontrol('style','text','units','normalized','position',[0.82 0.235 0.08 0.02],...
        'String','Mask Name:','FontSize', 11,'HorizontalAlignment','left','BackGroundColor', 'white', 'enable', 'off');
mask_name_edit = uicontrol('style','edit','units','normalized','position',...
        [0.86 0.23 0.08 0.03],'String', mask_name,'FontSize', 11, 'BackGroundColor','white', 'enable', 'off',...
        'callback',@mask_edit_callback);
    function mask_edit_callback(src,~)
        mask_name = get(src, 'String');
    end

% 1) drawing
CREATE_MASK_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.82 0.19 0.04 0.02],'callback', @create_mask_callback, ...
        'HorizontalAlignment','Center', 'FontSize', 10, 'ForegroundColor','blue', 'String', 'Draw', 'enable', 'off');

marker_bg = uibuttongroup( 'Position', [0.867 0.17 0.035 0.04], 'SelectionChangeFcn', @bselection, 'BorderType', 'none');
marker_toggle = uicontrol(marker_bg, 'Style','togglebutton','units','normalized','fontname','lucinda','Position',...
    [0 0.5 1 0.5],'String','Marker','HorizontalAlignment','left','FontSize', 10,...
    'BackgroundColor',light_blue,'ForegroundColor','Black', 'enable', 'off');
eraser_toggle = uicontrol(marker_bg, 'Style','togglebutton','units','normalized','fontname','lucinda','Position',...
    [0 0 1 0.5],'String','Eraser','HorizontalAlignment','left','FontSize', 10,...
    'BackgroundColor','White','ForegroundColor','Black', 'enable', 'off');
marker_bg.Visible = 'on';
    function bselection(~, evt)
        set(evt.NewValue, 'backgroundColor', light_blue);
        set(evt.OldValue, 'backgroundColor', 'white');
        if evt.NewValue==marker_toggle
            marker = 1;
        else
            marker = 0;
        end
    end

markersize_bg = uibuttongroup('Position', [0.91 0.145 0.05 0.07], 'SelectionChangeFcn', @markersize_bselection, 'BorderType', 'none');
LARGE_MARKER = uicontrol(markersize_bg, 'Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
[0 0.66 1 0.33],'String','5x5 voxels','HorizontalAlignment','left','value', 1,'FontSize', 10, ...
'BackgroundColor','White','ForegroundColor','Black', 'enable', 'off');
MED_MARKER = uicontrol(markersize_bg, 'Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
[0 0.33 1 0.33],'String','3x3 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10,...
'BackgroundColor','White','ForegroundColor','Black', 'enable', 'off');
SMALL_MARKER = uicontrol(markersize_bg, 'Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
[0 0 1 0.33],'String','1x1 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10,...
'BackgroundColor','White','ForegroundColor','Black', 'enable', 'off');
markersize_bg.Visible = 'on';
    function markersize_bselection(~, evt)
        if evt.NewValue==LARGE_MARKER
            markersize = 2;
        elseif evt.NewValue==MED_MARKER
            markersize = 1;
        else
            markersize = 0;
        end
    end

UNDO_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.82 0.16 0.04 0.02], 'callback', @undo_callback, ...
    'HorizontalAlignment','Center','FontSize', 10, 'ForegroundColor', 'red', 'String', 'UNDO', 'enable', 'off');
CLEAR_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.82 0.13 0.04 0.02], 'callback', @clear_callback, ...
    'HorizontalAlignment','Center','FontSize', 10, 'ForegroundColor', 'red', 'String', 'CLEAR', 'enable', 'off');
 

    function set_enable_mask(instr)
        set(mask_name_text, 'enable', instr);
        set(mask_name_edit, 'enable', instr);
        set(CREATE_MASK_BUTTON, 'enable', instr);
        set(UNDO_BUTTON, 'enable', instr);
        set(CLEAR_BUTTON, 'enable', instr);
        set(LARGE_MARKER, 'enable', instr);
        set(MED_MARKER, 'enable', instr);
        set(SMALL_MARKER, 'enable', instr);
        set(marker_toggle, 'enable', instr);
        set(eraser_toggle, 'enable', instr);
    end

% Probabilistic tractography
PROBTRACKX_BUTTON = uicontrol('Style','PushButton','Units','Normalized','Position', [0.05 0.1 0.08 0.04],'callback', @probtrackx_callback, ...
        'HorizontalAlignment','Center', 'FontSize', 11, 'ForegroundColor','blue', 'String', 'ProbtrackX', 'enable', 'off');
probtrackx_output_text = uicontrol('Style','Text','units','normalized','fontname','lucinda','Position',...
    [0.15 0.105 0.08 0.02],'String','ProbtrackX Folder: ','HorizontalAlignment','left','FontSize', 11,...
    'BackgroundColor','White','ForegroundColor','Black', 'enable', 'off');
probtrackx_output_edit = uicontrol('Style', 'edit','units','normalized','fontname','lucinda','enable', 'off', 'Position', ...
    [0.21 0.1 0.14 0.03],'String',prob_folder,'HorizontalAlignment','left','FontSize', 11,...
    'BackgroundColor','White','ForegroundColor','Black', 'callback', @prob_output_edit_callback);
    function prob_output_edit_callback(src,~)
        prob_folder = get(src,'string');
    end

    function set_enable_probtrackx(instr)
        set(PROBTRACKX_BUTTON, 'enable', instr);
        set(probtrackx_output_text, 'enable', instr);
        set(probtrackx_output_edit, 'enable', instr);
    end

% ========================= Viewer section ============================== %

subplot('Position', axi_subplot); imagesc(zeros(256, 256)); axis off;
subplot('Position', cor_subplot); imagesc(zeros(256, 256)); axis off;
subplot('Position', sag_subplot); imagesc(zeros(256, 256)); axis off;

uicontrol('style','text','units','normalized','position',[0.52 0.95 0.05 0.02],...
        'String','Viewer','ForegroundColor','blue','FontSize', 11,...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');
annotation('rectangle','position',[0.51 0.03 0.46 0.93],'edgecolor','blue');

SAGITTAL_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.80 0.50 0.09 0.02],'min',1,'max',(slice_dim(1)),...
    'Value',slice1_RAS+1, 'sliderStep', [1 1]/(slice_dim(1)-1),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@sagittal_slider_Callback);
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.76 0.53 0.02 0.02],'String','A','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.92 0.53 0.02 0.02],'String','P','HorizontalAlignment','right',...
    'BackgroundColor','White','ForegroundColor','red');
slice1_str = sprintf('Slice %d/%d', slice1_RAS, slice_dim(1)-1);
SLICE1_EDIT = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.82 0.53 0.10 0.02],'String', slice1_str,'HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');
uicontrol('style','text','units','normalized','position',[0.77 0.50 0.02 0.02],...
    'string','Left','fontsize',10,'background','white');
uicontrol('style','text','units','normalized','position',[0.90 0.50 0.03 0.02],...
    'string','Right','fontsize',10,'background','white');
    function sagittal_slider_Callback(src,~)
        slice1_RAS = round(get(src,'Value'))-1;
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        oldcoords(1)= slice1_RAS;
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        updateCrosshairs(oldcoords(1),oldcoords(2),oldcoords(3));
    end

uicontrol('style','pushbutton','units','normalized','position',[0.9 0.53 0.03 0.02],...
    'string','Zoom','fontsize',10,'background','white','callback',@zoomSagittalCallback);
    
CORONAL_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.585 0.50 0.09 0.02],'min',1,'max',(slice_dim(2)),...
    'Value',slice_dim(2)-slice2_RAS, 'sliderStep', [1 1]/(slice_dim(2)-1),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@coronal_slider_Callback);
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.54 0.53 0.02 0.02],'String','L','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.7 0.53 0.02 0.02],'String','R','HorizontalAlignment','right',...
    'BackgroundColor','White','ForegroundColor','red');
slice2_str = sprintf('Slice %d/%d', slice2_RAS, slice_dim(2)-1);
SLICE2_EDIT = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.60 0.53 0.10 0.02],'String', slice2_str,'HorizontalAlignment','left',...
    'BackgroundColor','White', 'enable','off');
uicontrol('style','text','units','normalized','position',[0.54 0.50 0.04 0.02],...
    'string','Anterior','fontsize',10,'background','white');

uicontrol('style','text','units','normalized','position',[0.68 0.50 0.04 0.02],...
    'string','Posterior','fontsize',10,'background','white');
    function coronal_slider_Callback(src,~)
        slice2_RAS = slice_dim(2)-round(get(src,'Value'));
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        oldcoords(2)= slice2_RAS;
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        updateCrosshairs(oldcoords(1),oldcoords(2),oldcoords(3));
    end

uicontrol('style','pushbutton','units','normalized','position',[0.68 0.53 0.03 0.02],...
    'string','Zoom','fontsize',10,'background','white','callback',@zoomCoronalCallback);

AXIS_SLIDER = uicontrol('style','slider','units', 'normalized',...
    'position',[0.585 0.06 0.09 0.02],'min',1,'max',(slice_dim(3)),...
    'Value',slice_dim(3)-slice3_RAS, 'sliderStep', [1 1]/(slice_dim(3)-1),'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@axis_slider_Callback);
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.54 0.09 0.02 0.02],'String','L','HorizontalAlignment','left',...
    'BackgroundColor','White','ForegroundColor','red');
uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
    [0.7 0.09 0.02 0.02],'String','R','HorizontalAlignment','right',...
    'BackgroundColor','White','ForegroundColor','red');
slice3_str = sprintf('Slice %d/%d', slice3_RAS, slice_dim(3)-1);
SLICE3_EDIT = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
        [0.60 0.09 0.10 0.02],'String', slice3_str,'HorizontalAlignment','left',...
        'BackgroundColor','White', 'enable','off');
uicontrol('style','text','units','normalized','position',[0.54 0.06 0.04 0.02],...
    'string','Superior','fontsize',10,'background','white');
uicontrol('style','text','units','normalized','position',[0.68 0.06 0.04 0.02],...
    'string','Inferior','fontsize',10,'background','white');
    function axis_slider_Callback(src,~)
        slice3_RAS = slice_dim(3)-round(get(src,'Value'));
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT, 'String', sliceStr3, 'enable', 'on');
        oldcoords(3)= slice3_RAS;
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        updateCrosshairs(oldcoords(1),oldcoords(2),oldcoords(3));
    end

uicontrol('style','pushbutton','units','normalized','position',[0.68 0.09 0.03 0.02],...
    'string','Zoom','fontsize',10,'background','white','callback',@zoomAxialCallback);

uicontrol('style','text','units','normalized','position',[0.75 0.45 0.06 0.02],...
    'string','Volume','fontsize',10,'background','white');
volumeStr = '0';
VOLUME_EDIT = uicontrol('Style','edit', 'FontSize',10,'Units','Normalized','Position',...
        [0.80 0.45 0.02 0.02],'String', volumeStr,'HorizontalAlignment','left',...
        'BackgroundColor','White', 'TooltipString', 'Enter Volume', 'callback', @volume_edit_callback);
maxVolumeStr = sprintf('/ %d', max_volumes-1);    
max_volume_text=uicontrol('style','text','units','normalized','position',[0.82 0.45 0.02 0.02],...
    'string',maxVolumeStr,'fontsize',10,'background','white');
    
LOOP_BUTTON = uicontrol('style','pushbutton','units', 'normalized',...
    'position',[0.92 0.45 0.04 0.03],'String','LOOP','FontWeight','bold','FontSize',12,...
    'HorizontalAlignment','left', 'enable', 'off', 'callback',@loop_Callback);
VOLUME_SCROLL = uicontrol('style','slider','units', 'normalized',...
    'position',[0.84 0.44 0.06 0.03],'min',0,'max',1,...
    'Value',0, 'sliderStep', [1 1],'BackGroundColor',...
    [0.9 0.9 0.9],'callback',@imageScroll_Callback);

FILE_LISTBOX=uicontrol('Style','Listbox','fontName','lucinda','Units','Normalized','Position',...
    [0.765 0.31 0.18 0.13],'String','Original Data','HorizontalAlignment','Center','BackgroundColor',...
    'White','min',1,'max',10,'Callback',@file_listbox_callback);

uicontrol('style', 'pushbutton', 'units', 'normalized','fontName','lucinda',...
    'position',[0.765 0.28 0.05 0.02],'String','- remove','FontSize',10,...
    'HorizontalAlignment','left', 'callback',@remove_Callback);

% sliders
uicontrol('style','text','units','normalized','position',[0.765 0.105 0.1 0.02],...
    'string','Brightness','fontsize',10,'FontWeight','normal','background','white','horizontalalignment','left');

uicontrol('style','slider','units', 'normalized',...
    'position',[0.765 0.085 0.18 0.02],'min',0.0,'max',maxBrightness,...
    'Value',contrast_value, 'sliderStep', [0.03 0.03],'BackGroundColor',[0.9 0.9 0.9],'callback',@brightness_slider_Callback);

% transparency slider
uicontrol('style','text','units','normalized','position',[0.765 0.06 0.1 0.02],...
    'string','Transparency','fontsize',10,'FontWeight','normal','background','white','horizontalalignment','left');

uicontrol('style','slider','units', 'normalized',...
    'position',[0.765 0.04 0.18 0.02],'min',0.0,'max',1.0,...
    'Value',overlayAlpha, 'sliderStep', [0.001 0.01],'BackGroundColor',[0.9 0.9 0.9],'callback',@transparency_slider_Callback);

uicontrol('style','text','units','normalized','position',[0.95 0.04 0.017 0.02],...
    'string','Max','fontsize',10,'FontWeight','normal','background','white', 'horizontalalignment','left');

uicontrol('style','text','units','normalized','position',[0.745 0.04 0.017 0.02],...
    'string','Min','fontsize',10,'FontWeight','normal','background','white','horizontalalignment','left');


    function brightness_slider_Callback(src, ~)
        contrast_value = get(src,'Value');
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
    end

    function transparency_slider_Callback(src, ~)
        overlayAlpha = get(src,'Value');
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
    end

    % load a tractography file into viewer
    function load_tract_file(~,~)

        [basefile, tractfile] = select_tract_files;
        
        if ~isempty(basefile)
            overlayBase = 1;
        else   
            overlayBase = 0;
        end        
        if isempty(tractfile)
            return;
        end
        
        [~, n, ~] = fileparts(tractfile);
      
        % display overlaid on base
        if overlayBase
            display_mode = 0;
            loadData(basefile);
            display_mode = 5;
            loadTract(tractfile);

            [~, nb, ~] = fileparts(basefile);
            
            l = size(files,2);
            str = sprintf('%s (overlaid on %s)', n, nb);
            files(l+1) = {str};
            set(FILE_LISTBOX, 'String', files);
            set(FILE_LISTBOX, 'Value', l+1);

            loaded_files{size(loaded_files,1)+1,1} = 5;
            loaded_files{size(loaded_files,1),2} = {basefile};
            loaded_files{size(loaded_files,1),3} = {tractfile};
            
        % display as projection in coronal, axial, and sagittal planes
        else
            display_mode = 6;
            loadTract(tractfile);

            l = size(files,2);
            files(l+1) = {n};
            set(FILE_LISTBOX, 'String', files);
            set(FILE_LISTBOX, 'Value', l+1);

            loaded_files{size(loaded_files,1)+1,1} = 6;
            loaded_files{size(loaded_files,1),2} = {tractfile};
        end
    end

    % load dtifit output files into viewer
    function load_dtifit_file(~,~)
        
        [basefile, dtifile, eigenfile] = select_dti_files;
        
        overlayBase = 0;
        overlayDTI = 0;
        if ~isempty(basefile)
            overlayBase = 1;
        end
        
        if ~isempty(dtifile)
            overlayDTI = 1;
            dtifile = getUnzipped(dtifile);
        end       
        
        if isempty(eigenfile)
            return;
        end
        
        eigenfile = getUnzipped(eigenfile);          
        [~, n, ~] = fileparts(eigenfile);
  
        % overlay on base image (e.g. T1)
        if overlayBase
            
            % modulate by dtifit output file
            if overlayDTI
                
                display_mode = 0;
                loadData(basefile);
                display_mode = 8;
                loadDTIOverlay(dtifile, eigenfile);

                [~, nb2, ~] = fileparts(dtifile);
                [~, nb, ~] = fileparts(basefile);
                
                l = size(files,2);
                str = sprintf('%s Modulated by %s (overlaid on %s)', n, nb2, nb);
                files(l+1) = {str};
                set(FILE_LISTBOX, 'String', files);
                set(FILE_LISTBOX, 'Value', l+1);

                loaded_files{size(loaded_files,1)+1,1} = 8;
                loaded_files{size(loaded_files,1),2} = {basefile};
                loaded_files{size(loaded_files,1),3} = {dtifile};
                loaded_files{size(loaded_files,1),4} = {eigenfile};
            
            % do not modulate
            else 
            
                display_mode = 0;
                loadData(basefile);
                display_mode = 8;
                empty = [];
                loadDTIOverlay(empty, eigenfile);

                [~, nb, ~] = fileparts(basefile);
               
                l = size(files,2);
                str = sprintf('%s (overlaid on %s)', n, nb);
                files(l+1) = {str};
                set(FILE_LISTBOX, 'String', files);
                set(FILE_LISTBOX, 'Value', l+1);

                loaded_files{size(loaded_files,1)+1,1} = 8;
                loaded_files{size(loaded_files,1),2} = {basefile};
                loaded_files{size(loaded_files,1),3} = {''};
                loaded_files{size(loaded_files,1),4} = {eigenfile};
            end
        
        % do not overlay
        else
            
            % modulate by dtifit output file
            if overlayDTI
                
                display_mode = 7;
                loadDTIOverlay(dtifile, eigenfile);

                [~, nb2, ~] = fileparts(dtifile);
                
                l = size(files,2);
                str = sprintf('%s Modulated by %s', n, nb2);
                files(l+1) = {str};
                set(FILE_LISTBOX, 'String', files);
                set(FILE_LISTBOX, 'Value', l+1);

                loaded_files{size(loaded_files,1)+1,1} = 7;
                loaded_files{size(loaded_files,1),2} = {dtifile};
                loaded_files{size(loaded_files,1),3} = {eigenfile};
            
            % do not modulate
            else
            
                display_mode = 7;
                empty = [];
                loadDTIOverlay(empty, eigenfile);

                l = size(files,2);
                files(l+1) = {n};
                set(FILE_LISTBOX, 'String', files);
                set(FILE_LISTBOX, 'Value', l+1);

                loaded_files{size(loaded_files,1)+1,1} = 7;
                loaded_files{size(loaded_files,1),2} = {''};
                loaded_files{size(loaded_files,1),3} = {eigenfile};
            end
        end
    end

    % add overlay to currently viewed volume
    function add_overlay(src,~)
        
        if isempty(loaded_files)
            fprintf('Must first load a background image\n');
            return;
        end
        
        % cannot overlay ontop of tractography projections
        if display_mode == 6
            fprintf('Cannot add overlay to tractography projection\n');
            return;
        end
        
        % get tract file
        [fileName, filePath] = uigetfile(...
            {'*.nii','Overlay file (*.nii)'; '*.nii.gz','Overlay file (*.nii.gz)'},...            
            'Select Overlay file');
        if isequal(fileName,0) || isequal(filePath,0)
            return;
        end
        file = fullfile(filePath, fileName);
        file = getUnzipped(file);
        
        result = loadOverlay(file);
        if ~result
            return;
        end
        
        file_num = get(FILE_LISTBOX, 'value');
%         file_display_name = files{file_num};
%         str = sprintf('%s (overlaid on %s)', n, file_display_name);
%         files(file_num) = {str};
%         set(FILE_LISTBOX, 'String', files);

        cell_files = cellfun(@isempty, (loaded_files(file_num, :))) == 0;
        num_files = size(loaded_files(file_num, cell_files), 2);
        loaded_files{file_num,num_files+1} = {file};
        
        if size(overlay_img, 2) == 5
            set(src, 'enable', 'off');
        end
    end

    % clear all overlays on currently viewed volume
    function clear_overlay(~,~)

        fileNum = get(FILE_LISTBOX, 'value');
        
        % remove overlays from loaded_files
        num_overlays = size(overlay_img, 2);
        cell_files = cellfun(@isempty, (loaded_files(fileNum, :))) == 0;
        num_files = size(loaded_files(fileNum, cell_files), 2);
        for i=0:(num_overlays-1)
            loaded_files{fileNum, num_files-i} = [];
        end
        
        overlay_img = [];
        load_selected_file(fileNum);
        
        set(ADD_OVERLAY, 'enable', 'on');
    end

    % extract a volume from a multi-volume (4D) file
    function extract_volume_callback(~, ~)
        
        % select file to extract from
        [fileName, filePath] = uigetfile(...
                {'*.nii','extraction file (*.nii)'; '*.nii.gz','extraction file (*.nii.gz)'},...            
                'Select 4D file to extract volume from...');
        if isequal(fileName,0) || isequal(filePath,0)
            return;
        end
        old_file_original = fullfile(filePath, fileName);
        old_file = getUnzipped(old_file_original);
        
         % check that file is 4D
        nii = load_nii(old_file);
        if size(nii.img, 4) == 1
            fprintf('File to extract volume from must be 4D\n');
            return;
        else
            max_vol = size(nii.img, 4)-1;
        end
        clear nii;
        
        vol_num = 0;
        cont = 0;
        
        % popup to select volume to extract
        fig2=figure('Name', 'Select Volume to Extract', 'Position', [(scrsz(3)-300)/2 (scrsz(4)-80)/2 300 80],...
            'menubar','none','numbertitle','off', 'Color','white', 'CloseRequestFcn', @vol_close);
        vol_edit = uicontrol('style','edit','units','normalized','position',...
            [0.1 0.4 0.2 0.4],'String', '0',...
            'FontSize', 10, 'BackGroundColor','white');
        max_str = sprintf('/ %g', max_vol);
        uicontrol('style', 'text','units','normalized','position',...
            [0.31 0.5 0.1 0.2],'String', max_str,...
            'FontSize', 10, 'BackGroundColor','white');
        uicontrol('Style','PushButton','Units','Normalized','Position', [0.5 0.40 0.4 0.4],'callback', @extract_callback, ...
            'HorizontalAlignment','Center','BackGroundColor',...
            'white', 'FontSize', 11, 'ForegroundColor','green', 'String', 'EXTRACT');
        
        function extract_callback(~, ~)
            cont = 1;
            vol_num = round(str2num(get(vol_edit, 'String')));
            uiresume(gcf);
            delete(fig2);
        end
        
        function vol_close(~,~)
            cont = 0;
            uiresume(gcf);
            delete(fig2);
        end
        
        uiwait(gcf);
        
        if ~cont
            return;
        end

        % extract and let user choose file name
        [nn, np] = uiputfile('', 'Save Extracted Volume As...');
        if isequal(np, 0) || isequal(nn, 0)
            return;
        end
        [~, n, ~] = fileparts(nn);
        new_file_name = fullfile(np, n);
        file = fullfile(np, strcat(n, '.nii.gz'));
        
        command = sprintf('%s %s %s %g 1', fullfile(fsldir, 'bin', 'fslroi'), old_file, new_file_name, vol_num);
        
        fprintf('Running FSL version %g fslroi to extract volume %g from %s...\n%s\n', FSLVer, vol_num, old_file_original, command);
        
        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/fslroi\n', fsldir);
            return;
        end

        file = getUnzipped(file);
        
        display_mode = 0;
        loadData(file);
        
        l = size(files,2);
        files(l+1) = {n};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        
        loaded_files{size(loaded_files,1)+1,1} = display_mode;
        loaded_files{size(loaded_files,1),2} = {file};
        
        oldcoords = [round(max_dim/2)-1 round(max_dim/2)-1 round(max_dim/2)-1];
        slice1_RAS = oldcoords(1);
        slice2_RAS = oldcoords(2);
        slice3_RAS = oldcoords(3);
        
    end

    % merge volumes into 4D file
    function merge_volumes_callback(~, ~)
        
        % select files to merge
        [names, paths] = uigetfile({'*.nii.gz', 'Select volumes to merge (*.nii.gz)'; '*.nii', 'Select volumes to merge (*.nii)'}, 'Select volumes to merge' , 'MultiSelect', 'on');
        if isequal(names,0) || isequal(paths, 0)
            return;
        end
        
        % merge files
        if ~isequal(class(names),'cell')
            fprintf('Must select multiple files to merge\n');
            return;
        end
        in_files = fullfile(paths, names{1});
        for i=2:size(names, 2)
            in_files = sprintf('%s %s', in_files, fullfile(paths, names{i}));
        end

        % user selects new name
        [new_name, new_path] = uiputfile('', 'Save Merged Volumes As...');
        if isequal(new_path, 0) || isequal(new_name, 0)
            return;
        end
        file = fullfile(new_path, new_name);
        [~, n, ~] = fileparts(file);

        command = sprintf('%s -t %s %s', fullfile(fsldir, 'bin', 'fslmerge'), file, in_files);
        fprintf('Running FSL version %g fslmerge...\n%s\n', FSLVer, command);

        [status, ~] = system(command, '-echo');
        if status ~= 0
            fprintf('Error executing %s/bin/fslmerge\n', fsldir);
            return;
        end
        
        file = strcat(file, '.nii.gz');   
        file = getUnzipped(file);
        
        % load 4D merged file
        display_mode = 0;
        loadData(file);
                
        l = size(files,2);
        files(l+1) = {n};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        
        loaded_files{size(loaded_files,1)+1,1} = display_mode;
        loaded_files{size(loaded_files,1),2} = {file};
        
        oldcoords = [round(max_dim/2)-1 round(max_dim/2)-1 round(max_dim/2)-1];
        slice1_RAS = oldcoords(1);
        slice2_RAS = oldcoords(2);
        slice3_RAS = oldcoords(3);
        
    end
    
    % display data in viewer
    function loadData(file)
        
        fprintf('Loading %s...\n', file);
        
        data_nii = load_nii(file);
        
        % make isotropic if necessary
        data_nii = makeIsotropic(data_nii);

        % load 1st volume of image (in case there are multiple)
        img1 = data_nii.img(:,:,:,1);        
        img_RAS=img1;
        
        % flip z and y directions RAS -> RPI
        img2 = flipdim(img_RAS,3);
        img = flipdim(img2,2);
        
        if(data_nii.hdr.dime.datatype==2)
            img_display=uint8(img);
        else
            maxVal = max(max(max(img)));
            maxVal = double(maxVal);
            scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
            img_display = scaleTo8bit* img; 
            img_display = uint8(img_display);
        end
        
        % set display variables
        max_dim = max(data_nii.hdr.dime.dim(2), max(data_nii.hdr.dime.dim(3), data_nii.hdr.dime.dim(4)));    
        max_volumes = size(data_nii.img,4);
        mmPerVoxel = data_nii.hdr.dime.pixdim(2);
        
        slice_dim = [data_nii.hdr.dime.dim(2) data_nii.hdr.dime.dim(3) data_nii.hdr.dime.dim(4)];
        slice1_RAS = round(data_nii.hdr.dime.dim(2)/2)-1;
        slice2_RAS = round(data_nii.hdr.dime.dim(3)/2)-1;
        slice3_RAS = round(data_nii.hdr.dime.dim(4)/2)-1;
        oldcoords=[slice1_RAS slice2_RAS slice3_RAS];
        
        if max(max(max(data_nii.img)))==1
            display_mode = 3;
        end

        % reset drawing settings
        if drawing           
            set(UNDO_BUTTON, 'enable', 'off');
            set(CLEAR_BUTTON, 'enable', 'off');
            set(CREATE_MASK_BUTTON, 'string', 'Draw');
            prev = [];
            drawing = 0;
            set(f,'WindowButtonDownFcn', @buttondown);
        end
        
        % reset overlays
        overlay_img = [];
        set(ADD_OVERLAY, 'enable', 'on');
        
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        
        % update slice slider information (scale to current data dimensions)
        slice3_str = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT, 'String', slice3_str);
        slice1_str = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT, 'String', slice1_str);
        slice2_str = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT, 'String', slice2_str);
        
        set(AXIS_SLIDER, 'max', slice_dim(3));
        set(CORONAL_SLIDER, 'max', slice_dim(2));
        set(SAGITTAL_SLIDER, 'max', slice_dim(1));
        
        set(AXIS_SLIDER, 'sliderStep', [1 1]/(slice_dim(3)-1));
        set(CORONAL_SLIDER, 'sliderStep', [1 1]/(slice_dim(2)-1));
        set(SAGITTAL_SLIDER, 'sliderStep', [1 1]/(slice_dim(1)-1));
        
        set(AXIS_SLIDER, 'value', slice_dim(3)-slice3_RAS);
        set(CORONAL_SLIDER, 'value', slice_dim(2)-slice2_RAS);
        set(SAGITTAL_SLIDER, 'value', slice1_RAS+1);
        
        % update volume edit
        % try to keep current volume selection
        
        currentImage = str2num(get(VOLUME_EDIT, 'String'));
        if currentImage > max_volumes-1
            currentImage = max_volumes-1;
        end
        set(VOLUME_SCROLL,'min',0,'max',max_volumes-1);
        set(VOLUME_SCROLL,'sliderStep',[1/(max_volumes) , 1/(max_volumes)]);
        set(VOLUME_SCROLL,'value',currentImage);
        
        set(VOLUME_EDIT, 'String', num2str(currentImage));
        
        maxVolStr = sprintf('/ %d', max_volumes-1);
        set(max_volume_text, 'String', maxVolStr);
        
        if max_volumes>1
            set(LOOP_BUTTON, 'enable', 'on');
        else
            set(LOOP_BUTTON, 'enable', 'off');
        end

    end

    % display eigenvector file in viewer
    function loadDTIOverlay(fa_file, v1_file)
        
        % reset overlays
        dti_v1_overlay = [];
        dti_fa_overlay = [];
        overlay_img = [];
        set(ADD_OVERLAY, 'enable', 'on');
        
        % split vector file
        nii = load_nii(v1_file);
        
        % modulate by dtifit output file or not (empty 'fa_file')
        if ~isempty(fa_file)
            fprintf('Reading files %s and %s\nVoxel dimensions: %g %g %g\n',...
                fa_file, v1_file, nii.hdr.dime.pixdim(2), nii.hdr.dime.pixdim(3), nii.hdr.dime.pixdim(4));
        else
            fprintf('Reading file %s\nVoxel dimensions: %g %g %g\n',...
                v1_file, nii.hdr.dime.pixdim(2), nii.hdr.dime.pixdim(3), nii.hdr.dime.pixdim(4));
        end
        
        % make isotropic if necessary
        nii = makeIsotropic(nii);

        if size(nii.img, 4) == 3
            dti_v1_overlay.x = nii;
            dti_v1_overlay.x.img = nii.img(:, :, :, 1);
            dti_v1_overlay.y = nii;
            dti_v1_overlay.y.img = nii.img(:, :, :, 2);
            dti_v1_overlay.z = nii;
            dti_v1_overlay.z.img = nii.img(:, :, :, 3);
        else
            fprintf('overlay image is not 3-vector (%d)\n', size(nii.img, 4));
            return;
        end
        
        % flip z direction RAS -> RAI
        img_x = flipdim(dti_v1_overlay.x.img,3);
        img_y = flipdim(dti_v1_overlay.y.img,3);
        img_z = flipdim(dti_v1_overlay.z.img,3);
        
        % flip y direction RAI -> RPI
        dti_v1_overlay.x.img = flipdim(img_x,2);
        dti_v1_overlay.y.img = flipdim(img_y,2);
        dti_v1_overlay.z.img = flipdim(img_z,2);
    
        if ~isempty(fa_file)
            fa_nii = load_nii(fa_file);

            % make isotropic if necessary
            fa_nii = makeIsotropic(fa_nii);

            img1 = fa_nii.img(:,:,:,1);        

            % flip z and y directions RAS -> RPI
            img2 = flipdim(img1,3);
            img = flipdim(img2,2);

            if(fa_nii.hdr.dime.datatype==2)
                dti_fa_overlay=uint8(img);
            else
                maxVal = max(max(max(img)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;
                dti_fa_overlay = scaleTo8bit* img; 
                dti_fa_overlay = uint8(dti_fa_overlay);
            end
        end
        
        % if not overlaid on base image, display over
        % black background
        if display_mode == 7
            img_display = zeros(nii.hdr.dime.dim(2), nii.hdr.dime.dim(3), nii.hdr.dime.dim(4));
            max_dim = max(nii.hdr.dime.dim(2), max(nii.hdr.dime.dim(3), nii.hdr.dime.dim(4)));    

            slice_dim = [nii.hdr.dime.dim(2) nii.hdr.dime.dim(3) nii.hdr.dime.dim(4)];
            slice1_RAS = round(nii.hdr.dime.dim(2)/2)-1;
            slice2_RAS = round(nii.hdr.dime.dim(3)/2)-1;
            slice3_RAS = round(nii.hdr.dime.dim(4)/2)-1;
            oldcoords=[slice1_RAS slice2_RAS slice3_RAS];

            % update slice slider information (scale to current data dimensions)
            slice3_str = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
            set(SLICE3_EDIT, 'String', slice3_str);
            slice1_str = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
            set(SLICE1_EDIT, 'String', slice1_str);
            slice2_str = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
            set(SLICE2_EDIT, 'String', slice2_str);

            set(AXIS_SLIDER, 'max', slice_dim(3));
            set(CORONAL_SLIDER, 'max', slice_dim(2));
            set(SAGITTAL_SLIDER, 'max', slice_dim(1));

            set(AXIS_SLIDER, 'sliderStep', [1 1]/(slice_dim(3)-1));
            set(CORONAL_SLIDER, 'sliderStep', [1 1]/(slice_dim(2)-1));
            set(SAGITTAL_SLIDER, 'sliderStep', [1 1]/(slice_dim(1)-1));
            
            set(AXIS_SLIDER, 'value', slice_dim(3)-slice3_RAS);
            set(CORONAL_SLIDER, 'value', slice_dim(2)-slice2_RAS);
            set(SAGITTAL_SLIDER, 'value', slice1_RAS+1);

            % update volume edit
            set(VOLUME_EDIT, 'String', '0');
            set(max_volume_text, 'String', '/ 0');
            set(LOOP_BUTTON, 'enable', 'off');
            
            % reset drawing settings
            if drawing
                set(UNDO_BUTTON, 'enable', 'off');
                set(CLEAR_BUTTON, 'enable', 'off');
                set(CREATE_MASK_BUTTON, 'string', 'Draw');
                prev = [];
                drawing = 0;
                set(f,'WindowButtonDownFcn', @buttondown);
            end
        end
        
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        
    end

    % display tract image in viewer
    function loadTract(file)
        
        fprintf('Loading %s...\n', file);
        
        data_nii = load_nii(file);
        
        data_nii = makeIsotropic(data_nii);

        % load 1st volume of image (in case there are multiple)
        img1 = data_nii.img(:,:,:,1);        
        img_RAS=img1;
        
        % flip z and y directions RAS -> RPI
        img2 = flipdim(img_RAS,3);
        img = flipdim(img2,2);
        
        if(data_nii.hdr.dime.datatype==2)
            tract_colour_top=uint8(img);
        else
            maxVal = max(max(max(img)));
            maxVal = double(maxVal);
            scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
            tract_colour_top = scaleTo8bit* img; 
            tract_colour_top = uint8(tract_colour_top);
        end

        % set display variables
        max_dim = max(data_nii.hdr.dime.dim(2), max(data_nii.hdr.dime.dim(3), data_nii.hdr.dime.dim(4)));    
        max_volumes = size(data_nii.img,4);
        mmPerVoxel = data_nii.hdr.dime.pixdim(2);
        
        slice_dim = [data_nii.hdr.dime.dim(2) data_nii.hdr.dime.dim(3) data_nii.hdr.dime.dim(4)];
        slice1_RAS = round(data_nii.hdr.dime.dim(2)/2)-1;
        slice2_RAS = round(data_nii.hdr.dime.dim(3)/2)-1;
        slice3_RAS = round(data_nii.hdr.dime.dim(4)/2)-1;
        oldcoords=[slice1_RAS slice2_RAS slice3_RAS];
        
        % scale up image values to display in colour
        tract_colour_top = bsxfun(@plus, tract_colour_top, 128);
        
        % if chose to display as projection, compute projections in each
        % plane
        if display_mode == 6
            
            % black image background
            img_display = zeros(slice_dim(1), slice_dim(2), slice_dim(3));
            
            sag_tract_proj = zeros(slice_dim(3), slice_dim(2));
            axi_tract_proj = zeros(slice_dim(2), slice_dim(1));
            cor_tract_proj = zeros(slice_dim(3), slice_dim(1));
            for i=1:slice_dim(3)
                for j=1:slice_dim(2)
                    vec = tract_colour_top(:,j,i);
                    sag_tract_proj(i,j) = max(vec);
                end
            end
            for i=1:slice_dim(3)
                for j=1:slice_dim(1)
                    vec = tract_colour_top(j,:,i);
                    cor_tract_proj(i,j) = max(vec);
                end
            end
            for i=1:slice_dim(2)
                for j=1:slice_dim(1)
                    vec = tract_colour_top(j,i, :);
                    axi_tract_proj(i,j) = max(vec);
                end
            end
        end
        
        % reset overlays
        overlay_img = [];
        set(ADD_OVERLAY, 'enable', 'on');
            
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
        
        % update slice slider information (scale to current data dimensions)
        slice3_str = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT, 'String', slice3_str);
        slice1_str = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT, 'String', slice1_str);
        slice2_str = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT, 'String', slice2_str);
        
        set(AXIS_SLIDER, 'max', slice_dim(3));
        set(CORONAL_SLIDER, 'max', slice_dim(2));
        set(SAGITTAL_SLIDER, 'max', slice_dim(1));
        
        set(AXIS_SLIDER, 'sliderStep', [1 1]/(slice_dim(3)-1));
        set(CORONAL_SLIDER, 'sliderStep', [1 1]/(slice_dim(2)-1));
        set(SAGITTAL_SLIDER, 'sliderStep', [1 1]/(slice_dim(1)-1));
        
        set(AXIS_SLIDER, 'value', slice_dim(3)-slice3_RAS);
        set(CORONAL_SLIDER, 'value', slice_dim(2)-slice2_RAS);
        set(SAGITTAL_SLIDER, 'value', slice1_RAS+1);
        
        % update volume edit
        set(VOLUME_EDIT, 'String', '0');
        maxVolStr = sprintf('/ %d', max_volumes-1);
        set(max_volume_text, 'String', maxVolStr);
        if max_volumes>1
            set(LOOP_BUTTON, 'enable', 'on');
        else
            set(LOOP_BUTTON, 'enable', 'off');
        end
        
        % reset drawing settings
        if drawing
            set(UNDO_BUTTON, 'enable', 'off');
            set(CLEAR_BUTTON, 'enable', 'off');
            set(CREATE_MASK_BUTTON, 'string', 'Draw');
            prev = [];
            drawing = 0;
            set(f,'WindowButtonDownFcn', @buttondown);
        end
        
    end

    % load overlay image
    function result = loadOverlay(file)
        
        fprintf('Loading %s...\n', file);
        
        nii = load_nii(file);
        
        nii = makeIsotropic(nii);

        % load 1st volume of image (in case there are multiple)
        img1 = nii.img(:,:,:,1);        
        img_RAS=img1;
        
        % flip z and y directions RAS -> RPI
        img2 = flipdim(img_RAS,3);
        img = flipdim(img2,2);

        % check display variables 
        if max_dim ~= max(nii.hdr.dime.dim(2), max(nii.hdr.dime.dim(3), nii.hdr.dime.dim(4))) ||...           
            max_volumes ~= size(nii.img,4) || mmPerVoxel ~= nii.hdr.dime.pixdim(2) ||...
            slice_dim(1) ~= nii.hdr.dime.dim(2) || slice_dim(2) ~= nii.hdr.dime.dim(3) || slice_dim(3) ~= nii.hdr.dime.dim(4)
            fprintf('Overlay dimensions must match base image\n');
            result = 0;
            return;
        end
        
        % scale up image values to display in a new colour
        dimg = double(img);
        maxVal = max(max(max(dimg)));
        maxVal = double(maxVal);
        scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
        overlay = scaleTo8bit* dimg;
        new_overlay = round( overlay + (128+128*(size(overlay_img,2)+1)));
        
        % add to list of overlay images
        overlay_img{size(overlay_img,2)+1} = new_overlay;
        
        if size(overlay_img, 2) == 5
            set(ADD_OVERLAY, 'enable', 'off');
        end
        
        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
      
        % reset drawing settings
        if drawing
            set(UNDO_BUTTON, 'enable', 'off');
            set(CLEAR_BUTTON, 'enable', 'off');
            set(CREATE_MASK_BUTTON, 'string', 'Draw');
            prev = [];
            drawing = 0;
            set(f,'WindowButtonDownFcn', @buttondown);
        end
        
        result = 1;
    end

    % interpolate to isotropic dimensions if necessary
    function nii = makeIsotropic(nii)

        %fprintf('Checking image dimensions...\n');
        %fprintf('image size: %g %g %g %g voxels\n', ...
        %    nii.hdr.dime.dim(2), nii.hdr.dime.dim(3), nii.hdr.dime.dim(4), nii.hdr.dime.dim(5));
        %fprintf('voxel dimensions: %g %g %g mm\n', ...
        %    nii.hdr.dime.pixdim(2), nii.hdr.dime.pixdim(3), nii.hdr.dime.pixdim(4));
        
        % downsample if larger than max_pixels in any dimension (for memory
        % reasons)
        max_pixels = 400;
        
        idx = find( nii.hdr.dime.dim > max_pixels );
        volumes = nii.hdr.dime.dim(5);
        if size(idx ~= 0)
            if nii.hdr.dime.dim(2) > max_pixels
                newdim = floor(nii.hdr.dime.dim(2) / 2);
                fprintf('%d voxels in x dimension detected .. downsampling to %d...\n',nii.hdr.dime.dim(2), newdim);
                nii.img = nii.img(1:2:end,:,:,:);
                nii.hdr.dime.dim(2) = newdim;
                nii.hdr.dime.pixdim(2) = nii.hdr.dime.pixdim(2) * 2.0;
            end
            if nii.hdr.dime.dim(3) > max_pixels
                newdim = floor(nii.hdr.dime.dim(3) / 2);
                fprintf('%d voxels in y dimension detected .. downsampling to %d...\n',nii.hdr.dime.dim(3), newdim);
                nii.img = nii.img(:,1:2:end,:,:);
                nii.hdr.dime.dim(3) = newdim;
                nii.hdr.dime.pixdim(3) = nii.hdr.dime.pixdim(3) * 2.0;
            end
            if nii.hdr.dime.dim(4) > max_pixels
                newdim = floor(nii.hdr.dime.dim(4) / 2);
                fprintf('%d voxels in z dimension detected .. downsampling to %d...\n', nii.hdr.dime.dim(4), newdim);
                nii.img = nii.img(:,:,1:2:end,:);
                nii.hdr.dime.dim(4) = newdim;
                nii.hdr.dime.pixdim(4) = nii.hdr.dime.pixdim(4) * 2.0;
            end
            fprintf('new image size: %g %g %g voxels\n', ...
                nii.hdr.dime.dim(2), nii.hdr.dime.dim(3), nii.hdr.dime.dim(4));
            fprintf('new voxel dimensions: %g %g %g mm\n', ...
                nii.hdr.dime.pixdim(2), nii.hdr.dime.pixdim(3), nii.hdr.dime.pixdim(4));

        end 
        
        % interpolate if any dim differs by > 0.01mm
        minErr = 0.01; 
        diff1 = abs( nii.hdr.dime.pixdim(2) - nii.hdr.dime.pixdim(3) );
        diff2 = abs( nii.hdr.dime.pixdim(3) - nii.hdr.dime.pixdim(4) );
        diff3 = abs( nii.hdr.dime.pixdim(2) - nii.hdr.dime.pixdim(4) );

        if diff1 < minErr && diff2 < minErr && diff3 < minErr
            isIsotropic = true;
%             fprintf('original image is isotropic (within %g mm). No interpolation will be done...\n', minErr);
        else
            isIsotropic = false;
            fprintf('image differs by more than %g mm in one or more dimensions, interpolating...\n', minErr);

            pixdim=[nii.hdr.dime.pixdim(2) nii.hdr.dime.pixdim(3) nii.hdr.dime.pixdim(4)];

            %  find smallest voxel size to use as resolution (that doesn't
            %  exceed max_pixels)
            sdim = sort(pixdim);
            
            canInterpolate = false;
            for k=1:3
                  mmPerVoxel = sdim(k);                                                                              
                  fprintf('trying %g mm voxel size...\n', mmPerVoxel);
                  
                  % get new voxel dimensions
                  vox_x = round(nii.hdr.dime.dim(2)*nii.hdr.dime.pixdim(2)/mmPerVoxel); % vox number in x direction,round to integer value
                  vox_y = round(nii.hdr.dime.dim(3)*nii.hdr.dime.pixdim(3)/mmPerVoxel);
                  vox_z = round(nii.hdr.dime.dim(4)*nii.hdr.dime.pixdim(4)/mmPerVoxel);      
                  if vox_x <= max_pixels && vox_y <= max_pixels && vox_z <= max_pixels
                      canInterpolate = true;
                      break;
                  end
                  fprintf('image equals exceeds %g voxels...\n', max_pixels);
            end                
            if ~canInterpolate
                fprintf('*** Image resolution appears too high to fit in less than %gx%gx%g - defaulting to 1 mm isotropic interpolation ***\n', max_pixels, max_pixels, max_pixels);
                mmPerVoxel = 1.0;
                vox_x = round(nii.hdr.dime.dim(2)*nii.hdr.dime.pixdim(2)/mmPerVoxel); % vox number in x direction,round to integer value
                vox_y = round(nii.hdr.dime.dim(3)*nii.hdr.dime.pixdim(3)/mmPerVoxel);
                vox_z = round(nii.hdr.dime.dim(4)*nii.hdr.dime.pixdim(4)/mmPerVoxel);                   
                if vox_x >= max_pixels && vox_y >= max_pixels && vox_z >= max_pixels                             
                    fprintf('Sorry, having trouble interpolating this image...\n');
                    return;
                end                    
            end 
        end
        
        % if image is perfectly isotropic just store original data at original resolution...
        if isIsotropic
            mmPerVoxel = nii.hdr.dime.pixdim(2);
            vox_x = nii.hdr.dime.dim(2);
            vox_y = nii.hdr.dime.dim(3);
            vox_z = nii.hdr.dime.dim(4);
            img1 = nii.img;

        % if not isotropic, reshape data to be isotropic
        else                   
            dim_x=(nii.hdr.dime.dim(2)-1)/(vox_x-1);
            dim_y=(nii.hdr.dime.dim(3)-1)/(vox_y-1);
            dim_z=(nii.hdr.dime.dim(4)-1)/(vox_z-1);

            x = 1 + (0:vox_x-1) .* dim_x;
            M_x = reshape(repmat(x, 1, vox_y*vox_z), vox_x, vox_y, vox_z);

            y = 1 + (0:vox_y-1) .* dim_y;
            M_y = reshape(repmat(y, vox_x, vox_z), vox_x, vox_y, vox_z);

            z = 1 + (0:vox_z-1) .* dim_z;
            M_z = reshape(repmat(z, vox_x*vox_y, 1), vox_x, vox_y, vox_z);

            vols = nii.hdr.dime.dim(5);
            
            if (exist('trilinear') == 3)
                for i=1:vols
                    cur_vol = nii.img(:,:,:,i);
                    img1(:,:,:, i) = trilinear(double(cur_vol), double(M_y), double(M_x), double(M_z));
                end
            else
                for i=1:vols
                    cur_vol = nii.img(:,:,:,i);
                    img1(:,:,:, i) = interp3(double(cur_vol), double(M_y), double(M_x), double(M_z), 'linear',0);
                end
            end         

            fprintf('The image size after interpolation is: %g %g %g voxels\n',size(img1,1), size(img1,2), size(img1,3));                

        end
        
        
        si = size(img1);
        si = si(1:3);
        if all(si== si(1))
            nii.img=img1;
            nii.hdr.dime.dim(2)= size(img1, 1);
            nii.hdr.dime.dim(3)= size(img1, 2);
            nii.hdr.dime.dim(4)= size(img1, 3);
            nii.hdr.dime.pixdim(2)= mmPerVoxel;
            nii.hdr.dime.pixdim(3)= mmPerVoxel;
            nii.hdr.dime.pixdim(4)= mmPerVoxel;
            
        % pad image if necessary (dimensions aren't all the same size)
        else         
            maxDim = max(vox_x, max(vox_y, vox_z));
%             fprintf('padding image data (%d x %d x %d) to %d x %d x %d\n', vox_x, vox_y, vox_z, maxDim, maxDim, maxDim);
            
            % translate each point in old image to new image point
            new_img = zeros(maxDim,maxDim,maxDim, volumes);
            [x, y, z] = meshgrid(1:vox_x, 1:vox_y, 1:vox_z);
            pts = [x(:), y(:), z(:)];
            new_pts = zeros(size(pts));
            new_pts(:, 1) = pts(:,1) + ones(size(pts(:,1)))*round((maxDim-vox_x)/2);
            new_pts(:, 2) = pts(:,2) + ones(size(pts(:,2)))*round((maxDim-vox_y)/2);
            new_pts(:, 3) = pts(:,3) + ones(size(pts(:,3)))*round((maxDim-vox_z)/2);

            % make indices into old image
            Is1 = size(img1(:,:,:,1));
            Ioff = cumprod([1 Is1(1:end-1)]);
            idx1 = (pts-1)*Ioff.' + 1;

            % make indices into new image
            Is2 = size(new_img(:,:,:,1));
            Ioff2 = cumprod([1 Is2(1:end-1)]);
            idx2 = (new_pts-1)*Ioff2.' + 1;

            % translate each volume into padded image
            for i=1:volumes
                new_imgv = new_img(:,:,:,i);
                old_imgv = img1(:,:,:,i);
                new_imgv(idx2) = old_imgv(idx1);
                new_img(:,:,:,i) = new_imgv;
            end

            % return updated nifti
            nii.img = new_img;
            nii.hdr.dime.dim(2) = maxDim;
            nii.hdr.dime.dim(3) = maxDim;
            nii.hdr.dime.dim(4) = maxDim;
            nii.hdr.dime.pixdim(2) = mmPerVoxel;
            nii.hdr.dime.pixdim(3) = mmPerVoxel;
            nii.hdr.dime.pixdim(4) = mmPerVoxel;
        end
        
    end


    % run FSL's bedpostX
    function bedpostx_callback(~, ~)
        
        r = questdlg('Run bedpostx (this will take several hours) or create executable file?','DTI Analysis','Run in Matlab','Create executable file','Cancel','Cancel');
        if strcmp(r,'Cancel')
            return;
        end
        
        % launch through command line script - requires terminal window open?        
        if strcmp(r,'Create executable file')
            command = sprintf('%s %s -n %d -w %d -b %d -j %d -s %d', fullfile(fsldir, 'bin', 'bedpostx'), ds_folder, num_fibres, ard_weight, burnin_period, num_jumps, sample_every); 
            batfile = 'run_bedpostx.bat';
            fp = fopen(batfile,'w');
            fprintf(fp,'%s',command);
            fclose(fp);
            cmd = sprintf('chmod a+x %s', batfile);
            system(cmd);
            s = sprintf('Bedpost command saved in file [%s]. (Use ./%s to execute in terminal mode)', batfile, batfile); 
            msgbox(s); 
        elseif strcmp(r,'Run in Matlab')
            run_bedpost;  % run in Matlab
        end
        
    end

    function run_bedpost

        wbh = waitbar(0,'Running FSL bedpostx ...');

        waitbar(0.25,wbh);

        %  call bedpostx from commandline
        tic 
        command = sprintf('%s %s -n %d -w %d -b %d -j %d -s %d', fullfile(fsldir, 'bin', 'bedpostx'), ds_folder, num_fibres, ard_weight, burnin_period, num_jumps, sample_every); 
        fprintf('Running FSL version %g bedpostx ...\n%s\n', FSLVer, command);
        [status, ~] = system(command, '-echo');
        if status ~= 0
            fprintf('Error executing %s/bin/bedpostx\n', fsldir);
            delete(wbh);
            return;
        end

        toc

        waitbar(1,wbh);

        delete(wbh);  
        
        set(BEDPOST_BUTTON, 'enable', 'off');
        set_enable_register('on');
        set_enable_probtrackx('on');
        set(SELECT_BEDPOST_BUTTON,'enable', 'on');
                
        bedpostx_dir = strcat(ds_folder,'.bedpostX');
        
    end

    % create registration matrices
    function register_callback(~,~)
        
       tDir = fullfile(bedpostx_dir, 'xfms');
       if exist(tDir,'dir')
           s = sprintf('Use existing transformations in %s?', tDir);
           r = questdlg(s,'DTI Analysis','Yes','No. Re-Calculate','Cancel','Cancel');
            if strcmp(r,'Cancel')
                return;
            end
            if strcmp(r,'Yes')
                reg_dir = tDir;
                set_enable_dtifit('on');
                set_enable_mask('on');
                set_enable_probtrackx('on');
                return;
            end
       end

        wbh = waitbar(0,'Creating registration matrices...');
        
        waitbar(0.25,wbh);
        
        % check for necessary files
        if isempty(std_ref_file) && isempty(mri_ref_file)
            fprintf('Cannot create registration matrices without reference volumes\n');
            delete(wbh);
            return;
        end

        if ~exist(bedpostx_dir, 'dir')
            fprintf('Must have run bedpostx to create registration matrices\n%s does not exist\n', bedpostx_dir);
            delete(wbh);
            return;
        end
        
        % if selected an structural file, create registration matrices
        % to and from structural space
        if ~isempty(mri_ref_file)           
            
            % diff2str
            command = sprintf('%s -in %s -ref %s -omat %s.mat -cost mutualinfo', fullfile(fsldir, 'bin', 'flirt'), ...
                char(fullfile(bedpostx_dir, 'nodif_brain')), mri_ref_file, ...
                char(fullfile(bedpostx_dir, 'xfms','diff2str')));
            fprintf('\nRunning FSL version %g flirt to create diff2str registration matrix...\n%s\n', FSLVer, command);

            [status, ~] = system(command, '-echo');
            if status ~= 0
                fprintf('Error executing %s/bin/flirt \n', fsldir);
                delete(wbh);
                return;
            end

            waitbar(0.375,wbh);
            
            % str2diff
            command = sprintf('%s -omat %s.mat -inverse %s.mat', fullfile(fsldir, 'bin', 'convert_xfm'), ...
                char(fullfile(bedpostx_dir, 'xfms','str2diff')),...
                char(fullfile(bedpostx_dir, 'xfms','diff2str')));
            fprintf('\nRunning FSL version %g convert_xfm to create str2diff registration matrix...\n%s\n', FSLVer, command);

            [status, ~] = system(command, '-echo');
            if status ~= 0
                fprintf('Error executing %s/bin/convert_xfm \n', fsldir);
                delete(wbh);
                return;
            end
            
            waitbar(0.5,wbh);
            
            % if also have standard reference, create matrice to and from
            % standard space
            if ~isempty(std_ref_file)
                
                % str2standard
                command = sprintf('%s -in %s -ref %s -omat %s.mat', fullfile(fsldir, 'bin', 'flirt'), ...
                    mri_ref_file, std_ref_file, char(fullfile(bedpostx_dir, 'xfms','str2standard')));
                fprintf('\nRunning FSL version %g flirt to create str2standard registration matrix...\n%s\n', FSLVer, command);

                [status, ~] = system(command, '-echo');
                if status ~= 0
                    fprintf('Error executing %s/bin/flirt \n', fsldir);
                    delete(wbh);
                    return;
                end
                
                waitbar(0.625,wbh);
                
                % standard2str
                command = sprintf('%s -omat %s.mat -inverse %s.mat', fullfile(fsldir, 'bin', 'convert_xfm'), ...
                    char(fullfile(bedpostx_dir, 'xfms','standard2str')),...
                    char(fullfile(bedpostx_dir, 'xfms','str2standard')));
                fprintf('\nRunning FSL version %g convert_xfm to create standard2str registration matrix...\n%s\n', FSLVer, command);

                [status, ~] = system(command, '-echo');
                if status ~= 0
                    fprintf('Error executing %s/bin/convert_xfm \n', fsldir);
                    delete(wbh);
                    return;
                end
                
                waitbar(0.75,wbh);
                
                % diff2standard
                command = sprintf('%s -omat %s.mat -concat %s.mat %s.mat', fullfile(fsldir, 'bin', 'convert_xfm'), ...
                    char(fullfile(bedpostx_dir, 'xfms','diff2standard')),...
                    char(fullfile(bedpostx_dir, 'xfms','str2standard')), ...
                    char(fullfile(bedpostx_dir, 'xfms','diff2str')));
                fprintf('\nRunning FSL version %g convert_xfm to create diff2standard registration matrix...\n%s\n', FSLVer, command);

                [status, ~] = system(command, '-echo');
                if status ~= 0
                    fprintf('Error executing %s/bin/convert_xfm \n', fsldir);
                    delete(wbh);
                    return;
                end
                
                waitbar(0.875,wbh);
                
                % standard2diff
                command = sprintf('%s -omat %s.mat -inverse %s.mat', fullfile(fsldir, 'bin', 'convert_xfm'), ...
                    char(fullfile(bedpostx_dir, 'xfms','standard2diff')),...
                    char(fullfile(bedpostx_dir, 'xfms','diff2standard')));
                fprintf('\nRunning FSL version %g convert_xfm to create standard2diff registration matrix...\n%s\n', FSLVer, command);
                
                [status, ~] = system(command, '-echo');
                if status ~= 0
                    fprintf('Error executing %s/bin/convert_xfm \n', fsldir);
                    delete(wbh);
                    return;
                end
                
            end
         
        % if only standard reference file, create matrices to and from
        % standard space
        elseif ~isempty(std_ref_file)
            
            % diff2standard
            command = sprintf('%s -in %s -ref %s -omat %s.mat', fullfile(fsldir, 'bin', 'flirt'), ...
                char(fullfile(bedpostx_dir, 'nodif_brain')), std_ref_file,...
                char(fullfile(bedpostx_dir, 'xfms','diff2standard')));
            fprintf('\nRunning FSL version %g flirt to create diff2standard  registration matrix ...\n%s\n', FSLVer, command);

            [status, ~] = system(command, '-echo');
            if status ~= 0
                fprintf('Error executing %s/bin/flirt\n', fsldir);
                delete(wbh);
                return;
            end
            
            waitbar(0.5,wbh);
            
            % standard2diff
            command = sprintf('%s -omat %s.mat -inverse %s.mat', fullfile(fsldir, 'bin', 'convert_xfm'), ...
                    char(fullfile(bedpostx_dir, 'xfms','standard2diff')),...
                    char(fullfile(bedpostx_dir, 'xfms','diff2standard')));
            fprintf('\nRunning FSL version %g convert_xfm to create standard2diff registration matrix...\n%s\n', FSLVer, command);

            [status, ~] = system(command, '-echo');
            if status ~= 0
                fprintf('Error executing %s/bin/convert_xfm \n', fsldir);
                delete(wbh);
                return;
            end
            
            waitbar(0.75,wbh);
            
        end
        
        % move steps past registration
        set_enable_dtifit('on');
        set_enable_mask('on');
        set_enable_probtrackx('on');
        
        reg_dir = fullfile(bedpostx_dir, 'xfms');
        
        waitbar(1,wbh);
        
        delete(wbh);
        
    end

    % run FSL's dtifit 
    function dtifit_callback(~,~)
        
        wbh = waitbar(0,'Running FSL DTI fitting ...');

        waitbar(0.25,wbh);
        
        % create folder to store dtifit output files
        dti_folder = char(fullfile(ds_folder, dti_folder_name));
        if ~exist(dti_folder, 'dir')
            status = mkdir(dti_folder);
            if ~status
                errordlg('Failed to make dti directory');
                delete(wbh);
                return;
            end
        else
            str = sprintf('%s already exists. Overwrite?', dti_folder);
            response = questdlg(str,'DTI Analysis','Yes','No','Yes');
            if strcmp(response, 'No')
                delete(wbh);
                return;
            end
        end
        
        dti_folder_prefix = fullfile(dti_folder_name, dti_file_prefix);

        % if not progressing from artifact correction step, ask user what
        % dtifit should be run on
        if ~exist(corrected_file, 'file')
            [filename, filepath] = uigetfile({'*.nii.gz', 'Diffusion Weighted Images File (*.nii.gz)'; '*.nii', 'Diffusion Weighted Images File (*.nii)'}, 'Select DTI Input File (DW images)');
            if isequal(filename, 0) || isequal(filepath,0)
                delete(wbh);
                return;
            end
            
            input_file = fullfile(filepath, filename);
            input_file = getUnzipped(input_file);
        else
            input_file = corrected_file; 
        end
        
        % if bet has not been run, ask user for brain extracted mask
        if isempty(bet_file)
            [filename, filepath] = uigetfile({'*.nii.gz', 'BET Mask File (*.nii.gz)'; '*.nii', 'BET Mask File (*.nii)'}, 'Select Brain Extracted Mask File');
            if isequal(filename, 0) || isequal(filepath,0)
                delete(wbh);
                return;
            end
            bet_mask = char(fullfile(filepath, filename));
        else
            bet_mask = char(fullfile(ds_folder, strcat(bet_file_prefix,'_mask.nii.gz')));
        end
            
        
        % call FSL's dtifit (generate FA,MD, V1, V2, V3, L1, L2, L3 ..etc.)
        command = sprintf('%s -k %s -o %s -m %s -r %s -b %s', fullfile(fsldir, 'bin', 'dtifit'), input_file, char(fullfile(ds_folder, dti_folder_prefix)), bet_mask, bvecs_file, bvals_file);
        fprintf('Running FSL version %g dtifit ...\n%s\n', FSLVer, command);

        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/dtifit\n', fsldir);
            delete(wbh);
            return;
        end
        
        waitbar(0.4,wbh);
        
        % call fslmaths to calculate RD and AD
        command = sprintf('%s %s -add %s -div 2 %s', fullfile(fsldir, 'bin', 'fslmaths'),char(fullfile(ds_folder, strcat(dti_folder_prefix, '_L2.nii.gz'))), char(fullfile(ds_folder, strcat(dti_folder_prefix,'_L3.nii.gz'))), char(fullfile(ds_folder, strcat(dti_folder_prefix, '_RD.nii.gz'))));
        fprintf(command);
        fprintf('\n');
        [status, ~] = system(command, '-echo');
        if status ~= 0
            fprintf('Error executing %s/bin/fslmaths to calculate RD\n', fsldir);
            delete(wbh);
            return;
        end
        
        waitbar(0.55,wbh);
        
        command = sprintf('%s %s %s', fullfile(fsldir, 'bin', 'fslmaths'), char(fullfile(ds_folder, strcat(dti_folder_prefix, '_L1.nii.gz'))), char(fullfile(ds_folder, strcat(dti_folder_prefix, '_AD.nii.gz'))));
        fprintf(command);
        fprintf('\n');
        [status, ~] = system(command, '-echo');
        if status ~= 0
            fprintf('Error executing %s/bin/fslmaths to calculate AD\n', fsldir);
            delete(wbh);
            return;
        end
        
        waitbar(0.7,wbh);
        
        % display FA and V1 for verification
        fa_zip = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_FA.nii.gz')));
        if ~exist(fa_zip, 'file')
            fa = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_FA.nii')));
            if ~exist(fa, 'file')
                fprintf('Attempt to use file that does not exist %s\n', fa);
                delete(wbh);
                return;
            end
            fa_file = fa;
        else
            fa_file = getUnzipped(fa_zip);
        end
        
        v1_zip = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_V1.nii.gz')));
        if ~exist(v1_zip, 'file')
            v1 = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_V1.nii')));
            if ~exist(v1, 'file')
                fprintf('Attempt to unzip file that does not exist %s\n', v1_zip);
                delete(wbh);
                return;
            end
            v1_file = v1;
        else
            v1_file = getUnzipped(v1_zip);
        end
        
        if isempty(bedpostx_dir) && (dti_reg_mri || dti_reg_std) 
            bedpostx_dir = uigetdir('title', 'Select Subject''s bedpostX folder');
            if isequal(bedpostx_dir, 0)
                delete(wbh);
                return;
            end
        end
        
        % register dtifit output to standard space
        if dti_reg_mri

            if ~exist( char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')), 'file')
                fprintf('Must have diff2str conversion matrix to register to standard space\n');
                delete(wbh);
                return;
            end
            if isempty(mri_ref_file) || isempty(reg_dir)
                [filename, filepath] = uigetfile({'*.nii', 'Structural Space Reference (*.nii)'; '*.nii.gz', 'Structural Space Reference (*.nii.gz)'}, 'Select Structural Space Reference (Brain Extracted)');
                if isequal(filename, 0) || isequal(filepath, 0)
                    delete(wbh);
                    return;
                end
                mri_ref_file = char(fullfile(filepath, filename));
                mri_ref_file = getUnzipped(mri_ref_file);            
            end
            
            result = register_diff2mri;
            if ~result
              delete(wbh);
              return;
            end
            waitbar(0.85,wbh);
        end
        
        % register dtifit output to structural space
        if dti_reg_std
            
            if ~exist( char(fullfile(bedpostx_dir, 'xfms','diff2standard.mat')), 'file')
                fprintf('Must have diff2str conversion matrix to register to standard space\n');
                delete(wbh);
                return;
            end
            if isempty(std_ref_file) || isempty(reg_dir)
                [filename, filepath] = uigetfile({'*.nii', 'Standard Space Reference (*.nii)'; '*.nii.gz', 'Standard Space Reference (*.nii.gz)'}, 'Select Standard Space Reference (Brain Extracted)');
                if isequal(filename, 0) || isequal(filepath, 0)
                    delete(wbh);
                    return;
                end
                std_ref_file = char(fullfile(filepath, filename));
                std_ref_file = getUnzipped(std_ref_file);
            end
            
            result = register_diff2std;
            if ~result
              delete(wbh);
              return;
            end
        end
        
        waitbar(1,wbh);
        
        delete(wbh);
        
        % display structural space registered FA and V1 on standard ref
        if dti_reg_mri
            fa_mri_zip = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_FA_str.nii.gz')));
            fa_mri_file = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_FA_str.nii')));
            if ~exist(fa_mri_zip, 'file')
                if ~exist(fa_mri_file, 'file')
                    fprintf('Attempt to unzip file that does not exist %s\n', fa_mri_zip);
                    return;
                end
            else
                fa_mri_file = getUnzipped(fa_mri_zip);
            end
            
            v1_mri_zip = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_V1_str.nii.gz')));
            v1_mri_file = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_V1_str.nii')));
            if ~exist(v1_mri_zip, 'file')
                if ~exist(v1_mri_file, 'file')
                    fprintf('Attempt to unzip file that does not exist %s\n', v1_mri_zip);
                    return;
                end
            else
                v1_mri_file = getUnzipped(v1_mri_zip);
            end

            l = size(files,2);
            n = sprintf('%s V1 Modulated by FA (structural)', dti_file_prefix);
            files(l+1) = {n};
            
            loaded_files{size(loaded_files,1)+1,1} = 8;
            loaded_files{size(loaded_files,1),2} = {mri_ref_file};
            loaded_files{size(loaded_files,1),3} = {fa_mri_file};
            loaded_files{size(loaded_files,1),4} = {v1_mri_file};
            
        end
        
        % display standard space registered FA and V1 on structural ref
        if dti_reg_std
            
            fa_std_zip = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_FA_mni.nii.gz')));
            fa_std_file = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_FA_mni.nii')));
            if ~exist(fa_std_zip, 'file')
                if ~exist(fa_std_file, 'file')
                    fprintf('Attempt to unzip file that does not exist %s\n', fa_std_zip);
                    return;
                end
            else
                fa_std_file = getUnzipped(fa_std_zip);
            end
            
            v1_std_zip = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_V1_mni.nii.gz')));
            v1_std_file = char(fullfile(ds_folder, strcat(dti_folder_prefix, '_V1_mni.nii')));
            if ~exist(v1_std_zip, 'file')
                if ~exist(v1_std_file, 'file')
                    fprintf('Attempt to unzip file that does not exist %s\n', v1_std_zip);
                    return;
                end
            else
                v1_std_file =getUnzipped(v1_std_zip);
            end
            
            
            l = size(files,2);
            n = sprintf('%s V1 Modulated by FA (standard)', dti_file_prefix);
            files(l+1) = {n};

            loaded_files{size(loaded_files,1)+1,1} = 8;
            loaded_files{size(loaded_files,1),2} = {std_ref_file};
            loaded_files{size(loaded_files,1),3} = {fa_std_file};
            loaded_files{size(loaded_files,1),4} = {v1_std_file};
            
        end

        % reset drawing settings
        if drawing
            set(UNDO_BUTTON, 'enable', 'off');
            set(CLEAR_BUTTON, 'enable', 'off');
            set(CREATE_MASK_BUTTON, 'string', 'Draw');
            prev = [];
            drawing = 0;
            set(f,'WindowButtonDownFcn', @buttondown);
        end
        
        % display diffusion space FA and V1
        display_mode = 7;
        loadDTIOverlay(fa_file, v1_file);
        
        l = size(files,2);
        n = sprintf('%s V1 Modulated by FA', dti_file_prefix);
        files(l+1) = {n};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        
        loaded_files{size(loaded_files,1)+1,1} = 7;
        loaded_files{size(loaded_files,1),2} = {fa_file};
        loaded_files{size(loaded_files,1),3} = {v1_file};
        
        set(VOLUME_EDIT, 'String', '0');
        set(LOOP_BUTTON, 'enable', 'off');
    end

    % register dtifit output to standard space
    function result = register_diff2std
        
        result = 1;
      
        % find diff2standard registration matrix
        if ~exist(bedpostx_dir, 'dir') || ~exist( char(fullfile(bedpostx_dir, 'xfms','diff2standard.mat')), 'file')
            fprintf('Must have run bedpostx and created diff2standard matrix to register dtifit output\n');
            result = 0;
            return;
        end
        
        % register FA, AD, MD and RD to mni space
        command = sprintf('%s -interp nearestneighbour -in %s.nii.gz -ref %s -applyxfm -out %s -init %s.mat -noresample -noresampblur',fullfile(fsldir, 'bin', 'flirt'),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_FA'))), std_ref_file,...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_FA_mni'))), ...
            char(fullfile(bedpostx_dir, 'xfms','diff2standard')));
        fprintf('\nRunning FSL version %g flirt for registration to standard space...\n%s\n', FSLVer, command);

        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/flirt for registration of FA to standard space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -interp nearestneighbour -in %s.nii.gz -ref %s -applyxfm -out %s -init %s.mat -noresample -noresampblur',fullfile(fsldir, 'bin', 'flirt'),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_MD'))), std_ref_file, ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_MD_mni'))),...
            char(fullfile(bedpostx_dir, 'xfms','diff2standard')));
        fprintf('%s\n', command);

        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/flirt for registration of MD to standard space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -interp nearestneighbour -in %s.nii.gz -ref %s -applyxfm -out %s -init %s.mat -noresample -noresampblur', fullfile(fsldir, 'bin', 'flirt'), ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_RD'))), std_ref_file, ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_RD_mni'))),...
            char(fullfile(bedpostx_dir, 'xfms','diff2standard')));
        fprintf('%s\n', command);

        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/flirt for registration of RD to standard space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -interp nearestneighbour -in %s.nii.gz -ref %s -applyxfm -out %s -init %s.mat -noresample -noresampblur', fullfile(fsldir, 'bin', 'flirt'), ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_AD'))), std_ref_file, ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_AD_mni'))),...
            char(fullfile(bedpostx_dir, 'xfms','diff2standard')));
        fprintf('%s\n', command);

        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/flirt for registration of AD to standard space\n', fsldir);
            result = 0;
            return;
        end
        
        % register eigenvectors (V1, V2, V3) to standard space
        command = sprintf('%s -i %s -o %s -r %s -t %s', fullfile(fsldir, 'bin', 'vecreg'), char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V1.nii.gz'))), ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V1_mni'))), std_ref_file, ...
            char(fullfile(bedpostx_dir, 'xfms','diff2standard.mat')));
        fprintf('\nRunning FSL version %g vecreg for registration of diffusion eigenvectors to standard space...\n%s\n', FSLVer, command);
        
        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/vecreg for registration of V1 to standard space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -i %s -o %s -r %s -t %s', fullfile(fsldir, 'bin', 'vecreg'), char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V2.nii.gz'))), ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V2_mni'))), std_ref_file, ...
            char(fullfile(bedpostx_dir, 'xfms','diff2standard.mat')));
        fprintf('%s\n', command);
        
        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/vecreg for registration of V2 to standard space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -i %s -o %s -r %s -t %s', fullfile(fsldir, 'bin', 'vecreg'), char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V3.nii.gz'))),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V3_mni'))), std_ref_file, ...
            char(fullfile(bedpostx_dir, 'xfms','diff2standard.mat')));
        fprintf('%s\n', command);
        
        [status, result] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/vecreg for registration of V3 to standard space\n', fsldir);
            result = 0;
            return;
        end

    end

    % register dtifit output to structural space
    function result = register_diff2mri
        
        result = 1;
      
        % find diff2str registration matrix
        bedpostx_folder = char(bedpostx_dir);
        if ~exist(bedpostx_folder, 'dir') || ~exist( char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')), 'file')
            fprintf('Must have run bedpostx and created diff2str.mat matrix to register dtifit output\n');
            result = 0;
            return;
        end
        
        % register anisotropy files (FA, AD, RD, MD) to structural space
        command = sprintf('%s -interp nearestneighbour -in %s.nii.gz -ref %s -applyxfm -out %s -init %s -noresample -noresampblur',...
            fullfile(fsldir, 'bin', 'flirt'), char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_FA'))),...
            mri_ref_file, char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_FA_str'))),...
            char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')));
        fprintf('\nRunning FSL version %g flirt for registration to structural space...\n%s\n', FSLVer, command);
        
        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/flirt for registration of FA to structural space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -interp nearestneighbour -in %s.nii.gz -ref %s -applyxfm -out %s -init %s -noresample -noresampblur',fullfile(fsldir, 'bin', 'flirt'),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_MD'))), mri_ref_file, ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_MD_str'))),...
            char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')));
        fprintf('%s\n', command);
        
        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/flirt for registration of MD to structural space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -interp nearestneighbour -in %s.nii.gz -ref %s -applyxfm -out %s -init %s -noresample -noresampblur',fullfile(fsldir, 'bin', 'flirt'),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_AD'))), mri_ref_file, ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_AD_str'))), ...
            char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')));
        fprintf('%s\n', command);
        
        [status, ~] = system(command, '-echo');
        
        if status ~= 0
            fprintf('Error executing %s/bin/flirt for registration of AD to structural space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -interp nearestneighbour -in %s.nii.gz -ref %s -applyxfm -out %s -init %s -noresample -noresampblur',fullfile(fsldir, 'bin', 'flirt'),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_RD'))), mri_ref_file, ...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_RD_str'))), ...
            char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')));
        fprintf('%s\n',  command);
        
        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/flirt for registration of RD to structural space\n', fsldir);
            result = 0;
            return;
        end
        
        % register eigenvectors (V1, V2, V3) to structural space
        command = sprintf('%s -i %s -o %s -r %s -t %s', fullfile(fsldir, 'bin', 'vecreg'), char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V1.nii.gz'))),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V1_str'))), mri_ref_file, ...
            char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')));
        fprintf('\nRunning FSL version %g vecreg for registration of diffusion eigenvectors to structural space...\n%s\n', FSLVer, command);
        
        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/vecreg for registration of V1 to structural space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -i %s -o %s -r %s -t %s', fullfile(fsldir, 'bin', 'vecreg'), char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V2.nii.gz'))),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V2_str'))), mri_ref_file, ...
            char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')));
        fprintf('%s\n', command);
        
        [status, ~] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/vecreg for registration of V2 to structural space\n', fsldir);
            result = 0;
            return;
        end
        
        command = sprintf('%s -i %s -o %s -r %s -t %s', fullfile(fsldir, 'bin', 'vecreg'), char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V3.nii.gz'))),...
            char(fullfile(ds_folder, strcat(fullfile(dti_folder_name, dti_file_prefix), '_V3_str'))), mri_ref_file, ...
            char(fullfile(bedpostx_dir, 'xfms','diff2str.mat')));
        fprintf('%s\n', command);
        
        [status, result] = system(command, '-echo');

        if status ~= 0
            fprintf('Error executing %s/bin/vecreg for registration of V3 to structural space\n', fsldir);
            result = 0;
            return;
        end
    end

        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% build and run probtrackx command        
      

    % open new GUI for running probabilistic tractography
    function probtrackx_callback(~, ~)
        
        % find bedpostx directory
        if isempty(bedpostx_dir)     
            dir = uigetdir('title', 'Select Subject''s BedpostX directory');
            if isequal(dir, 0)
                fprintf('Must run bedpostX before probtrackX\n');
                return;
            end
            bedpostx_dir = dir;
        end

        % probtrackx variables
        num_samples = 5000;
        curv_thresh = 0.2;
        loopcheck = true;
        verbose = false;
        modeuler = false;
        max_steps = 2000;
        step_length = 0.5;
        use_aniso = false;
        use_distance = true;
        
        % other defaults - need to add to dialog?
        force_wayorder = true;
        fibthresh = 0.1;
        distthresh = 0.0; 
        sampvox = 0.0;
       
        % files
        seed_masks = {};
        seed_masks_disp = {};
        wp_masks = {};
        wp_masks_disp = {};
        ta_masks = {};
        ta_masks_disp = {};
        ex_mask = [];
        ex_mask_disp = {'None', 'Select Exclusion Mask...'};
        term_mask = [];
        term_mask_disp = {'None', 'Select Termination Mask...'};
        xfm = [];
        
        % popup GUI
        scrsz = get(0,'ScreenSize');
        f2=figure('Name', 'Probabilistic Tractography', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-400)/2 800 400],...
            'menubar','none','numbertitle','off', 'Color','white');
        
        % Seed Masks listbox
        uicontrol('style', 'text', 'string', 'Seed Mask(s): ', 'fontName','lucinda','Units','Normalized','Position',...
            [0.04 0.9 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        SEED_MASK_LIST = uicontrol('style', 'listbox', 'string', seed_masks_disp, 'fontName','lucinda','Units','Normalized','Position',...
            [0.19 0.74 0.3 0.2],'HorizontalAlignment','Center','BackgroundColor',...
            'White','min',1,'max',100);
        
        uicontrol('style', 'pushbutton', 'string', 'ADD', 'fontName','lucinda','Units','Normalized','Position',...
            [0.44 0.69 0.05 0.04],'HorizontalAlignment','Center','BackgroundColor',...
            'White', 'ForegroundColor', 'red', 'Callback',@add_seed_callback);
        
        % add seed mask to list
        function add_seed_callback(~,~)
            f3=figure('Name', 'DTI Preprocessor Files', 'Position', [(scrsz(3)-400)/2 (scrsz(4)-400)/2 400 400],...
                'menubar','none','numbertitle','off', 'Color','white');
            FILE_LISTBOX2=uicontrol('Style','Listbox','fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.15 0.9 0.8],'String',files, 'value', 1, 'HorizontalAlignment','Center','BackgroundColor',...
                'White','min',1,'max',10);
            ADD_BUTTON = uicontrol('style', 'pushbutton', 'string', 'ADD', 'fontName','lucinda','Units','Normalized','Position',...
                [0.8 0.05 0.1 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'red', 'Callback',@addfiles_callback);
            
            % add from file listbox
            function addfiles_callback(~,~)
                values = get(FILE_LISTBOX2, 'value');
                
                for i=1:size(values,2)
                    mode = loaded_files{values(i),1}; 
                    if mode == 4 || mode == 5 || mode == 7 || mode == 8
                        fprintf('Error: could not add file. Make sure is a mask file\n');
                        return;
                    end
                    seed_masks(size(seed_masks,2)+1) = {char(loaded_files{values(i), 2})};
                    seed_masks_disp(size(seed_masks_disp,2)+1) = files(values(i));
                end
                
                if size(seed_masks,2) > 1
                    set(TARGET_MASK_LIST, 'enable', 'off');
                    set(TARGET_ADD, 'enable', 'off');
                    set(TARGET_REM, 'enable', 'off');
                end
                set(SEED_MASK_LIST, 'string', seed_masks_disp);
                close(f3);
            end
            
            OTHER_BUTTON = uicontrol('style', 'pushbutton', 'string', 'Other', 'fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.05 0.15 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'black', 'Callback',@otherfiles_callback);
            
            % add from file directory
            function otherfiles_callback(~,~)
                [filename, filepath] = uigetfile({'*.nii', 'Mask File (*.nii)'; '*.nii.gz', 'Mask File (*.nii.gz'}, 'Select Seed Mask File');
                if isequal(filename, 0) || isequal(filepath, 0)
                    return;
                end
                
                file = fullfile(filepath, filename);
                [~, n, ~] = fileparts(file);

                % add to probtrackx GUI
                seed_masks(size(seed_masks,2)+1) = {file};
                seed_masks_disp(size(seed_masks_disp,2)+1) = {n};
                set(SEED_MASK_LIST, 'string', seed_masks_disp);
                
                % add to main GUI
                files(size(files,2)+1) = {n};
                loaded_files{size(loaded_files,1)+1,1} = 0;
                loaded_files{size(loaded_files,1),2} = {file};
                set(FILE_LISTBOX, 'string', files);
                
                if size(seed_masks,2) > 1
                    set(TARGET_MASK_LIST, 'enable', 'off');
                    set(TARGET_ADD, 'enable', 'off');
                    set(TARGET_REM, 'enable', 'off');
                end
                close(f3);
            end
        
        end
        
        uicontrol('style', 'pushbutton', 'string', '- remove', 'fontName','lucinda','Units','Normalized','Position',...
            [0.19 0.69 0.1 0.04],'HorizontalAlignment','Center','BackgroundColor',...
            'White', 'ForegroundColor', 'blue', 'Callback',@remove_seed_callback);
        
        % remove seed mask from list
        function remove_seed_callback(~,~)
            num = get(SEED_MASK_LIST, 'value');
            
            if isempty(seed_masks_disp) || size(seed_masks_disp, 2)<num
                return;
            end

            if isempty(num)
                    return;
            end

            % shift files in list
            for i=num:size(seed_masks_disp, 2)-1
                seed_masks_disp(i) = seed_masks_disp(i+1);
                seed_masks(i) = seed_masks(i+1);
            end
            seed_masks_disp(size(seed_masks_disp,2)) = [];
            seed_masks(size(seed_masks,2)) = [];

            while num > size(seed_masks_disp,2) && num > 1
                num = num -1;
            end

            set(SEED_MASK_LIST, 'value', num);
            set(SEED_MASK_LIST, 'string', seed_masks_disp);
            
            if size(seed_masks,2) <= 1
                set(TARGET_MASK_LIST, 'enable', 'on');
                set(TARGET_ADD, 'enable', 'on');
                set(TARGET_REM, 'enable', 'on');
            end
        end
        
        % Waypoint Masks listbox
        uicontrol('style', 'text', 'string', 'Waypoint Mask(s): ', 'fontName','lucinda','Units','Normalized','Position',...
            [0.04 0.59 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        WP_MASK_LIST = uicontrol('style', 'listbox', 'string', wp_masks_disp, 'fontName','lucinda','Units','Normalized','Position',...
            [0.19 0.43 0.3 0.2],'HorizontalAlignment','Center','BackgroundColor',...
            'White','min',1,'max',100);
        
        uicontrol('style', 'pushbutton', 'string', 'ADD', 'fontName','lucinda','Units','Normalized','Position',...
            [0.44 0.38 0.05 0.04],'HorizontalAlignment','Center','BackgroundColor',...
            'White','ForegroundColor', 'red','Callback',@add_waypoint_callback);
        
        % add waypoint masks to list
        function add_waypoint_callback(~,~)
            f4=figure('Name', 'DTI Preprocessor Files', 'Position', [(scrsz(3)-400)/2 (scrsz(4)-400)/2 400 400],...
                'menubar','none','numbertitle','off', 'Color','white');
            FILE_LISTBOX3=uicontrol('Style','Listbox','fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.15 0.9 0.8],'String',files, 'value', 1, 'HorizontalAlignment','Center','BackgroundColor',...
                'White','min',1,'max',10);
            ADD_BUTTON = uicontrol('style', 'pushbutton', 'string', 'ADD', 'fontName','lucinda','Units','Normalized','Position',...
                [0.8 0.05 0.1 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'red', 'Callback',@addfiles_callback);
            
            % add mask from file listbox
            function addfiles_callback(~,~)
                values = get(FILE_LISTBOX3, 'value');
                
                for i=1:size(values,2)
                    mode = loaded_files{values(i),1}; 
                    if mode == 4 || mode == 5 || mode == 7 || mode == 8
                        fprintf('Error: could not add file. Make sure is a mask file\n');
                        return;
                    end

                    wp_masks(size(wp_masks,2)+1) = {char(loaded_files{values(i),2})};
                    wp_masks_disp(size(wp_masks_disp,2)+1) = files(values(i));
                end
                
                set(WP_MASK_LIST, 'string', wp_masks_disp);
                close(f4);
            end
            
            OTHER_BUTTON = uicontrol('style', 'pushbutton', 'string', 'Other', 'fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.05 0.15 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'black', 'Callback',@otherfiles_callback);
            
            % add mask from file directory
            function otherfiles_callback(~,~)
                [filename, filepath] = uigetfile({'*.nii', 'Mask File (*.nii)'; '*.nii.gz', 'Mask File (*.nii.gz'}, 'Select Waypoint Mask File');
                if isequal(filename, 0) || isequal(filepath, 0)
                    return;
                end
                
                file = fullfile(filepath, filename);
                [~, n, ~] = fileparts(file);
    
                % add to probtrackx GUI
                wp_masks(size(wp_masks,2)+1) = {file};
                wp_masks_disp(size(wp_masks_disp,2)+1) = {n};
                set(WP_MASK_LIST, 'string', wp_masks_disp);
                
                % add to main GUI
                files(size(files,2)+1) = {n};
                loaded_files{size(loaded_files,1)+1,1} = 0;
                loaded_files{size(loaded_files,1),2} = {file};
                set(FILE_LISTBOX, 'string', files);
                close(f4);
            end
        end
        
        uicontrol('style', 'pushbutton', 'string', '- remove', 'fontName','lucinda','Units','Normalized','Position',...
            [0.19 0.38 0.1 0.04],'HorizontalAlignment','Center','BackgroundColor',...
            'White','ForegroundColor', 'blue','Callback',@remove_waypoint_callback);
        
        % remove waypoint mask from list
        function remove_waypoint_callback(~,~)
            num = get(WP_MASK_LIST, 'value');
            
            if isempty(wp_masks) || size(wp_masks, 2)<num
                return;
            end

            if isempty(num)
                return;
            end

            % shift files in list
            for i=num:size(wp_masks, 2)-1
                wp_masks(i) = wp_masks(i+1);
                wp_masks_disp(i) = wp_masks_disp(i+1);
            end
            wp_masks(size(wp_masks,2)) = [];
            wp_masks_disp(size(wp_masks_disp,2)) = [];

            while num > size(wp_masks_disp,2) && num > 1
                num = num -1;
            end

            set(WP_MASK_LIST, 'value', num);
            set(WP_MASK_LIST, 'string', wp_masks_disp);
        end
        
        % Target Masks listbox
        uicontrol('style', 'text', 'string', 'Target Mask(s): ', 'fontName','lucinda','Units','Normalized','Position',...
            [0.51 0.9 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        TARGET_MASK_LIST = uicontrol('style', 'listbox', 'string', ta_masks_disp, 'fontName','lucinda','Units','Normalized','Position',...
            [0.67 0.74 0.3 0.2],'HorizontalAlignment','Center','BackgroundColor',...
            'White','min',1,'max',100);
        
        TARGET_ADD = uicontrol('style', 'pushbutton', 'string', 'ADD', 'fontName','lucinda','Units','Normalized','Position',...
            [0.92 0.69 0.05 0.04],'HorizontalAlignment','Center','BackgroundColor',...
            'White', 'ForegroundColor', 'red', 'Callback',@add_target_callback);
        
        % add target mask to list
        function add_target_callback(~,~)
            f5=figure('Name', 'DTI Preprocessor Files', 'Position', [(scrsz(3)-400)/2 (scrsz(4)-400)/2 400 400],...
                'menubar','none','numbertitle','off', 'Color','white');
            FILE_LISTBOX4=uicontrol('Style','Listbox','fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.15 0.9 0.8],'String',files, 'value', 1, 'HorizontalAlignment','Center','BackgroundColor',...
                'White','min',1,'max',10);
            uicontrol('style', 'pushbutton', 'string', 'ADD', 'fontName','lucinda','Units','Normalized','Position',...
                [0.8 0.05 0.1 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'red', 'Callback',@addfiles_callback);
            
            % add from file listbox
            function addfiles_callback(~,~)
                values = get(FILE_LISTBOX4, 'value');
                
                for i=1:size(values,2)
                    mode = loaded_files{values(i),1}; 
                    if mode == 4 || mode == 5 || mode == 7 || mode == 8
                        fprintf('Error: could not add file. Make sure is a mask file\n');
                        return;
                    end
                    ta_masks(size(ta_masks,2)+1) = {char(loaded_files{values(i), 2})};
                    ta_masks_disp(size(ta_masks_disp,2)+1) = files(values(i));
                end
                
                set(TARGET_MASK_LIST, 'string', ta_masks_disp);
                close(f5);
            end
            
            OTHER_BUTTON = uicontrol('style', 'pushbutton', 'string', 'Other', 'fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.05 0.15 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'black', 'Callback',@otherfiles_callback);
            
            % add from file directory
            function otherfiles_callback(~,~)
                [filename, filepath] = uigetfile({'*.nii', 'Mask File (*.nii)'; '*.nii.gz', 'Mask File (*.nii.gz'}, 'Select Target Mask File');
                if isequal(filename, 0) || isequal(filepath, 0)
                    return;
                end
                
                file = fullfile(filepath, filename);
                [~, n, ~] = fileparts(file);

                % add to probtrackx GUI
                ta_masks(size(ta_masks,2)+1) = {file};
                ta_masks_disp(size(ta_masks_disp,2)+1) = {n};
                set(TARGET_MASK_LIST, 'string', ta_masks_disp);
                
                % add to main GUI
                files(size(files,2)+1) = {n};
                loaded_files{size(loaded_files,1)+1,1} = 0;
                loaded_files{size(loaded_files,1),2} = {file};
                set(FILE_LISTBOX, 'string', files);
                
                close(f5);
            end
        
        end
        
        TARGET_REM = uicontrol('style', 'pushbutton', 'string', '- remove', 'fontName','lucinda','Units','Normalized','Position',...
            [0.67 0.69 0.1 0.04],'HorizontalAlignment','Center','BackgroundColor',...
            'White', 'ForegroundColor', 'blue', 'Callback',@remove_target_callback);
        
        % remove target mask from list
        function remove_target_callback(~,~)
            num = get(TARGET_MASK_LIST, 'value');
            
            if isempty(ta_masks_disp) || size(ta_masks_disp, 2)<num
                return;
            end

            if isempty(num)
                    return;
            end

            % shift files in list
            for i=num:size(ta_masks_disp, 2)-1
                ta_masks_disp(i) = ta_masks_disp(i+1);
                ta_masks(i) = ta_masks(i+1);
            end
            ta_masks_disp(size(ta_masks_disp,2)) = [];
            ta_masks(size(ta_masks,2)) = [];

            while num > size(ta_masks_disp,2) && num > 1
                num = num -1;
            end

            set(TARGET_MASK_LIST, 'value', num);
            set(TARGET_MASK_LIST, 'string', ta_masks_disp);
        end

        % exclusion mask
        uicontrol('style', 'text', 'string', 'Exclusion Mask: ', 'fontName','lucinda','Units','Normalized','Position',...
            [0.51 0.59 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        EX_MASK_POPUP = uicontrol('style','popup','units','normalized',...
            'position',[0.67 0.6 0.29 0.03],'String', ex_mask_disp, 'Backgroundcolor','white',...
            'fontsize',11,'value',1,'callback',@select_exclusion_callback);
        
        % select an exclusion mask
        function select_exclusion_callback(src,~)
            if ~strcmp(ex_mask_disp(get(src, 'value')), 'Select Exclusion Mask...')
                return;
            end
            
            f5=figure('Name', 'DTI Preprocessor Files', 'Position', [(scrsz(3)-400)/2 (scrsz(4)-400)/2 400 400],...
                'menubar','none','numbertitle','off', 'Color','white');
            FILE_LISTBOX5=uicontrol('Style','Listbox','fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.15 0.9 0.8],'String',files, 'value', 1, 'HorizontalAlignment','Center','BackgroundColor',...
                'White','min',1,'max',10);
            uicontrol('style', 'pushbutton', 'string', 'Select', 'fontName','lucinda','Units','Normalized','Position',...
                [0.8 0.05 0.15 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'red', 'Callback',@addfiles_callback);
            
            % select exclusion mask from file listbox
            function addfiles_callback(~,~)
                values = get(FILE_LISTBOX5, 'value');

                mode = loaded_files{values,1}; 
                if mode == 4 || mode == 5 || mode == 7 || mode == 8
                    fprintf('Error: could not add file. Make sure is a mask file\n');
                    return;
                end
                
                ex_mask = char(loaded_files{values(1),2});
                ex_mask_disp(2) = files(values(1));
                ex_mask_disp(3) = {'Select Exclusion Mask...'};
                
                set(EX_MASK_POPUP, 'value', 2);
                set(EX_MASK_POPUP, 'string', ex_mask_disp);
                close(f5);
            end
            
            uicontrol('style', 'pushbutton', 'string', 'Other', 'fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.05 0.15 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'black', 'Callback',@otherfiles_callback);
            
            % select exclusion mask from file directory
            function otherfiles_callback(~,~)
                [filename, filepath] = uigetfile({'*.nii', 'Mask File (*.nii)'; '*.nii.gz', 'Mask File (*.nii.gz'}, 'Select Exclusion Mask File');
                if isequal(filename, 0) || isequal(filepath, 0)
                    return;
                end

                file = fullfile(filepath, filename);
                [~, n, ~] = fileparts(file);

                % add to probtrackx GUI
                ex_mask = file;
                ex_mask_disp(2) = {n};
                ex_mask_disp(3) = {'Select Exclusion Mask...'};
                set(EX_MASK_POPUP, 'value', 2);
                set(EX_MASK_POPUP, 'string', ex_mask_disp);

                % add to main GUI
                files(size(files,2)+1) = {n};
                loaded_files{size(loaded_files,1)+1,1} = 0;
                loaded_files{size(loaded_files,1),2} = {file};
                set(FILE_LISTBOX, 'string', files);
                close(f5);
            end

        end
        
        % termination mask
        uicontrol('style', 'text', 'string', 'Termination Mask: ', 'fontName','lucinda','Units','Normalized','Position',...
            [0.51 0.52 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        TERM_MASK_POPUP = uicontrol('style','popup','units','normalized',...
            'position',[0.67 0.53 0.29 0.03],'String', term_mask_disp, 'Backgroundcolor','white',...
            'fontsize',11,'value',1,'callback',@select_termination_callback);
        
        % select termination mask
        function select_termination_callback(src,~)
            if ~strcmp(term_mask_disp(get(src, 'value')), 'Select Termination Mask...')
                return;
            end
            
            f6=figure('Name', 'DTI Preprocessor Files', 'Position', [(scrsz(3)-400)/2 (scrsz(4)-400)/2 400 400],...
                'menubar','none','numbertitle','off', 'Color','white');
            FILE_LISTBOX6=uicontrol('Style','Listbox','fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.15 0.9 0.8],'String',files, 'value', 1, 'HorizontalAlignment','Center','BackgroundColor',...
                'White','min',1,'max',10);
            uicontrol('style', 'pushbutton', 'string', 'Select', 'fontName','lucinda','Units','Normalized','Position',...
                [0.8 0.05 0.15 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'red', 'Callback',@addfiles_callback);
            
            % select termination mask from file listbox
            function addfiles_callback(~,~)
                values = get(FILE_LISTBOX6, 'value');
                
                mode = loaded_files{values,1}; 
                if mode == 4 || mode == 5 || mode == 7 || mode == 8
                    fprintf('Error: could not add file. Make sure is a mask file\n');
                    return;
                end
                
                term_mask = char(loaded_files{values(1),2});
                term_mask_disp(2) = files(values(1));
                term_mask_disp(3) = {'Select Termination Mask...'};
                
                set(TERM_MASK_POPUP, 'value', 2);
                set(TERM_MASK_POPUP, 'string', term_mask_disp);
                close(f6);
            end
            
            uicontrol('style', 'pushbutton', 'string', 'Other', 'fontName','lucinda','Units','Normalized','Position',...
                [0.05 0.05 0.15 0.08],'HorizontalAlignment','Center','BackgroundColor',...
                'White','ForegroundColor', 'black', 'Callback',@otherfiles_callback);
            
            % select termination mask from file directory
            function otherfiles_callback(~,~)
                [filename, filepath] = uigetfile({'*.nii', 'Mask File (*.nii)'; '*.nii.gz', 'Mask File (*.nii.gz'}, 'Select Termination Mask File');
                if isequal(filename, 0) || isequal(filepath, 0)
                    return;
                end

                file = fullfile(filepath, filename);
                [~, n, ~] = fileparts(file);

                % add to probtrackx GUI
                term_mask = file;
                term_mask_disp(2) = {n};
                term_mask_disp(3) = {'Select Termination Mask...'};
                set(TERM_MASK_POPUP, 'value', 2);
                set(TERM_MASK_POPUP, 'string', term_mask_disp);

                % add to main GUI
                files(size(files,2)+1) = {n};
                loaded_files{size(loaded_files,1)+1,1} = 0;
                loaded_files{size(loaded_files,1),2} = {file};
                set(FILE_LISTBOX, 'string', files);
                close(f6);
            end
        end
        
        % space toggles
        uicontrol('style', 'text', 'string', 'Mask Space: ', 'fontName','lucinda','Units','Normalized','Position',...
            [0.51 0.45 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        space_bg = uibuttongroup('Position', [0.67 0.355 0.15 0.13], 'SelectionChangeFcn', @space_bselection, 'BorderType', 'none');
        diff_toggle = uicontrol(space_bg, 'Style','radiobutton','units','normalized','fontname','lucinda','Position',...
            [0 0.66 1 0.33],'String','Diffusion','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor','white','ForegroundColor','Black', 'Value', 1);
        mri_toggle = uicontrol(space_bg, 'Style','radiobutton','units','normalized','fontname','lucinda','Position',...
            [0 0.33 1 0.33],'String','Structural','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor','White','ForegroundColor','Black','Value', 0);
        std_toggle = uicontrol(space_bg, 'Style','radiobutton','units','normalized','fontname','lucinda','Position',...
            [0 0 1 0.33],'String','Standard','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor','White','ForegroundColor','Black', 'Value', 0);
        space_bg.Visible = 'on';
        
        % choose space
        function space_bselection(~,evt)
             if evt.NewValue==diff_toggle
                xfm = [];
             elseif evt.NewValue==mri_toggle
                xfm = fullfile(bedpostx_dir, 'xfms', 'str2diff.mat');
             elseif evt.NewValue==std_toggle
                xfm = fullfile(bedpostx_dir, 'xfms', 'standard2diff.mat');
             end
        end
        
        % Other Options
        uicontrol('style', 'text', 'string', 'Num. Samples', 'fontName','lucinda','Units','Normalized','Position',...
            [0.04 0.24 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        uicontrol('style','edit','units','normalized','position',[0.19 0.24 0.08 0.05],'String', num_samples,...
            'FontSize', 11, 'BackGroundColor','white', 'callback',@samples_edit_callback);
        function samples_edit_callback(src,~)
            if isempty(get(src,'string'))
                return;
            end
            num_samples = str2double(get(src,'string'));
        end
        
        uicontrol('style', 'text', 'string', 'Curv. Thresh.', 'fontName','lucinda','Units','Normalized','Position',...
            [0.04 0.16 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        uicontrol('style','edit','units','normalized','position',[0.19 0.16 0.08 0.05],'String', curv_thresh,...
            'FontSize', 11, 'BackGroundColor','white', 'callback',@cthresh_edit_callback);
        function cthresh_edit_callback(src,~)
            if isempty(get(src,'string'))
                return;
            end
            curv_thresh = str2double(get(src,'string'));
        end
        
        uicontrol('style', 'text', 'string', 'Max. Num. Steps', 'fontName','lucinda','Units','Normalized','Position',...
            [0.04 0.08 0.15 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        uicontrol('style','edit','units','normalized','position',[0.19 0.08 0.08 0.05],'String', max_steps,...
            'FontSize', 11, 'BackGroundColor','white','callback',@steps_edit_callback);
        function steps_edit_callback(src,~)
            if isempty(get(src,'string'))
                return;
            end
            max_steps = str2double(get(src,'string'));
        end
        
        uicontrol('style', 'text', 'string', 'Step Length', 'fontName','lucinda','Units','Normalized','Position',...
            [0.29 0.24 0.1 0.04],'HorizontalAlignment','Left','BackgroundColor','White');
        uicontrol('style','edit','units','normalized','position',[0.38 0.24 0.08 0.05],'String', step_length,...
            'FontSize', 11, 'BackGroundColor','white','callback',@step_length_edit_callback);
        function step_length_edit_callback(src,~)
            if isempty(get(src,'string'))
                return;
            end
            step_length = str2double(get(src,'string'));
        end

        uicontrol('Style', 'checkbox', 'String', 'Loopcheck', 'units', 'normalized','Position', [0.29 0.16 0.15 0.04], ...
            'Value', loopcheck, 'FontWeight', 'normal','background','white',...
            'horizontalalignment','left', 'callback', @loopcheck_callback);
        function loopcheck_callback(src,~)
            loopcheck = get(src,'Value');
        end
        
        uicontrol('Style', 'checkbox', 'String', 'Verbose', 'units', 'normalized','Position', [0.29 0.08 0.15 0.04], ...
            'Value', verbose, 'FontWeight', 'normal','background','white',...
            'horizontalalignment','left', 'callback', @verbose_callback);
        function verbose_callback(src,~)
            verbose = get(src,'Value');
        end      
        
        uicontrol('Style', 'checkbox', 'String', 'Use Modified Euler Streamlining', 'units', 'normalized','Position', [0.48 0.24 0.31 0.04], ...
            'Value', modeuler, 'FontWeight', 'normal','background','white',...
            'horizontalalignment','left', 'callback', @modeul_callback);
        function modeul_callback(src,~)
            modeuler = get(src,'Value');
        end
        
        uicontrol('Style', 'checkbox', 'String', 'Use Anisotropy to Constrain Tracking', 'units', 'normalized','Position', [0.48 0.16 0.33 0.04], ...
            'Value', use_aniso, 'FontWeight', 'normal','background','white',...
            'horizontalalignment','left', 'callback', @aniso_callback);
        function aniso_callback(src,~)
            use_aniso = get(src,'Value');
        end
        
        uicontrol('Style', 'checkbox', 'String', 'Use Distance Correction', 'units', 'normalized','Position', [0.48 0.08 0.31 0.04], ...
            'Value', use_distance, 'FontWeight', 'normal','background','white',...
            'horizontalalignment','left', 'callback', @dist_corr_callback);
        function dist_corr_callback(src,~)
            use_distance = get(src,'Value');
        end
        
        uicontrol('style', 'pushbutton', 'string', 'RUN', 'fontName','lucinda','Units','Normalized','Position',...
            [0.83 0.12 0.13 0.08],'HorizontalAlignment','Center','BackgroundColor',...
            'White','ForegroundColor', 'green', 'Callback',@run_probtrackx_callback);
        
           
        
        % run probtrackx with chosen parameters
        function run_probtrackx_callback(~,~)
        
            if isempty(bedpostx_dir) || ~exist(bedpostx_dir, 'dir')
                errordlg('Must run bedpostX before probtrackX');
                return;
            end
                       
            fprintf('Creating probatrackX output folder\n');
            
            % make new probtrackx folder in subject directory
            pf = fullfile(ds_folder, prob_folder);
            if ~exist(pf, 'dir')
                status = mkdir(pf);
                if ~status
                    fprintf('Failed to make %s directory for unzipped files\n', pf);
                    return;
                end
            else
                str = sprintf('%s already exists. Overwrite?', pf);
                response = questdlg(str, 'DTI Analysis','Yes', 'No', 'Yes');
                if strcmp(response,'No')
                    return;
                end
            end
            

            % create text file with list of seed masks
            if isempty(seed_masks)
                fprintf('At least one seed mask is necessesary to run probabilistic tractography\n');
                return;
            elseif size(seed_masks,2) > 1
                fprintf('Creating seed mask list file\n');
                seed_list_file = fullfile(pf, 'seed_masks.txt');
                fp = fopen(seed_list_file, 'w');
                for i=1:size(seed_masks, 2)
                    fprintf(fp, '%s\n', char(seed_masks(i)));
                end
                fclose(fp);
            end             
              
            wbh = waitbar(0,'Running probtrackX2...');
          
            % create text file with list of waypoint masks
            
            fprintf('Creating waypoint and target list file...\n');

            wp_list_file = fullfile(ds_folder, prob_folder, 'waypoint_masks.txt');
            fp = fopen(wp_list_file, 'w');
            for i=1:size(wp_masks, 2)
                fprintf(fp, '%s\n', char(wp_masks(i)));
            end
            % create text file with list of target masks 
            if ~isempty(ta_masks) && size(seed_masks,2) == 1
                fprintf('Adding target masks ...\n');
                for i=1:size(ta_masks, 2)
                    fprintf(fp, '%s\n', char(ta_masks(i)));
                end
            end                          

            fclose(fp);                      

            waitbar(0.7,wbh);
            
            % make probtrackx2 command out of chosen arguments
            % requires FSL version 6.0 or greater
            if size(seed_masks,2) > 1
                command = sprintf('%s -x %s',fullfile(fsldir, 'bin', 'probtrackx2'), seed_list_file);
            elseif size(seed_masks,2) == 1
                command = sprintf('%s -x %s',fullfile(fsldir, 'bin', 'probtrackx2'), char(seed_masks(1)));
            end
            
            if loopcheck
                command = strcat(command, ' -l');
            end
            if use_distance
                command = strcat(command, ' --pd');
            end
            command = strcat(command, sprintf(' -c %.2f -S %d --steplength=%.2f -P %d', curv_thresh, max_steps, step_length, num_samples));
            if verbose
                command = strcat(command, ' -V');
            end
            if modeuler
                command = strcat(command, ' --modeuler');
            end
            if use_aniso
                command = strcat(command, ' -f');
            end
            
            % add wayorder command and run probtrack
            
            if force_wayorder
                command = strcat(command, ' --waycond=AND --wayorder');
            end
                     
            command = strcat(command, sprintf(' --fibthresh=%.2f --distthresh=%.2f --sampvox=%.2f', fibthresh, distthresh, sampvox));

            if ~isempty(xfm)
                if ~exist(xfm, 'file')
                  fprintf('transformation directory %s not found\n', xfm);
                  delete(wbh);
                  return;
                end
                
                command = strcat(command, sprintf(' --xfm=%s', xfm));
            end
            
            if get(EX_MASK_POPUP, 'value')==2 && size(ex_mask_disp,2)>2
                command = strcat(command, sprintf(' --avoid=%s', ex_mask));
            end
            if get(TERM_MASK_POPUP, 'value')==2 && size(term_mask_disp,2)>2
                command = strcat(command, sprintf(' --stop=%s', term_mask));
            end
            
            command = strcat(command, ' --forcedir --opd');
            command = strcat(command, sprintf(' -s %s -m %s --dir=%s', fullfile(bedpostx_dir, 'merged'),...
                fullfile(bedpostx_dir, 'nodif_brain_mask'), pf));
            
            % targets and waypoints now in one file.
            command = strcat(command, sprintf(' --waypoints=%s', wp_list_file));

            fprintf('\nRunning FSL version %g probtrackx for probabilistic tractography...\n%s\n', FSLVer, command);
        
            % run probtrackx from the command line
            [status, ~] = system(command, '-echo');
            if status ~= 0
                fprintf('Error executing %s/bin/probtrackx\n', fsldir);
                return;
            end
            
            if get(diff_toggle, 'value')==1
                xfm_used = 0;
            elseif get(mri_toggle, 'value')==1
                xfm_used = 1;
            else
                xfm_used = 2;
            end
            
            waitbar(1, wbh);
            
            delete(wbh);
                        
            delete(f2);
            
            % locate output tract file
            % if zipped file exists unzip
            zip_tract_file = fullfile(pf, 'fdt_paths.nii.gz');                        
            if exist(zip_tract_file,'file')
                gunzip(zip_tract_file);                
            end
            tract_file = strrep(zip_tract_file,'.nii.gz','.nii'); 
            % unzip in place - otherwise overwrites file in unzipped folder
            if ~exist(tract_file,'file')
                fprintf('Could not find tract file %s\n', zip_tract_file);
                return;
            end
            
            % show tractography over reference image
            display_mode = 0;
            if xfm_used==0
                
                % diffusion space reference
                zip_bet_corr_file = fullfile(bedpostx_dir, 'nodif_brain.nii.gz');
                bet_corr_file = fullfile(bedpostx_dir, 'nodif_brain.nii');
                if ~exist(bet_corr_file, 'file')
                    if ~exist(zip_bet_corr_file, 'file')
                        fprintf('Error: %s does not exist\n', zip_bet_corr_file);
                        return;
                    else
                        bet_corr_file = getUnzipped(zip_bet_corr_file);
                    end
                end

                loaded_files{size(loaded_files,1)+1,1} = 5;
                loaded_files{size(loaded_files,1),2} = {bet_corr_file};
                loaded_files{size(loaded_files,1),3} = {tract_file};
                
                [~, nb, ~] = fileparts(bet_corr_file);
                
            elseif xfm_used == 1
                
                % structural space reference
                if isempty(mri_ref_file)
                    [filename, filepath] = uigetfile({'*.nii', 'Structural Space Reference File (*.nii)'}, 'Select Structural Space Reference File for Tractography Overlay');
                    if isequal(filename, 0) || isequal(filepath, 0)
                       return; 
                    end
                    mri_ref_file = fullfile(filepath, filename);
                end
                loaded_files{size(loaded_files,1)+1,1} = 5;
                loaded_files{size(loaded_files,1),2} = {mri_ref_file};
                loaded_files{size(loaded_files,1),3} = {tract_file};
                
                [~, nb, ~] = fileparts(mri_ref_file);
                
            elseif xfm_used == 2
                
                % standard space reference
                if isempty(std_ref_file)
                    [filename, filepath] = uigetfile({'*.nii', 'Standard Space Reference File (*.nii)'}, 'Select Standard Space Reference File for Tractography Overlay');
                    if isequal(filename, 0) || isequal(filepath, 0)
                       return; 
                    end
                    std_ref_file = fullfile(filepath, filename);
                end
                loaded_files{size(loaded_files,1)+1,1} = 5;
                loaded_files{size(loaded_files,1),2} = {std_ref_file};
                loaded_files{size(loaded_files,1),3} = {tract_file};
                
                [~, nb, ~] = fileparts(std_ref_file);
                
            end
            
            [~, n, ~] = fileparts(tract_file);
            l = size(files,2);
            str = sprintf('%s (overlaid on %s)', n, nb);
            files(l+1) = {str};
            set(FILE_LISTBOX, 'Value', l+1);
            set(FILE_LISTBOX, 'String', files);
            
            display_mode = 6;
            loadTract(tract_file);
            
            [~, n, ~] = fileparts(tract_file);
            l = size(files,2);
            files(l+1) = {n};
            set(FILE_LISTBOX, 'Value', l+1);
            set(FILE_LISTBOX, 'String', files);
            
            loaded_files{size(loaded_files,1)+1,1} = display_mode;
            loaded_files{size(loaded_files,1),2} = {tract_file};
            
        end
    end
    
% ====================== Mask drawing functions ========================= %

    % Draw/Pause button
    function create_mask_callback(~, ~)

        % enable cursor draw function
        if strcmp(get(CREATE_MASK_BUTTON, 'string'), 'Draw')
            if ~drawing
                drawing = 1;
                mask = zeros(max_dim, max_dim, max_dim);
                set(SAVE_MASK_BUTTON, 'enable', 'on');
                set(LOAD_MASK_BUTTON, 'enable', 'on');
            end

            axi_view(oldcoords(1), oldcoords(2), oldcoords(3));
            cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
            sag_view(oldcoords(1), oldcoords(2), oldcoords(3));

            set(f,'WindowButtonDownFcn', @down_callback);
            set(CREATE_MASK_BUTTON, 'string', 'Pause');
            set(marker_toggle, 'enable', 'on');
            set(eraser_toggle, 'enable', 'on');
            set(SMALL_MARKER, 'enable', 'on');
            set(MED_MARKER, 'enable', 'on');
            set(LARGE_MARKER, 'enable', 'on');
            
        % shut off cursor draw function
        else
            set(f,'WindowButtonDownFcn', @buttondown);
            set(CREATE_MASK_BUTTON, 'string', 'Draw');
            set(marker_toggle, 'enable', 'off');
            set(eraser_toggle, 'enable', 'off');
            set(SMALL_MARKER, 'enable', 'off');
            set(MED_MARKER, 'enable', 'off');
            set(LARGE_MARKER, 'enable', 'off');
            
        end
    end

    % Draw function 1: when click down start drawing new line
    function down_callback(~,~)
        up = 0;
        
        persistent chk
        
        % single click starts drawing
        if isempty(chk)
            chk = 1;
            set(f, 'WindowButtonUpFcn',@up_callback);
            pause(0.4); %Add a delay to distinguish single click from a double click
            if chk == 1

                % track changes (enable 'UNDO')
                prev = mask;
                
                pos_s = round(get(sagaxis, 'currentpoint'));
                pos_a = round(get(axiaxis, 'currentpoint'));
                pos_c = round(get(coraxis, 'currentpoint'));
                curpos = [];
                
                % sagittal display
                if pos_s(1,1:2) < [size(img_display,1) size(img_display,2)] & pos_s(1,1:2) >=0

                    curpos = pos_s;
                    
                    mask_img = rot90(fliplr(squeeze(mask(oldcoords(1)+1, :, :))));

                    % expand number of voxels depending on marker size
                    [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);

                    % exclude points that fall outside of volume
                    i = x<1 | x>slice_dim(2) | y<1 | y>slice_dim(3);
                    x(i) = []; y(i) = [];

                    % track drawn or erased points
                    if marker
                        mask_img(y,x) = 1;
                    else
                        mask_img(y,x) = 0;
                    end
                    mask(oldcoords(1)+1,:, :) = fliplr(rot90(mask_img, -1));
                    
                % axial display
                elseif pos_a(1,1:2) < [size(img_display,1) size(img_display,2)] & pos_a(1,1:2) >=0

                    curpos = pos_a;

                    mask_img = rot90(fliplr(squeeze(mask(:,:,slice_dim(3)-oldcoords(3)))));

                    % expand number of voxels depending on marker size
                    [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);

                    % exclude points that fall outside of volume
                    i = x<1 | x>slice_dim(1) | y<1 | y>slice_dim(2);
                    x(i) = []; y(i) = [];

                    % track drawn or erased points
                    if marker
                        mask_img(y,x) = 1;
                    else
                        mask_img(y,x) = 0;
                    end
                    mask(:, :, slice_dim(3)-oldcoords(3)) = fliplr(rot90(mask_img, -1));
                 
                % coronal display
                elseif pos_c(1,1:2) < [size(img_display,1) size(img_display,2)] & pos_c(1,1:2) >=0

                    curpos = pos_c;

                    mask_img = rot90(fliplr(squeeze(mask(:,slice_dim(2)-oldcoords(2), :))));

                    % number of voxels drawn on depends on marker size
                    [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
                    i = x<1 | x>slice_dim(1) | y<1 | y>slice_dim(3);
                    x(i) = []; y(i) = [];

                    if marker
                        mask_img(y,x) = 1;
                    else
                        mask_img(y,x) = 0;
                    end
                    mask(:, slice_dim(2)-oldcoords(2), :) = fliplr(rot90(mask_img, -1));

                end

                % change to color map to display marker in red
                colormap(cmap);
                             
                axi_view(oldcoords(1), oldcoords(2), oldcoords(3));
                cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
                sag_view(oldcoords(1), oldcoords(2), oldcoords(3));
                
                % if haven't released cursor, enable move function
                if ~up
                    set(f, 'WindowButtonMotionFcn',@move_callback)
                end
                
                chk = [];
            end
            
        % Double click opens expanded slice viewer
        else
            chk = [];

            % find which subplot was clicked on
            pos_a = round(get(axiaxis, 'currentpoint'));
            pos_c = round(get(coraxis, 'currentpoint'));
            pos_s = round(get(sagaxis, 'currentpoint'));

            if ~isempty(pos_a) && pos_a(1,1) >= 0 && pos_a(1,2) >= 0 && pos_a(1,2) <= size(img_display,1) && pos_a(1,1) <= size(img_display,1)
                axiaxis_big_view;
            elseif ~isempty(pos_c) && pos_c(1,1) >= 0 && pos_c(1,2) >= 0 && pos_c(1,2) <= size(img_display,1) && pos_c(1,1) <= size(img_display,1)
                coraxis_big_view;
            elseif ~isempty(pos_s) && pos_s(1,1) >= 0 && pos_s(1,2) >= 0 && pos_s(1,2) <= size(img_display,1) && pos_s(1,1) <= size(img_display,1)
                sagaxis_big_view;
            end

        end
    end
    
    % Draw functin 2: when move cursor, extend line to include new positions
    function move_callback(~,~)
        
        % find which subplot was clicked on
        pos_a = round(get(axiaxis, 'currentpoint'));
        pos_c = round(get(coraxis, 'currentpoint'));
        pos_s = round(get(sagaxis, 'currentpoint'));
        
        % axial display
        if pos_a(1,1:2) < [size(img_display,1) size(img_display,2)] & pos_a(1,1:2) >=0
            curpos = pos_a;


            mask_img = rot90(fliplr(squeeze(mask(:,:,slice_dim(3)-oldcoords(3)))));

            % number of voxels drawn on depends on marker size
            [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
            i = x<1 | x>slice_dim(1) | y<1 | y>slice_dim(2);
            x(i) = []; y(i) = [];
            if marker
                mask_img(y,x) = 1;
            else
                mask_img(y,x) = 0;
            end
            mask(:, :, slice_dim(3)-oldcoords(3)) = fliplr(rot90(mask_img, -1));
            
        % coronal display
        elseif pos_c(1,1:2) < [size(img_display,1) size(img_display,2)] & pos_c(1,1:2) >=0
            curpos = pos_c;         

            mask_img = rot90(fliplr(squeeze(mask(:,slice_dim(2)-oldcoords(2), :))));

            % number of voxels drawn on depends on marker size
            [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
            i = x<1 | x>slice_dim(1) | y<1 | y>slice_dim(3);
            x(i) = []; y(i) = [];
            if marker
                mask_img(y,x) = 1;
            else
                mask_img(y,x) = 0;
            end

            mask(:, slice_dim(2)-oldcoords(2), :) = fliplr(rot90(mask_img, -1));

        % sagittal slice: draw on current position
        elseif pos_s(1,1:2) < [size(img_display,1) size(img_display,2)] & pos_s(1,1:2) >=0
            curpos = pos_s;
            
            mask_img = rot90(fliplr(squeeze(mask(oldcoords(1)+1, :, :))));

            % number of voxels drawn on depends on marker size
            [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
            i = x<1 | x>slice_dim(2) | y<1 | y>slice_dim(3);
            x(i) = []; y(i) = [];
            if marker
                mask_img(y,x) = 1;
            else
                mask_img(y,x) = 0;
            end

            mask(oldcoords(1)+1,:, :) = fliplr(rot90(mask_img, -1));

        end
        
        
        axi_view(oldcoords(1), oldcoords(2), oldcoords(3));
        cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
        sag_view(oldcoords(1), oldcoords(2), oldcoords(3));
        
    end

    % when release click, end line
    function up_callback(~,~)
        
        up = 1;
        
        % reset cursor settings
        set(f, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
        set(UNDO_BUTTON, 'enable', 'on');
        set(CLEAR_BUTTON, 'enable', 'on');
        
                
        % update view
        axi_view(oldcoords(1), oldcoords(2), oldcoords(3));
        cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
        sag_view(oldcoords(1), oldcoords(2), oldcoords(3));
        
    end

    % load a precomputed mask file (assume in same space as displayed image)
    function load_mask_callback(~,~)
        
        % stop drawing function
        drawing = 0;

         % get mask file
        [fileName, filePath] = uigetfile(...
            {'*.nii','MASK file (*.nii)'; '*.nii.gz','Mask file (*.nii.gz)'},...            
            'Select Overlay file');
        if isequal(fileName,0) || isequal(filePath,0)
            return;
        end
        mask_name = fileName;      
        mask_nii_file = fullfile(ds_folder, fileName);                 
        [~,mask_name, ~] = fileparts(fileName);
        
        % add mask to file listbox and viewer
        loaded_files{size(loaded_files,1)+1, 1} = 3;
        loaded_files{size(loaded_files,1), 2} = {mask_nii_file};        
        set(mask_name_edit,'string',mask_name);
        
        % load mask
        display_mode = 3;
        loadData(mask_nii_file);
        
        
        l = size(files,2);
        files(l+1) = {mask_name};
        set(FILE_LISTBOX, 'String', files);
        set(FILE_LISTBOX, 'Value', l+1);
        set(VOLUME_EDIT, 'String', '0');
        set(LOOP_BUTTON, 'enable', 'off');

        % reset mask controls
        set(CREATE_MASK_BUTTON, 'String', 'Draw');
        set(UNDO_BUTTON, 'enable', 'off');
        set(CLEAR_BUTTON, 'enable', 'off');


    end

    % save mask
    function save_mask_callback(~,~)
        % only save mask if drawing or thresholding a SAM/ERB image
        if display_mode~=2 && display_mode~=4 && ~drawing
            return;
        end
        
        if isempty(mask_name)
          fprintf('Must set mask name before save\n');
          return;
        end
        
        wbh = waitbar(0,'Saving binary mask ...');

        waitbar(0.25,wbh);
        
        % save as nifti file (dimensions and settings of underlying
        % image)
        fileNum = get(FILE_LISTBOX, 'Value');
        cur_nii_file = char(loaded_files{fileNum, 2});
        mask_nii = load_nii(cur_nii_file);
        mask_nii_file = fullfile(ds_folder, strcat(mask_name, '.nii'));
        
        % stop drawing function
        set(f,'WindowButtonDownFcn', @buttondown);
        drawing = 0;
        
        % create mask for non-padded image (fascilitate removing of
        % padding to even dimensions --> get mask of original size)
        vox_x = mask_nii.hdr.dime.dim(2);
        vox_y = mask_nii.hdr.dime.dim(3);
        vox_z = mask_nii.hdr.dime.dim(4);
        volumes = mask_nii.hdr.dime.dim(5);
        
        [x, y, z] = meshgrid(1:vox_x, 1:vox_y, 1:vox_z);
        mask_nii_pts = [x(:), y(:), z(:)];
        pad_mask_pts(:, 1) = mask_nii_pts(:,1) + ones(size(mask_nii_pts(:,1)))*round((slice_dim(1)-vox_x)/2);
        pad_mask_pts(:, 2) = mask_nii_pts(:,2) + ones(size(mask_nii_pts(:,2)))*round((slice_dim(2)-vox_y)/2);
        pad_mask_pts(:, 3) = mask_nii_pts(:,3) + ones(size(mask_nii_pts(:,3)))*round((slice_dim(3)-vox_z)/2);
        
        waitbar(0.3,wbh);
        
        pad_mask = zeros(slice_dim(1),slice_dim(2),slice_dim(3), volumes);
        Is = size(pad_mask(:,:,:,1));
        pad_mask_idx = sub2ind(Is, pad_mask_pts(:,1), pad_mask_pts(:,2), pad_mask_pts(:,3));       
        if volumes > 1
            v = str2double(get(VOLUME_EDIT, 'String'))+1;
            pad_mask = pad_mask(:,:,:,v);
            pad_mask(pad_mask_idx) = 1;
            mask_nii.hdr.dime.dim(1) = 3;
            mask_nii.hdr.dime.dim(5) = 1;
        else
            pad_mask(pad_mask_idx) = 1;
        end
        pad_mask = permute(pad_mask, [2 1 3]);
        
        waitbar(0.4,wbh);
        
        % indices into [vox_x vox_y vox_z] sized image (original size)
        mask_nii_idx = sub2ind([vox_x vox_y vox_z], mask_nii_pts(:,1), mask_nii_pts(:,2), mask_nii_pts(:,3));
        
        % hand drawn mask
        if ~isempty(find(mask))
           mask = mask > 0;
           draw_roi_mask = permute(mask, [2 1 3]);
           draw_roi_mask = flipdim(flipdim(draw_roi_mask,1),3);
           draw_roi_img = zeros(vox_x, vox_y, vox_z);
           draw_roi_img(mask_nii_idx) = draw_roi_mask(find(pad_mask));     
        end        
         
        waitbar(0.75,wbh);
        
        mask_nii.img = logical(draw_roi_img);
        
        fprintf('Save mask as NifTi file..\n');
        save_nii(mask_nii, mask_nii_file);
   
       % add mask to file listbox and viewer
       loaded_files{size(loaded_files,1)+1, 1} = 3;
       loaded_files{size(loaded_files,1), 2} = {mask_nii_file};
       [~, mask_nii_name, ~] = fileparts(mask_nii_file);

       waitbar(1,wbh);

       delete(wbh);

       % load mask
       display_mode = 3;
       loadData(mask_nii_file);
       l = size(files,2);
       files(l+1) = {mask_nii_name};
       set(FILE_LISTBOX, 'String', files);
       set(FILE_LISTBOX, 'Value', l+1);
       set(VOLUME_EDIT, 'String', '0');
       set(LOOP_BUTTON, 'enable', 'off');

       % reset mask controls
       set(CREATE_MASK_BUTTON, 'String', 'Draw');
       set(UNDO_BUTTON, 'enable', 'off');
       set(CLEAR_BUTTON, 'enable', 'off');
       set(SAVE_MASK_BUTTON, 'enable', 'off');

    end

    % undo most recent drawing
    function undo_callback(~,~)
        set(UNDO_BUTTON, 'enable', 'off');
        
        mask = prev;
        
        axi_view(oldcoords(1), oldcoords(2), oldcoords(3));
        cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
        sag_view(oldcoords(1), oldcoords(2), oldcoords(3));
    end
    
    % clear all drawing
    function clear_callback(~,~)
        mask = zeros(slice_dim(1), slice_dim(2), slice_dim(3));
             
        axi_view(oldcoords(1), oldcoords(2), oldcoords(3));
        cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
        sag_view(oldcoords(1), oldcoords(2), oldcoords(3));
    end
    
% ====================== Display Functions ============================== %

    % saggital slice display
    function sag_view(s,c,a)

        sagaxis=subplot('Position', sag_subplot);

        % RAS -> RPI coordinates for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        if display_mode~=6
          mdata = rot90(fliplr(squeeze(img_display(s,:,:))));      
        end
          
        % display BET mask or outline in yellow
        if display_mode == 1
            bet_mask = mdata==127;
            mdata = mdata * contrast_value;
            mdata(bet_mask) = 220;
            mdata(mdata>127 & ~bet_mask) = 127;
            
            imagesc(mdata, [0 255]);
            colormap(cmap);
            
        % show drawing
        elseif display_mode == 2
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(cmap);

        % show mask (binary) in red
        elseif display_mode == 3
            mdata(mdata~=0) = 175;
            imagesc(mdata, [0 255]);
            colormap(cmap);
            
            
        % show tractography image ontop of background
        elseif display_mode == 5
            
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(tmap);

            hold on;

            % influence transparency (allow background image to show
            % through when tract data low)
            img = rot90(fliplr(squeeze(tract_colour_top(s,:,:))));
            im = imagesc(img,[0 255]);
            m = img > 128;
            m = m .* overlayAlpha;
            set(im, 'AlphaData', m);
           
            hold off;
            
        % show tractography image all at once (projection) alone
        elseif display_mode == 6
            
            blank_img = zeros(max_dim, max_dim);
            imagesc(blank_img, [0 255]);
            colormap(tmap);
            
            hold on;
            im = imagesc(sag_tract_proj, [0 255]);
            m = sag_tract_proj > 128;
            set(im, 'AlphaData', m);
            hold off; 
            
        else
            mdata = mdata * contrast_value;
            idx = find(mdata > 127);
            mdata(idx) = 127;

            imagesc(mdata,[0 127]);
            colormap(gmap);
        end
        
        % display v1 in RGB coding
        if display_mode == 7 || display_mode == 8
            
            if ~isempty(dti_fa_overlay)
                
                % prep FA for display
                fa_data = rot90(fliplr(squeeze(dti_fa_overlay(s,:,:))));
                fa_data = fa_data * contrast_value;
                idx = find(fa_data > 127);
                fa_data(idx) = 127;
            end
            
            hold on;

            % calculate vector colors (for each voxel)
            dti_colour_top = zeros(slice_dim(2), slice_dim(3), 3);
            for z_vox=1:slice_dim(3)
                for y_vox=1:slice_dim(2)

                      dti_colour_top(y_vox, z_vox, 1) = uint8(abs(dti_v1_overlay.x.img(s, y_vox, z_vox))*255);
                      dti_colour_top(y_vox, z_vox, 2) = uint8(abs(dti_v1_overlay.y.img(s, y_vox, z_vox))*255);
                      dti_colour_top(y_vox, z_vox, 3) = uint8(abs(dti_v1_overlay.z.img(s, y_vox, z_vox))*255);

                end
            end

            if(dti_v1_overlay.x.hdr.dime.datatype==2)
                dti_colour_top=uint8(dti_colour_top);
            else
                maxVal = max(max(max(dti_colour_top)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                dti_colour_top = scaleTo8bit*dti_colour_top; 
                dti_colour_top = uint8(dti_colour_top);
            end

            % display vector colors
            o_data(:,:,1) = rot90(fliplr(squeeze(dti_colour_top(:,:,1))));
            o_data(:,:,2) = rot90(fliplr(squeeze(dti_colour_top(:,:,2))));
            o_data(:,:,3) = rot90(fliplr(squeeze(dti_colour_top(:,:,3))));
            o_data = o_data * contrast_value;
            im = imagesc(o_data);

            if ~isempty(dti_fa_overlay)
                m = fa_data*2;
                m = m .* overlayAlpha;
                set(im, 'AlphaData', m);
            else
                m = o_data(:,:,1)==0 & o_data(:,:,2)==0 & o_data(:,:,3)==0;
                m = ~m;
                set(im, 'AlphaData', m);
            end
            
            hold off;
        end

        if ~isempty(overlay_img)
            
            hold on;
            
            for i=1:size(overlay_img,2)
                overlay = overlay_img{i};
                img = rot90(fliplr(squeeze(overlay(s,:,:))));
                mask_img = img>(128+(128*i));
                im = imagesc(img, [0 895]);
                set(im, 'AlphaData', mask_img);
            end
            
            if display_mode == 5 || display_mode == 6
                colormap(overlay_tmaps);
            else
                colormap(overlay_cmaps);
            end
            
            hold off;
            
        end
        
        % if drawing, display mask drawing on top of display
        if display_mode == 2 || drawing
            colormap(cmap);
            
            hold on;
            
            mask_colour = rot90(fliplr(squeeze(mask(s,:,:))));
            mask_colour_img = mask_colour;
            mask_colour_img(mask_colour_img==1) = 175;
            im = imagesc(mask_colour_img, [0 895]);
            set(im, 'AlphaData', mask_colour);
            colormap(overlay_cmaps);
            
            hold off;
        end
        
        axis off;
        sag_hor=line([1, slice_dim(2)],[a, a],'color',orange);
        sag_ver=line([c, c],[1,slice_dim(3)],'color',orange);
        
    end

    % coronal slice display
    function cor_view(s,c,a)
        coraxis = subplot('Position', cor_subplot);
        % RAS -> RPI coordinates for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        if display_mode~=6
          mdata = rot90(fliplr(squeeze(img_display(:,c,:))));      
        end
        
        % display mask or outline in yellow
        if display_mode == 1
            bet_mask = mdata==127;
            mdata = mdata * contrast_value;
            mdata(bet_mask) = 220;
            mdata(mdata>127 & ~bet_mask) = 127;
            
            imagesc(mdata, [0 255]);
            colormap(cmap);
            
        % show drawing
        elseif display_mode == 2 
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(cmap);
           
        % show mask (binary) in red
        elseif display_mode == 3
            mdata(mdata~=0) = 175;
            imagesc(mdata, [0 255]);
            colormap(cmap);
               
        % show tractography image ontop of background
        elseif display_mode == 5
            
            colormap(tmap);
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);

            hold on;

            % influence transparency (allow background image to show
            % through where tract data low)
            img = rot90(fliplr(squeeze(tract_colour_top(:,c,:))));
            im = imagesc(img,[0 255]);
            m = img > 128;
            m = m .* overlayAlpha;
            set(im, 'AlphaData', m);
            hold off;
                
        % show tractography image al at once (projection) alone
        elseif display_mode == 6
            blank_img = zeros(max_dim, max_dim);
            imagesc(blank_img, [0 255]);
            colormap(tmap);
            
            hold on;
            im = imagesc(cor_tract_proj, [0 255]);
            m = cor_tract_proj > 128;
            set(im, 'AlphaData', m);
            hold off;   
            
        else
            mdata = mdata * contrast_value;
            idx = find(mdata > 127);
            mdata(idx) = 127;

            imagesc(mdata,[0 127]);
            colormap(gmap);
        end
        
        % display v1 in RGB coding
        if display_mode == 7 || display_mode == 8
            
            if ~isempty(dti_fa_overlay)
                
                % display fa
                fa_data = rot90(fliplr(squeeze(dti_fa_overlay(:,c,:))));
                fa_data = fa_data * contrast_value;
                idx = find(fa_data > 127);
                fa_data(idx) = 127;
                
            end
            
            hold on;

            % calculate vector colors (for each voxel)
            dti_colour_top = zeros(slice_dim(1), slice_dim(3), 3);
            for z_vox=1:slice_dim(3)
                for x_vox=1:slice_dim(1)

                      dti_colour_top(x_vox, z_vox, 1) = uint8(abs(dti_v1_overlay.x.img(x_vox, c, z_vox))*255);
                      dti_colour_top(x_vox, z_vox, 2) = uint8(abs(dti_v1_overlay.y.img(x_vox, c, z_vox))*255);
                      dti_colour_top(x_vox, z_vox, 3) = uint8(abs(dti_v1_overlay.z.img(x_vox, c, z_vox))*255);
                end
            end

            if(dti_v1_overlay.x.hdr.dime.datatype==2)
                dti_colour_top=uint8(dti_colour_top);
            else
                maxVal = max(max(max(dti_colour_top)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                dti_colour_top = scaleTo8bit*dti_colour_top; 
                dti_colour_top = uint8(dti_colour_top);
            end

            %display vector colors
            o_data(:,:,1) = rot90(fliplr(squeeze(dti_colour_top(:,:,1))));
            o_data(:,:,2) = rot90(fliplr(squeeze(dti_colour_top(:,:,2))));
            o_data(:,:,3) = rot90(fliplr(squeeze(dti_colour_top(:,:,3))));    
            o_data = o_data * contrast_value;
            im = imagesc(o_data);

            if ~isempty(dti_fa_overlay)
                m = fa_data*2;
                m = m .* overlayAlpha;
                set(im, 'AlphaData', m);
            else
                m = o_data(:,:,1)==0 & o_data(:,:,2)==0 & o_data(:,:,3)==0;
                m = ~m;
                set(im, 'AlphaData', m);
            end
            
            hold off;
        end
        
        if ~isempty(overlay_img)
            
            hold on;
            
            for i=1:size(overlay_img,2)
                overlay = overlay_img{i};
                img = rot90(fliplr(squeeze(overlay(:,c,:))));
                mask_img = img>(128+(128*i));
                im = imagesc(img, [0 896]);
                set(im, 'AlphaData', mask_img);
            end
            
            if display_mode == 5 || display_mode == 6
                colormap(overlay_tmaps);
            else
                colormap(overlay_cmaps);
            end
            
            hold off;
            
        end
        
        % if drawing, display mask drawing on top of display
        if display_mode == 2 || drawing
            hold on;
            
            mask_colour = rot90(fliplr(squeeze(mask(:,c,:))));
            mask_colour_img = mask_colour;
            mask_colour_img(mask_colour_img==1) = 175;
            im = imagesc(mask_colour_img, [0 896]);
            set(im, 'AlphaData', mask_colour);
            colormap(overlay_cmaps);
            
            hold off;
        end
        
        axis off;
        cor_hor=line([1, slice_dim(1)],[a, a],'color',orange);
        cor_ver=line([s, s],[1, slice_dim(3)],'color',orange);
        

    end

    % axial slice display
    function axi_view(s,c,a)
        axiaxis = subplot('Position', axi_subplot);
        % RAS -> RPI coordinates for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        if display_mode~=6
          mdata = rot90(fliplr(squeeze(img_display(:,:,a))));
        end
        
        % display mask or outline in yellow
        if display_mode == 1
            bet_mask = mdata==127;
            mdata = mdata * contrast_value;
            mdata(bet_mask) = 220;
            mdata(mdata>127 & ~bet_mask) = 127;
            
            imagesc(mdata, [0 255]);
            colormap(cmap);
            
        % show drawing 
        elseif display_mode == 2
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(cmap);
        
        % show mask (binary) in red
        elseif display_mode == 3
            mdata(mdata~=0) = 175;
            imagesc(mdata, [0 255]);
            colormap(cmap);

        % show tractography on background image
        elseif display_mode == 5
            
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(tmap);

            hold on;

            % influence transparency (allow background image to show
            % through when tract data low)
            img = rot90(fliplr(squeeze(tract_colour_top(:,:,a))));
            im = imagesc(img,[0 255]);
            m = img > 128;
            m = m .* overlayAlpha;
            set(im, 'AlphaData', m);
            hold off;
            
        % show tractography image all at once (projection) alone
        elseif display_mode == 6
            blank_img = zeros(max_dim, max_dim);
            imagesc(blank_img, [0 255]);
            colormap(tmap);
            
            hold on;
            im = imagesc(axi_tract_proj, [0 255]);
            m = axi_tract_proj > 128;
            set(im, 'AlphaData', m);
            hold off;
        else
            mdata = mdata * contrast_value;
            mdata(mdata > 127) = 127;

            imagesc(mdata,[0 127]);
            colormap(gmap);
        end
        
        if display_mode == 7 || display_mode == 8

            if ~isempty(dti_fa_overlay)
                
                % display fa
                fa_data = rot90(fliplr(squeeze(dti_fa_overlay(:,:,a))));
                fa_data = fa_data * contrast_value;
                idx = find(fa_data > 127);
                fa_data(idx) = 127;
                
            end
            
            hold on;

            % display v1 in RGB coding: calculate vector colors (for each voxel)
            dti_colour_top = zeros(slice_dim(1), slice_dim(2), 3);

            for y_vox=1:slice_dim(2)
                for x_vox=1:slice_dim(1)

                      dti_colour_top(x_vox, y_vox, 1) = uint8(abs(dti_v1_overlay.x.img(x_vox, y_vox, a))*255);
                      dti_colour_top(x_vox, y_vox, 2) = uint8(abs(dti_v1_overlay.y.img(x_vox, y_vox, a))*255);
                      dti_colour_top(x_vox, y_vox, 3) = uint8(abs(dti_v1_overlay.z.img(x_vox, y_vox, a))*255);
                end
            end

            if(dti_v1_overlay.x.hdr.dime.datatype==2)
                dti_colour_top=uint8(dti_colour_top);
            else
                maxVal = max(max(max(dti_colour_top)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                img_scaled = scaleTo8bit*dti_colour_top; 
                dti_colour_top = uint8(img_scaled);
            end

            % display vector colors
            o_data(:,:,1) = rot90(fliplr(squeeze(dti_colour_top(:,:,1))));
            o_data(:,:,2) = rot90(fliplr(squeeze(dti_colour_top(:,:,2))));
            o_data(:,:,3) = rot90(fliplr(squeeze(dti_colour_top(:,:,3))));      
            o_data = o_data * contrast_value;
            im = imagesc(o_data);

            if ~isempty(dti_fa_overlay)
                % brightness of colours depends on underlying fa image
                set(im, 'AlphaData', fa_data*2);
                m = fa_data*2;
                m = m .* overlayAlpha;
                set(im, 'AlphaData', m);
            else
                m = o_data(:,:,1)==0 & o_data(:,:,2)==0 & o_data(:,:,3)==0;
                m = ~m;
                set(im, 'AlphaData', m);
            end
            
            hold off;
        end

        if ~isempty(overlay_img)
            
            hold on;
            
            for i=1:size(overlay_img,2)
                overlay = overlay_img{i};
                img = rot90(fliplr(squeeze(overlay(:,:, a))));
                mask_img = img>(128+(128*i));
                im = imagesc(img, [0 896]);
                set(im, 'AlphaData', mask_img);
            end
            if display_mode == 5 || display_mode == 6
                colormap(overlay_tmaps);
            else
                colormap(overlay_cmaps);
            end
            hold off;
            
        end
        
         % if drawing, display mask drawing on top of display
        if display_mode == 2 || drawing
            hold on;
            
            mask_colour = rot90(fliplr(squeeze(mask(:,:,a))));
            mask_colour_img = mask_colour;
            mask_colour_img(mask_colour_img==1) = 175;
            im = imagesc(mask_colour_img, [0 896]);
            set(im, 'AlphaData', mask_colour);
            colormap(overlay_cmaps);
            
            hold off;
        end
       
        
        axis off;
        axi_hor=line([1,slice_dim(1)],[c, c],'color',orange);
        axi_ver=line([s, s],[1, slice_dim(3)],'color',orange);
              
    end



    % big slice displays
    function sag_view_big(s,c,a)
        
        % RAS -> RPI coordinates for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        if display_mode~=6
          mdata = rot90(fliplr(squeeze(img_display(s,:,:))));      
        end
          
        % display BET mask or outline in yellow
        if display_mode == 1
            bet_mask = mdata==127;
            mdata = mdata * contrast_value;
            mdata(bet_mask) = 220;
            mdata(mdata>127 & ~bet_mask) = 127;
            
            imagesc(mdata, [0 255]);
            colormap(cmap);
        elseif display_mode == 2
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(cmap);

        elseif display_mode == 3
            mdata(mdata~=0) = 175;
            imagesc(mdata, [0 255]);
            colormap(cmap);
            
        elseif display_mode == 5
            
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(tmap);

            hold on;

            % influence transparency (allow background image to show
            % through when tract data low)
            img = rot90(fliplr(squeeze(tract_colour_top(s,:,:))));
            im = imagesc(img,[0 255]);
            m = img > 128;
            m = m .* overlayAlpha;
            set(im, 'AlphaData', m);
            hold off;
            
        elseif display_mode == 6
            
            blank_img = zeros(max_dim, max_dim);
            imagesc(blank_img, [0 255]);
            colormap(tmap);
            
            hold on;
            im = imagesc(sag_tract_proj, [0 255]);
            m = sag_tract_proj > 128;
            set(im, 'AlphaData', m);
            hold off; 
            
        else
            mdata = mdata * contrast_value;
            idx = find(mdata > 127);
            mdata(idx) = 127;

            imagesc(mdata,[0 127]);
            colormap(gmap);
        end
        
        % display v1 in RGB coding
        if display_mode == 7 || display_mode == 8
            
            if ~isempty(dti_fa_overlay)
            
                % prep FA for display
                fa_data = rot90(fliplr(squeeze(dti_fa_overlay(s,:,:))));
                fa_data = fa_data * contrast_value;
                idx = find(fa_data > 127);
                fa_data(idx) = 127;
            
            end
            
            hold on;

            % calculate vector colors (for each voxel)
            dti_colour_top = zeros(slice_dim(2), slice_dim(3), 3);
            for z_vox=1:slice_dim(3)
                for y_vox=1:slice_dim(2)

                      dti_colour_top(y_vox, z_vox, 1) = uint8(abs(dti_v1_overlay.x.img(s, y_vox, z_vox))*255);
                      dti_colour_top(y_vox, z_vox, 2) = uint8(abs(dti_v1_overlay.y.img(s, y_vox, z_vox))*255);
                      dti_colour_top(y_vox, z_vox, 3) = uint8(abs(dti_v1_overlay.z.img(s, y_vox, z_vox))*255);

                end
            end

            if(dti_v1_overlay.x.hdr.dime.datatype==2)
                dti_colour_top=uint8(dti_colour_top);
            else
                maxVal = max(max(max(dti_colour_top)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                dti_colour_top = scaleTo8bit*dti_colour_top; 
                dti_colour_top = uint8(dti_colour_top);
            end

            % display vector colors
            o_data(:,:,1) = rot90(fliplr(squeeze(dti_colour_top(:,:,1))));
            o_data(:,:,2) = rot90(fliplr(squeeze(dti_colour_top(:,:,2))));
            o_data(:,:,3) = rot90(fliplr(squeeze(dti_colour_top(:,:,3))));
            o_data = o_data * contrast_value;
            im = imagesc(o_data);

            if ~isempty(dti_fa_overlay)
                m = fa_data*2;
                m = m .* overlayAlpha;
                set(im, 'AlphaData', m);
            else
                m = o_data(:,:,1)==0 & o_data(:,:,2)==0 & o_data(:,:,3)==0;
                m = ~m;
                set(im, 'AlphaData', m);
            end

            hold off;
        end
        
        if ~isempty(overlay_img)
            
            hold on;
            
            for i=1:size(overlay_img,2)
                overlay = overlay_img{i};
                img = rot90(fliplr(squeeze(overlay(s,:,:))));
                mask_img = img>(128+(128*i));
                im = imagesc(img, [0 895]);
                set(im, 'AlphaData', mask_img);
            end
            
            if display_mode == 5 || display_mode == 6
                colormap(overlay_tmaps);
            else
                colormap(overlay_cmaps);
            end
            
            hold off;
            
        end
        
        if display_mode == 2 || drawing
            colormap(cmap);
            
            hold on;
            
            mask_colour = rot90(fliplr(squeeze(mask(s,:,:))));
            mask_colour_img = mask_colour;
            mask_colour_img(mask_colour_img==1) = 175;
            im = imagesc(mask_colour_img, [0 895]);
            set(im, 'AlphaData', mask_colour);
            colormap(overlay_cmaps);
            
            hold off;
        end
        
        axis off;
        sag_hor=line([1, slice_dim(2)],[a, a],'color',orange);
        sag_ver=line([c, c],[1,slice_dim(3)],'color',orange);
        
    end

    function cor_view_big(s,c,a)
        
        % RAS -> RPI coordinates for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        if display_mode~=6
          mdata = rot90(fliplr(squeeze(img_display(:,c,:))));      
        end
        
        % display mask or outline in yellow
        if display_mode == 1
            bet_mask = mdata==127;
            mdata = mdata * contrast_value;
            mdata(bet_mask) = 220;
            mdata(mdata>127 & ~bet_mask) = 127;
            
            imagesc(mdata, [0 255]);
            colormap(cmap);
            
        elseif display_mode == 2 
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(cmap);
           
        elseif display_mode == 3
            mdata(mdata~=0) = 175;
            imagesc(mdata, [0 255]);
            colormap(cmap);         
                
        elseif display_mode == 5
            
            colormap(tmap);
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);

            hold on;

            % influence transparency (allow background image to show
            % through where tract data low)
            img = rot90(fliplr(squeeze(tract_colour_top(:,c,:))));
            im = imagesc(img,[0 255]);
            m = img > 128;
            m = m .* overlayAlpha;
            set(im, 'AlphaData', m);
            hold off;
                
        elseif display_mode == 6
            blank_img = zeros(max_dim, max_dim);
            imagesc(blank_img, [0 255]);
            colormap(tmap);
            
            hold on;
            im = imagesc(cor_tract_proj, [0 255]);
            m = cor_tract_proj > 128;
            set(im, 'AlphaData', m);
            hold off;   
            
        else
            mdata = mdata * contrast_value;
            idx = find(mdata > 127);
            mdata(idx) = 127;

            imagesc(mdata,[0 127]);
            colormap(gmap);
        end
        
        % display v1 in RGB coding
        if display_mode == 7 || display_mode == 8
            
            if ~isempty(dti_fa_overlay)
            
                % display fa
                fa_data = rot90(fliplr(squeeze(dti_fa_overlay(:,c,:))));
                fa_data = fa_data * contrast_value;
                idx = find(fa_data > 127);
                fa_data(idx) = 127;
            
            end
            
            hold on;

            % calculate vector colors (for each voxel)
            dti_colour_top = zeros(slice_dim(1), slice_dim(3), 3);
            for z_vox=1:slice_dim(3)
                for x_vox=1:slice_dim(1)

                      dti_colour_top(x_vox, z_vox, 1) = uint8(abs(dti_v1_overlay.x.img(x_vox, c, z_vox))*255);
                      dti_colour_top(x_vox, z_vox, 2) = uint8(abs(dti_v1_overlay.y.img(x_vox, c, z_vox))*255);
                      dti_colour_top(x_vox, z_vox, 3) = uint8(abs(dti_v1_overlay.z.img(x_vox, c, z_vox))*255);
                end
            end

            if(dti_v1_overlay.x.hdr.dime.datatype==2)
                dti_colour_top=uint8(dti_colour_top);
            else
                maxVal = max(max(max(dti_colour_top)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                dti_colour_top = scaleTo8bit*dti_colour_top; 
                dti_colour_top = uint8(dti_colour_top);
            end

            %display vector colors
            o_data(:,:,1) = rot90(fliplr(squeeze(dti_colour_top(:,:,1))));
            o_data(:,:,2) = rot90(fliplr(squeeze(dti_colour_top(:,:,2))));
            o_data(:,:,3) = rot90(fliplr(squeeze(dti_colour_top(:,:,3))));    
            o_data = o_data * contrast_value;
            im = imagesc(o_data);

            if ~isempty(dti_fa_overlay)
                m = fa_data*2;
                m = m .* overlayAlpha;
                set(im, 'AlphaData', m);
            else
                m = o_data(:,:,1)==0 & o_data(:,:,2)==0 & o_data(:,:,3)==0;
                m = ~m;
                set(im, 'AlphaData', m);
            end

            hold off;
        end
        
        if ~isempty(overlay_img)
            
            hold on;
            
            for i=1:size(overlay_img,2)
                overlay = overlay_img{i};
                img = rot90(fliplr(squeeze(overlay(:,c,:))));
                mask_img = img>(128+(128*i));
                im = imagesc(img, [0 896]);
                set(im, 'AlphaData', mask_img);
            end
            
            if display_mode == 5 || display_mode == 6
                colormap(overlay_tmaps);
            else
                colormap(overlay_cmaps);
            end
            
            hold off;
            
        end
        
        if display_mode == 2 || drawing
            hold on;
            
            mask_colour = rot90(fliplr(squeeze(mask(:,c,:))));
            mask_colour_img = mask_colour;
            mask_colour_img(mask_colour_img==1) = 175;
            im = imagesc(mask_colour_img, [0 896]);
            set(im, 'AlphaData', mask_colour);
            colormap(overlay_cmaps);
            
            hold off;
        end
        
        axis off;
        cor_hor=line([1, slice_dim(1)],[a, a],'color',orange);
        cor_ver=line([s, s],[1, slice_dim(3)],'color',orange);
        
    end

    function axi_view_big(s,c,a)

        % RAS -> RPI coordinates for display
        s = s+1;
        c = slice_dim(2)-c;
        a = slice_dim(3)-a;
        
        if display_mode~=6
          mdata = rot90(fliplr(squeeze(img_display(:,:,a))));
        end
        
        % display mask or outline in yellow
        if display_mode == 1
            bet_mask = mdata==127;
            mdata = mdata * contrast_value;
            mdata(bet_mask) = 220;
            mdata(mdata>127 & ~bet_mask) = 127;
            
            imagesc(mdata, [0 255]);
            colormap(cmap);
            
        elseif display_mode == 2
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(cmap);
            
        elseif display_mode == 3
            mdata(mdata~=0) = 175;
            imagesc(mdata, [0 255]);
            colormap(cmap);

        elseif display_mode == 5
            
            mdata = mdata*contrast_value;
            mdata(mdata>127) = 127;
            imagesc(mdata,[0 255]);
            colormap(tmap);

            hold on;

            % influence transparency (allow background image to show
            % through when tract data low)
            img = rot90(fliplr(squeeze(tract_colour_top(:,:,a))));
            im = imagesc(img,[0 255]);
            m = img > 128;
            m = m .* overlayAlpha;
            set(im, 'AlphaData', m);
            hold off;
            
        elseif display_mode == 6
            blank_img = zeros(max_dim, max_dim);
            imagesc(blank_img, [0 255]);
            colormap(tmap);
            
            hold on;
            im = imagesc(axi_tract_proj, [0 255]);
            m = axi_tract_proj > 128;
            set(im, 'AlphaData', m);
            hold off;
        else
            mdata = mdata * contrast_value;
            mdata(mdata > 127) = 127;

            imagesc(mdata,[0 127]);
            colormap(gmap);
        end
        
        if display_mode == 7 || display_mode == 8

            if ~isempty(dti_fa_overlay)
                % display fa
                fa_data = rot90(fliplr(squeeze(dti_fa_overlay(:,:,a))));
                fa_data = fa_data * contrast_value;
                idx = find(fa_data > 127);
                fa_data(idx) = 127;
            end
            
            hold on;

            % display v1 in RGB coding: calculate vector colors (for each voxel)
            dti_colour_top = zeros(slice_dim(1), slice_dim(2), 3);

            for y_vox=1:slice_dim(2)
                for x_vox=1:slice_dim(1)

                      dti_colour_top(x_vox, y_vox, 1) = uint8(abs(dti_v1_overlay.x.img(x_vox, y_vox, a))*255);
                      dti_colour_top(x_vox, y_vox, 2) = uint8(abs(dti_v1_overlay.y.img(x_vox, y_vox, a))*255);
                      dti_colour_top(x_vox, y_vox, 3) = uint8(abs(dti_v1_overlay.z.img(x_vox, y_vox, a))*255);
                end
            end

            if(dti_v1_overlay.x.hdr.dime.datatype==2)
                dti_colour_top=uint8(dti_colour_top);
            else
                maxVal = max(max(max(dti_colour_top)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                img_scaled = scaleTo8bit*dti_colour_top; 
                dti_colour_top = uint8(img_scaled);
            end

            % display vector colors
            o_data(:,:,1) = rot90(fliplr(squeeze(dti_colour_top(:,:,1))));
            o_data(:,:,2) = rot90(fliplr(squeeze(dti_colour_top(:,:,2))));
            o_data(:,:,3) = rot90(fliplr(squeeze(dti_colour_top(:,:,3))));      
            o_data = o_data * contrast_value;
            im = imagesc(o_data);

            if ~isempty(dti_fa_overlay)
                % brightness of colours depends on underlying fa image
                m = fa_data*2;
                m = m .* overlayAlpha;
                set(im, 'AlphaData', m);
            else
                m = o_data(:,:,1)==0 & o_data(:,:,2)==0 & o_data(:,:,3)==0;
                m = ~m;
                set(im, 'AlphaData', m);
            end
            
            hold off;
        end
        
         if ~isempty(overlay_img)
            
            hold on;
            
            for i=1:size(overlay_img,2)
                overlay = overlay_img{i};
                img = rot90(fliplr(squeeze(overlay(:,:, a))));
                mask_img = img>(128+(128*i));
                im = imagesc(img, [0 896]);
                set(im, 'AlphaData', mask_img);
            end
            if display_mode == 5 || display_mode == 6
                colormap(overlay_tmaps);
            else
                colormap(overlay_cmaps);
            end
            hold off;
            
        end
        
        
        if display_mode == 2 || drawing
            hold on;
            
            mask_colour = rot90(fliplr(squeeze(mask(:,:,a))));
            mask_colour_img = mask_colour;
            mask_colour_img(mask_colour_img==1) = 175;
            im = imagesc(mask_colour_img, [0 896]);
            set(im, 'AlphaData', mask_colour);
            colormap(overlay_cmaps);
            
            hold off;
        end
        
        axis off;
        axi_hor=line([1,slice_dim(1)],[c, c],'color',orange);
        axi_ver=line([s, s],[1, slice_dim(3)],'color',orange);
        
    end   

    function sagaxis_big_view
                
        oldcoords_big = oldcoords;
        slice1_big_RAS = oldcoords_big(1);
        scrsz = get(0,'ScreenSize');
        f_big=figure('Name', 'Viewer Sagittal', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@clickcursor_big, 'CloseRequestFcn', @close_big_callback);
        
        % when close, update main window viewer settings
        function close_big_callback(~,~)
            
            delete(f_big);
            
            oldcoords = oldcoords_big;
            if markersize==0
                set(SMALL_MARKER, 'value', 1);
                set(MED_MARKER, 'value', 0);
                set(LARGE_MARKER, 'value', 0);
            elseif markersize==1
                set(MED_MARKER, 'value', 1);
                set(SMALL_MARKER, 'value', 0);
                set(LARGE_MARKER, 'value', 0);
            else
                set(LARGE_MARKER, 'value', 1);
                set(SMALL_MARKER, 'value', 0);
                set(MED_MARKER, 'value', 0);
            end
            if marker
                set(marker_toggle, 'BackgroundColor', light_blue, 'value', 1);
                set(eraser_toggle, 'BackgroundColor', 'white', 'value', 0);
            else
                set(marker_toggle, 'BackgroundColor', 'white', 'value', 0);
                set(eraser_toggle, 'BackgroundColor', light_blue, 'value', 1);
            end
            

            slice1_RAS=oldcoords(1);
            sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
            set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
            set(SAGITTAL_SLIDER,'Value', oldcoords(1)+1);
            slice2_RAS=oldcoords(2);
            sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
            set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
            set(CORONAL_SLIDER,'Value', slice_dim(2)-oldcoords(2));
            slice3_RAS=oldcoords(3);
            sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
            set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
            set(AXIS_SLIDER,'Value', slice_dim(3)-oldcoords(3));
            
            axi_view(oldcoords(1),oldcoords(2), oldcoords(3));
            cor_view(oldcoords(1),oldcoords(2), oldcoords(3));
            sag_view(oldcoords(1),oldcoords(2), oldcoords(3));
        end
        
        sag_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        
        SAGITTAL_SLIDER_BIG = uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(1),...
            'Value',slice1_RAS+1, 'sliderStep', [1 1]/(slice_dim(1)-1),'BackGroundColor',[0.9 0.9 0.9],'callback',@sagittal_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.4 0.08 0.05 0.02],'String','Left','HorizontalAlignment','left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.05 0.02],'String','Right','HorizontalAlignment','right',...
            'BackgroundColor','White','ForegroundColor','red');
        slice1_str = sprintf('Slice %d/%d', slice1_big_RAS, slice_dim(1)-1);
        SLICE1_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String',slice1_str,'HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');
        
        function sagittal_slider_big_Callback(src,evt)
            slice1_big_RAS = round(get(src,'Value'))-1;
            sliceStr1 = sprintf('Slice: %d/%d', slice1_big_RAS, slice_dim(1)-1);
            set(SLICE1_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(1)= slice1_big_RAS;
            sag_RAS = oldcoords_big(1);
            sliceStr1 = sprintf('%d %d %d', sag_RAS,cor_RAS, axi_RAS);
            set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            
            sag_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.06 0.04 0.25 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.12 0.02 0.2 0.04],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1);
        cor_RAS = oldcoords_big(2);
        axi_RAS = oldcoords_big(3);
        
        sliceStr1 = sprintf('%d %d %d', sag_RAS,cor_RAS, axi_RAS);
        
        sag_RAS = oldcoords_big(1);
        cor_RAS = oldcoords_big(2);
        axi_RAS = oldcoords_big(3);

        
        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
        function clickcursor_big(~,~)
            posit = round(get(gca,'currentpoint'));
            if posit(1,2) <= size(img_display,1) && posit(1,1) <= size(img_display,1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[oldcoords_big(1),slice_dim(2)-posit(1,1),slice_dim(3)-posit(1,2)];
                sag_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
                sag_RAS = oldcoords_big(1);
                cor_RAS = oldcoords_big(2);
                axi_RAS = oldcoords_big(3);
                sliceStr1 = sprintf('%d %d %d', sag_RAS,cor_RAS, axi_RAS );              
                set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            end
        end

        
        marker_bg_big = uibuttongroup('Position', [0.34 0.015 0.08 0.04], 'SelectionChangeFcn', @bselection);
        marker_toggle_big = uicontrol(marker_bg_big, 'Style','togglebutton','units','normalized','fontname','lucinda','Position',...
            [0 0.5 1 0.5],'String','Marker','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor',light_blue,'ForegroundColor','Black');
        eraser_toggle_big = uicontrol(marker_bg_big, 'Style','togglebutton','units','normalized','fontname','lucinda','Position',...
            [0 0 1 0.5],'String','Eraser','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor','White','ForegroundColor','Black');
        
            function bselection(~, evt)
                set(evt.NewValue, 'backgroundColor', light_blue);
                set(evt.OldValue, 'backgroundColor', 'white');
                if evt.NewValue==marker_toggle_big
                    marker = 1;
                else
                    marker = 0;
                end
            end
            
        LARGE_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.43 0.03 0.12 0.02],'String','5x5 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10, 'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @large_marker_big_callback);
        function large_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 2;
                set(SMALL_MARKER_BIG,'value', 0);
                set(MED_MARKER_BIG, 'value', 0);
            end
        end
        MED_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.56 0.03 0.12 0.02],'String','3x3 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10,'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @medium_marker_big_callback);
        function medium_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 1;
                set(SMALL_MARKER_BIG,'value', 0);
                set(LARGE_MARKER_BIG, 'value', 0);
            end
        end
        SMALL_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.69 0.03 0.12 0.02],'String','1x1 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10,'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @small_marker_big_callback);
        function small_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 0;
                set(LARGE_MARKER_BIG,'value', 0);
                set(MED_MARKER_BIG, 'value', 0);
            end
        end

        UNDO_BUTTON_BIG = uicontrol('Style','PushButton','Units','Normalized','Position', [0.83 0.025 0.08 0.03], 'callback', @undo_big_callback, ...
            'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor', 'red','visible', 'off', 'String', 'UNDO');
        
            
        % either enable drawing or setting of fiducials
        if strcmp(get(CREATE_MASK_BUTTON, 'string'), 'Pause')
            set(marker_bg_big, 'visible', 'on');
            set(LARGE_MARKER_BIG, 'visible', 'on');
            set(MED_MARKER_BIG, 'visible', 'on');
            set(SMALL_MARKER_BIG, 'visible', 'on');
            set(UNDO_BUTTON_BIG, 'visible', 'on');
            set(f_big,'WindowButtonDownFcn', @down_big_callback);
            if markersize==0
                set(SMALL_MARKER_BIG, 'value', 1);
            elseif markersize==1
                set(MED_MARKER_BIG, 'value', 1);
            else
                set(LARGE_MARKER_BIG, 'value', 1);
            end
            if marker
                set(marker_toggle_big, 'BackgroundColor', light_blue);
                set(eraser_toggle_big, 'BackgroundColor', 'white');
            else
                set(marker_toggle_big, 'BackgroundColor', 'white');
                set(eraser_toggle_big, 'BackgroundColor', light_blue);
            end

        end
        
        % Drawing function 1
        function down_big_callback(~,~)
 
            curpos = round(get(gca, 'currentpoint'));

            prev = mask;

            if ~isempty(curpos) && curpos(1,1) >= 1 && curpos(1,2) >= 1 && curpos(1,2) <= size(img_display,1) && curpos(1,1) <= size(img_display,1)
                
                
                mask_img = rot90(fliplr(squeeze(mask(oldcoords_big(1)+1, :,:))));

                [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
                i = x<1 | x>slice_dim(2) | y<1 | y>slice_dim(3);
                x(i) = []; y(i) = [];
                if marker
                    mask_img(y,x) = 1;
                else
                    mask_img(y,x) = 0;
                end

                mask(oldcoords_big(1)+1, :, :) = fliplr(rot90(mask_img, -1));
                                          
                sag_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));

            end

            colormap(overlay_cmaps);
            set(f_big, 'WindowButtonMotionFcn',@move_big_callback, 'WindowButtonUpFcn',@up_big_callback)

        end

        % Drawing function 2: when move cursor, extend line to include new positions
        function move_big_callback(~,~)

            curpos = round(get(gca, 'currentpoint'));

            if ~isempty(curpos) && curpos(1,1) >= 1 && curpos(1,2) >= 1 && curpos(1,2) <= size(img_display,1) && curpos(1,1) <= size(img_display,1)
                
                mask_img = rot90(fliplr(squeeze(mask(oldcoords_big(1)+1, :,:))));

                [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
                i = x<1 | x>slice_dim(2) | y<1 | y>slice_dim(3);
                x(i) = []; y(i) = [];
                if marker
                    mask_img(y,x) = 1;
                else
                    mask_img(y,x) = 0;
                end

                mask(oldcoords_big(1)+1, :, :) = fliplr(rot90(mask_img, -1));
                
                sag_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));
            end
        end

        % Drawing function 3: when release click, end line
        function up_big_callback(~,~)

            set(f_big, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
            set(UNDO_BUTTON_BIG, 'enable', 'on');
            sag_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));

        end

        % undo most recent drawing
        function undo_big_callback(~,~)
            set(UNDO_BUTTON_BIG, 'enable', 'off');
            mask = prev;           
            sag_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));
        end
    end

    function coraxis_big_view
                
        oldcoords_big = oldcoords;
        slice2_big_RAS = oldcoords_big(2);
        scrsz = get(0,'ScreenSize');
        f_big=figure('Name', 'Viewer Coronal', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@clickcursor_big, 'CloseRequestFcn', @close_big_callback);
          
        % when close, update main window viewer settings
        function close_big_callback(~,~)
            
            delete(f_big);
            
            oldcoords = oldcoords_big;
            if markersize==0
                set(SMALL_MARKER, 'value', 1);
                set(MED_MARKER, 'value', 0);
                set(LARGE_MARKER, 'value', 0);
            elseif markersize==1
                set(MED_MARKER, 'value', 1);
                set(SMALL_MARKER, 'value', 0);
                set(LARGE_MARKER, 'value', 0);
            else
                set(LARGE_MARKER, 'value', 1);
                set(SMALL_MARKER, 'value', 0);
                set(MED_MARKER, 'value', 0);
            end
            if marker
                set(marker_toggle, 'BackgroundColor', light_blue, 'value', 1);
                set(eraser_toggle, 'BackgroundColor', 'white', 'value', 0);
            else
                set(marker_toggle, 'BackgroundColor', 'white', 'value', 0);
                set(eraser_toggle, 'BackgroundColor', light_blue, 'value', 1);
            end
            
            slice1_RAS=oldcoords(1);
            sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
            set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
            set(SAGITTAL_SLIDER,'Value', oldcoords(1)+1);
            slice2_RAS=oldcoords(2);
            sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
            set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
            set(CORONAL_SLIDER,'Value', slice_dim(2)-oldcoords(2));
            slice3_RAS=oldcoords(3);
            sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
            set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
            set(AXIS_SLIDER,'Value', slice_dim(3)-oldcoords(3));
            
            axi_view(oldcoords(1),oldcoords(2), oldcoords(3));
            cor_view(oldcoords(1),oldcoords(2), oldcoords(3));
            sag_view(oldcoords(1),oldcoords(2), oldcoords(3));
        end

        cor_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(2),...
            'Value',slice_dim(2)-slice2_big_RAS, 'sliderStep', [1 1]/(slice_dim(2)-1),'BackGroundColor',[0.9 0.9 0.9],'callback',@coronal_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.38 0.08 0.06 0.02],'String','Anterior','HorizontalAlignment','Left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.08 0.02],'String','Posterior','HorizontalAlignment','Right',...
            'BackgroundColor','White','ForegroundColor','red');
        
        sliceStr1 = sprintf('Slice: %d/%d', slice2_big_RAS, slice_dim(2)-1);
        SLICE2_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');

        function coronal_slider_big_Callback(src,~)
            slice2_big_RAS = slice_dim(2)-round(get(src,'Value'));
            sliceStr1 = sprintf('Slice: %d/%d', slice2_big_RAS, slice_dim(2)-1);
            set(SLICE2_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(2)= slice2_big_RAS;
            cor_RAS = oldcoords_big(2);
            sliceStr1 = sprintf('%d %d %d', sag_RAS,cor_RAS, axi_RAS);
            set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            
            cor_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.06 0.04 0.25 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.12 0.02 0.24 0.04],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1);
        cor_RAS = oldcoords_big(2);
        axi_RAS = oldcoords_big(3);
        sliceStr1 = sprintf('%d %d %d ', sag_RAS,cor_RAS, axi_RAS);

        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
        function clickcursor_big(~,~)
            posit = round(get(gca,'currentpoint'));
            if posit(1,2) <= size(img_display,1) && posit(1,1) <= size(img_display,1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[posit(1,1)-1,oldcoords_big(2),slice_dim(3)-posit(1,2)];
                cor_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
                sag_RAS = oldcoords_big(1);
                cor_RAS = oldcoords_big(2);
                axi_RAS = oldcoords_big(3);
                sliceStr1 = sprintf('%d %d %d', sag_RAS,cor_RAS, axi_RAS);
                set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            end
        end

        marker_bg_big = uibuttongroup('Position', [0.34 0.015 0.08 0.04], 'SelectionChangeFcn', @bselection);
        marker_toggle_big = uicontrol(marker_bg_big, 'Style','togglebutton','units','normalized','fontname','lucinda','Position',...
            [0 0.5 1 0.5],'String','Marker','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor',light_blue,'ForegroundColor','Black');
        eraser_toggle_big = uicontrol(marker_bg_big, 'Style','togglebutton','units','normalized','fontname','lucinda','Position',...
            [0 0 1 0.5],'String','Eraser','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor','White','ForegroundColor','Black');
        
            function bselection(~, evt)
                set(evt.NewValue, 'backgroundColor', light_blue);
                set(evt.OldValue, 'backgroundColor', 'white');
                if evt.NewValue==marker_toggle_big
                    marker = 1;
                else
                    marker = 0;
                end
            end
        LARGE_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.43 0.03 0.12 0.02],'String','5x5 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10, 'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @large_marker_big_callback);
        function large_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 2;
                set(SMALL_MARKER_BIG,'value', 0);
                set(MED_MARKER_BIG, 'value', 0);
            end
        end
        MED_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.56 0.03 0.12 0.02],'String','3x3 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10,'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @medium_marker_big_callback);
        function medium_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 1;
                set(SMALL_MARKER_BIG,'value', 0);
                set(LARGE_MARKER_BIG, 'value', 0);
            end
        end
        SMALL_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.69 0.03 0.12 0.02],'String','1x1 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10,'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @small_marker_big_callback);
        function small_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 0;
                set(LARGE_MARKER_BIG,'value', 0);
                set(MED_MARKER_BIG, 'value', 0);
            end
        end

        UNDO_BUTTON_BIG = uicontrol('Style','PushButton','Units','Normalized','Position', [0.83 0.025 0.08 0.03], 'callback', @undo_big_callback, ...
            'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor', 'red','visible', 'off', 'String', 'UNDO');
        
        % enable either drawing of setting fiducials
        if strcmp(get(CREATE_MASK_BUTTON, 'string'), 'Pause')
            set(marker_bg_big, 'visible', 'on');
            set(LARGE_MARKER_BIG, 'visible', 'on');
            set(MED_MARKER_BIG, 'visible', 'on');
            set(SMALL_MARKER_BIG, 'visible', 'on');
            set(UNDO_BUTTON_BIG, 'visible', 'on');
            set(f_big,'WindowButtonDownFcn', @down_big_callback);
            
            if markersize==0
                set(SMALL_MARKER_BIG, 'value', 1);
            elseif markersize==1
                set(MED_MARKER_BIG, 'value', 1);
            else
                set(LARGE_MARKER_BIG, 'value', 1);
            end
            
            if marker
                set(marker_toggle_big, 'BackgroundColor', light_blue);
                set(eraser_toggle_big, 'BackgroundColor', 'white');
            else
                set(marker_toggle_big, 'BackgroundColor', 'white');
                set(eraser_toggle_big, 'BackgroundColor', light_blue);
            end
            
        end
        
        % Drawing function 1
        function down_big_callback(~,~)

            curpos = round(get(gca, 'currentpoint'));

            prev = mask;

            if ~isempty(curpos) && curpos(1,1) >= 1 && curpos(1,2) >= 1 && curpos(1,2) <= size(img_display,1) && curpos(1,1) <= size(img_display,1)


                mask_img = rot90(fliplr(squeeze(mask(:,slice_dim(2)-oldcoords_big(2), :))));
                [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
                i = x<1 | x>slice_dim(1) | y<1 | y>slice_dim(3);
                x(i) = []; y(i) = [];
                if marker
                    mask_img(y,x) = 1;
                else
                    mask_img(y,x) = 0;
                end

                mask(:, slice_dim(2)-oldcoords_big(2), :) = fliplr(rot90(mask_img, -1));                         
                cor_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));
            end

            colormap(overlay_cmaps);
            set(f_big, 'WindowButtonMotionFcn',@move_big_callback, 'WindowButtonUpFcn',@up_big_callback)

        end

        % Drawing function 2: when move cursor, extend line to include new positions
        function move_big_callback(~,~)

            curpos = round(get(gca, 'currentpoint'));

            if ~isempty(curpos) && curpos(1,1) >= 1 && curpos(1,2) >= 1 && curpos(1,2) <= size(img_display,1) && curpos(1,1) <= size(img_display,1)               

                mask_img = rot90(fliplr(squeeze(mask(:,slice_dim(2)-oldcoords_big(2), :))));

                [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
                i = x<1 | x>slice_dim(1) | y<1 | y>slice_dim(3);
                x(i) = []; y(i) = [];
                if marker
                    mask_img(y,x) = 1;
                else
                    mask_img(y,x) = 0;
                end

                mask(:, slice_dim(2)-oldcoords_big(2), :) = fliplr(rot90(mask_img, -1));
                cor_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));
            end
        end

        % Drawing function 3: when release click, end line
        function up_big_callback(~,~)

            set(f_big, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
            set(UNDO_BUTTON_BIG, 'enable', 'on');
            cor_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));

        end

        % undo most recent drawing
        function undo_big_callback(~,~)
            set(UNDO_BUTTON_BIG, 'enable', 'off');
            mask = prev;          
            cor_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));
        end
    end

    function axiaxis_big_view
                
        oldcoords_big = oldcoords;
        slice3_big_RAS = oldcoords_big(3);
        scrsz = get(0,'ScreenSize');
        f_big=figure('Name', 'Viewer Axial', 'Position', [(scrsz(3)-800)/2 (scrsz(4)-800)/2 800 800],...
            'menubar','none','numbertitle','off', 'Color','white','WindowButtonUpFcn',@clickcursor_big, 'CloseRequestFcn', @close_big_callback);
        
        % when close, update main window viewer settings
        function close_big_callback(~,~)
            
            delete(f_big);
            
            oldcoords = oldcoords_big;
            if markersize==0
                set(SMALL_MARKER, 'value', 1);
                set(MED_MARKER, 'value', 0);
                set(LARGE_MARKER, 'value', 0);
            elseif markersize==1
                set(MED_MARKER, 'value', 1);
                set(SMALL_MARKER, 'value', 0);
                set(LARGE_MARKER, 'value', 0);
            else
                set(LARGE_MARKER, 'value', 1);
                set(SMALL_MARKER, 'value', 0);
                set(MED_MARKER, 'value', 0);
            end
            if marker
                set(marker_toggle, 'BackgroundColor', light_blue, 'value', 1);
                set(eraser_toggle, 'BackgroundColor', 'white', 'value', 0);
            else
                set(marker_toggle, 'BackgroundColor', 'white', 'value', 0);
                set(eraser_toggle, 'BackgroundColor', light_blue, 'value', 1);
            end
            
            slice1_RAS=oldcoords(1);
            sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
            set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
            set(SAGITTAL_SLIDER,'Value', oldcoords(1)+1);
            slice2_RAS=oldcoords(2);
            sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
            set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
            set(CORONAL_SLIDER,'Value', slice_dim(2)-oldcoords(2));
            slice3_RAS=oldcoords(3);
            sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
            set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
            set(AXIS_SLIDER,'Value', slice_dim(3)-oldcoords(3));
            
            axi_view(oldcoords(1),oldcoords(2), oldcoords(3));
            cor_view(oldcoords(1),oldcoords(2), oldcoords(3));
            sag_view(oldcoords(1),oldcoords(2), oldcoords(3));
        end
        
        axi_view_big(oldcoords(1),oldcoords(2),oldcoords(3));
        AXI_SLIDER_BIG = uicontrol('style','slider','units', 'normalized','position',[0.45 0.08 0.4 0.02],'min',1,'max',slice_dim(3),...
            'Value',slice_dim(3)-slice3_RAS, 'sliderStep', [1 1]/(slice_dim(3)-1),'BackGroundColor',[0.9 0.9 0.9],'callback',@axial_slider_big_Callback);
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.38 0.08 0.06 0.02],'String','Superior','HorizontalAlignment','Left',...
            'BackgroundColor','White','ForegroundColor','red');
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.86 0.08 0.08 0.02],'String','Inferior','HorizontalAlignment','Right',...
            'BackgroundColor','White','ForegroundColor','red');
        
        sliceStr1 = sprintf('Slice: %d/%d', slice3_big_RAS, slice_dim(3)-1);
        SLICE3_EDIT_BIG = uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',...
            [0.2 0.08 0.15 0.02],'String',sliceStr1,'HorizontalAlignment','left',...
            'BackgroundColor','White', 'enable','on');
        
        function axial_slider_big_Callback(src,~)
            slice3_big_RAS = slice_dim(3)-round(get(src,'Value'));
            sliceStr1 = sprintf('Slice: %d/%d', slice3_big_RAS, slice_dim(3)-1);
            set(SLICE3_EDIT_BIG,'String',sliceStr1);
            oldcoords_big(3)= slice3_big_RAS;
            axi_RAS = oldcoords_big(3);
            sliceStr1 = sprintf('%d %d %d', sag_RAS,cor_RAS, axi_RAS);
            set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            
            axi_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
        end
        
        uicontrol('Style','Text','FontSize',10,'Units','Normalized','Position',[0.06 0.05 0.06 0.02],'String','Voxel:','HorizontalAlignment','left',...
            'BackgroundColor','White');
        POSITION_VALUE = uicontrol('Style','Text','FontSize',11,'Units','Normalized','Position',[0.12 0.03 0.15 0.04],'String',' ','HorizontalAlignment','left',...
            'BackgroundColor','White');
        sag_RAS = oldcoords_big(1);
        cor_RAS = oldcoords_big(2);
        axi_RAS = oldcoords_big(3);

        sliceStr1 = sprintf('%d %d %d', sag_RAS,cor_RAS, axi_RAS);

        set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
        function clickcursor_big(~,~)
            posit = round(get(gca,'currentpoint'));
            if posit(1,2) <= size(img_display,1) && posit(1,1) <= size(img_display,1) && posit(1,2) >= 0 && posit(1,1) >=0
                oldcoords_big=[posit(1,1)-1,slice_dim(2)-posit(1,2),oldcoords_big(3)];
                axi_view_big(oldcoords_big(1),oldcoords_big(2),oldcoords_big(3));
                sag_RAS = oldcoords_big(1);
                cor_RAS = oldcoords_big(2);
                axi_RAS = oldcoords_big(3);
                sliceStr1 = sprintf('%d %d %d', sag_RAS,cor_RAS, axi_RAS);
                set(POSITION_VALUE,'String',sliceStr1, 'enable','on');
            end
        end
        
        marker_bg_big = uibuttongroup('Position', [0.34 0.015 0.08 0.04], 'SelectionChangeFcn', @bselection);
        marker_toggle_big = uicontrol(marker_bg_big, 'Style','togglebutton','units','normalized','fontname','lucinda','Position',...
            [0 0.5 1 0.5],'String','Marker','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor',light_blue,'ForegroundColor','Black');
        eraser_toggle_big = uicontrol(marker_bg_big, 'Style','togglebutton','units','normalized','fontname','lucinda','Position',...
            [0 0 1 0.5],'String','Eraser','HorizontalAlignment','left','FontSize', 10,...
            'BackgroundColor','White','ForegroundColor','Black');
        
            function bselection(~, evt)
                set(evt.NewValue, 'backgroundColor', light_blue);
                set(evt.OldValue, 'backgroundColor', 'white');
                if evt.NewValue==marker_toggle_big
                    marker = 1;
                else
                    marker = 0;
                end
            end
        LARGE_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.43 0.03 0.12 0.02],'String','5x5 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10, 'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @large_marker_big_callback);
        function large_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 2;
                set(SMALL_MARKER_BIG,'value', 0);
                set(MED_MARKER_BIG, 'value', 0);
            end
        end
        MED_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.56 0.03 0.12 0.02],'String','3x3 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10,'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @medium_marker_big_callback);
        function medium_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 1;
                set(SMALL_MARKER_BIG,'value', 0);
                set(LARGE_MARKER_BIG, 'value', 0);
            end
        end
        SMALL_MARKER_BIG = uicontrol('Style', 'radiobutton', 'units','normalized','fontname','lucinda','Position',...
        [0.69 0.03 0.12 0.02],'String','1x1 voxels','HorizontalAlignment','left','value', 0,'FontSize', 10,'visible', 'off',...
        'BackgroundColor','White','ForegroundColor','Black', 'Callback', @small_marker_big_callback);
        function small_marker_big_callback(src, ~)
            if get(src, 'Value')
                markersize = 0;
                set(LARGE_MARKER_BIG,'value', 0);
                set(MED_MARKER_BIG, 'value', 0);
            end
        end

        UNDO_BUTTON_BIG = uicontrol('Style','PushButton','Units','Normalized','Position', [0.83 0.025 0.08 0.03], 'callback', @undo_big_callback, ...
            'HorizontalAlignment','Center','FontSize', 11, 'ForegroundColor', 'red','visible', 'off', 'String', 'UNDO');
        
        % enable either drawing or setting fiducials
        if strcmp(get(CREATE_MASK_BUTTON, 'string'), 'Pause')
            set(marker_bg_big, 'visible', 'on');
            set(LARGE_MARKER_BIG, 'visible', 'on');
            set(MED_MARKER_BIG, 'visible', 'on');
            set(SMALL_MARKER_BIG, 'visible', 'on');
            set(UNDO_BUTTON_BIG, 'visible', 'on');
            set(f_big,'WindowButtonDownFcn', @down_big_callback);
            if markersize==0
                set(SMALL_MARKER_BIG, 'value', 1);
            elseif markersize==1
                set(MED_MARKER_BIG, 'value', 1);
            else
                set(LARGE_MARKER_BIG, 'value', 1);
            end
            if marker
                set(marker_toggle_big, 'BackgroundColor', light_blue, 'value', 1);
                set(eraser_toggle_big, 'BackgroundColor', 'white', 'value', 0);
            else
                set(marker_toggle_big, 'BackgroundColor', 'white', 'value', 0);
                set(eraser_toggle_big, 'BackgroundColor', light_blue, 'value', 1);
            end
        end
        
        % drawing function 1
        function down_big_callback(~,~)

            curpos = round(get(gca, 'currentpoint'));

            prev = mask;

            if ~isempty(curpos) && curpos(1,1) >= 1 && curpos(1,2) >= 1 && curpos(1,2) <= size(img_display,1) && curpos(1,1) <= size(img_display,1)

                mask_img = rot90(fliplr(squeeze(mask(:,:,slice_dim(3)-oldcoords_big(3)))));

                [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
                i = x<1 | x>slice_dim(1) | y<1 | y>slice_dim(2);
                x(i) = []; y(i) = [];
                if marker
                    mask_img(y,x) = 1;
                else
                    mask_img(y,x) = 0;
                end

                mask(:, :, slice_dim(3)-oldcoords_big(3)) = fliplr(rot90(mask_img, -1));              
                axi_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));

            end

            colormap(overlay_cmaps);
            set(f_big, 'WindowButtonMotionFcn',@move_big_callback, 'WindowButtonUpFcn',@up_big_callback)

        end

        % drawing function 2: when move cursor, extend line to include new positions
        function move_big_callback(~,~)

            curpos = round(get(gca, 'currentpoint'));

            if ~isempty(curpos) && curpos(1,1) >= 1 && curpos(1,2) >= 1 && curpos(1,2) <= size(img_display,1) && curpos(1,1) <= size(img_display,1)
                 % expand extent of editing for normalized images
                % (interpolated)


                mask_img = rot90(fliplr(squeeze(mask(:,:,slice_dim(3)-oldcoords_big(3)))));

                [x, y] = meshgrid(curpos(1,1)-markersize:curpos(1,1)+markersize, curpos(1,2)-markersize:curpos(1,2)+markersize);
                i = x<1 | x>slice_dim(1) | y<1 | y>slice_dim(2);
                x(i) = []; y(i) = [];
                if marker
                    mask_img(y,x) = 1;
                else
                    mask_img(y,x) = 0;
                end

                mask(:, :, slice_dim(3)-oldcoords_big(3)) = fliplr(rot90(mask_img, -1));
                axi_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));
            end
        end

        % drawing function 3: when release click, end line
        function up_big_callback(~,~)

            set(f_big, 'WindowButtonMotionFcn', '', 'WindowButtonUpFcn', '');
            set(UNDO_BUTTON_BIG, 'enable', 'on');            
            axi_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));

        end

       % undo most recent drawing
        function undo_big_callback(~,~)
            set(UNDO_BUTTON_BIG, 'enable', 'off');
            mask = prev;          
            axi_view_big(oldcoords_big(1), oldcoords_big(2), oldcoords_big(3));
        end
    end

    function imageScroll_Callback(src,~)
        val = round(get(src,'value'));
        if val > max_volumes
            return;
        end
        set(VOLUME_EDIT,'string',num2str(val));
        goToVolume(val+1);
    end

    % display chosen volume out of all image volumes (4D images)
    
    function volume_edit_callback(src,~)       
        volume = int8(round(str2double(get(src,'String')))) + 1;
        goToVolume(volume);
    end

    function goToVolume(volume)
            
        if max_volumes==1
          set(VOLUME_EDIT, 'String', '0');
          return;
        end
        
        if volume > max_volumes
            set(VOLUME_EDIT, 'String', '0');
            volume = 1;
        end
        if display_mode==6
            img1 = data_nii.img(:,:,:,volume);        
            img_RAS=img1;

            % flip z and y directions RAS -> RPI
            img2 = flipdim(img_RAS,3);
            img = flipdim(img2,2);

            if(data_nii.hdr.dime.datatype==2)
                tract_colour_top=uint8(img);
            else
                maxVal = max(max(max(img)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                tract_colour_top = scaleTo8bit* img; 
                tract_colour_top = uint8(tract_colour_top);
            end

            % scale up image values to display in colour
            tract_colour_top = bsxfun(@plus, tract_colour_top, 128);     

            % black image background
            img_display = zeros(slice_dim(1), slice_dim(2), slice_dim(3));

            sag_tract_proj = zeros(slice_dim(3), slice_dim(2));
            axi_tract_proj = zeros(slice_dim(2), slice_dim(1));
            cor_tract_proj = zeros(slice_dim(3), slice_dim(1));
            for i=1:slice_dim(3)
                for j=1:slice_dim(2)
                    vec = tract_colour_top(:,j,i);
                    sag_tract_proj(i,j) = max(vec);
                end
            end
            for i=1:slice_dim(3)
                for j=1:slice_dim(1)
                    vec = tract_colour_top(j,:,i);
                    cor_tract_proj(i,j) = max(vec);
                end
            end
            for i=1:slice_dim(2)
                for j=1:slice_dim(1)
                    vec = tract_colour_top(j,i, :);
                    axi_tract_proj(i,j) = max(vec);
                end
            end
        else
            
            img1 = data_nii.img(:,:,:,volume);        
            img_RAS=img1;

            % flip z and y directions RAS -> RPI
            img2 = flipdim(img_RAS,3);
            img = flipdim(img2,2);

            if(data_nii.hdr.dime.datatype==2)
                img_display=uint8(img);
            else
                maxVal = max(max(max(img)));
                maxVal = double(maxVal);
                scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                img_display = scaleTo8bit* img; 
                img_display = uint8(img_display);
            end
        end
        sag_view(oldcoords(1), oldcoords(2), oldcoords(3));
        cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
        axi_view(oldcoords(1), oldcoords(2), oldcoords(3));
    end

    % control display of all image volumes (4D images)
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

    % display all volumes in order (4D images)
    function doMovieLoop
                
        isPlaying = true;        

        curV = int8(round(str2double(get(VOLUME_EDIT,'String')))) + 1;
        if curV==max_volumes
          curV = 1;
        end
        
        if display_mode==6
             for k=curV:size(data_nii.img,4)

                if ~isPlaying
                    break;   % cancelled
                end

                img1 = data_nii.img(:,:,:,k);        
                img_RAS=img1;

                % flip z and y directions RAS -> RPI
                img2 = flipdim(img_RAS,3);
                img = flipdim(img2,2);

                if(data_nii.hdr.dime.datatype==2)
                    tract_colour_top=uint8(img);
                else
                    maxVal = max(max(max(img)));
                    maxVal = double(maxVal);
                    scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                    tract_colour_top = scaleTo8bit* img; 
                    tract_colour_top = uint8(tract_colour_top);
                end
                
                % scale up image values to display in colour
                tract_colour_top = bsxfun(@plus, tract_colour_top, 128);     
                
                % black image background
                img_display = zeros(slice_dim(1), slice_dim(2), slice_dim(3));

                sag_tract_proj = zeros(slice_dim(3), slice_dim(2));
                axi_tract_proj = zeros(slice_dim(2), slice_dim(1));
                cor_tract_proj = zeros(slice_dim(3), slice_dim(1));
                for i=1:slice_dim(3)
                    for j=1:slice_dim(2)
                        vec = tract_colour_top(:,j,i);
                        sag_tract_proj(i,j) = max(vec);
                    end
                end
                for i=1:slice_dim(3)
                    for j=1:slice_dim(1)
                        vec = tract_colour_top(j,:,i);
                        cor_tract_proj(i,j) = max(vec);
                    end
                end
                for i=1:slice_dim(2)
                    for j=1:slice_dim(1)
                        vec = tract_colour_top(j,i, :);
                        axi_tract_proj(i,j) = max(vec);
                    end
                end
                
                sag_view(oldcoords(1), oldcoords(2), oldcoords(3));
                cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
                axi_view(oldcoords(1), oldcoords(2), oldcoords(3));

                volumeStr = sprintf('%d', k-1);
                set(VOLUME_EDIT, 'String', volumeStr);

                pause(0.1);
             end
        else
            for k=curV:size(data_nii.img,4)

                if ~isPlaying
                    break;   % cancelled
                end
                img1 = data_nii.img(:,:,:,k);        

                % flip z and y direction RAS -> RPI
                img2 = flipdim(img1,3);
                img = flipdim(img2,2);

                if(data_nii.hdr.dime.datatype==2)
                    img_display=uint8(img);
                else
                    maxVal = max(max(max(img)));
                    maxVal = double(maxVal);
                    scaleTo8bit = 127/maxVal;  % changed dyn range for overlay
                    img_display = scaleTo8bit* img; 
                    img_display = uint8(img_display);
                end
                sag_view(oldcoords(1), oldcoords(2), oldcoords(3));
                cor_view(oldcoords(1), oldcoords(2), oldcoords(3));
                axi_view(oldcoords(1), oldcoords(2), oldcoords(3));

                volumeStr = sprintf('%d', k-1);
                set(VOLUME_EDIT, 'String', volumeStr);

                pause(0.1);
            end
        end

    end

    % clicking on a file in list -> display file
    function file_listbox_callback(src,~)
        
        % no matter what, stop drawing
        if drawing
            drawing = 0;
            prev = [];
            set(UNDO_BUTTON, 'enable', 'off');
            set(CLEAR_BUTTON, 'enable', 'off');
            set(CREATE_MASK_BUTTON, 'String', 'Draw');
            set(SAVE_MASK_BUTTON, 'enable', 'off');
            set(f,'WindowButtonDownFcn', @buttondown);
        end
        
        fileNum = get(src, 'Value');
        
        load_selected_file(fileNum);
        
    end

    % load file (spec by file number in listbox)
    function load_selected_file(fileNum)
        
        if isempty(files)
            return;
        end
        
        if isempty(fileNum)
                return;
        else
            
            hasOverlay = false;
            overlay_img = [];
            
            % determine display depending on display mode
            mode = loaded_files{fileNum,1};
            switch mode
                   
                % SAM/ERB image
                case 4
                    file = char(loaded_files{fileNum,3});
                    display_mode = 0;
                    loadData(char(loaded_files{fileNum,2}));
                    display_mode = mode;
                    loadMEGoverlay(char(file));
                    
                    if (size(loaded_files(fileNum,:),2) > 3) && ~isempty(loaded_files{fileNum, 4})
                        hasOverlay = true;
                        overlayIdx = 4;
                    end
                    
                % tractography overlaid on base
                case 5
                    file = char(loaded_files{fileNum, 3});
                    display_mode = 0;
                    loadData(char(loaded_files{fileNum,2}));
                    display_mode = 5;
                    loadTract(file);
                    
                    if (size(loaded_files(fileNum,:),2) > 3) && ~isempty(loaded_files{fileNum, 4})
                        hasOverlay = true;
                        overlayIdx = 4;
                    end
                    
                % tractography projection
                case 6
                    display_mode = mode;
                    loadTract(char(loaded_files{fileNum, 2}));
  
                % eigenvector file
                case 7
                    display_mode = mode;
                    loadDTIOverlay(char(loaded_files{fileNum,2}), char(loaded_files{fileNum,3}));
                    
                    if (size(loaded_files(fileNum,:),2) > 3) && ~isempty(loaded_files{fileNum, 4})
                        hasOverlay = true;
                        overlayIdx = 4;
                    end
                    
                % eigenvector file overlaid on base
                case 8
                    display_mode = 0;
                    loadData(char(loaded_files{fileNum,2}));
                    display_mode = mode;
                    loadDTIOverlay(char(loaded_files{fileNum,3}), char(loaded_files{fileNum,4}));
                    
                    if (size(loaded_files(fileNum,:),2) > 4) && ~isempty(loaded_files{fileNum, 5})
                        hasOverlay = true;
                        overlayIdx = 5;
                    end
                    
                % regular (0), brain outline (1), drawing (2), or mask (3)
                otherwise
                    display_mode = mode;
                    loadData(char(loaded_files{fileNum,2}));
                    
                    if (size(loaded_files(fileNum,:),2) > 2) && ~isempty(loaded_files{fileNum, 3})
                        hasOverlay = true;
                        overlayIdx = 3;
                    end
                    
            end
            
            % display all overlay files
            if hasOverlay
               for k = overlayIdx: size(loaded_files,2)
                   file = char(loaded_files{fileNum, k});
                   if ~isempty(file)
                        loadOverlay(file);  
                   else
                       break;
                   end
               end
            end
            
         end
        
    end

    % remove file from file listbox
    function remove_Callback(~, ~)
        fileNum = get(FILE_LISTBOX, 'Value');
        
        if fileNum == 0
            imsac
        end
        
        if isempty(files) || size(files, 2)<fileNum
            return;
        end
        
        if isempty(fileNum)
                return;
        end
        
        % shift remaining files
        for i=fileNum:size(files, 2)-1
            files(i) = files(i+1);
            loaded_files(i, :) = loaded_files(i+1, :);
        end
        files(size(files,2)) = [];
        loaded_files(size(loaded_files,1), :) = [];
        
        while fileNum > size(files,2)
            fileNum = fileNum -1;
        end
        
        set(FILE_LISTBOX, 'value', fileNum);
        set(FILE_LISTBOX, 'string', files);
        
        % load file next to removed one
        load_selected_file(fileNum);
        
        set_enable_mask('on');

    end

    % removed double click - replaced with zoom buttons
    function [ax, coords] = get_cursor_coords
        
        pos_a = round(get(axiaxis, 'currentpoint'));
        pos_c = round(get(coraxis, 'currentpoint'));
        pos_s = round(get(sagaxis, 'currentpoint'));
        ax = [];
        coords = [0, 0, 0 ];
        if ~isempty(pos_a) && pos_a(1,1) >= 0 && pos_a(1,2) >= 0 && pos_a(1,2) <= size(img_display,1) && pos_a(1,1) <= size(img_display,1)
            posit = pos_a;
            coords=[posit(1,1)-1,slice_dim(2)-posit(1,2),oldcoords(3)];
            ax = axiaxis;
        elseif ~isempty(pos_c) && pos_c(1,1) >= 0 && pos_c(1,2) >= 0 && pos_c(1,2) <= size(img_display,1) && pos_c(1,1) <= size(img_display,1)
            posit = pos_c;
            coords=[posit(1,1)-1,oldcoords(2),slice_dim(3)-posit(1,2)];
            ax = coraxis;
        elseif ~isempty(pos_s) && pos_s(1,1) >= 0 && pos_s(1,2) >= 0 && pos_s(1,2) <= size(img_display,1) && pos_s(1,1) <= size(img_display,1)
            posit = pos_s;
            coords=[oldcoords(1),slice_dim(2)-posit(1,1),slice_dim(3)-posit(1,2)];    
            ax = sagaxis;
        end
        
    end
    
    function buttondown(~,~)         

        % need to move to current location first...
        [ax, posit] = get_cursor_coords;
        drawCursor(gca,posit);
        % update drawing while cursor being dragged
        set(f,'WindowButtonMotionFcn',{@dragCursor,ax}) % need to explicitly pass the axis handle to the motion callback
        set(f,'WindowButtonUpFcn', @stopdrag);
    end
 
    % button down function - drag cursor
    function dragCursor(~,~, ax)
        [ax, posit] = get_cursor_coords;   
        % update view and cursor in one call
        if ~isempty(ax)
            drawCursor(ax, posit);
        end
    end
    
    % on button up event set motion event back to no callback 
    function stopdrag(~,~)
        set(f,'WindowButtonMotionFcn','');
    end
 
    function drawCursor(ax, posit)

        switch ax
            case sagaxis
                if posit(1,2) < 1 || posit(1,2) > slice_dim(2)-1 || posit(1,3) < 1 || posit(1,3) > slice_dim(3)-1
                    return;
                end
            case coraxis
                if posit(1,1) < 1 || posit(1,1) > slice_dim(1)-1 || posit(1,3) < 1 || posit(1,3) > slice_dim(3)-1
                    return;
                end
            case axiaxis
                if posit(1,1) < 1 || posit(1,1) > slice_dim(1)-1 || posit(1,2) < 1 || posit(1,2) > slice_dim(2)-1
                    return;
                end
            otherwise
        end
        oldcoords = posit;
        
        slice1_RAS=oldcoords(1);
        sliceStr1 = sprintf('Slice: %d/%d', slice1_RAS, slice_dim(1)-1);
        set(SLICE1_EDIT,'String',sliceStr1, 'enable','on');
        set(SAGITTAL_SLIDER,'Value', oldcoords(1)+1);
        slice2_RAS=oldcoords(2);
        sliceStr2 = sprintf('Slice: %d/%d', slice2_RAS, slice_dim(2)-1);
        set(SLICE2_EDIT,'String',sliceStr2, 'enable','on');
        set(CORONAL_SLIDER,'Value', slice_dim(2)-oldcoords(2));
        slice3_RAS=oldcoords(3);
        sliceStr3 = sprintf('Slice: %d/%d', slice3_RAS, slice_dim(3)-1);
        set(SLICE3_EDIT,'String',sliceStr3, 'enable','on');
        set(AXIS_SLIDER,'Value', slice_dim(3)-oldcoords(3));

        sag_view(oldcoords(1),oldcoords(2),oldcoords(3));
        cor_view(oldcoords(1),oldcoords(2),oldcoords(3));
        axi_view(oldcoords(1),oldcoords(2),oldcoords(3));
    end

    function zoomSagittalCallback(~,~)        
        sagaxis_big_view;      
    end
    function zoomCoronalCallback(~,~)
        coraxis_big_view;      
    end
    function zoomAxialCallback(~,~)        
        axiaxis_big_view;      
    end

    % update position of crosshairs
    function updateCrosshairs(s,c,a)
        
        s = s +1;
        c = slice_dim(2) - c;
        a = slice_dim(3) - a;
        
        % cor view
        coraxis = subplot('Position', cor_subplot);
        delete(cor_hor);
        delete(cor_ver);
        axis off;
        cor_hor=line([1, size(img_display,1)],[a, a],'color',orange);
        cor_ver=line([s, s],[1, size(img_display,3)],'color',orange);
        
        % sag view
        sagaxis=subplot('Position', sag_subplot);
        delete(sag_hor);
        delete(sag_ver);
        axis off;
        sag_hor=line([1, size(img_display,2)],[a, a],'color',orange);
        sag_ver=line([c, c],[1,size(img_display,3)],'color',orange);
        
        % axi view
        axiaxis=subplot('Position', axi_subplot);
        delete(axi_hor);
        delete(axi_ver);
        axis off;
        axi_hor=line([1,size(img_display,1)],[c, c],'color',orange);
        axi_ver=line([s, s],[1, size(img_display,3)],'color',orange);
           
    end

    % warning dialog gui
    function response = warning_dialog(message, yesStr, noStr)
        if ~exist('yesStr','var')
            yesStr = 'Yes';
        end
        if ~exist('noStr','var')
            noStr = 'No';
        end
        
        scrnsizes=get(0,'MonitorPosition');
        response = 0;
        fg=figure('Name', 'Alert', 'Position', [scrnsizes(1,3)/3 scrnsizes(1,4)/2 600 140],...
            'menubar','none','numbertitle','off', 'Color','white');
        
        uicontrol('style','text','fontsize',12,'Units','Normalized','Position',...
            [0.15 0.6 0.7 0.3],'String',message,'BackgroundColor','White','HorizontalAlignment','left');

        %buttons
        uicontrol('style','pushbutton','fontsize',10,'units','normalized','position',...
            [0.265 0.1 0.2 0.3],'string',yesStr,'Backgroundcolor','white','foregroundcolor',[0.8,0.4,0.1],'callback',@yes_button_callback);

            function yes_button_callback(~,~)
                response = 1;
                uiresume(gcf);
            end   
        uicontrol('style','pushbutton','fontsize',10,'units','normalized','position',...
            [0.55 0.1 0.2 0.3],'string',noStr,'Backgroundcolor','white','callback',@no_button_callback);

            function no_button_callback(~,~)
                response = 0;
                uiresume(gcf);
            end

        uiwait(gcf);

        if ishandle(fg)
            close(fg);   
        end
    end

end
