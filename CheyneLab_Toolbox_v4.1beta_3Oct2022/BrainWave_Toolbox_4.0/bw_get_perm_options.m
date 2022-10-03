function [result perm_options] = bw_get_perm_options(numSubjects, allowROI)
%
% get permutation test options as separate dialog
%
%
scrnsizes=get(0,'MonitorPosition');

% Initialize Variables

if ~exist('allowROI','var')
    allowROI = true;
end

result = 0;

perm_options = [];
max_perm_cutoff=2048;       % for large number of Ss stop here...

xmin = -75;
xmax = 75;
ymin = -112;
ymax = 75;
zmin = -50;
zmax = 85;
default_roi = [xmin xmax ymin ymax zmin zmax];

perm_options.num_permutations = 2^numSubjects;
if perm_options.num_permutations  > max_perm_cutoff
    perm_options.num_permutations = max_perm_cutoff;
end

% default options - need to add to defaults file...
perm_options.corrected = 1;
perm_options.alpha = 0.05;
perm_options.showNeg = true;

perm_options.roi = default_roi;
perm_options.useROI = false;

perm_options.showDist = false;

default_options = perm_options;

f=figure('Name', 'BrainWave - Permutation Options', 'Position', [scrnsizes(1,4)/6 scrnsizes(1,4)/2  800 350],...
            'menubar','none','numbertitle','off', 'Color','white');

okButton=uicontrol('style','pushbutton','units','normalized','position',...
    [0.05 0.1 0.14 0.12],'string','Run','background','white',...
    'foregroundcolor','blue','fontsize',10,'callback',@ok_button_callback);

cancelButton=uicontrol('style','pushbutton','units','normalized','position',...
    [0.3 0.1 0.14 0.12],'string','Cancel','background','white',...
    'foregroundcolor','black','fontsize',10,'callback',@cancel_button_callback);

% plot Distr
plot_dist_check=uicontrol('style','checkbox','units','normalized','position',...
    [0.55 0.12 0.25 0.06],'string','Plot Distribution','value',perm_options.showDist,...
    'background','white','callback',@plotDist_callback);

    function plotDist_callback(src,evt)
        perm_options.showDist = get(src,'value');
    end

% Controls

alpha_text=uicontrol('style','text','units','normalized','position',...
    [0.08 0.7 0.1 0.08],'horizontalAlignment','left','string','Alpha:','background','white');

alpha_number=uicontrol('style','edit','units','normalized','position',...
    [0.12 0.7 0.08 0.12],'string',perm_options.alpha,'fontsize',12,'backgroundcolor',...
    'white','callback',@alpha_number_callback);

max_perm_text=uicontrol('style','text','units','normalized','position',...
    [0.24 0.7 0.15 0.08],'string','No. of Permutations:','background','white');
max_perm_number=uicontrol('style','edit','units','normalized','position',...
    [0.38 0.7 0.08 0.12],'string',perm_options.num_permutations,'fontsize',12,'backgroundcolor',...
    'white','callback',@max_perm_number_callback);

options_title=uicontrol('style','text','units','normalized','position',...
    [0.1 0.9 0.1 0.05],'string','Options','background','white','fontsize',12,...
    'foregroundcolor','blue','fontweight','bold');

% put radio for omnibus

% corrected radio
corrected_radio=uicontrol('style','radio','units','normalized','position',...
    [0.08 0.55 0.25 0.08],'string','Corrected (omnibus):','value',perm_options.corrected,...
    'background','white','callback',@corrected_radio_callback);

% corrected radio
uncorrected_radio=uicontrol('style','radio','units','normalized','position',...
    [0.28 0.55 0.25 0.08],'string','Uncorrected (voxelwise):','value',~perm_options.corrected,...
    'background','white','callback',@uncorrected_radio_callback);

    function corrected_radio_callback(src,evt)
        perm_options.corrected = 1;
        set(src,'value',1);
        set(uncorrected_radio,'value',0);
        set(plot_dist_check, 'enable','on');
    end
    function uncorrected_radio_callback(src,evt)
        perm_options.corrected = 0;
        set(src,'value',1);
        set(corrected_radio,'value',0);
        set(plot_dist_check, 'enable','off');
    end

% not implemented yet
% set(uncorrected_radio,'enable','off');

% plot Neg values by default 
% but have option to show only positive (i.e., in direction of contrast) 
% - not sure if option is still needed 
plotPos_check=uicontrol('style','checkbox','units','normalized','position',...
    [0.55 0.725 0.25 0.06],'string','Exclude Negative Voxels','value',~perm_options.showNeg,...
    'background','white','callback',@plotPos_callback);

    function plotPos_callback(src,evt)
        perm_options.showNeg = ~get(src,'value');
    end


if allowROI

    % ROI
    use_ROI_check=uicontrol('style','checkbox','units','normalized','position',...
        [0.08 0.37 0.25 0.08],'string','Use ROI (mm):','value',perm_options.useROI,...
        'background','white','callback',@useROI_callback);

    % X
    ROI_XMIN_TXT = uicontrol('style','text','units','normalized','position',...
        [0.22 0.35 0.06 0.08],'string','Xmin','background','white');
    ROI_XMIN=uicontrol('style','edit','units','normalized','position',...
        [0.27 0.35 0.06 0.12],'string',xmin,'fontsize',12,'backgroundcolor',...
        'white','enable', 'off','callback',@xmin_callback);

    ROI_XMAX_TXT = uicontrol('style','text','units','normalized','position',...
        [0.34 0.35 0.06 0.08],'string','Xmax','background','white');
    ROI_XMAX=uicontrol('style','edit','units','normalized','position',...
        [0.39 0.35 0.06 0.12],'string',xmax,'fontsize',12,'backgroundcolor',...
        'white','enable', 'off','callback',@xmax_callback);

    % Y
    ROI_YMIN_TXT = uicontrol('style','text','units','normalized','position',...
        [0.47 0.35 0.06 0.08],'string','Ymin','background','white');
    ROI_YMIN=uicontrol('style','edit','units','normalized','position',...
        [0.52 0.35 0.06 0.12],'string',ymin,'fontsize',12,'backgroundcolor',...
        'white','enable', 'off','callback',@ymin_callback);

    ROI_YMAX_TXT = uicontrol('style','text','units','normalized','position',...
        [0.58 0.35 0.06 0.08],'string','Ymax','background','white');
    ROI_YMAX=uicontrol('style','edit','units','normalized','position',...
        [0.63 0.35 0.06 0.12],'string',ymax,'fontsize',12,'backgroundcolor',...
        'white','enable', 'off','callback',@ymax_callback);

    % Z
    ROI_ZMIN_TXT = uicontrol('style','text','units','normalized','position',...
        [0.7 0.35 0.06 0.08],'string','Zmin','background','white');
    ROI_ZMIN=uicontrol('style','edit','units','normalized','position',...
        [0.75 0.35 0.06 0.12],'string',zmin,'fontsize',12,'backgroundcolor',...
        'white','enable', 'off','callback',@zmin_callback);

    ROI_ZMAX_TXT = uicontrol('style','text','units','normalized','position',...
        [0.81 0.35 0.06 0.08],'string','Zmax','background','white');
    ROI_ZMAX=uicontrol('style','edit','units','normalized','position',...
        [0.86 0.35 0.06 0.12],'string',zmax,'fontsize',12,'backgroundcolor',...
        'white','enable', 'off','callback',@zmax_callback);
end


% Boxes

options_box=annotation('rectangle',[0.05 0.28 0.9 0.65],'EdgeColor','blue');

    function useROI_callback(src,evt)
        perm_options.useROI = get(src,'value');
        if perm_options.useROI
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

    function alpha_number_callback(src,evt)      
        
        t=str2num(get(src,'string'));
        min_perm = 1/perm_options.num_permutations;
        if t < min_perm
            fprintf('Insufficient # of permutations, setting to minimum alpha level for %d permutations...\n', perm_options.num_permutations );
            perm_options.alpha = min_perm;
            set(alpha_number,'string',perm_options.alpha);
            return;
        end
        
        perm_options.alpha = t;
    end

    function max_perm_number_callback(src,evt)
        
        perm_options.num_permutations = str2num(get(src,'string'));
        
        if perm_options.num_permutations > 2^numSubjects
            perm_options.num_permutations=2^numSubjects;
            set(max_perm_number,'string',perm_options.num_permutations);
            fprintf('not enough subjects for this many permutations...resetting to max\n');
        end
    end

    function ok_button_callback(src,evt)
        
        % gather params ...     
        perm_options.roi = [xmin xmax ymin ymax zmin zmax];
        result = 1;
        uiresume(gcbf);
    end

    function cancel_button_callback(src,evt)
        
        result = 0;
        perm_options = default_options;
        uiresume(gcbf);
    end
    
 uiwait(gcf);
 
    if ishandle(f)
        close(f);  
    end

end