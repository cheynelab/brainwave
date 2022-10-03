function  perm_order = bw_get_perm_table(num_subj,num_perm)
%       BW_GET_PERM_TABLE
%
%   function  perm_order = bw_get_perm_table(num_subj,num_perm)
%
%   DESCRIPTION: Generates a matrix with the dimensions decided by the 
%   number of permutations (num_perm) for the columns and the number of 
%   subjects (num_subj) times two for the rows and where the alternating 
%   rows of the table are randomly exchanged so that each column is unique.
%
% (c) D. Cheyne, 2011. All rights reserved. Based off code by W. Chau and 
% T. Herdman. This software is for RESEARCH USE ONLY. Not approved for 
% clinical use.

%------------------------------------------------------------------------
%
%  Generate the permutation order for 2 conditions for N subjects
%  modified from Wilken Chau / Tony Herdman, 2005
%  D. Cheyne, october, 2005
%  This generates a table of num_perm columns by num_subject * 2 rows
%  where alternating rows are randomly exchanged and each column is unique
%  There are 2^num_subj maximum number of permutations but you can
%  choose less
%  e.g., for 3 subjects and 5 permutations the output matrix might be 
%     1     2     1     2     1
%     2     1     2     1     2
%     3     4     3     4     4
%     4     3     4     3     3
%     5     5     6     6     5
%     6     6     5     5     6
% -----------------------------------------------------------------------

total_possible_perm = power(2,num_subj);

% use different method to generate the random order. For number of
% subjects < 20, generate ALL random orders and select order numbers
% starting from the beginning.  For number of subjects >= 20, generate 
% the order numbers randomly one by one.
%
if (num_subj < 20)
    perm_idx = randperm(total_possible_perm) - 1;
else
    perm_idx = unique(round(rand(1,num_perm*2) * total_possible_perm));
    perm_idx = perm_idx(randperm(length(perm_idx)));
end;
perm_idx = perm_idx(1:num_perm);
row_idx_template = repmat([1:2:2*num_subj],2,1);
perm_order = zeros(num_subj*2,num_perm);
for i=1:num_perm,
    task_order = zeros(2,num_subj);
    order = dec2bin(perm_idx(i),num_subj);
    offset = [order == '1'; order == '0'];
    perm_row_idx = row_idx_template + offset;
    perm_order(:,i) = perm_row_idx(:);
end;
return;
%----------------------------------------------------------