function [response] = bw_warning_dialog(message, yesStr, noStr)
%       BW_WARNING_DIALOG
%
%   function bw_warning_dialog(starthandle)
%
%   DESCRIPTION: Creates a GUI that requests whether users are sure they
%   wish to close all BrainWave GUIs by closing the BrainWave start GUI.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


%figure

if ~exist('yesStr','var')
    yesStr = 'Yes';
end
if ~exist('noStr','var')
    noStr = 'No';
end


scrnsizes=get(0,'MonitorPosition');
response = 0;
fg=figure('Name', 'BrainWave - Alert', 'Position', [scrnsizes(1,3)/3 scrnsizes(1,4)/2 600 140],...
    'menubar','none','numbertitle','off', 'Color','white');

%warning image
warningpic=imread('warning.jpg');
axes('parent',fg,'position',[0.03 0.15 0.12 0.35]);
image(warningpic);
axis off;

uicontrol('style','text','fontsize',12,'Units','Normalized','Position',...
    [0.05 0.6 0.9 0.3],'String',message,'BackgroundColor','White','HorizontalAlignment','left');

%buttons
yes_button=uicontrol('style','pushbutton','fontsize',10,'units','normalized','position',...
    [0.365 0.1 0.2 0.3],'string',yesStr,'Backgroundcolor','white','foregroundcolor',[0.8,0.4,0.1],'callback',@yes_button_callback);

    function yes_button_callback(src,evt)
        response = 1;
        uiresume(gcf);
    end   
no_button=uicontrol('style','pushbutton','fontsize',10,'units','normalized','position',...
    [0.65 0.1 0.2 0.3],'string',noStr,'Backgroundcolor','white','callback',@no_button_callback);

    function no_button_callback(src,evt)
        response = 0;
        uiresume(gcf);
    end

uiwait(gcf);

if ishandle(fg)
    close(fg);   
end

end

