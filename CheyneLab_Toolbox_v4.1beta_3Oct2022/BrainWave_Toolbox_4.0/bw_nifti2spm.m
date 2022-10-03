function bw_nifti2spm(niftiFile)
%       BW_NIFTI2SPM
%
%   function bw_nifti2spm(niftiFile)
%
%   DESCRIPTION: Reads the .nii NIfTI file specified by niftiFile and
%   converts and saves it as a SPM .hdr and .img Analyze file.
%
% (c) D. Cheyne, 2011. All rights reserved. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  
% function bw_nifti2spm(niftiFile)
%  
%   bw_nifti2spm reads a nifti file (.nii) and converts it to Analyze
%   (.hdr, .img)
%
%  D. Cheyne, Mar, 2011
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%1

    nii = load_nii(niftiFile);
    file_prefix = strrep(niftiFile,'.nii','');
    
    hdr = nii.hdr;
    avw.hdr = bw_create_spm_header; % creates default header structure

    % copy over only the relevant structures

    avw.hdr.dime.dim = hdr.dime.dim;
    avw.hdr.dime.pixdim = hdr.dime.pixdim;
    avw.hdr.dime.datatype = hdr.dime.datatype;
    avw.hdr.dime.bitpix = hdr.dime.bitpix;
    avw.hdr.dime.glmin = hdr.dime.glmin;
    avw.hdr.dime.glmax = hdr.dime.glmax;

    avw.hdr.hist.descrip = hdr.hist.descrip;
    avw.hdr.hist.originator = hdr.hist.originator;
    
    avw.img = nii.img;
    
    bw_write_spm_analyze(avw, file_prefix);


end