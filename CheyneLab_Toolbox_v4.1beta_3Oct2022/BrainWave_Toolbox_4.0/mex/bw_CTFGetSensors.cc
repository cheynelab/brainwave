// *************************************
// mex routine to read all channel names and positions (i.e., 1st coil x,y,z coordinates)
// for the primary sensing MEG channels from a CTF dataset
//
// calling syntax is:
// [names positions] = CTFGetSensors( dsName, includeReferences);
//
//		revisions:
//		1.0		- initial version for BrainWave
//      1.4		- revised for version 1.4 - includes reference channels if second argument == 1
//
//				2.5  - recompiled with separate ctflib and bwlib
// ************************************
#include "mex.h"
#include "string.h"
#include "../../../ctflib/headers/datasetUtils.h"

// Version
#define VERSION_NO 2.5

ds_params		dsParams;

extern "C"
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double			*paramArray; 
	char			*fileName;
	int				buflen;
	int				status;
  	unsigned int 	m;
	unsigned int	n; 
  	char			msg[256];
	int             ok;        
	char            *list[MAX_CHANNELS];
	double			*data;
	double			*sensorType;
	double			*val;
	bool			includeReferences;
	int				numSensors;
	
	/* Check for proper number of arguments */
        
	int n_inputs = 2;
	int n_outputs = 3;
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("bw_CTFGetSensors ver. %.1f (c) Douglas Cheyne, PhD. 2010-2011. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf("   [names positions sensorType] = bw_CTFGetSensors(datasetName, includeReferences) \n");
		mexPrintf("   returns numSensors x 32 character array for names, positions as numSensors x 3 array (x,y,z in cm), sensorType as numSensors x 1 array\n");
		mexPrintf("   includes reference channels if includeReferences == 1\n");    
		return;
	} 
	
	for (int i=0; i<MAX_CHANNELS; i++ )
	{
		list[i] = (char *)malloc(sizeof(char) * 32);
		if (list[i] == NULL)
		{
			mexErrMsgTxt("Error allocating memory for string array");
		}
	}

	/* ================== */
	/* Following is the rather complicated way that you have to read in a C string in mex function */

  	/* Input must be a string. */
  	if (mxIsChar(prhs[0]) != 1)
    		mexErrMsgTxt("Input must be a string.");

  	/* Input must be a row vector. */
  	if (mxGetM(prhs[0]) != 1)
    		mexErrMsgTxt("Input must be a row vector.");

  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[0]) * mxGetN(prhs[0])) + 1;
  
	/* Allocate memory for input and output strings. */
  	fileName = (char *)mxCalloc(buflen, sizeof(char));

	val = mxGetPr(prhs[1]);
	includeReferences = int(*val);
	
  	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[0], fileName, buflen);
  	if (status != 0) 
		mexWarnMsgTxt("Not enough space. String is truncated.");        

	// get dataset info
    if ( !readMEGResFile( fileName, dsParams ) )
    {
		mexErrMsgTxt("Error reading res4 file for virtual sensors\n");
		return;
    }
	
    // copy string and position data...

	// define matrix for position data as we will assign this as we go through 
	// the loop, the name data will be copied from local array to Matlab in one call below.
	
	numSensors = dsParams.numSensors;
	if (includeReferences)
	{
		numSensors += dsParams.numBalancingRefs;
		//mexPrintf("numSensors = %d\n", numSensors);
	}
	
	plhs[2] = mxCreateDoubleMatrix(numSensors,1, mxREAL); 
	sensorType = mxGetPr(plhs[2]);
	int sensorCount = 0;
    for (int k=0; k<dsParams.numChannels; k++)
	{
		if (dsParams.channel[k].isSensor || (dsParams.channel[k].isBalancingRef && includeReferences) )
		{
			sensorType[sensorCount++] = dsParams.channel[k].sensorType;
		}
	}
	
	plhs[1] = mxCreateDoubleMatrix(numSensors,3, mxREAL); 
	data = mxGetPr(plhs[1]);
	
	sensorCount = 0;
    for (int k=0; k<dsParams.numChannels; k++)
	{
		if (dsParams.channel[k].isSensor || (dsParams.channel[k].isBalancingRef && includeReferences) )
		{
			sprintf(list[sensorCount++],"%s",dsParams.channel[k].name);
		}
	}

	// must fill 2D array as if it was one big vector so needs its own index counter
	// cannot tranpose output from here, so must fill array this way to be consistent
	// with names array
	int idx = 0;		
	for (int k=0; k<dsParams.numChannels; k++)
		if (dsParams.channel[k].isSensor || (dsParams.channel[k].isBalancingRef && includeReferences))
			data[idx++] = dsParams.channel[k].xpos;
	for (int k=0; k<dsParams.numChannels; k++)
		if (dsParams.channel[k].isSensor || (dsParams.channel[k].isBalancingRef && includeReferences))
			data[idx++] = dsParams.channel[k].ypos;
	for (int k=0; k<dsParams.numChannels; k++)
		if (dsParams.channel[k].isSensor || (dsParams.channel[k].isBalancingRef && includeReferences))
			data[idx++] = dsParams.channel[k].zpos;
	
	
	/* return params in numChan x 32 char array */
	plhs[0] = mxCreateCharMatrixFromStrings(numSensors, (const char **)list); 

	// free local string array
	for (int i=0; i<MAX_CHANNELS; i++ )
		free(list[i]);
	
	mxFree(fileName);

	return;
         
}
    
}


