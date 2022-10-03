%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function markerFileName = bw_concatenate_datasets(startPath)
%
% Function to concatenate multiple single trial datasets into one
% contiguous dataset
% startPath - option to define starting point for open file dialog
% 
%   D. Cheyne, March, 2022
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function bw_concatenate_datasets(startPath)        

        if ~exist('startPath','var')
            startPath = pwd;
        end
        
        % to multiselect directories use uigetdir2          
        fileList = uigetdir2(startPath,'Select datasets to concatenate');
        
        if isempty(fileList)
            return;
        end

        % build default save name
        s1 = char(fileList(1));
        s2 = char(fileList(2));
        [p,n,e] = fileparts(s1);
        [~,n2,~] = fileparts(s2);
        idx = strfind(n2,'_');
        if ~isempty(idx)
            n2 = n2(idx(end)+1:end);
        end
        n = strcat(n,'+',n2);
        saveName = fullfile(p,[n e]);
     
        [dsName,dsPath,~] = uiputfile('*.ds','Select Name for concatenated dataset:',saveName);
        if isequal(dsName,0)
            return;
        end
        
        saveName = fullfile(dsPath,dsName);   

        if exist(saveName,'dir')
            s = sprintf('The dataset %s already exists! Overwrite?', saveName);
            response = bw_warning_dialog(s);
            if response == 0
                return;
            end
        end

        % call mex function to concatenate data - will check file limit
        fprintf('Concatenating data ...\n')
        bw_concatenateDs(fileList, saveName);
            
        % in case mex function fails
        if ~exist(saveName,'file')
            beep;
            return;
        end
        
        % create concatenated markerFile ...
        % have to convert latencies to absolute time in case of preTrigTime
        % have to match marker names... 
        
        latencyOffset = 0.0;
        
        for j=1:numel(fileList)
            
            latencyCorrection = 0.0;
            dsName = char(fileList(j));
            header = bw_CTFGetHeader(dsName);
            if header.epochMinTime < 0.0
              latencyCorrection = -header.epochMinTime;
            end
                        
            markerFileName = sprintf('%s%smarkerFile.mrk',dsName,filesep);

            [markerNames, markerData] = bw_readCTFMarkerFile(markerFileName);
            
            fprintf('Concatenating marker data for %s...\n',dsName)
            if j == 1  
                for k=1:numel(markerNames)
                    newMarkerData(k).ch_name = char(markerNames{k});  
                    markerTimes = markerData{k};
                    trials = markerTimes(:,1) - 1;  % bw_readCTFMarkerFile adds one to trial number
                    latencies = markerTimes(:,2) + latencyCorrection;
                    newMarkerData(k).trials = trials; 
                    newMarkerData(k).latencies = latencies; 
                end
            else       
                % match and add to existing markers
                for k=1:numel(newMarkerData)    
                    name = cellstr(newMarkerData(k).ch_name);
                    [~, idx] = ismember(name,markerNames);
                    if idx > 0
                        markerTimes = markerData{idx};
                        trials = markerTimes(:,1) - 1; 
                        latencies = markerTimes(:,2) + latencyCorrection + latencyOffset;
                        
                        newMarkerData(k).trials = [ newMarkerData(k).trials; trials ];
                        newMarkerData(k).latencies = [ newMarkerData(k).latencies; latencies];
                        % remove from list
                        markerNames(idx) = [];
                        markerData(idx) = [];                        
                    end
                end
                % add any new markers
                if ~isempty(markerNames)
                    for k=1:numel(markerNames)
                        idx = numel(newMarkerData) + 1;
                        newMarkerData(idx).ch_name = char(markerNames{k});  
                        markerTimes = markerData{k};
                        trials = markerTimes(:,1) - 1;  % bw_readCTFMarkerFile adds one to trial number
                        latencies = markerTimes(:,2) + latencyCorrection + latencyOffset;
                        newMarkerData(idx).trials = trials; 
                        newMarkerData(idx).latencies = latencies; 
                    end
                end               
            end
            
            % add total duration to latency offset to next file
            latencyOffset = latencyOffset + header.epochMaxTime - header.epochMinTime;                    
        end
        
        bw_writeNewMarkerFile(saveName,newMarkerData);          
   
        
        
    end