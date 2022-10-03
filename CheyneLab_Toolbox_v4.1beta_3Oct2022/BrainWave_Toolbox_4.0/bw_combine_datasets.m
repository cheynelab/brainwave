   
function bw_combine_datasets(startPath)        

        % to multiselect directories use uigetdir2          
        fileList = uigetdir2(startPath,'Select datasets to combine');
        
        if isempty(fileList)
            return;
        end

        % build default save name
        s1 = char(fileList(1));
        s2 = char(fileList(2));
        [p,n,e] = fileparts(s1);
        [~,n2,~] = fileparts(s2);
        n = strcat(n,'+',n2);
        saveName = fullfile(p,[n e]);
     
        [dsName,dsPath,~] = uiputfile('*.ds','Select Name for combined dataset:',saveName);
        if isequal(dsName,0)
            return;
        end
        saveName = fullfile(dsPath,dsName);   

        if exist(saveName,'dir')
            s = sprintf('The dataset %s already exists! Overwrite?', saveName);
            response = questdlg(s,'BrainWave','Yes','No','Yes');
            if strcmp(response,'No')
                return;
            end
        end

        bw_combineDs(fileList, saveName);
        
        % in case mex function fails
        if ~exist(saveName,'file')
            beep;
            return;
        end
        
        % create concatenated markerFile ...
        % have to match marker names... 
        
        trialOffset = 0.0;
        
        for j=1:numel(fileList)
            
            dsName = char(fileList(j));
            header = bw_CTFGetHeader(dsName);
                        
            markerFileName = sprintf('%s%smarkerFile.mrk',dsName,filesep);
           
            if ~exist(markerFileName,'file')
                s = sprintf('Warning: Marker File not found for dataset %s',dsName);             
                errordlg(s);
                continue;
            end
            
            [markerNames, markerData] = bw_readCTFMarkerFile(markerFileName);
            
            fprintf('Concatenating marker data for %s...\n',dsName)
            if j == 1  
                for k=1:numel(markerNames)
                    newMarkerData(k).ch_name = char(markerNames{k});  
                    markerTimes = markerData{k};
                    trials = markerTimes(:,1) - 1;  % bw_readCTFMarkerFile adds one to trial number
                    latencies = markerTimes(:,2);
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
                        trials = markerTimes(:,1) - 1 + trialOffset; 
                        latencies = markerTimes(:,2);
                        
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
                        latencies = markerTimes(:,2);
                        newMarkerData(idx).trials = trials + trialOffset; 
                        newMarkerData(idx).latencies = latencies; 
                    end
                end               
            end
            
            % add total number of trials to trial offset for next file
            trialOffset = trialOffset + header.numTrials;                    
        end
        
        bw_writeNewMarkerFile(saveName,newMarkerData);               
        
        
        
    end