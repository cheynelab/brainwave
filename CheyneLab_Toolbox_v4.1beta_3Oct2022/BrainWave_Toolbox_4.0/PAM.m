%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% From: Doualot and Achim (2021) A Polarity Alignment Method for Group-Averaging of Event-Related
%       Neural Signals at Source Level in MEG Beamforming Applications.
%       Brain Topography 34:269?271.
%
% function Out=PAM(In);
% For dipole orientations from n cases, In is (n,3), but its columns could also be topographies
% Out is like In but the signs in some rows may have been inverted to make the dipole (or topography) positively correlated
% with the first principal component of the rows of In
% The rows of In are checked for equal sum of squares. A warning is given if some cases would have more influence than others
% on the first principal component
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Out = PAM(In)
    
    SS=sum(In.^2);
    if max(SS)-min(SS)>.001*mean(SS)
        warning('The cases have different sums of squares.'); 
    end
    
    Out=In; 
    
    [C,~]=eigs(In'*In,1); 

    s=find(In*C<0);
    if ~isempty(s)
        Out(s,:)=-Out(s,:); 
    end

end

