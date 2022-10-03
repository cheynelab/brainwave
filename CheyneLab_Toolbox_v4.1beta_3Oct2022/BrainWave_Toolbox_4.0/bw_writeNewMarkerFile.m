%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function markerFileName = bw_writeNewMarkerFile(dsName, trig)
%
% create a new CTF-readable MarkerFile.mrk in the dataset folder 'dsName'
%       - will overwrite any existing MarkerFile.mrk !
%
% input format:
%       for n markers
%       trig.ch_name(1:n) - markerNames
%       trig.trials(1:n) - marker trial number (starts at zero!)  
%       trig.latencies(1:n) - marker latencies
%       where,  trig(i).trials(1:M) = array of integers 
%               trig(i).latencies(1:M) = array of doubles
%
%   D. Cheyne, March, 2022
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function markerFileName = bw_writeNewMarkerFile(dsName, trig)

    if isempty(trig) 
        return;
    end
    
    no_markers=numel(trig);
       
    markerFileName = strcat(dsName,filesep,'MarkerFile.mrk');
    fprintf('writing marker file %s\n', markerFileName);

    fid = fopen(markerFileName,'w','n');
        
    fprintf(fid,'PATH OF DATASET:\n');
    fprintf(fid,'%s\n\n\n',dsName);
    fprintf(fid,'NUMBER OF MARKERS:\n');
    fprintf(fid,'%g\n\n\n',no_markers);

    for i = 1:no_markers

        fprintf(fid,'CLASSGROUPID:\n');
        fprintf(fid,'3\n');
        fprintf(fid,'NAME:\n');
        fprintf(fid,'%s\n',trig(i).ch_name);
        fprintf(fid,'COMMENT:\n\n');
        fprintf(fid,'COLOR:\n');
        fprintf(fid,'blue\n');
        fprintf(fid,'EDITABLE:\n');
        fprintf(fid,'Yes\n');
        fprintf(fid,'CLASSID:\n');
        fprintf(fid,'%g\n',i);
        fprintf(fid,'NUMBER OF SAMPLES:\n');
        fprintf(fid,'%g\n',length(trig(i).trials));
        fprintf(fid,'LIST OF SAMPLES:\n');
        fprintf(fid,'TRIAL NUMBER\t\tTIME FROM SYNC POINT (in seconds)\n');
        for t = 1:length(trig(i).trials)-1
            fprintf(fid,'                  %+g\t\t\t\t               %+0.6f\n',trig(i).trials(t), trig(i).latencies(t));
        end
        fprintf(fid,'                  %+g\t\t\t\t               %+0.6f\n\n\n',trig(i).trials(end), trig(i).latencies(end));
    end

    fclose(fid);

end
