//////////////////////////////////////////////////////////////////////

This directory contains software developed by Dr. Douglas Cheyne at the 
Hospital for Sick Children with the support of grants from the Canadian 
Institutes of Health Research and the Natural Sciences and Engineering 
Research Council of Canada.
 
This software is intended for RESEARCH PURPOSES ONLY and is not 
to be distributed without permission.

The beamformer images and virtual sensor calculations are based on algorithm described in:

   Cheyne D., Bakhtazad L. and Gaetz W. (2006) Spatiotemporal mapping of cortical activity accompanying 
   voluntary movements using an event-related beamforming approach.  Human Brain Mapping 27: 213-229.
and
   Cheyne D., Bostan AC., Gaetz W, Pang EW. (2007) Event-related beamforming: A robust method for 
   presurgical functional mapping using MEG. Clinical Neurophysiology, Vol 118 pp. 1691-1704.

Differential images based on modified version of SAM algorithm described in:
   Robinson, S. and Vrba J. (1999).  Functional neuroimaging by synthetic aperture magnetometry. 
   In: Nenonen J, Ilmoniemi RJ, Katila T, editors. 
   Biomag 2000: Proceedings of the 12th International Conference on Biomagnetism. p 302-305

Copyright (c) 2005 2010, Douglas O. Cheyne, PhD, All rights reserved.

/////////////////////////////////////////////////////////////////////

This software can be compiled on Linux 32 or 64 bit or OS X version 10.5 for Intel Macs

How to compile the megcode applications:

Step 1. make a clean compile of libraries as follows:

> cd ../megcode/MEGlib
> make clean			# remove any existing object files
> make <platform>             # <platform> = linux32, linux64, or imac

Step 2. Compile application

e.g., to compile makeBeamformer application

> cd ../megcode/MEGapps/makeBeamformer
> make clean		# remove any existing object files
> make <platform>       # <platform> = linux32, linux64, or imac

> make install		# copies executable to directory ${HOME}/bin 
 or
> cp makeBeamformer <directory in your path>



NOTES:
1. not tested on Windows and likely will not compile or work!  **

2.  to compile  mex files the platform does not need to be  specified. 
Matlab must be installed and the gcc compiler selected using mex -setup

