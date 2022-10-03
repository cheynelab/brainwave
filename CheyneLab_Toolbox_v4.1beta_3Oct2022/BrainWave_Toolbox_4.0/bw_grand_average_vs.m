function bw_grand_average_vs(listFile, aveName)
%       BW_GRAND_AVERAGE_VS 
%
%   function bw_grand_average_vs(fileList, aveName)
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
% 
% script to average (and plot) a list of virtual sensor files in .ave
% format

filelist = bw_read_list_file(listFile);

numFiles = size(filelist,1);

% get time base from first file and check rest for compatibility
file = char( filelist(1,:) );
fprintf('reading vs file %s\n', file);
t = load(file);
timeVec = t(:,1)';
data = zeros(numFiles,length(timeVec));
data(1,:) = t(:,2)';

figure('Position',[300 700 900 600]);
subplot(2,1,1);

hold on;
for j=2:numFiles
    
    file = char( filelist(j,:) );
    fprintf('reading vs file %s\n', file);
    t = load(file);
    tt = t(:,1)';
    if ~isequal(tt,timeVec)
        fprintf('warning: time base of file differs from first file ... interpolating values...\n' );
        ytemp = t(:,2)';
        ttemp = t(:,1)';
        data(j,:) = interp1(ttemp, ytemp, timeVec);
    else
        data(j,:) = t(:,2)';
    end
    
end

plot(timeVec,data);
tt = legend(filelist, 'Location', 'SouthWest');
set(tt,'Interpreter','none');

ave = mean(data,1) ./ numFiles;

% legend
xlabel('Time (sec)');
ylabel('Amplitude');

% lines through origin
ax = axis;
line_h1 = line([0 0],[ax(3) ax(4)]);
set(line_h1, 'Color', [0 0 0]);
vertLineVal = 0;
if vertLineVal > ax(3) && vertLineVal < ax(4),
    line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
    set(line_h2, 'Color', [0 0 0]);
end

tstr = sprintf('All waveforms:%s  (n=%d)', listFile, numFiles);
tt = title(tstr);
set(tt,'Interpreter','none');

% plot average

subplot(2,1,2);

% 
plot(timeVec, ave);

% legend
xlabel('Time (sec)');
ylabel('Amplitude');

% lines through origin
ax = axis;
line_h1 = line([0 0],[ax(3) ax(4)]);
set(line_h1, 'Color', [0 0 0]);
vertLineVal = 0;
if vertLineVal > ax(3) && vertLineVal < ax(4),
    line_h2 = line([ax(1) ax(2)], [vertLineVal vertLineVal]);
    set(line_h2, 'Color', [0 0 0]);
end


if ~exist('aveName','var')
    [path name ext] = bw_fileparts(listFile);
    file = fullfile(path,name);
    file = strcat(file,'.ave');
else
    file = listFile;
end

tstr = sprintf('Grand Average:%s', file);
tt = title(tstr);
set(tt,'Interpreter','none');

% save average

fid = fopen(file,'w');
fprintf('Saving grand averaged data in file %s...\n', file);
for i=1:length(timeVec)
    fprintf(fid, '%.4f\t%g\n', timeVec(i), ave(i) );
end
fclose(fid);




return;


