/////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//		bw_makeEventRelated
//
//		C-mex function to make event-related source images using a minimum-variance beamformer
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
//				2.5  - recompiled with separate ctflib and bwlib
//				2.6  - recompiled with change to computeEventRelated - now takes vector of latencies.
//				2.7  - changed arguments to take covDsName and voxFile params for surface imaging
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

#define VERSION_NO 2.7

double			**imageData; 
double			**covArray;
double			**icovArray;
vectorCart		*voxelList;
vectorCart		*normalList;

char			**fileList;
ds_params		dsParams;

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
	int				numLatencies;
    int             numCovSensors;
	
	double          highPass;
	double          lowPass;
	
	double			minTime;
	double			maxTime;
	
	double			*latencyList;
	
	double			wStart;
	double			wEnd;
	
	double			regularization = 0.0;
	
	bool			nonRectified = false;
	bool			computePlusMinus = false;
	bool			computeMean = false;
	bool			computeRMS = false;
	
	bool			useHdmFile = false;
	bool			useVoxFile = false;
	bool			useVoxNormals = true;
	
	bool			useReverseFilter = true;
	
    int             outputFormat = 0;  // 0 = CIVET *.txt, 2 = Freesurfer overlay *.w
	
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
	int n_inputs = 24;
	int n_outputs = 2;
 	mexPrintf("bw_makeEventRelated ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO);
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("\nincorrect number of input or output arguments for bw_makeEventRelated  ...\n");
		mexPrintf("\nCalling syntax:\n"); 
		mexPrintf("[listFile fileNames] = bw_makeEventRelated(datasetName, covarianceDsName, hdmFileName, useHdmFile, filter, boundingBox, stepSize, \n");
		mexPrintf("                   covWindow, voxelFileName, useVoxFile, useVoxNormals, baselineWindow, useBaselineWindow, sphere, noiseRMS, regularization, \n");
		mexPrintf("                  numLatencies, latencyList, nonRectified, computeRMS, computePlusMinus, computeMean, useReverseFilter, outputFormat)\n");
		mexPrintf("\n returns: name of the .list file and an array of names of files saved to disk. \n");
		return;
	}

	///////////////////////////////////
	// get datasest name 
  	if (mxIsChar(prhs[0]) != 1)
		mexErrMsgTxt("Input [0] must be a string for dataset name.");
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
		mexErrMsgTxt("Input [1] must be a string for covariance dataset name.");
 	if (mxGetM(prhs[1]) != 1)
		mexErrMsgTxt("Input [1] must be a row vector.");
   	// Get the length of the input string.
  	buflen = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 1;
  	covDsName = (char *)mxCalloc(buflen, sizeof(char));
  	status = mxGetString(prhs[1], covDsName, buflen);  	// Copy the string into a C string
 	if (status != 0)
		mexWarnMsgTxt("Not enough space. String is truncated.");
	
	///////////////////////////////////
	// get headModel file name 
  	if (mxIsChar(prhs[2]) != 1)
		mexErrMsgTxt("Input [2] must be a string for head model name.");
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
		mexWarnMsgTxt("Not enough space. String is truncated.");        
	
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
			 
	if (mxGetM(prhs[7]) != 1 || mxGetN(prhs[7]) != 2)
		mexErrMsgTxt("Input [7] must be a row vector [wStart wStart].");
	dataPtr = mxGetPr(prhs[7]);
	wStart = dataPtr[0];
	wEnd = dataPtr[1];
	
	///////////////////////////////////
	// get voxFile name
  	if (mxIsChar(prhs[8]) != 1)
		mexErrMsgTxt("Input [8] must be a string for voxfile name.");
 	if (mxGetM(prhs[8]) != 1)
		mexErrMsgTxt("Input [8] must be a row vector.");
 	if (mxGetN(prhs[8]) > 0)
    {
        // Get the length of the input string.
        buflen = (mxGetM(prhs[8]) * mxGetN(prhs[8])) + 1;
        voxFileName = (char *)mxCalloc(buflen, sizeof(char));
        status = mxGetString(prhs[8], voxFileName, buflen);  	// Copy the string into a C string
        if (status != 0)
            mexWarnMsgTxt("Not enough space. String is truncated.");
    }
    
	val = mxGetPr(prhs[9]);
	useVoxFile = (int)*val;
    
    if (useVoxFile && voxFileName == NULL)
		mexErrMsgTxt("Cannot use vox File - voxfile name is invalid.");
	
	val = mxGetPr(prhs[10]);
	useVoxNormals = (int)*val;
		
	if (mxGetM(prhs[11]) != 1 || mxGetN(prhs[11]) != 2)
		mexErrMsgTxt("Input [11] must be a row vector [bStart bStart].");
	dataPtr = mxGetPr(prhs[11]);
	bparams.baselineWindowStart = dataPtr[0];
	bparams.baselineWindowEnd = dataPtr[1];
	
	val = mxGetPr(prhs[12]);
	bparams.baselined = (int)*val;

	if (mxGetM(prhs[13]) != 1 || mxGetN(prhs[13]) != 3)
		mexErrMsgTxt("Input [13] must be a row vector [sphereX sphereY sphereZ].");
	dataPtr = mxGetPr(prhs[13]);
	sphereX = dataPtr[0];
	sphereY = dataPtr[1];
	sphereZ = dataPtr[2];
	
	val = mxGetPr(prhs[14]);
	bparams.noiseRMS = *val;
	bparams.normalized = true;
	
	val = mxGetPr(prhs[15]);
	regularization = *val;

	val = mxGetPr(prhs[16]);
	numLatencies = (int)*val;
	
	if (mxGetM(prhs[17]) != 1 )
		mexErrMsgTxt("Input [16] must be a row vector of latency data.");
	if (mxGetN(prhs[17]) != numLatencies)
		mexErrMsgTxt("numLatencies and length of latencyList do not agree");
	latencyList = mxGetPr(prhs[17]);
	
	val = mxGetPr(prhs[18]);
	nonRectified = (int)*val;

	val = mxGetPr(prhs[19]);
	computeRMS = (int)*val;

	val = mxGetPr(prhs[20]);
	computePlusMinus = (int)*val;

	val = mxGetPr(prhs[21]);
	computeMean = (int)*val;

	val = mxGetPr(prhs[22]);
	useReverseFilter = (int)*val;

    val = mxGetPr(prhs[23]);
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
    
	mexPrintf("dataset:  %s, (%d trials, %d samples, %d sensors, epoch time = %g to %g s)\n", 
			  dsName, dsParams.numTrials, dsParams.numSamples, dsParams.numSensors, dsParams.epochMinTime, dsParams.epochMaxTime);
	mexEvalString("drawnow");

    if (dsParams.numSensors != numCovSensors)
	{
		mexPrintf("Covariance dataset and image dataset have different numbers of sensors...\n");
		return;
	}
    
	if ( !init_dsParams( dsParams, &sphereX, &sphereY, &sphereZ, hdmFile, useHdmFile) )
	{
		mexErrMsgTxt("Error initializing dsParams and head model\n");
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

	if (bparams.baselined)
		mexPrintf("Using baseline window for average (%g to %g s)\n",  bparams.baselineWindowStart, bparams.baselineWindowEnd);  
	
	
	if (bparams.normalized)
		mexPrintf("units = pseudoZ (noiseRMS = %g Tesla/sqrt(Hz))\n", bparams.noiseRMS);
	else
		mexPrintf("units = nanoAmpere-meter\n");
	
	
	mexEvalString("drawnow");

	// setup filter 
	if ( highPass == 0 && lowPass == 0)
	{
		bparams.hiPass = dsParams.highPass;		// still need to know bandpass for covariance files etc..
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
	mexEvalString("drawnow");
	
	// generate covariance arrays for primary sensors...
	//
	covArray = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (covArray == NULL)
	{
		mexPrintf("memory allocation failed for covariance array");
		return;
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		covArray[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( covArray[i] == NULL)
		{
			mexPrintf( "memory allocation failed for covariance array" );
			return;
		}
	}
 	icovArray = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (icovArray == NULL)
	{
		mexPrintf("memory allocation failed for inverse covariance array");
		return;
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		icovArray[i] = (double *)malloc( sizeof(double) * dsParams.numSensors );
		if ( icovArray[i] == NULL)
		{
			mexPrintf( "memory allocation failed for covariance array" );
			return;
		}
	}
	
	mexPrintf("computing %d images s\n", numLatencies); 
	mexEvalString("drawnow");
	
	
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
	sprintf(imageFileBaseName, "image,cw_%g_%g", wStart, wEnd);
	
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
	if ( strcmp(dsName,covDsName) )
	{
		removeFilePath(covDsName, s);
		removeDotExtension(s, addName);
		sprintf(imageFileBaseName, "%s,cDs_%s",imageFileBaseName, addName);
	}
	if (regularization > 0.0)
		sprintf(imageFileBaseName,"%s,reg=%g", imageFileBaseName, regularization);

	if (nonRectified)
		sprintf(imageFileBaseName,"%s_NR", imageFileBaseName);
	
	if (computeRMS)
		sprintf(imageFileBaseName,"%s_RMS", imageFileBaseName);
	
	if (computePlusMinus)
		sprintf(imageFileBaseName,"%s_PM", imageFileBaseName);
	
	if (computeMean)
		sprintf(imageFileBaseName,"%s_MEAN", imageFileBaseName);
	

	mexPrintf("computing %d by %d covariance matrix (BW %g to %g Hz) for window %g %g s (reg. = %g) from dataset %s\n",
			  dsParams.numSensors, dsParams.numSensors, bparams.hiPass, bparams.lowPass, wStart, wEnd, regularization, covDsName);
	mexEvalString("drawnow");

	// get covariance... - need to remove anglewindow args from library function...
	computeCovarianceMatrices(covArray, icovArray, dsParams.numSensors, covDsName, fparams, wStart, wEnd, wStart, wEnd, false, regularization);
	
	// allocate memory for all images...
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
	
	int numImages;
	if (computeMean)
		numImages = 1;
	else
		numImages = numLatencies;

    // create character array of image filenames
	fileList = (char **)malloc(sizeof(char *) * numImages);
	for (int i=0; i<numImages; i++)
	{
		fileList[i] = (char *)malloc(sizeof(char) * 256);
		if (fileList[i] == NULL)
		{
			mexPrintf( "memory allocation failed for fileList array" );
			return;
		}
	}
	
	// generate images...
	if ( !computeEventRelated(imageData, dsName, dsParams, fparams, bparams, covArray, icovArray, numVoxels,
							voxelList, normalList, numLatencies, latencyList, computePlusMinus, nonRectified) )
	{
		mexPrintf( "error returned from computeEventRelated\n" );
		return;			
	}

	double startLatency;
	double	endLatency;
	
	startLatency = latencyList[0];
	endLatency = latencyList[numLatencies-1];
	
	char listFileName[256];
	sprintf(listFileName, "");
	    
    ///////////// compute the mean image and write to single file
	if (computeMean) 
	{		
        // average all time points and put in array index zero
        
		mexPrintf("Computing mean image across latencies..\n");		
		for (int i=1; i<numLatencies; i++)
		{
			for (int voxel=0; voxel<numVoxels; voxel++)
				imageData[0][voxel] += imageData[i][voxel];
		}
		for (int voxel=0; voxel<numVoxels; voxel++)
			imageData[0][voxel] = imageData[0][voxel] / numLatencies;
		
        // put latency range in filename
#if _WIN32||WIN64
	sprintf(filename, "%s\\%s,time=%.3f_%.3f", analysisDir, imageFileBaseName, startLatency, endLatency);
#else
	sprintf(filename, "%s/%s,time=%.3f_%.3f", analysisDir, imageFileBaseName, startLatency, endLatency);
#endif
    }
    
    // write out all time points to specified file format
    
    for (int i=0; i<numImages; i++)
    {
        if (!computeMean)
        {
            double latency = latencyList[i];
            
#if _WIN32||WIN64
        sprintf(filename, "%s\\%s_time=%.3f", analysisDir, imageFileBaseName, latency);
#else
        sprintf(filename, "%s/%s_time=%.3f", analysisDir, imageFileBaseName, latency);
#endif
      
        }
        
        if (!useVoxFile)
        {
            sprintf(savename, "%s.svl", filename);
            mexPrintf("Saving image in CTF .svl format as %s\n", savename);
            saveVolumeAsSvl(savename, voxelList, imageData[i], numVoxels, xMin, xMax, yMin, yMax, zMin, zMax, stepSize, SAM_UNIT_SPMZ);
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
                    fprintf(fp, "%g\n",imageData[i][voxel]);
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
                unsigned short sval = 0;
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
                    float temp = imageData[i][voxel];
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
        
        
        sprintf(fileList[i],"%s",savename);
    }
    
    // if more than one file written - save list of filenames in the .list file in local directory
		
    if ( numImages >  1 )
    {
			
#if _WIN32||WIN64
	sprintf(listFileName,"%s\\%s.list",analysisDir, imageFileBaseName);
#else
	sprintf(listFileName,"%s/%s.list",analysisDir, imageFileBaseName);
#endif
        
        mexPrintf("writing file names to list file %s\n", listFileName);
        FILE * listFile = fopen(listFileName, "w");
        if ( listFile == NULL)
        {
            mexPrintf("Couldn't open listFile %s\n", listFileName);
            return;
        }
        for (int i=0; i<numLatencies; i++)
        {
            removeFilePath(fileList[i], s);
            fprintf(listFile,"%s\n",s);
        }
        fclose(listFile);
    }		

	mexEvalString("drawnow");
	
    
    // if successful, return to calling function the filenames a
	if (numImages > 0)
	{
		plhs[0] = mxCreateString(listFileName); 
		plhs[1] = mxCreateCharMatrixFromStrings(numImages, (const char **)fileList); 
	}
	
	///////////////////////////////////
    // change for Version 2.5 - always save .vox file...
	// 
	
#if _WIN32||WIN64
	sprintf(filename,"%s\\%s.vox", analysisDir, imageFileBaseName);
#else
	sprintf(filename,"%s/%s.vox", analysisDir, imageFileBaseName);
#endif
		
    mexPrintf("writing vox file with computed orientations to %s\n", filename);
    
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
    fclose(fp);
	
	///////////////////////////////////
	// free temporary arrays for this routine

	for (int i = 0; i < numLatencies; i++)
		free(imageData[i]);
	free(imageData);
	
	for (int i=0; i <numImages; i++)
		free(fileList[i]);
	free(fileList);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(covArray[i]);
	free(covArray);
	
	for (int i = 0; i < dsParams.numSensors; i++)
		free(icovArray[i]);
	free(icovArray);	
	
	free(voxelList);
	free(normalList);
	
	mxFree(dsName);
	mxFree(hdmFile);
	
	return;
         
}
    
}


