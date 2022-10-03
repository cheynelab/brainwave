function [condName, condIdx, dsList] = bw_getConditionList(label, studyName)

   dsList = [];
   condName = [];
   condIdx = 1;
   
   if ~exist('studyName','var')
       [name path garbaged]=uigetfile({'*_STUDY.mat', 'GROUP STUDY (*STUDY.mat)'},'Select a STUDY');
        if isequal(name,0)
            return;
        end
       studyName = fullfile(path,name);       
   end
   
    if ~exist('label','var')
        label = sprintf('Select Condition');
    end
    
   study = load(studyName);
   
   scrnsizes=get(0,'MonitorPosition');
   fg=figure('color','white','name',label,'numbertitle','off','menubar','none','position',[300 (scrnsizes(1,4)-300) 500 150]);

   CONDITION1_DROP_DOWN = uicontrol('style','popup','units','normalized',...
        'position',[0.1 0.55 0.35 0.05],'String','','Backgroundcolor','white','fontsize',12,...
        'value',1,'callback',@condition_popup_callback);

   set(CONDITION1_DROP_DOWN,'string',study.conditionNames);

    condIdx = get(CONDITION1_DROP_DOWN,'val');
    dsList = study.conditions{condIdx};
    s = sprintf('Number of datasets = %d', size(dsList,2) );

    ok=uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.6 0.25 0.25],'string','OK','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@ok_callback);

    cancel=uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.2 0.25 0.25],'string','Cancel','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@cancel_callback);

    condString=uicontrol('style','text','units','normalized','position',...
        [0.1 0.05 0.5 0.25],'string',s,'backgroundcolor','white','fontsize',12,'horizontalalignment','left',...
        'foregroundcolor','blue','callback',@condition_popup_callback);

    function condition_popup_callback(src,evt)
        condIdx = get(CONDITION1_DROP_DOWN,'val');
        dsList = study.conditions{condIdx};
        s = sprintf('Number of datasets = %d', size(dsList,2) );
        set(condString,'string',s);
    end
    
    function ok_callback(src,evt)
        condIdx = get(CONDITION1_DROP_DOWN,'val');
        dsList = study.conditions{condIdx};
        condName = study.conditionNames{condIdx};
        uiresume(gcf);
    end

    function cancel_callback(src,evt)
        uiresume(gcf);
    end

    uiwait(gcf);
    %%CLOSES GUI
    close(fg); 
end

