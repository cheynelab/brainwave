function output_txt = myfunction(obj,event_obj,dcmObj,max_x,max_y,max_z,max_mag,mag)
% Display the position of the data cursor
% obj          Currently not used (empty)
% event_obj    Handle to event object
% output_txt   Data cursor text string (string or cell array of strings).

pos = get(event_obj,'Position');
output_txt = {['MAX PEAK'],...
    ['X: ',num2str(max_x),' Y: ',num2str(max_y),' Z: ',num2str(max_z),' Mag: ',num2str(max_mag)],...
%     ['Max Magnitude: ',num2str(max_mag)],...
    ['CURRENT PEAK'],...
    ['X: ',num2str(pos(1),4),' Y: ',num2str(pos(2),4),' Z: ',num2str(pos(3),4),' Mag: ',num2str(mag)]};

% % If there is a Z-coordinate in the position, display it as well
% if length(pos) > 2
%     output_txt{end+1} = ['Z: ',num2str(pos(3),4)];
% end

% output_txt{end+1}=['Magnitude: ',num2str(mag)];
