// *************************************
// mex routine to read single trial dataset and return the average waveforms for all sensor channels
//
// calling syntax is:
// [timeVec channelNames data] = sim_CTFGetAverage( filename );
//
// returns
//      timeVec = [1 x nsamples] vector of latencies of each sample
//      channelNames = [nchannels] array of channel names for data array
//      data = [nSamples x nChannels] array of averaged waveforms
//
//		(c) Douglas O. Cheyne, 2004-2010  All rights reserved.
//
//		revisions:
//		version 2.4  - first release 
//
//				2.5  - recompiled with separate ctflib and bwlib
//				3.0  - May 7, 2020 changed to use new function in ctflib insetead of bwlib - removed filtering
// ************************************

#include "mex.h"
#include "string.h"
#include "../../../ctflib/headers/datasetUtils.h"

#define VERSION_NO 3.0

double	**aveTrialData;
ds_params		dsParams;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double			*data;
	double			*timeVec;
	char			*dsName;
	char            channelName[256];
	int				buflen;
	int				status;
  	unsigned int 	m;
	unsigned int	n; 
  	char			msg[256];
	
	
	int             vectorLen;
	double          *val;
	int             gradient;
	double			sampleRate;
	int				sensorsOnly;
	
	char            *list[MAX_CHANNELS];

	/* Check for proper number of arguments */
	int n_inputs = 1;
	int n_outputs = 3;
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("sim_CTFGetAverage ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO);
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf("   [timeVec channelNames data] = bw_CTFGetAverage(datasetName)\n");
		mexPrintf("   [datasetName] and [channelName] are strings\n");
		mexPrintf(" \n");
		return;
	}

	/* ================== */
	/* get file name */

  	/* Input must be a string. */
  	if (mxIsChar(prhs[0]) != 1)
    		mexErrMsgTxt("Input must be a string.");

  	/* Input must be a row vector. */
  	if (mxGetM(prhs[0]) != 1)
    		mexErrMsgTxt("Input must be a row vector.");

  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[0]) * mxGetN(prhs[0])) + 1;
  
	/* Allocate memory for input and output strings. */
  	dsName = (char *)mxCalloc(buflen, sizeof(char));

  	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[0], dsName, buflen);
  	if (status != 0) 
    		mexWarnMsgTxt("Not enough space. String is truncated.");        

	// get dataset info
    if ( !readMEGResFile( dsName, dsParams ) )
    {
		mexPrintf("Error reading res4 file ...\n");
		return;
    }
	
	if ( dsParams.numChannels == 0 || dsParams.numSamples == 0 || dsParams.numTrials == 0)
	{
		sprintf(msg, "Error reading dataset dimensions %s\n", dsName);
		mexPrintf(msg);
		return;
	}

//	if ( dsParams.numTrials < 4)
//	{
//		sprintf(msg, "Dataset %s has 1 to 3 trials - may already be averaged? %s\n", dsName);
//		mexPrintf(msg);
//		return;
//	}
		
	for (int i=0; i<MAX_CHANNELS; i++ )
	{
		list[i] = (char *)malloc(sizeof(char) * 32);
		if (list[i] == NULL)
		{
			mexPrintf("Error allocating memory for string array");
			return;
		}
	}
	
	// allocate memory for Matlab return vectors
	//
	
	// get timeVec
	plhs[0] = mxCreateDoubleMatrix(dsParams.numSamples, 1, mxREAL); 
	timeVec = mxGetPr(plhs[0]);
	for (int i=0; i<dsParams.numSamples; i++)
		timeVec[i] = double(i-dsParams.numPreTrig)/dsParams.sampleRate;
	
	
	// copy string data...
	int idx = 0;
    for (int k=0; k<dsParams.numChannels; k++)
	{
		if (dsParams.channel[k].isSensor)
			sprintf(list[idx++],"%s",dsParams.channel[k].name);
	}
	
	/* return params in numChan x 32 char array */
	plhs[1] = mxCreateCharMatrixFromStrings(dsParams.numSensors, (const char **)list); 
	
	plhs[2] = mxCreateDoubleMatrix(dsParams.numSamples, dsParams.numSensors, mxREAL); 
	data = mxGetPr(plhs[2]);
	
	mexPrintf("getting average sensor data for %s ...\n", dsName);

	aveTrialData = (double **)malloc( sizeof(double *) * dsParams.numSensors );
	if (aveTrialData == NULL)
	{
		mexPrintf("memory allocation failed for trial array");
		return;
	}
	for (int i = 0; i < dsParams.numSensors; i++)
	{
		aveTrialData[i] = (double *)malloc( sizeof(double) * dsParams.numSamples);
		if ( aveTrialData[i] == NULL)
		{
			mexPrintf( "memory allocation failed for trial array" );
			return;
		}
	}
		
	if ( !readMEGDataAverage( dsName, dsParams, aveTrialData, -1, 1) ) 	// read average for saved gradient, sensorsOnly
	{
		mexPrintf("Error returned from readMEGDataAverage...\n");
		return;
	}

	idx = 0;		// must return array to Matlab as vector
	for (int j=0; j<dsParams.numSensors; j++)
		for (int i=0; i<dsParams.numSamples; i++)
			data[idx++] = aveTrialData[j][i];
	
	for (int i=0; i<MAX_CHANNELS; i++ )
	{
		free(list[i]);
	}
	
	free(aveTrialData);
	
	mxFree(dsName);
	 
	return;
         
}
	
}


