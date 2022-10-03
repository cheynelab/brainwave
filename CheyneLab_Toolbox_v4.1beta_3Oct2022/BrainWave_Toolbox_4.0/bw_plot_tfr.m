%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%       BW_PLOT_TFR
%
%   function bw_plot_tfr(TFR_DATA, plotTimeCourse)
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%   D. Cheyne, July, 2011
%  - replaces functionality in bw_make_vs_mex for computing TFR and
%  plotting it
%  - needs to return the TFR data for grand averaging ...
%
%  D. Cheyne, Sept, 2011 
%   modified to take all parameters in TFR_DATA and update plot - this will allow adding 
%   more options in future.  Can also take data from reading struct from
%   file
%
%  D. Cheyne, Nov 2011
%   major changes.  - plotMode replaced with plotType and plotUnits
%                   - TFR routine creates basic data types and saves power
%                   and mean and phase so that plotting routine can convert
%                   between them without recomputing the transform. Added
%                   new menus to do this and option to plot in dB 
%
%  D. Cheyne, Jan, 2012  - make plotTimeCourse passed option                   
%  D. Cheyne, May, 2012  - added option to plot error bars    
%
%               Nov 2012 - Vers 2.2 - major changes for plotting
%               multi-subject data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_plot_tfr(TFR_ARRAY, plotTimeCourse, groupLabel, filename)
    if ~exist('plotTimeCourse','var')
        plotTimeCourse = 0;
    end

    if ~exist('groupLabel','var')
        groupLabel = 'Group Average';
    end 
    
    if ~exist('filename','var')
        filename = 'Time-Frequency Plot';
    end 
    
    
    fh = figure('color','white', 'NumberTitle','off');
    if ispc
        movegui(fh,'center');
    end
    BRAINWAVE_MENU=uimenu('Label','Brainwave');

    uimenu(BRAINWAVE_MENU,'label','Plot parameters...','Callback',@change_baseline_callback);
    uimenu(BRAINWAVE_MENU,'label','Save TFR data...','separator','on','Callback',@save_tfr_data_callback);
    uimenu(BRAINWAVE_MENU,'label','Add TFR data...','Callback',@open_tfr_callback);
    SAVE_TIMECOURSE_MENU = uimenu(BRAINWAVE_MENU,'label','Save Time Course ...','Callback',@save_timecourse_callback);
    uimenu(BRAINWAVE_MENU,'label','Show Time Course','separator','on','Callback',@plot_time_callback);

    COLOR_MENU = uimenu(BRAINWAVE_MENU,'label','Change Plot Colour','enable','off', 'Callback',@plot_color_callback);
    
    COLORMAP_MENU = uimenu(BRAINWAVE_MENU,'label', 'Change Colormap','enable','on');
    COLOR_JET = uimenu(COLORMAP_MENU, 'label', 'Jet', 'checked','on','Callback',@plot_jet_callback);
    COLOR_PARULA = uimenu(COLORMAP_MENU, 'label', 'Parula', 'Callback',@plot_parula_callback);
    COLOR_GRAY = uimenu(COLORMAP_MENU, 'label', 'Gray', 'Callback',@plot_gray_callback);
    COLOR_HOT = uimenu(COLORMAP_MENU, 'label', 'Hot', 'Callback',@plot_hot_callback);
    COLOR_COOL = uimenu(COLORMAP_MENU, 'label', 'Cool', 'Callback',@plot_cool_callback);
    
    ERROR_BAR_MENU = uimenu(BRAINWAVE_MENU,'label','Show Standard Error', 'enable','off');

    uimenu(BRAINWAVE_MENU,'label','Show Values...','separator','on','Callback',@data_window_callback);

    ERROR_NONE = uimenu(ERROR_BAR_MENU,'label','None','checked','on','Callback',@plot_none_callback);
    ERROR_SHADED = uimenu(ERROR_BAR_MENU,'label','Shaded','Callback',@plot_shaded_callback);
    ERROR_BARS = uimenu(ERROR_BAR_MENU,'label','Bars','Callback',@plot_bars_callback);
    
    PLOT_MENU = uimenu(BRAINWAVE_MENU,'label','Plot','separator','on');
    PLOT_TOTAL_POWER_ITEM=uimenu(PLOT_MENU,'label','Total Power','Callback',@plot_totalpower_callback);
    PLOT_SUBTRACTION_ITEM=uimenu(PLOT_MENU,'label','Power - Average','Callback',@plot_subtraction_callback);
    PLOT_AVERAGE_ITEM=uimenu(PLOT_MENU,'label','Average','Callback',@plot_average_callback);
    PLOT_PLF_ITEM = uimenu(PLOT_MENU,'label','Phase-locking Factor','Callback',@plot_PLF_callback);
    
    UNITS_MENU = uimenu(BRAINWAVE_MENU,'label','Units');
    PLOT_POWER_ITEM = uimenu(UNITS_MENU,'label','Power','Callback',@plot_power_callback);
    PLOT_DB_ITEM = uimenu(UNITS_MENU,'label','Power dB','Callback',@plot_dB_callback);
    PLOT_PERCENT_ITEM = uimenu(UNITS_MENU,'label','Percent change','Callback',@plot_percent_callback);
 
    DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');

     
    numSubjects = 1;
   
    subject_idx = 1;
    timeCourse = [];
    plotOverlay = 0;
    
    plotColor = [0 0 1];   
    ave_group = [];
    labels = {};
    
    dataUnits = TFR_ARRAY{1}.dataUnits;
    plotType = TFR_ARRAY{1}.plotType;   % 0 = total power, 1 = power-average, 2 = average, 3 = PLF
    plotUnits = TFR_ARRAY{1}.plotUnits;   % 0 =  power, 1 = dB, 2 = percent
    baseline = TFR_ARRAY{1}.baseline;
    timeVec = TFR_ARRAY{1}.timeVec;
    freqVec = TFR_ARRAY{1}.freqVec;
              
    freqRange = freqVec;  % freqRange can be changed in plot
    xlimits = [timeVec(1) timeVec(end)];  % timeRange can be changed in plot
   
    initialize_subjects;
   
    function initialize_subjects 
        
       [~, numSubjects] = size(TFR_ARRAY);
       if numSubjects == 1
            set(ERROR_BAR_MENU,'enable','off');
            subject_idx = 1;
        else
            subject_idx = 0;
        end  

        labels = {};

        % rebuild data menu
        if exist('DATA_SOURCE_MENU','var')
            delete(DATA_SOURCE_MENU);
            clear DATA_SOURCE_MENU;
        end
        
        DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');
        
        for k=1:numSubjects
            labels{k} = cellstr(TFR_ARRAY{k}.label); 
        end
        
        for k=1:numSubjects
            uimenu(DATA_SOURCE_MENU,'Label',char(labels{k}),'Callback',@data_menu_callback);               
        end
        
        if (numSubjects > 1)

            uimenu(DATA_SOURCE_MENU,'Label',groupLabel,'Checked','on',...
                'separator','on','Callback',@data_menu_callback);
                        
            s = sprintf('All Subjects (overlay)');
            uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','off','enable','off',...
                'separator','on','Callback',@data_menu_callback);    
        else
             % check single menu
            set(get(DATA_SOURCE_MENU,'Children'),'Checked','on');
        end
        
    end
       
        % ** version 3.6 - add option to load another subject / condition
    function open_tfr_callback(~,~)
        [name,path,~] = uigetfile('*.mat','Select a TFR .mat file:');
        if isequal(name,0)
            return;
        end
        infile = fullfile(path,name);
       
        t = load(infile);
        
        % read old format...(needs testing)
        if ~isfield(t,'TFR_ARRAY')
            fprintf('This does not appear to be a BrainWave VS data file\n');
            return;
        end
        
        % check for same time base - use original VS for params?
        
        t_timeVec = t.TFR_ARRAY{1}.timeVec;
        if any(t_timeVec~=timeVec)
            beep();
            fprintf('TFR plots have different time bases\n');
            return;
        end
             
        
        t_freqVec = t.TFR_ARRAY{1}.freqVec;
        if any(t_freqVec~=freqVec)
            beep();
            fprintf('VS plots have different frequency ranges\n');
            return;
        end
        
                
        for k=1:size(t.TFR_ARRAY,2)
            TFR_ARRAY{numSubjects+k} = t.TFR_ARRAY{k};  
        end

        initialize_subjects;  
        updatePlot;        
        
     end    
    
    function data_menu_callback(src,~)      
        subject_idx = get(src,'position');
        
        plotOverlay = 0;
        % if subject_idx == 0 plot average
        if subject_idx == numSubjects + 1
            subject_idx = 0;
        end
        
        if subject_idx == numSubjects + 2
            subject_idx = 0;
            plotOverlay = 1;
        end
        % uncheck all menus
        set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');
        
        set(src,'Checked','on');
        
        updatePlot;
        
    end
        
 
      
    s = sprintf('Power (%s^2)', dataUnits);
    set(PLOT_POWER_ITEM,'label',s);

    if (plotUnits == 0)
        set(PLOT_POWER_ITEM,'Checked','on');
    elseif (plotUnits == 1)
        set(PLOT_DB_ITEM,'Checked','on');
    elseif (plotUnits == 2)
        set(PLOT_PERCENT_ITEM,'Checked','on');
    end
 
    if (plotType == 0)
        set(PLOT_TOTAL_POWER_ITEM,'Checked','on');
    elseif (plotType == 1)
        set(PLOT_SUBTRACTION_ITEM,'Checked','on');
    elseif (plotType == 2)
        set(PLOT_AVERAGE_ITEM,'Checked','on');
    elseif (plotType == 3)
        set(PLOT_PLF_ITEM,'Checked','on');
    end    
    
    if (plotType == 3)
        set(PLOT_POWER_ITEM,'enable','off');
        set(PLOT_DB_ITEM,'enable','off');
        set(PLOT_PERCENT_ITEM,'enable','off');
    end
    
    set(SAVE_TIMECOURSE_MENU,'enable','off');
    
    % can be added to defaults
    errorBarMode = 0;
    errorBarInterval = 0.1;
    errorBarWidth = errorBarInterval * 0.3;
    
    % global pointer to currently displayed data...
    tf_data = zeros(length(freqVec),length(timeVec));
    fdata = zeros(numSubjects, length(timeVec));
    
    plotColormap = jet;
    
    updatePlot;
    
   function data_window_callback(~,~)  
        plotDataWindow (timeVec, labels, fdata);
   end

   function change_baseline_callback(~,~)   
       pparams.baseline = baseline;
       pparams.freqRange = freqRange;
       pparams.errorBarInterval = errorBarInterval;
       pparams.errorBarWidth = errorBarWidth;
       pparams.timeVec = timeVec;
       pparams.freqVec = freqVec;
       
       [newparams, xlimits] = updateParamsDlg(pparams, xlimits);
       
       baseline = newparams.baseline;
       freqRange = newparams.freqRange;
       errorBarInterval = newparams.errorBarInterval;
       errorBarWidth = newparams.errorBarWidth;
       
       updatePlot;
   end

   function plot_time_callback(src,~) 
        plotTimeCourse = ~plotTimeCourse;
        if plotTimeCourse
            set(src,'Checked','on');
            set(SAVE_TIMECOURSE_MENU,'enable','on');
            set(COLOR_MENU,'enable','on');
            set(COLORMAP_MENU,'enable','off');
            set(ERROR_BAR_MENU,'enable','on');
            if numSubjects > 1
                tt = get(DATA_SOURCE_MENU,'Children'); 
                set(tt(1),'enable','on');
            end
        else
            set(src,'Checked','off');
            set(SAVE_TIMECOURSE_MENU,'enable','off');
            set(COLOR_MENU, 'enable','off');
            set(COLORMAP_MENU,'enable','on');
            set(ERROR_BAR_MENU,'enable','off');    
            if numSubjects > 1
                tt = get(DATA_SOURCE_MENU,'Children');              
                set(tt(1),'enable','off', 'checked','off');
            end
        end
        
        updatePlot;
   end

    function plot_none_callback(src,~) 
        errorBarMode = 0;
        enable_error_menus('off');
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_bars_callback(src,~) 
        errorBarMode = 1;
        enable_error_menus('off');
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_shaded_callback(src,~) 
        errorBarMode = 2;
        enable_error_menus('off');
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_color_callback(~,~) 
          newColor = uisetcolor;
          if size(newColor,2) == 3
              plotColor = newColor;
          end
          updatePlot;       
    end

    function enable_error_menus(str)
        set(ERROR_SHADED,'Checked',str);
        set(ERROR_NONE,'Checked',str);
        set(ERROR_BARS,'Checked',str);            
    end
 
    % Colormap
        
    function plot_jet_callback(src,~)
        plotColormap = jet;    
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function plot_parula_callback(src,~)
        plotColormap = parula;
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function plot_gray_callback(src,~)
        plotColormap = gray;
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function plot_hot_callback(src,~)
        plotColormap = hot;
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function plot_cool_callback(src,~)
        plotColormap = cool;
        enable_colormap_menus('off');
        set(src, 'Checked', 'on');
        updatePlot;
    end

    function enable_colormap_menus(str)
        set(COLOR_PARULA,'Checked',str);
        set(COLOR_JET,'Checked',str);
        set(COLOR_GRAY,'Checked',str);            
        set(COLOR_HOT,'Checked',str);            
        set(COLOR_COOL,'Checked',str);            
    end

    % type
    
    function plot_totalpower_callback(src,~) 
        plotType = 0;
        enable_type_menus('off');
        set(src,'Checked','on');
        updatePlot;

    end
    function plot_subtraction_callback(src,~)
        plotType = 1;
        enable_type_menus('off');
        set(src,'Checked','on');
 
        updatePlot;
    end
    function plot_average_callback(src,~)
        plotType = 2;
        enable_type_menus('off');
        set(src,'Checked','on');
        updatePlot;
    end
    function plot_PLF_callback(src,~)
        plotType = 3;
        enable_type_menus('off');       
        set(src,'Checked','on');
        updatePlot;
    end

    function enable_type_menus(str)
        set(PLOT_TOTAL_POWER_ITEM,'Checked',str);
        set(PLOT_SUBTRACTION_ITEM,'Checked',str);
        set(PLOT_AVERAGE_ITEM,'Checked',str);            
        set(PLOT_PLF_ITEM,'Checked',str);            
    end

    % units 

    function plot_power_callback(src,~) 
        plotUnits = 0;        
        enable_units_menus('off');       
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_dB_callback(src,~)
        plotUnits = 1;        
        enable_units_menus('off');       
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_percent_callback(src,~)
        plotUnits = 2;        
        enable_units_menus('off');       
        set(src,'Checked','on');
        updatePlot;
    end

    function enable_units_menus(str)
        set(PLOT_POWER_ITEM,'Checked',str);
        set(PLOT_PERCENT_ITEM,'Checked',str);
        set(PLOT_DB_ITEM,'Checked',str);            
    end

    function save_tfr_data_callback(~,~)      
        
        [name,path,~] = uiputfile('*.mat','Select Name for TFR file:');
        if isequal(name,0)
            return;
        end
        outFile = fullfile(path,name);
                  
        % update to save currently displayed image
        
        % save currently displayed image
        % added save file name for plot titles 
        plotName = name(1:end-4);
        set(fh,'Name',plotName);
        
        % check if has single trial data - use option to save large .mat files
        if isfield(TFR_ARRAY,'TRIAL_MAGNITUDE')
            fprintf('Saving TFR data to file %s using -v7.3 switch...\n', outFile);
            save(outFile,'TFR_ARRAY','filename','-v7.3');            
        else
            save(outFile,'TFR_ARRAY', 'filename');            
            fprintf('Saving TFR data to file %s ...\n', outFile);
        end

    end


    function save_timecourse_callback(~,~)      
        if isempty(timeCourse)
            return;
        end
        
        [name,path,~] = uiputfile({'*.txt','ASCII file (*.txt)';},...
                    'Export time course data to:');
        if isequal(name,0)
            return;
        end

        filename = fullfile(path,name);
        fprintf('Saving time course to file %s\n', filename);
        fid = fopen(filename,'w');
        for k=1:size(timeCourse,1)
            fprintf(fid, '%.4f', timeVec(k) );
            fprintf(fid, '\t%8.4f', timeCourse(k) );
            fprintf(fid,'\n');
        end

        fclose(fid);

    end

    function updatePlot
        
        set(fh,'Name',filename);
  
        % choose data to plotfunction 
        % we also do preprocessing and conversions here so 
        % that group error is correct etc.
      
        tf_data = zeros(length(freqRange),length(timeVec));   
        
        if (subject_idx >  0)
           
            if plotType == 0
                tf_data = TFR_ARRAY{subject_idx}.TFR;
            elseif plotType == 1
                tf_data = TFR_ARRAY{subject_idx}.TFR - TFR_ARRAY{subject_idx}.MEAN;
            elseif plotType == 2
                tf_data = TFR_ARRAY{subject_idx}.MEAN;
            elseif plotType == 3
                tf_data = TFR_ARRAY{subject_idx}.PLF;
            end
            
            % truncate to freq range
            [~, idx] = ismember(freqRange, freqVec);
            tf_data = tf_data(idx,:);      
            
            if plotType ~= 3
                tf_data = transformData(tf_data);
            end
            
            % time course is mean over frequency
            % no std err in this case...
            timeCourse = mean(tf_data)';

            plotLabel = TFR_ARRAY{subject_idx}.plotLabel;
            
        else
        
            % generate average TFR 
            ave_data = zeros(length(freqRange),length(timeVec));
           
            for k=1:numSubjects
                
               if plotType == 0
                    tf_data = TFR_ARRAY{k}.TFR;
                elseif plotType == 1
                    tf_data = (TFR_ARRAY{k}.TFR - TFR_ARRAY{k}.MEAN );
                elseif plotType == 2
                    tf_data = TFR_ARRAY{k}.MEAN;
                elseif plotType == 3
                    tf_data = TFR_ARRAY{k}.PLF;
               end
               
               % truncate to freq range
               [~, idx] = ismember(freqRange, freqVec);   
               tf_data = tf_data(idx,:);

               if plotType ~= 3
                    tf_data = transformData(tf_data);
                end
                
                % need time course collapsed over frequency for each subj
                fdata(k,:) = mean(tf_data)';
                
                % average the time-frequency data
                ave_data = ave_data + tf_data;
            end
            
            tf_data = ave_data ./ numSubjects;
                       
            % compute mean image and time course + error           
            timeCourse = mean(tf_data)';
            
            stderr = std(fdata) ./sqrt(numSubjects);
                      
            plotLabel = sprintf('%s - %g to %g Hz', groupLabel, freqRange(1), freqRange(end)); 
            
        end
          
        if (plotType == 3)
            set(PLOT_POWER_ITEM,'enable','off');
            set(PLOT_DB_ITEM,'enable','off');
            set(PLOT_PERCENT_ITEM,'enable','off');
        else
            set(PLOT_POWER_ITEM,'enable','on');
            set(PLOT_DB_ITEM,'enable','on');
            set(PLOT_PERCENT_ITEM,'enable','on');
        end    
        
        % April 2012 - exclude boundaries from autoscaling 
        edgePts = ceil(0.1 * length(timeVec));
        trunc_data = tf_data(:,edgePts:end-edgePts);
       
        
        maxVal = max(max(abs(trunc_data)));
         
        if plotType == 3
            minVal = 0.0;       % if plotting PLF no negative range
        else
            minVal = -maxVal;
        end
        
        if plotType == 3
            unitLabel = sprintf('Phase-locking Factor');
        else
            if (plotUnits == 0)
                unitLabel = sprintf('Power (%s^2)',dataUnits);
            elseif (plotUnits == 1)
                unitLabel = sprintf('Power (dB)');
            elseif (plotUnits == 2)
                unitLabel = sprintf('Percent Change');
            end
        end
  
        if plotTimeCourse
            if subject_idx == 0
               % plot time course of group data with error bars
               if plotOverlay
                    %  fdata contains individual timecourses...
                    plot(timeVec, fdata);      
               else
                    if errorBarMode == 0                           
                        plot(timeVec, timeCourse, 'color',plotColor);
                    elseif errorBarMode == 1
                        % create std error bars every errorBarInterval seconds
                        dwel = double(timeVec(2) - timeVec(1));
                        err_step = round(errorBarInterval / dwel);

                        % zero values between steps
                        stderr( find( mod( 1:length(stderr), err_step ) > 0 ) ) = NaN;   
                        errorbar(timeVec, timeCourse, stderr, 'color',plotColor,'CapSize',errorBarWidth);    
 
                    elseif errorBarMode == 2
                        uplim=timeCourse'+stderr;
                        lolim=timeCourse'-stderr;
                        filledValue=[uplim fliplr(lolim)]; %depends on column type (needs to plot forward, then back to start before fill/patch)
                        timeValue=[timeVec; flipud(timeVec)]; 

                        h1=fill(timeValue,filledValue,plotColor);
                        set(h1,'FaceAlpha',0.5,'EdgeAlpha',0.5,'EdgeColor',plotColor);
                        hold on
                        plot(timeVec,timeCourse, 'color',plotColor);
                        hold off
                    end
                end
                
            else 
                plot(timeVec, timeCourse, 'color',plotColor);      
            end
        
            legStr = {};
            plotTitle = plotLabel;

            if plotOverlay 
                plotTitle = sprintf('Overlay (All Subjects)');
                for k=1:numSubjects
                    legStr(k) = labels{k};
                end
            else
                if subject_idx > 0
                    legStr = labels{subject_idx};
                else
                    legStr = {'Average'};
                end      
            end
            
            tt = legend(legStr);
            set(tt,'Interpreter','none','AutoUpdate','off');

            xlim(xlimits);
            ylim([-maxVal maxVal]);     % autoscale
            
            xlabel('Time (s) ');
            ylabel(unitLabel);
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
            
        else
            imagesc(timeVec, freqRange, tf_data, [minVal maxVal] );
            colormap(plotColormap);
            axis xy;  
            h = colorbar;
            
            xlim(xlimits);

            xlabel('Time (s) ');
            ylabel('Freq (Hz)');

            set(get(h,'YLabel'),'String',unitLabel);

            tt = title(plotLabel);
            set(tt,'Interpreter','none');
       
        end
        
        clear trunc_data
        
    end

    function transformed_data = transformData( data )
           
        % remove baseline power and convert units
        
        tidx = find(timeVec >= baseline(1) & timeVec <= baseline(2));

        for jj=1:size(data,1)
            t = data(jj,:);
            b = mean(t(tidx));

            if plotUnits == 0  
                % baseline correct only
                transformed_data(jj,:) = data(jj,:)-b;                                   
            elseif plotUnits == 1  
                % convert to dB scale  
                ratio = data(jj,:)/b;
                transformed_data(jj,:) = 10 * log10(ratio);
            elseif plotUnits == 2  
                % convert to percent change
                transformed_data(jj,:) = data(jj,:)-b;        
                transformed_data(jj,:) = ( transformed_data(jj,:)/b ) * 100.0;
            end
            
        end
    end

end       

function [newparams, xrange] = updateParamsDlg ( pparams, xrange )

    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','TFR Processing Parameters','numbertitle','off','menubar','none','position',[400 (scrnsizes(1,4)-400) 650 400]);

    newparams = pparams;

    uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.77 0.25 0.1],'String','Freq Range:        Min (Hz):','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black');  

    uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.45 0.77 0.25 0.1],'String','Max (Hz):','FontSize',12,...
       'BackGroundColor','white','foregroundcolor','black'); 
     
    FREQ_START_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.32 0.80 0.1 0.1],'String', pparams.freqRange(1), 'FontSize', 12,...
          'BackGroundColor','white');

    FREQ_END_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.80 0.1 0.1],'String', pparams.freqRange(end), 'FontSize', 12,...
              'BackGroundColor','white');    

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.76 0.80 0.15 0.1],'string','Use full range','backgroundcolor','white',...
        'fontsize',10,'foregroundcolor','blue','callback',@use_full_freq_range_callback);

        function use_full_freq_range_callback(src,evt)        
            set(FREQ_START_EDIT,'String',pparams.freqVec(1));
            set(FREQ_END_EDIT,'String',pparams.freqVec(end));    
        end
    
   uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.6 0.25 0.1],'String','Time Range:              Min (s):','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black');  

    uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.45 0.6 0.25 0.1],'String','Max (s):','FontSize',12,...
       'BackGroundColor','white','foregroundcolor','black'); 
     
    TIME_START_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.32 0.63 0.1 0.1],'String', xrange(1), 'FontSize', 12,...
          'BackGroundColor','white');

    TIME_END_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.63 0.1 0.1],'String', xrange(end), 'FontSize', 12,...
              'BackGroundColor','white');              
          
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.76 0.63 0.15 0.1],'string','Use full range','backgroundcolor','white',...
        'fontsize',10,'foregroundcolor','blue','callback',@use_full_time_range_callback);

        function use_full_time_range_callback(src,evt)        
            set(TIME_START_EDIT,'String',pparams.timeVec(1));
            set(TIME_END_EDIT,'String',pparams.timeVec(end));    
        end
    
    % baseline
    
    BASELINE_TITLE2=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.45 0.25 0.1],'String','Baseline:                  Start (s):','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black');  

    BASELINE_TITLE3=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.5 0.45 0.1 0.1],'String','End (s):','FontSize',12,...
       'BackGroundColor','white','foregroundcolor','black'); 

    BASELINE_START_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.32 0.48 0.1 0.1],'String', pparams.baseline(1), 'FontSize', 12,...
          'BackGroundColor','white');

    BASELINE_END_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.48 0.1 0.1],'String', pparams.baseline(2), 'FontSize', 12,...
              'BackGroundColor','white');    

    USE_ALL_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
        [0.76 0.48 0.18 0.1],'string','Set to whole epoch','backgroundcolor','white',...
        'fontsize',10,'foregroundcolor','blue','callback',@use_all_callback);

        function use_all_callback(src,evt)        
            baseline = [pparams.timeVec(1) pparams.timeVec(end)];
            set(BASELINE_START_EDIT,'String',baseline(1));
            set(BASELINE_END_EDIT,'String',baseline(2));    
        end
    

    uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.3 0.3 0.1],'String','Error Bar Step (s)','FontSize',12,...
       'BackGroundColor','white','foregroundcolor','black'); 

    ERROR_BAR_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.25 0.31 0.1 0.12],'String', pparams.errorBarInterval, 'FontSize', 12,...
          'BackGroundColor','white');

    uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.4 0.3 0.3 0.1],'String','Error Bar Width (s)','FontSize',12,...
       'BackGroundColor','white','foregroundcolor','black'); 

    ERROR_WIDTH_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.31 0.1 0.12],'String', pparams.errorBarWidth, 'FontSize', 12,...
          'BackGroundColor','white');
      
    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.1 0.2 0.12],'string','OK','BackgroundColor',[0.99,0.64,0.3],...
        'FontSize',13,'ForegroundColor','black','FontWeight','b','callback',@ok_callback);

    cancel=uicontrol('style','pushbutton','units','normalized','position',...
        [0.4 0.1 0.2 0.12],'string','Cancel','BackgroundColor','white','FontSize',13,...
        'ForegroundColor','black','callback',@cancel_callback);

        function cancel_callback(src,evt)
            uiresume(gcbf); 
        end
    
    function ok_callback(src,evt)
        
        f1 = str2num(get(FREQ_START_EDIT,'string'));
        f2 = str2num(get(FREQ_END_EDIT,'string'));
        
        if ( f1 > f2 || f1 < pparams.freqVec(1) || f2 > pparams.freqVec(end) )
            warndlg('Bad frequency range ...');
            return;
        end
        
        % find closest values in freqVec
        tmp = abs(f1-pparams.freqVec);
        [val minidx] = min(tmp);
        f1 = pparams.freqVec(minidx);
        
        tmp = abs(f2-pparams.freqVec);
        [val maxidx] = min(tmp);  
        f2 = pparams.freqVec(maxidx);
        
        fprintf('*** setting frequency range to %g Hz to %g Hz ***\n', f1, f2);
        newparams.freqRange = pparams.freqVec(minidx:maxidx);
        
        f1 = str2num(get(TIME_START_EDIT,'string'));
        f2 = str2num(get(TIME_END_EDIT,'string'));
        
        xrange = [f1 f2];
        fprintf('*** setting time range to %g s to %g s ***\n', f1, f2);        
     
        string_value=get(BASELINE_START_EDIT,'String');
        baseline(1)=str2double(string_value);
        string_value=get(BASELINE_END_EDIT,'String');
        baseline(2)=str2double(string_value);  

       if (baseline(1) < pparams.timeVec(1) || baseline(2) > pparams.timeVec(end))
            warndlg('Bad baseline range ...\n');
            return;
       end
       newparams.baseline = baseline;
        
       string_value=get(ERROR_BAR_EDIT,'String');
       newparams.errorBarInterval=str2double(string_value);  

       string_value=get(ERROR_WIDTH_EDIT,'String');
       newparams.errorBarWidth=str2double(string_value);  
       
        uiresume(gcf);
    end


    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
end



function plotDataWindow (timeVec, labels, fdata )

    latency = 0.0;
    
    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','TFR Data','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 300 400]);
       
    
    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.25 0.05 0.5 0.08],'string','Close','BackgroundColor',[0.99,0.64,0.3],...
        'FontSize',13,'ForegroundColor','black','FontWeight','b','callback',@ok_callback);


   uicontrol('style','text','units','normalized','position',...
          [0.08 0.82 0.5 0.1],'String', 'Enter latency (s)', 'FontSize', 12,...
          'BackGroundColor','white');

   s = sprintf('%.4f', latency);
   LATENCY_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.85 0.25 0.08],'String', s, 'FontSize', 12,...
          'BackGroundColor','white', 'callback',@latency_callback);
    
    DATA_WINDOW=uicontrol('style','listbox','units','normalized','position',...
    [0.08 0.2 0.8 0.6],'string','','fontsize',12,'max',10000,'background','white');

    update;

    function ok_callback(src,evt)
        delete(fg);
    end

    function latency_callback(src,evt)
       s = get(src,'string');
       latency = str2num(s);
       update;
    end

    function update
       if latency < timeVec(1) || latency > timeVec(end)
           data = '*** exceeds time range ***';
       else
           
           dwel = timeVec(2) - timeVec(1);
           sample = round( (latency - timeVec(1)) / dwel) + 1;
           t = fdata(:,sample);
           for j=1:size(t,1)
               % to include dsName in list - but can't cut and paste...
               % s = sprintf('%s %12.4f', char(labels{j}), t(j) );
               % data(j,:) = cellstr(s); 
               data(j,:) = cellstr(sprintf('%0.3f', t(j) ));
           end
       end
      set(DATA_WINDOW,'string',data);     
    end   

end





