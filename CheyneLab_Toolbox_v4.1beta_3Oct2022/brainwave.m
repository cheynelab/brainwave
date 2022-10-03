function brainwave
    % start brain wave
    
    % version 4.0 - this function is now called from parent folder (e.g., CheyneLab_Toolbox)
    % to avoid confusion (spaces in BW directory name etc).
    
    s = which('brainwave');
    [tpath,~,~] = fileparts(s);
    bw_path = strcat(tpath,filesep,'BrainWave Toolbox 4.0');
    addpath(bw_path);
    bw_main_menu      % this adds all other paths needed
    
end