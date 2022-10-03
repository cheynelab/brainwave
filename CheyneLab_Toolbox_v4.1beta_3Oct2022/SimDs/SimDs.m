%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SimDs.m
% main function for GUI version of simDs
% 
%   (c) D. Cheyne, 2020. All rights reserved. 
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%  Last update May7, 2020
%  v 1.4 update September, 2020.
%
%  ** added to CheyneLab_Toolbox Dec 19, 2021 - deleted or replaced unused
%  variables with ~
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function SimDs


scrnsizes=get(0,'MonitorPosition');

VERSION = 1.4;

s = sprintf('MEG Data Simulator (version %g)', VERSION);

if ismac
    width = 1200;
    height = 800;
elseif isunix
    width = 1400;
    height = 800;
elseif ispc
    width = 1400;
    height = 800;
end
    
sx = round(scrnsizes(3) * 0.1);
sy = round(scrnsizes(4) * 0.9) - height;

left2 = sx + width;
top = sy + height;

f=figure('Name', s, 'Position', [sx sy width height],...
    'menubar','none','numbertitle','off', 'Color','white');

if ispc == 1
    movegui(f,[sx 100]);
end

geomIndex = 1;
geom_types = {'Generic CTF 151','Generic CTF 275','Load Geom File...','Load CTF Dataset...'};
gradient_types = {'None','1st order','2nd order','3rd order','3rd order + adaptive'};

% use local copy of topoplot directory for now ... put in common external folder?
topopath=which('SimDs');
idx = find(topopath == filesep);
topopath=strcat(topopath(1:idx(end)),'topoplot');
addpath(topopath);

%% globals
orange = [0.6,0.25,0.1];

SIM_VERSION ='SIM_FILE_VER_2';

%general
loadfull='';

dataType = '';

%channel select button
validChan=[];
bcpos=[];

%%%%%%%%%%%%%%%%%%%%%%%%%
loadfull = ' ';

gotData = 0;
dsName = ' ';
gotGeomFile = 0;
geomFileName = ' ';
gotSim = 0;
simFileName = ' ';
gotFile = 0;
newDsName = ' ';

AddBrainnoise = 0;
hasOrigin = 1;
sphereOrigin_x = 0;
sphereOrigin_y = 0;
sphereOrigin_z = 5;
AddNoise = 0;
peakNoise = 0;
highPassFreq = 0;

SampleRate = 600;
lowPassFreq = SampleRate/2;

rotateDipoles = 0;
GradientOrder = 0;
totalReferences = 0;
totalChannels = 0;

gotTrials = 1;
TrialNumber = 100;
gotSamples = 1;
NumberSamples = 600;
gotSampleRate = 1;
EpochDuration = NumberSamples/SampleRate;
PreTrigPoints = 0;

UseSingleSphere = 1;
headModelFile = ' ';
dipoleType = 1;     % 1 = current, 2 = magnetic
    
dumpForward = 0;
dumpFileName = ' ';
verbose = 0;
previewHdl = 0;

forceOverwrite = 1;
writeADC = 1;

Continue = 1;

num_sources = 0;

cursorHandle = 0;
latency = 0.0;
latency_text = '';

mapFig = 0;

plot_data = [];
mapLocs = [];

leftarrow_im=draw_leftarrow;
rightarrow_im=draw_rightarrow;

% added ctf_header global
ctf_header.sampleRate=0;
ctf_header.numSamples=0;
ctf_header.numSensors=0;
geom_info = [];

dipole_params = struct('xpos',{},'ypos',{},'zpos',{},'xori',{},...
                'yori',{},'zori',{},'moment',{});
sim_params = struct('frequency',{},'onsetTime',{},'duration',{},'onsetJitter',{},...
                'amplitudeJitter',{},'sourceType',{},'sourceFile',{});
              
tpath=which('SimDs');
SIMDS_PATH=tpath(1:end-7);       
            
%% Menu
filemenu=uimenu('label','File');
%uimenu(filemenu,'label','Open File','accelerator','O','callback',@load_filemenu_callback)
uimenu(filemenu,'label','Quit','accelerator','Q','callback',@quit_filemenu_callback)
    function quit_filemenu_callback(~,~)
        
        answer = questdlg('Quit SimDs?','SimDs', 'Yes','No','No');
        if strcmp(answer,'No')
            return;
        end
        
        if previewHdl ~= 0 && ishandle(previewHdl)
            close(previewHdl);
        end 
        
        if mapFig ~= 0 && ishandle(mapFig)
            close(mapFig);
        end 
        
        close(f);
        
    end
%% Printed Info
uicontrol('style','text','units','normalized','position',[0.03 0.92 0.14 0.04],...
    'String','Sensor Geometry','ForegroundColor','blue','FontSize', 12,...
    'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');

datafile_name=uicontrol('style','text','units','normalized','position',[0.19 0.85 0.37 0.08],...
    'FontSize', 9,'String','File:','HorizontalAlignment','left',...
    'BackgroundColor','white');
data_type=uicontrol('style','text','units','normalized','position',[0.04 0.84 0.37 0.05],...
    'FontSize', 11,'String','DataType:','HorizontalAlignment','left',...
    'BackgroundColor','white');
total_channels=uicontrol('style','text','units','normalized','position',[0.04 0.81 0.37 0.05],...
    'FontSize', 11,'String','Number of Sensors:','HorizontalAlignment','left',...
    'BackgroundColor','white');
total_references=uicontrol('style','text','units','normalized','position',[0.04 0.78 0.37 0.05],...
    'FontSize', 11,'String','Number of References:','HorizontalAlignment','left',...
    'BackgroundColor','white');


annotation('rectangle','position',[0.01 0.72 0.58 0.23],'edgecolor','blue');

uicontrol('style','popup','units','normalized','position',[0.034 0.83 0.14 0.1],'fontSize',11,...
    'string',geom_types,'value',geomIndex,'backgroundcolor','white','callback',@geomMenu_callback);

    function geomMenu_callback(src,~)   
        value = get(src,'value');   
        if value == 4
            path = uigetdir('.ds', 'Select CTF dataset ...');
            if isequal(path, 0)
                set(src,'value', geomIndex);
                return;
            else
                geomIndex = value;
                load_dataset(path);
            end      
        elseif value == 3
            path = uigetfile('.geom', 'Select Custom .geom file ...');
            if isequal(path, 0)
                set(src,'value', geomIndex);
                return;
            else
                geomIndex = value;
                load_geom(path);
            end
         else
             geomIndex = value;
            if geomIndex == 1
                path = sprintf('%sCTF_151.geom', SIMDS_PATH);
            elseif geomIndex == 2
                path = sprintf('%sCTF_275.geom', SIMDS_PATH);
            end           
            load_geom(path);
        end
    end

uicontrol('style','text','units','normalized','position',[0.04 0.74 0.15 0.02],...
        'string','Synthetic Noise Reduction:','fontsize',11,'BackgroundColor','white','horizontalalignment','left');

Gradient_Menu = uicontrol('style','popup','units','normalized','position',[0.18 0.72 0.145 0.04],'fontSize',11,...
    'string',gradient_types(1),'value',1,'backgroundcolor','white','callback',@gradientMenu_callback);
    
    function gradientMenu_callback(src,~)   
        GradientOrder = get(src,'value') - 1;
        
         if gotData && previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
         end
    end

createButton =  uicontrol('style','pushbutton','units','normalized','position',[0.1 0.02 0.1 0.04],...
    'enable','off','string','Create Dataset','Foregroundcolor',orange,'backgroundcolor','white','callback',@create_ds_callback);

preViewButton =  uicontrol('style','pushbutton','units','normalized','position',[0.3 0.02 0.12 0.04],...
    'enable','off','string','Preview/Update','Foregroundcolor',orange,'backgroundcolor','white','callback',@preview_ds_callback);

% load dataset ...
    function load_dataset(path)
        
        loadfull=path;
        dsName = loadfull;
        geomFileName = ' ';
        gotData = 1;
        gotGeomFile = 0;
        tstr = sprintf('File: %s',loadfull);
        set(datafile_name,'string',tstr);
        
        % get dataset info
        ctf_header = sim_CTFGetHeader(loadfull);  
        
        dataType='CTF';   
        set(data_type,'string','Data Type: CTF Dataset');
               
        totalChannels=ctf_header.numSensors;
        totalReferences=ctf_header.numReferences;
        GradientOrder = ctf_header.gradientOrder;
        
        validChan = ones(totalChannels,1);
        badChannels = [];
        bcpos = [];
        
        tstr = sprintf('Number of Sensors: %g',totalChannels);
        set(total_channels,'string',tstr);
        tstr = sprintf('Number of References: %g',totalReferences);
        set(total_references,'string',tstr);   
        
        if totalReferences > 0
            set(Gradient_Menu,'string',gradient_types);
        else
            set(Gradient_Menu,'string',gradient_types(1));
        end
        
        set(Gradient_Menu,'value',GradientOrder+1);
        
        SampleRate = ctf_header.sampleRate;
        NumberSamples = ctf_header.numSamples;
        TrialNumber = ctf_header.numTrials;
        EpochDuration = NumberSamples/SampleRate;
        PreTrigPoints = ctf_header.numPreTrig
        
        set(Sample_rate,'string',num2str(SampleRate));
        set(trial_number,'string',num2str(TrialNumber));
        set(Epoch_duration,'string',num2str(EpochDuration));
       
        % added Sept, 2021 - disable option to
        % change dataset params when using MEG data.
        set(trial_number,'enable','off');      
        set(Epoch_duration,'enable','off');         
        set(Sample_rate,'enable','off');       
        
        set(createButton,'enable','on');
        set(preViewButton,'enable','on');
        set(add_brainnoise_check,'enable','on');
        

    end

    function load_geom(datafile)

        loadfull = datafile;
        geomFileName = loadfull;
        dsName = ' ';
        gotGeomFile = 1;
        gotData = 0;
        
        tstr = sprintf('File:%s',datafile);
        set(datafile_name,'string',tstr);
        dataType='GEOM';
        set(data_type,'string','Data Type: GEOM File');
        geom_info=sim_read_geom(datafile);
        
        
        totalChannels = size(geom_info.channel,1);
        totalReferences = 0;
        tstr = sprintf('Number of Sensors: %g',totalChannels);
        set(total_channels,'string',tstr);
        tstr = sprintf('Number of References: %g',totalReferences);
        set(total_references,'string',tstr);
             
        if totalReferences > 0
            set(Gradient_Menu,'string',gradient_types);
        else
            set(Gradient_Menu,'string',gradient_types(1));        
        end
        
        GradientOrder = 0;
        set(Gradient_Menu,'value',1);
        
        validChan = ones(totalChannels,1);
        badChannels = [];
        bcpos = [];
        
        % set defaults
        AddBrainnoise = 0;
        SampleRate = 600;
        NumberSamples = 600;
        TrialNumber = 100;
        EpochDuration = NumberSamples/SampleRate;
        
        set(Sample_rate,'string',num2str(SampleRate));
        set(trial_number,'string',num2str(TrialNumber));
        set(Epoch_duration,'string',num2str(EpochDuration));
        
        % added Sept, 2021 - allow option to
        % change dataset params only when not using MEG data.
        set(trial_number,'enable','on');      
        set(Epoch_duration,'enable','on');         
        set(Sample_rate,'enable','on'); 
        
        set(createButton,'enable','on');
        set(preViewButton,'enable','on');
        set(add_brainnoise_check,'enable','off','value', 0);
    end


% Parameters
uicontrol('style','text','units','normalized','position',[0.62 0.92 0.18 0.04],...
    'String','Dataset Parameters','FontSize',11,'ForegroundColor','blue',...
    'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');

%surrounding rectangle
annotation('rectangle','position',[0.6 0.57 0.38 0.38],'edgecolor','blue');

uicontrol('style','text','units','normalized','position',[0.62 0.87 0.09 0.04],...
    'string','Trial number:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');

uicontrol('style','edit','units','normalized','position',[0.73 0.88 0.055 0.03],...
    'string',TrialNumber,'FontSize', 11, 'BackGroundColor','white','callback',@trial_number_callback);

    function trial_number_callback(src,~)
        TrialNumber = str2double(get(src,'String'));
        
        % update trial slider in Simulation Source plot
        if trial > TrialNumber
            trial = TrialNumber;
          
            plot_sources;
            if previewHdl ~= 0 && ishandle(previewHdl)             
                updatePreview;
            end            
            str = sprintf('Trial #%d', trial);
            set(trial_number,'string',str);

        end
        
        set(trial_slider, 'value', trial, 'max', TrialNumber);
        if TrialNumber == 1
            set(trial_slider, 'sliderstep', [0 0]);
        else
            set(trial_slider, 'sliderstep', [1 1]/(TrialNumber-1));
        end

    end

uicontrol('style','text','units','normalized','position',[0.62 0.83 0.14 0.04],...
    'string','Epoch duration (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
Epoch_duration=uicontrol('style','edit','units','normalized','position',[0.73 0.84 0.055 0.03],...
    'string',EpochDuration,'FontSize', 11, 'BackGroundColor','white','callback',@epoch_duration_callback);

    function epoch_duration_callback(src,~)
        EpochDuration = str2double(get(src,'String'));
        NumberSamples = EpochDuration*SampleRate;
        if previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
        end        
        plot_sources;
    end


uicontrol('style','text','units','normalized','position',[0.62 0.79 0.14 0.04],...
    'string','Sample rate:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
Sample_rate=uicontrol('style','edit','units','normalized','position',[0.73 0.80 0.055 0.03],...
    'string',SampleRate,'FontSize', 11, 'BackGroundColor','white','callback',@sample_rate_callback);

    function sample_rate_callback(src,~)
        SampleRate = str2double(get(src,'String'));
        NumberSamples = EpochDuration*SampleRate;
        
         if previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
         end
         plot_sources;
    end

uicontrol('style','text','units','normalized','position',[0.62 0.75 0.1 0.04],...
    'string','High-pass (Hz):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
uicontrol('style','edit','units','normalized','position',[0.73 0.76 0.055 0.03],...
    'string',0.0,'FontSize', 11, 'BackGroundColor','white','callback',@highpass_freq_callback);
    function highpass_freq_callback(src,~)
        highPassFreq = str2double(get(src,'String'));
      
        if previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
        end
    end
uicontrol('style','text','units','normalized','position',[0.62 0.71 0.1 0.04],...
    'string','Low-pass (Hz):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
uicontrol('style','edit','units','normalized','position',[0.73 0.72 0.055 0.03],...
    'string',SampleRate/2,'FontSize', 11, 'BackGroundColor','white','callback',@lowpass_freq_callback);
    function lowpass_freq_callback(src,~)
        lowPassFreq = str2double(get(src,'String'));
         if previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
         end
    end

uicontrol('style','checkbox','units','normalized','position',[0.62 0.63 0.2 0.04],...
    'string','Add Gaussian Noise: ','value', 0,'FontSize',11,'backgroundcolor','white','callback',@add_gaussiannoise_callback);
    function add_gaussiannoise_callback(src,~)
 
        AddNoise=get(src,'value');
        if AddNoise
            set(gaussian_pp,'enable','on');
        else
            set(gaussian_pp,'enable','off');
        end
        if previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
        end
    end

uicontrol('style','text','units','normalized','position',[0.81 0.625 0.14 0.04],...
    'string','fT peak-to-peak','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
gaussian_pp = uicontrol('style','edit','units','normalized','position',[0.75 0.635 0.045 0.03],...
    'string',0.0,'enable','off','FontSize', 11, 'BackGroundColor','white','callback',@gaussian_pp_callback);
    function gaussian_pp_callback(src,~)
        peakNoise = str2double(get(src,'String'));     
        if previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
        end
    end

add_brainnoise_check = uicontrol('style','checkbox','units','normalized','position',[0.62 0.58 0.2 0.04],...
    'string','Add MEG Data to Simulation','value', 0,'enable','off','FontSize',11,'horizontalalignment','left',...
    'backgroundcolor','white','callback',@add_brainnoise_callback);
    function add_brainnoise_callback(src,~)
        AddBrainnoise=get(src,'value');          
        if previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
        end
    end

% % options
% uicontrol('style','text','units','normalized','position',[0.45 0.32 0.06 0.04],...
%         'String','Options','FontSize',12,'ForegroundColor','blue',...
%         'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');
% 


% plot window

%surrounding rectangle
annotation('rectangle','position',[0.6 0.09 0.38 0.45],'edgecolor','blue');
uicontrol('style','text','units','normalized','position',[0.62 0.515 0.16 0.04],...
    'String','Source Activity','FontSize',11,'ForegroundColor','blue',...
    'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');

% source plot
source_plot = [0.65 0.18 0.28 0.3];
subplot('Position', source_plot);
xlabel('Time');
ylabel('Normalized Amplitude');

trial = 1;

trial_number = uicontrol('style', 'text', 'units','normalized','position',[0.65 0.115 0.1 0.02],...
    'BackGroundColor','white','HorizontalAlignment','left','FontSize',11,'string', 'Trial 1');

trial_slider = uicontrol('style', 'slider', 'units','normalized','position',[0.7 0.11 0.23 0.02],...
    'BackGroundColor','white', 'value', 1,'sliderstep', [1 1]/(TrialNumber-1),...
    'min', 1, 'max', TrialNumber, 'callback', @trial_slider_callback);

  function trial_slider_callback(src, ~)
      trial = round(get(src, 'Value'));
      
      % update plot
      plot_sources;
      pause(0.1);
      
      % update plot title
      str = sprintf('Trial #%d', trial);
      set(trial_number,'string',str);

  end
% 

uicontrol('style','text','units','normalized','position',[0.03 0.66 0.2 0.04],...
    'String','Simulation Parameters','FontSize',11,'ForegroundColor','blue',...
    'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');

HDM_RADIO=uicontrol('style','radio','units','normalized','position',[0.02 0.62 0.22 0.04],...
    'string','Use Head Model File (*.hdm):','fontsize',11,'value',~UseSingleSphere,'backgroundcolor','white','callback',@hdm_radio_callback);

    function hdm_radio_callback (~,~)
        UseSingleSphere = 0;
        set(HDM_EDIT,'enable','on');
        set(HDM_PUSH,'enable','on');
        set(HDM_RADIO,'value',1);
        set(SPHERE_RADIO,'value',0);
        set(SPHERE_EDIT_X,'enable','off');
        set(SPHERE_EDIT_Y,'enable','off');
        set(SPHERE_EDIT_Z,'enable','off');
        set(SPHERE_TITLE_X,'enable','off');
        set(SPHERE_TITLE_Y,'enable','off');
        set(SPHERE_TITLE_Z,'enable','off');
    end

HDM_EDIT = uicontrol('style','edit','units','normalized','position', [0.2 0.62 0.28 0.035],...
    'String', headModelFile, 'enable','off','FontSize', 10, 'BackGroundColor','white','callback',@hdm_edit_callback);

    function hdm_edit_callback(src,~)
        headModelFile=get(src,'String');
        if isempty(headModelFile)
            headModelFile=' ';
        end
    end

HDM_PUSH=uicontrol('style','pushbutton','units','normalized','position',[0.51 0.62 0.06 0.035],...
    'String','Browse','FontSize',11,'enable','off','BackgroundColor','white','callback',@HDM_PUSH_CALLBACK);

    function HDM_PUSH_CALLBACK(~,~)
        
        s = fullfile(char(loadfull),'*.hdm');
        [hdmfilename,hdmpathname,~] = uigetfile('*.hdm','Select a Head Model (.hdm) file', s);
        if isequal(hdmfilename,0) || isequal(hdmpathname,0)
            return;
        else
            headModelFile=fullfile(hdmpathname,hdmfilename);
            %  this was causing problems... params.hdmFile= [hdmpathname,hdmfilename];
            %set(HDM_EDIT,'string',params.hdmFile)
            set(HDM_EDIT,'string',headModelFile);
            if isempty(headModelFile)
                headModelFile=' ';
            end
        end
    end


SPHERE_RADIO=uicontrol('style','radio','units','normalized','position',[0.02 0.56 0.22 0.04],...
    'string','Use Single Sphere (cm):','fontsize',11,'value',UseSingleSphere,'backgroundcolor','white','callback',@sphere_radio_callback);

    function sphere_radio_callback(~,~)
        UseSingleSphere = 1;
        set(HDM_RADIO,'value',0);
        set(SPHERE_RADIO,'value',1);
        set(HDM_EDIT,'enable','off');
        set(HDM_PUSH,'enable','off');
        set(SPHERE_EDIT_X,'enable','on');
        set(SPHERE_EDIT_Y,'enable','on');
        set(SPHERE_EDIT_Z,'enable','on');
        set(SPHERE_TITLE_X,'enable','on');
        set(SPHERE_TITLE_Y,'enable','on');
        set(SPHERE_TITLE_Z,'enable','on');
        
        set(SPHERE_EDIT_X,'string',sphereOrigin_x);
        set(SPHERE_EDIT_Y,'string',sphereOrigin_y);
        set(SPHERE_EDIT_Z,'string',sphereOrigin_z);
        %
    end

SPHERE_EDIT_X=uicontrol('style','edit','units','normalized','position', [0.23 0.565 0.05 0.03],...
    'String', sphereOrigin_x, 'FontSize', 11, 'BackGroundColor','white','callback',@sphere_edit_x_callback);
    function sphere_edit_x_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            sphereOrigin_x = 0;
            set(SPHERE_EDIT_X,'string',sphereOrigin_x);
            sphereOrigin_y = 0;
            set(SPHERE_EDIT_Y,'string',sphereOrigin_y);
            sphereOrigin_z = 5;
            set(SPHERE_EDIT_Z,'string',sphereOrigin_z);
        else
            sphereOrigin_x = str2double(string_value);
        end
    end
SPHERE_TITLE_X=uicontrol('style','text','units','normalized','position',[0.2 0.56 0.02 0.03],...
    'String','X:','FontSize',11,'BackGroundColor','white');

SPHERE_EDIT_Y=uicontrol('style','edit','units','normalized','position', [0.33 0.565 0.05 0.03],...
    'String', sphereOrigin_y, 'FontSize', 11, 'BackGroundColor','white','callback',@sphere_edit_y_callback);
    function sphere_edit_y_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            sphereOrigin_x = 0;
            set(SPHERE_EDIT_X,'string',sphereOrigin_x);
            sphereOrigin_y = 0;
            set(SPHERE_EDIT_Y,'string',sphereOrigin_y);
            sphereOrigin_z = 5;
            set(SPHERE_EDIT_Z,'string',sphereOrigin_z);
        else
            sphereOrigin_y = str2double(string_value);
        end
    end
SPHERE_TITLE_Y=uicontrol('style','text','units','normalized','position',[0.3 0.56 0.02 0.03],...
    'String','Y:','FontSize',11,'BackGroundColor','white');

SPHERE_EDIT_Z=uicontrol('style','edit','units','normalized','position', [0.44 0.565 0.05 0.03],...
    'String', sphereOrigin_z, 'FontSize', 11, 'BackGroundColor','white','callback',@sphere_edit_z_callback);
    function sphere_edit_z_callback(src,~)
        string_value=get(src,'String');
        if isempty(string_value)
            sphereOrigin_x = 0;
            set(SPHERE_EDIT_X,'string',sphereOrigin_x);
            sphereOrigin_y = 0;
            set(SPHERE_EDIT_Y,'string',sphereOrigin_y);
            sphereOrigin_z = 5;
            set(SPHERE_EDIT_Z,'string',sphereOrigin_z);
        else
            sphereOrigin_z = str2double(string_value);
        end
    end
SPHERE_TITLE_Z=uicontrol('style','text','units','normalized','position',[0.41 0.56 0.02 0.03],...
    'String','Z:','FontSize',11,'BackGroundColor','white');

uicontrol('style','pushbutton','units','normalized','position',[0.05 0.5 0.08 0.04],...
    'enable','on','string','Load Sim File','Foregroundcolor',orange,'backgroundcolor',...
    'white','callback',@load_simfile_callback);

uicontrol('style','pushbutton','units','normalized','position',[0.15 0.5 0.08 0.04],...
    'enable','on','string','Add Source','Foregroundcolor',orange,'backgroundcolor',...
    'white','callback',@add_source_callback);

uicontrol('style','pushbutton','units','normalized','position',[0.25 0.5 0.08 0.04],...
    'enable','on','string','Edit Source','Foregroundcolor',orange,'backgroundcolor',...
    'white','callback',@edit_source_callback);

uicontrol('style','pushbutton','units','normalized','position',[0.35 0.5 0.08 0.04],...
    'enable','on','string','Delete Source','Foregroundcolor',orange,'backgroundcolor',...
    'white','callback',@delete_source_callback);
uicontrol('style','pushbutton','units','normalized','position',[0.45 0.5 0.08 0.04],...
    'enable','on','string','Save sim file','Foregroundcolor',orange,'backgroundcolor',...
    'white','callback',@save_simfile_callback);
    


uicontrol('style','text','units','normalized','position',[0.04 0.2 0.14 0.04],...
        'string','Options:','fontsize',11,'fontweight','bold','backgroundcolor','white','horizontalalignment','left');

uicontrol('style','popup','units','normalized','position',[0.03 0.17 0.22 0.04],'fontSize',11,...
    'string',{'Project dipoles onto tangential direction','Rotate dipoles onto tangential direction'},...
    'backgroundcolor','white','value',rotateDipoles+1,'callback',@rotateMenu_callback);
    function rotateMenu_callback(src,~)
        rotateDipoles = get(src,'value')-1;
    end

uicontrol('style','popup','units','normalized','position',[0.03 0.13 0.18 0.04],'fontSize',11,...
    'string',{'Simulate Current Dipole','Simulate Magnetic Dipole'},...
    'backgroundcolor','white','callback',@forwardMenu_callback);
    function forwardMenu_callback(src,~)
        dipoleType = get(src,'value');
    end


uicontrol('style','checkbox','units','normalized','position',[0.031 0.1 0.24 0.04],...
    'string','Save source waveforms as ADC channels','value', writeADC,'FontSize',11,'backgroundcolor','white','callback',@writeADC_callback);
    function writeADC_callback(src,~)
        writeADC = get(src,'value');
    end

SimParams_box=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized','Position',...
    [0.03 0.25 0.54 0.24],'String',' ','HorizontalAlignment','Left',...
    'BackgroundColor','white');

%set(SimParams_box,'String',['var1';'var2';'var3'])

    function load_simfile_callback(~,~)
        params = {};
        
        [filename, path]=uigetfile({'*.sim','SIM file (*.sim)'},'Select a sim file');
        if isequal(filename,0)
            return;
        end
        sim_file_in = fullfile(path,filename);
        gotSim = 1;
        [num_sources, validFile] = sim_initSimFile(sim_file_in, SIM_VERSION);
        if (validFile==0) || (num_sources==0)
            return;
        end
        
        [dipole_params, sim_params] = sim_readSimFile(sim_file_in, 0);        
       
        [params] = read_sim_txt(num_sources,dipole_params, sim_params);
        
        set(SimParams_box,'Value',1);
        set(SimParams_box,'String',params);
                 
        plot_sources;
                
        if previewHdl ~= 0 && ishandle(previewHdl)             
            updatePreview;
        end
        
    end

    function [params] = read_sim_txt(num_sources, dipole_params, sim_params)
        params{1} = 'Dipoles: Position (x, y, z in cm), Orientation (x, y, z),  Moment(nAm)';
        for i = 1:num_sources
            sss = '';
            ff = sprintf('  %d:',i);
            sss = strcat(sss,ff);
            ff = sprintf('  %f',dipole_params.xpos(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',dipole_params.ypos(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',dipole_params.zpos(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',dipole_params.xori(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',dipole_params.yori(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',dipole_params.zori(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',dipole_params.moment(i));
            sss = strcat(sss,ff);
            params{i+1} = sss;
        end
        
        params{num_sources+2} = ' ';
        params{num_sources+3} = 'Parameter: Frequency(Hz)  Onset(s)  Duration(s)  Onset_jitter(s)  Amp_jitter(%)  Waveform  SourceFile';
        for i = 1:num_sources
            sss = '';
            ff = sprintf('  %d:',i);
            sss = strcat(sss,ff);
            ff = sprintf('  %f',sim_params.frequency(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',sim_params.onsetTime(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',sim_params.duration(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',sim_params.onsetJitter(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %f',sim_params.amplitudeJitter(i));
            sss = strcat(sss,ff);
            ff = sprintf('  %s',char(sim_params.sourceType(i)));
            sss = strcat(sss,ff);
            ff = sprintf('  %s',char(sim_params.sourceFile(i)));
            sss = strcat(sss,ff);
            params{i+num_sources+3} = sss;
        end
    end

    function add_source_callback(~, ~)
        
        [add_dip, add_sim] = add_source_param(num_sources+1);
        
        if Continue
            if num_sources == 0
                dipole_params = struct('xpos',{add_dip.xpos},'ypos',{add_dip.ypos},'zpos',{add_dip.zpos},'xori',{add_dip.xori},...
                    'yori',{add_dip.yori},'zori',{add_dip.zori},'moment',{add_dip.moment});
                sim_params = struct('frequency',{add_sim.frequency},'onsetTime',{add_sim.onsetTime},'duration',{add_sim.duration},'onsetJitter',{add_sim.onsetJitter},...
                    'amplitudeJitter',{add_sim.amplitudeJitter},'sourceType',{cellstr(add_sim.sourceType)},'sourceFile',{cellstr(add_sim.sourceFile)});
            else
                dipole_params.xpos(num_sources+1) = add_dip.xpos;
                dipole_params.ypos(num_sources+1) = add_dip.ypos;
                dipole_params.zpos(num_sources+1) = add_dip.zpos;
                dipole_params.xori(num_sources+1) = add_dip.xori;
                dipole_params.yori(num_sources+1) = add_dip.yori;
                dipole_params.zori(num_sources+1) = add_dip.zori;
                dipole_params.moment(num_sources+1) = add_dip.moment;
                
                sim_params.frequency(num_sources+1) = add_sim.frequency;
                sim_params.onsetTime(num_sources+1) = add_sim.onsetTime;
                sim_params.duration(num_sources+1) = add_sim.duration;
                sim_params.onsetJitter(num_sources+1) = add_sim.onsetJitter;
                sim_params.amplitudeJitter(num_sources+1) = add_sim.amplitudeJitter;
                sim_params.sourceType(num_sources+1) = cellstr(add_sim.sourceType);
                sim_params.sourceFile(num_sources+1) = cellstr(add_sim.sourceFile);
            end
            num_sources = num_sources + 1;
            
            [params] = read_sim_txt(num_sources,dipole_params, sim_params);
            
            set(SimParams_box,'Value',1);
            set(SimParams_box,'String',params);
            
            plot_sources;
            
        else
            return;
        end
    end

    function plot_sources
              
          if num_sources == 0
            return;
          end
      
          subplot('Position', source_plot);
      
          % clear all currently plotted sources
          cla(gca);
      
          % plot source for one trial
          ylims = [-3 3];
          colorstring = 'bgrcmykw';

          for source=1:num_sources
            
              duration_samples = round(sim_params.duration(source)*SampleRate);
              wave = zeros(duration_samples, 1);
              sourceData = zeros(NumberSamples, 1);

              if size(loadfull,2)>1
                  [~,~,EXT] = fileparts(loadfull);

                  if strcmp(EXT,'.geom')
                      numPreTrig = 0;
                  else
                      numPreTrig = ctf_header.numPreTrig;
                  end
              else
                  numPreTrig = 0;
              end

              % calculate wave data for wave duration
              if strcmp(sim_params.sourceType(source),'source_file')
                  fid = fopen(char(sim_params.sourceFile(source)), 'r');

                  for sample=1:duration_samples
                      fval = fscanf(fid, '%g', [1 1]);
                      if isempty(fval)
                          fprintf('Error reading samples from %s: check that file contains %d valid data samples\n', char(sim_params.sourceFile(1)), duration_samples);
                          return;
                      end
                      wave(sample) = fval;
                  end

                  fclose(fid);

                  % make sure source waveform is not zero and is normalized to
                  % 1.0
                  maxVal = max(abs(wave));
                  if maxVal == 0
                      fprintf('Error: waveform values from file %s are all zero\n', char(sim_params.sourceFile(source)));
                      return;
                  end
                  wave = wave/maxVal;

              else
                  t = (1:duration_samples)/SampleRate;
                  if strcmp(sim_params.sourceType(source), 'sine')
                       wave = (sin(2*pi*t*sim_params.frequency(source)))';
                  elseif strcmp(sim_params.sourceType(source), 'sine-squared')
                       wave = ((sin(2*pi*t*sim_params.frequency(source))).^2)';
                  elseif strcmp(sim_params.sourceType(source), 'square')
                       wave = double(ones(duration_samples,1));
                  end
              end

              % get wave onset time
              onsetTime = sim_params.onsetTime(source);
              if sim_params.onsetJitter(source) > 0
                  onsetTime = onsetTime + ((rand(1,1)*2.0)-1.0)*sim_params.onsetJitter(source);
              end

              % add wave amplitude jitter
              if sim_params.amplitudeJitter(source) > 0
                  inc = 1.0 + (((rand(1,1)*2.0)-1.0)*sim_params.amplitudeJitter(source))*0.01;
                  wave = wave.*inc;
              end

              % get start and end samples
              startSample = round((onsetTime*SampleRate) + numPreTrig);
              if startSample < 1
                  startSample = 1;
              elseif startSample > NumberSamples
                  startSample = NumberSamples;
              end
              endSample = startSample + duration_samples-1;
              if endSample > NumberSamples
                  endSample = NumberSamples;
              end
              if (endSample-startSample+1) < size(wave,1)
                  fprintf('Error: wave duration cannot exceed trial\n');
                  return;
              end 
              
              % sourceData for whole trial 
              sourceData(startSample:endSample) = wave;

              maxScale = max(sourceData) * 1.2;
              minScale = min(sourceData) * 1.2;
              
              % plot source
%               if max(sourceData,1) > 1
%                   ylim([-1 (max(sourceData,1)+0.5)]);
%                   ylims(2) = (max(sourceData,1)+0.5);
%               end
%               if min(wave,1) < -1
%                   ylim([(min(sourceData,1)-0.5) ylims(2)]); 
%                   ylims(1) = (min(sourceData,1)-0.5);
%               end
              legend_str{source} = sprintf('source %d', source);
              color = colorstring(mod(source, 9));
              hold on;
              preTrigTime = PreTrigPoints / SampleRate;
              tVec = -preTrigTime: 1/SampleRate: EpochDuration-preTrigTime;
              tVec = tVec(1:NumberSamples)';
              ploti = plot(tVec, sourceData, 'Color', color);
              p(source) = ploti(1);
              hold off;
          end

%           legend(p, legend_str, 'FontSize', 7, 'position', [0.92 0.55 0.01 0.01]);
          legend(p, legend_str, 'FontSize', 7);
          ylim([minScale maxScale]);

    end
  
    function [add_dip, add_sim] = add_source_param(source)
        
        scrsz=get(0,'ScreenSize');
        f2=figure('Name', 'Add Source', 'Position', [(scrsz(3)-650)/2 (scrsz(4)-550)/2 650 550],...
            'menubar','none','numbertitle','off','Color','white');
        if source > num_sources
            xpos = 0; ypos = 0; zpos = 0;
            xori = 1; yori = 0; zori = 0;
            moment = 0;
            frequency = 0; onsetTime = 0; duration = 0; onsetJitter = 0; amplitudeJitter = 0;
            sourceType = 'sine';
            sourceFile = ' ';
        else
            xpos = dipole_params.xpos(source);
            ypos = dipole_params.ypos(source);
            zpos = dipole_params.zpos(source);
            xori = dipole_params.xori(source);
            yori = dipole_params.yori(source);
            zori = dipole_params.zori(source);
            moment = dipole_params.moment(source);
            frequency = sim_params.frequency(source);
            onsetTime = sim_params.onsetTime(source);
            duration = sim_params.duration(source);
            onsetJitter = sim_params.onsetJitter(source);
            amplitudeJitter = sim_params.amplitudeJitter(source);
            sourceType = sim_params.sourceType(source);
            sourceFile = sim_params.sourceFile(source);
            
        end
        
    % parameter text box
    uicontrol('style','text','units','normalized','position',[0.1 0.92 0.25 0.04],...
        'String','Dipole Parameters','ForegroundColor','blue','FontSize', 11,...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');

    annotation('rectangle','position',[0.02 0.62 0.96 0.33],'edgecolor','blue');
       
    uicontrol('style','text','units','normalized','position',[0.1 0.52 0.28 0.04],...
        'String','Simulation Parameters','ForegroundColor','blue','FontSize', 11,...
        'HorizontalAlignment','center','BackGroundColor', 'white','fontweight','b');

       annotation('rectangle','position',[0.02 0.1 0.96 0.45],'edgecolor','blue');
        
        uicontrol('style','text','units','normalized','position',[0.04 0.85 0.18 0.04],...
            'string','X position (cm):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.23 0.85 0.08 0.04],...
            'string',xpos,'FontSize', 11, 'BackGroundColor','white','callback',@dip_xpos_callback);
        function dip_xpos_callback(src,~)
            xpos = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.35 0.85 0.18 0.04],...
            'string','Y position (cm):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.54 0.85 0.08 0.04],...
            'string',ypos,'FontSize', 11, 'BackGroundColor','white','callback',@dip_ypos_callback);
        function dip_ypos_callback(src,~)
            ypos = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.66 0.85 0.18 0.04],...
            'string','Z position (cm):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.85 0.85 0.08 0.04],...
            'string',zpos,'FontSize', 11, 'BackGroundColor','white','callback',@dip_zpos_callback);
        function dip_zpos_callback(src,~)
            zpos = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.04 0.75 0.18 0.04],...
            'string','X orientation:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.2 0.75 0.08 0.04],...
            'string',xori,'FontSize', 11, 'BackGroundColor','white','callback',@dip_xori_callback);
        function dip_xori_callback(src,~)
            xori = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.36 0.75 0.18 0.04],...
            'string','Y orientation:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.52 0.75 0.08 0.04],...
            'string',yori,'FontSize', 11, 'BackGroundColor','white','callback',@dip_yori_callback);
        function dip_yori_callback(src,~)
            yori = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.67 0.75 0.18 0.04],...
            'string','Z orientation:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.83 0.75 0.08 0.04],...
            'string',zori,'FontSize', 11, 'BackGroundColor','white','callback',@dip_zori_callback);
        function dip_zori_callback(src,~)
            zori = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.04 0.65 0.18 0.04],...
            'string','Moment (nAm):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.23 0.65 0.08 0.04],...
            'string',moment,'FontSize', 11, 'BackGroundColor','white','callback',@dip_moment_callback);
        function dip_moment_callback(src,~)
            moment = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.04 0.45 0.18 0.04],...
            'string','Frequency (Hz):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.23 0.45 0.08 0.04],...
            'string',frequency,'FontSize', 11, 'BackGroundColor','white','callback',@sim_frequency_callback);
        function sim_frequency_callback(src,~)
            frequency = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.35 0.45 0.18 0.04],...
            'string','onsetTime (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.54 0.45 0.08 0.04],...
            'string',onsetTime,'FontSize', 11, 'BackGroundColor','white','callback',@sim_onsettime_callback);
        function sim_onsettime_callback(src,~)
            onsetTime = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.68 0.45 0.18 0.04],...
            'string','duration (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.83 0.45 0.08 0.04],...
            'string',duration,'FontSize', 11, 'BackGroundColor','white','callback',@sim_duration_callback);
        function sim_duration_callback(src,~)
            duration = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.04 0.35 0.18 0.04],...
            'string','onsetJitter (s):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.22 0.35 0.08 0.04],...
            'string',onsetJitter,'FontSize', 11, 'BackGroundColor','white','callback',@sim_onsetjitter_callback);
        function sim_onsetjitter_callback(src,~)
            onsetJitter = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.35 0.35 0.22 0.04],...
            'string','amplitudeJitter (%):','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.58 0.35 0.08 0.04],...
            'string',amplitudeJitter,'FontSize', 11, 'BackGroundColor','white','callback',@sim_amplitudeJitter_callback);
        function sim_amplitudeJitter_callback(src,~)
            amplitudeJitter = str2double(get(src,'String'));
        end
        
        uicontrol('style','text','units','normalized','position',[0.04 0.25 0.18 0.04],...
            'string','sourceType:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        sim_sourcetype=uicontrol('style','popup','units','normalized','position',[0.2 0.25 0.25 0.04],...
            'string','Sinewave|Sinewave squared|Squarewave|Choose a source file','FontSize', 11, 'BackGroundColor','white','callback',@sim_sourcetype_callback);
        function sim_sourcetype_callback(~,~)
            val = get(sim_sourcetype,'Value');
            switch val
                case 1
                    sourceType = 'sine';
                    sourceFile = ' ';
                    set(sim_sourcefile,'enable','off');
                    set(sourcefile_browse, 'enable','off');
                case 2
                    sourceType = 'sine-squared';
                    sourceFile = ' ';
                    set(sim_sourcefile,'enable','off');
                    set(sourcefile_browse, 'enable','off');
                case 3
                    sourceType = 'square';
                    sourceFile = ' ';
                    set(sim_sourcefile,'enable','off');
                    set(sourcefile_browse, 'enable','off');
                case 4
                    sourceType = 'source_file';
                    set(sim_sourcefile,'enable','on');
                    set(sourcefile_browse, 'enable','on');
            end
        end

        uicontrol('style','text','units','normalized','position',[0.04 0.15 0.18 0.04],...
            'string','sourceFile:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        sim_sourcefile=uicontrol('style','edit','units','normalized','position',[0.2 0.15 0.45 0.04],...
            'string',sourceFile,'FontSize', 11,'enable','off', 'BackGroundColor','white','callback',@sim_sourcefile_callback);
        function sim_sourcefile_callback(src,~)
            sourceFile = get(src,'String');
        end
        
        sourcefile_browse = uicontrol('style','pushbutton','units','normalized','position',[0.7 0.15 0.12 0.04],...
            'String','Browse','FontSize',11,'enable','off','BackgroundColor','white','callback',@sourcefile_browse_callback);
        
        function sourcefile_browse_callback(~,~)
            
            s = fullfile(char(loadfull),'*.*');
            [filename,path,~] = uigetfile('*.*','Select a source file', s);
            if isequal(filename,0) || isequal(path,0)
                return;
            else
                sourceFile=fullfile(path,filename);
                set(sim_sourcefile,'string',sourceFile);
                if isempty(sourceFile)
                    sourceFile=' ';
                end
            end
        end
        
        switch char(sourceType)
            case 'sine'
                set(sim_sourcetype, 'value', 1);
                set(sim_sourcefile,'enable','off');
                set(sourcefile_browse, 'enable','off');
            case 'sine-squared'
                set(sim_sourcetype, 'value', 2);
                set(sim_sourcefile,'enable','off');
                set(sourcefile_browse, 'enable','off');
            case 'square'
                set(sim_sourcetype, 'value', 3);
                set(sim_sourcefile,'enable','off');
                set(sourcefile_browse, 'enable','off');
            case 'source_file'
                set(sim_sourcetype, 'value', 4);
                set(sim_sourcefile,'enable','on');
                set(sourcefile_browse, 'enable','on');
        end
        
        uicontrol('Units','Normalized','Position',[0.3 0.03 0.1 0.04],'String','Save',...
            'FontSize',11,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@save_callback);
        uicontrol('Units','Normalized','Position',[0.6 0.03 0.1 0.04],'String','Cancel',...
            'FontSize',11,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@cancel_callback);
        
        function save_callback(~, ~)
            add_dip = struct('xpos',{xpos},'ypos',{ypos},'zpos',{zpos},'xori',{xori},...
                'yori',{yori},'zori',{zori},'moment',{moment});
            add_sim = struct('frequency',{frequency},'onsetTime',{onsetTime},'duration',{duration},'onsetJitter',{onsetJitter},...
                'amplitudeJitter',{amplitudeJitter},'sourceType',{sourceType},'sourceFile',{sourceFile});
            
            uiresume(gcf);
            Continue = 1;
        end
        
        function cancel_callback(~, ~)
            add_dip = struct('xpos',{},'ypos',{},'zpos',{},'xori',{},...
                'yori',{},'zori',{},'moment',{});
            add_sim = struct('frequency',{},'onsetTime',{},'duration',{},'onsetJitter',{},...
                'amplitudeJitter',{},'sourceType',{},'sourceFile',{});
            uiresume(gcf);
            Continue = 0;
        end
        
        
        uiwait(gcf);
        close(f2);      
                
    end

    function edit_source_callback(~,~)
        if num_sources==0
            return;
        end
        
        % choose source to edit
        ed_sourcenum = num_sources;
        scrsz=get(0,'ScreenSize');
        f2=figure('Name', 'Edit Source', 'Position', [(scrsz(3)-500)/2 (scrsz(4)-150)/2 500 150],...
            'menubar','none','numbertitle','off','Color','white');
        
        uicontrol('style','text','units','normalized','position',[0.05 0.65 0.75 0.12],...
            'string','Choose a source number you want to edit:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.7 0.65 0.1 0.12],...
            'string',ed_sourcenum,'FontSize', 11, 'BackGroundColor','white','callback',@ed_sourcenum_callback);
        function ed_sourcenum_callback(src,~)
            ed_sourcenum = str2double(get(src,'String'));
        end
        
        uicontrol('Units','Normalized','Position',[0.3 0.2 0.12 0.15],'String','Okay',...
            'FontSize',11,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@save_callback);
        uicontrol('Units','Normalized','Position',[0.6 0.2 0.12 0.15],'String','Cancel',...
            'FontSize',11,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@cancel_callback);
        function save_callback(~, ~)
            uiresume(gcf);
            Continue = 1;
        end
        
        function cancel_callback(~, ~)
            uiresume(gcf);
            Continue = 0;
        end
        
        uiwait(f2);
        close(f2);
        
        if Continue == 0
            return;
        end
        
        if (ed_sourcenum < 1 || ed_sourcenum > num_sources)
            tstr = sprintf('You need to choose a source number between 1 and %d',num_sources);
            warndlg(tstr);
            return;
        end
        
        % edit source params
        [add_dip, add_sim] = add_source_param(ed_sourcenum);
        
        % save and plot
        if Continue
            dipole_params.xpos(ed_sourcenum) = add_dip.xpos;
            dipole_params.ypos(ed_sourcenum) = add_dip.ypos;
            dipole_params.zpos(ed_sourcenum) = add_dip.zpos;
            dipole_params.xori(ed_sourcenum) = add_dip.xori;
            dipole_params.yori(ed_sourcenum) = add_dip.yori;
            dipole_params.zori(ed_sourcenum) = add_dip.zori;
            dipole_params.moment(ed_sourcenum) = add_dip.moment;

            sim_params.frequency(ed_sourcenum) = add_sim.frequency;
            sim_params.onsetTime(ed_sourcenum) = add_sim.onsetTime;
            sim_params.duration(ed_sourcenum) = add_sim.duration;
            sim_params.onsetJitter(ed_sourcenum) = add_sim.onsetJitter;
            sim_params.amplitudeJitter(ed_sourcenum) = add_sim.amplitudeJitter;
            sim_params.sourceType(ed_sourcenum) = cellstr(add_sim.sourceType);
            sim_params.sourceFile(ed_sourcenum) = cellstr(add_sim.sourceFile);

            [params] = read_sim_txt(num_sources,dipole_params, sim_params);
            
            set(SimParams_box,'Value',1);
            set(SimParams_box,'String',params);
            
            plot_sources;
            
        else
            return;
        end
    end

    function delete_source_callback(~,~)
        del_sourcenum = num_sources;
        scrsz=get(0,'ScreenSize');
        f2=figure('Name', 'Delete Source', 'Position', [(scrsz(3)-500)/2 (scrsz(4)-150)/2 500 150],...
            'menubar','none','numbertitle','off','Color','white');
        
        uicontrol('style','text','units','normalized','position',[0.05 0.65 0.75 0.12],...
            'string','Choose a source number you want to delete:','fontsize',11,'backgroundcolor','white','horizontalalignment','left');
        uicontrol('style','edit','units','normalized','position',[0.7 0.65 0.1 0.12],...
            'string',del_sourcenum,'FontSize', 11, 'BackGroundColor','white','callback',@del_sourcenum_callback);
        function del_sourcenum_callback(src,~)
            del_sourcenum = str2double(get(src,'String'));
        end
        
        uicontrol('Units','Normalized','Position',[0.3 0.2 0.12 0.15],'String','Save',...
            'FontSize',11,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@save_callback);
        uicontrol('Units','Normalized','Position',[0.6 0.2 0.12 0.15],'String','Cancel',...
            'FontSize',11,'FontWeight','normal','ForegroundColor',...
            'black','Callback',@cancel_callback);
        function save_callback(~, ~)
            uiresume(gcf);
            Continue = 1;
        end
        
        function cancel_callback(~, ~)
            uiresume(gcf);
            Continue = 0;
        end
        
        uiwait(gcf);
        close(f2);
        
        if Continue == 0
            return;
        end
        
        if (num_sources==0)
            tstr = sprintf('There is no dipole source exist');
            warndlg(tstr);
            return;
            
        elseif (del_sourcenum >0 && del_sourcenum <= num_sources)
            dipole_params.xpos(del_sourcenum) = [];
            dipole_params.ypos(del_sourcenum) = [];
            dipole_params.zpos(del_sourcenum) = [];
            dipole_params.xori(del_sourcenum) = [];
            dipole_params.yori(del_sourcenum) = [];
            dipole_params.zori(del_sourcenum) = [];
            dipole_params.moment(del_sourcenum) = [];
            
            sim_params.frequency(del_sourcenum) = [];
            sim_params.onsetTime(del_sourcenum) = [];
            sim_params.duration(del_sourcenum) = [];
            sim_params.onsetJitter(del_sourcenum) = [];
            sim_params.amplitudeJitter(del_sourcenum) = [];
            sim_params.sourceType(del_sourcenum) = [];
            sim_params.sourceFile(del_sourcenum) = [];
        else
            tstr = sprintf('You need to choose a source number between 1 and %d',num_sources);
            warndlg(tstr);
            return;
        end
        
        num_sources = num_sources -1;
        [params] = read_sim_txt(num_sources,dipole_params, sim_params);
        set(SimParams_box,'Value',1);
        set(SimParams_box,'String',params);
        
        plot_sources;
    end

    function save_simfile_callback(~,~)
        
        if (num_sources==0)
            tstr = sprintf('There is no source to save');
            warndlg(tstr);
            return;
        end
        [filename,Path,~] = uiputfile('*.sim','Select Dataset Name:');
        if isequal(filename,0)
            return;
        end
        simfile = fullfile(Path, filename);        
        fid = fopen(simfile,'wt');
        fprintf(fid,'SIM_FILE_VER_2\n');
        fprintf(fid,'//     index	xpos(cm)	ypos(cm)	zpos(cm)	xo		yo		zo		Q (nAm)\n');
        
        % write dip params
        fprintf(fid,'Dipoles\n');
        fprintf(fid,'{\n');
        for i=1:num_sources
            fprintf(fid,'\t%d:\t%.2f\t%.2f\t%.2f\t%.4f\t%.4f\t%.4f\t%f\n',i, dipole_params.xpos(i),dipole_params.ypos(i),dipole_params.zpos(i),dipole_params.xori(i),dipole_params.yori(i),dipole_params.zori(i),dipole_params.moment(i));
        end
        fprintf(fid,'}\n');
        fprintf(fid,'\n');
        
        % write sim params
        fprintf(fid,'//	    index	frequency(Hz)	onset(s)	duration(s)	onset jitter(s)	amp. jitter(percent)	type\n');
        fprintf(fid,'Params\n');
        fprintf(fid,'{\n');
        for i=1:num_sources
            if strcmp(sim_params.sourceType(i),'source_file')
                sourfile_str = strcat('file:',char(sim_params.sourceFile(i)));
                fprintf(fid,'\t%d:\t%f\t%f\t%f\t%f\t%f\t%s\n',i, sim_params.frequency(i),sim_params.onsetTime(i),sim_params.duration(i),sim_params.onsetJitter(i),sim_params.amplitudeJitter(i),sourfile_str);
            else
                fprintf(fid,'\t%d:\t%f\t%f\t%f\t%f\t%f\t%s\n',i, sim_params.frequency(i),sim_params.onsetTime(i),sim_params.duration(i),sim_params.onsetJitter(i),sim_params.amplitudeJitter(i),char(sim_params.sourceType(i)));
            end
        end
        fprintf(fid,'}\n');       
        
        fclose(fid);
    end

%surrounding rectangle
annotation('rectangle','position',[0.01 0.09 0.58 0.6],'edgecolor','blue');

startFile = sprintf('%sCTF_151.geom', SIMDS_PATH);
load_geom(startFile);


% create dataset
%
    function preview_ds_callback(~,~)
        updatePreview;
    end

    function updatePreview
        
        tempDsName = sprintf('%s%ssimDsTempFile_000.ds',pwd,filesep);
       
        % delete any old copy of temp file to avoid overwrite permissions
        
        if exist(tempDsName,'dir')
            if ispc 
                cmd = sprintf('rmdir /s /q %s',tempDsName); 
            else
                cmd = sprintf('rm -rf %s',tempDsName);
            end
            system(cmd);
        end
        
        gotFile = 1;
        if num_sources == 0
            gotSim = 0;
        else
            gotSim = 1;
        end
       
        wbh = waitbar(0.3,'Generating dataset...');
      
        save_simfile = sim_write_simfile(num_sources, dipole_params,sim_params);
        simFileName = save_simfile;     
       
        if dipoleType == 1
            computeMagnetic = 0;
        else
            computeMagnetic = 1;
        end
         
        err = simDsMex(gotData, dsName, gotGeomFile, geomFileName, gotSim, simFileName, gotFile, tempDsName, AddBrainnoise, hasOrigin, [sphereOrigin_x sphereOrigin_y sphereOrigin_z],...
            AddNoise, peakNoise, highPassFreq, lowPassFreq, rotateDipoles, GradientOrder, gotTrials, TrialNumber, gotSamples, NumberSamples, gotSampleRate, SampleRate,...
            UseSingleSphere, headModelFile, dumpForward, dumpFileName, verbose, forceOverwrite, computeMagnetic, writeADC);
        
        if err==0
            s = sprintf('simDsMex returned error %d ... ', err);
            warndlg(s);
            delete(wbh);
            return;
        end
        
        waitbar(0.6,wbh);         
        plot_average(tempDsName, 1); 
        delete(wbh);      
        
    end

    function create_ds_callback(~,~)
        
        [filename,Path,~] = uiputfile('*.ds','Select Dataset Name:');
        if isequal(filename,0)
            return;
        end
        
        newDsName = fullfile(Path, filename);
                  
        gotFile = 1;
        if num_sources ==0
            gotSim = 0;
        else
            gotSim = 1;
        end
       
        wbh = waitbar(0.3,'Generating dataset...');
      
        save_simfile = sim_write_simfile(num_sources, dipole_params,sim_params);
        simFileName = save_simfile;    
        
        if dipoleType == 1
            computeMagnetic = 0;
        else
            computeMagnetic = 1;
        end
        
        err = simDsMex(gotData, dsName, gotGeomFile, geomFileName, gotSim, simFileName, gotFile, newDsName, AddBrainnoise, hasOrigin, [sphereOrigin_x sphereOrigin_y sphereOrigin_z],...
            AddNoise, peakNoise, highPassFreq, lowPassFreq, rotateDipoles, GradientOrder, gotTrials, TrialNumber, gotSamples, NumberSamples, gotSampleRate, SampleRate,...
            UseSingleSphere, headModelFile, dumpForward, dumpFileName, verbose, forceOverwrite, computeMagnetic, writeADC);


        if err==0
            s = sprintf('simDsMex returned error %d ... ', err);
            warndlg(s);
            delete(wbh);
            return;
        end
        
        waitbar(0.6,wbh);
        plot_average(newDsName, 0); 
        delete(wbh);      
        
    end

    function cursor_left_callback(~,~)
         latency = latency - 1/SampleRate;
         if (latency < 0.0)
            beep;
            latency = 0.0;
            return;
         end
         updateCursors;
         updateMap(latency);            
    end

    function cursor_right_callback(~,~)
         latency = latency + 1/SampleRate;
         if (latency > EpochDuration )
            beep;
            latency = EpochDuration;
            return;
         end
         updateCursors;
         updateMap(latency);            
    end    

    function plot_average(dsName, previewMode)
        
         % plot averaged MEG data (as in bw_plot_data)
        [timeVec, ~, plot_data] = sim_CTFGetAverage(dsName ); 
        plot_data = plot_data * 1e15;  % display in femtoTesla
        
        maxScale = max(max(abs(plot_data)))*1.2;
        minScale = -maxScale;
                   
        if previewHdl ~= 0 && ishandle(previewHdl)             
            figure(previewHdl)
        else
            previewHdl = figure('Position', [left2 top-400+22 500 400],...
                'menubar','none','numbertitle','off', 'Color','white',...
                'WindowButtonUpFcn',@stopdrag, 'WindowButtonDownFcn',@buttondown);
            
            uicontrol('style','pushbutton','units','normalized','position',[0.35 0.16 0.05 0.05],...
                'CData',leftarrow_im,'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@cursor_left_callback);                         
            uicontrol('style','pushbutton','units','normalized','position',[0.41 0.16 0.05 0.05],...
                'CData',rightarrow_im,'Foregroundcolor','black','backgroundcolor','white','FontSize',10,'callback',@cursor_right_callback);                         

            if ispc
                movegui(previewHdl, [left2+10, 100]);
            end    
            
        end
        
        if previewMode == 1
            s = sprintf('Simulated Data: preView');
        else
             s = sprintf('Simulated Data: %s', dsName);
        end

        set(previewHdl,'Name', s);
        
        % clear all currently plotted sources
        cla(gca);
        
        plot(timeVec, plot_data);
        
        set(gca, 'ylim', [minScale maxScale]);
        
        % time zero vertical and baseline
        ax = axis;
        line_h1 = line([0 0],[ax(3) ax(4)]);
        set(line_h1, 'Color', [0 0 0]);
        vertLineVal = 0;
        if vertLineVal > ax(3) && vertLineVal < ax(4),...
            line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
            set(line_h2, 'Color', [0 0 0]);
        end
        
        % add cursor at peak
        [m,idx] = max(abs(plot_data(:,:))');    % returns peaks for all channels
        [~,sample] = max(m);             % get index of largest value in m
      
        if sample < 1; sample = round(size(plot_data,1)/2); end
        if sample > size(plot_data,1); sample = round(size(plot_data,1)/2); end
           
        latency = timeVec(sample);
        h = [latency latency];
        v = ylim;
        cursorHandle = line(h,v, 'color', 'blue');         
        s = sprintf('Latency = %.3f s', latency);
        latency_text = uicontrol('style','text','units','normalized','position',[0.15 0.15 0.2 0.05],...
            'string',s,'fontsize',11,'backgroundcolor','white','horizontalalignment','left');
       
        xlabel('Time (s)');
        ylabel('Amplitude (fT)');
        title('MEG Average (All Channels)', 'Fontsize', 10);
 
        initMap(dsName, latency);
        
        updateMap(latency);
        
    end 
       
   function initMap(dsName, latency)
     
        if mapFig ~= 0 && ishandle(mapFig)             
            figure(mapFig)
        else
            mapFig = figure('Position', [left2 top-822+22 500 400],...
                'menubar','none','numbertitle','off', 'Color','white');
           
            if ispc
                movegui(mapFig, [left2+422, 100]);
            end            
            
        end
        
        % init map structures once 
        [~, ~, plot_data] = sim_CTFGetAverage(dsName ); 
        plot_data = plot_data * 1e15;  % display in femtoTesla
        

        % create an EEGLAB chanlocs structure to avoid having to save .locs file
        mapLocs = struct('labels',{},'theta', {}, 'radius', {});
        header = sim_CTFGetHeader(dsName);
        mapLocs = getMapLocs(header);
        clear header;
        
        updateMap(latency);
        
        h = colorbar;
        tstr = sprintf('femtoTesla');
        set(get(h,'YLabel'),'String',tstr);
          
   end

    function updateMap(latency)
     
        figure(mapFig)
        
        sample = round(latency * SampleRate) + 1 + PreTrigPoints;
        map_data = plot_data(sample,:)';

        topoplot(map_data, mapLocs, 'colormap',jet,'numcontour',8,'electrodes','on','shrink',0.15);
        
        tstr = sprintf('Latency = %.3f s', latency);
        set(mapFig,'Name', tstr);
        set(mapFig,'Color','White');
         
    end

    function [mapLocs] = getMapLocs(header)

        % create an EEGLAB chanlocs structure to avoid having to save .locs file
        mapLocs = struct('labels',{},'theta', {}, 'radius', {});

        channelIndex = 1;
        for i=1:header.numChannels

            chan = header.channel(i);
            if ~chan.isSensor
                continue;
            end

            name = chan.name;
            % remove dashes in CTF names
            idx = strfind(name,'-');
            if ~isempty(idx)
                temp=name(1:idx-1);
                name = temp;
            end

            X = chan.xpos;
            Y = chan.ypos;
            Z = chan.zpos;
            

            [th, phi, ~] = cart2sph(X,Y,Z);

            decl = (pi/2) - phi;
            radius = decl / pi;
            theta = th * (180/pi);
            if (theta < 180)
                theta = -theta;
            else
                theta = 360 - theta;
            end

            mapLocs(channelIndex).labels = name;
            mapLocs(channelIndex).theta = theta;
            mapLocs(channelIndex).radius = radius;  
            channelIndex = channelIndex + 1;
        end
    end

    % generic cursor routines
    
    function updateCursors
        if ~isempty(cursorHandle)
            set(cursorHandle, 'XData', [latency latency]);      
        end 
        s = sprintf('Latency = %.3f s', latency);
        set(latency_text, 'string', s);
    end
    
    % update drawing while cursor being dragged
    function buttondown(~,~)         

        % get current latency in s (x coord)
        mousecoord = get(gca,'currentpoint');
        ax = gca;

        % drag if within +/- 1 second from cursor
        if latency > mousecoord(1,1)-1 && latency < mousecoord(1,1)+1
            set(previewHdl,'WindowButtonMotionFcn',{@dragCursor,ax}) % need to explicitly pass the axis handle to the motion callback
            return;
        end      
    end

    % button down function - drag cursor
    function dragCursor(~,~, ax)
        mousecoord = get(ax,'currentpoint');
        latency = mousecoord(1,1);
        updateCursors;
    end

    % on button up event set motion event back to no callback 
    function stopdrag(~,~)
        set(previewHdl,'WindowButtonMotionFcn','');
        updateMap(latency);
    end


end
