// *************************************
// mex routine to read all data for one channel
//
// calling syntax is:
// [data] = bw_CTFGetChannelData(datasetName, channelName, [highPass lowPass], [gradient]);
//
// returns
//      data = [nsamples x ntrials] matrix of data for selected channel
//		(c) Douglas O. Cheyne, 2004-2010  All rights reserved.
//	
//
//		revisions:  copy of ctf_GetChannelData
//
// ************************************

#include "mex.h"
#include "string.h"
#include "../../../ctflib/headers/datasetUtils.h"
#include "../../../ctflib/headers/BWFilter.h"

#define VERSION_NO 1.1

double	*bw_dataBuffer;
double	*bw_filterBuffer;
ds_params		dsParams;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double			*data;
	double			*timeVec;
	char			*dsName;
	char            *channelName;
	int				buflen;
	int				status;
  	unsigned int 	m;
	unsigned int	n; 
  	char			msg[256];
	
	int				idx;
	
	int             vectorLen;
	double          *val;
	int             gradient;
	double			sampleRate;
	double          highPass;
	double          lowPass;

	bool			filterData;
	double			*dataPtr;	
	
	filter_params 	fparams;

	/* Check for proper number of arguments */
	int n_inputs = 2;
	int n_outputs = 2;
	if ( nlhs != n_outputs | nrhs < n_inputs)
	{
		mexPrintf("bw_CTFGetChannelData ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf("   [timeBase data] = bw_CTFGetChannelData(datasetName, channelName, [highPass lowPass], [gradient]\n");
		mexPrintf("   [datasetName]     - name of CTF dataset\n");
		mexPrintf("   [channelName]     - name of data channel (e.g., 'MLC24')\n\n");
		mexPrintf("Options:\n");
		mexPrintf("   [highPass lowpass]    data bandwidth in Hz, default = bandpass of saved data\n");
		mexPrintf("   [gradient]            data gradient (0=raw, 1=1st, 2=2nd, 3=3rd, 4=3rd+adaptive) default = gradient of saved data\n");
		mexPrintf(" \n");
		return;
	}

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

	
	/* get channel name */

 	/* Input must be a string. */
  	if (mxIsChar(prhs[1]) != 1)
		mexErrMsgTxt("Input must be a string.");
	
  	/* Input must be a row vector. */
  	if (mxGetM(prhs[1]) != 1)
		mexErrMsgTxt("Input must be a row vector.");
	
  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 1;
	
	/* Allocate memory for input and output strings. */
  	channelName = (char *)mxCalloc(buflen, sizeof(char));
	
 	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[1], channelName, buflen);
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

	mexPrintf("dataset:  %s, (%d trials, %d samples, %d sensors, epoch time = %g to %g s)\n", 
			  dsName, dsParams.numTrials, dsParams.numSamples, dsParams.numSensors, dsParams.epochMinTime, dsParams.epochMaxTime);
	mexEvalString("drawnow");
	
	if (nrhs > 2)
	{
		if (mxGetM(prhs[2]) != 1 || mxGetN(prhs[2]) != 2)
			mexErrMsgTxt("Input 3 must be a row vector [hipass lowpass].");
		dataPtr = mxGetPr(prhs[2]);
		highPass = dataPtr[0];
		lowPass = dataPtr[1];
		filterData = true;
		if ( highPass > lowPass)
		{
			mexPrintf("invalid filter settings");
			return;
		}
		
		if ( lowPass > dsParams.sampleRate / 2.0 )
		{
			mexPrintf("low-pass filter cutoff exceeds Nyquist...");
			return;
		}		
	}
	else
	{
		lowPass = dsParams.lowPass;
		highPass = dsParams.highPass;
		filterData = false;
	}
	
	if (nrhs > 3)
	{
		val = mxGetPr(prhs[3]);
		gradient = (int)*val;	
	}
	else
	{
		gradient = -1;
	}

	bool foundChannel = false;
	
	for (int j=0; j<dsParams.numChannels; j++)
	{
		if (strncmp(dsParams.channel[j].name,channelName, strlen(channelName) ))
		{
			foundChannel = true;
			break;
		}
	}
	
	if (!foundChannel)
	{
		mexPrintf("Couldn't find channel [%s]...", channelName);
		return;
	}		
	
	// allocate memory for Matlab return vectors
	//
	
	plhs[0] = mxCreateDoubleMatrix(dsParams.numSamples, 1, mxREAL); 
	timeVec = mxGetPr(plhs[0]);
	double dwel = 1.0 / dsParams.sampleRate;
	
	for (int j=0; j<dsParams.numSamples; j++)
		timeVec[j] = (double)(dsParams.epochMinTime + (j * dwel) );
	
	plhs[1] = mxCreateDoubleMatrix(dsParams.numSamples, dsParams.numTrials, mxREAL); 
	
	data = mxGetPr(plhs[1]);
	
	mexPrintf("getting sensor data for %s (BW %g to %g Hz, gradient = %d)...\n", dsName, highPass, lowPass, gradient);

	bw_dataBuffer = (double *)malloc( sizeof(double) * dsParams.numSamples );
	if (bw_dataBuffer == NULL)
	{
		mexPrintf("memory allocation failed for bw_dataBuffer array");
		return;
	}
	
	bw_filterBuffer = (double *)malloc( sizeof(double) * dsParams.numSamples );
	if (bw_filterBuffer == NULL)
	{
		mexPrintf("memory allocation failed for bw_filterBuffer array");
		return;
	}
	
	if (!filterData)
	{
		fparams.enable = false;
		mexPrintf("filter off...\n");
	}
	else
	{
		fparams.enable = true;
		if ( highPass == 0.0 )
			fparams.type = BW_LOWPASS;     
		else
			fparams.type = BW_BANDPASS;
		
		fparams.bidirectional = true;
		fparams.hc = lowPass;
		fparams.lc = highPass;
		fparams.fs = dsParams.sampleRate;
		fparams.order = 4;	
		fparams.ncoeff = 0;	
		
		if (build_filter (&fparams) == -1)
		{
			mexPrintf("memory allocation failed for trial array\n");
			return;
		}
	}

	idx = 0;		
	for (int j=0; j<dsParams.numTrials; j++)
	{
	
		if ( !readMEGChannelData( dsName, dsParams, channelName, bw_dataBuffer, j, gradient) )  // get all trials 
		{
			mexWarnMsgTxt("readMEGChannelData() returned error... data may not be valid");
		}
		
		if (filterData)
		{
			for (int k=0; k< dsParams.numSamples; k++)
				bw_filterBuffer[k] = bw_dataBuffer[k];
			
			applyFilter( bw_filterBuffer, bw_dataBuffer, dsParams.numSamples, &fparams);
		}
		
		// have to return data as contiguous vector, even though Matlab thinks it is an array
		for (int k=0; k<dsParams.numSamples; k++)
			data[idx++] = bw_dataBuffer[k];
	
	}
	
	free(bw_filterBuffer);
	free(bw_dataBuffer);
	mxFree(dsName);
	mxFree(channelName);
	 
	return;
         
}
    
}


