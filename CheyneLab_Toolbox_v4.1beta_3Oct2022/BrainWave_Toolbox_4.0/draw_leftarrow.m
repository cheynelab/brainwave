function [leftarrow_im]=draw_leftarrow

leftarrow = [ ...
    '         0     ';
    '       000     ';
    '     00000     ';
    '   00000000000 ';
    '  000000000000 ';
    '   00000000000 ';
    '     00000     ';
    '       000     ';
    '         0     ';];

lut(double(' 01')) = [NaN 0 1];
leftarrow_im = repmat(lut(leftarrow),[1 1 3]);

end