function [badchanposition] = sim_select_data(dsName,badchanposition)
%   copied from  BW_SELECT_DATA
%
%   function [badchan badchanposition] = sim_select_data(dsName,badchan,badchanposition)
%
%   DESCRIPTION: Creates a GUI that allows the user to select the bad
%   channels from a .ds or .geom dataset indicated by dsName and returns an
%   array of their names (badchan) and their positions on the channel list
%   (badchanposition).
%
% (c) D. Cheyne, 2011. Hospital for Sick Kids. Written by N. van Lieshout.
% This program, along with all the BrainWave toolbox, has not been
% approved for clinical use. All users employ it at their own risk. 

scrnsizes=get(0,'MonitorPosition');

fh = figure('color','white','name','Brainwave - Channel Selection',...
    'numbertitle','off', 'Position', [scrnsizes(1,4)/2 scrnsizes(1,4)/2  700 700], 'closeRequestFcn', @cancel_button_callBack);

[pathstr,name,ext] = fileparts(dsName);

if strcmp(ext,'.ds')   
   ctf_header = sim_CTFGetHeader(dsName);
   isSensorMat = arrayfun(@(x) double(x.isSensor), ctf_header.channel);
   longNames = char({ctf_header.channel(find(isSensorMat)).name});
   sensorPos(:,1) = arrayfun(@(x) double(x.xpos), ctf_header.channel);
   sensorPos(:,2) = arrayfun(@(x) double(x.ypos), ctf_header.channel);
   sensorPos(:,3) = arrayfun(@(x) double(x.zpos), ctf_header.channel);
   position = sensorPos(find(isSensorMat),:);
   sensorType = arrayfun(@(x) double(x.sensorType), ctf_header.channel(find(isSensorMat)))';
   clear sensorPos;
   channelNames = sim_truncateSensorNames(longNames);
elseif strcmp(ext,'.geom')
   datastructure=sim_read_geom(dsName);
   channelNames=datastructure.channel;
   position=[datastructure.xposition,datastructure.yposition,datastructure.zposition];
   sensorType = ones(1,size(channelNames,1)) * 5;  % for now Yokogawa is always gradiometer system
else
   return;
end

% plot
subplot(2,2,1)
p=plot3(position(:,1),position(:,2),position(:,3));
hold on
set(p,'LineStyle','none','marker','o')
set(gca,'xtick',[],'ytick',[],'ztick',[])
   

displaylistbox=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized',...
    'Position',[0.05 0.05 0.4 0.25],'HorizontalAlignment',...
    'Center','BackgroundColor','White','max',10000,'Callback',@displaylistbox_callback);

hidelistbox=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized',...
    'Position',[0.55 0.05 0.4 0.25],'HorizontalAlignment',...
    'Center','BackgroundColor','White','max',10000,'Callback',@hidelistbox_callback);

%%%%%%%%%%%%
% init flags
goodChans = {};
badChans = {};
channelExcludeFlags = zeros(size(channelNames,1),1);
channelExcludeFlags(badchanposition) = 1;
updateChannelLists;


    function displaylistbox_callback(src,evt)       
        idx=get(src,'value');
        list = get(src,'String');
        if isempty(list)
            return;
        end
        selected = list(idx,:);
        chanCount = 0;
        for i=1:size(selected,1)
            a = selected(i);
            chanCount = chanCount + 1;
            selectedChans(chanCount) = find(strcmp(deblank(a),channelNames));  
        end
        
        cla;
        h=plot3(position(:,1),position(:,2),position(:,3));
        hold on
        set(h,'LineStyle','none','marker','o')
        set(gca,'xtick',[],'ytick',[],'ztick',[])      
          
        h=plot3(position(selectedChans,1),position(selectedChans,2),position(selectedChans,3));
        hold on
        set(h,'markerfacecolor',[1,0.45,0],'marker','o','LineStyle','none')
        set(gca,'xtick',[],'ytick',[],'ztick',[])

        h=plot3(position(badchanposition,1),position(badchanposition,2),position(badchanposition,3));
        hold on
        set(h,'markerfacecolor',[0.5,0.5,0.5],'marker','o','LineStyle','none')
        set(gca,'xtick',[],'ytick',[],'ztick',[])
    end

    function hidelistbox_callback(src,evt)
    end

displaytext=uicontrol('style','text','fontsize',12,'units','normalized',...
    'position',[0.05 0.3 0.1 0.05],'string','Include:','HorizontalAlignment',...
    'left','backgroundcolor','white');
hidetext=uicontrol('style','text','fontsize',12,'units','normalized',...
    'position',[0.55 0.3 0.105 0.05],'string','Exclude:','HorizontalAlignment',...
    'left','backgroundcolor','white');

tohidearrow=uicontrol('Style','pushbutton','FontSize',10,'Units','Normalized',...
    'Position',[0.46 0.2 0.08 0.05],'String','==>','HorizontalAlignment',...
    'Center','BackgroundColor','White','Callback',@tohidearrow_callback);

todisplayarrow=uicontrol('Style','pushbutton','FontSize',10,'Units','Normalized',...
    'Position',[0.46 0.1 0.08 0.05],'String','<==','HorizontalAlignment',...
    'Center','BackgroundColor','White','Callback',@todisplayarrow_callback);

    function tohidearrow_callback(src,evt)
        idx=get(displaylistbox,'value');
        list = get(displaylistbox,'String');
        if isempty(list)
            return;
        end
        selected = list(idx,:);
        for i=1:size(selected,1)
            a = selected(i);
            index = find(strcmp(deblank(a),channelNames));
            channelExcludeFlags(index) = 1;
        end
        updateChannelLists;

%         h=plot3(position(badchanposition,1),position(badchanposition,2),position(badchanposition,3));
%         hold on
%         set(h,'markerfacecolor',[0.5,0.5,0.5],'marker','o','LineStyle','none')
%         set(gca,'xtick',[],'ytick',[],'ztick',[]) 
    end

    function todisplayarrow_callback(src,evt)
        idx=get(hidelistbox,'value');
        list = get(hidelistbox,'String');
        if isempty(list)
            return;
        end
        selected = list(idx,:);
        numselected = size(selected,1);
        for i=1:size(selected,1)
            a = selected(i);
            index = find(strcmp(deblank(a),channelNames));
            channelExcludeFlags(index) = 0;
        end
        updateChannelLists;
                
%         h=plot3(position(badchanposition,1),position(badchanposition,2),position(badchanposition,3));
%         hold on
%         set(h,'markerfacecolor',[0.5,0.5,0.5],'marker','o','LineStyle','none')
%         set(gca,'xtick',[],'ytick',[],'ztick',[]) 
    end


   function updateChannelLists
        goodChans = {};
        badChans = {};
        badChanCount = 0;
        goodChanCount = 0;
        for i=1:size(channelExcludeFlags,1)
            if channelExcludeFlags(i) == 1
                badChanCount = badChanCount + 1;
                badChans(badChanCount) = cellstr(channelNames(i,:));
            else
                goodChanCount = goodChanCount + 1;
                goodChans(goodChanCount) = cellstr(channelNames(i,:));
            end                
        end
        
        
        % make sure we are setting list beyond range.
        
        set(displaylistbox,'String',goodChans);
        set(hidelistbox,'String',badChans);   
         
        if ~isempty(goodChans)
            idx = get(displaylistbox,'value');
            if idx(end) > size(goodChans,2) && size(goodChans,2) > 0
                set(displaylistbox,'value',size(goodChans,2));
            end
        end
        
        if ~isempty(badChans)
       
            idx = get(hidelistbox,'value');
            if idx(end) > size(badChans,2) && size(badChans,2) > 0
                set(hidelistbox,'value',size(badChans,2));
            end     
        end
        
        badchanposition=find(channelExcludeFlags == 1);

        cla;
        h=plot3(position(:,1),position(:,2),position(:,3));
        hold on
        set(h,'LineStyle','none','marker','o')
        set(gca,'xtick',[],'ytick',[],'ztick',[])      
          
        h=plot3(position(badchanposition,1),position(badchanposition,2),position(badchanposition,3));
        hold on
        set(h,'markerfacecolor',[0.5,0.5,0.5],'marker','o','LineStyle','none')
        set(gca,'xtick',[],'ytick',[],'ztick',[]) 
   end



selectAll=uicontrol('style','radio','fontsize',12,'units','normalized',...
    'position',[0.05 0.5 0.3 0.05],'string','all sensors','HorizontalAlignment',...
    'left','backgroundcolor','white', 'value',0,'Callback',@all_chan_callback);

selectMags=uicontrol('style','radio','fontsize',12,'units','normalized',...
    'position',[0.05 0.46 0.3 0.05],'string','magnetometers only','HorizontalAlignment',...
    'left','backgroundcolor','white', 'Callback',@mags_only_callback);

selectGrads=uicontrol('style','radio','fontsize',12,'units','normalized',...
    'position',[0.05 0.42 0.3 0.05],'string','gradiometers only','HorizontalAlignment',...
    'left','backgroundcolor','white', 'Callback',@grads_only_callback);

set(selectAll,'enable','off');
set(selectMags,'enable','off');
set(selectGrads,'enable','off');

hasMags = false;
hasGrads = false;

for n=1:size(channelNames,1)
    if sensorType(n) == 4 
        hasMags = true;
        break;
    end 
end
for n=1:size(channelNames,1)
    if sensorType(n) == 5 
        hasGrads = true;
        break;
    end 
end

if (hasMags && hasGrads)
    set(selectAll,'enable','on');
    set(selectMags,'enable','on');
    set(selectGrads,'enable','on');
elseif (hasMags)
    set(selectMags,'enable','on');
    set(selectMags,'value',1);
elseif (hasGrads)
    set(selectGrads,'enable','on');
    set(selectGrads,'value',1);
end    
    
    
    function all_chan_callback(src,evt)

        set(src,'value',1);
        set(selectMags,'value',0);
        set(selectGrads,'value',0);

        for i=1:size(channelNames,1)
            channelExcludeFlags(i) = 0;
        end
        
        updateChannelLists;
            
    end

    function mags_only_callback(src,evt)

        set(src,'value',1);
        set(selectAll,'value',0);
        set(selectGrads,'value',0);

        for i=1:size(channelNames,1)
            if sensorType(i) == 5
                channelExcludeFlags(i) = 1;
            end
            if sensorType(i) == 4
                channelExcludeFlags(i) = 0;
            end
        end
        updateChannelLists;


    end

    function grads_only_callback(src,evt)

        set(src,'value',1);
        set(selectAll,'value',0);
        set(selectMags,'value',0);
        
        for i=1:size(channelNames,1)
            if sensorType(i) == 5
                channelExcludeFlags(i) = 0;
            end
            if sensorType(i) == 4
                channelExcludeFlags(i) = 1;
            end
        end
        updateChannelLists;
        
    end


%Apply button
apply_button=uicontrol('Style','PushButton','FontSize',13,'Units','Normalized','Position',...
    [0.57 0.55 0.15 0.06],'String','Apply','HorizontalAlignment','Center',...
    'BackgroundColor',[0.99,0.64,0.3],'ForegroundColor','white','Callback',@apply_button_callback);

    function apply_button_callback(src,evt)
        
        badchanposition=find(channelExcludeFlags == 1);      
        delete(fh);
    end

%Cancel button

cancel_button = uicontrol('units','normalized','Position',[0.78 0.55 0.15 0.06],'String','Cancel',...
              'BackgroundColor','white','FontSize',13,'ForegroundColor','black','callback',@cancel_button_callBack);
              
    function cancel_button_callBack(src,evt)
        delete(fh);
    end

%temp. text
temptext=uicontrol('style','text','units','normalized','position',[0.57 0.65 0.36 0.2],'string',...
    'Hint: Use options in Tools drop down menu to rotate and scale image.',...
    'Fontsize',11,'backgroundcolor','white','horizontalalignment','left');

%title
title=uicontrol('style','text','units','normalized','position',[0.23 0.89 0.54 0.1],...
        'String','Channel Selector','FontSize',20,'ForegroundColor',[0.93,0.6,0.2], 'HorizontalAlignment','center','BackGroundColor', 'white');

% PAUSES MATLAB
uiwait(gcf);
    
end
