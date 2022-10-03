function [origin, radius] = bw_fitSphere(points, startParams)
%       BW_FITSPHERE
%
%   function [origin, radius] = bw_fitSphere(points, startParams)
%
%   DESCRIPTION: Taking an n x 3 array of points (points) and set of 
%   standard parameters including average origin coordinates and radius 
%   (startParams), this function will fit a sphere to these points which is
%   output as the sphere's origin and radius. 
%
% (c) D. Cheyne, 2011. All rights reserved.
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% fitSphere Version 1.0
% written by D. Cheyne, November, 2006
%
% function to fit a sphere to an arry of 3D points
%
% Input:  
% points: An n x 3  array of locations to fit to. 
%
% Output: 
% [origin, radius]  These are the fitted origin and radius of the sphere
% in the same units as the passed array of points.
%  
% 
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% we need to define an error function for Simplex fit
%
% error function computes the mean of the absolute differences between the 
% length of each vector from fitted origin to each point and the sphere 
% radius. Takes as input start parameters for Simplex in vec = [x y z R]
% and points = matrix of N x 3 vectors that are the points to fit to. 

errFun = @(vec, points) ( mean(abs( (sqrt(sum( (points - ones(size(points,1),1)*vec(1:3)).^2,2))') - vec(4))) );

if ~exist('startParams','var')
    % if no start params passed, 
    % use the centroid of the points and mean radius 
    x = mean(points(:,1));
    y = mean(points(:,2));
    z = mean(points(:,3));
    R = mean(sqrt(sum(points.^2,2))');
else
    x = startParams(1);
    y = startParams(2);  
    z = startParams(3);    
    R = startParams(4);     
end

vec = [x, y, z, R];
    
% call Matlab's built-in Simplex minimization function
options = optimset('MAXFUNEVALS',5000,'MAXITER',1000);
[vecout] = fminsearch(errFun, vec, options, points);

origin = vecout(1:3);
radius = vecout(4);

end