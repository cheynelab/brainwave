/////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//		bw_makeVS
//
//		Program to make virtual sensors using a minimum-variance beamformer
//      with either optimized scalar or fixed orientation sources
//
//      derived from makeBeamformer 
// 
//
//		(c) Douglas O. Cheyne, 2005-2010  All rights reserved.
//
//		revisions:
//              2.1  Aug, 2010 - compiled with newest libraries.
//				2.2  - release version with check on input arguments 
//				2.4  - recompiled with library revisions (Nov, 2010)
//				2.5  - recompiled with separate ctflib and bwlib
//				2.6  - added flag for bidirectional filter and covDsName
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


#define VERSION_NO 2.6

double			**vsData; 
double			**covArray;
double			**icovArray;
ds_params		dsParams;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double			*data;
	double			*normalVec;
	double			*time;

	double			*dataPtr;	
	
	char			*dsName;
	char			*covDsName;
	char			*hdmFile;
	
	int				buflen;
	int				status;
  	unsigned int	m;
	unsigned int	n; 
	char			msg[256];
	double			*val;

	// makeVS params...
	int				numSamples;	
	int				numSensors;
	int				numVecs;
    int             numCovSensors;

	double          highPass;
	double          lowPass;
	bool			bidirectional = true;
	
	double			minTime;
	double			maxTime;
	
	double			wStart;
	double			wEnd;
	
	double			regularization = 0.0;
	
	bool			computeRMS = false;
	bool			useHdmFile = false;
	bool			saveSingleTrials = false;
	bool			unused;		// place holder for now...
	
	double			x;
	double			y;
	double			z;
	double			xo;
	double			yo;
	double			zo;
	bool			useNormal = false;
	
	double			sphereX = 0.0;
	double			sphereY = 0.0;
	double			sphereZ = 5.0;
	
	bf_params		bparams;
	filter_params 	fparams;
	
 	/* Check for proper number of arguments */
	int n_inputs = 18;
	int n_outputs = 3;
	mexPrintf("bw_makeVS ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO); 
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("\nincorrect number of input or output arguments for bw_makeVS  ...\n");
		mexPrintf("\nCalling syntax:\n"); 
		mexPrintf("[timeVec data computed_normal] = bw_makeVS(datasetName, covDsName, hdmFileName, useHdmFile, filter, voxel, normal, useNormal, covWindow, \n");
		mexPrintf("         baselineWindow, useBaselineWindow, sphere, normalize, noiseRMS, regularization, computeRMS, useReversingFilter, saveSingleTrials)\n");
		mexPrintf(" \n");
		mexPrintf("\n returns: vectors of latencies and values at each latency and the  dipole orientation. \n");
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
		mexErrMsgTxt("Not enough space for dsName. String is truncated.");
			
	///////////////////////////////////
	// get covariance datasest name - may be same as dsName
  	if (mxIsChar(prhs[1]) != 1)
		mexErrMsgTxt("Input [1] must be a string for covariance dataset name.");
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

	if (mxGetM(prhs[5]) != 1 || mxGetN(prhs[5]) != 3)
		mexErrMsgTxt("Input [5] must be a row vector [x y z].");
	dataPtr = mxGetPr(prhs[5]);
	x = dataPtr[0];
	y = dataPtr[1];
	z = dataPtr[2];

	if (mxGetM(prhs[6]) != 1 || mxGetN(prhs[6]) != 3)
		mexErrMsgTxt("Input [6] must be a row vector [xo yo zo].");
	dataPtr = mxGetPr(prhs[6]);
	xo = dataPtr[0];
	yo = dataPtr[1];
	zo = dataPtr[2];
	
	val = mxGetPr(prhs[7]);
	useNormal = (int)*val;
			 
	if (mxGetM(prhs[8]) != 1 || mxGetN(prhs[8]) != 2)
		mexErrMsgTxt("Input [8] must be a row vector [wStart wEnd].");
	dataPtr = mxGetPr(prhs[8]);
	wStart = dataPtr[0];
	wEnd = dataPtr[1];
	
	if (mxGetM(prhs[9]) != 1 || mxGetN(prhs[9]) != 2)
		mexErrMsgTxt("Input [9] must be a row vector [bStart bStart].");
	dataPtr = mxGetPr(prhs[9]);
	bparams.baselineWindowStart = dataPtr[0];
	bparams.baselineWindowEnd = dataPtr[1];
	
	val = mxGetPr(prhs[10]);
	bparams.baselined = (int)*val;

	if (mxGetM(prhs[11]) != 1 || mxGetN(prhs[11]) != 3)
		mexErrMsgTxt("Input [11] must be a row vector [sphereX sphereY sphereZ].");
	dataPtr = mxGetPr(prhs[11]);
	sphereX = dataPtr[0];
	sphereY = dataPtr[1];
	sphereZ = dataPtr[2];
	
	val = mxGetPr(prhs[12]);
	bparams.normalized = (int)*val;

	val = mxGetPr(prhs[13]);
	bparams.noiseRMS = *val;

	val = mxGetPr(prhs[14]);
	regularization = *val;

	val = mxGetPr(prhs[15]);
	computeRMS = (int)*val;

	val = mxGetPr(prhs[16]);
	bidirectional = (int)*val;

	val = mxGetPr(prhs[17]);
	saveSingleTrials = (int)*val;
	
    
    // ** new - check covariance data file for data range error
    // ** also add check that sensor number agrees
    
    if ( !readMEGResFile( covDsName, dsParams) )
	{
		mexPrintf("Error reading res4 file for %s/n", covDsName);
		return;
	}
	minTime = dsParams.epochMinTime;
	maxTime = dsParams.epochMaxTime;
    numCovSensors = dsParams.numSensors;

	minTime = dsParams.epochMinTime;
	maxTime = dsParams.epochMaxTime;
	
	if (wStart < minTime || wEnd > maxTime)
	{
		mexPrintf("Covariance window values (%g to %g seconds) exceeds data length (%g to %g seconds)\n", wStart, wEnd, minTime, maxTime);
		return;
	}
    
    
	if ( !readMEGResFile( dsName, dsParams) )
	{
		mexPrintf("Error reading res4 file for %s/n", dsName);
		return;
	}
    
    // reset params
    minTime = dsParams.epochMinTime;
	maxTime = dsParams.epochMaxTime;
	
	numSamples = dsParams.numSamples;
	numSensors = dsParams.numSensors;
		
	mexPrintf("dataset:  %s, (%d trials, %d samples, %d sensors, epoch time = %g to %g s)\n", 
			  dsName, dsParams.numTrials, dsParams.numSamples, dsParams.numSensors, dsParams.epochMinTime, dsParams.epochMaxTime);
	

	if ( !init_dsParams( dsParams, &sphereX, &sphereY, &sphereZ, hdmFile, useHdmFile) )
	{
		mexErrMsgTxt("Error initializing dsParams and head model\n");
		return;
	}
	
	// override normal vector
	
	// overrides above
	if (computeRMS)
	{
		bparams.type = BF_TYPE_RMS;
		mexPrintf("Computing RMS (vector) output ...\n");  
	}
	else
	{
		if (useNormal)
		{
			bparams.type = BF_TYPE_FIXED;
			mexPrintf("Using fixed orientation = %g %g %g...\n",  xo, yo, zo);  
		}
		else
		{
			bparams.type = BF_TYPE_OPTIMIZED;	
			mexPrintf("Computing optimized orientation...\n");  
		}
	}	

	// allocate data matrix for virtual sensor data	
	if (saveSingleTrials)
	{
		numVecs = dsParams.numTrials;
		mexPrintf("creating single trial virtual sensor data (# trials = %d) from dataset %s (Fs = %g Samples/s, duration = %g s)\n", 
				  dsParams.numTrials, dsName, dsParams.sampleRate, (maxTime-minTime) );  
	}
	else
	{
		numVecs = 1;			
		mexPrintf("creating average virtual sensor from dataset %s (Fs = %g S/s, duration = %g s)\n", dsName, dsParams.sampleRate, (maxTime-minTime) );  
	}

	bparams.sphereX = sphereX;
	bparams.sphereY = sphereY;
	bparams.sphereZ = sphereZ;
		
	if (useHdmFile)
		mexPrintf("Using head model file %s (mean sphere = %g %g %g)\n", hdmFile,  bparams.sphereX, bparams.sphereY, bparams.sphereZ);  
	else
		mexPrintf("Using single sphere %g %g %g\n",  sphereX, sphereY, sphereZ);  

	if (bparams.baselined)
		mexPrintf("Using baseline window for average (%g to %g s)\n",  bparams.baselineWindowStart, bparams.baselineWindowEnd);  

	
	//////////////////////////////////////////////////////////////////////////////////////
	// Allocate memory to return vs to Matlab in numSamples x 1 double array plus time Vec
	//////////////////////////////////////////////////////////////////////////////////////
	
	
	plhs[0] = mxCreateDoubleMatrix(numSamples, 1, mxREAL); 
	time = mxGetPr(plhs[0]);
	
	plhs[1] = mxCreateDoubleMatrix(numSamples, numVecs, mxREAL); 
	data = mxGetPr(plhs[1]);

	plhs[2] = mxCreateDoubleMatrix(3, 1, mxREAL); 
	normalVec = mxGetPr(plhs[2]);
		
	if (bparams.normalized)
		mexPrintf("units = pseudoZ (noiseRMS = %g Tesla/sqrt(Hz))\n", bparams.noiseRMS);
	else
		mexPrintf("units = nanoAmpere-meter\n");
	
	// setup filter 
	if ( highPass == 0 && lowPass == 0)
	{
		bparams.hiPass = dsParams.highPass;  
		bparams.lowPass = dsParams.lowPass;
		fparams.hc = bparams.lowPass;			// fparams used to get name for covariance file!
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
		fparams.bidirectional = bidirectional;
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

	// generate covariance arrays for primary sensors...
	//
	covArray = (double **)malloc( sizeof(double *) * numSensors );
	if (covArray == NULL)
	{
		mexErrMsgTxt("memory allocation failed for covariance array");
		return;
	}
	for (int i = 0; i < numSensors; i++)
	{
		covArray[i] = (double *)malloc( sizeof(double) * numSensors );
		if ( covArray[i] == NULL)
		{
			mexErrMsgTxt( "memory allocation failed for covariance array" );
			return;
		}
	}
 	icovArray = (double **)malloc( sizeof(double *) * numSensors );
	if (icovArray == NULL)
	{
		mexErrMsgTxt("memory allocation failed for inverse covariance array");
		return;
	}
	for (int i = 0; i < numSensors; i++)
	{
		icovArray[i] = (double *)malloc( sizeof(double) * numSensors );
		if ( icovArray[i] == NULL)
		{
			mexErrMsgTxt( "memory allocation failed for covariance array" );
			return;
		}
	}
	
	mexPrintf("computing %d by %d covariance matrix (%g to %g Hz) for window %g %g s (reg. = %g) for beamformer weights from dataset %s\n",
			  numSensors, numSensors, bparams.hiPass, bparams.lowPass, wStart, wEnd, regularization, covDsName);
		
	computeCovarianceMatrices(covArray, icovArray, numSensors, covDsName, fparams, wStart, wEnd, wStart, wEnd, false, regularization);

	vsData = (double **)malloc( sizeof(double *) * numVecs );
	if (vsData == NULL)
	{
		mexErrMsgTxt( "memory allocation failed for vsData array" );
		return;
	}
	for (int i = 0; i < numVecs; i++)
	{
		vsData[i] = (double *)malloc( sizeof(double) * dsParams.numSamples );
		if ( vsData[i] == NULL)
		{
			mexErrMsgTxt( "memory allocation failed for vsData array" );
			return;
		}
	}	
	
	// generate a VS ...
	//
	if (bparams.type == BF_TYPE_FIXED)
		mexPrintf("creating virtual sensor at location (x=%g y=%g z=%g) with fixed orientation = %.4f %.4f %.4f\n", x, y, z, xo, yo, zo);
	else if (bparams.type == BF_TYPE_RMS)
		mexPrintf("creating RMS output of vector virtual sensor at location (x=%g y=%g z=%g)\n", x, y, z);
	else
		mexPrintf("creating virtual sensor at location (x=%g y=%g z=%g) with optimized orientation ...", x, y, z);

	computeVS(vsData, dsName, dsParams, fparams, bparams, covArray, icovArray, x, y, z, &xo, &yo, &zo, saveSingleTrials);

	if (bparams.type == BF_TYPE_OPTIMIZED)
		mexPrintf(" Computed orientation = %.4f %.4f %.4f\n", xo, yo, zo);
	
	for (int i=0; i<dsParams.numSamples; i++)
		time[i] = double(i-dsParams.numPreTrig)/dsParams.sampleRate;
	
	int idx = 0;
	
	for (int j=0; j<numVecs; j++)
		for (int i=0; i<dsParams.numSamples; i++)
			data[idx++] = vsData[j][i];
		
	
	// return optimized orientation vector
	normalVec[0] = xo;
	normalVec[1] = yo;
	normalVec[2] = zo;
	
	// free memory
	for (int i = 0; i < numSensors; i++)
		free(covArray[i]);
	free(covArray);
	for (int i = 0; i < numSensors; i++)
		free(icovArray[i]);
	free(icovArray);
	for (int i = 0; i < numVecs; i++)
		free(vsData[i]);
	free(vsData);
	
	
	///////////////////////////////////
	// free temporary arrays for this routine
	mxFree(dsName);
	mxFree(hdmFile);
	
	return;
         
}
    
}


