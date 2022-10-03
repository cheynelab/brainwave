function head_shape_points = bw_getHeadShape(niifile,na_RAS,le_RAS,re_RAS,mmPerVoxel)
        
        fprintf('Extracting head shape points from MRI outer surface for %s\n', niifile);
        head_shape_RAS = [];
        
        nii = load_nii(niifile);
        length_x = size(nii.img,1);
        length_y = size(nii.img,2);
        length_z = size(nii.img,3);
        mx=max(max(max(max(nii.img))),1);
        thresh_val = mx*0.2;
        
        
        step_x = round((length_x-1)/35);
        step_y = round((length_y-1)/35);
        step_z = round((length_z-1)/35);       
     
%         for x=1:step_x:length_x
%             for y = 1:step_y:length_y
%                 for z = 1:length_z
%                     if (nii.img(x,y,z)>thresh_val)
%                         head_shape_RAS = [head_shape_RAS;x y z];
%                         break;
%                     end
%                 end
%             end
%         end
        
        
        for x=1:step_x:length_x
            for y = 1:step_y:length_y
                for z = length_z:-1:1
                    if (nii.img(x,y,z)>thresh_val)
                        head_shape_RAS = [head_shape_RAS;x y z];
                        break;
                    end
                end
            end
        end
        
        for x=1:step_x:length_x
            for z = 1:step_z:length_z
                for y = 1:length_y
                    if (nii.img(x,y,z)>thresh_val)
                        head_shape_RAS = [head_shape_RAS;x y z];
                        break;
                    end
                end
            end
        end
        
        for x=1:step_x:length_x
            for z = 1:step_z:length_z
                for y = length_y:-1:1
                    if (nii.img(x,y,z)>thresh_val)
                        head_shape_RAS = [head_shape_RAS;x y z];
                        break;
                    end
                end
            end
        end
        
        for y=1:step_y:length_y
            for z = 1:step_z:length_z
                for x = 1:length_x
                    if (nii.img(x,y,z)>thresh_val)
                        head_shape_RAS = [head_shape_RAS;x y z];
                        break;
                    end
                end
            end
        end
        
        for y=1:step_y:length_y
            for z = 1:step_z:length_z
                for x = length_x:-1:1
                    if (nii.img(x,y,z)>thresh_val)
                        head_shape_RAS = [head_shape_RAS;x y z];
                        break;
                    end
                end
            end
        end
        M = bw_getAffineVox2CTF(na_RAS, le_RAS, re_RAS,mmPerVoxel);
        npts = size(head_shape_RAS,1);
        pts = [head_shape_RAS ones(npts,1)];     % add ones
        headpts = pts*M;                        % convert to MEG coordsbet
        clear pts;
        headpts(:,4) = [];                      % remove ones
        head_shape_points = headpts * 0.1;
        head_shape_points = unique(head_shape_points,'rows');
    end