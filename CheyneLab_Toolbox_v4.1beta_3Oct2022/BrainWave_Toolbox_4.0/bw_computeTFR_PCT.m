function TFR = bw_computeTFR(S,freqVec,timeVec,Fs,width, TimeInt, plotMode)
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
% (c) D. Cheyne, 2011. All rights reserved. Based off code by O. Jensen. 
% This software is for RESEARCH USE ONLY. Not approved for clinical use.

% This is the version of bw_computeTFR that uses the parallel processing
% toolbox in Matlab.

    S = S';

    B = zeros(length(freqVec),size(S,2)); 
    disp('Computing time-frequency transformation ...')
    tic;

    if TimeInt(1) == 0 and TimeInt(2) == 0
        tidx = 1:length(timeVec);
    else
        tidx = find(timeVec >= TimeInt(1) & timeVec <= TimeInt(2));
    end
    
    if (plotMode ~= 2)
        fprintf('Subtracting baseline power from %g to %g s...\n', TimeInt);
    end
    
    %checking if parallel toolbox installed
%     toolboxes=ver;
%     hasPCT=0;
%     
%     % disabled - not faster than single core.....
%     for n=1:size(toolboxes,2)
%         hasPCT=strcmp(toolboxes(n).Name,'Parallel Computing Toolbox');
%     end
%    numCores = feature('numCores');
    
    if (hasPCT == 0 || numCores < 4)
        for jj=1:length(freqVec)          
            for ii=1:size(S,1)            
                dt = 1/Fs;
                sf = freqVec(jj)/width;
                st = 1/(2*pi*sf);
                t=-3.5*st:dt:3.5*st;
                A = 1/sqrt(st*sqrt(pi));
                m = A*exp(-t.^2/(2*st^2)).*exp(i*2*pi*freqVec(jj).*t);
                y =conv(detrend(S(ii,:)),m); 
            
                if plotMode == 3
                    l = find(abs(y) == 0); 
                    y(l) = 1;
                    y = y./abs(y);
                    y(l) = 0;
                    y = y(ceil(length(m)/2):length(y)-floor(length(m)/2));
                    B(jj,:) = y + B(jj,:);
                else
                    y = (2*abs(y)/Fs).^2;
                    y = y(ceil(length(m)/2):length(y)-floor(length(m)/2)); 
                    if (plotMode == 2)
                        b = mean(y(tidx));
                        sd = std(y(tidx));
                        B(jj,:) = ((y - b) ./ sd) + B(jj,:);
                    else
                        B(jj,:) = y + B(jj,:);
                    end     
                end
            end
        end
    else
        fprintf('Parallel Computing Toolbox and %d cores available -- multithreading TFR routines...\n', numCores)
        matlabpool open; %%parallel
    
        for jj=1:length(freqVec)
            freqvecindex=freqVec(jj);
            ansval = 0;
            parfor ii=1:size(S,1)
                dt = 1/Fs;
                sf = freqvecindex/width;
                st = 1/(2*pi*sf);
                t=-3.5*st:dt:3.5*st;
                A = 1/sqrt(st*sqrt(pi));
                m = A*exp(-t.^2/(2*st^2)).*exp(i*2*pi*freqvecindex.*t);
                y =conv(detrend(S(ii,:)),m);
 
                if plotMode == 3
                    l = find(abs(y) == 0); 
                    y(l) = 1;
                    y = y./abs(y);
                    y(l) = 0;
                    y = y(ceil(length(m)/2):length(y)-floor(length(m)/2));
                    ansval= y + ansval;
                else
                    y = (2*abs(y)/Fs).^2;
                    y = y(ceil(length(m)/2):length(y)-floor(length(m)/2)); 
                    if (plotMode == 2)
                        b = mean(y(tidx));
                        sd = std(y(tidx));
                        ansval = ((y-b) ./ sd) + ansval;
                    else
                        ansval = y + ansval;
                    end     
                end
            end
            B(jj,:) = ansval;
        end
    
        matlabpool close; %%parallel
    end
            
    if plotMode ==3
        B = B/size(S,1);     
        TFR = abs(B);   
        toc
        disp('PLF Status: Finished');        
    else
        TFR = B/size(S,1);        
        if (plotMode ~= 2)
            if (plotMode == 1)
                fprintf('Converting to percent change ...\n');
            end

            for jj=1:length(freqVec)
                t = TFR(jj,:);
                b = mean(t(tidx));
                TFR(jj,:) = t-b;

                if ( plotMode == 1)
                    TFR(jj,:) = ( TFR(jj,:)/b ) * 100.0;
                end

            end
        end
    toc
    disp('TFR Status: Finished');
    end
end