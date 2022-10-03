function trig = getKITEvents(eventFile)

    trig = [];

    if ~exist(eventFile,'file')
        return;
    end
    t =importdata(eventFile);
    
    trigNames = unique(t.data(:,2));
    for k=1:size(trigNames,1)
        idx = find(t.data(:,2)== trigNames(k) );
        fprintf('Reading %d events for trigger %d\n', length(idx), trigNames(k) );
        latencyList = t.data(idx,1);
        
        % put in struct format for bw_write_MarkerFile
        trig(k).ch_name = num2str( trigNames(k) );
        trig(k).times = latencyList;        
               
    end

end     