%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% yokogawa2ctf - conversion routines (version 1.0, August 20, 2018)
% 
% This folder contains scripts to convert a KIT MEG system continuous
% dataset (.con file) to a CTF format dataset (.ds folder). Requires that a
% marker (.mrk) and Polhemus HPI (.elp) co-registration files exists in the
% same directory. If a KIT / Macquarie event file (.evt) file exists in the
% directory with the .con file name, it will be used to create CTF
% compatible event marker (Marker.mrk) file. 
%
% The Yokogawa Matlab library (YokogawaMEGReader_R1.04.00)
% must be installed and in your file path. No other libraries are required.
% 
% written by Douglas Cheyne and Merron Woodbury
% Copyright Hospital for Sick Children, Toronto, Canada
%
% Updates
% Version 1.1  Sept 13, 2018
% - modified calculation of HPI / polhemus transformation matrix to exclude
%   coils with zero value or high alignment error to flag bad HPI coils.
% - fixed bug in naming of ADC channels
% - renamed parsePolhemus.m to readElpFile.m
%
% Please forward comments / bug reports to douglas.cheyne@utoronto.ca
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
