%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  *** modified for Version 4.0 - must now pass the marker file and
%  optionally the event file
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function errorFlag = con2ctf(conFile, markerFile, eventFile)
%
%   function errorFlag = con2ctf(conFile, [markerFile], [elpFile])
%
%   DESCRIPTION: Function to convert a KIT continuous (.con) file to a
%   continuous CTF .ds format
%
%   if markerFile not specified will try to find the '_preB<n>.mrk' file 
%   where <n> is the block number
%
%   if elpFile not specified will look for an .elp file in the same directory
% 
%   (c) D. Cheyne, 2016. All rights reserved.
%   Revised by Merron Woodbury and Douglas Cheyne, August 2018
%   This software is for RESEARCH USE ONLY. Not approved for clinical use.

    errorFlag = -1;

    % should not need to check
%     if isempty(strfind(which('getYkgwHdrAcqCond'),'getYkgwHdrAcqCond'))
%         fprintf('You must install the YokogawaMEGReader_R1.04.00 toolbox and add to your Matlab path\n');
%         return;
%     end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % get dataset info from .con file

    header = read_yokogawa_header(conFile);

    if ~strcmp(header.dataType, 'continuous_raw')
        fprintf('Can only convert KIT continuous (*.con) files ...\n');
        return;
    end

    % minimal information in header
    numMEGChannels = header.numSensors;
    numADC = header.numADC;
    sampleRate = header.sampleRate;
    numSamples = header.numSamples;
    
    % header doesn't provide the true LP setting and KIT Acq software
    % actually allows up to the Nyquist! However, downsample menu generates
    % error if not less - should find fix for this...
    
    bandpass = [0 sampleRate/3.0];  
    validChannels = ones(numMEGChannels,1);

    % create the .ds folder and res4 file.
    dsName = strrep(conFile,'.con','.ds');           
    if ~exist(dsName,'dir')
        fprintf('Creating .ds folder %s\n', dsName);
        mkdir(dsName);
        fileattrib(dsName,'+w','ug');
    end
    [~, basename, ~] = fileparts(dsName);
    res4File = strcat(dsName, filesep, basename,'.res4');   
    
    % If not specified, try to find the elp and marker files
    
    if ~exist('elpFile','var')
        elpFile = dir('*.elp');
        if isempty(elpFile)
            fprintf('could not find a .elp file (digitized HPI coils) for this subject ...\n');
            return;
        end
        if elpFile(1).name(1) == '.'
            elpFile = elpFile(2).name;
        else 
            elpFile = elpFile(1).name;
        end
    end

    if ~exist('markerFile','var')
        fprintf('No marker (.mrk) file specified for co-registration for this dataset...\n')
        % mrk file with head shape (named same as .con file until block ID, then
        return;
    end

    [res4, fid_pts_head, fid_pts_dewar] = yokogawa2res4(dsName, conFile, markerFile, elpFile, 1, 0, bandpass, validChannels);  
    if isempty(res4)
        return;
    end
    
    % call writeRes4, which writes the res4 struct into the res4 file
    % header

    fprintf('writing CTF res4 header...\n');

    err = yokogawa_writeRes4(res4File,res4,8); % MAX_COILS = 8 for now (change?)
    if (err == -1)
        fprintf('writeRes4 returned error\n');
        return;
    end

    % write a head coil file for CTF software...
    writeHeadCoilFile(dsName, fid_pts_head, fid_pts_dewar); 

    % write marker data if .evt file was passed
    if exist(eventFile,'file')
        fprintf('Found event file %s...\n', eventFile);       
        trig = getKITEvents(eventFile);
        write_MarkerFile(dsName,trig);       
    else
        fprintf('Event file %s not found. No marker file was created\n', eventFile);       
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % extract trials and write binary data to .meg4 format

    % open meg4 file for writing data...

    [~,NAME,~] = fileparts(dsName);
    fname = strcat(NAME,'.meg4');
    meg4File = fullfile(dsName,fname);

    fid2 = fopen(meg4File,'wb','ieee-be');
    if (fid2 == -1)
        fprintf('Could not open %s for writing...\n', meg4File);
        return;
    end

    head = sprintf('MEG41CP');
    fwrite(fid2,[head(1:7),char(0)],'uint8');

    tic

    fprintf('writing data... \n');

    % get one trial of data - returns [nchans x nsamples] 
    % returns all channels (MEG + empty or EEG channels ...)

    tmp_data = getYkgwData(conFile, 0, numSamples);    
    trial = tmp_data(1:numMEGChannels,:);
    trial = round(trial * header.MEGgain);
    fwrite(fid2,trial','int32');
    
    trial = tmp_data(numMEGChannels+1:numMEGChannels+numADC,:);
    trial = round(trial * header.ADCgain);
    fwrite(fid2,trial','int32');
    
    fprintf('... all trials converted\n');

    toc

    clear trial;
    
    fclose(fid2);

    errorFlag = 0;

end

