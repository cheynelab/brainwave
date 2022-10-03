// *************************************
// mex routine to convert a geom file to a res4 file assuming .ds folder already exists...
// written by D. Cheyne, April, 2011
//
// calling syntax is:
// result = bw_geom2res4( geomFile, dsName, numSamples, numTrials, preTrigPts, sampleRate);
//
//		(c) Douglas O. Cheyne, 2004-2010  All rights reserved.
//
//		revisions:
//      1.0     - first version
//				2.5  - recompiled with separate ctflib and bwlib
//				2.6 - Sept, 2014 - added second geom file to define the "device" based coordinates
//					this is temporary workaround until rew-writing KIT import to directly write res4 instead of using geom files...
//
// ************************************

#include "mex.h"
#include "string.h"

#include "../../../ctflib/headers/datasetUtils.h"

#define VERSION_NO 2.6

extern "C" 
{

bool loadGeomFile( char *fileName, ds_params & params);
	
ds_params	dsParams;
    
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double 		*params; 
	char 		*fileName;
	char		geomFile[256];
    char        s[256];
	char		dsName[256];
	double		*dataPtr;	

	int			numSamples;
	int			numTrials;
	int			preTrigPts;
	double		sampleRate;
	double		highPass;
	double		lowPass;
	
	int   		buflen;
	int			status;
	double		*val;
	double		*errCode;
  	char		msg[256];
   	
	/* Check for proper number of arguments */
	int n_inputs = 7;
	int n_outputs = 1;
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("bw_geom2res4 ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf(" [err] = bw_geom2res4(geomFileName, datasetName, numSamples, numTrials, preTrigPts, sampleRate, bandpass) \n");
		mexPrintf(" returns err = 0 if successful\n");
		return;
	} 

  	// get geomFile name
  	if (mxIsChar(prhs[0]) != 1)
    		mexErrMsgTxt("Input must be a string.");

  	/* Input must be a row vector. */
  	if (mxGetM(prhs[0]) != 1)
    		mexErrMsgTxt("Input must be a row vector.");

  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[0]) * mxGetN(prhs[0])) + 1;
  
	/* Allocate memory for input and output strings. */
  	fileName = (char *)mxCalloc(buflen, sizeof(char));

  	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[0], fileName, buflen);
  	if (status != 0) 
    		mexErrMsgTxt("Not enough space. String is truncated.");        

	sprintf(geomFile,"%s",fileName);
	mxFree(fileName);
			
	// get dsName
  	if (mxIsChar(prhs[1]) != 1)
		mexErrMsgTxt("Input must be a string.");
	
  	/* Input must be a row vector. */
  	if (mxGetM(prhs[1]) != 1)
		mexErrMsgTxt("Input must be a row vector.");
	
  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 1;
	
	/* Allocate memory for input and output strings. */
  	fileName = (char *)mxCalloc(buflen, sizeof(char));
	
  	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[1], fileName, buflen);
  	if (status != 0) 
		mexErrMsgTxt("Not enough space. String is truncated.");        

	sprintf(dsName,"%s",fileName);
	mxFree(fileName);

	// get other params
	val = mxGetPr(prhs[2]);
	numSamples = (int)*val;

	val = mxGetPr(prhs[3]);
	numTrials = (int)*val;

	val = mxGetPr(prhs[4]);
	preTrigPts = (int)*val;
	
	val = mxGetPr(prhs[5]);
	sampleRate = *val;

	if (mxGetM(prhs[6]) != 1 || mxGetN(prhs[6]) != 2)
		mexErrMsgTxt("Input [6] must be a row vector [hipass lowpass].");
	dataPtr = mxGetPr(prhs[6]);
	highPass = dataPtr[0];
	lowPass = dataPtr[1];
	
	
	/* return error code */
	plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL); 
	errCode  = mxGetPr(plhs[0]);
	errCode[0] = -1;
	
	if ( !readGeomFile( geomFile, dsParams ) )
	{
		mexErrMsgTxt("Error reading geom file...\n");
		return;
	}
		
	mexPrintf("writing %d MEG channels in %s to %s\n", dsParams.numChannels, geomFile, dsName);
	
	// set parameters not filled by readGeomFile() ...
	dsParams.numSamples = numSamples;
	dsParams.numTrials = numTrials;
	dsParams.numPreTrig = preTrigPts;
	dsParams.sampleRate = sampleRate;
	
	dsParams.lowPass = lowPass;
	dsParams.highPass = highPass;
	
//	sprintf(dsParams.run_description,"Dataset created by bw_geom2res4");
//	geomFile[strlen(geomFile)-5] = '\0';
//	sprintf(dsParams.run_title,"%s", geomFile);
	sprintf(dsParams.operator_id,"none");
	
	    
	if ( !writeMEGResFile( dsName, dsParams ) )
	{
		mexErrMsgTxt("Error creating CTF dataset\n");
		return;
	}
	
	errCode[0] = 0;
	 
	return;
         
}
  
    
}


