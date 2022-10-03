%% script to convert marker files from Benoit to default format
%
% August, 2011  D. Cheyne
%

function convertEventFile(eventFile)

t = importdata(eventFile);

fname = sprintf('%s_converted.evt',eventFile(1:end-4));
fid = fopen(fname,'w');

fprintf(fid,'Tsec\tTriNo\tCode\n');
for i=1:size(t,1)
   fprintf(fid,'%.4f\t%d\t%d\n',t(i,1)*0.001, round(t(i,2)), round(t(i,3)) );
end

fclose(fid);