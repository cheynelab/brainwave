%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% get dimensions and resolution of an svl file
%
% D.Cheyne, Oct, 2012
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [bb svlResolution] = bw_get_svl_dims(svlFile)

    bb = [0 0 0 0 0 0];
    svlResolution = 0.0;
    
    fid = fopen(svlFile, 'r', 'b','latin1');
    if (fid == -1)
        return;
    end
    
    identity = transpose(fread(fid,8,'*char'));
    if(~strcmp(identity,'SAMIMAGE'))
        error('This doesn''t look like a SAM IMAGE file.');
    end % if SAM image
    vers = fread(fid,1,'int32'); % SAM file version
    setname = fread(fid,256,'*char');
    numchans = fread(fid,1,'int32');
    numweights = fread(fid,1,'int32');
    if(numweights ~= 0)
        warning('... numweights ~= 0');
    end

    padbytes1 = fread(fid,1,'int32');

    XStart = fread(fid,1,'double');
    XEnd = fread(fid,1,'double');
    YStart = fread(fid,1,'double');
    YEnd = fread(fid,1,'double');
    ZStart = fread(fid,1,'double');
    ZEnd = fread(fid,1,'double');
    StepSize = fread(fid,1,'double');

    fclose(fid);
    
    svlResolution = StepSize * 1000.0;  % return res in mm...
    xmin = XStart * 100.0;  % convert bb to cm!
    ymin = YStart * 100.0;
    zmin = ZStart * 100.0;
    xmax = XEnd * 100.0;
    ymax = YEnd * 100.0;
    zmax = ZEnd * 100.0;
    bb = [xmin xmax ymin ymax zmin zmax];

end
