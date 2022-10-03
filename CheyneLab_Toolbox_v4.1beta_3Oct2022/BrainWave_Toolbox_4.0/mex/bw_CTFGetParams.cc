// *************************************
// mex routine to get dataset paramters
// written by D. Cheyne, Nov, 2004
//
// calling syntax is:
// params = CTFGetParams( filename );
//
//		(c) Douglas O. Cheyne, 2004-2010  All rights reserved.
//
//		revisions:
//      1.0     - first version
//      1.1     - added gradient to list
//		1.2			- recompiled 
//      2.1		Aug, 2010 - compiled with newest libraries.  Included new fields in dsParams
//
//		2.4    - renamed version of CTFGetParams.cc for Brainwave - no other changes except don't show copyright each time
//				2.5  - recompiled with separate ctflib and bwlib
// ************************************

#include "mex.h"
#include "../../../ctflib/headers/datasetUtils.h"

#define VERSION_NO 2.5
ds_params	dsParams;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double 		*params; 
	char 		*fileName;
	int   		buflen;
	int			status;
  	char		msg[256];
   	
	/* Check for proper number of arguments */
	int n_inputs = 1;
	int n_outputs = 1;
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("bw_CTFGetParams ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf(" [params] = CTFGetParams(datasetName)\n format of [params] is: \n");                    
		mexPrintf(" params[1] = number of Samples \n");
		mexPrintf(" params[2] = numbers of Pretrigger points \n");
		mexPrintf(" params[3] = number of Channels \n");
		mexPrintf(" params[4] = number of Trials \n");
		mexPrintf(" params[5] = sample Rate \n");
		mexPrintf(" params[6] = trial Duration (s) \n");
		mexPrintf(" params[7] = lowPass (Hz) \n");
		mexPrintf(" params[8] = highPass (Hz) \n");
		mexPrintf(" params[9] = gradient (-1=unknown, 0=raw, 1=1st, 2=2nd, 3=3rd, 4=3rd+adaptive) \n");
		mexPrintf(" params[10] = number of Primary sensors \n");
		mexPrintf(" params[11] = number of Balancing reference sensors \n");
		mexPrintf(" params[12] = epoch min. time (s) \n");
		mexPrintf(" params[13] = epoch max. time (s) \n");
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
    		mexErrMsgTxt("Not enough space. String is truncated.");        

	/* check that dataset exists */
	/* ========================== */                 

	/* return params in 9 x 1 double array */
	plhs[0] = mxCreateDoubleMatrix(13, 1, mxREAL); 

	/* Assign pointers to the array */      
	params = mxGetPr(plhs[0]);
	
	/* Call the subroutine */   
    // get dataset info
    if ( !readMEGResFile( fileName, dsParams ) )
    {
		mexErrMsgTxt("Error reading res4 file for virtual sensors\n");
    }
	
    params[0] = dsParams.numSamples;
    params[1] = dsParams.numPreTrig;	
    params[2] = dsParams.numChannels;        
    params[3] = dsParams.numTrials;
    params[4] = dsParams.sampleRate;     
    params[5] = dsParams.trialDuration; 
    params[6] = dsParams.lowPass; 
    params[7] = dsParams.highPass;     
    params[8] = dsParams.gradientOrder;    
    params[9] = dsParams.numSensors;   
    params[10] = dsParams.numBalancingRefs;           
    params[11] = dsParams.epochMinTime;           
    params[12] = dsParams.epochMaxTime;  
		
	mxFree(fileName);
	 
	return;
         
}
    
}


