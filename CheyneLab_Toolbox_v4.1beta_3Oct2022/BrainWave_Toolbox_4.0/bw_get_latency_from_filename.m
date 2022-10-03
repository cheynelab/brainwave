function [latency, label] = bw_get_latency_from_filename(filename)

    [~,NAME,~] = bw_fileparts(filename);

    latency = [];
    label = [];

    % ERB images
    s1 = strfind(NAME,'time=');
    if ~isempty(s1)
        s = NAME(s1+5:end);
        idx = strfind(s,'_');     % strip off appended text (e.g., _AVE)
        if ~isempty(idx) 
            s = s(1:idx-1);
        end
        latency = str2double(s);
        latency = latency * 1000.0;       % return latency in ms 
        label = sprintf('Latency = %.1f ms', latency);
        return;
    end

    % SAM images
    idx = strfind(NAME,'A=');
    if isempty(idx)
        return;
    end     
    labelstr = NAME(idx:end);    % 'A= .....' 
    tidx = strfind(labelstr,'_');

    % return active window start time for sorting ...
    timeStr = labelstr(3:tidx(1)-1);
    latency = str2double(timeStr) * 1000.0;

    % build label for SAM images....
    if contains(labelstr,'B=')                    % is pseudoT       
        label = sprintf('Time windows: %ssec',labelstr(1:tidx(3)-1));
    else
        label = sprintf('Time window: %ssec',labelstr(1:tidx(2)-1));
    end

end