function aveFileName = bw_grand_average_surface_files(listFile)
%
%   function bw_grand_average_surface_files(listFile)
%
%   DESCRIPTION: Grand averages the given list of images saved as ascii
%   text files (e.g., when using vox file meshes
%
% (c) D. Cheyne, 2013. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% get array of file names to process

filelist = bw_read_list_file(listFile);
numSubjects = size(filelist,1);

% check file length
file = char( filelist(1,:) );
t = load(file);
ave = zeros(length(t),1);

for j=1:numSubjects
    file = char( filelist(j,:) );
    t = load(file);
    ave = ave + t;
end
ave = ave ./ numSubjects;

aveFileName = strrep(listFile,'.list','.txt');

fprintf('saving average in file %s\n', aveFileName);

dlmwrite(aveFileName,ave,'delimiter','\n','precision','%.6f');

end

