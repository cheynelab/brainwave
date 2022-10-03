// *************************************
// mex routine to read all channel names
// calling syntax is:
// [labels] = bw_CTFGetChannelLabels( dsName, includeReferences);
//
//		revisions:
//
//		D. Cheyne, Nov, 2012  - needed for scanning trigger channels
//
// ************************************
#include "mex.h"
#include "string.h"
#include "../../../ctflib/headers/datasetUtils.h"

// Version
#define VERSION_NO 1.0

ds_params		CTF_Labels_dsParams;

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
        
	int n_inputs = 1;
	int n_outputs = 1;
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("bw_CTFGetChannelLabels ver. %.1f (c) Douglas Cheyne, PhD. 2010-2011. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf("   [labels] = bw_CTFGetChannelLabels(datasetName) \n");
		mexPrintf("   returns numChannels x 32 character array for all channel names.\n");
		return;
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
	
  	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[0], fileName, buflen);
  	if (status != 0) 
		mexWarnMsgTxt("Not enough space. String is truncated.");        

	// get dataset info
    if ( !readMEGResFile( fileName, CTF_Labels_dsParams ) )
    {
		mexErrMsgTxt("Error reading res4 file for virtual sensors\n");
		return;
    }

	for (int i=0; i<CTF_Labels_dsParams.numChannels; i++ )
	{
		list[i] = (char *)malloc(sizeof(char) * 32);
		if (list[i] == NULL)
		{
			mexErrMsgTxt("Error allocating memory for string array");
		}
	}
	
    for (int k=0; k<CTF_Labels_dsParams.numChannels; k++)
		sprintf(list[k],"%s",CTF_Labels_dsParams.channel[k].name);
	
    // copy string data...
		
	/* return params in numChan x 32 char array */
	plhs[0] = mxCreateCharMatrixFromStrings(CTF_Labels_dsParams.numChannels, (const char **)list);

	// free local string array
	for (int i=0; i<CTF_Labels_dsParams.numChannels; i++ )
		free(list[i]);
	
	mxFree(fileName);

	return;
         
}
    
}


