% from  https://github.com/Macquarie-MEG-Research/coreg/tree/master/realign_MEG_sensors
%
% Takes elp and hsp files for subject and returns struct with 
% pnt = digitized points, fid.pnt = all fiducials points, fid.label = names of
% all fiducials/surface coils. 
%
% For use in conversion of .con data to .ctf, only the fiducials are
% required (hfp file is unnecessary)
%
% D. Cheyne, Sept, 2018. renamed function to avoid conflict with original
% function (parsePolhemus). Also, don't need to save the shape data. 
%
function [shape] = readElpFile(elpfile)
        
        fid1 = fopen(elpfile);
        C = fscanf(fid1,'%c');
        fclose(fid1);
        
        E = regexprep(C,'\r','xx'); % replace each return with 'xx'
        E = regexprep(E,'\t','yy'); % replace each tab with 'yy'
        
        % get indexes for returns, tabs, sensors, and fiducials
        returnsi = strfind(E,'xx');
        tabsi = strfind(E,'yy');
        sensornamesi = strfind(E,'%N');
        fiducialsstarti = strfind(E,'%F');
        lastfidendi = strfind(E(fiducialsstarti(3):fiducialsstarti(length(fiducialsstarti))+100),'xx');
        fiducialsendi = fiducialsstarti(1)+strfind(E(fiducialsstarti(1):fiducialsstarti(length(fiducialsstarti))+lastfidendi(1)),'xx');
        
        % get coordinates for fiducials
        NASION = E(fiducialsstarti(1)+4:fiducialsendi(1)-2);
        NASION = regexprep(NASION,'yy','\t');
        NASION = str2num(NASION);
        
        LPA = E(fiducialsstarti(2)+4:fiducialsendi(2)-2);
        LPA = regexprep(LPA,'yy','\t');
        LPA = str2num(LPA);
        
        RPA = E(fiducialsstarti(3)+4:fiducialsendi(3)-2);
        RPA = regexprep(RPA,'yy','\t');
        RPA = str2num(RPA);
        
        % get coordinates for coils 1-5 (red, yellow, blue, white, and
        % black)
        LPAredstarti = strfind(E,'LPAred');
        LPAredendi = strfind(E(LPAredstarti(1):LPAredstarti(length(LPAredstarti))+45),'xx');
        LPAred = E(LPAredstarti(1)+11:LPAredstarti(1)+LPAredendi(2)-2);
        LPAred = regexprep(LPAred,'yy','\t');
        LPAred = str2num(LPAred);
        
        RPAyelstarti = strfind(E,'RPAyel');
        RPAyelendi = strfind(E(RPAyelstarti(1):RPAyelstarti(length(RPAyelstarti))+45),'xx');
        RPAyel = E(RPAyelstarti(1)+11:RPAyelstarti(1)+RPAyelendi(2)-2);
        RPAyel = regexprep(RPAyel,'yy','\t');
        RPAyel = str2num(RPAyel);
        
        PFbluestarti = strfind(E,'PFblue');
        PFblueendi = strfind(E(PFbluestarti(1):PFbluestarti(length(PFbluestarti))+45),'xx');
        PFblue = E(PFbluestarti(1)+11:PFbluestarti(1)+PFblueendi(2)-2);
        PFblue = regexprep(PFblue,'yy','\t');
        PFblue = str2num(PFblue);
        
        LPFwhstarti = strfind(E,'LPFwh');
        LPFwhendi = strfind(E(LPFwhstarti(1):LPFwhstarti(length(LPFwhstarti))+45),'xx');
        LPFwh = E(LPFwhstarti(1)+11:LPFwhstarti(1)+LPFwhendi(2)-2);
        LPFwh = regexprep(LPFwh,'yy','\t');
        LPFwh = str2num(LPFwh);
        
        RPFblackstarti = strfind(E,'RPFblack');
        RPFblackendi = strfind(E(RPFblackstarti(1):end),'xx');
        RPFblack = E(RPFblackstarti(1)+11:RPFblackstarti(1)+RPFblackendi(2)-2);
        RPFblack = regexprep(RPFblack,'yy','\t');
        RPFblack = str2num(RPFblack);
        
        FObluestarti = strfind(E,'FOblue');
        if isempty(FObluestarti) 
            
            allfids = [NASION;LPA;RPA;LPAred;RPAyel;PFblue;LPFwh;RPFblack];
            fidslabels = {'NASION';'LPA';'RPA';'LPAred';'RPAyel';'PFblue';'LPFwh';'RPFblack'};
        else
            
            FOblueendi = strfind(E(FObluestarti(1):end),'xx');
            FOblue = E(FObluestarti(1)+11:FObluestarti(1)+FOblueendi(2)-2);
            FOblue = regexprep(FOblue,'yy','\t');
            FOblue = str2num(FOblue);
            
            LOgreenstarti = strfind(E,'LOgreen');
            LOgreenendi = strfind(E(LOgreenstarti(1):end),'xx');
            LOgreen = E(LOgreenstarti(1)+11:LOgreenstarti(1)+LOgreenendi(2)-2);
            LOgreen = regexprep(LOgreen,'yy','\t');
            LOgreen = str2num(LOgreen);

            ROredstarti = strfind(E,'ROred');
            ROredendi = strfind(E(ROredstarti(1):end),'xx');
            ROred = E(ROredstarti(1)+11:ROredstarti(1)+ROredendi(2)-2);
            ROred = regexprep(ROred,'yy','\t');
            ROred = str2num(ROred);

            allfids = [NASION;LPA;RPA;LPAred;RPAyel;PFblue;LPFwh;RPFblack;FOblue;LOgreen;ROred];
            fidslabels = {'NASION';'LPA';'RPA';'LPAred';'RPAyel';'PFblue';'LPFwh';'RPFblack';'FOblue';'LOgreen';'ROred'};
        end
        
        shape.fid.pnt = allfids;
        shape.fid.label = fidslabels;

    end
