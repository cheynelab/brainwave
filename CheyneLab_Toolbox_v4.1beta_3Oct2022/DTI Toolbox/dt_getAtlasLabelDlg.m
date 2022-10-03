%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% function [labels, values] = dt_getAtlasLabelDlg( atlasFile )
%
% GUI to select one or more brainRegions from an atlas

% input:   name of an atlas file
%
% returns: selected labels and their corresponding values in the atlas
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [atlasFile, labels, values] = dt_getAtlasLabelDlg
     
    global atlasPath;

    labels = [];
    values = [];
    atlas_labels = {};
    atlas_values = [];
    atlasFile = [];
    
    scrnsizes=get(0,'MonitorPosition');

    fg=figure('color','white','name','Atlas Region Selector','numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 500 300]);
    
    selectedAtlas = 1;
    atlases = {'AAL1','AAL2','SPM Anatomy (JuBrain)'};

    
    uicontrol('style','text','units','normalized','position',[0.1 0.86 0.3 0.1],...
        'string','Atlas:','backgroundcolor','white','FontSize',11,'horizontalalignment','left');

    uicontrol('style','popup','units','normalized',...
        'position',[0.1 0.75 0.5 0.15],'String', atlases, 'Backgroundcolor','white','fontsize',12,...
        'value',selectedAtlas,'callback',@atlas_popup_callback);

        function atlas_popup_callback(src,~)
            menu_select=get(src,'value');
            selectedAtlas = menu_select;
            initAtlas;
        end
    

    uicontrol('style','text','units','normalized','position',[0.1 0.66 0.2 0.1],...
        'string','Brain Region:','backgroundcolor','white','FontSize',11,'horizontalalignment','left');
 
    nRegionsText = uicontrol('style','text','units','normalized','position',[0.1 0.0 0.4 0.1],...
        'string','','backgroundcolor','white','FontSize',11,'horizontalalignment','left');
   
    
    region_listbox=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized','Position',...
        [0.1 0.1 0.5 0.6],'String','','HorizontalAlignment','Center','min',1,'max',1000,...
        'BackgroundColor','white');        

    function initAtlas
        if selectedAtlas == 1
            [atlas_labels, atlas_values, atlasFile] = dt_get_AAL1_labels(atlasPath);          
            if ~isempty(atlas_labels)
                set(region_listbox,'string',atlas_labels);
            end
        elseif  selectedAtlas == 2
            [atlas_labels, atlas_values, atlasFile] = dt_get_AAL2_labels(atlasPath);          
            if ~isempty(atlas_labels)
                set(region_listbox,'string',atlas_labels);
            end     
        elseif  selectedAtlas == 3
            [jlabels, juBrainIndex, juBrainMPM, atlasFile] = dt_get_JuBrain_labels(atlasPath);
            atlas_labels = jlabels{1}'; 
            
            % need add labels for left and right
            
            if ~isempty(atlas_labels)
                set(region_listbox,'string',atlas_labels);
            end         
            atlas_values = [];
        end     
        s = sprintf('(total = %d)',size(atlas_labels,2));
        set(nRegionsText,'string',s);
    end

    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.3 0.2 0.15],'string','Select','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@ok_callback);
    
        function ok_callback(src,evt)
            idx = get(region_listbox,'val');
            labels = atlas_labels(idx);
            values = atlas_values(idx);
            uiresume(gcf);
        end

    cancel=uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.1 0.2 0.15],'string','Cancel','backgroundcolor','white',...
        'foregroundcolor','black','callback',@cancel_callback);
    
        function cancel_callback(src,evt)
            uiresume(gcf);
        end

    initAtlas;
    
    %%PAUSES MATLAB
    uiwait(gcf);
    %%CLOSES GUI
    close(fg);   
    
    
end
