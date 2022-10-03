function params = bw_set_image_options(dsName, input_params)
%       BW_SET_IMAGE_OPTIONS
%
%   function params.beamformer_params = bw_set_image_options(bf,param)
%
%   DESCRIPTION: Creates a GUI that allows the user to set a series of
%   parameters related to creating beamformer images.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%
%   --VERSION 1.1--
% Last Revised by N.v.L. on 13/07/2010
% Major Changes: Uicontrols were shifted around and new options of
% makeBeamformer added such as voxgrid, nofix, output, mean, etc. 
%
% Revised by N.v.L. on 23/06/2010
% Major Changes: Changed the help file.
%
% Written by N.v.L. on 03/06/2010 for the Hospital for Sick Children.

%% FIGURE

global BW_PATH;

stepSizeNames={'10 mm';'8 mm';'5 mm';'4 mm';'3 mm';'2.5 mm';'2 mm'};
stepSizeVals=[1.0 0.8 0.5 0.4 0.3 0.25 0.2];

outputFormatNames={'Plain Text file (.txt)';'Freesurfer Overlay (.w)'};

% get paths to this subject's MRI directory

[ds_path, ds_name, subject_ID, mriDir, mri_filename] = bw_parse_ds_filename(dsName);        

scrnsizes=get(0,'MonitorPosition');

f=figure('Name', 'Image Options', 'Position', [scrnsizes(1,3)/3 scrnsizes(1,4)/2 800 600],...
            'menubar','none','numbertitle','off', 'Color','white');
if ispc
    movegui(f,'center');
end
params = input_params;        
        
        
%SAVES THE BEAMFORMERparameters
uicontrol('style','pushbutton','units','normalized','Position',[0.7 0.05 0.15 0.08],'String','Save',...
              'FontSize',13,'FontWeight','b',...
              'ForegroundColor','black','Callback','uiresume(gcbf)','callback',@save_callBack);
 
    function save_callBack(~,~)
        
       if params.spm_options.useDefaultTemplate == 0           
            % warn if switching from default
            response = bw_warning_dialog('  WARNING. You have specified a custom template MRI for spatial normalization. *** TALAIRACH COORDINATES MAY BE INVALID! *** Proceed?');
            if response == 0
                return;
            end
            params.spm_options.templateFile = get(CUSTOM_TEMPLATE_EDIT,'string');
            params.spm_options.maskFile = get(CUSTOM_MASK_EDIT,'string');
            
        end
        
        uiresume(gcbf);
    end
          
uicontrol('style','pushbutton','units','normalized','Position',[0.5 0.05 0.15 0.08],'String','Cancel',...
              'FontSize',13,'ForegroundColor','black','callback',@cancel_callBack);
              
    function cancel_callBack(~,~)
        params = input_params; % undo changes
        uiresume(gcbf);
    end

uicontrol('style','pushbutton','units','normalized','position',[0.1 0.05 0.18 0.08],'string','Set to Default',...
    'fontsize',11,'foregroundcolor','blue','callback',@default_callback);

    function default_callback(~,~)
        t_params =  bw_setDefaultParameters;
        def_params = t_params.beamformer_parameters;
        params.beamformer_parameters.stepSize = def_params.stepSize;
        menu_val = find(stepSizeVals==params.beamformer_parameters.stepSize);
        set(STEPSIZE_POPUP,'val',menu_val);

        params.beamformer_parameters.nr=  def_params.nr;
        set(RECTIFY_CHECK,'value',params.beamformer_parameters.nr)

        params.beamformer_parameters.useBrainMask = 0;
        set(FSL_MASK_EDIT,'enable','off');
        set(FLS_MASK_BUTTON,'enable','off');
        
        params.beamformer_parameters.boundingBox=def_params.boundingBox;
        set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
        set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
        set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
        set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
        set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
        set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))

        params.spm_options.useDefaultTemplate = 1;
        set(DEFAULT_RADIO,'value',1)
        set(CUSTOM_RADIO,'value',0)
        
        params.beamformer_parameters.noise = def_params.noise;
        set(NOISE_EDIT,'string',params.beamformer_parameters.noise * 1e15);        

    end

% INITIALIZE VARIABLES

uicontrol('style','text','units','normalized','position',[0.46 0.56 0.22 0.06],...
    'string','SPM Normalization','Fontsize',12,'Backgroundcolor','white','FontWeight','b','foregroundcolor','blue');
annotation('rectangle','position',[0.44 0.2 0.5 0.4],'edgecolor','blue');

DEFAULT_RADIO=uicontrol('style','radiobutton','units','normalized','fontsize',12,'position',[0.45 0.5 0.45 0.06],...
    'string',' Use Default SPM Template (ICBM152)','backgroundcolor','white',...
    'value',params.spm_options.useDefaultTemplate,'callback',@DEFAULT_CALLBACK);
CUSTOM_RADIO=uicontrol('style','radiobutton','units','normalized','fontsize',12,'position',[0.45 0.43 0.42 0.06],...
    'string',' Use Custom Template','backgroundcolor','white',...
    'value',~params.spm_options.useDefaultTemplate,'callback',@CUSTOM_CALLBACK);

uicontrol('style','text','units','normalized','position',[0.45 0.35 0.2 0.06],'horizontalalignment','left',...
    'string','Template File:','fontsize',12,'backgroundcolor','white');

CUSTOM_TEMPLATE_EDIT=uicontrol('style','edit','units','normalized','fontsize',11,'position',[0.45 0.32 0.38 0.06],...
    'string',params.spm_options.templateFile,'backgroundcolor','white','horizontalalignment','left');

uicontrol('style','text','units','normalized','position',[0.45 0.25 0.3 0.06],'horizontalalignment','left',...
    'string','Mask File (Optional):','fontsize',12,'backgroundcolor','white');

CUSTOM_MASK_EDIT=uicontrol('style','edit','units','normalized','fontsize',11,'position',[0.45 0.22 0.38 0.06],...
    'string',params.spm_options.maskFile,'backgroundcolor','white','horizontalalignment','left');

TEMPLATE_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',10,'position',[0.85 0.32 0.08 0.06],...
    'string','Select','foregroundcolor','blue','callback',@TEMPLATE_BUTTON_CALLBACK);

MASK_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',10,'position',[0.85 0.22 0.08 0.06],...
    'string','Select','foregroundcolor','blue','callback',@MASK_BUTTON_CALLBACK);

if params.spm_options.useDefaultTemplate
     set(CUSTOM_TEMPLATE_EDIT,'enable','off');
     set(CUSTOM_MASK_EDIT,'enable','off');
else
     set(CUSTOM_TEMPLATE_EDIT,'enable','on');
     set(CUSTOM_MASK_EDIT,'enable','on');     
end
function DEFAULT_CALLBACK(src,~)
     params.spm_options.useDefaultTemplate = 1;
     set(src,'value',1);
     set(CUSTOM_RADIO,'value',0);
     set(CUSTOM_TEMPLATE_EDIT,'enable','off');
     set(CUSTOM_MASK_EDIT,'enable','off');
end

function CUSTOM_CALLBACK(src,~)
     params.spm_options.useDefaultTemplate = 0;
     set(src,'value',1);
     set(DEFAULT_RADIO,'value',0);
     set(CUSTOM_TEMPLATE_EDIT,'enable','on');
     set(CUSTOM_MASK_EDIT,'enable','on');
end

function TEMPLATE_BUTTON_CALLBACK(~,~)
     defPath = strcat(BW_PATH,'template_MRI');
     [name,~,~] = uigetfile('*.nii','Select MRI Template',defPath);
     if isequal(name,0)
        return;
     end
     params.spm_options.templateFile = name;
     set(CUSTOM_TEMPLATE_EDIT,'String',params.spm_options.templateFile);
end

function MASK_BUTTON_CALLBACK(~,~)
     defPath = strcat(BW_PATH,'template_MRI');
     [name,~,~] = uigetfile('*.nii','Select Mask file for Template',defPath);
     if isequal(name,0)
        return;
     end
     params.spm_options.maskFile = name;
     set(CUSTOM_MASK_EDIT,'String',params.spm_options.maskFile);
end


    % BOUNDING BOX
uicontrol('style','text','units','normalized','position',[0.05 0.905 0.18 0.06],...
    'string','Image Volume','fontweight','b','fontsize',12,'backgroundcolor','white','foregroundcolor','blue');
annotation('rectangle',[0.01 0.2 0.4 0.75],'edgecolor','blue');

% X
uicontrol('style','text','units','normalized','position',[0.07 0.845 0.12 0.06],...
    'string','X Min (cm):','fontsize',12,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.785 0.12 0.06],...
    'string','X Max (cm):','fontsize',12, 'backgroundcolor','white');

BB_X_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.86 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(1),'fontsize',12,'backgroundcolor','white','callback',@bb_x_min_edit_callback);

    function bb_x_min_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))
        else
            params.beamformer_parameters.boundingBox(1)=str2double(string_value);
        end
    end

BB_X_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.8 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(2),'fontsize',12,'backgroundcolor','white','callback',@bb_x_max_edit_callback);
    function bb_x_max_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))
        else
            params.beamformer_parameters.boundingBox(2)=str2double(string_value);
        end
    end

% Y
uicontrol('style','text','units','normalized','position',[0.07 0.715 0.12 0.06],...
    'string','Y Min (cm):','fontsize',12,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.655 0.12 0.06],...
    'string','Y Max (cm):','fontsize',12, 'backgroundcolor','white');
BB_Y_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.73 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(3),'fontsize',12,'backgroundcolor','white','callback',@bb_y_min_edit_callback);
    function bb_y_min_edit_callback(src,~)
     string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))                
        else
            params.beamformer_parameters.boundingBox(3)=str2double(string_value);
        end
    end
BB_Y_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.67 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(4),'fontsize',12,'backgroundcolor','white','callback',@bb_y_max_edit_callback);
    function bb_y_max_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))    
        else
            params.beamformer_parameters.boundingBox(4)=str2double(string_value);
        end
    end
% Z
uicontrol('style','text','units','normalized','position',[0.07 0.585 0.12 0.06],...
    'string','Z Min (cm):','fontsize',12,'backgroundcolor','white');
uicontrol('style','text','units','normalized','position',[0.07 0.525 0.12 0.06],...
    'string','Z Max (cm):','fontsize',12, 'backgroundcolor','white');
BB_Z_MIN_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.6 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(5),'fontsize',12,'backgroundcolor','white','callback',@bb_z_min_edit_callback);
    function bb_z_min_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))    
              
        else
            params.beamformer_parameters.boundingBox(5)=str2double(string_value);
        end
    end
BB_Z_MAX_EDIT=uicontrol('style','edit','units','normalized','position',[0.22 0.54 0.1 0.06],...
    'string',params.beamformer_parameters.boundingBox(6),'fontsize',12,'backgroundcolor','white','callback',@bb_z_max_edit_callback);
    function bb_z_max_edit_callback(src,~)
        string_value=get(src,'string');
        if isempty(string_value)
            params.beamformer_parameters.boundingBox=[-10 10 -8 8 0 14];
            set(BB_X_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(1))
            set(BB_X_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(2))
            set(BB_Y_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(3))
            set(BB_Y_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(4))
            set(BB_Z_MIN_EDIT,'string',params.beamformer_parameters.boundingBox(5))
            set(BB_Z_MAX_EDIT,'string',params.beamformer_parameters.boundingBox(6))    
        else
            params.beamformer_parameters.boundingBox(6)=str2double(string_value);
        end
    end


init_val = find(stepSizeVals==params.beamformer_parameters.stepSize);
        
uicontrol('style','text','units','normalized','position',[0.08 0.425 0.15 0.06],...
     'string','Step Size:','fontweight','b','fontsize',12,'backgroundcolor','white','foregroundcolor','blue','horizontalAlignment','left');

 STEPSIZE_POPUP = uicontrol('style','popup','units','normalized',...
    'position',[0.2 0.39 0.15 0.1],'String',stepSizeNames,'Backgroundcolor','white','fontsize',12,...
    'value',init_val,'callback',@stepsize_popup_callback);

        function stepsize_popup_callback(src,~)
            menu_select=get(src,'value');
            params.beamformer_parameters.stepSize = stepSizeVals(menu_select);           
        end

%
uicontrol('style','text','units','normalized','position',[0.05 0.25 0.3 0.06],'horizontalalignment','left',...
    'string','Mask File:','fontsize',11,'backgroundcolor','white');

FSL_MASK_EDIT=uicontrol('style','edit','units','normalized','fontsize',12,'position',[0.05 0.22 0.3 0.06],...
    'string',params.beamformer_parameters.brainMaskFile,'enable','off','backgroundcolor','white','horizontalalignment','left');

uicontrol('style','check', 'units', 'normalized','position',[0.05 0.34 0.2 0.06],...
        'String','Apply Brain Mask', 'BackGroundColor','white','fontsize',11,'Value', params.beamformer_parameters.useBrainMask,'callback',@useMask_check_callback);

FLS_MASK_BUTTON=uicontrol('style','pushbutton','units','normalized','fontsize',10,'position',[0.25 0.34 0.1 0.06],...
    'string','Select','foregroundcolor','blue','enable','off','callback',@FSL_MASK_BUTTON_CALLBACK);

if params.beamformer_parameters.useBrainMask
    set(FSL_MASK_EDIT,'enable','on');
    set(FLS_MASK_BUTTON,'enable','on');
end      

function useMask_check_callback(src,~)
   params.beamformer_parameters.useBrainMask=get(src,'Value');

   if params.beamformer_parameters.useBrainMask
        set(FSL_MASK_EDIT,'enable','on');
        set(FLS_MASK_BUTTON,'enable','on');
   else
        set(FSL_MASK_EDIT,'enable','off');
        set(FLS_MASK_BUTTON,'enable','off');
   end 

end

function FSL_MASK_BUTTON_CALLBACK(~,~)
    
     [ds_path, ds_name, subject_ID, mriDir, mri_filename] = bw_parse_ds_filename(dsName);
     defPath = strcat(mriDir,filesep,'*.nii');
     
     [name,~,~] = uigetfile({'bet_inskull_mask.nii';'*.nii'},'Select FSL Binary Mask',defPath);
     if isequal(name,0)
        return;
     end
     params.beamformer_parameters.brainMaskFile = name;
     set(FSL_MASK_EDIT,'String',params.beamformer_parameters.brainMaskFile);
end
    
uicontrol('style','text','units','normalized','position',[0.46 0.905 0.2 0.06],...
    'string','Image Options','fontweight','b','fontsize',12,'backgroundcolor','white','foregroundcolor','blue');
annotation('rectangle',[0.44 0.65 0.5 0.3],'edgecolor','blue');


uicontrol('style','check', 'units', 'normalized','position',[0.46 0.86 0.3 0.05],...
        'String','Use normal constraint for surfaces', 'BackGroundColor','white','FontSize', 12,'Value', params.beamformer_parameters.useVoxNormals,'callback',@useNormal_check_callback);
    function useNormal_check_callback(src,~)
       params.beamformer_parameters.useVoxNormals=get(src,'Value');
       
       % do not allow non-rectified ERB images unless constraining
       % orientation across subjects..
       if params.beamformer_parameters.useVoxNormals
            set(RECTIFY_CHECK,'enable','on');
       else
            set(RECTIFY_CHECK,'enable','off');
            params.beamformer_parameters.nr =0;
            set(RECTIFY_CHECK,'value',0);
       end 
       
    end

% RECTIFY_ERB
RECTIFY_CHECK=uicontrol('style','check', 'units', 'normalized','position',[0.46 0.8 0.3 0.05],...
        'String','Compute non-rectified ERB images', 'BackGroundColor','white','FontSize', 12,'Value', params.beamformer_parameters.nr,'callback',@rectify_check_callback);
    function rectify_check_callback(src,~)
       params.beamformer_parameters.nr=get(src,'Value');
    end

if params.beamformer_parameters.useSurfaceNormals
    set(RECTIFY_CHECK,'enable','on');
else
    params.beamformer_parameters.nr = 0;
    set(RECTIFY_CHECK,'enable','off');
end    
    
% moved from Data Parameters menu
% only one normalization method currently - could add here variance normalization etc...
NOISE_Z_RADIO=uicontrol('style','radiobutton','units','normalized','position',[0.46 0.73 0.2 0.06],...
    'value',1,'string','Pseudo-Z Normalization','fontsize',12,'backgroundcolor','white','callback',@noise_z_radio_callback);
    function noise_z_radio_callback(~,~)
        set(NOISE_Z_RADIO,'value',1);
    end

noisefT = params.beamformer_parameters.noise*1e15;

uicontrol('style','text','units','normalized','HorizontalAlignment','Left','position',[0.7 0.715 0.1 0.06],...
        'String','RMS:','FontSize',12,'BackGroundColor','white','foregroundcolor','black');
uicontrol('style','text','units','normalized','HorizontalAlignment','left','position',[0.82 0.715 0.1 0.06],...
        'String','fT / sqrt(Hz)','FontSize',12,'BackGroundColor','white','foregroundcolor','black');
NOISE_EDIT=uicontrol('style','edit','units','normalized','position', [0.75 0.73 0.05 0.06],...
        'String',noisefT , 'FontSize', 12, 'BackGroundColor','white','callback',@noise_edit_callback);
    function noise_edit_callback(src,~)
        s=get(src,'String');
        if isempty(s)
            params.beamformer_parameters.noise=3.0e-15;
            set(NOISE_EDIT,'string',3.0)
        else
            params.beamformer_parameters.noise=str2double(s)*1e-15;   % convert from fT to Tesla
        end
    end



%% RESUMING MATLAB
 uiwait(gcf);
%% CLOSING FIGURE
  if ishandle(f)
    close(f);  
  end     
end