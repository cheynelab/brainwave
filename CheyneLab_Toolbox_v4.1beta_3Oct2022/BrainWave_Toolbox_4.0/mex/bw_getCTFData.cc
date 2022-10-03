// *****************************************************************************************************
// mex routine to read a segment of data for all MEG channels from a single trial dataset
//
// calling syntax is:
//  
//		data = bw_getCTFData(datasetName, startSample, numSamples);
//
//		datasetName:	name of CTF dataset
//		startSample:	offset from beginning of trial (1st sample = zero!).
//		numSamples:		number of samples to return;
//
// returns
//      data = [numSamples x numSensors] matrix of data in Tesla with gradient of saved data...
//		** this returns primary sensor data only ***
//             
//		(c) Douglas O. Cheyne, 2010-2012  All rights reserved.
//
//		revisions:
//
// ****************************************************************************************************

#include "mex.h"
#include "string.h"
#include "../../../ctflib/headers/datasetUtils.h"
#include "../../../ctflib/headers/BWFilter.h"
#include "../../../ctflib/headers/path.h"

#define VERSION_NO 1.0

double	*chanBuffer;
int		*sampleBuffer;

ds_params		CTF_Data_dsParams;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double			*data;
	double			*dPtr;
	char			*dsName;
	char            channelName[256];
	char			megName[256];
	char			baseName[256];
	char			s[256];
		
	int				buflen;
	int				status;
  	unsigned int 	m;
	unsigned int	n; 
  	char			msg[256];
	
	int				idx;
	int				startSample = 0;
	int				numSamples = 0;
	
	bool			allChannels = 0;
	
	double          *val;
	
	
	double			*dataPtr;	
	

	/* Check for proper number of arguments */
	int n_inputs = 3;
	int n_outputs = 1;
	if ( nlhs != n_outputs | nrhs < n_inputs)
	{
		mexPrintf("bw_getCTFData ver. %.1f (c) Douglas Cheyne, PhD. 2012. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf("   data = bw_getCTFData(datasetName, startSample, numSamples, {allchannels}) \n");
		mexPrintf("   [datasetName]        - name of dataset\n");
		mexPrintf("   [startSample]        - sample from beginning of trial (1st sample = zero!)\n");
		mexPrintf("   [numSamples]         - sample length to get \n");
		mexPrintf("   [allChannels]        - if == 1, return all channels (default: returns primary sensors only) \n");
		
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

	val = mxGetPr(prhs[1]);
	startSample = (int)*val;	

	val = mxGetPr(prhs[2]);
	numSamples = (int)*val;	

	if (nrhs > 3)
	{
		val = mxGetPr(prhs[3]);
		allChannels = (int)*val;
	}
	
	// get dataset info
    if ( !readMEGResFile( dsName, CTF_Data_dsParams ) )
    {
		mexPrintf("Error reading res4 file ...\n");
		return;
    }
	
	if ( startSample < 0 ||  startSample + numSamples >= CTF_Data_dsParams.numSamples )
	{
		mexPrintf("valid sample range is 0 to %d ...\n", CTF_Data_dsParams.numSamples );
		return;
	}		
	
	int nchans;
		
	if (allChannels == 1)
		nchans = CTF_Data_dsParams.numChannels;
	else
		nchans = CTF_Data_dsParams.numSensors;
			
	plhs[0] = mxCreateDoubleMatrix(numSamples, nchans, mxREAL);
	data = mxGetPr(plhs[0]);
	
		// mexPrintf("getting data from %s (sample %d to %d)\n", dsName, startSample, startSample+numSamples-1);

	chanBuffer = (double *)malloc( sizeof(double) * CTF_Data_dsParams.numSamples );
	if (chanBuffer == NULL)
	{
		mexPrintf("memory allocation failed for chanBuffer array");
		return;
	}

	sampleBuffer = (int *)malloc( sizeof(int) * CTF_Data_dsParams.numSamples );
	if (sampleBuffer == NULL)
	{
		mexPrintf("memory allocation failed for sampleBuffer array");
		return;
	}
	
	removeFilePath( dsName, baseName);
	baseName[strlen(baseName)-3] = '\0';
	
	sprintf(megName, "%s%s%s.meg4", dsName, FILE_SEPARATOR, baseName );
		
	FILE *fp;
	// open data file and start reading...
	//
	if ( ( fp = fopen( megName, "rb") ) == NULL )
	{
		return;
	}
	
	fread( s, sizeof( char ), 8, fp );
	if ( strncmp( s, "MEG4CPT", 7 ) && strncmp( s, "MEG41CP", 7 )  )
	{
		mexPrintf("%s does not appear to be a valid CTF meg4 file\n", megName);
		return;
	}
	
	// num trial bytes per channel 
	int numBytesPerChannel = CTF_Data_dsParams.numSamples * sizeof(int);
	
	idx=0;
	for (int k=0; k<CTF_Data_dsParams.numChannels; k++)
	{
		if (CTF_Data_dsParams.channel[k].isSensor || allChannels == 1)
		{
			double thisGain =  CTF_Data_dsParams.channel[k].gain;
			
			// go to sample offset
			
			int bytesToStart = startSample * sizeof(int);
			fseek(fp, bytesToStart, SEEK_CUR);
			
			fread( sampleBuffer, sizeof(int), numSamples, fp);
			
			for (int j=0; j<numSamples; j++)
			{
				 double d = ToHost( (int)sampleBuffer[j] );
				 data[idx++] = d / thisGain;
			}
			int bytesToSkip = (CTF_Data_dsParams.numSamples - numSamples - startSample) * sizeof(int);
			fseek(fp, bytesToSkip, SEEK_CUR);			
		}
		else
			fseek(fp, numBytesPerChannel, SEEK_CUR);
		
	}
	


	fclose(fp);
	
	free(chanBuffer);
	free(sampleBuffer);
	
	mxFree(dsName);
	 
	return;
         
}
    
}


