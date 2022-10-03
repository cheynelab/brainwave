function bw_VSplot(VS_ARRAY, params)       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%   function bw_VSplot(VS_ARRAY, vs_options)
%
%   DESCRIPTION: creates a virtual sensor plot window - separate function 
%   that is derived from bw_make_vs_mex.  Note plot window holds  all params
%   necessary to save average and/or generate the single trial data for saving.
%
%   Dec, 2015 - replaces bw_plot_vs.m
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


    if isempty(params.vs_parameters.plotLabel)
        groupLabel = 'Grand Average';
    else
        groupLabel = params.vs_parameters.plotLabel;
    end
    
    if isfield(params.vs_parameters,'groupLabel')
        filename = params.vs_parameters.groupLabel;
    else
        filename = 'Virtual Sensor';
    end
    
    scrnsizes=get(0,'MonitorPosition');

    % persistent counter to move figure
    persistent plotcount;

    if isempty(plotcount)
        plotcount = 0;
    else
        plotcount = plotcount+1;
    end

    % tile windows
    width = 680;
    height = 500;
    start = round(0.4 * scrnsizes(1,3));
    bottom_start = round(0.7 * scrnsizes(1,4));

    inc = plotcount * 0.01 * scrnsizes(1,3);
    left = start+inc;
    bottom = bottom_start - inc;

    ylimits = []; % forces autoscale first time
    xlimits = []; % forces autoscale first time
    autoscale = 1;
    flipWaveforms = 0;
    
    if ( (left + width) > scrnsizes(1,3) || (bottom + height) > scrnsizes(1,4)) 
        plotcount = 0;
        left = start;
        bottom = bottom_start;
    end
    
    fh = figure('color','white','Position',[left,bottom,width,height], 'NumberTitle','off');
    if ispc
        movegui(fh,'center');
    end
    
    datacursormode(fh);
        
    BRAINWAVE_MENU=uimenu('Label','Brainwave');

    uimenu(BRAINWAVE_MENU,'label','Edit Plot...','Callback',@change_parameters_callback); % Anton 2021/05/20 - erased space between "edit" and "..."
        
    uimenu(BRAINWAVE_MENU,'label','Save VS Plot...','separator','on','Callback',@save_vs_data_callback);
    uimenu(BRAINWAVE_MENU,'label','Add VS Plot...','Callback',@open_vs_callback);
    uimenu(BRAINWAVE_MENU,'label','Export VS data ...','Callback',@save_data_callback);
    
    PLOT_AVERAGE_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Average','separator','on','Callback',@average_callback);
    PLOT_PLUSMINUS_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Average+PlusMinus','Callback',@plusminus_callback);
    PLOT_ALL_EPOCHS_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Single trials','Callback',@all_epochs_callback);

    ERROR_BAR_MENU = uimenu(BRAINWAVE_MENU,'label','Show Standard Error','separator','on');
    uimenu(BRAINWAVE_MENU,'label','Change Plot Colour...','Callback',@plot_color_callback);
    uimenu(BRAINWAVE_MENU,'label','Flip Polarity','Callback',@flip_callback);
    uimenu(BRAINWAVE_MENU,'label','Autoscale','checked','on','Callback',@autoscale_callback);

    ERROR_NONE = uimenu(ERROR_BAR_MENU,'label','None','checked','on','Callback',@plot_none_callback);
    ERROR_SHADED = uimenu(ERROR_BAR_MENU,'label','Shaded','Callback',@plot_shaded_callback);
    ERROR_BARS = uimenu(ERROR_BAR_MENU,'label','Bars','Callback',@plot_bars_callback);
          
    DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');
   
    set(PLOT_AVERAGE_MENU,'checked','on');      
    
    numSubjects = 1;
    bandwidth = VS_ARRAY{1}.filter; 
    timeVec = VS_ARRAY{1}.timeVec;
    dwel = timeVec(2) - timeVec(1);
    sampleRate = 1.0 / dwel; 

    plotAverage = 1;
    plotPlusMinus = 0;
    plotOverlay = 0;
    subject_idx = 1;
    
    vs_data = {};
    ave_group = [];
    labels = {};
    
    initialize_subjects;
   
    function initialize_subjects() 
        
       [~, numSubjects] = size(VS_ARRAY);
       if numSubjects == 1
            set(ERROR_BAR_MENU,'enable','off');
            subject_idx = 1;
        else
            subject_idx = 0;
       end  
        
        for k=1:numSubjects
            labels{k} = cellstr(VS_ARRAY{k}.label); 
        end

        % rebuild data menu
        if exist('DATA_SOURCE_MENU','var')
            delete(DATA_SOURCE_MENU);
            clear DATA_SOURCE_MENU;
        end    
        DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');
        for k=1:numSubjects
            uimenu(DATA_SOURCE_MENU,'Label',char(labels{k}),'Callback',@data_menu_callback);   
        end

        if (numSubjects > 1)
            plotOverlay = 1;        % make overlay default
            s = sprintf('%s', groupLabel);
            uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','off',...
                'separator','on','Callback',@data_menu_callback);        
            s = sprintf('Overlay');
            uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','on',...edit 
                'separator','on','Callback',@data_menu_callback);        
        else
             % uncheck all menus
            set(get(DATA_SOURCE_MENU,'Children'),'Checked','on');
        end

        vs_data = {numSubjects};    
        numSamples = length(timeVec);
        ave_group = zeros(numSubjects,numSamples);

        for k=1:numSubjects
            vs_data{k} = VS_ARRAY{k}.vs_data';

            % check for single trial data
            if size(vs_data{k},1) == 1
                set(PLOT_ALL_EPOCHS_MENU,'enable','off');
                set(PLOT_PLUSMINUS_MENU,'enable','off');
            end
        end
        
    end
    
    % ** version 3.6 - add option to load another subject / condition
    function open_vs_callback(~,~)
        [name,path,~] = uigetfile('*.mat','Select a VS .mat file:');
        if isequal(name,0)
            return;
        end
        infile = fullfile(path,name);
       
        t = load(infile);
        
        % read old format...(needs testing)
        if ~isfield(t,'VS_ARRAY')
            fprintf('This does not appear to be a BrainWave VS data file\n');
            return;
        end
        
        % check for same time base - use original VS for params?
        
        t_timeVec = t.VS_ARRAY{1}.timeVec;
        if any(t_timeVec~=timeVec)
            beep();
            fprintf('VS plots have different time bases\n');
            return;
        end
        
        for k=1:size(t.VS_ARRAY,2)
            VS_ARRAY{numSubjects+k} = t.VS_ARRAY{k};  
        end
        initialize_subjects;  
        updatePlot;        
        
     end    


    % callbacks
    
    function data_menu_callback(src,~)      
        subject_idx = get(src,'position');
        
        % if subject_idx == 0 plot average
        if subject_idx == numSubjects + 1
            subject_idx = 0;   
            plotOverlay = 0;
            set(ERROR_BAR_MENU,'enable','on');
        elseif subject_idx == numSubjects + 2
            subject_idx = 0;   
            plotOverlay = 1;
        else
            plotOverlay = 0;
            set(ERROR_BAR_MENU,'enable','off');
        end
        % uncheck all menus
        set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');
        
        set(src,'Checked','on');
        processData;
        updatePlot;
        
    end
    

    function average_callback(src,~)  
        plotAverage = true;
        plotPlusMinus = false;
        
        set(src,'Checked','on');
        set(PLOT_ALL_EPOCHS_MENU,'Checked','off');
        set(PLOT_PLUSMINUS_MENU,'Checked','off');
        
        processData;
        updatePlot;     
    end

    function plusminus_callback(src,~)  
        plotPlusMinus = true;
        plotAverage = false;

        set(src,'Checked','on');
        set(PLOT_ALL_EPOCHS_MENU,'Checked','off');
        set(PLOT_AVERAGE_MENU,'Checked','off');

        processData;
        updatePlot;     
    end

    function all_epochs_callback(src,~)  
        plotAverage = false;
        plotPlusMinus = false;
       
        set(src,'Checked','on');
        set(PLOT_AVERAGE_MENU,'Checked','off');
        set(PLOT_PLUSMINUS_MENU,'Checked','off');
        
        processData;
        updatePlot;     
    end

   function plot_color_callback(~,~) 
        newColor = uisetcolor;
        if size(newColor,2) == 3
            params.vs_parameters.plotColor = newColor;
        end        
        updatePlot;
   end

   function flip_callback(src,~) 
        flipWaveforms = ~flipWaveforms;
        
        if flipWaveforms
            set(src,'Checked','on');
        else       
            set(src,'Checked','off');
        end
        updatePlot;
   end

   function autoscale_callback(src,~) 
        autoscale = ~autoscale;
        
        if autoscale
            set(src,'Checked','on');
        else       
            set(src,'Checked','off');
        end
        updatePlot;
   end



   function plot_none_callback(src,~) 
        params.vs_parameters.errorBarType = 0;
        set(src,'Checked','on');
        set(ERROR_SHADED,'Checked','off');
        set(ERROR_BARS,'Checked','off');
        
        updatePlot;
   end

   function plot_bars_callback(src,~) 
        params.vs_parameters.errorBarType = 1;
        set(src,'Checked','on');
        set(ERROR_NONE,'Checked','off');
        set(ERROR_SHADED,'Checked','off');
        
        updatePlot;
   end

   function plot_shaded_callback(src,~) 
        params.vs_parameters.errorBarType = 2;
        set(src,'Checked','on');
        set(ERROR_NONE,'Checked','off');
        set(ERROR_BARS,'Checked','off');
        
        updatePlot;
   end


   function save_data_callback(~,~)
       
        [name,path,idx] = uiputfile({'*.mat','MAT-file (*.mat)';'*.txt','ASCII file (*.txt)';},...
                    'Export virtual sensor data to:');
        if isequal(name,0)
            return;
        end
        
        filename = fullfile(path,name);
                
        if idx == 1
            saveMatFile = true;
        else
            saveMatFile = false;
        end

        % format for matfile 
        % for n subjects / voxels
        % vsdata.subject{n}.timeVec = 1D array of latencies (nsamples x 1)
        % vsdata.subject{n}.trials = 3D array of vs data (ntrials x nsamples)
        % vsdata.subject{n}.label = original plot label

 
        % ensure current params applied 
        processData;
       
        saveAll = 1;
        % if displaying a single subject otion to save only that data
        if (subject_idx >  0)              
           r = questdlg('Save data for selected subject only?','BrainWave','Save single subject','Save all subjects','Save single subject');
           if strcmp(r,'Save single subject')
               saveAll = 0;
           end
        end
            
        if ~saveAll
           % save this subject's data...           
           data = vs_data{subject_idx};
           
           % save in transposed in format = 1st column is timeVec, 2nd column is trial1...

           fprintf('Saving virtual sensor data to file %s\n', filename);      
            
           if saveMatFile 
                vsdata.subjects{1}.timeVec = timeVec;
                vsdata.subjects{1}.label = VS_ARRAY{1}.plotLabel;
                vsdata.subjects{1}.data = single(data');    % save single precision              
                save(filename,'-struct','vsdata');
           else
                fid = fopen(filename,'w');
                for k=1:size(data,2)
                    fprintf(fid, '%.4f', timeVec(k) );
                    for j=1:size(data,1)
                        fprintf(fid, '\t%8.4f', data(j,k) );
                    end   
                    fprintf(fid,'\n');
                end
                fclose(fid);                                                
            end
        else
            % save multi-subject (voxel) data...
           
            if saveMatFile   
                fprintf('Saving virtual sensor data to file %s\n', filename); 
                for k=1:numSubjects                    
                    data = vs_data{k}; 
                    vsdata.subjects{k}.timeVec = timeVec;
                    vsdata.subjects{k}.label = VS_ARRAY{k}.plotLabel;
                    vsdata.subjects{k}.data = single(data');                 
                end
                save(filename,'-struct','vsdata');
            else
                % put ascii data in separate files but don't overwrite 
                for k=1:numSubjects
                    data = vs_data{k};
                    [path, name, ~] = bw_fileparts(filename); 
                    tname = sprintf('%s_%s.txt', name, char(labels{k}));
                    tFileName = fullfile(path,tname);
                    fprintf('Saving virtual sensor data to file %s\n', tFileName); 
                    fid = fopen(tFileName,'w');
                    for t=1:size(data,2)
                        fprintf(fid, '%.4f', timeVec(t) );
                        for j=1:size(data,1)
                            fprintf(fid, '\t%8.4f', data(j,t) );
                        end   
                        fprintf(fid,'\n');
                    end
                    fclose(fid);     
                end                  
            end
     
        end
   end

    % save data in re-loadable .mat file in BW format...
    function save_vs_data_callback(~,~)      
              
        defName = 'vs_plot.mat';
        [name,path,~] = uiputfile('*.mat','Select Name for VS data file:',defName);
        if isequal(name,0)
            return;
        end
        outFile = fullfile(path,name);
        
        fprintf('Saving VS data to file %s\n', outFile);
        
        % save currently displayed image (groupLabel not used?)
        % added save file name for plot titles 
        plotName = name(1:end-4);
        params.vs_parameters.groupLabel = plotName;
        set(fh,'Name',plotName);
        
        save(outFile,'VS_ARRAY','params', 'groupLabel');            

    end

    function change_parameters_callback(~,~)   
       
        % Version 3.6 now applies fixed x and y scaling 
        [new_params, xlimits, ylimits] = updateParametersDlg(params, timeVec, bandwidth, xlimits, ylimits);

        if ~isempty(new_params)
            params = new_params;
            processData;
            updatePlot;
        end
    end

    processData;
    updatePlot;

    
    function processData
        
        % reload original data
        for k=1:numSubjects
            vs_data{k} = VS_ARRAY{k}.vs_data';
        end
        
        % filter and offset removal
        for k=1:numSubjects            
            data = vs_data{k};
            if (~plotAverage || params.vs_parameters.plotAnalyticSignal) && subject_idx > 0 && params.vs_parameters.subtractAverage
               fprintf('subtracting average from single trials...\n');
               ave_data = mean(data,1);     
               for j=1:size(data,1)
                    data(j,:) = data(j,:) - ave_data;
               end
            end
            
            % filter if this is original bandwidth
            if params.beamformer_parameters.filter(1) ~= bandwidth(1) || params.beamformer_parameters.filter(2) ~= bandwidth(2)
                fprintf('filtering data...\n');
                for j=1:size(data,1)
                    data(j,:) = bw_filter(data(j,:),  sampleRate,  params.beamformer_parameters.filter, 4, params.beamformer_parameters.useReverseFilter);                  
                end
            end
            
            % if plot hilbert amplitude apply to the single trials
            % then compute average
            
            if params.vs_parameters.plotAnalyticSignal
                for j=1:size(data,1)               
                   h = hilbert( data(j,:) );
                   data(j,:) = abs(h);     
                end      
            end    
                                
            vs_data{k} = data;       
                        
        end
    end

    function updatePlot
             
        
        % prepare data for plotting....
        
        if (subject_idx >  0)     
            % plot single subject 
            plotLabel = VS_ARRAY{subject_idx}.plotLabel;    
            start = subject_idx;
            finish = subject_idx;
        else
            plotLabel = groupLabel;    
            start = 1;
            finish = numSubjects;
        end
       
        for k=start:finish
           
            % get data for subject k          
            trial_data = vs_data{k};         
            ave = mean(trial_data,1);     
            if plotPlusMinus   
               nr = (floor(size(trial_data,1)/2) * 2);
               oddTrials = 1:2:nr;
               tdata = trial_data(1:nr,:);  % make sure we have even # of trials
               tdata(oddTrials,:) = tdata(oddTrials,:) * -1.0;   
               pm_ave = mean(tdata,1);
            end
            
            % apply baseline correction to averages only
            % this can be set to params setting - doesn't matter if we do
            % it again for plots..
            if params.beamformer_parameters.useBaselineWindow
                startSample = round( ( params.beamformer_parameters.baseline(1) - timeVec(1)) / dwel) + 1;
                endSample = round( ( params.beamformer_parameters.baseline(2) - timeVec(1)) / dwel) + 1;
                b = mean( ave(startSample:endSample) );               
                ave = ave - b;   
            end
            
            if plotPlusMinus   
                startSample = round( ( params.beamformer_parameters.baseline(1) - timeVec(1)) / dwel) + 1;
                endSample = round( ( params.beamformer_parameters.baseline(2) - timeVec(1)) / dwel) + 1;
                b = mean( pm_ave(startSample:endSample) );               
                pm_ave = pm_ave - b;              
                pm_group(k,:) = pm_ave;  % pm ave for this subject
            end      
            
            % grand average data across subjects
            ave_group(k,:) = ave;  % ave for this subject
            if k==start
                trial_group = trial_data;          
            else
                trial_group = [trial_group; trial_data];
            end
        end
        
        if (subject_idx >  0)     
            if plotAverage    
                plot_data = ave;
            elseif plotPlusMinus
                plot_data = [ave; pm_ave];
            else
                plot_data = trial_data;
            end
        else
            if plotOverlay
                plot_data = ave_group;
            elseif plotAverage
                plot_data = mean(ave_group,1);
            elseif plotPlusMinus
                plot_data = [mean(ave_group,1); mean(pm_group,1)];
            else
                plot_data = trial_group;
            end
        end
                   
        % plot data ...
        
        if flipWaveforms
            plot_data = plot_data .* -1.0;
        end
        
        s = sprintf('%s (%g to %g Hz)', filename, params.beamformer_parameters.filter(1),  params.beamformer_parameters.filter(2));
        
        set(fh,'Name',s);

        if params.vs_parameters.errorBarType > 0 && plotAverage && subject_idx == 0 && plotOverlay == 0
            
            % compute variance across subjects
            stderr = std(ave_group,1) ./sqrt(numSubjects); 
            
            if params.vs_parameters.errorBarType == 1
                % zero values between steps
                err_step = round( params.vs_parameters.errorBarInterval / dwel);
                stderr( find( mod( 1:length(stderr), err_step ) > 0 ) ) = NaN;   

                errorbar(timeVec, plot_data, stderr,'color', params.vs_parameters.plotColor, 'CapSize', params.vs_parameters.errorBarWidth);

                
            elseif params.vs_parameters.errorBarType == 2      
                uplim=plot_data+stderr;
                lolim=plot_data-stderr;
                filledValue=[uplim fliplr(lolim)]; %depends on column type (needs to plot forward, then back to start before fill/patch)
                timeValue=[timeVec; flipud(timeVec)]; 

                h1=fill(timeValue,filledValue,params.vs_parameters.plotColor);
                set(h1,'FaceAlpha',0.5,'EdgeAlpha',0.5,'EdgeColor',params.vs_parameters.plotColor);
                hold on
                plot(timeVec,plot_data, 'color', params.vs_parameters.plotColor);
                hold off
            end
            
        else
            if size(plot_data,1) == 1
                plot(timeVec, plot_data, 'color', params.vs_parameters.plotColor); % apply color only if not plotting plus/ minus
            else
                plot(timeVec, plot_data);  
            end
        end

        % adjust scales
        if isempty(xlimits)
            xlimits = [timeVec(1) timeVec(end)];
        end    
        xlim(xlimits);
        
        % autoscale first time only
        % avoid end effects by 10% for scaling
        if isempty(ylimits) | autoscale
            
            endpts = round(0.1*size(timeVec,1));
            if size(plot_data,1) > 1
                mx = 1.2*max(max(abs( plot_data(:,endpts:end-endpts)) ));
            else
                mx = 1.2*max(abs( plot_data(endpts:end-endpts) ));                       
            end        
            ylimits = [-mx mx];
        end
       
        ylim(ylimits);
        
        % annotate plot       
        if (params.vs_parameters.pseudoZ)   
            dataUnits = 'Pseudo-Z';
        else
            dataUnits = 'Moment (nAm)';
        end
        xlabel('Time (sec)');
        if params.vs_parameters.rms
            ytxt = strcat(dataUnits, ' (RMS)');
        else
            ytxt = dataUnits ;
        end
        ylabel(ytxt);


        legStr = {};
        plotTitle = plotLabel;
        
        if plotPlusMinus
            legend('average','plus-minus average');
        else
            if plotOverlay
                plotTitle = sprintf('Overlay');
                for k=1:numSubjects
                    legStr(k) = labels{k};
                end
            else
                if subject_idx > 0
                    legStr = labels{subject_idx};
                else
                    s = sprintf('Average (n=%d)', numSubjects);
                    legStr = {s};
                end        
            end
        end

        tt = legend(legStr);
        set(tt,'Interpreter','none','AutoUpdate','off','Location','NorthWest');
        
        % draw axes
        ax = axis;
        line_h1 = line([0 0],[ax(3) ax(4)]);
        set(line_h1, 'Color', [0 0 0]);
        vertLineVal = 0;
        if vertLineVal > ax(3) && vertLineVal < ax(4)
            line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
            set(line_h2, 'Color', [0 0 0]);
        end
        tt = title(plotTitle);
        
        set(tt,'Interpreter','none');
       

    end


end


function [params, xscale, yscale] = updateParametersDlg ( init_params, timeVec, bandwidth, xscale, yscale )

    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Processing Parameters','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 650 430]);

    params = init_params;
    % filter 
    
    FREQ_TITLE2=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.77 0.25 0.08],'String','Filter:        Hi-pass (Hz):','FontSize',12,'fontname','lucinda',...
        'BackGroundColor','white','foregroundcolor','black');  

    FREQ_TITLE3=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.45 0.77 0.25 0.08],'String','Low-pass (Hz):','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 
     
    FREQ_START_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.32 0.79 0.1 0.08],'String', params.beamformer_parameters.filter(1), 'FontSize', 12,...
          'BackGroundColor','white');

    FREQ_END_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.79 0.1 0.08],'String', params.beamformer_parameters.filter(2), 'FontSize', 12,...
              'BackGroundColor','white');    

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.76 0.80 0.15 0.1],'string','Use full range','backgroundcolor','white',...
        'fontsize',10,'foregroundcolor','blue','callback',@use_full_range_callback);

        function use_full_range_callback(~,~)        
            set(FREQ_START_EDIT,'String',params.beamformer_parameters.filter(1));
            set(FREQ_END_EDIT,'String',params.beamformer_parameters.filter(2));    
        end
    
    uicontrol('style','check','units','normalized','horizontalalignment','left','position',...
        [0.05 0.88 0.3 0.04],'String','Zero phase shift','FontSize',12,'value',params.beamformer_parameters.useReverseFilter,...
       'BackGroundColor','white','foregroundcolor','black','callback',@reversing_filter_Callback); 

    function reversing_filter_Callback(src,~)
        val = get(src,'value');
        if val
            params.beamformer_parameters.useReverseFilter = 1;
        else
            params.beamformer_parameters.useReverseFilter = 0;
        end
    end

    % baseline
    
    BASELINE_TITLE2=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.53 0.25 0.08],'String','Baseline:          Start (s):','FontSize',12,'fontname','lucinda',...
        'BackGroundColor','white','foregroundcolor','black');  

    BASELINE_TITLE3=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.5 0.53 0.1 0.08],'String','End (s):','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

    BASELINE_START_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.32 0.56 0.1 0.08],'String', params.beamformer_parameters.baseline(1), 'FontSize', 12,...
          'BackGroundColor','white');

    BASELINE_END_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.56 0.1 0.08],'String', params.beamformer_parameters.baseline(2), 'FontSize', 12,...
              'BackGroundColor','white');    

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.76 0.56 0.18 0.1],'string','Set to whole epoch','backgroundcolor','white',...
        'fontsize',10,'foregroundcolor','blue','callback',@use_all_callback);

        function use_all_callback(~,~)        
            set(BASELINE_START_EDIT,'String',timeVec(1));
            set(BASELINE_END_EDIT,'String',timeVec(end));    
        end
    
    % D. Cheyne - allow to turn on baseline here - already on if set in
    % data parameters...
    uicontrol('style','check','units','normalized','horizontalalignment','left','position',...
        [0.05 0.65 0.3 0.04],'String','Apply Baseline','FontSize',12,'value',params.beamformer_parameters.useBaselineWindow,...
       'BackGroundColor','white','foregroundcolor','black','callback',@apply_baseline_Callback); 

    function apply_baseline_Callback(src,~)
        val = get(src,'value');
        if val
            params.beamformer_parameters.useBaselineWindow = 1;
        else
            params.beamformer_parameters.useBaselineWindow = 0;
        end
        updateGUI;
    end
    
    function updateGUI
        if params.beamformer_parameters.useBaselineWindow
            set(BASELINE_TITLE2,'enable','on');
            set(BASELINE_TITLE3,'enable','on');
            set(BASELINE_START_EDIT,'enable','on');
            set(BASELINE_END_EDIT,'enable','on');
        else
            set(BASELINE_TITLE2,'enable','off');
            set(BASELINE_TITLE3,'enable','off');
            set(BASELINE_START_EDIT,'enable','off');
            set(BASELINE_END_EDIT,'enable','off');
        end
    end
   

   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.35 0.3 0.08],'String','Time Scale:          Min:','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 
        
   XMIN_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.27 0.37 0.1 0.08],'String', xscale(1), 'FontSize', 12,...
          'BackGroundColor','white');
   
   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.38 0.35 0.3 0.08],'String','Max:','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

   XMAX_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.45 0.37 0.1 0.08],'String', xscale(2), 'FontSize', 12,...
          'BackGroundColor','white');
   
   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.58 0.35 0.3 0.08],'String','seconds','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black');       
      
   
   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.25 0.3 0.08],'String','Amplitude Scale:  Min:','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 
        
   YMIN_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.27 0.27 0.1 0.08],'String', yscale(1), 'FontSize', 12,...
          'BackGroundColor','white');
   
   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.38 0.25 0.3 0.08],'String','Max:','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

   YMAX_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.45 0.27 0.1 0.08],'String', yscale(2), 'FontSize', 12,...
          'BackGroundColor','white');
    
   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.58 0.25 0.3 0.08],'String','nAm','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black');       
 

   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.1 0.3 0.08],'String','Error Bar Interval (s):','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 
        
   ERROR_BAR_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.27 0.12 0.1 0.08],'String', params.vs_parameters.errorBarInterval, 'FontSize', 12,...
          'BackGroundColor','white');
   
   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.38 0.1 0.3 0.08],'String','Width:','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

   ERROR_BAR_WIDTH_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.45 0.12 0.1 0.08],'String', params.vs_parameters.errorBarWidth, 'FontSize', 12,...
          'BackGroundColor','white');
    
   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.58 0.1 0.3 0.08],'String','points','FontSize',12,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

    
    % D. Cheyne - add back to version 3.2
     uicontrol('style','check','units','normalized','horizontalalignment','left','position',...
        [0.05 0.05 0.3 0.04],'String','Plot Amplitude Envelope','FontSize',12,'value',params.vs_parameters.plotAnalyticSignal,...
       'BackGroundColor','white','foregroundcolor','black','callback',@plot_Analytic_Callback); 
       
   uicontrol('style','check','units','normalized','horizontalalignment','left','position',...
        [0.35 0.05 0.35 0.04],'String','Subtract Average from Single Trials','FontSize',12,'value',params.vs_parameters.subtractAverage,...
       'BackGroundColor','white','foregroundcolor','black','callback',@subtract_Average_Callback); 
    
    function plot_Analytic_Callback(src,~)
        val = get(src,'value');
        if val
            params.vs_parameters.plotAnalyticSignal = 1;
        else
            params.vs_parameters.plotAnalyticSignal = 0;
        end
    end

    function subtract_Average_Callback(src,~)
        val = get(src,'value');
        if val
            params.vs_parameters.subtractAverage = 1;
        else
            params.vs_parameters.subtractAverage = 0;
        end
    end
      
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.1 0.15 0.1],'string','OK','BackgroundColor',[0.99,0.64,0.3],...
        'FontSize',13,'ForegroundColor','black','FontWeight','b','callback',@ok_callback);

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.28 0.15 0.1],'string','Cancel','BackgroundColor','white','FontSize',13,...
        'ForegroundColor','black','callback',@cancel_callback);

        function cancel_callback(~,~)
            
            params = []; 
            uiresume(gcbf); 
           
        end


    function ok_callback(~,~)
        
        f1 = str2double(get(FREQ_START_EDIT,'string'));
        f2 = str2double(get(FREQ_END_EDIT,'string'));
        
        if ( f1 > f2 || f1 < bandwidth(1) || f2 > bandwidth(2) )
            warndlg('Invalid frequency range ...');
            return;
        end    
 
        % ** issue warning here for out of original weights range...?      
        fprintf('setting frequency range to %g Hz to %g Hz...\n', f1, f2);
        
        params.beamformer_parameters.filter = [f1 f2];
        
        % update params
        string_value=get(BASELINE_START_EDIT,'String');
        b1=str2double(string_value);
        string_value=get(BASELINE_END_EDIT,'String');
        b2=str2double(string_value);
        if ( b1 > b2 || b1 < timeVec(1) || b2 > timeVec(end) )
            warndlg('Invalid baseline range ...');
            return;
        end    

        fprintf('setting baseline to %g s to %g s...\n',b1, b2);
        params.beamformer_parameters.baseline = [b1 b2];
      
        string_value=get(ERROR_BAR_EDIT,'String');
        params.vs_parameters.errorBarInterval = str2double(string_value);  
        string_value=get(ERROR_BAR_WIDTH_EDIT,'String');
        params.vs_parameters.errorBarWidth = str2double(string_value); 

        string_value=get(XMIN_EDIT,'String');
        xscale(1) = str2double(string_value);
        string_value=get(XMAX_EDIT,'String');
        xscale(2) = str2double(string_value);  
        
        string_value=get(YMIN_EDIT,'String');
        yscale(1) = str2double(string_value);
        string_value=get(YMAX_EDIT,'String');
        yscale(2) = str2double(string_value);  
             
       uiresume(gcf);
    end

    updateGUI
    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
end


