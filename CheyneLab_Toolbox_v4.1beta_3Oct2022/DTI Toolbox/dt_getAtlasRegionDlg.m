%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 
% function [mni_voxels, voxelSize, labels, atlasName] = dt_getAtlasRegionDlg
%
% GUI to select one or more brainRegions from an atlas
%
% returns: selected labels for one or more regions and
% their corresponding mni coordinates in the atlas
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mni_voxels, voxelSize, labels, atlasName] = dt_getAtlasRegionDlg
     
    tpath=which('dt_getAtlasRegionDlg');
    DT_PATH=tpath(1:end-23);
    
    atlasPath = sprintf('%s%satlases', DT_PATH, filesep);

    atlasName = [];
    
    mni_voxels = {};        % return as cell arrays - can be different sizes    
    labels = {};
    atlas_labels = {};
    
    atlas_values = [];
    jbrain = [];
    atlasFile = [];
    voxelSize = [];
        
    atlases = {'AAL1','AAL2','SPM Anatomy Toolbox','Talairach Atlas'};

    scrnsizes=get(0,'MonitorPosition');

    fg=figure('color','white','name','Atlas Region Selector','numbertitle','off',...
        'menubar','none','position',[300 (scrnsizes(1,4)-300) 600 700], 'CloseRequestFcn', @close_callback);
    if ispc
        movegui(fg,'center')
    end
    
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.65 0.4 0.3 0.08],'string','Create MNI Mask','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@save_mask_callback);
    
        function save_mask_callback(~,~)
            load_regions;            
            if isempty(mni_voxels)
                warndlg('No regions selected\n');
                return;
            end
            s = sprintf('%s_%s.nii',atlasName,char(labels));
            [filename, pathname, ~]=uiputfile('*.nii','Select File Name for Volume ...',s);
            if isequal(filename,0)
                return;
            end           
            maskFileName = [pathname filename];
                     
            dt_make_MNI_mask(maskFileName, mni_voxels);

        end
    
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.1 0.2 0.08],'string','Select','backgroundcolor','white',...
        'foregroundcolor','blue','callback',@ok_callback);
    
        function ok_callback(~,~)
            load_regions;                     
            uiresume(gcf);
            delete(fg);  
        end
    
    uicontrol('style','pushbutton','units','normalized','position',...
        [0.7 0.2 0.2 0.08],'string','Cancel','backgroundcolor','white',...
        'foregroundcolor','black','callback',@cancel_callback);
    
        function cancel_callback(~,~)
            uiresume(gcf);
            delete(fg);  
        end
    
     function close_callback(~,~)    
        uiresume(gcf);
        delete(fg);   
     end    
    
    selectedAtlas = 1;

    
    uicontrol('style','text','units','normalized','position',[0.1 0.86 0.3 0.1],...
        'string','Atlas:','backgroundcolor','white','FontSize',11,'horizontalalignment','left');

    uicontrol('style','popup','units','normalized',...
        'position',[0.1 0.75 0.5 0.15],'String', atlases, 'Backgroundcolor','white','fontsize',12,...
        'value',selectedAtlas,'callback',@atlas_popup_callback);

        function atlas_popup_callback(src,~)
            menu_select=get(src,'value');
            selectedAtlas = menu_select;
            initAtlas;
        end
    

    uicontrol('style','text','units','normalized','position',[0.1 0.7 0.2 0.1],...
        'string','Brain Region:','backgroundcolor','white','FontSize',11,'horizontalalignment','left');
 
    nRegionsText = uicontrol('style','text','units','normalized','position',[0.1 0.0 0.4 0.1],...
        'string','','backgroundcolor','white','FontSize',11,'horizontalalignment','left');
   
    
    region_listbox=uicontrol('Style','Listbox','FontSize',10,'Units','Normalized','Position',...
        [0.1 0.1 0.5 0.75],'String','','HorizontalAlignment','Center','min',1,'max',1000,...
        'BackgroundColor','white');        

    function initAtlas

        switch selectedAtlas

            case 1
                [atlas_labels, atlas_values, atlasFile] = dt_get_AAL1_labels(atlasPath);          
                if ~isempty(atlas_labels)
                    set(region_listbox,'string',atlas_labels);
                end
            case 2
                [atlas_labels, atlas_values, atlasFile] = dt_get_AAL2_labels(atlasPath);          
                if ~isempty(atlas_labels)
                    set(region_listbox,'string',atlas_labels);
                end    
            case 3
                [jlabels, jbrain, atlasFile] = dt_get_JuBrain_labels(atlasPath);
                atlas_labels = jlabels{1}'; 
                s1 = strcat(atlas_labels,' (L)');
                s2 = strcat(atlas_labels,' (R)');

                % interleave so that odd indices = L, even = right;
                rows = 1:2:numel(s1)*2;
                atlas_labels(rows) = s1;
                rows = 2:2:numel(s1)*2;
                atlas_labels(rows) = s2;

                % need add labels for left and right

                if ~isempty(atlas_labels)
                    set(region_listbox,'string',atlas_labels);
                end      

                atlas_values = [];
            case 4
                [atlas_labels, atlas_values, atlasFile] = dt_get_Talairach_labels(atlasPath);          
                if ~isempty(atlas_labels)
                    set(region_listbox,'string',atlas_labels);
                end
            otherwise
                fprintf('invalid option \n');
        end
      
        s = sprintf('(total = %d)',size(atlas_labels,2));
        set(nRegionsText,'string',s);
        
    end


    
        function load_regions
            selectedRegions = get(region_listbox,'val')';
            
            if isempty(selectedRegions)
                errordlg('No regions selected...');
                return;
            end
            
            labels = atlas_labels(:,selectedRegions);
            switch selectedAtlas
                                
                case {1, 2}
                    voxelSize = 2;
                    for j=1:numel(labels)
                        region = selectedRegions(j);
                        values = atlas_values(region);
                        voxels = dt_get_MNI_coords_by_value(atlasFile, values);
                        fprintf('Read %d voxels from region %s ...\n',size(voxels,1), char(labels(j)));   
                        mni_voxels{j} = voxels;     
                    end   
                    mni_voxels{j} = voxels;
            
                    atlasName = 'AAL';
                case 3
                    nii = load_nii(atlasFile);
                    pixdim = nii.hdr.dime.pixdim(2:4);

                    origin = [nii.hdr.hist.srow_x(4) nii.hdr.hist.srow_y(4) nii.hdr.hist.srow_z(4)];  % juBrain is RAS...
                    voxelSize = pixdim(1);

                    for j=1:numel(labels)
                        voxelArray = [];
                        % get index into mpm table for this label                 
                        t = selectedRegions(j); 
                        mpmIndex = ceil(t/2); % converts back to non-interleaved index
                        if rem(t,2) 
%                         if isodd(t) 
                            side = 1;
                        else
                            side = 2;
                        end

                        % get values in jbrain.Index corresponding to this region
                        regionValues = find(jbrain.mpm == mpmIndex)'; 
                        regionHemi = jbrain.lr(regionValues);

                        % remove opposite hemisphere
                        if side == 1
                            idx = find(regionHemi == 2);
                        else
                            idx = find(regionHemi == 1);
                        end
                        regionValues(idx) = [];

                        idx = find(ismember(jbrain.Index, regionValues));
                        % convert linear index to voxel coords and add to list
                        [x, y, z] = ind2sub(size(jbrain.Index), idx);
                        voxelArray = [voxelArray; [x y z] ];     

                        % convert to MNI coordinates MNI = (voxel-1) * voxelSize + origin
                        % where voxels go from 0 to dims-1
                        voxels = zeros(size(voxelArray,1),3);
                        voxels(:,1) = (voxelArray(:,1)-1) * pixdim(1);  
                        voxels(:,2) = (voxelArray(:,2)-1) * pixdim(2);
                        voxels(:,3) = (voxelArray(:,3)-1) * pixdim(3);
                        voxels = voxels + repmat(origin,size(voxels,1),1);
                        voxels = round(voxels);
                        voxels = unique(voxels,'rows');                                        

                        mni_voxels{j} = voxels;
                        fprintf('Read %d voxels from region %s ...\n',size(voxels,1), char(labels(j)));   
                    end              
                    atlasName = 'SPM Anatomy Toolbox';

                case 4
                   voxelSize = 1;
                    for j=1:numel(labels)
                        region = selectedRegions(j);
                        values = atlas_values(region);
                        voxels = dt_get_MNI_coords_by_value(atlasFile, values);
                        fprintf('Read %d voxels from region %s ...\n',size(voxels,1), char(labels(j)));   
                        mni_voxels{j} = bw_tal2mni(voxels);     
                    end  
                    atlasName = 'Talairach';
                otherwise 
                    fprintf('uknnown option\n');
            end
                     
        end


    initAtlas;
    
    uiwait(gcf);  
    uiresume(gcf);    
    
end
