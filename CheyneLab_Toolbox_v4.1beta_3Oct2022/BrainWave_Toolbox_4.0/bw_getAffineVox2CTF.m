function M = bw_getAffineVox2CTF(nasion_pos, left_preauricular_pos, right_preauricular_pos, mmPerVoxel )
%      BW_GETAFFINEVOX2CTF
%
%   function M = bw_getAffineVox2CTF(nasion_pos, left_preauricular_pos, right_preauricular_pos, mmPerVoxel )
%
%   DESCRIPTION: Takes the voxel coordinates of fiducial points 
%   (nasion_pos, left_preauricular_pos, right_preauricular_pos) and the 
%   scaling factor (mmPerVoxel) from an isotropic MRI and returns the 4 by 
%   4 affine transformation matrix (M) that is capable of transforming a 
%   point from voxel coordinates to CTF head coordinates.
%
% (c) D. Cheyne, 2011. All rights reserved.
% 
%  
% This software is for RESEARCH USE ONLY. Not approved for clinical use.


% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% written by D. Cheyne.  September 2006
%
% this script takes as input the voxel coordinates of the fiducial points
% and the scaling factor from mm to voxel dimensions, assuming that
% scaling is the same in all directions (isotropic  MRI), and returns the
% 4x4 affine tranformation matrix that converts a point in voxel
% coordinates to CTF head coordinates 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% build CTF coordinate system
% origin is midpoint between ears
origin = (left_preauricular_pos + right_preauricular_pos) /2;

% x axis is vector from this origin to Nasion
x_axis = nasion_pos - origin; 
x_axis=x_axis/norm(x_axis);

% y axis is origin to left ear vector
y_axis= left_preauricular_pos - origin;
y_axis=y_axis/norm(y_axis);

% This y-axis is not necessarely perpendicular to the x-axis, this corrects
z_axis=cross(x_axis,y_axis);
z_axis=z_axis/norm(z_axis);

y_axis=cross(z_axis,x_axis);
y_axis=y_axis/norm(y_axis);

% now build 4 x 4 affine transformation matrix

% rotation matrix is constructed from principal axes as unit vectors
% note transpose for correct direction of rotation 
rmat = [ [x_axis 0]; [y_axis 0]; [z_axis 0]; [0 0 0 1] ]';

% scaling matrix from mm to voxels
smat = diag([mmPerVoxel mmPerVoxel mmPerVoxel 1]);

% translation matrix - subtract origin
tmat = diag([1 1 1 1]);
tmat(4,:) = [-origin, 1];

% affine transformation matrix for voxels to CTF is concatenation of these
% three transformations. Order of first two operations is important. Since
% the origin is in units of voxels we must subtract it BEFORE scaling. Also
% since translation vector is in original coords must be also be rotated in
% order to rotate and translate with one matrix operation

M = tmat * smat * rmat;

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




