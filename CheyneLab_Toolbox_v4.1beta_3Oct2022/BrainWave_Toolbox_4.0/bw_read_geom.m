function data = bw_read_geom(Name)
%       BW_READ_GEOM
%
%   function data = bw_read_geom(Name)
%
%   DESCRIPTION: Reads the data contained in a .geom file and passes it
%   back as a MATLAB structure.
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% reads data in a .geom file and passes it back as a matlab structure

% [FileName,PathName] = uigetfile('*.geom','Select .geom file:');

%opening text file
fID=fopen(Name);

%initializing structure
data.channel=[];
data.gain1=[];
data.gain2=[];
data.numcoils=[];
data.turns=[];
data.area=[];
data.xposition=[];
data.yposition=[];
data.zposition=[];
data.xorientation=[];
data.yorientation=[];
data.zorientation=[];
data.turns2=[];
data.area2=[];
data.xposition2=[];
data.yposition2=[];
data.zposition2=[];
data.xorientation2=[];
data.yorientation2=[];
data.zorientation2=[];

%skipping header lines
garbage=fscanf(fID,'%s #\n');
data.creation=fgetl(fID);
garbage=fscanf(fID,'%s #\n');
data.header=fgetl(fID);

%grabbing values from text file and putting into structure
while feof(fID) == 0 %feof=check for End Of File
    data.channel=[data.channel;fscanf(fID,'%s/t')];
    data.gain1=[data.gain1;fscanf(fID,'%e/t')];
    data.gain2=[data.gain2;fscanf(fID,'%e/t')];
    data.numcoils=[data.numcoils;fscanf(fID,'%d/t')];
    data.turns=[data.turns;fscanf(fID,'%d/t')];
    data.area=[data.area;fscanf(fID,'%e/t')];
    data.xposition=[data.xposition;fscanf(fID,'%e/t')];
    data.yposition=[data.yposition;fscanf(fID,'%e/t')];  
    data.zposition=[data.zposition;fscanf(fID,'%e/t')];
    data.xorientation=[data.xorientation;fscanf(fID,'%e/t')];
    data.yorientation=[data.yorientation;fscanf(fID,'%e/t')];
    data.zorientation=[data.zorientation;fscanf(fID,'%e/t')];
    data.turns2=[data.turns2;fscanf(fID,'%d/t')];
    data.area2=[data.area2;fscanf(fID,'%e/t')];
    data.xposition2=[data.xposition2;fscanf(fID,'%e/t')];
    data.yposition2=[data.yposition2;fscanf(fID,'%e/t')];
    data.zposition2=[data.zposition2;fscanf(fID,'%e/t')];
    data.xorientation2=[data.xorientation2;fscanf(fID,'%e/t')];
    data.yorientation2=[data.yorientation2;fscanf(fID,'%e/t')];
    data.zorientation2=[data.zorientation2;fscanf(fID,'%e/t')];
end

%closing text file
fclose(fID);

end