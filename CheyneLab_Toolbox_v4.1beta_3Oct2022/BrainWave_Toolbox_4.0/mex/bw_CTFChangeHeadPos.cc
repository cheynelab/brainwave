// *************************************
//      mex routine to modify the .res4 file hdCoilTable values using the passed fiducials
//      will apply to MEG sensors and reference channels only
//
//      bw_CTFChangeHeadPos( dsName, Nasion, LeftEar, RightEar);
//
//		(c) Douglas O. Cheyne, 2014  All rights reserved.
//
//		revisions:
//      1.0     - first version
// ************************************
#include "mex.h"
#include "../../../ctflib/headers/datasetUtils.h"

// Version
#define VERSION_NO 1.0

ds_params		dsParams;

extern "C"
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	char			*dsName;
	int				buflen;
	int				status;
  	unsigned int 	m;
	unsigned int	n; 
    
	double			*dataPtr;
	vectorCart      na;
	vectorCart      le;
	vectorCart      re;
    
    
	/* Check for proper number of arguments */
        
	int n_inputs = 4;
	int n_outputs = 0;
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("bw_CTFChangeHeadPos ver. %.1f (c) Douglas Cheyne, PhD. 2013-2014. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf("   bw_CTFChangeHeadPos(datasetName, Nasion, LeftEar, RightEar) \n");
		return;
	} 
	
	/* ================== */
	/* Following is the rather complicated way that you have to read in a C string in mex function */

  	/* Input must be a string. */
  	if (mxIsChar(prhs[0]) != 1)
    		mexErrMsgTxt("Input [0] must be a string.");

  	/* Input must be a row vector. */
  	if (mxGetM(prhs[0]) != 1)
    		mexErrMsgTxt("Input [0] must be a row vector.");

  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[0]) * mxGetN(prhs[0])) + 1;
  
	/* Allocate memory for input and output strings. */
  	dsName = (char *)mxCalloc(buflen, sizeof(char));

  	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[0], dsName, buflen);
  	if (status != 0)
        mexWarnMsgTxt("Not enough space. String is truncated.");
    
	if (mxGetM(prhs[1]) != 1 || mxGetN(prhs[1]) != 3)
		mexErrMsgTxt("Input [1] must be a row vector for Nasion fiducial [x y z].");
	dataPtr = mxGetPr(prhs[1]);
	na.x = dataPtr[0];
	na.y = dataPtr[1];
	na.z = dataPtr[2];
    
	if (mxGetM(prhs[2]) != 1 || mxGetN(prhs[2]) != 3)
		mexErrMsgTxt("Input [2] must be a row vector for LeftEar fiducial [x y z].");
	dataPtr = mxGetPr(prhs[2]);
	le.x = dataPtr[0];
	le.y = dataPtr[1];
	le.z = dataPtr[2];
 
	if (mxGetM(prhs[3]) != 1 || mxGetN(prhs[3]) != 3)
		mexErrMsgTxt("Input [3] must be a row vector for Right fiducial [x y z].");
	dataPtr = mxGetPr(prhs[3]);
	re.x = dataPtr[0];
	re.y = dataPtr[1];
	re.z = dataPtr[2];
    
    
	mexPrintf("updating sensor coordinates for datset %s using fiducials na = %g %g %g, le = %g %g %g, re = %g, %g %g\n",
			  dsName, na.x, na.y, na.z, le.x, le.y, le.z, re.x, re.y, re.z);
  
	if ( !updateSensorPositions( dsName, na, le, re ) )
    {
		mexPrintf("Error returned from updateSensorPositions ...\n");
    }
	
	// update headCoil file - note only updates dewar coords
	if ( !writeHeadCoilFile( dsName, na,  le, re))
    {
		mexPrintf("Error returned from writeHeadCoilFile ...\n");
    }
	
	mxFree(dsName);

	return;
    
}

}

