function meshFile = dt_import_surfaces

    meshFile = [];
    mesh_dir = [];
    mri_dir = [];
    outputFile = [];
    meshType = [];
    downSample = 1.0;
    
    d = figure('Position',[500 800 600 300],'Name','Import Cortical Surfaces', ...
        'numberTitle','off','menubar','none');
      
    if ispc
        movegui(d,'center')
    end
    
    uicontrol('Style','text',...
        'fontsize',12,...
        'HorizontalAlignment','left',...
        'units', 'normalized',...
        'Position',[0.02 0.77 0.4 0.1],...
        'String','Select Freesurfer or CIVET results directory:');

    mesh_edit = uicontrol('Style','edit',...
        'fontsize',10,...
        'units', 'normalized',...
        'HorizontalAlignment','left',...
        'Position',[0.02 0.7 0.75 0.1],...
        'String','');

    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'units', 'normalized',...
        'Position',[0.8 0.7 0.15 0.1],...
        'String','Browse',...
        'Callback',@select_mesh_callback);  
      
    uicontrol('Style','text',...
        'fontsize',12,...
        'HorizontalAlignment','left',...
        'units', 'normalized',...
        'Position',[0.02 0.57 0.4 0.1],...
        'String','Select directory of MEG co-registered MRI:');
 
    mri_edit = uicontrol('Style','edit',...
        'fontsize',10,...
        'units', 'normalized',...
        'HorizontalAlignment','left',...
        'Position',[0.02 0.5 0.75 0.1],...
        'String','');
    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'units', 'normalized',...
        'Position',[0.8 0.5 0.15 0.1],...
        'String','Browse',...
        'Callback',@select_mri_callback);              
    
    uicontrol('Style','text',...
        'fontsize',12,...
        'HorizontalAlignment','left',...
        'units', 'normalized',...
        'Position',[0.02 0.37 0.4 0.1],...
        'String','Select ouput directory for surface file:');
    
    outfile_edit = uicontrol('Style','edit',...
        'fontsize',10,...
        'units', 'normalized',...
        'HorizontalAlignment','left',...
        'Position',[0.02 0.3 0.75 0.1],...
        'String','');    
   
    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'units', 'normalized',...
        'Position',[0.8 0.3 0.15 0.1],...
        'String','Browse',...
        'Callback',@select_outfile_callback);          
   
    uicontrol('Style','text',...
        'fontsize',12,...
        'HorizontalAlignment','left',...
        'units', 'normalized',...
        'Position',[0.02 0.17 0.4 0.1],...
        'String','DownSample Factor (0.0-1.0):');
    
    downsample_edit = uicontrol('Style','edit',...
        'fontsize',10,...
        'units', 'normalized',...
        'HorizontalAlignment','left',...       
        'Position',[0.02 0.1 0.2 0.1],...
        'String','1.0');       
    
    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'foregroundColor','blue',...
        'units', 'normalized',...
        'Position',[0.75 0.1 0.2 0.1],...
        'String','Import',...
        'Callback',@OK_callback);  
      
    uicontrol('Style','pushbutton',...
        'fontsize',12,...
        'units', 'normalized',...
        'Position',[0.5 0.1 0.2 0.1],...
        'String','Cancel',...
        'Callback','delete(gcf)');
 
    
    
    function OK_callback(~,~)
        % get from text box in case user typed in
        mesh_dir = get(mesh_edit,'string');
        mri_dir = get(mri_edit,'string');        
        outputFile = get(outfile_edit,'string');
        downSample = str2double(get(downsample_edit,'string'));
        
        if downSample < 0.0 || downSample > 1.0
            errordlg('Downsample factor must be between 0.0 and 1.0');
            return;
        end
        
        if ~isempty(mesh_dir) && ~isempty(mri_dir) && ~isempty(outputFile)
            meshFile = dt_importMeshFiles(mesh_dir, mri_dir, outputFile, downSample);
        else
            errordlg('Missing input');
            return;
        end
        
        delete(gcf)
    end
    
    function select_mesh_callback(~,~)
        s =uigetdir('*','Select Surfaces directory...');
        if isequal(s,0)
            return;
        end    
        
        % check if CIVET or FS
        if exist(fullfile(s, 'surfaces'), 'dir') && exist(fullfile(s, 'transforms'), 'dir')
            meshType = 'CIVET';
        elseif exist(fullfile(s, 'surf'), 'dir') && exist(fullfile(s, 'mri', 'transforms'), 'dir')
            meshType = 'FS';
        else
            errordlg('The selected folder does not appear to be a Freesurfer or CIVET output folder');
            return;
        end
        set(mesh_edit,'string',s);      
        
    end

    function select_mri_callback(~,~)
        s =uigetdir('*','Select MRI directory...');   
        if isequal(s,0)
            return;
        end    
        set(mri_edit,'string',s);    
        if ~isempty(meshType)
            if strcmp(meshType,'FS')
                outstr = sprintf('%s%s%s',s,filesep,'FS_SURFACES.mat');
            else  
                outstr = sprintf('%s%s%s',s,filesep,'CIVET_SURFACES.mat');
            end
            set(outfile_edit,'string',outstr);      
        end
    end

   function select_outfile_callback(~,~)
            
            [filename, pathname, ~]=uiputfile('*.mat','Select File Name for Surface file (*.mat) ...');
            if isequal(filename,0)
                return;
            end           
            outputFile = [pathname filename];    
            set(outfile_edit,'string',outputFile);      
    end


    % make modal   
    
    
    uiwait(d);
    
end