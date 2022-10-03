function bw_about
%       BW_ABOUT
%
%   function bw_about
%
%   DESCRIPTION: Creates a GUI about the Brainwave toolbox including the 
%   copyright, authors and acknowledgements.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%   D. Cheyne - Nov 2010 - read about info from text file
%% FIGURE

global BW_VERSION;

% crazy way Matlab reads text from a file...
fid = fopen('bw_about_Brainwave.txt','r');
C = textscan(fid,'%s','delimiter', '\n');
ABOUT_STR = C{:};
fclose(fid);

fid = fopen('bw_about_Contributors.txt','r');
C = textscan(fid,'%s','delimiter', '\n');
CONTRIB_STR = C{:};
fclose(fid);

scrnsizes=get(0,'MonitorPosition');

f=figure('Name', '','Position', [scrnsizes(1,3)/4 scrnsizes(1,4)/7 850 700],...
        'menubar','none','numbertitle','off', 'Color','white');

%% UICONTROLS
    version_string = sprintf('BrainWave\n Version: %s', BW_VERSION);
    title=uicontrol('style','text','units','normalized','position',[0.25 0.9 0.45 0.08],...
        'fontweight','b','foregroundcolor',[0.93,0.5,0.15],'fontsize',14,'backgroundcolor','white','string',version_string);
    
    copyrighttitle=uicontrol('style','text','units','normalized','position',[0.03 0.87 0.18 0.03],...
         'fontweight','b','fontsize',11,'foregroundcolor','blue','backgroundcolor','white','string','About Brainwave');
    copyrighttext=uicontrol('style','text','units','normalized','position',[0.05 0.58 0.85 0.28],...
        'fontsize',9,'fontname','lucinda','HorizontalAlignment','left', 'backgroundcolor','white','string',ABOUT_STR);
    copyrightbox=annotation('rectangle',[0.02 0.56 0.95 0.325],'EdgeColor','blue');
    
    
    programmerstitle=uicontrol('style','text','units','normalized','position',[0.03 0.51 0.2 0.03],...
        'fontweight','b','fontsize',11,'backgroundcolor','white','foregroundcolor','blue','string','Acknowledgements');
    programmerstext=uicontrol('style','text','units','normalized','position',[0.05 0.235 0.85 0.27],...
        'fontsize',9,'fontname','lucinda','HorizontalAlignment','left','backgroundcolor','white','string',CONTRIB_STR);
    programmersbox=annotation('rectangle',[0.02 0.225 0.95 0.3],'EdgeColor','blue');
    
    
    
    contacttitle=uicontrol('style','text','units','normalized','position',[0.03 0.125 0.1 0.03],...
        'fontweight','b','fontsize',11,'backgroundcolor','white','foregroundcolor','blue','string','Contact');
    CONTACT_STR = {'For information or program updates contact:','','brainwave.megsoftware@gmail.com    http://cheynelab.utoronto.ca'};
    contacttext=uicontrol('style','text','units','normalized','position',[0.03 0.04 0.55 0.08],...
        'fontsize',10,'fontname','lucinda','HorizontalAlignment','left','backgroundcolor','white','string',CONTACT_STR);
    contactbox=annotation('rectangle',[0.02 0.04 0.6 0.1],'EdgeColor','blue');

%% LOGO
    logo=imread('BRAINWAVE_LOGO_2.png');                                      
    axes('parent',f,'position',[0.7 0.02 0.23 0.20]);                  
    image(logo)                                                                  
    axis off    
    
end