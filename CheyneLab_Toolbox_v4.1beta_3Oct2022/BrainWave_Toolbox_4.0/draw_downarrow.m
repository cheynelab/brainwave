function [downarrow_im]=draw_downarrow

downarrow = [ ...
    '   000   '
    '   000   ';
    '   000   ';
    '   000   ';
    '000000000';
    ' 0000000 ';
    '  00000  ';
    '   000   ';
    '    0    '];
lut(double(' 01')) = [NaN 0 1];
downarrow_im = repmat(lut(downarrow),[1 1 3]);

end