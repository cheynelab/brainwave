%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function function aal_region = dt_get_AAL_region (index)
%
% get an AAL atlas brain region by atlas index
%
% D. Cheyne, October 2021
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function aal_region = dt_get_AAL_region (index )
              
    aal_labels = dt_get_AAL_labels;
   
    aal_region = [];
    
    for k=1:size(aal_labels,1)
        s = aal_labels{k};
        aal_name = s(1:end-5);
        aal_index = str2num(s(end-3:end));       
        if index == aal_index
            aal_region = aal_name;
            break;
        end
    end
    
end
