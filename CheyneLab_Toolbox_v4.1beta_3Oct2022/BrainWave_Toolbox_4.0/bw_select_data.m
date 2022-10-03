function [badchanposition, menuSelect, valid] = bw_select_data(dsName, old_badchanposition, menuSelect)
% 
% Version 3.3 - add options for custom lists
%
% (c) D. Cheyne, 2011. Hospital for Sick Kids.

global defaultPrefsFile

scrnsizes=get(0,'MonitorPosition');

valid = 0; 

fh = figure('color','white','name','Brainwave - Channel Selection',...
    'numbertitle','off', 'Position', [scrnsizes(1,4)/2 scrnsizes(1,4)/2  700 700], 'closeRequestFcn', @cancel_button_callBack);
if ispc
    movegui(fh,'center');
end
[pathstr,name,ext] = bw_fileparts(dsName);

badchanposition = old_badchanposition;

if strcmp(ext,'.ds')   
   [longNames position sensorType] = bw_CTFGetSensors(dsName, 0);
   channelNames = bw_truncateSensorNames(longNames);
elseif strcmp(ext,'.geom')
   datastructure=bw_read_geom(dsName);
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
set(gca,'xtick',[],'ytick',[],'ztick',[]);
view(-90,90) 
   

displaylistbox=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized',...
    'Position',[0.05 0.05 0.4 0.35],'HorizontalAlignment',...
    'Center','BackgroundColor','White','max',10000,'Callback',@displaylistbox_callback);

hidelistbox=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized',...
    'Position',[0.55 0.05 0.4 0.35],'HorizontalAlignment',...
    'Center','BackgroundColor','White','max',10000,'Callback',@hidelistbox_callback);

channeltext=uicontrol('style','text','fontsize',12,'units','normalized',...
    'position',[0.06 0.5 0.2 0.05],'string','Channel List:','HorizontalAlignment',...
    'left','backgroundcolor','white');

includetext=uicontrol('style','text','fontsize',12,'units','normalized',...
    'position',[0.05 0.42 0.25 0.02],'string','Included Channels:','HorizontalAlignment',...
    'left','backgroundcolor','white');
excludetext=uicontrol('style','text','fontsize',12,'units','normalized',...
    'position',[0.55 0.42 0.25 0.02],'string','Excluded Channels:','HorizontalAlignment',...
    'left','backgroundcolor','white');


%%%%%%%%%%%%
% init flags
goodChans = {};
badChans = {};
channelExcludeFlags = zeros(size(channelNames,1),1);
channelExcludeFlags(badchanposition) = 1;

updateChannelLists;

% get saved channel sets
prefs = bw_readPrefsFile(defaultPrefsFile);

if isfield(prefs,'channelLists')
    channelLists = prefs.channelLists;
else
    channelLists = [];
end
   
numDefaultChanList = 9;

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

        badchanposition=find(channelExcludeFlags == 1);
        goodchanposition=find(channelExcludeFlags == 0);

        cla;
        h=plot3(position(:,1),position(:,2),position(:,3));
        hold on
        set(h,'LineStyle','none','marker','o')
        set(gca,'xtick',[],'ytick',[],'ztick',[])      

        h=plot3(position(badchanposition,1),position(badchanposition,2),position(badchanposition,3));
        hold on
        set(h,'markerfacecolor',[0.5,0.5,0.5],'marker','o','LineStyle','none')
        set(gca,'xtick',[],'ytick',[],'ztick',[])
        
%         h=plot3(position(goodchanposition,1),position(goodchanposition,2),position(goodchanposition,3));
%         hold on
%         set(h,'markerfacecolor',[1,0,0],'marker','o','LineStyle','none')
%         set(gca,'xtick',[],'ytick',[],'ztick',[]) 
%         
        h=plot3(position(selectedChans,1),position(selectedChans,2),position(selectedChans,3));
        hold on
        set(h,'markerfacecolor',[1,0,0],'marker','o','LineStyle','none')
        set(gca,'xtick',[],'ytick',[],'ztick',[])

    end

    function hidelistbox_callback(src,evt)
    end


right_arrow=draw_rightarrow;
tohidearrow=uicontrol('Style','pushbutton','FontSize',10,'Units','Normalized',...
    'Position',[0.46 0.3 0.08 0.05],'CData',right_arrow,'HorizontalAlignment',...
    'Center','BackgroundColor','White','Callback',@tohidearrow_callback);
left_arrow=draw_leftarrow;
todisplayarrow=uicontrol('Style','pushbutton','FontSize',10,'Units','Normalized',...
    'Position',[0.46 0.2 0.08 0.05],'CData',left_arrow,'HorizontalAlignment',...
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
            idx = find(strcmp(deblank(a),channelNames));
            channelExcludeFlags(idx) = 1;
        end
        updateChannelLists;

    end

    function todisplayarrow_callback(src,evt)
        idx=get(hidelistbox,'value');
        list = get(hidelistbox,'String');
        if isempty(list)
            return;
        end
        selected = list(idx,:);
        for i=1:size(selected,1)
            a = selected(i);
            idx = find(strcmp(deblank(a),channelNames));
            channelExcludeFlags(idx) = 0;
        end
        updateChannelLists;
                
    end

save_button = uicontrol('units','normalized','Position',[0.57 0.465 0.15 0.06],'String','Save List',...
              'BackgroundColor','white','FontSize',13,'ForegroundColor','black','callback',@save_button_callBack);
              
    function save_button_callBack(src,evt)
 
        listName = getListName;
        if isempty(listName)
            return;
        end
        
        % add to current channelLists structure and save in prefs
        listNo = size(channelLists,2) + 1;
        channelLists(listNo).name = listName;
        channelLists(listNo).list = get(displaylistbox,'String');  % save list of channel names           
        
        % save in prefs?
        %%%%%%%%%%%%%%%%
        prefs.channelLists = channelLists;
        
        fprintf('saving current settings to file %s\n', defaultPrefsFile)
        save(defaultPrefsFile, '-struct', 'prefs')    
            
        % add to menu
        buildChannelMenu;
        newlist = get(channel_popup,'String');
        menuSelect = size(newlist,1);
        
        updateMenuSelection(menuSelect);      

    end

delete_button = uicontrol('units','normalized','Position',[0.78 0.465 0.15 0.06],'String','Delete List','enable','off',...
              'BackgroundColor','white','FontSize',13,'ForegroundColor','black','callback',@delete_button_callBack);
              
    function delete_button_callBack(src,evt)
 
        idx = get(channel_popup,'value');  

        listNo = idx - numDefaultChanList;
        s = sprintf('Delete channel set [%s]?',char(channelLists(listNo).name));
        response = bw_warning_dialog(s);
        if response == 0
            return;
        end
        
        % delete list
        if size(channelLists,2) == 1
            channelLists = [];
        else    
            channelLists(listNo) = [];
        end

        prefs.channelLists = channelLists;
        
        fprintf('saving current settings to file %s\n', defaultPrefsFile)
        save(defaultPrefsFile, '-struct', 'prefs')    
        
        buildChannelMenu;
        
        % switch to default
        menuSelect = 1;
        updateMenuSelection(menuSelect);
               
    end

%Apply button
apply_button=uicontrol('Style','PushButton','FontSize',13,'Units','Normalized','Position',...
    [0.57 0.55 0.15 0.06],'String','Apply','HorizontalAlignment','Center',...
    'BackgroundColor',[0.99,0.64,0.3],'ForegroundColor','white','Callback',@apply_button_callback);

    function apply_button_callback(src,evt)
        badchanposition=find(channelExcludeFlags == 1);
        valid = 1;
        listIndex = get(channel_popup,'value');
        delete(fh);
    end

%Cancel button

cancel_button = uicontrol('units','normalized','Position',[0.78 0.55 0.15 0.06],'String','Cancel',...
              'BackgroundColor','white','FontSize',13,'ForegroundColor','black','callback',@cancel_button_callBack);
              
    function cancel_button_callBack(src,evt)
        badchanposition = old_badchanposition;
        valid = 0;
        delete(fh);
    end

%temp. text
temptext=uicontrol('style','text','units','normalized','position',[0.57 0.65 0.36 0.2],'string',...
    'Hint: Use options in Tools drop down menu to rotate and scale image.',...
    'Fontsize',11,'backgroundcolor','white','horizontalalignment','left');

%title
title=uicontrol('style','text','units','normalized','position',[0.1 0.95 0.8 0.04],...
        'String','Channel Selector','FontSize',20,'ForegroundColor',[0.93,0.6,0.2], 'HorizontalAlignment','center','BackGroundColor', 'white');

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
        goodchanposition=find(channelExcludeFlags == 0);

        cla;
        h=plot3(position(:,1),position(:,2),position(:,3));
        hold on
        set(h,'LineStyle','none','marker','o')
        set(gca,'xtick',[],'ytick',[],'ztick',[])      
          
        h=plot3(position(badchanposition,1),position(badchanposition,2),position(badchanposition,3));
        hold on
        set(h,'markerfacecolor',[0.5,0.5,0.5],'marker','o','LineStyle','none')
        set(gca,'xtick',[],'ytick',[],'ztick',[]) 
        
        h=plot3(position(goodchanposition,1),position(goodchanposition,2),position(goodchanposition,3));
        hold on
        set(h,'markerfacecolor',[1,0,0],'marker','o','LineStyle','none')
        set(gca,'xtick',[],'ytick',[],'ztick',[]) 
        
        s = sprintf('Included channels (%d):',goodChanCount);
        set(includetext,'string',s);

        s = sprintf('Excluded channels (%d):',badChanCount);
        set(excludetext,'string',s);
        
   end

channel_popup = uicontrol('style','popup','units','normalized',...
    'position',[0.05 0.45 0.35 0.06],'String',{}, 'Backgroundcolor','white','fontsize',12,...
    'value',1,'callback',@channel_popup_callback);

    function channel_popup_callback(src,evt)
        menuSelect=get(src,'value'); 
        updateMenuSelection(menuSelect);
    end


    function buildChannelMenu
        
        menuList = {'All Sensors';'All Sensors Left';'All Sensors Right';'All Magnetometers';'All Gradiometers';...
            'Magnetometers Left';'Magnetometers Right';'Gradiometers Left';'Gradiometers Right'};
        
        if ~isempty(channelLists)
            for j=1:size(channelLists,2)
                menuList{j+numDefaultChanList} = channelLists(j).name;
            end
        end
        set(channel_popup,'String',menuList);    
        set(channel_popup,'value',menuSelect);
        
    end

    function updateMenuSelection(idx)

        set(channel_popup,'value',menuSelect);
            
        % exclude all...
        for i=1:size(channelNames,1)    
            channelExcludeFlags(i) = 1;
        end
            
       switch idx
            case 1
                for i=1:size(channelNames,1)  
                    channelExcludeFlags(i) = 0;  % add grads
                end
            case 2  % left
                for i=1:size(channelNames,1)  
                    if (position(i,2) > 0);  channelExcludeFlags(i) = 0; end                
                end
            case 3  % right
                for i=1:size(channelNames,1)  
                    if (position(i,2) < 0);  channelExcludeFlags(i) = 0; end                
                end
            case 4  %  mags
                for i=1:size(channelNames,1)  
                    if (sensorType(i) == 4);  channelExcludeFlags(i) = 0; end
                end %         
            case 5  %  grads
                for i=1:size(channelNames,1)  
                    if (sensorType(i) == 5);  channelExcludeFlags(i) = 0; end
                end
            case 6  % left
                for i=1:size(channelNames,1)  
                    if (sensorType(i) == 4) && (position(i,2) > 0);  channelExcludeFlags(i) = 0; end                
                end
            case 7  % right
                for i=1:size(channelNames,1)  
                    if (sensorType(i) == 4) && (position(i,2) < 0);  channelExcludeFlags(i) = 0; end                
                end
            case 8  % left
                for i=1:size(channelNames,1)  
                    if (sensorType(i) == 5) && (position(i,2) > 0);  channelExcludeFlags(i) = 0; end                
                end
            case 9  % right
                for i=1:size(channelNames,1)  
                    if (sensorType(i) == 5) && (position(i,2) < 0);  channelExcludeFlags(i) = 0; end                
                end
           otherwise
                listNo = idx - numDefaultChanList;
                % read custom lists
                customList = channelLists(listNo).list;
                for j=1:size(customList,1)
                    a = customList(j);
                    idx(j) = find(strcmp( deblank(a), channelNames));
                end
                channelExcludeFlags(idx) = 0;
       end
       
       %update listbox
       updateChannelLists;
        
       if menuSelect > numDefaultChanList
           set(delete_button,'enable','on');
       else
           set(delete_button,'enable','off');
       end
    end

buildChannelMenu;

% set menu to passed selection
% if exist('menuSelect','var')
%     names = get(channel_popup,'String');
%     if menuSelect > size(names,1)
%         return;
%     end
%     updateMenuSelection(menuSelect);
%     
% end    
% 

% PAUSES MATLAB
uiwait(gcf);


% helper functions
function name = getListName
   name = [];
    
   fg=figure('color','white','name','Channel Lists','numbertitle','off','menubar','none','position',[100,900, 400 150]);

    uicontrol('style','text','units','normalized','HorizontalAlignment','Left',...
        'position',[0.05 0.7 0.4 0.2],'String','Enter Name for this List:','Backgroundcolor','white','fontsize',13);

    LIST_DLG = uicontrol('style','edit','units','normalized','HorizontalAlignment','Left',...
        'position',[0.05 0.25 0.4 0.3],'String','','Backgroundcolor','white','fontsize',13);

    uicontrol('style','pushbutton','units','normalized','position',...
        [0.5 0.25 0.2 0.3],'string','OK','backgroundcolor','white','callback',@ok_callback);
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.75 0.25 0.2 0.3],'string','Cancel','backgroundcolor','white','callback',@cancel_callback);

    function ok_callback(src,evt)    
        name = get(LIST_DLG,'string');
        uiresume(gcf);
    end

    function cancel_callback(src,evt)    
        uiresume(gcf);
    end

    %%PAUSES MATLAB
    uiwait(gcf);
    
    %%CLOSES GUI
    close(fg);  
end
    
end
