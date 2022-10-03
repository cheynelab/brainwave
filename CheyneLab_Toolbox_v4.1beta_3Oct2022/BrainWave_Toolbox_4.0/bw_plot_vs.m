function bw_plot_vs(VS_ARRAY, vs_options, groupLabel)       
%
%   function bw_plot_vs(VS_ARRAY, vs_options, groupLabel)
%
%   DESCRIPTION: creates a virtual sensor plot window - separate function 
%   that is derived from bw_make_vs_mex.  Note plot window holds  all params
%   necessary to save average and/or generate the single trial data for saving.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%

    if ~exist('groupLabel','var')
        groupLabel = 'Grand Average';
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
%     width = 680;
%     height = 500;
%     start = round(0.4 * scrnsizes(1,3));
%     bottom_start = round(0.7 * scrnsizes(1,4));
% 
%     inc = plotcount * 0.01 * scrnsizes(1,3);
%     left = start+inc;
%     bottom = bottom_start - inc;
% 
%     if ( (left + width) > scrnsizes(1,3) || (bottom + height) > scrnsizes(1,4)) 
%         plotcount = 0;
%         left = start;
%         bottom = bottom_start;
%     end
%     
    fh = figure('color','white');%,'Position',[left,bottom,width,height]);
    if ispc
        movegui(fh,'center');
    end
    if isfield(vs_options, 'plotColor')
        plotColor = vs_options.plotColor;
    else
        plotColor = [0 0 1];
    end
    
    BRAINWAVE_MENU=uimenu('Label','Brainwave');

    SAVE_WAVEFORM_MENU = uimenu(BRAINWAVE_MENU,'label','Save VS Plot...','Callback',@save_vs_data_callback);
    SAVE_ASCII_MENU = uimenu(BRAINWAVE_MENU,'label','Export data ...','Callback',@save_data_callback);
    PARAMETERS_MENU = uimenu(BRAINWAVE_MENU,'label','Plot parameters...','separator','on','Callback',@change_parameters_callback);
    PLOT_COLOR_MENU = uimenu(BRAINWAVE_MENU,'label','Change Plot Colour...','Callback',@plot_color_callback);
    DATA_WINDOW_MENU = uimenu(BRAINWAVE_MENU,'label','Display Voxel Parameters ...','Callback',@data_window_callback);
    
    PLOT_AVERAGE_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Average','separator','on','Callback',@average_callback);
    PLOT_PLUSMINUS_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Average+PlusMinus','Callback',@plusminus_callback);
    PLOT_ALL_EPOCHS_MENU = uimenu(BRAINWAVE_MENU,'label','Plot Single trials','Callback',@all_epochs_callback);
    DATA_SOURCE_MENU = uimenu(BRAINWAVE_MENU,'label','Data source','separator','on');

    set(PLOT_AVERAGE_MENU,'checked','on');      

    [rows numSubjects] = size(VS_ARRAY);
 
    if numSubjects == 1
        subject_idx = 1;
    else
        subject_idx = 0;
    end  
    
    labels = {};

    for i=1:numSubjects
%         uimenu_call = ['uimenu_action = ''' VS_ARRAY{i}.dsName '''; uimenu_control;'];
        uimenu(DATA_SOURCE_MENU,'Label',VS_ARRAY{i}.dsName,'Callback',@data_menu_callback);        
        labels{i} = cellstr(VS_ARRAY{i}.dsName);    
    end
    
    if (numSubjects > 1)
        s = sprintf('%s', groupLabel);
%         uimenu_call = ['uimenu_action = ''' s '''; uimenu_control;'];
        uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','on',...
            'separator','on','Callback',@data_menu_callback);        
    else
         % uncheck all menus
        set(get(DATA_SOURCE_MENU,'Children'),'Checked','on');
    end
   
    timeVec = VS_ARRAY{1}.timeVec;
    dwel = (timeVec(2) - timeVec(1));
    numSamples = length(timeVec);
    
    plotAverage = 1;
    plotPlusMinus = 0;
    plotOverlay = 0;
    
    pparams.plotHilbert = false;
    pparams.plotHilbertPhase = false;
    
    pparams.numSubjects = numSubjects;
    pparams.timeVec = timeVec; % copy to pass to subroutine.
    pparams.sampleRate = 1.0 / dwel;    
    pparams.timeVec = VS_ARRAY{1}.timeVec;
    pparams.filter = VS_ARRAY{1}.filter;
    pparams.range = pparams.filter;
    pparams.baseline = VS_ARRAY{1}.baseline;
   
    pparams.plotError = 0;
    pparams.errorBarType = 1;
    pparams.subtractAverage = false;
    pparams.errorBarInterval = 0.1;
    pparams.errorBarWidth = pparams.errorBarInterval * 0.30;
    pparams.bidirectionalFilter = 1;
       
   
    % keep copy of original data
    hasSingleTrial = false;
    
    vs_data = {numSubjects};
    
    ave_group = zeros(numSubjects,numSamples);
       
    for k=1:numSubjects
        vs_data{k} = VS_ARRAY{k}.vs_data';
        
        % check for single trial data
        if size(vs_data{k},1) == 1
            set(PLOT_ALL_EPOCHS_MENU,'enable','off');
            set(PLOT_PLUSMINUS_MENU,'enable','off');
        end
    end
    
    % callbacks
    
    function data_menu_callback(src,evt)      
        subject_idx = get(src,'position');
        
        % if subject_idx == 0 plot average
        if subject_idx == numSubjects + 1
            subject_idx = 0;   
            plotOverlay = false;
        end

        % uncheck all menus
        set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');
        
        set(src,'Checked','on');
        processData;
        updatePlot;
        
    end

    function average_callback(src,evt)  
        plotAverage = true;
        plotPlusMinus = false;
        
        set(src,'Checked','on');
        set(PLOT_ALL_EPOCHS_MENU,'Checked','off');
        set(PLOT_PLUSMINUS_MENU,'Checked','off');
        set(DATA_WINDOW_MENU, 'enable','on');
        
        processData;
        updatePlot;     
    end

    function plusminus_callback(src,evt)  
        plotPlusMinus = true;
        plotAverage = false;

        set(src,'Checked','on');
        set(PLOT_ALL_EPOCHS_MENU,'Checked','off');
        set(PLOT_AVERAGE_MENU,'Checked','off');
        set(DATA_WINDOW_MENU, 'enable','on');
        
        processData;
        updatePlot;     
    end

    function all_epochs_callback(src,evt)  
        plotAverage = false;
        plotPlusMinus = false;
       
        set(src,'Checked','on');
        set(PLOT_AVERAGE_MENU,'Checked','off');
        set(DATA_WINDOW_MENU, 'enable','off');
        set(PLOT_PLUSMINUS_MENU,'Checked','off');
        
        processData;
        updatePlot;     
    end    
    
   function plot_color_callback(src,evt) 
        newColor = uisetcolor;
        if size(newColor,2) == 3
            plotColor = newColor;
        end        
        updatePlot;
    end

    function save_data_callback(src,evt)
       
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
        
        % saves the currently displayed (processed) data
        % NOTE: since currently can only display averages for group data,
        % it is unlikely this would be used to save group vs data..

        % format for matfile 
        %
        % format:
        % vsdata.timeVec = 1D array of latencies (nsamples x 1)
        % vsdata.trials = 3D array of vs data (ntrials x nsamples)
        % vsdata.label = original plot label
 
       % ensure current params applied 
       processData;
       
       if (subject_idx >  0)              
           
           % save this subject's data...           
           data = vs_data{subject_idx};
           
           if plotAverage  
               % NOTE: if data only contains single trial (i.e., average)
               % this will just divide average by one 
               save_data = mean(data,1);  
               % change in Vers 3 beta - averaged data is baselined in plot
               startSample = round( ( pparams.baseline(1) - timeVec(1)) / dwel) + 1;
               endSample = round( ( pparams.baseline(2) - timeVec(1)) / dwel) + 1;
               b = mean( save_data(startSample:endSample) );               
               save_data = save_data - b;   
           else       
               save_data = data;            
           end
           % save in transposed in format = 1st column is timeVec, 2nd column is trial1...

           fprintf('Saving virtual sensor data to file %s\n', filename);      
            
           if saveMatFile 
                vsdata.timeVec = timeVec;
                vsdata.label = VS_ARRAY{i}.plotLabel;
                vsdata.data = single(save_data');    % save single precision              
                save(filename,'-struct','vsdata');
           else
                fid = fopen(filename,'w');
                for k=1:size(save_data,2)
                    fprintf(fid, '%.4f', timeVec(k) );
                    for j=1:size(save_data,1)
                        fprintf(fid, '\t%8.4f', save_data(j,k) );
                    end   
                    fprintf(fid,'\n');
                end
                fclose(fid);                                                
            end
       else
           % save all subjects - need to label files...           
           for i=1:numSubjects
               [path, name, ext] = bw_fileparts(filename); 
               [tpath, dsname, ext] = bw_fileparts(VS_ARRAY{i}.dsName); 
               
               data = vs_data{i};
               if plotAverage  
                   save_data = mean(data,1);  
               else       
                   save_data = data;            
               end                              
                            
               if saveMatFile 
                   tname = sprintf('%s_%s.mat', name, dsname);
                   tFileName = fullfile(path,tname);
                   fprintf('Saving virtual sensor data to file %s\n', tFileName); 
                   vsdata.timeVec = timeVec;
                   vsdata.label = VS_ARRAY{i}.plotLabel;
                   vsdata.data = single(save_data');                 
                   save(tFileName,'-struct','vsdata');
               else                 
                   tname = sprintf('%s_%s.txt', name, dsname);
                   tFileName = fullfile(path,tname);
                   fprintf('Saving virtual sensor data to file %s\n', tFileName); 
                   fid = fopen(tFileName,'w');
                   for k=1:size(save_data,2)
                        fprintf(fid, '%.4f', timeVec(k) );
                        for j=1:size(save_data,1)
                            fprintf(fid, '\t%8.4f', save_data(j,k) );
                        end   
                        fprintf(fid,'\n');
                    end
                    fclose(fid);      
                    % save the group average (i.e., trial averaged data only...)               
                    ave_group(i,:) = mean(data,1);  % ave for this subject
               end
               
           end
           
           % export grand average waveform...
           if saveMatFile
               grand_ave = mean(ave_group,1);
               stderr = std(ave_group,1) ./sqrt(numSubjects); 
               tname = sprintf('%s_group_average.mat', name);
               tFileName = fullfile(path,tname);
               fprintf('Saving virtual sensor data to file %s\n', tFileName); 
               vsdata.timeVec = timeVec;
               vsdata.label = VS_ARRAY{i}.plotLabel;
               vsdata.data = single(grand_ave');  
               vsdata.stderr = single(stderr');                 
               save(tFileName,'-struct','vsdata');
           else
               grand_ave = mean(ave_group,1);
               stderr = std(ave_group,1) ./sqrt(numSubjects); 
               tname = sprintf('%s_group_average.txt', name);
               tFileName = fullfile(path,tname);
               fprintf('Saving virtual sensor data to file %s\n', tFileName); 
               fid = fopen(tFileName,'w');
               for k=1:size(grand_ave,2)
                    fprintf(fid, '%.4f', timeVec(k) );
                    fprintf(fid, '\t%8.4f', grand_ave(k) );                   
                    fprintf(fid, '\t%8.4f', stderr(k) );                   
                    fprintf(fid,'\n');
                end
                fclose(fid);      
           end
           
       end    
    end

    function save_vs_data_callback(src,evt)      
        
        defName = '*_WAVEFORMS.mat';
        [name,path,FilterIndex] = uiputfile('*.mat','Select Name for VS data file:',defName);
        if isequal(name,0)
            return;
        end
        outFile = fullfile(path,name);
        fprintf('Saving VS data to file %s\n', outFile);
                  
        % update to save currently displayed image
        
        save(outFile,'VS_ARRAY','vs_options', 'groupLabel');            

    end

    function change_parameters_callback(src,evt)   
        
        params = updateParametersDlg(pparams);

        if ~isempty(params)
            pparams = params;
            processData;
            updatePlot;
        end
    end

    function data_window_callback(src,evt)

        % make sure subj_data is updated - problem is offset?
        processData; 
        for k=1:numSubjects            
            data(k,:) = ave_group(k,:);
        end
        
        plotDataWindow (VS_ARRAY, vs_options, data);
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

            if ~plotAverage && subject_idx > 0 && pparams.subtractAverage
               fprintf('subtracting average from single trials...\n');
               ave_data = mean(data,1);     
               for j=1:size(data,1)
                    data(j,:) = data(j,:) - ave_data;
               end
            end
            
            % filter if not original bandwidth
            if ( pparams.range(1) ~=  pparams.filter(1)) || ( pparams.range(2) ~=  pparams.filter(2))
                fprintf('re-filtering data...\n');
                for j=1:size(data,1)
                    data(j,:) = bw_filter(data(j,:),  pparams.sampleRate,  pparams.range, 4, pparams.bidirectionalFilter);                  
                end
            end
            
            % if plot hilbert amplitude or phase apply to the single trials
            % then compute average
            
            if pparams.plotHilbert
                for j=1:size(data,1)               
                   h = hilbert( data(j,:) );
                   if pparams.plotHilbertPhase 
                        data(j,:) = angle(h);                         
                   else
                        data(j,:) = abs(h);     
                   end
                end      
            end    
                                
            vs_data{k} = data;       
            
            % ** save mean waveform for each subj **           
            % Note if we don't have single trials in the data array,
            % this just divides the average by one
%             ave = mean(data,1);   
%            
%             % apply baseline correction to averages only
%             startSample = round( ( pparams.baseline(1) - timeVec(1)) / dwel) + 1;
%             endSample = round( ( pparams.baseline(2) - timeVec(1)) / dwel) + 1;
%             b = mean( ave(startSample:endSample) );               
%             ave = ave - b;   
%             
%             vs_average{k} = ave;
            
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
            startSample = round( ( pparams.baseline(1) - timeVec(1)) / dwel) + 1;
            endSample = round( ( pparams.baseline(2) - timeVec(1)) / dwel) + 1;
            b = mean( ave(startSample:endSample) );               
            ave = ave - b;   
            if plotPlusMinus   
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
        
        % select data to plot
        
        if (subject_idx >  0)     
            if plotAverage    
                plot_data = ave;
            elseif plotPlusMinus
                plot_data = [ave; pm_ave];
            else
                plot_data = trial_data;
            end
        else
            if plotAverage
                plot_data = mean(ave_group,1);
            elseif plotPlusMinus
                plot_data = [mean(ave_group,1); mean(pm_group,1)];
            else
                plot_data = trial_group;
            end

        end
                   
        % plot data ...
        
        s = sprintf('Virtual Sensor (%g to %g Hz)', pparams.range(1),  pparams.range(2));
        
        set(fh,'Name',s);

        if  pparams.plotError && plotAverage && subject_idx == 0 
            
            % compute variance across subjects
            stderr = std(ave_group,1) ./sqrt(numSubjects); 
            
            if pparams.errorBarType == 0
                % zero values between steps
                err_step = round( pparams.errorBarInterval / dwel);
                stderr( find( mod( 1:length(stderr), err_step ) > 0 ) ) = NaN;   

                % set width of error bar whiskers
                w = pparams.errorBarWidth;  % width of error bar in milliseconds

                h = errorbar(timeVec, plot_data, stderr, 'color', plotColor);
                hh = get(h,'children');
                x = get(hh(2),'xdata');
                x(4:9:end) = x(1:9:end) - w/2;
                x(7:9:end) = x(1:9:end) - w/2;
                x(5:9:end) = x(1:9:end) + w/2;
                x(8:9:end) = x(1:9:end) + w/2;
                set(hh(2),'xdata',x(:));
            else            
                uplim=plot_data+stderr;
                lolim=plot_data-stderr;
                filledValue=[uplim fliplr(lolim)]; %depends on column type (needs to plot forward, then back to start before fill/patch)
                timeValue=[timeVec; flipud(timeVec)]; 

                h1=fill(timeValue,filledValue,plotColor);
                set(h1,'FaceAlpha',0.5,'EdgeAlpha',0.5,'EdgeColor',plotColor);
                hold on
                plot(timeVec,plot_data, 'color', plotColor);
                hold off
            end
            
        else
            if size(plot_data,1) == 1
                plot(timeVec, plot_data, 'color', plotColor); % apply color only if not plotting plus/ minus
            else
                plot(timeVec, plot_data);  
            end
        end

        % adjust scales
        xlim([timeVec(1) timeVec(end)]);
        
        
        % avoid end effects by 10% for scaling
        endpts = round(0.1*size(timeVec,1));
        if size(plot_data,1) > 1
            mx = 1.2*max(max(abs( plot_data(:,endpts:end-endpts)) ));
        else
            mx = 1.2*max(abs( plot_data(endpts:end-endpts) ));                       
        end        
        ylim([-mx mx]);
       
        % annotate plot       
        if pparams.plotHilbertPhase
            dataUnits = 'radians';
        else  
            if (vs_options.pseudoZ)   
                dataUnits = 'Pseudo-Z';
            else
                dataUnits = 'Moment (nAm)';
            end
        end
        xlabel('Time (sec)');
        if vs_options.rms
            ytxt = strcat(dataUnits, ' (RMS)');
        else
            ytxt = dataUnits ;
        end
        ylabel(ytxt);

        if plotPlusMinus
            legend('average','plus-minus average');
        end
        
        % draw axes
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
       

    end


end


function params = updateParametersDlg ( init_params )

    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Processing Parameters','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 650 430]);

    params = init_params;
    
    % filter 
    
    FREQ_TITLE2=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.77 0.25 0.08],'String','Filter:        Hi-pass (Hz):','FontSize',10,'fontname','lucinda',...
        'BackGroundColor','white','foregroundcolor','black');  

    FREQ_TITLE3=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.45 0.77 0.25 0.08],'String','Low-pass (Hz):','FontSize',10,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 
     
    FREQ_START_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.32 0.80 0.1 0.08],'String', params.range(1), 'FontSize', 12,...
          'BackGroundColor','white');

    FREQ_END_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.80 0.1 0.08],'String', params.range(end), 'FontSize', 12,...
              'BackGroundColor','white');    

    USE_FULL_RANGE_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
        [0.76 0.80 0.15 0.1],'string','Use full range','backgroundcolor','white',...
        'fontsize',10,'foregroundcolor','blue','callback',@use_full_range_callback);

        function use_full_range_callback(src,evt)        
            set(FREQ_START_EDIT,'String',params.filter(1));
            set(FREQ_END_EDIT,'String',params.filter(2));    
        end
    
    REVERSING_FILTER_CHECK = uicontrol('style','check','units','normalized','horizontalalignment','left','position',...
        [0.05 0.70 0.3 0.1],'String','Zero phase shift','FontSize',12,'value',params.bidirectionalFilter,...
       'BackGroundColor','white','foregroundcolor','black','callback',@reversing_filter_Callback); 
    
   
    % baseline
    
    BASELINE_TITLE2=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.05 0.53 0.25 0.08],'String','Baseline:          Start (s):','FontSize',10,'fontname','lucinda',...
        'BackGroundColor','white','foregroundcolor','black');  

    BASELINE_TITLE3=uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.5 0.53 0.1 0.08],'String','End (s):','FontSize',10,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

    BASELINE_START_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.32 0.56 0.1 0.08],'String', params.baseline(1), 'FontSize', 12,...
          'BackGroundColor','white');

    BASELINE_END_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.6 0.56 0.1 0.08],'String', params.baseline(2), 'FontSize', 12,...
              'BackGroundColor','white');    

    USE_ALL_BUTTON=uicontrol('style','pushbutton','units','normalized','position',...
        [0.76 0.56 0.18 0.1],'string','Set to whole epoch','backgroundcolor','white',...
        'fontsize',10,'foregroundcolor','blue','callback',@use_all_callback);

        function use_all_callback(src,evt)        
            fullrange = [params.timeVec(1) params.timeVec(end)];
            set(BASELINE_START_EDIT,'String',fullrange(1));
            set(BASELINE_END_EDIT,'String',fullrange(2));    
        end
    
   
   % plot options

    PLOT_HILBERT_CHECK = uicontrol('style','check','units','normalized','horizontalalignment','left','position',...
        [0.05 0.45 0.26 0.05],'String','Plot Hilbert Transform','FontSize',10,'fontname','lucinda','value',params.plotHilbert,...
       'BackGroundColor','white','foregroundcolor','black','callback',@plotHilbertCallback); 

    PLOT_AMPLITUDE_RADIO = uicontrol('style','radiobutton','units','normalized','horizontalalignment','left','position',...
        [0.34 0.45 0.14 0.05],'String','Amplitude','FontSize',10,'fontname','lucinda','value',~params.plotHilbertPhase,...
       'BackGroundColor','white','foregroundcolor','black','callback',@plotAmplitudeCallback); 
   
    PLOT_PHASE_RADIO = uicontrol('style','radiobutton','units','normalized','horizontalalignment','left','position',...
        [0.5 0.45 0.1 0.05],'String','Phase','FontSize',10,'fontname','lucinda','value',params.plotHilbertPhase,...
       'BackGroundColor','white','foregroundcolor','black','callback',@plotPhaseCallback); 
   
    SUBTRACT_AVERAGE_CHECK = uicontrol('style','check','units','normalized','horizontalalignment','left','position',...
        [0.05 0.385 0.4 0.05],'String','Subtract Average from Single Trials','FontSize',10,'fontname','lucinda','value',params.subtractAverage,...
       'BackGroundColor','white','foregroundcolor','black','callback',@subtractAverageCallback); 

    SHOW_ERROR_CHECK = uicontrol('style','check','units','normalized','horizontalalignment','left','position',...
        [0.05 0.32 0.4 0.05],'String','Plot Standard Error (Group data only)','FontSize',10,'fontname','lucinda','value',params.plotError,...
       'BackGroundColor','white','foregroundcolor','black','callback',@plotErrorCallback); 

    PLOT_ERROR_BARS_SMOOTH = uicontrol('style','radio','units','normalized','horizontalalignment','left','position',...
        [0.1 0.24 0.3 0.05],'String','Shaded','FontSize',10,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black','callback',@plotErrorSmoothCallback); 
   
    PLOT_ERROR_BARS = uicontrol('style','radio','units','normalized','horizontalalignment','left','position',...
        [0.1 0.15 0.3 0.1],'String','Error Bars every','FontSize',10,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black','callback',@plotErrorBarCallback); 

        
    PLOT_ERROR_TEXT = uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.38 0.135 0.3 0.08],'String','seconds','FontSize',10,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

   ERROR_BAR_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.29 0.16 0.08 0.08],'String', params.errorBarInterval, 'FontSize', 12,...
          'BackGroundColor','white');
      
   PLOT_WHISKER_TEXT1 = uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.13 0.035 0.3 0.08],'String','Error bar width','FontSize',10,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

   PLOT_WHISKER_TEXT2 = uicontrol('style','text','units','normalized','horizontalalignment','left','position',...
        [0.38 0.035 0.3 0.08],'String','seconds','FontSize',10,'fontname','lucinda',...
       'BackGroundColor','white','foregroundcolor','black'); 

   ERROR_BAR_WIDTH_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.29 0.05 0.08 0.08],'String', params.errorBarWidth, 'FontSize', 12,...
          'BackGroundColor','white');

   if params.errorBarType == 0
       set(PLOT_ERROR_BARS_SMOOTH,'value', 0);
       set(PLOT_ERROR_BARS,'value', 1);
   else
       set(PLOT_ERROR_BARS_SMOOTH,'value', 1);
       set(PLOT_ERROR_BARS,'value', 0);
   end
    if params.plotError
        set(PLOT_ERROR_BARS,'enable','on');
        set(PLOT_ERROR_BARS_SMOOTH,'enable','on');
        set(PLOT_WHISKER_TEXT1,'enable','on');
    else
        set(PLOT_ERROR_BARS,'enable','off');
        set(PLOT_ERROR_BARS_SMOOTH,'enable','off');
        set(PLOT_WHISKER_TEXT1,'enable','off');
    end
      
      
      
    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.1 0.15 0.1],'string','OK','BackgroundColor',[0.99,0.64,0.3],...
        'FontSize',13,'ForegroundColor','black','FontWeight','b','callback',@ok_callback);

    cancel=uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.28 0.15 0.1],'string','Cancel','BackgroundColor','white','FontSize',13,...
        'ForegroundColor','black','callback',@cancel_callback);

        function cancel_callback(src,evt)
            
            params = []; 
            uiresume(gcbf); 
           
        end
 
    
    if params.plotHilbert
        set(PLOT_AMPLITUDE_RADIO,'enable','on');
        set(PLOT_PHASE_RADIO,'enable','on');
    else
        set(PLOT_AMPLITUDE_RADIO,'enable','off');
        set(PLOT_PHASE_RADIO,'enable','off');
    end  
    
    if params.numSubjects < 2
        set(ERROR_BAR_EDIT,'enable','off');
        set(PLOT_ERROR_BARS,'enable','off');
        set(PLOT_ERROR_TEXT,'enable','off');
    end
    
    function plotHilbertCallback(src,evt)
        params.plotHilbert = get(src,'value');
        if params.plotHilbert
            set(PLOT_AMPLITUDE_RADIO,'enable','on');
            set(PLOT_PHASE_RADIO,'enable','on');
        else
            set(PLOT_AMPLITUDE_RADIO,'enable','off');
            set(PLOT_PHASE_RADIO,'enable','off');
        end            
    end

    function plotAmplitudeCallback(src,evt)
        params.plotHilbertPhase = 0;
        set(PLOT_AMPLITUDE_RADIO,'value',1);
        set(PLOT_PHASE_RADIO,'value',0);
    end

    function plotPhaseCallback(src,evt)
        params.plotHilbertPhase = 1;
        set(PLOT_AMPLITUDE_RADIO,'value',0);
        set(PLOT_PHASE_RADIO,'value',1);
    end

    function subtractAverageCallback(src,evt)
        params.subtractAverage = get(src,'value');
    end

    function plotErrorCallback(src,evt)
        params.plotError = get(src,'value');
        
        if params.plotError
            set(PLOT_ERROR_BARS,'enable','on');
            set(PLOT_ERROR_BARS_SMOOTH,'enable','on');
            set(PLOT_WHISKER_TEXT1,'enable','on');
        else
            set(PLOT_ERROR_BARS,'enable','off');
            set(PLOT_ERROR_BARS_SMOOTH,'enable','off');
            set(PLOT_WHISKER_TEXT1,'enable','off');
        end
        
    end

    function plotErrorBarCallback(src,evt)
        params.errorBarType = 0;     
        set(PLOT_ERROR_BARS,'value',1);
        set(PLOT_ERROR_BARS_SMOOTH,'value',0);
    end

    function plotErrorSmoothCallback(src,evt)
        params.errorBarType = 1;      
        set(PLOT_ERROR_BARS,'value',0);
        set(PLOT_ERROR_BARS_SMOOTH,'value',1);
    end

    function reversing_filter_Callback(src,evt)
        val = get(src,'value');
        if val
            params.bidirectionalFilter = 1;
        else
            params.bidirectionalFilter = 0;
        end
    end

    function ok_callback(src,evt)
        
        f1 = str2num(get(FREQ_START_EDIT,'string'));
        f2 = str2num(get(FREQ_END_EDIT,'string'));
        
        if ( f1 > f2 || f1 < params.filter(1) || f2 > params.filter(2) )
            warndlg('Invalid frequency range ...');
            return;
        end    
 
        fprintf('setting frequency range to %g Hz to %g Hz...\n', f1, f2);
        params.range = [f1 f2];
        
        % update params
        string_value=get(BASELINE_START_EDIT,'String');
        baseline(1)=str2double(string_value);
        string_value=get(BASELINE_END_EDIT,'String');
        baseline(2)=str2double(string_value);

       if (baseline(1) > baseline(2) || baseline(1) < params.timeVec(1) || baseline(2) > params.timeVec(end))
            warndlg('Invalid baseline range ...');
            return;
       end
       
       fprintf('setting baseline to %g s to %g s...\n', baseline);
       
       params.baseline = baseline;
       
       if params.plotError
            string_value=get(ERROR_BAR_EDIT,'String');
            params.errorBarInterval=str2double(string_value);  
            string_value=get(ERROR_BAR_WIDTH_EDIT,'String');
            params.errorBarWidth=str2double(string_value); 
       end
             
       uiresume(gcf);
    end


    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
end

function plotDataWindow (VS_ARRAY, vs_options, tdata )

    latency = 0.0;
    plot_mni = false;
    
    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Virtual Sensor Data','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 600 350]);
  
    FILE_MENU = uimenu('label','File');
    SAVE_VLIST_MENU = uimenu(FILE_MENU,'label','Save Voxel List ...','Callback',@save_vlist_callback);
    SAVE_DATA_MENU = uimenu(FILE_MENU,'label','Export data...','Callback',@save_data_callback);
    CLOSE_MENU = uimenu(FILE_MENU,'label','Close','separator','on','Callback',@close_callback);
    
    uicontrol('style','text','units','normalized','position',...
          [0.62 0.845 0.5 0.1],'String', 'Latency (s)', 'FontSize', 12,'horizontalAlignment','left',...
          'BackGroundColor','white');
    s = sprintf('%.4f', latency);
    LATENCY_EDIT=uicontrol('style','edit','units','normalized','position',...
          [0.75 0.88 0.18 0.08],'String', s, 'FontSize', 11,...
          'BackGroundColor','white', 'callback',@latency_callback); 

%     MEG_radio=uicontrol('style','radio','units','normalized','position',...
%           [0.28 0.9 0.2 0.08],'value',~plot_mni,'String', 'MEG coordinates', 'FontSize', 11,...
%           'BackGroundColor','white', 'callback',@meg_radio_callback); 
%       
%     MNI_radio=uicontrol('style','radio','units','normalized','position',...
%           [0.28 0.83 0.2 0.08],'value',plot_mni,'String', 'MNI coordinates', 'FontSize', 11,...
%           'BackGroundColor','white', 'callback',@mni_radio_callback); 
    s = sprintf('Dataset                           Location (cm)              Orientation                        Value');
    HEADER_TEXT = uicontrol('style','text','units','normalized','position',...
          [0.08 0.71 0.8 0.1],'String', s,...
          'FontSize', 12,'horizontalAlignment','left',...
          'BackGroundColor','white');
    DATA_WINDOW=uicontrol('style','listbox','units','normalized','position',...
    [0.08 0.05 0.85 0.7],'string','','fontsize',10,'max',10000,'background','white');

    timeVec = VS_ARRAY{1}.timeVec;
    
%     if ~VS_ARRAY{1}.isNormalized
%         set(MNI_radio, 'enable','off');
%     end
    
    update;

    function close_callback(src,evt)
        delete(fg);
    end

    function latency_callback(src,evt)
       s = get(src,'string');
       latency = str2num(s);
       update;
    end

%     function meg_radio_callback(src,evt)
%        plot_mni = false;
%        set(src,'value',1);
%        set(MNI_radio,'value',0);
%        update;
%     end
% 
%     function mni_radio_callback(src,evt)
%        plot_mni = true;
%        set(src,'value',1);
%        set(MEG_radio,'value',0);
%        update;
%     end


    function update
        
        
        if (vs_options.pseudoZ)   
            dataUnits = 'Pseudo-Z';
        else
            dataUnits = 'Moment (nAm)';
        end

       if latency < timeVec(1) || latency > timeVec(end)
           data = '*** exceeds time range ***';
       else          
           dwel = timeVec(2) - timeVec(1);
           sample = round( (latency - timeVec(1)) / dwel) + 1;
           t = tdata(:,sample);           
           for j=1:size(t,1)
               dsname = char(VS_ARRAY{j}.dsName);
%                if plot_mni
%                    if (vs_options.pseudoZ) 
%                         s = sprintf('Dataset                           Location (cm)                   Pseudo-Z');
%                    else
%                         s = sprintf('Dataset                           Location (cm)                   Moment (nAm)');
%                    end
%                    set(HEADER_TEXT, 'String',s);
%                    voxel = VS_ARRAY{j}.voxel_mni;
%                    s = sprintf('%s    %8.2f %8.2f %8.2f  %12.3f', dsname, voxel, t(j));
%                else
                   if (vs_options.pseudoZ) 
                        s = sprintf('Dataset                           Location (cm)             Orientation                             Pseudo-Z');
                   else
                        s = sprintf('Dataset                           Location (cm)             Orientation                             Moment (nAm)');
                   end
                   set(HEADER_TEXT, 'String',s);
                   voxel = [VS_ARRAY{j}.voxel VS_ARRAY{j}.normal];
                   s = sprintf('%s    %8.2f %8.2f %8.2f\t%10.4f %10.4f %10.4f  %12.3f', dsname, voxel, t(j));
%                end
               data(j,:) = cellstr(s); 
           end
       end
      set(DATA_WINDOW,'string',data);     
    end   


    function save_vlist_callback(src,evt)
       
        [name,path,FilterIndex] = uiputfile('*.vlist','Select Name for vlist file:');
        if isequal(name,0)
            return;
        end
        outFile = fullfile(path,name);
        fprintf('Saving VS data to file %s\n', outFile);
        fid = fopen(outFile,'w');
                
        for j=1:size(tdata,1)
           voxel = [VS_ARRAY{j}.voxel VS_ARRAY{j}.normal];
           dsname = char(VS_ARRAY{j}.dsName);
           fprintf(fid,'%s    %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f\n', dsname, voxel);  
        end
    
        fclose(fid);
    end   

    function save_data_callback(src,evt)
       
        [name,path,FilterIndex] = uiputfile('*.csv','Save data to CSV file');
        if isequal(name,0)
            return;
        end
        outFile = fullfile(path,name);
        fprintf('Saving VS data to file %s\n', outFile);
        fid = fopen(outFile,'w');
                
        dwel = timeVec(2) - timeVec(1);
        sample = round( (latency - timeVec(1)) / dwel) + 1;
        t = tdata(:,sample);           
        for j=1:size(tdata,1)
           dsname = char(VS_ARRAY{j}.dsName);
           voxel = [VS_ARRAY{j}.voxel VS_ARRAY{j}.normal];
           fprintf(fid,'%s,%.1f,%.1f,%.1f,%.3f,%.3f,%.3f,%g\n', dsname, voxel, t(j));  
        end
    
        fclose(fid);
    end   


end



