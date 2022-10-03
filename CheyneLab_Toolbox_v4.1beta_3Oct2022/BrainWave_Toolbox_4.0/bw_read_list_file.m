function [filelist] = bw_read_list_file(listFile)
%       BW_READ_LIST_FILE
%
%   function [filelist] = bw_read_list_file(listFile)
%
%   DESCRIPTION: Turns text files (.txt) specified by listFile which 
%   contain a list of image filenames into a MATLAB readable array.
%
% (c) D. Cheyne, 2011. Hospital for Sick Kids.
% This program, along with all the BrainWave toolbox, has not been
% approved for clinical use. All users employ it at their own risk. 

%
%   --VERSION 1.2--
% Last Revised by N.v.L. on 23/06/2010
% Major Changes: Changed the help file.
%
% Last revised by N.v.L. on 17/05/2010
% Major Changes: Edited the help file.
%
% Written by D. Cheyne on --/--/---- for the Hospital for Sick Children.

fid = fopen(listFile,'r','b','latin1');

if (fid == -1)
    fprintf('Error reading text file %s\n', listFile);
    return;
end
numFiles = 0;
while (~feof(fid)) 
    s = fgets(fid);
    % ignore blank lines at end of file
    if (length(s) > 1)
        numFiles = numFiles + 1;
        s = deblank(s);  % remove any blank spaces;
        filelist(numFiles,:) = cellstr(s);
    end
end
fclose(fid);

return;