function shortNames = bw_truncateSensorNames(channelNames)
    % function to remove sensor labels from MEG channels if they exist
    
    shortNames = [];
    idx = [];
    for i=1:size(channelNames,1)      
        x = strfind(channelNames(i,:),'-');
        if ~isempty(x)
            idx(i) = x;
        end
    end
      
    if isempty(idx)
        shortNames = channelNames;     
        return;        % if no dash do nothing
    end

    % should always be 5 characters, but in case set to longest...
    len = max(idx) - 1;  
    shortNames = channelNames(:,1:len);

end