function bw_save_mri(mri_nii,fileName,na,le,re,filetype)

if(filetype==0)    
    
    mri_nii.hdr.HeadModel_Info.Nasion_Sag = na(1);
    mri_nii.hdr.HeadModel_Info.Nasion_Cor = na(2);
    mri_nii.hdr.HeadModel_Info.Nasion_Axi = na(3);
    mri_nii.hdr.HeadModel_Info.LeftEar_Sag = le(1);
    mri_nii.hdr.HeadModel_Info.LeftEar_Cor = le(2);
    mri_nii.hdr.HeadModel_Info.LeftEar_Axi = le(3);
    mri_nii.hdr.HeadModel_Info.RightEar_Sag = re(1);
    mri_nii.hdr.HeadModel_Info.RightEar_Cor = re(2);
    mri_nii.hdr.HeadModel_Info.RightEar_Axi = re(3);    
    ctf_write_mri(mri_nii,fileName);
    
elseif(filetype==2)
    
    if ((mri_nii.hdr.dime.dim(2)==mri_nii.hdr.dime.dim(3))&&(mri_nii.hdr.dime.dim(3)==mri_nii.hdr.dime.dim(4))&&(mri_nii.hdr.dime.dim(4)==256))
        
        mri = make_mri;
        % flip z direction RAS -> RAI
        img2 = flipdim(mri_nii.img,3);
        % flip y direction RAI -> RPI
        mri.img = flipdim(img2,2);
        clear img2;
               
        %%copy pamaters from nii files
        if (mri_nii.hdr.dime.datatype==2|mri_nii.hdr.dime.datatype==256)
            mri.hdr.dataSize = 1;
            mri.img=uint8(mri.img-mri_nii.hdr.dime.glmin);  %scale int8 to uint8          
        elseif(mri_nii.hdr.dime.datatype==4|mri_nii.hdr.dime.datatype==512)
            mri.hdr.dataSize = 2;
            mri.img=uint16(mri.img-mri_nii.hdr.dime.glmin); %scale int16 to uint16
        else
            fprintf('Datatype is neither 8 bit nor 16 bit, scaling to 16 bit..\n');
            mri.hdr.dataSize = 2;
            maxVal = mri_nii.hdr.dime.glmax-mri_nii.hdr.dime.glmin;
            scaleTo16bit = 65535/maxVal;
            mri.img = scaleTo16bit* (mri.img-mri_nii.hdr.dime.glmin); %scale 32, 64, 128 bit data to unsigned 16 bit           
        end
        
     
        mri.hdr.clippingRange = mri_nii.hdr.dime.glmax;
        mri.hdr.mmPerPixel_sagittal = mri_nii.hdr.dime.pixdim(2);
        mri.hdr.mmPerPixel_coronal = mri_nii.hdr.dime.pixdim(3);
        mri.hdr.mmPerPixel_axial = mri_nii.hdr.dime.pixdim(4);        
        mri.hdr.HeadModel_Info.Nasion_Sag = na(1);
        mri.hdr.HeadModel_Info.Nasion_Cor = na(2);
        mri.hdr.HeadModel_Info.Nasion_Axi = na(3);
        mri.hdr.HeadModel_Info.LeftEar_Sag = le(1);
        mri.hdr.HeadModel_Info.LeftEar_Cor = le(2);
        mri.hdr.HeadModel_Info.LeftEar_Axi = le(3);
        mri.hdr.HeadModel_Info.RightEar_Sag = re(1);
        mri.hdr.HeadModel_Info.RightEar_Cor = re(2);
        mri.hdr.HeadModel_Info.RightEar_Axi = re(3); 
        mri.hdr.Image_Info.commentString = mri_nii.hdr.hist.descrip;        
        
        mri.hdr.transformMatrix = bw_getTransformMatrix(na,le,re);
        
        % write mri file
        ctf_write_mri(mri,fileName);
        
    else
        fprintf('original image size is not 256*256*256, need to interpolate before saving...\n');
        return;
        
    end    
end


    function mri = make_mri
        mri.file = '';
        mri.img = zeros(256,256,256);
        mri.hdr = Version_2_Header;        
    end

    function hdr = Version_2_Header
        hdr.identifierString = 'CTF_MRI_FORMAT VER 2.2';
        hdr.imageSize = 256; % always = 256
        hdr.dataSize = 0; % 1 = 8 bit data, 2 = 16 bit data
        hdr.clippingRange = 0; % Max. integer value in data
        hdr.imageOrientation = 0; % 0 = left on left, 1 = left on right
        hdr.mmPerPixel_sagittal = 0;
        hdr.mmPerPixel_coronal = 0;
        hdr.mmPerPixel_axial = 0;
        hdr.HeadModel_Info = HeadModel_Info;
        hdr.Image_Info = Image_Info;
        hdr.headOrigin_sagittal = 0; % voxel location of head origin
        hdr.headOrigin_coronal = 0;
        hdr.headOrigin_axial = 0;
        hdr.rotate_coronal = 0; % rotate in coronal plane by this angle
        hdr.rotate_sagittal = 0;
        hdr.rotate_axial = 0;
        hdr.orthogonalFlag = 0; % true if image is orthogonalized to head frame
        hdr.interpolatedFlag = 1; % true if slices were interpolated during conversion
        hdr.originalSliceThickness = 0;
        hdr.transformMatrix = zeros(4,4);
        hdr.unused = '';  %pad header to 1028 bytes       
    end

    function headModel = HeadModel_Info
        headModel.Nasion_Sag = 0; % fiduciary points
        headModel.Nasion_Cor = 0;
        headModel.Nasion_Axi = 0;
        headModel.LeftEar_Sag = 0;
        headModel.LeftEar_Cor = 0;
        headModel.LeftEar_Axi = 0;
        headModel.RightEar_Sag = 0;
        headModel.RightEar_Cor = 0;
        headModel.RightEar_Axi = 0;
        headModel.defaultSphereX = 0; % default sphere parameters in mm in head based coordinate system
        headModel.defaultSphereY = 0;
        headModel.defaultSphereZ = 50;
        headModel.defaultSphereRadius = 50;        
    end

    function imageInfo = Image_Info
        imageInfo.modality = 0; % 0 = MRI, 1 = CT, 2 = PET, 3 = SPECT, 4 = OTHER
        imageInfo.manufacturerName = '';
        imageInfo.instituteName = '';
        imageInfo.patientID = '';
        imageInfo.dateAndTime = '';
        imageInfo.scanType = '';
        imageInfo.contrastAgent = '';
        imageInfo.imagedNucleus = '';
        imageInfo.Frequency = 0;
        imageInfo.FieldStrength = 0;
        imageInfo.EchoTime = 0;
        imageInfo.RepetitionTime = 0;
        imageInfo.InversionTime = 0;
        imageInfo.FlipAngle = 0;
        imageInfo.NoExcitations = 0;
        imageInfo.NoAcquisitions = 0;
        imageInfo.commentString = '';
        imageInfo.forFutureUse = '';
    end

    function M = bw_getTransformMatrix(nasion_pos, left_preauricular_pos, right_preauricular_pos )        
        
        % build CTF coordinate system
        % origin is midpoint between ears
        origin=[left_preauricular_pos + right_preauricular_pos]/2;
        
        % x axis is vector from this origin to Nasion
        x_axis=[nasion_pos - origin];
        x_axis=x_axis/sqrt(dot(x_axis,x_axis));
        
        % y axis is origin to left ear vector
        y_axis=[left_preauricular_pos - origin];
        y_axis=y_axis/sqrt(dot(y_axis,y_axis));
        
        % This y-axis is not necessarely perpendicular to the x-axis, this corrects
        z_axis=cross(x_axis,y_axis);
        y_axis=cross(z_axis,x_axis);       
        
        % now build 4 x 4 affine transformation matrix     
        
        rmat = [ [x_axis 0]; [y_axis 0]; [z_axis 0]; [0 0 0 1] ]';        
        
        % translation matrix + origin
        tmat = diag([1 1 1 1]);        
        tmat(:,4) = [origin, 1];       
        M = tmat * rmat;
    end

end
