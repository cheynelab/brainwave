%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [mriDir, mriFile] = bw_importMRI( [useSPM] )  
% 
% Version 4.0 May, 2022
% D. Cheyne
% 
% moved MRI importing routines to external function to be called outside of
% MRIViewer with more debugging options
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [mriDir, mriFile] = bw_importMRI( padVolume )
        
    if ~exist('padVolume','var')
        padVolume = 1;
    end
    
    mriDir = [];
    mriFile = [];
    
    [fileName, filePath, ~] = uigetfile(...
        {'*.dcm; *.IMA; *', 'DICOM file (*.dcm, *.IMA, *)';...
        '*.nii','NIfTI file(*.nii)';...
        '*.mri','CTF mri file(*.mri)'},...            
        'Select a file');

    if isequal(fileName,0) || isequal(filePath,0)
        return;
    end

    File = fullfile(filePath, fileName);

    [filePath,~,EXT] = fileparts(File);

    if (strcmp(EXT,'.mri') == 1)                    
        mriFile = bw_convertCTF_MRI(File);
        if ~isempty(mriFile)
            bw_MRIViewer(mriFile);
        end
        return;
        
    elseif (strcmp(EXT, '.nii') == 1)
        % import NIfTI format        
        mri_nii = load_nii(File);

    else
        % assume we are importing DICOM - can have any or no file extension! 
        wbh = waitbar(0,'Converting DICOM to NIfTI ...');

        waitbar(0.25,wbh);

        dicomDir = sprintf('%s%s', filePath, filesep);
        niftiDir = strcat(dicomDir, 'converted', filesep);

        % Version 3.0 - switched from SPM to dicm2nii
        % faster and easier to debug

        waitbar(0.25,wbh);
        
        fprintf('--> converting DICOM images to NIfTI format using dicm2nii ...\n');
       
        % since dicm2nii doesn't seem to return the .nii file name we have
        % to look in the created folder to see if it exists
        
        dicm2nii(dicomDir, niftiDir, 'nii');
        
        filemask = strcat(niftiDir, '*.nii');
        t = dir(filemask);
        
        if isempty(t)
            beep;
            errordlg('dicm2nii failed. Check file type....');
            delete(wbh);
            return;
        end       
        
        % get the created file name. 
        fname = t.name;
        niftiFile = fullfile(niftiDir, fname);             

        % continue below to read image as NIfTI format...ls
        fprintf('Loading nifti file :\n');
        mri_nii = load_nii(niftiFile);           
        
        delete(wbh);

    end

    % process image

    % interpolate to isotropic if necessary...
    mri_nii = make_Isotropic(mri_nii, padVolume);

    % write the MRI directory and .mat file ...                       
    [filename, pathname, ~] = uiputfile( ...
        {'*','MRI_DIRECTORY'; '*.mri','CTF MRI file (*.mri)'}, ...
        'Enter Subject ID for MRI Directory');

    if isequal(filename,0) || isequal(pathname,0)
        return;
    end        
    filename_full = fullfile(pathname, filename);

    save_MRI_dir(filename_full, mri_nii);

    mriDir = sprintf('%s_MRI',filename_full);
    mriFile = sprintf('%s_MRI%s%s.nii',filename_full,filesep,filename);
    

end


%  check NIfTI image and if necessary interpolate to isotropic
function mri_nii = make_Isotropic(mri_nii, padVolume)  
                           
    fprintf('Checking image dimensions...\n');
    fprintf('image size: %g %g %g voxels\n', ...
        mri_nii.hdr.dime.dim(2), mri_nii.hdr.dime.dim(3), mri_nii.hdr.dime.dim(4));
    fprintf('voxel dimensions: %g %g %g mm\n', ...
        mri_nii.hdr.dime.pixdim(2), mri_nii.hdr.dime.pixdim(3), mri_nii.hdr.dime.pixdim(4));

    % change for 2.3 - need to handle > 256 in-plane resolution for
    % PRISMA system

    % limit dimension size for memory issues
    max_pixels = 400;
    idx = find( mri_nii.hdr.dime.dim > max_pixels );

    if size(idx ~= 0)
        if mri_nii.hdr.dime.dim(2) > max_pixels
            newdim = floor(mri_nii.hdr.dime.dim(2) / 2);
            fprintf('%d voxels in x dimension detected .. downsampling to %d...\n',mri_nii.hdr.dime.dim(2), newdim);
            mri_nii.img = mri_nii.img(1:2:end,:,:);
            mri_nii.hdr.dime.dim(2) = newdim;
            mri_nii.hdr.dime.pixdim(2) = mri_nii.hdr.dime.pixdim(2) * 2.0;
        end
        if mri_nii.hdr.dime.dim(3) > max_pixels
            newdim = floor(mri_nii.hdr.dime.dim(3) / 2);
            fprintf('%d voxels in y dimension detected .. downsampling to %d...\n',mri_nii.hdr.dime.dim(3), newdim);
            mri_nii.img = mri_nii.img(:,1:2:end,:);
            mri_nii.hdr.dime.dim(3) = newdim;
            mri_nii.hdr.dime.pixdim(3) = mri_nii.hdr.dime.pixdim(3) * 2.0;
        end
        if mri_nii.hdr.dime.dim(4) > max_pixels
            newdim = floor(mri_nii.hdr.dime.dim(4) / 2);
            fprintf('%d voxels in z dimension detected .. downsampling to %d...\n', mri_nii.hdr.dime.dim(4), newdim);
            mri_nii.img = mri_nii.img(:,:,1:2:end);
            mri_nii.hdr.dime.dim(4) = newdim;
            mri_nii.hdr.dime.pixdim(4) = mri_nii.hdr.dime.pixdim(4) * 2.0;
        end
        fprintf('new image size: %g %g %g voxels\n', ...
            mri_nii.hdr.dime.dim(2), mri_nii.hdr.dime.dim(3), mri_nii.hdr.dime.dim(4));
        fprintf('new voxel dimensions: %g %g %g mm\n', ...
            mri_nii.hdr.dime.pixdim(2), mri_nii.hdr.dime.pixdim(3), mri_nii.hdr.dime.pixdim(4));

    end

    % New code (Version 3.0)
    % interpolate only if any dimension differs by more than  
    % 0.01 mm (= 2.56 mm distortion over total volume)

    isIsotropic = false;
    minErr = 0.01; 

    diff1 = abs( mri_nii.hdr.dime.pixdim(2) - mri_nii.hdr.dime.pixdim(3) );
    diff2 = abs( mri_nii.hdr.dime.pixdim(3) - mri_nii.hdr.dime.pixdim(4) );
    diff3 = abs( mri_nii.hdr.dime.pixdim(2) - mri_nii.hdr.dime.pixdim(4) );

    if diff1 < minErr && diff2 < minErr && diff3 < minErr
        isIsotropic = true;
        fprintf('original image is isotropic (within %g mm). No interpolation will be done...\n', minErr);
    else
        isIsotropic = false;
        fprintf('image differs by more than %g mm in one or more dimensions, interpolating...\n', minErr);

        pixdim=[mri_nii.hdr.dime.pixdim(2) mri_nii.hdr.dime.pixdim(3) mri_nii.hdr.dime.pixdim(4)];

        %  find smallest voxel size that does not exceed 256 voxels 
        %  (e.g., if in-plane resolution is not equal will try to make image too big...)
        % - CHANGE to find smallest size that does not exceed
        % max_pixels
        %  (larger strains memory)

        sdim = sort(pixdim);

        canInterpolate = false;
        for k=1:3
              mmPerVoxel = sdim(k);                                                                              
              fprintf('trying %g mm voxel size...\n', mmPerVoxel);
              % get new voxel dimensions
              vox_x = round(mri_nii.hdr.dime.dim(2)*mri_nii.hdr.dime.pixdim(2)/mmPerVoxel); % vox number in x direction,round to integer value
              vox_y = round(mri_nii.hdr.dime.dim(3)*mri_nii.hdr.dime.pixdim(3)/mmPerVoxel);
              vox_z = round(mri_nii.hdr.dime.dim(4)*mri_nii.hdr.dime.pixdim(4)/mmPerVoxel);      
            if vox_x <= max_pixels && vox_y <= max_pixels && vox_z <= max_pixels
                canInterpolate = true;
               break;
            end
            fprintf('image equals or exceeds max_pixels voxels...\n');
        end                
        
        if ~canInterpolate

            fprintf('*** Image resolution appears too high for memory - defaulting to 1 mm isotropic interpolation ***\n');
            mmPerVoxel = 1.0;
            vox_x = round(mri_nii.hdr.dime.dim(2)*mri_nii.hdr.dime.pixdim(2)/mmPerVoxel); % vox number in x direction,round to integer value
            vox_y = round(mri_nii.hdr.dime.dim(3)*mri_nii.hdr.dime.pixdim(3)/mmPerVoxel);
            vox_z = round(mri_nii.hdr.dime.dim(4)*mri_nii.hdr.dime.pixdim(4)/mmPerVoxel);                   
            if vox_x > max_pixels && vox_y > max_pixels && vox_z > max_pixels                             
                fprintf('Sorry, having trouble interpolating this image...\n');
                return;
            end                    
        end

    end

    % reslice image if not isotropic
    if isIsotropic      
        mmPerVoxel = mri_nii.hdr.dime.pixdim(2);
        vox_x = mri_nii.hdr.dime.dim(2);
        vox_y = mri_nii.hdr.dime.dim(3);
        vox_z = mri_nii.hdr.dime.dim(4);
    else                  
        dim_x=(mri_nii.hdr.dime.dim(2)-1)/(vox_x-1);
        dim_y=(mri_nii.hdr.dime.dim(3)-1)/(vox_y-1);
        dim_z=(mri_nii.hdr.dime.dim(4)-1)/(vox_z-1);

        x = 1 + (0:vox_x-1) .* dim_x;
        M_x = reshape(repmat(x, 1, vox_y*vox_z), vox_x, vox_y, vox_z);

        y = 1 + (0:vox_y-1) .* dim_y;
        M_y = reshape(repmat(y, vox_x, vox_z), vox_x, vox_y, vox_z);

        z = 1 + (0:vox_z-1) .* dim_z;
        M_z = reshape(repmat(z, vox_x*vox_y, 1), vox_x, vox_y, vox_z);


        if (exist('trilinear') == 3)
            img1 = trilinear(double(mri_nii.img), double(M_y), double(M_x), double(M_z));
        else
            img1 = interp3(double(mri_nii.img), double(M_y), double(M_x), double(M_z), 'linear',0);
        end      
        
        mri_nii.img = img1;
        
        fprintf('The image resolution after interpolation is: %0.1f %0.1f %0.3f mm\n',mmPerVoxel);                
        fprintf('The image size after interpolation is: %g %g %g voxels\n',size(mri_nii.img));                
    end
    
    % pad image to be square volume
    if padVolume && ~all(size(mri_nii.img) == size(mri_nii.img,1))      

        max_dim = max(vox_x, max(vox_y, vox_z));
        fprintf('padding image data (%d x %d x %d) to %d x %d x %d\n', vox_x, vox_y, vox_z, max_dim, max_dim, max_dim);
        img_RAS = zeros(max_dim, max_dim, max_dim);

        [x, y, z] = meshgrid(1:vox_x, 1:vox_y, 1:vox_z);
        pts = [x(:), y(:), z(:)];
        new_pts = zeros(size(pts));
        new_pts(:, 1) = pts(:,1) + ones(size(pts(:,1)))*round((max_dim-vox_x)/2);
        new_pts(:, 2) = pts(:,2) + ones(size(pts(:,2)))*round((max_dim-vox_y)/2);
        new_pts(:, 3) = pts(:,3) + ones(size(pts(:,3)))*round((max_dim-vox_z)/2);

        % indices into old image
        Is1 = size(mri_nii.img);
        Ioff = cumprod([1 Is1(1:end-1)]);
        idx1 = (pts-1)*Ioff.' + 1;

        % indices into new (padded) image
        Is2 = size(img_RAS);
        Ioff2 = cumprod([1 Is2(1:end-1)]);
        idx2 = (new_pts-1)*Ioff2.' + 1;

        img_RAS(idx2) = mri_nii.img(idx1);

        mri_nii.img=img_RAS;
        mri_nii.hdr.dime.dim(2)= max_dim;
        mri_nii.hdr.dime.dim(3)= max_dim;
        mri_nii.hdr.dime.dim(4)= max_dim;
        mri_nii.hdr.dime.pixdim(2)= mmPerVoxel;
        mri_nii.hdr.dime.pixdim(3)= mmPerVoxel;
        mri_nii.hdr.dime.pixdim(4)= mmPerVoxel;
    end
    
end
    
function save_MRI_dir(file, mri_nii)
 
        [path, subject_ID, ~] = fileparts(file);
        file_directory=strcat(path, filesep, subject_ID,'_MRI');

        saveName_auto = strcat(file_directory,filesep, subject_ID, '.nii');        
        if exist(file_directory,'dir')
            fprintf('Using existing directory %s...\n', file_directory);
        else
            mkdir(file_directory);
        end

        if exist(saveName_auto,'file')
            s = sprintf('File %s already exists.  Do you want to overwrite?\n', saveName_auto);
            response = questdlg(s,'Import MRI','Yes','No','Yes');
            if strcmp(response,'No')
                return;
            end
        end
        
        datatype = mri_nii.hdr.dime.datatype;
        descrip = mri_nii.hdr.hist.descrip;
        
        mmPerVoxel = mri_nii.hdr.dime.pixdim(2); % image will be isotropic
        
        %  origin = mri_nii.hdr.hist.originator(1:3);
        %dims = size(img_RAS);
        %origin = [round(dims(1)/2) round(dims(2)/2) round(dims(3)/2)];
        nii = make_nii(mri_nii.img, mmPerVoxel, [], datatype, descrip);
        %nii_spm = make_nii(img_RAS, mmPerVoxel, origin, datatype, descrip);

        fprintf('Saving to isotropic NIfTI file %s\n', saveName_auto);
        save_nii(nii, saveName_auto);
        
  
        % save the .mat file

        % this renaming is because of need to save fields with correct names
        na = [0 0 0];
        le = [0 0 0];
        re = [0 0 0];
        M = zeros(4,4);

        matFileName = strrep(saveName_auto, '.nii', '.mat');
        if exist(matFileName,'file')
            s = sprintf('There is a .mat file already exist, save changes may change the original fiducial values. Are you sure to save the fiducials?');
            response = bw_warning_dialog(s);
            if (response == 0)
                return;
            else
                fprintf('Saving Voxel to MEG coordinate transformation matrix and fiducials in %s\n', matFileName);
                save(matFileName, 'M', 'na','le','re','mmPerVoxel');
            end
        else
            fprintf('Saving Voxel to MEG coordinate transformation matrix and fiducials in %s\n', matFileName);
            save(matFileName, 'M', 'na','le','re','mmPerVoxel');
        end        
end   
