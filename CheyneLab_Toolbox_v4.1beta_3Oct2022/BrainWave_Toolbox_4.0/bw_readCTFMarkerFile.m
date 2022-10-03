function [markerNames, markerData] = bw_readCTFMarkerFile( markerFile )
%
%   function bw_readCTFMarkerFile
%
%   DESCRIPTION: Reads a CTF Marker file
%
% (c) D. Cheyne, 2011. All rights reserved.
% adapted from Paul Ferrari's readmarkerfile.m script
%
%
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


markerData = [];
markerNames = [];

markr =  textread(markerFile,'%s','delimiter','\n');

% from Paul's script

number_markers_id = strmatch('NUMBER OF MARKERS:',markr,'exact');
markers = str2num(markr{number_markers_id+1});

% defines markers

number_samples_id = strmatch('NUMBER OF SAMPLES:',markr,'exact');
samples = str2num(char(markr(number_samples_id+1)));
% defines samples

% for i = 1:length(samples)
%     if samples(i) == 0
%         fprintf('Warning: Marker %d has no data!\n', i);
%     end
% end

name_id = strmatch('NAME:',markr,'exact');
names = markr(name_id+1);
% defines names

trial = strmatch('LIST OF SAMPLES',markr)+2;

%Identify only markers with data points
goodMrkIdx=find(samples>0);%find markers with data
samples=samples(goodMrkIdx);
markers=length(goodMrkIdx);
names=names(goodMrkIdx);
trial=trial(goodMrkIdx);

trials = {};
for i = 1:markers
    trials{i} = str2num(char(markr(trial(i):trial(i)+samples(i)))); 
    trials{i}(:,1) = trials{i}(:,1) + 1;
end

if ~isempty(trials)
    markerNames = names;
    markerData = trials;
end

