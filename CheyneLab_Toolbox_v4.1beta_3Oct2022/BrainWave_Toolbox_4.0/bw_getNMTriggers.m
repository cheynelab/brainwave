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
% revised Nov 19, 2012    - D. Cheyne
%                           - modfied to ues bw mex functions.
% modified Dec 4, 2013 Pferrari
%                       - now also scans STI101/201 Elekta Composite Chans
%%%%%

trig=[];
bin_idx=[];
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

% Stim Channel from Elekta are coded as CTF type '11'
% It is assumed that Channels STI001-STI099 are binary (5V+/-) stim channels
% and that Channels STI101 and STI201 are composite trigger code value stim
% channels.
% Warning: Some older Elekta systems use STI004 as a composite channel and
% would thus break may break this code.



%Find Trigger channels






% Set some values
tnum=0; % trigger counter
dt=1/ctf(5); %sample period
timearray=ctf(12):dt:ctf(13); %time array for marker times


%Collect Binary Stim channel data and make/add to trig data
bin_idx=find(strncmp('STI0',cellstr(labels),4));
if isempty(bin_idx)
    fprintf('No Binary channels were found!\n');
else
    for i = 1:length(bin_idx);
        sname = labels(bin_idx(i),:);
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
end

%Collect Composite STI101 channel data and add to Trigger datacomp1_idx= strncmp('STI101',cellstr(labels),6); %index of STI101
comp1_idx=find(strncmp('STI101',cellstr(labels),6)); %index of STI201
if isempty(comp1_idx)
    fprintf('FYI: No STI101 channel was found!\n');
else
    
    sname = labels(comp1_idx,1:6);
    [timeb sdata(:,1)] = bw_CTFGetChannelData(dsName,sname);
    
    if std(sdata)==0
        fprintf('FYI: No markers found on STI101!\n');
    else
        
        %Assume the mode represents baseline state
        dmin=min(sdata);% Deal with non-zero mode
        dmode=mode(sdata);
        ndata=sdata+(2*(dmode-dmin));%add a constant 2*negative separation
        ndata(ndata==(dmode+(2*(dmode-dmin))))=0;%zero out mode
        
        ddata(1)=diff(ndata(1:2)); ddata(2:length(ndata))=diff(ndata);
        
        comp1_trig(:,1)=find(ddata>0); %onset index
        comp1_trig(:,2)=sdata(comp1_trig(:,1)); %Onset Value
        comp1_trig(:,3)=timeb(comp1_trig(:,1)); %Onset time
        
        newtrigs=unique(comp1_trig(:,2));% Get unique trig values
        for i=1:length(newtrigs);% cycle through and add new trigs
            tnum=tnum+1;
            trig(tnum).ch_name=char([sname,'_',num2str(newtrigs(i))]);
            
            new_idx=find(comp1_trig(:,2)==newtrigs(i));
            trig(tnum).times=comp1_trig(new_idx,3);%this trig time
            trig(tnum).idx=comp1_trig(new_idx,1);%this trig sample
        end
    end
end



%Collect Composite STI201 channel data and add to Trigger datacomp1_idx= strncmp('STI201',cellstr(labels),6); %index of STI201
comp2_idx=find(strncmp('STI201',cellstr(labels),6)); %index of STI201
if isempty(comp2_idx)
    fprintf('FYI: no STI201 channel was found!\n');
else
    
    sname = labels(comp2_idx,1:6);
    [timeb sdata(:,1)] = bw_CTFGetChannelData(dsName,sname);
    
    if std(sdata)==0
        fprintf('FYI: No markers found on STI201!\n');
    else
        %Assume the mode represents baseline state
        dmin=min(sdata);% Deal with non-zero mode
        dmode=mode(sdata);
        ndata=sdata+(2*(dmode-dmin));%add a constant 2*negative separation
        ndata(sdata==(dmode+(2*(dmode-dmin))))=0;%zero out mode
        
        ddata(1)=diff(ndata(1:2)); ddata(2:length(ndata))=diff(ndata);
        
        
        
        comp2_trig(:,1)=find(ddata>0); %onset index
        comp2_trig(:,2)=sdata(comp2_trig(:,1)); %Onset Value
        comp2_trig(:,3)=timeb(comp2_trig(:,1)); %Onset time
        
        newtrigs=unique(comp2_trig(:,2));% Get unique trig values
        for i=1:length(newtrigs);% cycle through and add new trigs
            tnum=tnum+1;
            trig(tnum).ch_name=char([sname,'_',num2str(newtrigs(i))]);
            
            new_idx=find(comp2_trig(:,2)==newtrigs(i));
            trig(tnum).times=comp2_trig(new_idx,3);%this trig time
            trig(tnum).idx=comp2_trig(new_idx,1);%this trig sample
        end
    end
end






