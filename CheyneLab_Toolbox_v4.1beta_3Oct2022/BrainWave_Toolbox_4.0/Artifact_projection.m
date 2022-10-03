% function Artifact_projection(featureDs, cont_Ds, num_modes, useAverage)
function Artifact_projection(featureDs, cont_Ds, modes, useAverage)

%EX: featureDs='03_1kHzFS_EyeBlink.ds';

%Feature dataset info 
featDs_hdr = bw_CTFGetHeader(featureDs);

for i=1:length(featDs_hdr.channel) %find MEG Channels
chan_names{i}=featDs_hdr.channel(i).name;
end
meg_idx = find(strncmp(chan_names,'M',1));

%Get megsens data / assume prefiltered with BW
feat_mdata=ones(featDs_hdr.numSamples,featDs_hdr.numTrials,length(meg_idx));

for i=1:length(meg_idx)
[tvec, feat_mdata(:,:,i)]=bw_CTFGetChannelData(featureDs,chan_names{meg_idx(i)});
end


%Work on concatenated data for projectors
%EX: num_modes=3;

concat_featdata=reshape(feat_mdata,size(feat_mdata,1)*size(feat_mdata,2),size(feat_mdata,3))';
[Uc,Sc,Vc]=svd(concat_featdata,'econ');
I=eye(length(Uc));
Proj_c = I - Uc(:,modes)*Uc(:,modes)';
Clean_data_c = Proj_c'*concat_featdata;


%Work on the averaged feature data for projectors
mean_featdata=squeeze(mean(feat_mdata,2))';
[Ua,Sa,Va]=svd(mean_featdata,'econ');
I=eye(length(Ua));
Proj_a = I - Ua(:,modes)*Ua(:,modes)';
Clean_data_a = Proj_a'*concat_featdata;


%Apply projection to continuous data

%EX: cont_Ds = '03_MEG076_0-200Hz_1kHzFS.ds';
[cont_PATHSTR,cont_NAME,cont_EXT] = bw_fileparts(cont_Ds);

contDs_hdr = bw_CTFGetHeader(cont_Ds);

for i=1:length(contDs_hdr.channel)
[contDs_tv, contDs_data(:,i)] = bw_CTFGetChannelData(cont_Ds,contDs_hdr.channel(i).name);
end

fprintf('removing ...\n')
modes

if useAverage
    fprintf('Using average of %d features\n',featDs_hdr.numTrials);
    contDs_data(:,meg_idx) = (Proj_a' * contDs_data(:,meg_idx)')';
else
    fprintf('Using concatenation of %d features\n',featDs_hdr.numTrials);
    contDs_data(:,meg_idx) = (Proj_c' * contDs_data(:,meg_idx)')';
end

%Write new .meg4 file
%prepare data for writing: multiply by channel gains (when read divide
%by channel gains)
for i=1:size(contDs_data, 2)
    contDs_data(:,i)=contDs_data(:,i) * (contDs_hdr.channel(i).gain);
end


%MODIFY Merron's code to write a simple meg4 file with new clean data

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % extract trials and write binary data to .meg4 format

    % back up old meg4 file (save with suffix 'not_clean')
    fname = strcat(cont_NAME,'.meg4');
    meg4File = fullfile(cont_Ds,fname);
    
    new_name = strcat(cont_NAME, '_not_clean.meg4');
    old_meg4File = fullfile(cont_Ds, new_name);
    
    status = movefile(meg4File, old_meg4File);
    if ~status
        fprintf('Could not backup %s ...\n', meg4File);
        return;
    end

     % open meg4 file for writing data...
    fid2 = fopen(meg4File,'wb','ieee-be');
    if (fid2 == -1)
        fprintf('Could not open %s for writing...\n', meg4File);
        return;
    end

    head = sprintf('MEG41CP');
    fwrite(fid2,[head(1:7),char(0)],'uint8');

    tic

    fprintf('writing data... \n');

    % write data channel wise [samples x channels]
    fwrite(fid2,contDs_data,'int32');
    
    fprintf('... all trials written\n');

    toc
    
    fclose(fid2);

    errorFlag = 0;


end