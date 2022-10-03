function [dipole_params sim_params] = sim_readSimFile(simFile, verbose_val)


%%%%read dipole params
fid = fopen(simFile,'r');
if (fid == -1)
    fprintf('failed to open sim file %s \n',simFile);
    return;
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
num_dipoles = 0;
while 1
    s = fgets(fid);
    if strncmp('}',s(1), 1)
        break;
    end
    colon = find(s==':');
    if ~isempty(colon)
        ss = s(colon+1:end);
        params = sscanf(ss,'%f %f %f %f %f %f %f %f');
        num_dipoles = num_dipoles+1;
        dip_params(num_dipoles,:) = params(1:7);
    end
end


num_dipoles = size(dip_params,1);

dipole_params = struct('xpos',{dip_params(:,1)},'ypos',{dip_params(:,2)},'zpos',{dip_params(:,3)},'xori',{dip_params(:,4)},...
    'yori',{dip_params(:,5)},'zori',{dip_params(:,6)},'moment',{dip_params(:,7)});

clear params dip_params;
%%read sim file Params
while 1
    s = fscanf(fid,'%s',1);    
    if strncmp(s,'Params',6)
        break;
    end
    if feof(fid)
        fprintf('Could not find Params key word\n');
        return;
    end
end
s = fscanf(fid,'%s',1);  % skip {
s = fgets(fid);

for i=1:num_dipoles
    s = fgets(fid);
    if strncmp('}',s(1), 1)
        break;
    end
    colon = find(s==':');
    if ~isempty(colon)
        ss = s(colon+1:end);
        params = textscan(ss,'%f %f %f %f %f %s');
        sourcetype = params{6};
        sim(i,1) = params{1};
        sim(i,2) = params{2};
        sim(i,3) = params{3};
        sim(i,4) = params{4};
        sim(i,5) = params{5};
        tt=char(sourcetype);
        if length(tt)<4
            fprintf('Error: unknown activation type <%s> specified in .sim file \n', sourcetype);
            return;
        end
    
        
        if strcmp(sourcetype,'sine-squared')
            para_type{i}= 'sine-squared';  %output sourceType is a 1 by 1 cell
            source_name{i} = '';
        elseif strcmp(sourcetype,'sine')
            para_type{i}= 'sine';
            source_name{i} = '';
        elseif strcmp(sourcetype,'square')
            para_type{i} = 'square';
            source_name{i} = '';
        else
            if strncmp(sourcetype,'file:',5)
                para_type{i} = 'source_file';
                source_name{i} = tt(6:end);
            else
                fprintf('Error: unknown activation type <%s> specified in .sim file \n', sourcetype);
                return;
            end
        end
    end
    
end

sim_params = struct('frequency',{sim(:,1)},'onsetTime',{sim(:,2)},'duration',{sim(:,3)},'onsetJitter',{sim(:,4)},...
    'amplitudeJitter',{sim(:,5)},'sourceType',{para_type},'sourceFile',{source_name});  

fclose(fid);

clear params sim para_type source_name;
%%%printf dipole and sim paramaters
if (verbose_val)
    fprintf('Dipole params:\n');
    for i = 1:num_dipoles
        fprintf('Source %d: position: %f, %f, %f cm, orientation: %f, %f, %f, moment: %f nAm\n', i,dipole_params.xpos(i),...
            dipole_params.ypos(i),dipole_params.zpos(i),dipole_params.xori(i),dipole_params.yori(i),...
            dipole_params.zori(i),dipole_params.moment(i));
    end
    fprintf('Activation parameters:\n');
    for i = 1:num_dipoles
        sim_params.sourceType{i}
        if strcmp(sim_params.sourceType{i},'sine-squared')            
                tstr = sprintf('squared sine wave');
        elseif strcmp(sim_params.sourceType{i},'sine')
                tstr = sprintf('sine wave');
        elseif strcmp(sim_params.sourceType{i},'square')
                tstr = sprintf('square wave');
        elseif strcmp(sim_params.sourceType{i},'source_file')
                tstr = sprintf('waveform data from %s',sim_params.sourceFile{i});
        end
        fprintf('Souce %d: freq %f Hz, onset %f s, duration %f s, phase jitter %f s, amplitude jitter %f s, sourceType = %s\n',...
            i,sim_params.frequency(i),sim_params.onsetTime(i),sim_params.duration(i),sim_params.onsetJitter(i),...
            sim_params.amplitudeJitter(i),tstr);
    end
end

end