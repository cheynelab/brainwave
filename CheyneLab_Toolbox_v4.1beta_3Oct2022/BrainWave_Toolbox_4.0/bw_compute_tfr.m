function TFR_DATA = bw_compute_tfr(S, freqVec, timeVec, Fs, width, saveSingleTrials)
%       BW_COMPUTETFR
%
%   function TFR = bw_computeTFR(S,freqVec,timeVec,Fs,width, TimeInt, plotMode)
%
%   DESCRIPTION: The function requires the signal (S), the absolute time 
%   values for the trial (timeVec), the range of frequencies over which to 
%   calculate the time-frequency energy (freqVec), sampling frequency (Fs),
%   the number of cycles in the wavelet (width), the array specifying the 
%   start and end times in seconds for the baseline (TimeInt), and finally 
%   whether you want to plot with power relative to the baseline (0), the 
%   percent change in power relative to the baseline (1), plot as a z-score 
%   (2) or plot the phase-locking factor (3) using plotMode. Using all this
%   information, the function will convolute the Signal with a morlet
%   wavelet and then calculate the average of a time-frequency energy 
%   representation with multiple trials (TFR).
%
% (c) D. Cheyne and Natascha van Lieshout 2011. All rights reserved. 
%
% NOTES:  This routine is derived from the old makeTFR.m and makePLF.m routines
% from Ole Jensen's 4D Toolbox with additional Includes a
% correction to original code for normalization of wavelet energy.
% re-written by Natascha van Lieshout to combine both TFR and 
% PLF in one routine and also compute morlet wavelet in main routine  
%
% Reference for Morlet wavelet algorithm can be found in:
% Tallon-Baudry et al., J. Neurosci. 15, 722-734 (1997)
%
% Z-score transformation from
% Tallon-Baudry et al.,(2005) Cereb. Cortex 15:654
%
% July 27, 2011
% D. Cheyne - added waitbar 
%
% November 22, 2011 
% D. Cheyne - major revision of bw_computeTFR.m with new name 
% now generates TFR struct with both amplitude and  phase.  
% Also, optimized code quite a bit and added more comments
% Removed Z-score option and replaced with power in dB.
%
% March 2013
% added option to save single trial TFR array - 
% 


    if ~exist('saveSingleTrials','var')
        saveSingleTrials = false;
    end
    
    h = waitbar(0,'Please wait...');
    for n=0:10
        waitbar(n/100,h,'initializing...');
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
    
    fprintf('Computing time-frequency transformation using morlet wavelets (cycles = %d)...\n', width)
   
    tic;
    dt = 1/Fs;  % dwel is constant
    waitbar(n/100,h,'computing time-frequency transformation...');
    for jj=1:length(freqVec)   
            
        % compute wavelet for this frequency bin 
        sf = freqVec(jj)/width;
        st = 1/(2*pi*sf);
        t=-3.5*st:dt:3.5*st;    
        A = 1/sqrt(st*sqrt(pi));
        m = A*exp(-t.^2/(2*st^2)).*exp(i*2*pi*freqVec(jj).*t);
            
        for ii=1:size(S,1)          
            % convolve wavelet and data for each trial
            ydata =conv(detrend(S(ii,:)),m); 

            % compute phase angle avoiding divide by zero
            y = ydata;
            idx = find(abs(y) == 0); 
            y(idx) = 1;  
            y = y./abs(y);  % phase = real(y) / sqrt( real(y)^2 + imag(y^2))
            y(idx) = 0;  
            y = y(ceil(length(m)/2):length(y)-floor(length(m)/2));
            PHASE(jj,:) = y + PHASE(jj,:);      % sum phase for freq jj
            if saveSingleTrials
                TRIAL_PHASE(ii,jj,:) = y;
            end
                       
            % compute magnitude
            y = ydata;
            y = (2*abs(y)/Fs).^2;
            y = y(ceil(length(m)/2):length(y)-floor(length(m)/2));     
            MAG(jj,:) = y + MAG(jj,:);      % else just sum power
            if saveSingleTrials
                TRIAL_MAG(ii,jj,:) = y;
            end

        end
        
        % compute magnitude for average
        y = conv(detrend(S_ave),m);
        y = (2*abs(y)/Fs).^2;
        y = y(ceil(length(m)/2):length(y)-floor(length(m)/2));     
        MEAN(jj,:) = y;      % magnitude for freq jj

        waitbar(jj/length(freqVec),h,'computing time-frequency transformation...');
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
    
    waitbar(1,h,'done!');
    close(h);
    
end