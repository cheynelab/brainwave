# ![BW_logo_small](https://user-images.githubusercontent.com/15018908/156004784-f3533ea2-fbfd-4a5d-a9da-e076c4b0052c.png)  BrainWave SOFTWARE 
Current and archived versions of our MEG analysis MATLAB-based toolbox, BrainWave, created by Douglas Cheyne and contributors.

**BrainWave** is a user-friendly, MATLAB-based GUI for the computation  of beamformer source images from magnetoencephalography (MEG) neuroimaging data. 
It has integrated 4-dimensional image sequences and simple point-and-click waveform plotting as well as time-frequency analyses. 

**SOFTWARE REQUIREMENTS**

BrainWave has been tested on Linux (Ubuntu 16+, CentOS 6.0+), Mac (10.6+), and Windows (7 and 10) Operating Systems. It uses compiled C-mex functions for optimization and efficient handling of MEG data. It also uses multi-threaded libraries for fast computation of beamformer images, workstations with multiple core
processors are recommended, with at least 4 GB of RAM. MATLAB 2014b or higher is required. No custom toolboxes are required to run most BrainWave features (with
the exception of 
hilbert transform analysis which requires the MATLAB Signal Processing Toolbox). For spatial normalization and group analysis, it is necessary to 
install the most recent version of the Statistical Parametric Mapping (SPM) Matlab toolbox (SPM8 or SPM12) available from the Welcome Trust Centre for
Neuroimaging, UCL, London. For the extraction of surfaces from MRI images we recommend also installing the University of Oxford's FMRIB Software Library (FSL, 
version 5.0 or newer) Toolbox, which is available for various OS platforms. BrainWave works natively with the CTF Systems MEG data format (.ds files), however the
CTF MEG4 software suite does not need to be installed to run BrainWave. Finally, the high resolution 3D surface extractions for surface rendered beamforming 
within BrainWave, are generated by third-party programs: CIVET and FreeSurfer. 

Please visit these sites to learn more about how to obtain these files. 
SPM: https://www.fil.ion.ucl.ac.uk/spm/software/download/
FSL: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation
CIVET: http://www.bic.mni.mcgill.ca/ServicesSoftware/CIVET
FreeSurfer: https://surfer.nmr.mgh.harvard.edu/


**BrainWave INSTALLATION**

1. Download the latest version of BrainWave software.
2. Unzip the downloaded folder and save it to a safe location on your computer.
3. Open MATLAB and add the path to the BrainWave folder.
4. Ensure SPM and FSL software are installed (see respective websites on how to do this). Add paths and necessary environments in MATLAB.
5. In MATLAB command window, type: >> brainwave 


**BrainWave SUPPORT**

Have you come across an issue while running BrainWave? We can help!
Feel free to email us your questions and comments at any time. We'd be happy to hear from you! 
Visit our website contacts page https://cheynelab.utoronto.ca/contact


**DISCLAIMER & LICENSE**

This software package was developed by Dr. Douglas Cheyne and other contributors at the Toronto Hospital for Sick Children with support from the Ontario Brain Institute (OBI), Canadian Institutes of Health Research (CIHR) and the Natural Sciences and Engineering Research Council of Canada (NSERC). This program is made available at no cost to the research community. It is to be utilized for **RESEARCH PURPOSES ONLY, and has not been approved for clinical use.** Distribution of BrainWave is not permitted without permission by the developer and does not hold any warranty. Errors encountered using the program may be reported to the developer
