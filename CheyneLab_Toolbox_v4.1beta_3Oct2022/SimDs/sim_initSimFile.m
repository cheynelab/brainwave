function [num_sources validFile] = sim_initSimFile(simFileName, SIM_VERSION)

validFile = 0;
fid = fopen(simFileName,'r');
if (fid == -1)
    fprintf('failed to open sim file %s \n',simFileName);
    return;
end
s = fscanf(fid,'%s',1);
if strcmp(s,SIM_VERSION)
    validFile = 1;
else
    fprintf('sim file %s does not appear to be correct version [%s]\n',simFileName, SIM_VERSION);
end


while 1
    s = fscanf(fid,'%s',1);    
    if strncmp(s,'Dipoles',7)
        break;
    end
    if feof(fid)
        fprintf('Could not find Dipoles key word\n');
        return;
    end
end
s = fscanf(fid,'%s',1);  % skip {
s = fgets(fid);
num_sources = 0;

while ~feof(fid)
    s = fgets(fid);
    if strncmp('}',s(1), 1)
        break;
    else
        num_sources = num_sources+1;
    end    
end

end