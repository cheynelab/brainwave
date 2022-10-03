function prefs = bw_checkPrefs()
    % new handling of prefs for version 4.0.  
    % Checks for local copy of preferencesfile, if not found asks for 
    % prefs file or just return defaults. 

    localPrefs = strcat(pwd,filesep,'bw_prefs.mat');
    
    if exist(localPrefs,'file')
        r = questdlg('Load previous settings?','Brainwave','Yes','No','Select Settings File','Yes');
        if strcmp(r, 'Yes')
            prefs = bw_readPrefsFile(localPrefs);
        elseif strcmp(r, 'Select Settings File')
            [fname, fpath, ~]=uigetfile('*.mat','Select Settings File:');
            if ~isequal(fname,0)
                fullname=[fpath,fname];         
                prefs = bw_readPrefsFile(fullname);
            end
        else
            prefs = bw_setDefaultParameters;
        end
    else
        prefs = bw_setDefaultParameters;
    end   

end