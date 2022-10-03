function snMatFile = bw_get_SPM_normalization_file(mriFile, bb, spm_options, noSPMWindows)
 
    global BW_PATH
    global SPM_VERSION
    
    snMatFile = [];
    
    % check if normalization mat file already exists...
    appendStr = sprintf('_resl_%g_%g_%g_%g_%g_%g', bb(1), bb(2),bb(3),bb(4),bb(5),bb(6));
    resliced = strrep(mriFile, '.nii', appendStr);

    imageToGetNormalizationFrom = strcat(resliced,'.nii');    % name of resliced mri in NIfTI format     
  
    [mriPath,mriRoot,~] = bw_fileparts(imageToGetNormalizationFrom);
    
    % get name of mat file with correct normalization parameters
    if spm_options.useDefaultTemplate
        snMatFile = sprintf('%s%s%s_sn3d.mat', mriPath, filesep, mriRoot);
        fprintf('Looking for CTF to standard MNI T1 template normalization file (%s)\n', snMatFile);
    else
        snMatFile = sprintf('%s%s%s_%s_sn3d.mat', mriPath, filesep, mriRoot, spm_options.templateFile);
        fprintf('Looking for CTF to MNI using custom template (%s)\n', snMatFile);
    end
    
    % file snMatFile already exists just return its name
    if exist(snMatFile,'file')
        fprintf('Using existing file --> %s\n', snMatFile);
        return;  % file already exists - just return its name.      
    else
        s = sprintf('Run SPM%d to create normalization file?',SPM_VERSION);
        r = questdlg(s,'SPM Normalization','Yes','No','Yes');
        if strcmp(r,'No')
            snMatFile = [];
            return;
        end
    end
        
    % otherwise create normalization .mat file in mri directory..
    fprintf('Existing normalization not found, initializing normalization parameters...\n');
    % since these are not defined in SPM12 defaults and spm_normalise defaults when graphics=1
    estimate_flags.smosrc = 8;
    estimate_flags.smoref = 0;
    estimate_flags.regtype = 'mni';
    estimate_flags.weight = '';
    estimate_flags.cutoff = 25;
    estimate_flags.nits = 16;
    estimate_flags.reg = 1;
    
    fprintf('checking for existing resliced MRI file %s\n', imageToGetNormalizationFrom);

    if ~exist(imageToGetNormalizationFrom,'file')
        fprintf('re-slicing MRI file into bounding box of svl volume\n');   
        bw_reslice_nii(mriFile, bb);
    else
        fprintf('using existing resliced MRI file %s (delete file to overwrite)\n', resliced);
    end
     
    % flags for parameter estimation
    
    if spm_options.useDefaultTemplate
        if SPM_VERSION == 8
            templateFile = fullfile(spm('Dir'),'templates','T1.nii');
            maskFile = fullfile(spm('Dir'),'apriori','brainmask.nii');
        elseif SPM_VERSION == 12
            % SPM12 has moved these files to odd locations...
            templateFile = fullfile(spm('Dir'),'toolbox','OldNorm','T1.nii');
            maskFile = fullfile(spm('Dir'),'toolbox','FieldMap','brainmask.nii');
        end
    else
        % make full path
        defPath = strcat(BW_PATH,'template_MRI');

        templateFile = fullfile(defPath,spm_options.templateFile);
        if isempty(spm_options.templateFile) || isfolder(templateFile)
            fprintf('\n *** Invalid template file...\n');
            snMatFile = [];
            return;
        end
        
        if ~exist(templateFile,'file')
            fprintf('\n*** Could not find template file (%s)\n', templateFile);
            snMatFile = [];
            return;
        end
        
        if ~isempty(spm_options.maskFile)
            maskFile = fullfile(defPath,spm_options.maskFile);          
            if ~exist(maskFile,'file')
                fprintf('\n *** WARNING: Could not find brain mask file %s. *** \n', maskFile);
                snMatFile = [];
                return;
            end
            fprintf('\n\n *** Using custom template ***\n\n');
        else
            fprintf('\n\n *** Using custom template (NO MASK) ***\n\n');
            maskFile = '';
        end
    end

    fprintf('\nComputing linear and non-linear warping parameters using template file -> \n   %s\n', templateFile);

    % open SPM windows
    if noSPMWindows
        fprintf('\n\n *** WARNING: Running spm_normalise in without display of results (not recommeded) ***\n\n');
    else
        [Finter,~,CmdLine] = spm('FnUIsetup','Image normalization');
        % run spm_normalize to get normalization parameters 
        % disp(['']);
        spm('FigName',['Finding Norm params for ' imageToGetNormalizationFrom],Finter,CmdLine);
    end
    
    objMaskFile = '';    
    spm_normalise(templateFile, imageToGetNormalizationFrom, snMatFile, maskFile, objMaskFile,estimate_flags);
    
    % For back compatibility - store the CTF bounding box in the snMatFile
    % this can be used during unwarping to get from NIfTI to 
    % CTF coordinates (i.e., to get the CTF origin in the unwarped volume)

    t = load(snMatFile);
    t.ctf_bb = bb;
    save(snMatFile, '-struct', 't')
    fprintf('writing bounding box to file %s\n', snMatFile);
  
end