function simfile = sim_write_simfile(num_sources, dipole_params,sim_params)

path = pwd;
simfile = fullfile(path, 'SAVE.sim');
fid = fopen(simfile,'wt');
fprintf(fid,'SIM_FILE_VER_2\n');
fprintf(fid,'//     index	xpos(cm)	ypos(cm)	zpos(cm)	xo		yo		zo		Q (nAm)\n');

% write dip params
fprintf(fid,'Dipoles\n');
fprintf(fid,'{\n');
for i=1:num_sources
    fprintf(fid,'\t%d:\t%.2f\t%.2f\t%.2f\t%.4f\t%.4f\t%.4f\t%f\n',i, dipole_params.xpos(i),dipole_params.ypos(i),dipole_params.zpos(i),dipole_params.xori(i),dipole_params.yori(i),dipole_params.zori(i),dipole_params.moment(i));
end
fprintf(fid,'}\n');
fprintf(fid,'\n');

% write sim params
fprintf(fid,'//	    index	frequency(Hz)	onset(s)	duration(s)	onset jitter(s)	amp. jitter(percent)	type\n');
fprintf(fid,'Params\n');
fprintf(fid,'{\n');
for i=1:num_sources
    if strcmp(sim_params.sourceType(i),'source_file')
        sourfile_str = strcat('file:',char(sim_params.sourceFile(i)));
        fprintf(fid,'\t%d:\t%f\t%f\t%f\t%f\t%f\t%s\n',i, sim_params.frequency(i),sim_params.onsetTime(i),sim_params.duration(i),sim_params.onsetJitter(i),sim_params.amplitudeJitter(i),sourfile_str);
    else        
        fprintf(fid,'\t%d:\t%f\t%f\t%f\t%f\t%f\t%s\n',i, sim_params.frequency(i),sim_params.onsetTime(i),sim_params.duration(i),sim_params.onsetJitter(i),sim_params.amplitudeJitter(i),char(sim_params.sourceType(i)));
    end
end
fprintf(fid,'}\n');


fclose(fid);
end