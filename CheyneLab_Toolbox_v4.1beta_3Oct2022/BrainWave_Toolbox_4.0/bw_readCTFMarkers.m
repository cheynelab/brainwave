%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% function [latencies markerName] = bw_readCTFMarkers( markerFileName )
% GUI to select a marker from CTF Marker.mrk file
%
% input:   name of a CTF MarkerFile (e.g., dsName/MarkerFile.mrk)
%
% returns: latencies and label for selected marker
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [latencies, markerName] = bw_readCTFMarkers( markerFileName )
 

    latencies = [];
    markerName = '';
                
    if ~exist(markerFileName,'file')
        errordlg('No marker file exists yet. Create or import latencies then save events as markers.');
        return;
    end
    
    scrnsizes=get(0,'MonitorPosition');

    fg=figure('color','white','name','Marker Selector','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 500 150]);
    
    
    Event_popup = uicontrol('style','popup','units','normalized',...
    'position',[0.1 0.55 0.35 0.05],'String','No events','Backgroundcolor','white','fontsize',12,'value',1,'callback',@event_popup_callback);
        
        function event_popup_callback(src,~)
            menu_select=get(src,'value');
            t = trials{menu_select};
            latencies = t(:,2);
            str = sprintf('Number of Events = %d\n',length(latencies));   
            set(MarkerCountText,'String',str);

        end

    str = sprintf('Number of Markers = %d\n',length(latencies));   
    MarkerCountText = uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
    'position',[0.1 0.25 0.6 0.1],'String',str,'Backgroundcolor','white','fontsize',12);
   
    [names, trials] = bw_readCTFMarkerFile( markerFileName );
   
    % initialize list to first marker
    if ~isempty(names)
        set(Event_popup,'String',names,'value',1);  
        t = trials{1};
        latencies = t(:,2);
        str = sprintf('Number of Events = %d\n',length(latencies));   
        set(MarkerCountText,'String',str);
    end      

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.6 0.6 0.25 0.25],'string','OK','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@ok_callback);
    
    function ok_callback(~,~)
        idx = get(Event_popup,'val');
        if ~isempty(names)
            txt = names(idx);
            markerName = sprintf('%s',char(txt));
        end
        uiresume(gcf);
    end

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.6 0.2 0.25 0.25],'string','Cancel','backgroundcolor','white',...
        'foregroundcolor','black','callback',@cancel_callback);
    
    function cancel_callback(~,~)
        latencies = [];
        uiresume(gcf);
    end
    
    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
    
    
end
