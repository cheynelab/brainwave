function [peak_voxel]=bw_find_peaks(voxel_vals,thresh_val,thresh_limit,max_peaks)
%       BW_FIND_PEAKS
%
%   function [peak_voxel]=bw_find_peaks(voxel_vals,thresh_val,thresh_limit)
%
%   DESCRIPTION: The function will step through the xyz voxels and 
%   amplitudes specified in voxel_vals and using the minimum amplitude 
%   specified by thresh_val and the minimum number of voxels between peaks
%   specified by thresh_limit the function will find the peak voxel
%   (peak_voxel).
%
% (c) D. Cheyne, 2011. All rights reserved. Originally written by A.
% Herdman. This software is for RESEARCH USE ONLY. Not approved for
% clinical use.

%%
%   --VERSION 2.1--
% Last Revised by N.v.L. on 23/06/2010
% Major Changes: Edited the help file again.
%
% Revised by N.v.L. on 17/05/2010
% Major Changes: edited help file.
%
% Revised by D. Cheyne on --/01/2010
% Major Changes: modified and renamed routine. Added initialization of peak_voxel array at top of routine so that error is generated if no peaks are found...
% 
% D. Cheyne Dec, 2016 - max peaks option to avoid program hanging when
% threshold is set too low.
% Written by A. Herdman on 30/06/2005 for HSC


peak_voxel = [];

voxel_abs=voxel_vals;
voxel_abs(:,4)=abs(voxel_vals(:,4));

[lv_idx]=find(voxel_abs(:,4)>thresh_val);
voxel_lv=voxel_abs(lv_idx,:);
voxel_org=voxel_vals(lv_idx,:);

p=0;

for n=1:size(voxel_lv,1) 
	vox_roi=voxel_lv(n,:);
	vox_roi_org=voxel_org(n,:);

	[roi_idx,z,zz]=find((voxel_lv(:,1)< vox_roi(1,1)+thresh_limit & voxel_lv(:,1)>vox_roi(1,1)-thresh_limit)...
      	  	& (voxel_lv(:,2)< vox_roi(1,2)+thresh_limit & voxel_lv(:,2)>vox_roi(1,2)-thresh_limit)...
     	   	& (voxel_lv(:,3)< vox_roi(1,3)+thresh_limit & voxel_lv(:,3)>vox_roi(1,3)-thresh_limit));

	if vox_roi(1,4)==max(voxel_lv(roi_idx,4))
		p=p+1;
% 		fprintf(1,'Number of peaks = %.f\n',p);
		peak_voxel(p,:)=vox_roi_org;
        if p > max_peaks
            return;
        end
	end
end


