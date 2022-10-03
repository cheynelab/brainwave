%   Renamed version of Matthew Brett's mni2tal
%
%   --VERSION 2.1--
% Last Revised by N.v.L. on 23/06/2010
% Major Changes: Edited the help file.
%
% Revised by N.v.L. on 12/05/2010
% Major Changes: Changed the help file.
%
% Written by M. Brett on 10/08/2010
function outpoints = bw_mni2tal(inpoints)    

dimdim = find(size(inpoints) == 3);
if isempty(dimdim)
  error('input must be a N by 3 or 3 by N matrix')
end
if dimdim == 2
  inpoints = inpoints';
end

% Transformation matrices, different zooms above/below AC
upT = spm_matrix([0 0 0 0.05 0 0 0.99 0.97 0.92]);
downT = spm_matrix([0 0 0 0.05 0 0 0.99 0.97 0.84]);

tmp = inpoints(3,:)<0;  % 1 if below AC
inpoints = [inpoints; ones(1, size(inpoints, 2))];
inpoints(:, tmp) = downT * inpoints(:, tmp);
inpoints(:, ~tmp) = upT * inpoints(:, ~tmp);
outpoints = inpoints(1:3, :);
if dimdim == 2
  outpoints = outpoints';
end