function bw_headMotionPlot(latencyList,headMotion,sensorMotion,rejectedTrials,names,threshold)       

    scrnsizes=get(0,'MonitorPosition');

    % persistent counter to move figure
    persistent plotcount;

    if isempty(plotcount)
        plotcount = 0;
    else
        plotcount = plotcount+1;
    end

    % tile windows
    width = 950;
    height = 650;
    start = round(0.4 * scrnsizes(1,3));
    bottom_start = round(0.7 * scrnsizes(1,4));

    inc = plotcount * 0.01 * scrnsizes(1,3);
    left = start+inc;
    bottom = bottom_start - inc;

%     ylimits = []; % forces autoscale first time
%     xlimits = []; % forces autoscale first time
%     
%     flipWaveforms = 0;
    
    if ( (left + width) > scrnsizes(1,3) || (bottom + height) > scrnsizes(1,4)) 
        plotcount = 0;
        left = start;
        bottom = bottom_start;
    end
    
    fh = figure('color','white','Position',[left,bottom,width,height], 'NumberTitle','off','menubar','none');
    if ispc
        movegui(fh,'center');
    end


    DATA_SOURCE_MENU = uimenu('label','Dataset');
  
    numSubjects = 1;

    plotOverlay = 0;
    subject_idx = 1;
    

    labels = {};
    
    initialize_subjects;
    
    function initialize_subjects() 
        
       numSubjects = length(names);
       if numSubjects == 1
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
        
        DATA_SOURCE_MENU = uimenu('label','Dataset');
        for k=1:numSubjects
            
            if k == 1
                uimenu(DATA_SOURCE_MENU,'Label',names{k},'Checked','on','Callback',@data_menu_callback);        
            else
                uimenu(DATA_SOURCE_MENU,'Label',names{k},'Callback',@data_menu_callback);        
            end
            
            s = names{k};
            labels{k} = cellstr(s);  % dsNames for menu
            
        end
        
        if (numSubjects > 1)
            plotOverlay = 1;        % make overlay default
%             s = sprintf('%s', 'Group average');
%             uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','off',...
%                 'separator','on','Callback',@data_menu_callback);        
%             s = sprintf('All Subjects (overlay)');
%             uimenu(DATA_SOURCE_MENU,'Label',s,'Checked','on',...
%                 'separator','on','Callback',@data_menu_callback);        
        else
             % uncheck all menus
            set(get(DATA_SOURCE_MENU,'Children'),'Checked','on');
        end
        
    end

    function data_menu_callback(src,evt)      
            subject_idx = get(src,'position');

            % if subject_idx == 0 plot average
            if subject_idx == numSubjects + 1
                subject_idx = 0;   
                plotOverlay = 0;
            elseif subject_idx == numSubjects + 2
                subject_idx = 0;   
                plotOverlay = 1;
            else
                plotOverlay = 0;
            end
            % uncheck all menus
            set(get(DATA_SOURCE_MENU,'Children'),'Checked','off');

            set(src,'Checked','on');
            showHeadMotionPlot(latencyList(subject_idx,1:end),headMotion(subject_idx,1:end),sensorMotion(subject_idx,1:end),rejectedTrials(subject_idx,1:end),names{subject_idx},threshold);
            
            
    end


    function showHeadMotionPlot(latencies,headMotion,sensorMotion,rejectedTrials,name,threshold)
    % Makes a subplot of two plots. First, a time-series plot of a subject's head motion and sensor
    % motion results obtained from the "Scan Epochs" button in the
    % Import MEG window. Any epochs that exceed the threshold and were
    % rejected will be highlighted in green. The second plot is a
    % histogram of the sensor motion data. A green line is drawn at the
    % rejection threshold and any bins to the right of it will be
    % highlighted in green.
        
        % Keeping track of which latencies are bad trials so we know which latencies to highlight            
        rejectedLatencies = [];

        numLatencies = length(latencies);
        for i = 1:numLatencies
            if rejectedTrials(i)
                rejectedLatencies(end+1) = latencies(i);
            end
        end
        
        % Plotting an overlay of head motion in blue and sensor motion in red
        subplot(2,1,1);
        plot(latencies,headMotion, 'b');
        hold on;
        plot(latencies,sensorMotion, 'r');
        hold off;
        
        tt = title(['Head and Sensor Motion Data for Dataset ', name]);
        set(tt,'Interpreter','none');
        xlabel 'Time (s)';
        ylabel 'Distance from reference (cm)';
        grid on;

        % halfRectangleWidth is half the time in between events. If an epoch is rejected, 
        % the highlight patch will extend halfway before and halfway after the event
        halfRectangleWidth = ceil(min(diff(latencies))/2);
        greatestValue = ceil(max(sensorMotion)/0.05)*0.05; % Finds the largest y-value of sensormotion, rounded to the highest 0.05.
        xmax = ceil(max(latencies)/10)*10; % Finds the latest latency, rounded to the highest 10.
        grey = [0.7 0.7 0.7];
        
        xlim([0 xmax]);
        ylim([0 greatestValue]);
        
        % Plotting patches around the rejected trials
        if ~isempty(rejectedLatencies)
        % Highlight new bad trials in green by drawing patches around them.
        % patch width is supposed to extend halfway before and after. 
        % Patch height is supposed to be slightly taller than the maximum y value.
            numRejectedLatencies = length(rejectedLatencies);
            X = zeros(numRejectedLatencies,4);
            Y = zeros(numRejectedLatencies,4);
            
            for i = 1:numRejectedLatencies
                xmin = rejectedLatencies(i)-halfRectangleWidth;
                xmax = rejectedLatencies(i)+halfRectangleWidth;
                
                % The patch function requires and X and Y which represent
                % the coordinates of the 4 corners of the patch (bottom-left, bottom-right, top-right, top-left)
                
                % By creating a new row in X and Y for every rejected
                % trial, the patch function will plot multiple patches
                
                X(i,1:end) = [xmin xmax xmax xmin];
                Y(i,1:end) = [0 0 greatestValue greatestValue];
            end
                        
            patch(X',Y',grey, ...
            'Linestyle', 'none')%, 'FaceAlpha', 0.3);
        
            legend('Head Displacement (origin)', 'Mean Sensor Motion', 'Rejected epochs', 'Location', 'bestoutside')
        else
            legend('Head Displacement (origin)', 'Mean Sensor Motion', 'Location', 'bestoutside')

        end
        
        
        set(gca,'children',flipud(get(gca,'children'))); % unable to make the patches transparent without crashing MATLAB, so this line sends patches to the back, so that the plots are visible
        
        % Preparing the histogram
        numbins = ceil(length(latencies)/10); % number of bins will be equal to 10% of the number of epochs
        
        subplot(2,1,2);
        hist(sensorMotion,numbins);
        h = hist(sensorMotion); % h returns a count of how many elements are in each bin
        tallestBin = ceil(max(h)/10)*10; % the y limit will be set at the tallest bin, rounded to the highest 10.
        grid on;
        
        % plot a vertical line indicating where the rejection threhold is
        % and a legend 
        if threshold
            hold on;
            plot([threshold threshold], [0 tallestBin], 'k', 'LineWidth' ,3);
                
            if ~isempty(rejectedLatencies)
            % Preparing a patch to extend from the right side of the threshold
                X = [threshold greatestValue greatestValue threshold];
                Y = [0 0 tallestBin tallestBin];
                
                xlim([0 greatestValue]);
                patch(X,Y,grey), ...
                %'FaceAlpha', .3);
                
                set(gca,'children',flipud(get(gca,'children')));
            else
                % if a rejection threshold is selected, but none of the
                % subject's data exceeds it, then the x limit will be
                % slightly above the threshold in order to still include the threshold. 
                % For all other situations, the x limit will be the largest
                % sensor motion value.
                xlim([0 threshold+0.05]);
        
            end
            marker = plot(NaN,NaN,'-k');
            legend(marker,'Rejection threshold');
            hold off;
            
        else
            xlim([0 greatestValue]);
        end
        ylim([0 tallestBin])
        xlabel 'Distance from reference (cm)';
        ylabel 'Number of epochs';
        title 'Histogram of sensor motion';
        
        
    end
    
    % This line is needed in order to immediately draw a plot. 
    % It draws plots for the first subject in the dataset dropdown
    showHeadMotionPlot(latencyList(1,1:end),headMotion(1,1:end),sensorMotion(1,1:end),rejectedTrials(1,1:end),names{1},threshold);


end
