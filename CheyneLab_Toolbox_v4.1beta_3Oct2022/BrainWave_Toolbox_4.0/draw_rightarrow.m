function [rightarrow_im]=draw_rightarrow

rightarrow = [ ...
    '     0         ';
    '     000       ';
    '     00000     ';
    ' 00000000000   ';
    ' 000000000000  ';
    ' 00000000000   ';
    '     00000     ';
    '     000       '
    '     0         ';];

lut(double(' 01')) = [NaN 0 1];
rightarrow_im = repmat(lut(rightarrow),[1 1 3]);

end