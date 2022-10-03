function  [latencyList selectedEvent] = bw_readMACCSEventFile ( file )

    scrnsizes=get(0,'MonitorPosition');
    fg=figure('color','white','name','Event Selector','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 500 150]);
    
    triggerno = -1;
    trigvals = [];
    trignames = [];

    lattemp=importdata(file);
    latencyList=lattemp.data(:,1);

    
    Trigger_popup = uicontrol('style','popup','units','normalized',...
    'position',[0.1 0.55 0.35 0.05],'String','All events','Backgroundcolor','white','fontsize',12,...
    'value',1,'callback',@trigger_popup_callback);
        function trigger_popup_callback(src,evt)
            menu_select=get(src,'value');
            if menu_select > size(trigvals,1)
                triggerno = -1;
                latencyList=lattemp.data(:,1);
            else
                triggerno = trigvals(menu_select,:);
                idx = find(lattemp.data(:,2)==triggerno);
                latencyList = lattemp.data(idx,1);
            end    
            str = sprintf('Number of Events = %d\n',length(latencyList));   
            set(MarkerCountText,'String',str);

        end
    
    str = sprintf('Number of Markers = %d\n',length(latencyList));   
    MarkerCountText = uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
    'position',[0.1 0.25 0.6 0.1],'String',str,'Backgroundcolor','white','fontsize',12);
                
    % get list of trigger numbers / names 
    [path name ext] = bw_fileparts(file);
    if ext == '.evt'
        t =importdata(file);
        triglist = t.data(:,2);
        trigvals = unique(triglist);
        trignames = [trigvals; cellstr('all')];
    elseif ext == '.mrk'
        markr =  textread(file,'%s','delimiter','\n');
        name_id = strmatch('NAME:',markr,'exact');
        trignames = markr(name_id+1);
    end      
    set(Trigger_popup,'String',trignames,'value',1);  

    % ** initialize to menu item one in case user just hits OK
   
    % initialize list to first marker
    if ~isempty(latencyList)
        triggerno = trigvals(1,:);
        idx = find(lattemp.data(:,2)==triggerno);
        latencyList = lattemp.data(idx,1);
        str = sprintf('Number of Events = %d\n',length(latencyList));   
        set(MarkerCountText,'String',str);
    end          
   
    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.6 0.4 0.25 0.25],'string','OK','backgroundcolor','white',...
        'foregroundcolor','black','callback',@ok_callback);
    function ok_callback(src,evt)
        idx = get(Trigger_popup,'val');
        if idx > size(trigvals,1)
            txt = 'all';
        else
            n = trigvals(idx,:);
            txt = num2str(n);
        end
        selectedEvent = sprintf('%s',txt);        
        uiresume(gcf);
    end
    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
end