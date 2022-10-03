/////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//		bw_makeDifferential
//
//		C-mex function to make differential source images using a minimum-variance beamformer
//      with either optimized scalar or fixed orientation sources
//
//      derived from makeBeamformer 
// 
//
//		(c) Douglas O. Cheyne, 2005-2010  All rights reserved.
//
//		revisions:
//				2.0  Aug, 2010 - compiled with newest libraries.
//				2.2  - release version with check on input arguments 
//				2.4  - recompiled with library revisions (Nov, 2010) 
//                   -  additional arguments to makeDifferential for covariance data - leave turned off for now...
//				2.5  - recompiled with separate ctflib and bwlib
//              2.7  - vers 3.0beta - added code and print statement that alternate dataset is being used for baseline covariance
////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "mex.h"

#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#if defined _WIN64 || defined _WIN32
	#include <pthread.h>//pthread library for windows, added by zhengkai
#endif

#include "../../../ctflib/headers/datasetUtils.h"
#include "../../../ctflib/headers/BWFilter.h"
#include "../../../ctflib/headers/path.h"
#include "../../../bwlib/bwlib.h"

#define VERSION_NO 2.5

double			**imageData; 
double			**covArray;
double			**icovArray;
vectorCart		*voxelList;
vectorCart		*normalList;
ds_params		dsParams;
ds_params       covDsParams;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    

	double			*dataPtr;	
	char			*dsName;
	char			*covDsName;
	char			*hdmFile;
    char			*voxFileName;
	
	int				buflen;
	int				status;
  	unsigned int	m;
	unsigned int	n; 
	char			msg[256];
	char			filename[256];
	char			savename[256];

	
	char			imageFileBaseName[256];
	char			analysisDir[256];
	char			cmd[256];
	char			s[256];

	
	double			*val;
	FILE			*fp;

	// makeVS params...
	
	int				numVoxels;
	
	double			lowPass;		
	double			highPass;
	double			minTime;
	double			maxTime;
	
	double			activeStartTime;
	double			activeEndTime;
	double			baselineStartTime;
	double			baselineEndTime;
	
	int				imageType;
	
	double			regularization = 0.0;	
	bool			computeRMS = false;	
	bool			useHdmFile = false;
	bool			useVoxFile = false;
	bool			useVoxNormals = true;
	
    int             outputFormat = 0;  // 0 = CIVET *.txt, 2 = Freesurfer overlay *.w

    
	bool			useReverseFilter = true;
	bool			useCovAsControl = false;
	
	double			xMin;     
	double			xMax;
	double			yMin;			
	double			yMax;
	double			zMin;			
	double			zMax;        
 	double			stepSize;
	
	double			sphereX = 0.0;
	double			sphereY = 0.0;
	double			sphereZ = 5.0;
	
	bf_params		bparams;
	filter_params 	fparams;
	
 	/* Check for proper number of arguments */
	int n_inputs = 20;
	int n_outputs = 1;
 	mexPrintf("bw_makeDifferential ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO); 
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("\nincorrect number of input or output arguments for bw_makeDifferential  ...\n");
		mexPrintf("\nCalling syntax:\n"); 
		mexPrintf("[fileName] = bw_makeDifferential(dsName, covDsName, hdmFileName, useHdmFile, filter, boundingBox, stepSize, voxelFileName, useVoxFile, useVoxNormals,\n");
		mexPrintf("   sphere, noiseRMS, regularization, imageType, activeWindow, baselineWindow, computeRMS, useReversingFilter, useCovAsControl, outputFormat\n");
		mexPrintf("\n returns: filename of image file saved to disk \n");
		return;
	}

	///////////////////////////////////
	// get datasest name 
  	if (mxIsChar(prhs[0]) != 1)
		mexErrMsgTxt("Input [0] must be a string.");
 	if (mxGetM(prhs[0]) != 1)
		mexErrMsgTxt("Input [0] must be a row vector.");
   	// Get the length of the input string.
  	buflen = (mxGetM(prhs[0]) * mxGetN(prhs[0])) + 1;
  	dsName = (char *)mxCalloc(buflen, sizeof(char));
  	status = mxGetString(prhs[0], dsName, buflen);  	// Copy the string into a C string
 	if (status != 0) 
		mexWarnMsgTxt("Not enough space. String is truncated.");        
	
	
	///////////////////////////////////
	// get covariance datasest name - may be same as dsName
  	if (mxIsChar(prhs[1]) != 1)
		mexErrMsgTxt("Input [1] must be a string for covDsName dataset name.");
 	if (mxGetM(prhs[1]) != 1)
		mexErrMsgTxt("Input [1] must be a row vector.");
   	// Get the length of the input string.
  	buflen = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 1;
  	covDsName = (char *)mxCalloc(buflen, sizeof(char));
  	status = mxGetString(prhs[1], covDsName, buflen);  	// Copy the string into a C string
 	if (status != 0)
		mexWarnMsgTxt("Not enough space for covDsName. String is truncated.");

	///////////////////////////////////
	// get headModel file name
  	if (mxIsChar(prhs[2]) != 1)
		mexErrMsgTxt("Input [2] must be a string.");
  	// Get the length of the input string.
  	buflen = (mxGetM(prhs[2]) * mxGetN(prhs[2])) + 1;
	if (buflen < 1)
	{
		sprintf(msg, "Must pass valid hdm File name.");
		mexWarnMsgTxt(msg);
		mxFree(dsName);
		return;
	}
	else
	{
		hdmFile = (char *)mxCalloc(buflen, sizeof(char));
		status = mxGetString(prhs[2], hdmFile, buflen);  	// Copy the string into a C string
	}
	if (status != 0)
		mexErrMsgTxt("Not enough space for head Model filename. String is truncated.");
	
	val = mxGetPr(prhs[3]);
	useHdmFile = (int)*val;
	
	if (mxGetM(prhs[4]) != 1 || mxGetN(prhs[4]) != 2)
		mexErrMsgTxt("Input [4] must be a row vector [hipass lowpass].");
	dataPtr = mxGetPr(prhs[4]);
	highPass = dataPtr[0];
	lowPass = dataPtr[1];

	if (mxGetM(prhs[5]) != 1 || mxGetN(prhs[5]) != 6)
		mexErrMsgTxt("Input [5] must be row vector [xmin xmax ymin ymax zmin zmax]");
	dataPtr = mxGetPr(prhs[5]);
	xMin = dataPtr[0];
	xMax = dataPtr[1];
	yMin = dataPtr[2];
	yMax = dataPtr[3];
	zMin = dataPtr[4];
	zMax = dataPtr[5];

	val = mxGetPr(prhs[6]);
	stepSize = *val;
	
	///////////////////////////////////
	// get voxFile name
  	if (mxIsChar(prhs[7]) != 1)
		mexErrMsgTxt("Input [7] must be a string for dataset name.");
 	if (mxGetM(prhs[7]) != 1)
		mexErrMsgTxt("Input must be a row vector.");
   	// Get the length of the input string.
  	buflen = (mxGetM(prhs[7]) * mxGetN(prhs[7])) + 1;
  	voxFileName = (char *)mxCalloc(buflen, sizeof(char));
  	status = mxGetString(prhs[7], voxFileName, buflen);  	// Copy the string into a C string
 	if (status != 0)
		mexWarnMsgTxt("Not enough space. String is truncated.");
	
	val = mxGetPr(prhs[8]);
	useVoxFile = (int)*val;
	
	val = mxGetPr(prhs[9]);
	useVoxNormals = (int)*val;
	
	if (mxGetM(prhs[10]) != 1 || mxGetN(prhs[10]) != 3)
		mexErrMsgTxt("Input [10] must be a row vector [sphereX sphereY sphereZ].");
	dataPtr = mxGetPr(prhs[10]);
	sphereX = dataPtr[0];
	sphereY = dataPtr[1];
	sphereZ = dataPtr[2];
	
	val = mxGetPr(prhs[11]);
	bparams.noiseRMS = *val;
	bparams.normalized = true;
	
	val = mxGetPr(prhs[12]);
	regularization = *val;

	val = mxGetPr(prhs[13]);
	imageType = (int)*val;
	
	if (mxGetM(prhs[14]) != 1 || mxGetN(prhs[14]) != 2)
		mexErrMsgTxt("Input [14] must be a row vector [activeWindowStart activeWindowEnd].");
	dataPtr = mxGetPr(prhs[14]);
	activeStartTime = dataPtr[0];
	activeEndTime = dataPtr[1];
	
	if (mxGetM(prhs[15]) != 1 || mxGetN(prhs[15]) != 2)
		mexErrMsgTxt("Input [15] must be a row vector [baselineWindowStart baselineWindowEnd].");
	dataPtr = mxGetPr(prhs[15]);
	baselineStartTime = dataPtr[0];
	baselineEndTime = dataPtr[1];
	
	val = mxGetPr(prhs[16]);
	computeRMS = (int)*val;

	val = mxGetPr(prhs[17]);
	useReverseFilter = (int)*val;
	
	val = mxGetPr(prhs[18]);
	useCovAsControl = (int)*val;
	
    val = mxGetPr(prhs[19]);
	outputFormat = (int)*val;
    
	////////////////////////////////////////////////
	// setup directory paths and filenames
	////////////////////////////////////////////////

//added file separator for windows, added by zhengkai

	sprintf(analysisDir, "%s%sANALYSIS", dsName,FILE_SEPARATOR);	
	
	if ( ( fp = fopen(analysisDir, "r") ) == NULL )
	{
		mexPrintf ("Creating new ANALYSIS subdirectory in %s\n", dsName);
		sprintf (cmd, "mkdir %s", analysisDir);
		system (cmd);
	}
	else
		fclose(fp);
	    
	if ( !readMEGResFile( dsName, dsParams) )
	{
		mexPrintf("Error reading res4 file for %s/n", dsName);
		return;
	}
	
	mexPrintf("dataset:  %s, (%d trials, %d samples, %d sensors, epoch time = %g to %g s)\n", 
			  dsName, dsParams.numTrials, dsParams.numSamples, dsParams.numSensors, dsParams.epochMinTime, dsParams.epochMaxTime);
	mexEvalString("drawnow");
		
    if (activeStartTime < dsParams.epochMinTime || activeEndTime > dsParams.epochMaxTime)
    {
        mexPrintf("Active window values (%g to %g seconds) exceeds data length (%g to %g seconds)\n", activeStartTime, activeEndTime, dsParams.epochMinTime, dsParams.epochMaxTime);
        return;
    }
    
    if (useCovAsControl)
    {
        if ( !readMEGResFile( covDsName, covDsParams) )
        {
            mexPrintf("Error reading res4 file for %s/n", covDsParams);
            return;
        }
        if (baselineStartTime < covDsParams.epochMinTime || baselineEndTime > covDsParams.epochMaxTime)
        {
            mexPrintf("Alternate baseline window values (%g to %g seconds) exceeds data length (%g to %g seconds)\n", baselineStartTime, baselineEndTime, covDsParams.epochMinTime, covDsParams.epochMaxTime);
            return;
        }
    }
    else
    {
        if (baselineStartTime < dsParams.epochMinTime || baselineEndTime > dsParams.epochMaxTime)
        {
            mexPrintf("Baseline window values (%g to %g seconds) exceeds data length (%g to %g seconds)\n", baselineStartTime, baselineEndTime, dsParams.epochMinTime, dsParams.epochMaxTime);
            return;
        }
    }
	
	if ( !init_dsParams( dsParams, &sphereX, &sphereY, &sphereZ, hdmFile, useHdmFile) )
	{
		mexPrintf("Error initializing dsParams and head model\n");
		return;
	}
		
	if (computeRMS)
		bparams.type = BF_TYPE_RMS;
	else
	{
		if (useVoxFile && useVoxNormals)
			bparams.type = BF_TYPE_FIXED;
		else
			bparams.type = BF_TYPE_OPTIMIZED;
	}

	bparams.sphereX = sphereX;
	bparams.sphereY = sphereY;
	bparams.sphereZ = sphereZ;
		
	if (useHdmFile)
		mexPrintf("Using head model file %s (mean sphere = %g %g %g)\n", hdmFile,  bparams.sphereX, bparams.sphereY, bparams.sphereZ);  
	else
		mexPrintf("Using single sphere %g %g %g\n",  sphereX, sphereY, sphereZ);  
		
	if (bparams.normalized)
		mexPrintf("units = pseudoZ (noiseRMS = %g Tesla/sqrt(Hz))\n", bparams.noiseRMS);
	else
		mexPrintf("units = nanoAmpere-meter\n");
	mexEvalString("drawnow");

	// setup filter 
	if ( highPass == 0 && lowPass == 0)
	{
		bparams.hiPass = dsParams.highPass;			// still need to know bandpass of data!
		bparams.lowPass = dsParams.lowPass;
		fparams.hc = bparams.lowPass;			// fparams used to determine bandpass and get name for covariance files etc...
		fparams.lc = bparams.hiPass;
		fparams.enable = false;
		printf("**No filter specified. Using bandpass of dataset (%g to %g Hz)\n", bparams.hiPass, bparams.lowPass);
	}
	else
	{
		bparams.hiPass = highPass;  
		bparams.lowPass = lowPass;
		fparams.enable = true;
		if ( bparams.hiPass == 0.0 )
			fparams.type = BW_LOWPASS;
		else
			fparams.type = BW_BANDPASS;
		fparams.bidirectional = useReverseFilter;
		fparams.hc = bparams.lowPass;
		fparams.lc = bparams.hiPass;
		fparams.fs = dsParams.sampleRate;
		fparams.order = 4;	// 
		fparams.ncoeff = 0;				// init filter
		
		if (build_filter (&fparams) == -1)
		{
			mexPrintf("Could not build filter.  Exiting\n");
			return;
		}
		
		if (fparams.bidirectional)
			mexPrintf("Applying filter from %g to %g Hz (bidirectional)\n", bparams.hiPass, bparams.lowPass);
		else
			mexPrintf("Applying filter from %g to %g Hz (non-bidirectional)\n", bparams.hiPass, bparams.lowPass);

	}
	
   	if ( useVoxFile )
	{
		fp = fopen(voxFileName, "r");
		if (fp == NULL)
		{
			mexPrintf("Couldn't open voxfile  %s\n", voxFileName);
			return;
		}
		fgets(s, 256, fp);
		sscanf(s, "%d", &numVoxels);
		
		if (useVoxNormals)
			mexPrintf("Computing images for %d voxels specified in %s (with cortical constraints) \n", numVoxels, voxFileName);
		else
			mexPrintf("Computing images for %d voxels specified in %s (without cortical constraints) \n", numVoxels, voxFileName);
		
		voxelList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
		if ( voxelList == NULL)
		{
			mexPrintf("Could not allocate memory for voxel lists\n");
			return;
		}
		
		normalList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
		if ( normalList == NULL)
		{
			mexPrintf("Could not allocate memory for normal lists\n");
			return;
		}
		
		for (int i=0; i < numVoxels; i++)
		{
		    fgets(s, 256, fp);
		    sscanf(s, "%lf %lf %lf %lf %lf %lf",
				   &voxelList[i].x, &voxelList[i].y, &voxelList[i].z,
				   &normalList[i].x, &normalList[i].y, &normalList[i].z);
		}
		
		fclose(fp);
	}
	else
	{
		///////////////////
		// initialize grid
		
		double dx = (xMax - xMin) / stepSize;
		double dy = (yMax - yMin) / stepSize;
		double dz = (zMax - zMin) / stepSize;	    
		
		// add 1 voxel for zero crossing i.e., sets range to -10 to -10 inclusive	    
		int xVoxels = (int)dx + 1;
		int yVoxels = (int)dy + 1;
		int zVoxels = (int)dz + 1;	
		
		// get true range based on number of voxels
		xMax = xMin + ( (xVoxels-1)*stepSize);
		yMax = yMin + ( (yVoxels-1)*stepSize);
		zMax = zMin + ( (zVoxels-1)*stepSize);    
		
		numVoxels = xVoxels * zVoxels * yVoxels;
		
		// allocate memory for voxel list
		
		voxelList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
		if ( voxelList == NULL)
		{
			mexPrintf("Could not allocate memory for voxel lists\n");
			return;
		}
		
		normalList = (vectorCart *)malloc( sizeof(vectorCart) * numVoxels );
		if ( normalList == NULL)
		{
			mexPrintf("Could not allocate memory for voxel lists\n");
			return;
		}
		
		int index = 0;
		for (int i=0; i< xVoxels; i++)
		{
			for (int j=0; j< yVoxels; j++)
			{
				for (int k=0; k< zVoxels; k++)
				{
					// voxel location relative to coord. system origin
					double x = xMin + (i * stepSize);
					double y = yMin + (j * stepSize);
					double z = zMin + (k * stepSize);
					
					voxelList[index].x = x;
					voxelList[index].y = y;
					voxelList[index].z = z;
					
					normalList[index].x = 1;
					normalList[index].y = 0;
					normalList[index].z = 0;										
					index++;
				}
			}
		}
		mexPrintf("Using regular reconstruction grid with bounding box = [x = %g %g, y= %g %g, z= %g %g], resolution [%g cm] (%d voxels)\n", 
			   xMin, xMax, yMin, yMax, zMin, zMax, stepSize, numVoxels );
	}
	
	mexEvalString("drawnow");

	
	////////////////////////////////////////////////////////////////////////
	// set up file names for writing data...
	////////////////////////////////////////////////////////////////////////
	// filename always start with this...

	sprintf(imageFileBaseName, "image");	
		
	sprintf(imageFileBaseName, "%s,%g-%gHz", imageFileBaseName, bparams.hiPass, bparams.lowPass);
 	////////////////////////////////////////////////////////////////////////

	
	char addName[256];
	if (useVoxFile)
	{
		removeFilePath(voxFileName, s);
		removeDotExtension(s, addName);
		sprintf(imageFileBaseName, "%s,_vox_%s",imageFileBaseName, addName);
		if (!useVoxNormals)
			sprintf(imageFileBaseName,"%s_NC", imageFileBaseName);
	}
	
	if (useCovAsControl)
	{
		removeFilePath(covDsName, s);
		removeDotExtension(s, addName);
		sprintf(imageFileBaseName, "%s,bDs_%s",imageFileBaseName, addName);
	}
	if (regularization > 0.0)
		sprintf(imageFileBaseName,"%s,reg=%g", imageFileBaseName, regularization);
	
	if (computeRMS)
		sprintf(imageFileBaseName,"%s_RMS", imageFileBaseName);
	
	char outFileName[256];
	
	if ( imageType == BF_IMAGE_PSEUDO_Z ) 
		sprintf(outFileName, "%s_A=%g_%g_Z", imageFileBaseName, activeStartTime, activeEndTime);
	else if ( imageType == BF_IMAGE_PSEUDO_T )
		sprintf(outFileName, "%s_A=%g_%g,B=%g_%g_T", imageFileBaseName, activeStartTime, activeEndTime, baselineStartTime, baselineEndTime);  
	else
		sprintf(outFileName, "%s_A=%g_%g,B=%g_%g_F", imageFileBaseName, activeStartTime, activeEndTime, baselineStartTime, baselineEndTime);  
	
	
	// allocate memory for a single image - could be more (e.g., sliding window...)
	
	int numLatencies = 1;
	imageData = (double **)malloc( sizeof(double *) * numLatencies );
	if (imageData == NULL)
	{
		mexPrintf("memory allocation failed for imageData array");
		return;
	}
	for (int i = 0; i < numLatencies; i++)
	{
		imageData[i] = (double *)malloc( sizeof(double) * numVoxels );
		if ( imageData[i] == NULL)
		{
			mexPrintf( "memory allocation failed for imageData array" );
			return;
		}
	}
	
	// generate image...
	// Nov 19, 2010 - added option to pass a different covariance dataset - for now just set option off and pass dsName
	//
	if ( imageType == BF_IMAGE_PSEUDO_Z ) 
		mexPrintf("computing single state image for active window %g to %g s\n", activeStartTime, activeEndTime); 
	else
		mexPrintf("computing differential image for active window %g to %g s and baseline window %g to %g s \n", activeStartTime, activeEndTime, baselineStartTime, baselineEndTime);
	mexEvalString("drawnow");

	
	if (useCovAsControl)
	{
		mexPrintf("using alternate dataset (%s) for SAM baseline window\n", covDsName);
        mexEvalString("drawnow");
		if ( !computeDifferentialMultiDs(imageData, dsName, dsParams, covDsName, fparams, bparams, regularization, numVoxels,
								  voxelList, normalList, activeStartTime, activeEndTime, baselineStartTime, baselineEndTime, imageType) )
		{
			mexPrintf( "error returned from computeDifferentialMultiDs\n" );
			return;
		}
	}
	else
	{
		if ( !computeDifferential(imageData, dsName, dsParams, covDsName, true, fparams, bparams, regularization, numVoxels,
								  voxelList, normalList, activeStartTime, activeEndTime, baselineStartTime, baselineEndTime, imageType) )
		{
			mexPrintf( "error returned from computeDifferential\n" );
			return;
		}
	}
	mexEvalString("drawnow");

	// save image to file
	int	samType;
	if ( imageType == BF_IMAGE_PSEUDO_Z ) 
		samType = SAM_UNIT_SPMZ;
	else if ( imageType == BF_IMAGE_PSEUDO_T )
		samType = SAM_UNIT_SPMT;
	else
		samType = SAM_UNIT_SPMF;

#if _WIN32||WIN64
	sprintf(filename, "%s\\%s", analysisDir, outFileName);
#else
	sprintf(filename, "%s/%s", analysisDir, outFileName);
#endif
	

	if (!useVoxFile)
	{
        sprintf(savename, "%s.svl", filename);
		mexPrintf("Saving image in CTF .svl format as %s\n", savename);
		saveVolumeAsSvl(savename, voxelList, imageData[0], numVoxels, xMin, xMax, yMin, yMax, zMin, zMax, stepSize, SAM_UNIT_SPMZ);
    }
    else
    {
        if (outputFormat == 0) // plain text file (for BrainView)
        {
            sprintf(savename, "%s.txt", filename);
            mexPrintf("Saving image in ASCII text file %s\n", savename);
            fp = fopen(savename, "w");
            if ( fp == NULL)
            {
                mexPrintf("Couldn't open ASCII file %s\n", savename);
                return;
            }
            for (int voxel=0; voxel<numVoxels; voxel++)
                fprintf(fp, "%g\n",imageData[0][voxel]);
            fclose(fp);
        }
        else if (outputFormat == 1) // freesurfer .w format
        {
            unsigned int num;
            unsigned char byte1;
            unsigned char byte2;
            unsigned char byte3;
            sprintf(savename, "%s.w", filename);
            mexPrintf("Saving image as Freesurfer Overlay file %s\n", savename);
            fp = fopen(savename, "wb");
            if ( fp == NULL)
            {
                mexPrintf("Couldn't open file %s\n", savename);
                return;
            }
            // write unused latency value type int16
            unsigned short temps = 0;
            unsigned short sval = ToFile(temps);
            fwrite(&sval,  sizeof(unsigned short), 1, fp);
            
            // write numvoxels and each voxel index as a 3-byte integer
            // have to byte swap to big-endian
            num = numVoxels;
            byte1 = num & 0xff;
            byte2 = (num >> 8) & 0xff;
            byte3 = (num >> 16) & 0xff;
            fwrite(&byte3,  sizeof(unsigned char), 1, fp);
            fwrite(&byte2,  sizeof(unsigned char), 1, fp);
            fwrite(&byte1,  sizeof(unsigned char), 1, fp);
            
            for (int voxel=0; voxel<numVoxels; voxel++)
            {
                num = voxel;
                byte1 = num & 0xff;
                byte2 = (num >> 8) & 0xff;
                byte3 = (num >> 16) & 0xff;
                fwrite(&byte3,  sizeof(unsigned char), 1, fp);
                fwrite(&byte2,  sizeof(unsigned char), 1, fp);
                fwrite(&byte1,  sizeof(unsigned char), 1, fp);
                float temp = imageData[0][voxel];
                float fval = ToFile((float)temp);
                
                fwrite(&fval, sizeof(float),1, fp);
            }
            fclose(fp);
        }
        else
        {
            mexPrintf("Unknown file format code for surface (%d) .. no files written \n", outputFormat);
            return;
        }
    
    }
	
	plhs[0] = mxCreateString(savename);
	
	///////////////////////////////////
	// change for version 2.5 - always save vox file

#if _WIN32||WIN64
	sprintf(filename,"%s\\%s.vox", analysisDir, imageFileBaseName);
#else
	sprintf(filename,"%s/%s.vox", analysisDir, imageFileBaseName);
#endif
    
    printf("writing vox file with computed orientations to %s\n", filename);
    
    fp = fopen(filename, "w");
    if ( fp == NULL)
    {
        mexPrintf("Couldn't open voxel file %s\n", filename);
        return;
    }
    
    fprintf(fp, "%d\n", numVoxels);
    for (int i=0; i< numVoxels; i++)
    {
        fprintf(fp, "%.2f\t%.2f\t%.2f\t%.3f\t%.3f\t%.3f\n", 
                voxelList[i].x, voxelList[i].y, voxelList[i].z,
                normalList[i].x, normalList[i].y, normalList[i].z);
    }
    return;
	
	///////////////////////////////////
	// free temporary arrays for this routine

	for (int i = 0; i < numLatencies; i++)
		free(imageData[i]);
	free(imageData);
	
	free(voxelList);
	free(normalList);
	
	mxFree(dsName);
	mxFree(hdmFile);
	
    mexPrintf("... all done\n");
    mexEvalString("drawnow");

    
	return;
         
}
    
}


