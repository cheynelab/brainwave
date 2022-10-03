function [uparrow_im]=draw_uparrow

uparrow = [ ...
    '    0    ';
    '   000   ';
    '  00000  ';
    ' 0000000 ';
    '000000000';
    '   000   ';
    '   000   ';
    '   000   '
    '   000   '];

lut(double(' 01')) = [NaN 0 1];
uparrow_im = repmat(lut(uparrow),[1 1 3]);

end