function bw_peakListWindow(dsName, covDsName, voxel, normal)

    global g_current_peak
    global g_current_normal
    global g_current_Ds
    global g_current_covDs
    global addPeakFunction
    global PEAK_WINDOW_OPEN
    
    dsList{1} = cellstr(dsName);
    covDsList{1} = cellstr(covDsName);
    voxelList(1,1:3) = voxel(1:3);
    orientationList(1,1:3) = normal(1:3);
    
    data = {};
    
    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Virtual Sensor List','numbertitle','off','menubar','none',...
        'CloseRequestFcn',@close_callback,'position',[300 (scrnsizes(1,4)-300) 650 300]);
  
    FILE_MENU = uimenu('label','File');
    
    LOAD_CONDITION_MENU = uimenu(FILE_MENU,'label','Switch Condition...','Callback',@load_condition_callback);
    
    SAVE_VLIST_MENU = uimenu(FILE_MENU,'label','Save voxel list...','Callback',@save_vlist_callback);
    
    CLOSE_MENU = uimenu(FILE_MENU,'label','Close','separator','on','Callback',@close_callback);
    
    DELETE_BUTTON = uicontrol('style','pushbutton','units','normalized','position',...
          [0.75 0.85 0.15 0.08],'String', 'Remove', 'FontSize', 12,'horizontalAlignment','left',...
          'callback',@remove_peak_callback);

    s = sprintf('Dataset                           Location (cm)');
    HEADER_TEXT = uicontrol('style','text','units','normalized','position',...
          [0.08 0.71 0.8 0.1],'String', s,...
          'FontSize', 12,'horizontalAlignment','left',...
          'BackGroundColor','white');
    DATA_WINDOW=uicontrol('style','listbox','units','normalized','position',...
    [0.08 0.05 0.85 0.7],'string','','fontsize',10,'max',10000,'background','white');
    
    update;
    PEAK_WINDOW_OPEN = 1;  
       
      function load_condition_callback(src, evt)

            if isempty(voxelList)
                return;
            end

            newList = bw_getConditionList;

            if size(newList,2) == size(dsList,2)
                dsList = cellstr(newList);
                update;
            else
                fprintf('** Condition must contain same number of datasets **\n');
                return;
            end

       end

       function save_vlist_callback(src, evt)
        
        if isempty(voxelList)
            return;
        end
        
        [filename pathname xxx]=uiputfile({'*.vs','Virtual Sensor File (*.vs)'},'Save Virtual Sensor Parameters as...');
        if isequal(filename,0) || isequal(pathname,0)
            return;
        end
                    
        saveName = fullfile(pathname, filename);
        fprintf('Saving parameters in file %s\n', saveName);
        fid = fopen(saveName,'w');
                     
        for j=1:size(voxelList,1)
           dsName = char(dsList{j});
           covDsName = char(covDsList{j});
           voxel = voxelList(j,1:3);
           normal = orientationList(j,1:3);
           s = sprintf('%s  %s  %6.1f %6.1f %6.1f    %8.3f %8.3f %8.3f', dsName, covDsName, voxel, normal);    
           fprintf(fid,'%s\n', s);           
        end        
        
        fclose(fid);
        
       end    
    
        function remove_peak_callback(src,evt)
            
            if size(voxelList,1) < 1
                return;
            end
            selectedRow = get(DATA_WINDOW,'value');
            voxelList(selectedRow,:) = [];
            orientationList(selectedRow,:) = [];
            dsList(selectedRow) = [];
            covDsList(selectedRow) = [];
            
            set(DATA_WINDOW,'value',1);
            
            update;
        end

        function close_callback(src,evt)
            PEAK_WINDOW_OPEN = 0;
            delete(fg);
        end

        function addCurrentPeak
            dsName = g_current_Ds;
            covDsName = g_current_covDs;
            voxel = g_current_peak;
            normal = g_current_normal;

            numVoxels = size(voxelList,1);
            dsList{numVoxels+1} = cellstr(dsName);
            covDsList{numVoxels+1} = cellstr(covDsName);
            voxelList(numVoxels+1,1:3) = voxel(1:3);
            orientationList(numVoxels+1,1:3) = normal(1:3);

            figure(fg)
            update

        end

        addPeakFunction = @addCurrentPeak;

        function update

            data = {};
            for j=1:size(voxelList,1);
               dsname = char(dsList{j});
               covDsname = char(covDsList{j});
               voxel = voxelList(j,1:3);
               orientation = orientationList(j,1:3);
               s = sprintf('Dataset                         Covariance Dataset                        Location (cm)                     Normal');
               set(HEADER_TEXT, 'String', s);

               s = sprintf('%s    %s   %8.2f %8.2f %8.2f       %6.3f %6.3f %6.3f', dsname, covDsName, voxel, orientation);
               data(j,:) = cellstr(s); 
            end

           set(DATA_WINDOW,'string',data);     
        end   


end
