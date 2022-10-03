%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function bw_markerFile2Excel(markerFileName, saveName)
%
% reads CTF MarkerFile and converts to csv format to export to Excel
%
% D. Cheyne 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function bw_markerFile2Excel(markerFileName, saveName)


    [markerNames, markerData] = bw_readCTFMarkerFile( markerFileName );

    if isempty(markerData)
        return;
    end
    
    fid = fopen(saveName, 'w');
    
    for k=1:numel(markerData)
        fprintf('writing marker data for %s\n', markerNames{k});
        markerName = markerNames{k};
        
        markerTimes = markerData{k};
        
        fprintf(fid,'%s-trial', markerName);
        for j=1:size(markerTimes,1)
            fprintf(fid,', %.5f', markerTimes(j,1)-1);  % bw_readCTFMarkerFile adds one to trial number
        end
        fprintf(fid,'\n');
        
        fprintf(fid,'%s-latency', markerName);
        for j=1:size(markerTimes,1)
            fprintf(fid,', %.5f', markerTimes(j,2));
        end    
        fprintf(fid,'\n');
    end

    fclose(fid);


end