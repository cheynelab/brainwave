function markerData = bw_readKITMarkers(filePath)

% D. Cheyne, July, 2018
% how to read Marker data directly from KIT files 
% 
% from Matt Sanderson:
% Hi Doug.
% To retrieve the marker locations directly from an mrk file, first you 
% read out the 4 bytes as an integer at +0xC0 of the .mrk file.
% This is the absolute offset of the data, so then jump to this location. 
% From this location move forward by 0x104 bytes. The 4 byte value of this 
% location is the number of markers.
% For each marker coil you will do:
% - skip 0x28 bytes.
% - read 3 doubles (8 bytes each) as x, y, z locations
% 
% Version 2.0. Sept, 2018
% modified to always return 5 HPI positions, bad coils are set to zero?


fileID = fopen(filePath);
fseek(fileID,192,'bof');
offset = fread(fileID, 1, 'uint32');
fseek(fileID,offset,'bof');
fseek(fileID,260,'cof');
nmarkers = fread(fileID, 1, 'uint32');

% sometimes nmarkers > 5, read first 5 only ...
% but if less than 5 markers we won't know which ones are missing
if nmarkers < 5  
    fprintf('Error reading Marker File...\n');
    return;
end

markerData = zeros(5,3);
for j=1:5   
    fseek(fileID,40,'cof');
    m = fread(fileID, 3, 'double');
    markerData(j,:) = m(1:3) * 100.0;  % return in cm                
end

fclose(fileID);

end
