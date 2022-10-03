function [peak_voxels]=bw_find_peaks2(voxList,thresh,SR,max_peaks)

%   DESCRIPTION: The function will step through the xyz voxels and 
%   amplitudes specified in voxList and using the minimum amplitude 
%   specified by thresh (threshold) and the minimum number of voxels between peaks
%   specified by SR (search radius) the function will find the specified max number
%   (max_peaks) of peak voxels (peak_voxels).
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
% Major Changes: modified and renamed routine. Added initialization of peak_voxels array at top of routine so that error is generated if no peaks are found...
%
%
% Revised Oct 2016 by Sabah Master - added max_peaks option to avoid
% hanging if threshold is too low...
%
% Original version written by A. Herdman on 30/06/2005 for HSC


peak_voxels = [];

%Step 1: Rectify voxList 

voxel_abs=voxList;
voxel_abs(:,4)=abs(voxList(:,4));

%Step 2: Remove values below threshold (thresh)
[lv_idx]=find(voxel_abs(:,4)>thresh);
voxel_lv=voxel_abs(lv_idx,:);
voxel_org=voxList(lv_idx,:);

p=0;


%smin oct 20 2016 Keep a copy of the full voxel lists
%Step 3: 
voxel_full=voxel_lv;
voxel_org_full=voxel_org;
%smin oct 20 2016 end



%Step 3: Scan through rectified, above threshold voxList using search radius (SR)
for n=1:size(voxel_full,1) 
    %smin oct 20 2016 find the max value and start the search there
    [maxpkid]=find(voxel_lv(:,4)==max(voxel_lv(:,4)));
	vox_roi=voxel_lv(maxpkid,:);%smin 2016 now always search around highest mag voxel
	vox_roi_org=voxel_org(maxpkid,:);%smin 2016 always search around highest mag voxel
    %smin oct 20 2016 end



 	[roi_idx,z,zz]=find((voxel_full(:,1)< vox_roi(1,1)+SR & voxel_full(:,1)>vox_roi(1,1)-SR)...
       	  	& (voxel_full(:,2)< vox_roi(1,2)+SR & voxel_full(:,2)>vox_roi(1,2)-SR)...
      	   	& (voxel_full(:,3)< vox_roi(1,3)+SR & voxel_full(:,3)>vox_roi(1,3)-SR));

	if vox_roi(1,4)==max(voxel_full(roi_idx,4))%>=(max(voxel_full(roi_idx,4))-0.005));%smin oct 20 2016 keep peaks close to max?
            p=p+1;
            peak_voxels(p,:)=vox_roi_org;
            
        %smin to do oct 20 2016:    
        %add an ROI search in here to check if the peak is in the ROI, and
        %if so, add another "break" out of the find peaks loop early if peak in ROI is found.
        %if not AND (&) if n==10, set roi peak voxels to be in the middle
        %of the roi and set roi peak value to zero
        
	end
        
%smin oct 20 2016 delete found peak & limit iterations to number of max_peaks specified in input
	voxel_lv(maxpkid,:)=[];
    voxel_org(maxpkid,:)=[];
    
    if p==max_peaks
        break 
    end
%smin oct 20 2016 end
	
end
%add script to save ROI peak voxel and mag info to ROI peak data file here

end
