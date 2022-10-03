// *************************************
// mex routine to epoch single trial dataset - based on epochDs
//
// calling syntax is:
//
//	err = bw_CTFEpochDs(dsName, newDsName, latencies, [epochStart, epochEnd], saveAverage, filterData, [highPass lowPass], {badChannelList} )
//  [dsName]              - name of raw data (single trial) CTF dataset to epoch\n");
//	[newDsName]           - output name for epoched data (use *.ds extension!) \n");
//	[latencies]           - row vector of event latencies in seconds.\n");
//	[epochStart epochEnd] - row vector specifying epoch start and end times in seconds relative to event latencies.\n");
//	[saveAverage]         - integer flag (1 = save both single trial and average dataset. 0 = save single trial only)\n");
//	[filterData]          - flag indicating whether to filter data prior to saving. If false, next argument is ignored\n");
//	[highPass lowPass]    - row vector specifying prefilter data with high pass and low pass filter in Hz.\n\n");
//  [lineFilterFreq]      - integer value (Hz) indicating which mains frequency to filter out (e.g., 50 or 60 Hz) - pass value of 0 to disable\n");
//	[downSample]			- downSample factor (set to 1 to keep original sample rate).\n\n");
//	Options:\n\n");
//	[useExpandedWindow]   - flag to indicate whether to use expanded filter window. Ignored if filter off.\n\n");		
//	[deidentify]			- don't copy text fields that may contain patient name.\n\n");
//	[badChanneList]       - [nchannels x 5 chars] character array of MEG channel names to be excluded.\n");
//
// returns
//	errCode = 0    - no errors detected
//  errCode = 1    - unknown error
//  errCode = 2    - directory may already exist or cannot be created
//
//		(c) Douglas O. Cheyne, 2011 All rights reserved.
//
//		revisions:
//		version 2.4  - first version 
//		version 2.5  - removed check for existing dataset from here to have option to check from calling function - will now overwrite 
//					   moved ds_params declaration out of routine to avoid stack overflow on Windows...
//					   fixed bug in reading filter params ...
//
//				2.6  - recompiled with separate ctflib and bwlib
//              2.7  - Version 3.0beta - fixed bug in saving with expanded filter window - April 23 / 2015
//              2.8  - Version 3.3 modification - added lineFilter option - pass lineFilterFreq == 0 to disable  Dec 14 / 2016
//
// ************************************

#include "mex.h"
#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>
#include "string.h"
#include "../../../ctflib/headers/datasetUtils.h"
#include "../../../ctflib/headers/BWFilter.h"
#include "../../../ctflib/headers/path.h"

#define VERSION_NO 2.7

int				*windowData;                      
int				*channelData;  
int				*trialBlock;

double			*aveBlock;
double			*outBuffer;
double			*inBuffer;

ds_params		dsParams;
ds_params		newParams;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	char			*dsName;
	char			*newDsName;

	char			dsBaseName[256];	
	char			newDsBaseName[256];	
	
	int				numBadChannels;
	char			**badChannelNames;
	char			file[256];	
	char			file2[256];

	int				buflen;
	int				status;
  	unsigned int 	m;
	unsigned int	n; 
  	char			msg[256];
	char			tStr[256];
	char			cmd[256];

	
	int             vectorLen;
	double          *val;
	double			*dataPtr;	
	
	int				numLatencies;
	double          *latencies;
	double			*err;
	FILE			*fp;	
	FILE			*fp2;

	int				preFilterPts;
	double          highPass;
	double          lowPass;
	double			epochStart;
	double			epochEnd;

	bool			preFilter = false;
    bool            lineFilter = false;
	bool			saveAverage = false;
    
	bool			badChannelIndex[MAX_CHANNELS];
	int				downSample = 1;
	int				useExpandedWindow = 0;
	int				deidentify_data = 0;
    
	double          lineFilterFreq = 0.0;
    double          lineFilterWidth = 3.0;
    
	filter_params 	fparams;
    filter_params   lf1params;
    filter_params   lf2params;
    filter_params   lf3params;
    filter_params   lf4params;
    
	/* Check for proper number of arguments */
	
	bool inputErr;
		
	if ( nlhs != 1 | nrhs < 9)
	{
		mexPrintf("bw_CTFEpochDs ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf("   err = bw_CTFEpochDs(dsName, newDsName, latencies, [epochStart, epochEnd], saveAverage, filterData, [highPass lowPass], lineFilterFreq, downSample, {useExpandedWIndow}, {deidentify}, {badChannelList} )\n\n");
		mexPrintf("   [dsName]              - name of raw data (single trial) CTF dataset to epoch\n");
		mexPrintf("   [newDsName]           - output name for epoched data (use *.ds extension!) \n");
		mexPrintf("   [latencies]           - row vector of event latencies in seconds.\n");
		mexPrintf("   [epochStart epochEnd] - row vector specifying epoch start and end times in seconds relative to event latencies.\n");
		mexPrintf("   [saveAverage]         - integer flag (1 = save both single trial and average dataset. 0 = save single trial only)\n");
		mexPrintf("   [filterData]          - flag indicating whether to filter data prior to saving. If false, next argument is ignored\n");
		mexPrintf("   [highPass lowPass]    - row vector specifying prefilter data with high pass and low pass filter in Hz.\n\n");
        mexPrintf("   [lineFilterFreq]      - value indicating which line frequency to filter out (e.g. 50 or 60 Hz). Pass 0.0 to disable.\n");
		mexPrintf("   [downSample]			- downSample factor (set to 1 to keep original sample rate).\n\n");
		mexPrintf("   Options:\n\n");
		mexPrintf("   [useExpandedWindow]   - Filter using extended data segments Ignored if filter off.\n\n");
		mexPrintf("   [deidentify]			- don't copy text fields that may contain patient name.\n\n");
		mexPrintf("   [badChanneList]       - [nchannels x 5 chars] character array of MEG channel names to be excluded.\n");
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
	
  	if (mxIsChar(prhs[1]) != 1)
		mexErrMsgTxt("Input must be a string.");
	
  	/* Input must be a row vector. */
  	if (mxGetM(prhs[1]) != 1)
		mexErrMsgTxt("Input must be a row vector.");
	
  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 1;
	
	/* Allocate memory for input and output strings. */
  	newDsName = (char *)mxCalloc(buflen, sizeof(char));
	
  	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[1], newDsName, buflen);
  	if (status != 0) 
		mexWarnMsgTxt("Not enough space. String is truncated.");    	

	if (mxGetM(prhs[2]) != 1 )
		mexErrMsgTxt("Input [2] must be a row vector of latencies.");
	latencies = mxGetPr(prhs[2]);
	numLatencies = mxGetN(prhs[2]);

	if (mxGetM(prhs[3]) != 1 || mxGetN(prhs[3]) != 2)
		mexErrMsgTxt("Input [3] must be a row vector [epochStart epochEnd].");
	dataPtr = mxGetPr(prhs[3]);
	epochStart = dataPtr[0];
	epochEnd = dataPtr[1];

	dataPtr = mxGetPr(prhs[4]);
	saveAverage = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[5]);
	preFilter = (int)dataPtr[0];

	if (mxGetM(prhs[6]) != 1 || mxGetN(prhs[6]) != 2)
		mexErrMsgTxt("Input [5] must be a row vector [hipass lowpass].");
	dataPtr = mxGetPr(prhs[6]);
	highPass = dataPtr[0];
	lowPass = dataPtr[1];

    dataPtr = mxGetPr(prhs[7]);
    lineFilterFreq = dataPtr[0];

    dataPtr = mxGetPr(prhs[8]);
	downSample = (int)dataPtr[0];
	
	// optional arguments
	
	if (nrhs > 9)
	{
		dataPtr = mxGetPr(prhs[9]);
		useExpandedWindow = (int)dataPtr[0];
	}
	
	if (nrhs > 10)
	{
		dataPtr = mxGetPr(prhs[10]);
		deidentify_data = (int)dataPtr[0];
	}
	
	numBadChannels = 0;
	if (nrhs > 11)
	{
		if (mxIsCell(prhs[11]) != 1)
				mexErrMsgTxt("channel list must be cell string array");
		numBadChannels =mxGetNumberOfElements(prhs[11]);
		badChannelNames = (char **)mxCalloc(numBadChannels,sizeof(char*));	
		for (int i=0; i<numBadChannels;i++)
		{
			if (!mxIsChar( mxGetCell(prhs[11],i)))
				mexErrMsgTxt("channel list must be cell string array");
			else
			{
				badChannelNames[i] = mxArrayToString(  mxGetCell(prhs[11],i));
//				mexPrintf("excluding bad channel %s \n", badChannelNames[i]);
			}
		}
	}
	
	plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL); 
	err = mxGetPr(plhs[0]);
	err[0] = 0;

	
	// first make sure we can create datset folder 
	
	sprintf(msg,"creating new dataset %s...\n", newDsName );	
	mexPrintf(msg);
		
	int result;
#if _WIN32||WIN64
	result = mkdir(newDsName);
#else
	result = mkdir(newDsName, S_IRUSR | S_IWUSR | S_IXUSR );
#endif
	
	if ( result != 0 ) 
	{
		mexPrintf("** overwriting existing directory %s ...\n", newDsName);
		sprintf(cmd,"rm -r %s",newDsName);
		system(cmd);
#if _WIN32||WIN64
		mkdir(newDsName);
#else
		mkdir(newDsName, S_IRUSR | S_IWUSR | S_IXUSR );
#endif
	}
	
	
	// make sure directory is readable 
	sprintf(cmd,"chmod a+rX %s",newDsName);
	system(cmd);
		
	// get dataset info
    if ( !readMEGResFile( dsName, dsParams ) )
    {
		mexPrintf("Error reading res4 file ...\n");
		err[0] = -1;
		mxFree(dsName);
		mxFree(newDsName);
		return;
    }
	sprintf(msg, "Epoching dataset: %s\n", dsName);
	mexPrintf(msg);
	sprintf(msg,"Number of Channels %d\n", dsParams.numChannels);
	mexPrintf(msg);
	sprintf(msg,"Number of Primary MEG Channels %d\n", dsParams.numSensors);
	mexPrintf(msg);
	sprintf(msg,"Number of Samples: %d\n", dsParams.numSamples);
	mexPrintf(msg);
	if (downSample > 1)
		sprintf(msg,"Sample Rate: %g Samples/s (downsampling by factor of %d)\n", dsParams.sampleRate/downSample, downSample);
	else
		sprintf(msg,"Sample Rate: %g Samples/s\n", dsParams.sampleRate);
		
	mexPrintf(msg);
	
	if (dsParams.numTrials > 1)
	{
		mexPrintf("Cannot epoch CTF dataset with more than one trial\n");
		err[0] = -1;
		mxFree(dsName);
		mxFree(newDsName);
		return;
	}

	// need a copy for new dataset params...
	readMEGResFile( dsName, newParams);
	
	int preTrigPtsSigned = (int)(epochStart * dsParams.sampleRate);
	int postTrigPts = (int)(epochEnd * dsParams.sampleRate);
	int preTrigPts = abs(preTrigPtsSigned);
	int numSamples = preTrigPts + postTrigPts + 1;  // adds 1 for zero
	int numSaveSamples = (int)(numSamples / downSample);
	int numSavePostTrig = numSaveSamples - 1 - (int)(preTrigPts / downSample);
	double correctedEpochEnd = numSavePostTrig / (dsParams.sampleRate / downSample);
	mexPrintf("Saving %d epochs. Epoch duration = %.4f s to %.4f s (%d samples)\n", numLatencies, epochStart, correctedEpochEnd, numSaveSamples);
	
	fparams.enable = false;
	preFilterPts = 0;
	
    if (lineFilterFreq > 0.0)
        lineFilter = true;
                  
	if (preFilter || lineFilter)
	{
        if (preFilter)
        {
            if ( highPass == 0.0 )
                fparams.type = BW_LOWPASS;
            else
                fparams.type = BW_BANDPASS;
            fparams.bidirectional = true;
            fparams.hc = lowPass;
            fparams.lc = highPass;
            fparams.fs = dsParams.sampleRate;
            fparams.order = 4;	// 
            fparams.ncoeff = 0;				// init filter
            
            fparams.enable = true;
            if (build_filter (&fparams) == -1)
            {
                mexPrintf("Could not build filter.  Exiting\n");
                err[0] = -1;
                mxFree(dsName);
                mxFree(newDsName);
                return;
            }
        }
        
        // filter out mains frequency and up to 3rd harmonic (same as CTF DataEditor)
        if (lineFilter)
        {
            mexPrintf("Notch filtering powerline (%.1f Hz) and harmonics...\n", lineFilterFreq);
            lf1params.type = BW_BANDREJECT;
            lf1params.bidirectional = true;
            lf1params.hc = lineFilterFreq + lineFilterWidth;
            lf1params.lc = lineFilterFreq - lineFilterWidth;
            lf1params.fs = dsParams.sampleRate;
            lf1params.order = 4;	//
            lf1params.ncoeff = 0;				// init filter
              
            lf1params.enable = true;
            if (build_filter (&lf1params) == -1)
            {
              mexPrintf("Could not build band reject filter.  Exiting\n");
              err[0] = -1;
              mxFree(dsName);
              mxFree(newDsName);
              return;
            }
            
            lf2params.type = BW_BANDREJECT;
            lf2params.bidirectional = true;
            lf2params.hc = (lineFilterFreq * 2.0) + lineFilterWidth;
            lf2params.lc = (lineFilterFreq * 2.0) - lineFilterWidth;
            lf2params.fs = dsParams.sampleRate;
            lf2params.order = 4;	//
            lf2params.ncoeff = 0;				// init filter
            
            lf2params.enable = true;
            if (build_filter (&lf2params) == -1)
            {
                mexPrintf("Could not build band reject filter.  Exiting\n");
                err[0] = -1;
                mxFree(dsName);
                mxFree(newDsName);
                return;
            }
            
            lf3params.type = BW_BANDREJECT;
            lf3params.bidirectional = true;
            lf3params.hc = (lineFilterFreq * 3.0) + lineFilterWidth;
            lf3params.lc = (lineFilterFreq * 3.0) - lineFilterWidth;
            lf3params.fs = dsParams.sampleRate;
            lf3params.order = 4;	//
            lf3params.ncoeff = 0;				// init filter
            
            lf3params.enable = true;
            if (build_filter (&lf3params) == -1)
            {
                mexPrintf("Could not build band reject filter.  Exiting\n");
                err[0] = -1;
                mxFree(dsName);
                mxFree(newDsName);
                return;
            }
            
            lf4params.type = BW_BANDREJECT;
            lf4params.bidirectional = true;
            lf4params.hc = (lineFilterFreq * 4.0) + lineFilterWidth;
            lf4params.lc = (lineFilterFreq * 4.0) - lineFilterWidth;
            lf4params.fs = dsParams.sampleRate;
            lf4params.order = 4;	//
            lf4params.ncoeff = 0;				// init filter
            
            lf4params.enable = true;
            if (build_filter (&lf4params) == -1)
            {
                mexPrintf("Could not build band reject filter.  Exiting\n");
                err[0] = -1;
                mxFree(dsName);
                mxFree(newDsName);
                return;
            }
            
        
        }
        
		if (useExpandedWindow)
		{
			preFilterPts = int(numSamples / 2);
			mexPrintf("Pre-filtering data from %g to %g Hz using epoch window expanded by %d points \n",
					  highPass, lowPass, preFilterPts);
		}
		else
		{
			preFilterPts = 0;
			mexPrintf("Pre-filtering data from %g to %g Hz \n", highPass, lowPass);
		}
                  
		// change filter settings in header...
		newParams.highPass = highPass;
		newParams.lowPass = lowPass;
        
    }
	
	// data is ch1 all samples, ch2 allsamples....
	// easiest is to read in one channel at a time and write out epoch
	
	// allocate data for one channel, just need to read num epoch samples at a time.
	
	channelData = (int *)malloc( sizeof(int) * numSamples);
	if ( channelData == NULL)
	{
		mexPrintf("memory allocation failed for channel data buffer\n");
		err[0] = -1;
		mxFree(dsName);
		mxFree(newDsName);
		return;
	}
	// make larger buffer to write out one trial at a time
	trialBlock = (int *)malloc( sizeof(int) * numSamples * dsParams.numChannels);
	if ( trialBlock == NULL)
	{
		mexPrintf("memory allocation failed for trialBlock data buffer\n");
		err[0] = -1;
		free(channelData);
		mxFree(dsName);
		mxFree(newDsName);
		return;
	}
	
	// for averaging
	aveBlock = (double *)malloc( sizeof(double) * numSamples * dsParams.numChannels);
	if ( aveBlock == NULL)
	{
		mexPrintf("memory allocation failed for aveBlock data buffer\n");
		err[0] = -1;
		free(channelData);
		free(trialBlock);
		mxFree(dsName);
		mxFree(newDsName);
		return;
	}
	
	int windowPts = numSamples + (preFilterPts * 2);
	
	if (preFilter || lineFilter)
	{
		windowData = (int *)malloc( sizeof(int) * windowPts);
		if ( windowData == NULL)
		{
			mexPrintf("memory allocation failed for windowData  buffer\n");
			err[0] = -1;
			free(channelData);
			free(trialBlock);
			free(aveBlock);
			mxFree(dsName);
			mxFree(newDsName);
			return;
		}
		inBuffer = (double *)malloc( sizeof(double) * windowPts );
		if ( inBuffer == NULL)
		{
			mexPrintf("memory allocation failed for inBuffer\n");
			err[0] = -1;
			free(channelData);
			free(trialBlock);
			free(aveBlock);
			mxFree(dsName);
			mxFree(newDsName);
			return;
		}
		outBuffer = (double *)malloc( sizeof(double) * windowPts );
		if ( outBuffer == NULL)
		{
			mexPrintf("memory allocation failed for outBuffer\n");
			err[0] = -1;
			free(channelData);
			free(trialBlock);
			free(aveBlock);
			mxFree(dsName);
			mxFree(newDsName);
			return;
		}
	}
	
	// get filenames without path or ext..
	removeFilePath( dsName, dsBaseName);
	dsBaseName[strlen(dsBaseName)-3] = '\0';
	removeFilePath( newDsName, newDsBaseName);
	newDsBaseName[strlen(newDsBaseName)-3] = '\0';
	
	
	// open existing data..

	sprintf(file, "%s%s%s.meg4", dsName, FILE_SEPARATOR, dsBaseName );

	if ( ( fp = fopen( file, "rb") ) == NULL )
	{
		mexPrintf("couldn't open meg4 file for reading\n");
		err[0] = -1;
		mxFree(dsName);
		mxFree(newDsName);
		return;
	}
	
	// create the ds directory and meg4 file with header
	if ( !createMEG4File( newDsName ) )
	{
		mexPrintf("Error creating new dataset \n");
		err[0] = -1;
		mxFree(dsName);
		mxFree(newDsName);
		return;
	}
		
	// create the .meg4 file and write header
	sprintf(file, "%s%s%s.meg4", newDsName, FILE_SEPARATOR, newDsBaseName );
	
	if ( ( fp2 = fopen( file, "wb") ) == NULL )
	{
		mexPrintf("couldn't open meg4 file for writing\n");
		err[0] = -1;
		mxFree(dsName);
		mxFree(newDsName);
		return;
	}
	
	// write 8 byte header
	sprintf(tStr, "MEG41CP");
	fwrite(tStr, sizeof( char ), 8, fp2 );
	
	mexPrintf("extracting epochs ...  \n");
	mexEvalString("drawnow");
	
	for (int j=0;j<numSamples*dsParams.numChannels; j++)
		aveBlock[j] = 0.0;

	// check for bad channels
	
	for (int k=0; k<dsParams.numChannels; k++)
	{
		badChannelIndex[k] = false;
		for (int j=0; j<numBadChannels; j++)
		{
//			mexPrintf("<%s> <%s> \n", dsParams.channel[k].name, badChannelNames[j] );
//			mexEvalString("drawnow");
//			
			if ( !strncmp( dsParams.channel[k].name, badChannelNames[j], strlen(badChannelNames[j])) )
			{
				badChannelIndex[k] = true;
				break;
			}
		}		
	}

	int newChannelCount = 0;
    mexPrintf("Excluding channel:\n" );
	for (int k=0; k<dsParams.numChannels; k++)
	{
		if ( badChannelIndex[k] )
		{
			newParams.numChannels--;
			if (dsParams.channel[k].isSensor)
				newParams.numSensors--;
			if (dsParams.channel[k].isReference)
				newParams.numReferences--;
			if (dsParams.channel[k].isBalancingRef)
				newParams.numBalancingRefs--;
			mexPrintf("[%s] ", dsParams.channel[k].name );
			mexEvalString("drawnow");
		}
		else  // copy this channels record
		{
			newParams.channel[newChannelCount++] = dsParams.channel[k];
		}
	}

	// update the new res4 file...
	newParams.sampleRate = dsParams.sampleRate / downSample;
	newParams.numSamples = (int)(numSamples / downSample);
	newParams.numPreTrig = (int)(preTrigPts / downSample);
	
	
	int lineCount = 0;
	int numTrials = 0;
    mexPrintf("Writing trials:\n" );

	for (int i=0; i<numLatencies; i++)
	{
		// ** D. Cheyne fixed rounding error in version 3.6beta
		// note in case of preTrig points, latencies are shifted to beginning of data (= 0.0 s)
		double fval = latencies[i] * dsParams.sampleRate;
		int startSample = (int)(fval + 0.5);
		startSample -=  preTrigPts;
		
		int endSample = startSample + newParams.numSamples;
		if ( (startSample - preFilterPts) < 0 || (endSample + preFilterPts) > dsParams.numSamples)
		{
			mexPrintf("\n**excluding trial %d (sample %d to sample %d) -- exceeds data boundaries**\n", i+1, startSample, endSample);
			mexEvalString("drawnow");
			continue;
		}
		//		sprintf(msg,"reading trial %d at t = %.4f s (sample %d to %d)\n", i+1, latencies[i], startSample, endSample);
		//		mexPrintf(msg);
		//		mexEvalString("drawnow");
		if (lineCount++ == 40)
		{
			mexPrintf("\n");
			mexEvalString("drawnow");
			lineCount = 0;
		}
				
		mexPrintf("%d ", i+1);
		mexEvalString("drawnow");
		
		// read from input and write to output ds
		// - assume no byte swapping is needed here if not converting to Tesla
		
		//  -- jump to trial offset	
		int idx = 0;
		for (int k=0; k<dsParams.numChannels; k++)
		{
			// go to the beginning of the epoch for this channel
			int epochOffset = (k * dsParams.numSamples) + startSample - preFilterPts;
			
			int byteOffset = ( epochOffset * sizeof(int) ) + 8; // include ID string
			
			fseek( fp, byteOffset, SEEK_SET);
			
			// if skipping this channel (i.e., bad channel) read data then 
			// simply don't write it to the meg4.  
			if ( badChannelIndex[k] )
			{
//				mexPrintf("Excluding data for bad channel %s \n", dsParams.channel[k].name );
//				mexEvalString("drawnow");		
				continue;
			}	
				
            // bug fix April 20, * if prefilter was on,  non-MEG channels were being shifted in time..
			// since was skipping this section for all non analog channels
            if (preFilter || lineFilter )
            {

                fread( windowData, sizeof(int), windowPts, fp);
            
                // ** don't filter digital channels
                // filter data - need to byte swap and convert to floating point
                if (dsParams.channel[k].isSensor || dsParams.channel[k].isReference || dsParams.channel[k].isEEG )
                {
                    for (int j=0; j<windowPts; j++)
                    {
                        int iVal = ToHost(windowData[j]);
                        inBuffer[j] = double(iVal);
                    }
                    
                    if (preFilter)
                    {
                        applyFilter( inBuffer, outBuffer, windowPts, &fparams);
                        for (int j=0; j<windowPts; j++)
                            inBuffer[j] = outBuffer[j];
                    }
                    if (lineFilter)
                    {
                        if (lf1params.hc < (dsParams.sampleRate * 0.5) )
                        {
                            applyFilter( inBuffer, outBuffer, windowPts, &lf1params);
                            for (int j=0; j<windowPts; j++)
                                inBuffer[j] = outBuffer[j];
                        }
                        if (lf2params.hc < (dsParams.sampleRate * 0.5) )
                        {
                            applyFilter( inBuffer, outBuffer, windowPts, &lf2params);
                            for (int j=0; j<windowPts; j++)
                                inBuffer[j] = outBuffer[j];
                        }
                        if (lf3params.hc < (dsParams.sampleRate * 0.5) )
                        {
                            applyFilter( inBuffer, outBuffer, windowPts, &lf3params);
                            for (int j=0; j<windowPts; j++)
                                inBuffer[j] = outBuffer[j];
                        }
                        if (lf4params.hc < (dsParams.sampleRate * 0.5) )
                        {
                            applyFilter( inBuffer, outBuffer, windowPts, &lf4params);
                            for (int j=0; j<windowPts; j++)
                                inBuffer[j] = outBuffer[j];
                        }
                    }
                    
                    // convert back to byte swapped integer data...
                    for (int j=0; j<windowPts; j++)
                    {
                        int iVal = (int)inBuffer[j];
                        windowData[j] = ToFile(iVal);
                    }
                }
                // copy epoch window to output array
                for (int j=0; j<numSamples; j++)
                    channelData[j] = windowData[j+preFilterPts];
 			}
			else
				fread( channelData, sizeof(int), numSamples, fp);
			
			// create output data - downsample data here...
			
			for (int j=0; j<newParams.numSamples; j++)
				trialBlock[idx++] = channelData[j*downSample];
		}
		
		// ** note have to write blocks with size based on new params since channel count may have decreased
		
		
		if (saveAverage)
		{
			for (int j=0;j< newParams.numSamples * newParams.numChannels; j++)
			{
				int iVal = ToHost(trialBlock[j]);
				aveBlock[j] += double(iVal);
			}
		}
		
		fwrite( trialBlock, sizeof(int), newParams.numSamples*newParams.numChannels, fp2);
		numTrials++;
		
	}	

	newParams.numTrials = numTrials;
	
	mexPrintf("\n");
	mexEvalString("drawnow");
	
	fclose(fp);
	fclose(fp2);
	
	if (deidentify_data)
	{
		mexPrintf( "removing text field [%s]\n", newParams.run_description );
		mexPrintf( "removing text field [%s]\n", newParams.run_title );
		mexPrintf( "removing text field [%s]\n", newParams.operator_id);
		mexEvalString("drawnow");
		sprintf(newParams.run_description,"removed");
		sprintf(newParams.run_title,"removed");
		sprintf(newParams.operator_id,"removed");
	}
	
	if ( !writeMEGResFile(newDsName, newParams) )
	{
		mexPrintf("WARNING: error occurred writing new res4 file... dataset may be invalid \n");
		err[0] = -1;
	}	
	
	//  Copy the head coil (.hc) since CTF software needs this		
	mexPrintf("copying head coil file ...\n");
    #if _WIN32||WIN64
        sprintf(cmd, "copy %s%s%s.hc %s%s%s.hc", dsName, FILE_SEPARATOR, dsBaseName, newDsName, FILE_SEPARATOR, newDsBaseName );
    #else
        sprintf(cmd, "cp %s%s%s.hc %s%s%s.hc", dsName, FILE_SEPARATOR, dsBaseName, newDsName, FILE_SEPARATOR, newDsBaseName );
    #endif
	system(cmd);

	if (saveAverage)
	{
		char aveFileName[256];
		char aveFileBaseName[256];
		
		// divide and convert back to integer
		// *** note - should really scale data and gains here to a slightly lower LSB
		//            as is done in the CTF software
		for (int j=0;j<numSamples*dsParams.numChannels; j++)
		{
			int iVal = (int)(aveBlock[j] / numTrials);
			trialBlock[j] = ToFile(iVal);
		}
		
		newDsName[strlen(newDsName)-3] = '\0';
		sprintf(aveFileName,"%s-average.ds", newDsName);

		mexPrintf("Saving average as: %s\n", aveFileName);
		
		sprintf(msg,"creating new dataset %s...\n", aveFileName );	
		mexPrintf(msg);
		
#if _WIN32||WIN64
		result = mkdir(aveFileName);
#else
		result = mkdir(aveFileName, S_IRUSR | S_IWUSR | S_IXUSR );
#endif
		
		if ( result != 0 ) 
		{
			mexPrintf("** overwriting existing directory %s ...\n", aveFileName);
			sprintf(cmd,"rm -r %s",aveFileName);
			system(cmd);
#if _WIN32||WIN64
			mkdir(aveFileName);
#else
			mkdir(aveFileName, S_IRUSR | S_IWUSR | S_IXUSR );
#endif
		}
		
		// make sure directory is readable 
		sprintf(cmd,"chmod a+rX %s",aveFileName);
		system(cmd);
	
		// create the ds directory and meg4 file with header
		if ( !createMEG4File( aveFileName ) )
		{
			mexPrintf("Error creating new dataset \n");
			err[0] = -1;
		}
		
		// create the .meg4 file and write header
		removeFilePath( aveFileName, aveFileBaseName);
		aveFileBaseName[strlen(aveFileBaseName)-3] = '\0';

		sprintf(file, "%s%s%s.meg4", aveFileName, FILE_SEPARATOR, aveFileBaseName );
		if ( ( fp2 = fopen( file, "wb") ) == NULL )
		{
			mexPrintf("couldn't open meg4 file for writing\n");
			err[0] = -1;
		}
		
		if (err[0] == 0)
		{
			// write 8 byte header
			sprintf(tStr, "MEG41CP");
			fwrite(tStr, sizeof( char ), 8, fp2 );
			fwrite( trialBlock, sizeof(int), newParams.numSamples*dsParams.numChannels, fp2);
			
			fclose(fp2);

			// everything is same except ntrials now == 1
			
			newParams.numTrials = 1;
			if ( !writeMEGResFile(aveFileName, newParams) )
			{
				mexPrintf("WARNING: error occurred writing new res4 file... dataset may be invalid \n");
				err[0] = -1;
			}	
					
			//  Copy the head coil (.hc) since CTF software needs this		
			mexPrintf("copying head coil file ...\n");
            #if _WIN32||WIN64
                sprintf(cmd, "copy %s%s%s.hc %s%s%s.hc", dsName, FILE_SEPARATOR, dsBaseName, aveFileName, FILE_SEPARATOR, aveFileBaseName );
            #else
                sprintf(cmd, "cp %s%s%s.hc %s%s%s.hc", dsName, FILE_SEPARATOR, dsBaseName, aveFileName, FILE_SEPARATOR, aveFileBaseName );
            #endif
			system(cmd);
		}
	
	}
		
	
	mexPrintf("cleaning up...\n");

	free(channelData);	
	free(trialBlock);
	free(aveBlock);
	
	if (preFilter)
	{	
		free(windowData);
		free(inBuffer);
		free(outBuffer);
	}	

	if ( numBadChannels > 0)
	{
		for (int i=0; i<numBadChannels;  i++) 
			mxFree(badChannelNames[i]);	
		mxFree(badChannelNames);
	}
	
	mxFree(dsName);
	mxFree(newDsName);

	mexPrintf("done...\n");
	
	return;
}
    
}


