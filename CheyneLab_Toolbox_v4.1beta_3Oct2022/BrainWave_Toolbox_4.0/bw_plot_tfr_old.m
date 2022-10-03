function bw_plot_tfr(TFR_DATA, plotTimeCourse)
%       BW_PLOT_TFR
%
%   function bw_plot_tfr(TFR_DATA, plotTimeCourse)
%%
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

    if ~exist('plotTimeCourse','var')
        plotTimeCourse = 0;
    end
        
    fh = figure('color','white');

    BRAINWAVE_MENU=uimenu('Label','Brainwave');

    SAVE_TFR_MENU = uimenu(BRAINWAVE_MENU,'label','Save TFR data...','Callback',@save_tfr_data_callback);
    BASELINE_MENU = uimenu(BRAINWAVE_MENU,'label','Change Baseline...','separator','on','Callback',@change_baseline_callback);
    TIME_COURSE_MENU = uimenu(BRAINWAVE_MENU,'label','Show Time Course','Callback',@plot_time_callback);
    ERROR_BAR_MENU = uimenu(BRAINWAVE_MENU,'label','Show Error Bars','Callback',@plot_error_callback);
    
    PLOT_MENU = uimenu(BRAINWAVE_MENU,'label','Plot','separator','on');
    PLOT_TOTAL_POWER_ITEM=uimenu(PLOT_MENU,'label','Total Power','Callback',@plot_totalpower_callback);
    PLOT_SUBTRACTION_ITEM=uimenu(PLOT_MENU,'label','Power - Average','Callback',@plot_subtraction_callback);
    PLOT_AVERAGE_ITEM=uimenu(PLOT_MENU,'label','Average','Callback',@plot_average_callback);
    PLOT_PLF_ITEM = uimenu(PLOT_MENU,'label','Phase-locking Factor','Callback',@plot_PLF_callback);
    
    UNITS_MENU = uimenu(BRAINWAVE_MENU,'label','Units');
    PLOT_POWER_ITEM = uimenu(UNITS_MENU,'label','Power','Callback',@plot_power_callback);
    PLOT_DB_ITEM = uimenu(UNITS_MENU,'label','Power dB','Callback',@plot_dB_callback);
    PLOT_PERCENT_ITEM = uimenu(UNITS_MENU,'label','Percent change','Callback',@plot_percent_callback);
 
    
    % check for obsolete fields - only when reading MAT-file
 
    
    dsName = TFR_DATA.dsName;
    plotLabel = TFR_DATA.plotLabel;
    TFR = TFR_DATA.TFR;   
    PLF = TFR_DATA.PLF;
    MEAN = TFR_DATA.MEAN;
    timeVec = TFR_DATA.timeVec;
    freqVec = TFR_DATA.freqVec;
    dataUnits = TFR_DATA.dataUnits;
    plotType = TFR_DATA.plotType;   % 0 = total power, 1 = power-average, 2 = average, 3 = PLF
    plotUnits = TFR_DATA.plotUnits;   % 0 =  power, 1 = dB, 2 = percent
    baseline = TFR_DATA.baseline;
   
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

    if ~isfield(TFR_DATA, 'TimeCourseError')
        set(ERROR_BAR_MENU,'enable','off');
    end 
    
    % can be added to defaults ????
    plotError = 0;
    errorBarInterval = 0.1;
    
    updatePlot;
    
    function change_baseline_callback(src,evt)   
        
        new_baseline = updateParamsDlg(baseline, timeVec);
        
        if (new_baseline(1) < timeVec(1) || new_baseline(2) > timeVec(end))
            fprintf('WARNING: baseline values are out of data range... changes ignored!\n');
        else
            baseline = new_baseline;
            updatePlot;
        end
        
    end

   function plot_time_callback(src,evt) 
        plotTimeCourse = ~plotTimeCourse;
        if plotTimeCourse
            set(src,'Checked','on');
        else
            set(src,'Checked','off');
        end        
        
        updatePlot;
   end

   function plot_error_callback(src,evt) 
        plotError = ~plotError;
        if plotError
            set(src,'Checked','on');
        else
            set(src,'Checked','off');
        end        
        
        updatePlot;
   end


    % type
    
    function plot_totalpower_callback(src,evt) 
        plotType = 0;
        set(PLOT_SUBTRACTION_ITEM,'Checked','off');        
        set(PLOT_AVERAGE_ITEM,'Checked','off');        
        set(PLOT_PLF_ITEM,'Checked','off');
        set(src,'Checked','on');
        updatePlot;

    end
    function plot_subtraction_callback(src,evt)
        plotType = 1;
        set(PLOT_TOTAL_POWER_ITEM,'Checked','off');             
        set(PLOT_AVERAGE_ITEM,'Checked','off');        
        set(PLOT_PLF_ITEM,'Checked','off');
        set(src,'Checked','on');
 
        updatePlot;
    end
    function plot_average_callback(src,evt)
        plotType = 2;
        set(PLOT_TOTAL_POWER_ITEM,'Checked','off');             
        set(PLOT_SUBTRACTION_ITEM,'Checked','off');        
        set(PLOT_PLF_ITEM,'Checked','off');
        set(src,'Checked','on');
 
        updatePlot;
    end
    function plot_PLF_callback(src,evt)
        plotType = 3;
        set(PLOT_TOTAL_POWER_ITEM,'Checked','off');        
        set(PLOT_SUBTRACTION_ITEM,'Checked','off');        
        set(PLOT_AVERAGE_ITEM,'Checked','off');        
        set(src,'Checked','on');
        updatePlot;
    end

    % units 

    function plot_power_callback(src,evt) 
        plotUnits = 0;        
        set(PLOT_POWER_ITEM,'Checked','off');
        set(PLOT_PERCENT_ITEM,'Checked','off');
        set(PLOT_DB_ITEM,'Checked','off');
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_dB_callback(src,evt)
        plotUnits = 1;        
        set(PLOT_POWER_ITEM,'Checked','off');
        set(PLOT_PERCENT_ITEM,'Checked','off');
        set(PLOT_DB_ITEM,'Checked','off');
        set(src,'Checked','on');
        updatePlot;
    end

    function plot_percent_callback(src,evt)
        plotUnits = 2;        
        set(PLOT_POWER_ITEM,'Checked','off');
        set(PLOT_PERCENT_ITEM,'Checked','off');
        set(PLOT_DB_ITEM,'Checked','off');
        set(src,'Checked','on');
        updatePlot;
    end

    function save_tfr_data_callback(src,evt)      
        [name,path,FilterIndex] = uiputfile('*.mat','Select Name for TFR file:');
        if isequal(name,0)
            return;
        end
        outFile = fullfile(path,name);
        
        fprintf('Saving TFR data to file %s\n', outFile);
                  
        data.dsName = dsName;
        data.timeVec = timeVec;
        data.freqVec = freqVec;
        data.dataUnits = dataUnits;
        data.plotLabel = plotLabel;
        data.TFR = TFR;
        data.PLF = PLF;
        data.MEAN = MEAN;
        data.baseline = baseline;
        data.plotType = plotType;
        data.plotUnits = plotUnits;
        
        save(outFile,'data');            
        clear data;

    end

    function updatePlot
        set(fh,'Name','Time-Frequency Plot');
        
        if plotType == 0
            tf_data = TFR;
        elseif plotType == 1
            tf_data = TFR-MEAN;
        elseif plotType == 2
            tf_data = MEAN;
        elseif plotType == 3
            tf_data = PLF;
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
 
        
        if plotType ~= 3     
            % remove baseline power
            tidx = find(timeVec >= baseline(1) & timeVec <= baseline(2));
            for jj=1:length(freqVec)
                t = tf_data(jj,:);
                b = mean(t(tidx));
                
                if plotUnits == 0  
                    % baseline correct only
                    tf_data(jj,:) = tf_data(jj,:)-b;                                   
                elseif plotUnits == 1  
                    % convert to dB scale  
                    ratio = tf_data(jj,:)/b;
                    tf_data(jj,:) = 10 * log10(ratio);
                elseif plotUnits == 2  
                    % convert to percent change
                    tf_data(jj,:) = tf_data(jj,:)-b;        
                    tf_data(jj,:) = ( tf_data(jj,:)/b ) * 100.0;
                end
            end
        end
        
        % April 2012 - exclude boundaries from autoscaling 
        edgePts = ceil(0.1 * length(timeVec));
        trunc_data = tf_data(:,edgePts:end-edgePts);
       
        
        maxVal = max(max(abs(trunc_data)));
        
        if (plotType == 3)
            minVal = 0.0;
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
                      
            if plotError            
                
                timeCourse = TFR_DATA.TimeCourse; %% COMMENTED OUT BY
                %CECILIA
                %timeCourse = mean(tf_data); %% ADDED BY CECILIA 
                stderr = TFR_DATA.TimeCourseError;    
                
                % create std error bars every errorBarInterval seconds
                dwel = double(timeVec(2) - timeVec(1));
                err_step = round(errorBarInterval / dwel);
                % zero values between steps
                stderr( find( mod( 1:length(TFR_DATA.TimeCourseError), err_step ) > 0 ) ) = NaN;
                
                errorbar(timeVec, timeCourse, stderr);
                timeCourse'
                stderr'
            else
                timeCourse = TFR_DATA.TimeCourse; %% COMMENTED OUT BY
%                 timeCourse = mean(tf_data)'
                plot(timeVec, timeCourse);
            end
            
            ylim([minVal maxVal]);
            xlabel('Time (s) ');
            ylabel(unitLabel);
            ax = axis;
            line_h1 = line([0 0],[ax(3) ax(4)]);
            set(line_h1, 'Color', [0 0 0]);
            vertLineVal = 0;
            
            if vertLineVal > ax(3) && vertLineVal < ax(4),
                line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
                set(line_h2, 'Color', [0 0 0]);
            end
            tt = title(plotLabel);
            set(tt,'Interpreter','none');
            
        else
            imagesc(timeVec, freqVec, tf_data, [minVal maxVal] );
            axis xy;  
            h = colorbar;

            xlabel('Time (s) ');
            ylabel('Freq (Hz)');

            set(get(h,'YLabel'),'String',unitLabel);

            tt = title(plotLabel);
            set(tt,'Interpreter','none');

            % some useful info
            [xx, tmaxbin ] = max(max(trunc_data));
            [xx, tminbin ] = min(min(trunc_data));
            [maxPower, fmaxbin ] = max(max(trunc_data'));
            [minPower, fminbin ] = min(min(trunc_data'));     

            fprintf('Minimum value = %g %s at t = %g s, freg = %g Hz\n', minPower, unitLabel, timeVec(tminbin), freqVec(fminbin) );
            fprintf('Maximum value = %g %s at t = %g s, freg = %g Hz\n\n', maxPower, unitLabel, timeVec(tmaxbin), freqVec(fmaxbin) );
        end
        
        clear trunc_data
        
    end

end

function baseline = updateParamsDlg ( old_baseline, timeVec )

    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Change Baseline Range','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 650 200]);
    
    baseline = old_baseline;
   
    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.6 0.15 0.22],'string','OK','BackgroundColor',[0.99,0.64,0.3],...
        'FontSize',13,'ForegroundColor','black','FontWeight','b','callback',@ok_callback);

    cancel=uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.25 0.15 0.22],'string','Cancel','BackgroundColor','white','FontSize',13,...
        'ForegroundColor','black','callback',@cancel_callback);

        function cancel_callback(src,evt)
            uiresume(gcbf); 
        end
    
    BASELINE_TITLE2=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.5 0.223 0.1],'String','Baseline (s):     Start:','FontSize',12,...
        'BackGroundColor','white','foregroundcolor','black');  

    BASELINE_TITLE3=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.45 0.5 0.08 0.1],'String','End:','FontSize',12,...
       'BackGroundColor','white','foregroundcolor','black'); 

    BASELINE_START_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.28 0.46 0.12 0.2],'String', baseline(1), 'FontSize', 12,...
          'BackGroundColor','white');

    BASELINE_END_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.52 0.46 0.12 0.2],'String', baseline(2), 'FontSize', 12,...
              'BackGroundColor','white');    

    USE_ALL_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
        [0.1 0.15 0.25 0.14],'string','Set to whole epoch','backgroundcolor','white',...
        'fontsize',10,'foregroundcolor','blue','callback',@use_all_callback);

        function use_all_callback(src,evt)        
            baseline = [timeVec(1) timeVec(end)];
            set(BASELINE_START_EDIT,'String',baseline(1));
            set(BASELINE_END_EDIT,'String',baseline(2));    
        end
    
    function ok_callback(src,evt)
        % update params
        string_value=get(BASELINE_START_EDIT,'String');
        baseline(1)=str2double(string_value);
        string_value=get(BASELINE_END_EDIT,'String');
        baseline(2)=str2double(string_value);  

        uiresume(gcf);
    end
    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
end




