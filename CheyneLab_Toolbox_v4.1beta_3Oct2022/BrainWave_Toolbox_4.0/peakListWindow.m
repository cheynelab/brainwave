function [fg] = peakListWindow(init_voxel, init_dsName)

    dsList = [];
    voxelList = [];
    
    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Virtual Sensor List','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 400 350]);
  
    FILE_MENU = uimenu('label','File');
    SAVE_VLIST_MENU = uimenu(FILE_MENU,'label','Save Voxel List ...','Callback',@save_vlist_callback);
    CLOSE_MENU = uimenu(FILE_MENU,'label','Close','separator','on','Callback',@close_callback);
    
    uicontrol('style','text','units','normalized','position',...
          [0.62 0.845 0.5 0.1],'String', 'Latency (s)', 'FontSize', 12,'horizontalAlignment','left',...
          'BackGroundColor','white');

    s = sprintf('Dataset                           Location (cm)');
    HEADER_TEXT = uicontrol('style','text','units','normalized','position',...
          [0.08 0.71 0.8 0.1],'String', s,...
          'FontSize', 12,'horizontalAlignment','left',...
          'BackGroundColor','white');
    DATA_WINDOW=uicontrol('style','listbox','units','normalized','position',...
    [0.08 0.05 0.85 0.7],'string','','fontsize',10,'max',10000,'background','white');
    
    update;

    function close_callback(src,evt)
        delete(fg);
    end

    function update

        for j=1:size(voxelList,1)
           dsname = char(dsList{j});
           voxel = voxelList(j,1:3);
           s = sprintf('Dataset                           Location (cm)');
           set(HEADER_TEXT, 'String',s);
           s = sprintf('%s    %8.2f %8.2f %8.2f\t%10.4f %10.4f %10.4f  %12.3f', dsname, voxel);
           data(j,:) = cellstr(s); 
        end

       set(DATA_WINDOW,'string',data);     
    end   


end
