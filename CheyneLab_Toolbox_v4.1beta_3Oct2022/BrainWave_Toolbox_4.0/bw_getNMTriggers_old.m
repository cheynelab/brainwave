function trig = bw_getNMTriggers(dsName)
%%
%   function bw_ctf_makeMarkerFile(dsName)
%     Description: Scans the stimulus channels of a single-trial CTF dataset
%                  and for each event code logs the timing of each occurrance
%                  saves a CTF MarkerFile
%                  
%   As of 11/11/12 Requires the older mex files: 
%                                              ctf_GetParams();
%                                              ctf_GetChannelData();
%
%   revised Nov 19, 2012    - D. Cheyne
%                           - modfied to ues bw mex functions.
%
% Created: 08-2012, Paul Ferrari pferrari@meadowlandshospital.org
%%%%%

trig=[];
stim_idx=[];
% if ~exist('mychan','var')
%     fprintf('A channel selection is required at this time\n');
%     return;
% end

% if strcmpi('STI101',mychan) || strcmpi('STI102',mychan)
%     fprintf('Sorry! Not processing channels ''STI101'' or ''STI102'' at this time\n');
%     return;
% end


%dspath=[pwd,'/',dsName];
%if ~exist(dsName,'dir')
    %fprintf('Error: Dataset not found in this directory\n');
    %return;
%else fprintf('Reading Datset: %s\n', dsName);
%end


% ctf = ctf_GetParams(dsName)
ctf = bw_CTFGetParams(dsName);

numTrials = ctf(4);
%if ctf.setup.number_trials > 1  % make sure is one trial ds
if numTrials > 1  % make sure this is single Trial ds
    fprintf('Can only process CTF raw (single trial) datasets\n');
    return;
end

labels = bw_CTFGetChannelLabels(dsName);

%find STIM channel indexes and check if our channel is there

%stim_inds=ctf.sensor.index.stim_ref;  %labels @ ctf.sensor.info(Stim_ind).label
%channel_id=strmatch(channel,ctf.sensor.info(Stim_ind).label,'exact');

% Stim Channel types are coded as CTF type '11'
% Note as a default we assume that Stim Channels STI001-STI099 are used binary channels 
% Older Neuromag systems use channels STI0XX as a composite and
% would thus break this code
stim_idx=find(strncmp('STI0',cellstr(labels),4));

% comp_idx=find(strncmp('STI101',{ctf.channel.name},5) || strncmp('STI102',{ctf.channel.name},5));

if isempty(stim_idx)
    fprintf('No Stim channels were found!\n');
    return;
end

% if isempty(mychan_id);
%     fprintf('Channel %s was not found',mychan);
%     return; 
% end

%Collect STIM channel data and make trig data
tnum=0;
dt=1/ctf(5); %sample period

timearray=ctf(12):dt:ctf(13); %time array
for i = 1:length(stim_idx);
    sname = labels(stim_idx(i),:);
    %sdata(:,1) = CTFGetChannelData(dsName,sname , 1, -1);
    [timeb sdata(:,1)] = bw_CTFGetChannelData(dsName,sname);
    
    if std(sdata(:,1))>0 %only channels with triggers (deviations)
        tnum=tnum+1;
        trig(tnum).ch_name=sname;
        %make sure trigger onsets are rising 0->5V
        sdata=abs(sdata-mode(sdata));
        
        trig(tnum).onset_idx(:,1)=find(diff(sdata)>0)+1;
        trig(tnum).times(:,1)=timearray(trig(tnum).onset_idx);
    end    
end

%Collect Composite channel data
% for i = 1:length(stim_idx);
%     comps(i).name=ctf.channel(stim_idx(i)).name;
%     comps(i).data(:,1) = CTFGetChannelData(dspath,comps(i).name , 1, -1);  
% end






