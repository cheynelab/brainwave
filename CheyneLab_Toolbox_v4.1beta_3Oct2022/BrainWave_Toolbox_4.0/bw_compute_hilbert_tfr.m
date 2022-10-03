function TFR_DATA = bw_compute_hilbert_tfr(S, freqVec, timeVec, Fs, filter_width, saveSingleTrials)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%    function TFR_DATA = bw_compute_hilbert_tfr(S, freqVec, timeVec, Fs, filter_width, saveSingleTrials)
%
% (c) D. Cheyne, Sept, 2014
% function to compute TFR using hilbert transform instead of wavelet
% (similar to Krish Singh's "bertogram")
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if ~exist('saveSingleTrials','var')
        saveSingleTrials = false;
    end
    
    wh = waitbar(0,'Please wait...');
    for n=0:10
        waitbar(n/100,wh,'initializing...');
    end

    S = S';
    S_ave = mean(S);
      
    MAG = zeros(length(freqVec),size(S,2)); 
    PHASE = zeros(length(freqVec),size(S,2)); 
    MEAN = zeros(length(freqVec),size(S,2));
  
    if saveSingleTrials
        TRIAL_MAG = zeros(size(S,1),length(freqVec), size(S,2));
        TRIAL_PHASE = zeros(size(S,1),length(freqVec), size(S,2));
    end
    
    fprintf('*********************************************************** .\n');
    fprintf('*** WARNING: This is a beta test version of Hilbert TFR  *** \n');
    fprintf('*********************************************************** \n');

    fprintf('Computing time-frequency transformation using hilbert transform (filter width = %d)...\n', filter_width)
    tic;
    waitbar(n/100,wh,'computing time-frequency transformation...');
    
    for jj=1:length(freqVec)   
            
        % compute wavelet for this frequency bin for all trials
        fc = freqVec(jj);        
        bw =[fc - (filter_width/2.0) fc + (filter_width/2.0)]; 

        if bw(1) < 1                % do not go to DC ! 
            bw(1) = 1;
        end
        
        if bw(2) > freqVec(end)     % may be OK to go over filter range ???
            bw(2) = freqVec(end);
        end
        
        for ii=1:size(S,1)
            
            % filter data 
            
            ydata = bw_filter(S(ii,:), Fs, bw);
            
            h = hilbert(ydata);
            
            % compute phase             
%             PHASE(jj,:) = PHASE(jj,:) + angle(h);      % sum phase for freq jj
            PHASE(jj,:) = PHASE(jj,:) + h ./abs(h);      % sum phase for freq jj
            if saveSingleTrials
                TRIAL_PHASE(ii,jj,:) = angle(h);
            end
                       
            % compute magnitude          
            MAG(jj,:) = MAG(jj,:) + abs(h);      % sum power
            if saveSingleTrials
                TRIAL_MAG(ii,jj,:) = abs(h);
            end

        end
                
        % compute magnitude for average
        ydata = bw_filter(S_ave, Fs, bw);
        h = hilbert(ydata);
        MEAN(jj,:) = abs(h);      % magnitude for freq jj

        waitbar(jj/length(freqVec),wh,'computing time-frequency transformation...');
    end
    
    toc

    % convert arrays to single precision for smaller file sizes...
    
    PHASE = PHASE/size(S,1);      % PLF = mean phase across trials
    TFR_DATA.PLF = abs(PHASE);      
    TFR_DATA.TFR = MAG/size(S,1); % TFR = mean magnitude across trials  
    TFR_DATA.MEAN = MEAN;
     
    TFR_DATA.freqVec = freqVec;
    TFR_DATA.timeVec = timeVec;
    if saveSingleTrials
        TFR_DATA.TRIAL_MAGNITUDE = single(TRIAL_MAG);  % save single precision
        TFR_DATA.TRIAL_PHASE = single(TRIAL_PHASE);
        clear TRIAL_PHASE;
        clear TRIAL_MAG
    end
    
    clear PHASE;
    clear MAG;
    clear MEAN;
    
    waitbar(1,wh,'done!');
    close(wh);
    
end