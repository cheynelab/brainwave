function [PATHSTR,NAME,EXT] = bw_fileparts(filename)
%       BW_FILEPARTS
%
%   function [PATHSTR,NAME,EXT] = bw_fileparts(filename)
%
%   DESCRIPTION: Because fileparts has different syntax in R2007b and
%   before this function was created to use the right syntax regardless of
%   version. For more information type "help fileparts".
%
% (c) D. Cheyne, 2011. All rights reserved. Written by N. van Lieshout.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


if verLessThan('matlab','7.11')
    [PATHSTR,NAME,EXT,VERSN] = fileparts(filename);
else
    [PATHSTR,NAME,EXT] = fileparts(filename);
end

end