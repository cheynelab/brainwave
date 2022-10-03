// ************************************************************************
// saves both MEG and device coordinates for KIT data
// currently the device coordinates are BESA coordinates so don't work for
// head position averaging...
//
// modified March 2, 2017 D. Cheyne - added option to specify a number of ADC
//                   channels to come after the MEG channels in the geom file.
//
// TO DO:  eliminate geom file and pass the .pos file and fiducials instead?
//
// ************************************************************************

#include "mex.h"
#include "string.h"
#include "../../../ctflib/headers/datasetUtils.h"

#define VERSION_NO 3.0


extern "C" 
{

// bool loadGeomFile( char *fileName, ds_params & params);  // moved to library?
	
ds_params	dsParams;
ds_params	dsParams_dewar;
    
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double 		*params; 
	char 		*fileName;
	char		geomFile[256];
	char		geomFile_dewar[256];
    char        s[256];
	char		dsName[256];
	double		*dataPtr;	

	int			numSamples;
	int			numTrials;
	int			preTrigPts;
    int         numADC;
	double		sampleRate;
	double		highPass;
	double		lowPass;
	
	int   		buflen;
	int			status;
	double		*val;
	double		*errCode;
  	char		msg[256];
   	
	/* Check for proper number of arguments */
	int n_inputs = 9;
	int n_outputs = 1;
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("bw_kit2res4 ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO);
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf(" [err] = bw_kit2res4(datasetName, geomFileName, geomFileName_dewar, numSamples, numTrials, preTrigPts, sampleRate, bandpass, numADC) \n");
		mexPrintf(" returns err = 0 if successful\n");
		return;
	} 

 			
	// get dsName
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

	sprintf(dsName,"%s",fileName);
	mxFree(fileName);

	// get geomFile name
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
	
	sprintf(geomFile,"%s",fileName);
	mxFree(fileName);

	// get geomFile name for dewar coordinates
  	if (mxIsChar(prhs[2]) != 1)
		mexErrMsgTxt("Input must be a string.");
	
  	/* Input must be a row vector. */
  	if (mxGetM(prhs[2]) != 1)
		mexErrMsgTxt("Input must be a row vector.");
	
  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[2]) * mxGetN(prhs[2])) + 1;
	
	/* Allocate memory for input and output strings. */
  	fileName = (char *)mxCalloc(buflen, sizeof(char));
	
  	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[2], fileName, buflen);
  	if (status != 0)
		mexErrMsgTxt("Not enough space. String is truncated.");
	
	sprintf(geomFile_dewar,"%s",fileName);
	mxFree(fileName);
	
	// get other params
	val = mxGetPr(prhs[3]);
	numSamples = (int)*val;

	val = mxGetPr(prhs[4]);
	numTrials = (int)*val;

	val = mxGetPr(prhs[5]);
	preTrigPts = (int)*val;
	
	val = mxGetPr(prhs[6]);
	sampleRate = *val;

	if (mxGetM(prhs[7]) != 1 || mxGetN(prhs[7]) != 2)
		mexErrMsgTxt("Input [7] must be a row vector [hipass lowpass].");
	dataPtr = mxGetPr(prhs[7]);
	highPass = dataPtr[0];
	lowPass = dataPtr[1];

    val = mxGetPr(prhs[8]);
    numADC = (int)*val;

	
	/* return error code */
	plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL); 
	errCode  = mxGetPr(plhs[0]);
	errCode[0] = -1;
	
	mexPrintf("reading geom file %s\n", geomFile);
	if ( !readGeomFile( geomFile, dsParams ) )
	{
		mexErrMsgTxt("Error reading geom file...\n");
		return;
	}
		
	mexPrintf("reading geom file %s\n", geomFile_dewar);
	if ( !readGeomFile( geomFile_dewar, dsParams_dewar ) )
	{
		mexErrMsgTxt("Error reading geom file...\n");
		return;
	}

	
	mexPrintf("writing header info for %d MEG channels in %s to %s\n", dsParams.numSensors, geomFile, dsName);
	
	// transfer sensor geometry from second geom file to dewar coordinates structures...
	
	for (int i=0; i<dsParams.numChannels; i++)
	{
			if (dsParams.channel[i].isSensor || dsParams.channel[i].isReference)
			{
				dsParams.channel[i].xpos_dewar = dsParams_dewar.channel[i].xpos;
				dsParams.channel[i].ypos_dewar = dsParams_dewar.channel[i].ypos;
				dsParams.channel[i].zpos_dewar = dsParams_dewar.channel[i].zpos;
				dsParams.channel[i].xpos2_dewar = dsParams_dewar.channel[i].xpos2;
				dsParams.channel[i].ypos2_dewar = dsParams_dewar.channel[i].ypos2;
				dsParams.channel[i].zpos2_dewar = dsParams_dewar.channel[i].zpos2;
				
				dsParams.channel[i].p1x_dewar = dsParams_dewar.channel[i].p1x;
				dsParams.channel[i].p1y_dewar = dsParams_dewar.channel[i].p1y;
				dsParams.channel[i].p1z_dewar = dsParams_dewar.channel[i].p1z;
				dsParams.channel[i].p2x_dewar = dsParams_dewar.channel[i].p2x;
				dsParams.channel[i].p2y_dewar = dsParams_dewar.channel[i].p2y;
				dsParams.channel[i].p2z_dewar = dsParams_dewar.channel[i].p2z;
			}
	}
	
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
	
    // add ADC channels - these come after the MEG channels in KIT system
    // reading geom file sets
    if (numADC > 0)
    {
        int count = 1;
        dsParams.numChannels += numADC;
        mexPrintf("adding header info for %d ADC channels (totalChannels = %d) \n", numADC, dsParams.numChannels);
        
        for (int i=dsParams.numSensors; i<dsParams.numSensors + numADC; i++)
        {
            sprintf(s,"UADC%03d", count);
            mexPrintf("adding channel %d as %s \n", i, s);
            
            sprintf(dsParams.channel[i].name,"%s", s);
            dsParams.channel[i].qGain = 1.0e8;            // default LSB for CTF ADC ?
            dsParams.channel[i].properGain = 1.0;
            
            dsParams.channel[i].numCoils = 1;
            dsParams.channel[i].numTurns = 1;
            dsParams.channel[i].coilArea = 0.0;
            dsParams.channel[i].xpos = 0;
            dsParams.channel[i].ypos = 0;
            dsParams.channel[i].zpos = 0;
            dsParams.channel[i].p1x = 1;
            dsParams.channel[i].p1y = 0;
            dsParams.channel[i].p1z = 0;
            
            
            // set other channel info
            dsParams.channel[i].index = i;   // check ...
            dsParams.channel[i].isSensor = false;
            dsParams.channel[i].isReference = false;
            dsParams.channel[i].isBalancingRef = false;
            dsParams.channel[i].gradient = 0;
            dsParams.channel[i].gain = dsParams.channel[i].properGain * dsParams.channel[i].qGain;
            dsParams.channel[i].sensorType = 18;  // ADC channel
            count++;
        }
        
    }
	    
	if ( !writeMEGResFile( dsName, dsParams ) )
	{
		mexErrMsgTxt("Error creating CTF dataset\n");
		return;
	}
	
	errCode[0] = 0;
	 
	return;
         
}
  
    
}


