function [avw filetype] = bw_read_SPM_file(file)

[listPath,name,ext] = bw_fileparts(file);

filetype = 0;

if strcmp(ext,'.nii')
    avw = load_nii(file);
    filetype = 2;   
elseif strcmp(ext,'.img')
    avw = bw_read_spm_analyze(file);
    filetype = 1;
end

end