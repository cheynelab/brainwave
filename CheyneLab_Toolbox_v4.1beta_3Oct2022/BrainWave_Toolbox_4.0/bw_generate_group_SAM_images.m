%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [imagesetName] = bw_generate_group_images(groupPath, list, list2, covList, params)
%
%   DESCRIPTION: stand-alone routine to generate a group image from a passed 
%   list of datasets - was separate function in bw_group_images.m
%
% (c) D. Cheyne, 2014. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [imagesetName] = bw_generate_group_SAM_images(groupPath, list, list2, params)
 
    [path name ext] = bw_fileparts(groupPath);
    groupName = fullfile(name,ext);
    
    mkdir(groupPath);
    imageset.no_subjects = size(list,2);
    
    % save parameters and options that were used to generate this average
    imageset.params = params;
       
    wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wbh,'canceling',0)
       
    % first generate images for all subjects and timepoints and save in
    % individual files in subject directories
    group_surface = [];
  
    global_min = 0.0;
    global_max = 0.0;
        
    for n=1:imageset.no_subjects
                
        if getappdata(wbh,'canceling')
            delete(wbh);   
            fprintf('*** cancelled ***\n');
            return;
        end
        waitbar(n/imageset.no_subjects,wbh,sprintf('generating images for subject %d',n));
     
        dsName = deblank( list{1,n} );             
        fprintf('processing dataset -> %s ...\n', dsName);   
        imageset.dsName{n} = dsName;
                
        
        % *** generate images for this subject *** 
                
        if params.beamformer_parameters.useCovAsControl
            if isempty(list2)
                fprintf('List2 is blank...\n');   
                return;
            end
            covDsName = deblank( list2{1,n} );          
            imageset.controlDsName{n} = covDsName;  % save baseline dataset name in mat file..
        else
            imageset.controlDsName{n} = dsName;  
        end
        
        fprintf('using alternate dataset --> %s for SAM baseline window ...\n', controlDsName);   
        imageList = bw_make_beamformer(dsName, covDsName, params.beamformer_parameters);

        if isempty(imageList)
            delete(wbh);             
            return;
        end
                    
            if params.beamformer_parameters.contrastImage
                if isempty(list2)
                    fprintf('List2 is blank...\n');   
                    return;
                end
                contrastDsName = deblank( list2{1,n} );          
                imageset.contrastDsName{n} = contrastDsName;

                if params.beamformer_parameters.commonWeights
                    % build common weights file name
                    combinedDsName = sprintf('%s_%s.ds', dsName1, dsName2);

                    if exist(combinedDsName) == 7
                        fprintf('***********************************************************************************\n');
                        fprintf('using existing combined dataset --> %s for common weights covariance calculation...\n\n', combinedDsName);
                    else
                        fprintf('***********************************************************************************\n');
                        fprintf('creating combined dataset --> %s for for common weights covariance calculation...\n\n', combinedDsName);
                        bw_combineDs({dsName, contrastDsName}, combinedDsName);
                    end  

                    fprintf('using dataset --> %s for covariance calculation...\n', combinedDsName);
                    covDsName = combinedDsName;
                    imageset.covDsName{n} = combinedDsName;
                else
                    covDsName = dsName;
                    imageset.covDsName = [];       % ** set to empty so that plot uses each dsName list instead ???     
                end
            elseif params.beamformer_parameters.customWeights
                if isempty(covList)
                    fprintf('Custom covariance list is blank...\n');   
                    return;
                else
                    covDsName  = deblank( covList{1,n} );
                    fprintf('using dataset --> %s for covariance calculation...\n', covDsName);   
                    imageset.covDsName{n} = covDsName;
                end
            else
                covDsName = dsName;
                imageset.covDsName{n} = covDsName;          
            end
            
            % *** generate images for list 1
            imageList = bw_make_beamformer(dsName, covDsName, params.beamformer_parameters);

            if isempty(imageList)
                delete(wbh);
                return;
            end

            % *** optionally generate images for list 2...
            if params.beamformer_parameters.contrastImage

                fprintf('\ncreating constrast images using dataset --> %s ...\n', contrastDsName);   
                if params.beamformer_parameters.commonWeights
                    covDsName = combinedDsName;
                elseif params.beamformer_parameters.customWeights  % already set above but in case..
                    covDsName  = deblank( covList{1,n} );
                    fprintf('using dataset --> %s for covariance calculation...\n', covDsName);               
                else
                    covDsName = contrastDsName;                
                end
                imageList2 = bw_make_beamformer(contrastDsName, covDsName, params.beamformer_parameters);
                if isempty(imageList2)
                    delete(wbh);
                    return;
                end
            end
    
            % create contrast images...

            % surfaces
            if params.beamformer_parameters.useSurfaceFile

                if params.beamformer_parameters.contrastImage
                    for k=1:size(imageList,1)
                       file1 = deblank( char(imageList(k,:)) );               
                       file2 = deblank( char(imageList2(k,:)) );
                       [path, imageName, ext] = bw_fileparts(file1);                   
                       file = sprintf('%s%s%s-%s,%s%s', path,filesep, dsName1, dsName2, imageName, ext);
                       bw_make_contrast_image(file1, file2, file); 
                       diff_imageList{k} = file;                       
                    end
                    imageset.imageList{n} = char(diff_imageList); 
                else
                    imageset.imageList{n} = char(imageList);
                end

                % save data range for scaling
                fprintf('getting data range for this subject ...\n');
                thisList = imageset.imageList{n};
                for k=1:size(thisList,1)
                    file = deblank( char(thisList(k,:)));
                    t = load(file);
                    mx = max(t);
                    mn = min(t);   
                    if mn < global_min
                        global_min = mn;
                    end
                    if mx > global_max
                        global_max = mx;
                    end  
                end

           % volumes
           else
               % normalize volumetric images using SPM ...
                if isempty(mri_filename)
                    fprintf('Could not locate mri file for this dataset...\n');
                    delete(wbh);
                    return;
                end                        
                imageset.mriName{n} = mri_filename;     
                imageset.isNormalized = true;
                imageset.imageType = 'Volume';

                fprintf('Normalizing images...\n');      
                normalized_imageList = bw_normalize_images(mri_filename, imageList, spm_options);

                if params.beamformer_parameters.contrastImage
                    normalized_imageList2 = bw_normalize_images(mri_filename, imageList2, spm_options);  

                    for k=1:size(normalized_imageList,1)
                       file1 = deblank( char(normalized_imageList(k,:)) );               
                       file2 = deblank( char( normalized_imageList2(k,:)) );
                       [path, imageName, ext] = bw_fileparts(file1);                   
                       file = sprintf('%s%s%s-%s,%s%s', path,filesep, dsName1, dsName2, imageName, ext);
                       bw_make_contrast_image(file1, file2, file); 
                       diff_imageList{k} = file;    
                    end
                    imageset.imageList{n} = char(diff_imageList);

                else
                    imageset.imageList{n} = char(normalized_imageList);
                end

           end
        
        imageset.no_images = size(imageList,1);   % for now this is same for each ...       
        
        % ******************************
        % make averaged surface for group 
        % - can only do this for CIVET meshes
        % ******************************
    end
    
        if params.beamformer_parameters.useSurfaceFile   
            
            surfaceFile = fullfile(mriDir, params.beamformer_parameters.surfaceFile);                                         
            imageset.surfaceFiles{n} = surfaceFile;
            imageset.imageType = 'Surface';       
            
            surface = load(surfaceFile);
 
            canBeAveraged = false;
            if surface.isCIVET
                canBeAveraged = true;
            else
                if isfield(surface,'isTemplate')
                    if surface.isTemplate
                        canBeAveraged = true;
                    end
                end
            end
            
            if canBeAveraged                            
                imageset.isNormalized = true;
                % ** generate averaged surface for CIVET meshes ***
                if n==1
                    % set all surface parameters to first image 
                    group_surface = surface; 
                else
                    % get summ of vertex values across subjects
                    group_surface.vertices = group_surface.vertices + surface.vertices;
                    group_surface.normalized_vertices = group_surface.normalized_vertices + surface.normalized_vertices;
                    if ~isempty(surface.inflated_vertices)
                        group_surface.inflated_vertices = group_surface.inflated_vertices + surface.inflated_vertices;
                    end
                end
                
            else
                imageset.isNormalized = false;
            end                        
        end  
        
        if isempty(imageList)
            delete(wbh); 
            return;     % bw_make_beamformer possibly returned error..
        end
        
    end  % for n subjects
    
    delete(wbh); 
                
    % generate grand averages and save in named directory 
    
    % have to image across subjects for each latency 
    % by parsing the subject x latency image lists      
    
    % only generate averages if volume or normalized (CIVET) surfaces
    if imageset.isNormalized
               
        for k=1:imageset.no_images
                       
            for j=1:imageset.no_subjects
                 slist = char( imageset.imageList(j) );
                 tlist{j} = slist(k,:);
            end
            aveList = deblank(tlist');
            name = char(aveList(1,:));
            [path basename ext] = bw_fileparts(name);
            idx = strfind(basename,'_');
            fileID = basename(idx(end)+1:end);

            if params.beamformer_parameters.contrastImage

                if params.beamformer_parameters.useSurfaceFile
                    aveName = sprintf('%s%s%s_cond1-cond2_%s_AVE.txt', groupName,filesep,groupName, fileID);        
                else
                    aveName = sprintf('%s%s%s_cond1-cond2_%s_AVE.nii', groupName,filesep,groupName, fileID);
                end
            else
                if params.beamformer_parameters.useSurfaceFile
                    aveName = sprintf('%s%s%s_%s_AVE.txt', groupName,filesep,groupName, fileID );        
                else
                    aveName = sprintf('%s%s%s_%s_AVE.nii', groupName,filesep,groupName, fileID );
                end     
            end
            
            aveName = deblank(aveName);
            fprintf('generating average -->%s\n', aveName);

            bw_average_images(aveList, aveName);       

            % save average names for plotting...
            imageset.averageList{k} = aveName;            
        end
        
        % generate a group averageed surface to display on...
                
        if params.beamformer_parameters.useSurfaceFile
            % compute mean vertices
            group_surface.vertices = group_surface.vertices / imageset.no_subjects; 
            group_surface.normalized_vertices = group_surface.normalized_vertices / imageset.no_subjects;     
            if ~isempty(surface.inflated_vertices)
                group_surface.inflated_vertices = group_surface.inflated_vertices / imageset.no_subjects; 
            end
            
            surfaceFile = sprintf('%s%s%s_SURFACE.mat', groupPath,filesep,groupName);
            fprintf('saving average surface in %s...\n', surfaceFile); 
            save(surfaceFile, '-struct', 'surface');
            surfaceName = sprintf('%s%s%s_SURFACE.mat', groupName,filesep,groupName);
            
            imageset.averageSurface = surfaceName;
        end        
    else
        imageset.averageSurface = [];
    end
            
    % save data range for faster initializing of plots...
    imageset.global_max = global_max;
    imageset.global_min = global_min;

    % save image set info - this should be all that is needed to plot
    % images independently of # of latecies or files...
    if params.beamformer_parameters.useSurfaceFile
        imagesetName = sprintf('%s%s%s_SURFACE_IMAGES.mat', groupPath,filesep,groupName);
    else
        imagesetName = sprintf('%s%s%s_VOLUME_IMAGES.mat', groupPath,filesep,groupName);
    end
    
    fprintf('Saving image set information in %s\n', imagesetName);
    save(imagesetName, '-struct', 'imageset');
     
end


