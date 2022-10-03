%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [imagesetName] = bw_generate_group_images(groupPath, list, list2, covList, params)
%
%   DESCRIPTION: stand-alone routine to generate a group image from a passed 
%   list of datasets - was separate function in bw_group_images.m
%
% (c) D. Cheyne, 2014. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.
%
% 
% Version 4.0 March 2022 - removed optional averaging over CIVET surfaces.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [imagesetName] = bw_generate_group_images(groupPath, list, list2, covList, params, label1, label2)

    imagesetName = [];
    
    if ~exist('label1','var')
        label1 = 'Condition1';
    end
    
    if ~exist('label2','var')
        label2 = 'Condition2';
    end
    
    [~, name, ext] = bw_fileparts(groupPath);
    groupName = fullfile(name,ext);
    
    mkdir(groupPath);
    imageset.no_subjects = size(list,2);
    
    % save parameters and options that were used to generate this average
    imageset.params = params;
       
    wbh = waitbar(0,'1','Name','Please wait...','CreateCancelBtn','setappdata(gcbf,''canceling'',1)');
    setappdata(wbh,'canceling',0)
       
    % first generate images for all subjects and timepoints and save in
    % individual files in subject directories 
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
        
        imageset.dsName{n} = dsName;
        
        % *** generate images for this subject *** 
        [~, ~, ~, ~, mri_filename] = bw_parse_ds_filename(dsName);   % need MRI name and path for this subject   
      
        % create contrast images...
        if isempty(mri_filename)
            s = sprintf('Could not locate mri file for dataset %s. Cannot normalize images...\n', dsName);
            errordlg(s);
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
        end

        % get covariance dataset...
        if isempty(covList)
            fprintf('Covariance list is blank...\n');   
            return;
        else
            covDsName  = deblank( covList{1,n} );
            imageset.covDsName{n} = covDsName;
        end            

        % *** generate images for list 1
        fprintf('processing dataset -> %s ...\n', dsName);   
        
        if ( strcmp(params.beamformer_parameters.beam.use,'T') || strcmp(params.beamformer_parameters.beam.use,'F') ) && params.beamformer_parameters.multiDsSAM
            fprintf('using dataset --> %s for SAM baseline ...\n', covDsName);
        else
            fprintf('using dataset --> %s for covariance calculation...\n', covDsName);
        end
        
        imageList = bw_make_beamformer(dsName, covDsName, params.beamformer_parameters);

        if isempty(imageList)
            delete(wbh);
            return;
        end

        % *** if we are createing a contrast image, generate images for list 2...
        if params.beamformer_parameters.contrastImage
            if params.beamformer_parameters.covarianceType == 0
                covDsName = contrastDsName; 
            else
                covDsName = covDsName;              % set above
            end

            fprintf('\ncreating constrast images using dataset --> %s ...\n', contrastDsName);
            if ( strcmp(params.beamformer_parameters.beam.use,'T') || strcmp(params.beamformer_parameters.beam.use,'F') ) && params.beamformer_parameters.multiDsSAM
                fprintf('using dataset --> %s for SAM baseline ...\n', covDsName);
            else
                fprintf('using dataset --> %s for covariance calculation...\n', covDsName);
            end
            
            imageList2 = bw_make_beamformer(contrastDsName, covDsName, params.beamformer_parameters);

            if isempty(imageList2)
                delete(wbh);
                return;
            end
        end       
        
        imageset.mriName{n} = mri_filename;     
        imageset.isNormalized = true;
        imageset.imageType = 'Volume';

        fprintf('Normalizing images...\n');      
        normalized_imageList = bw_normalize_images(mri_filename, imageList, params.spm_options);

        if params.beamformer_parameters.contrastImage
            normalized_imageList2 = bw_normalize_images(mri_filename, imageList2, params.spm_options);  

            for k=1:size(normalized_imageList,1)
               file1 = deblank( char(normalized_imageList(k,:)) );               
               file2 = deblank( char( normalized_imageList2(k,:)) );
               [path, imageName, ext] = bw_fileparts(file1);                   
               file = sprintf('%s%s%s-%s,%s%s', path,filesep, dsName, contrastDsName, imageName, ext);
               bw_make_contrast_image(file1, file2, file); 
               diff_imageList{k} = file;    
            end
            imageset.imageList{n} = char(diff_imageList);

        else
            imageset.imageList{n} = char(normalized_imageList);
        end

        imageset.no_images = size(imageList,1);   % for now this is same for each ...       
        
    end  % for n subjects
    
    delete(wbh); 
                
    % generate grand averages and save in named directory 
    
    % have to image across subjects for each latency 
    % by parsing the subject x latency image lists      
                   
    for k=1:imageset.no_images
        for j=1:imageset.no_subjects
             slist = char( imageset.imageList(j) );
             tlist{j} = slist(k,:);
        end
        aveList = deblank(tlist');
        name = char(aveList(1,:));
        [~, basename, ~] = fileparts(name);
        idx = strfind(basename,'_time');
        if isempty(idx)
            idx = strfind(basename,'_A');
        end
        fileID = basename(idx(1)+1:end);

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
        
        % not used
        imageset.averageSurface = [];

    end
       
            
    % save data range for faster initializing of plots...
    imageset.global_max = global_max;
    imageset.global_min = global_min;
    
    imageset.cond1Label = label1;
    imageset.cond2Label = label2;

    % save image set info - this should be all that is needed to plot
    % images independently of # of latecies or files...
    imagesetName = sprintf('%s%s%s_IMAGES.mat', groupPath,filesep,groupName);
    
    
    fprintf('Saving images in %s\n', imagesetName);
    save(imagesetName, '-struct', 'imageset');
     
end


