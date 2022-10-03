// *************************************
//      mex routine to combine multiple CTF datasets into one dataset
//
//      Syntax:
//      bw_combineDs( {'file1.ds','file2.ds',....}, 'saveName', {useMeanHeadPos} );
//
//		(c) Douglas O. Cheyne, 2014  All rights reserved.
//
//      options:
//      useMeanHeadPos:     Flag: 1 = apply mean head position to output file, 0 = use first run head position (default = 1) \n");
//		revisions:
//      1.0     - first version
//      2.0     - Sept, 2014, modified to handle multiple datasets
//      2.1     - May, 2016, always use first dataset's gradient order to read data
//      3.2     - Dec, 2016  - make mean head pos option (for Elekta data...)
//
// ************************************
#include "mex.h"
#include "string.h"
#include "../../../ctflib/headers/datasetUtils.h"

// Version
#define VERSION_NO 1.0

ds_params		dsParams;
ds_params		tempParams;
double			**trialDataArray;            // Array for trial data
double			**totalDataArray;

extern "C"
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
	char			dsName[256];
	char			dsName_old[256];
	char			*saveName;
	char			s[256];
	
	mxArray			*cell_element_ptr;
	
	int				buflen;
	char			*buf[128];
    double          *val;
	
	int				status;
    
  	unsigned int 	m;
	unsigned int	n; 
    
	vectorCart		na;
	vectorCart		le;
	vectorCart		re;
	vectorCart		meanNa;
	vectorCart		meanLe;
	vectorCart		meanRe;
	
	markerArray		markerList;
	
	
	double			*dataPtr;

    int numFiles;
    int useMeanHeadPos = 1;
	
	FILE 			*fp;
	
	/* Check for proper number of arguments */
        
	int n_inputs = 2;
	int n_outputs = 0;
	if ( nlhs != n_outputs | nrhs < n_inputs)
	{
		mexPrintf("Incorrect number of input or output arguments\n\n");
		mexPrintf("bw_combineDs ver. %.1f (c) Douglas Cheyne, PhD. 2022. All rights reserved.\n", VERSION_NO);
		mexPrintf("Program to concatenate multiple CTF datsets into one dataset (optionally adjusts sensors to mean head position)\n");
		mexPrintf("options:\n");
		mexPrintf("useMeanHeadPos:    1 = apply mean head position to output file, 0 = use first run head position. Default = 1\n");
		mexPrintf("Example usage:\n");
		mexPrintf("   bw_concatenateDs( {'dataset1.ds', 'dataset2.ds', 'dataset3.ds'}, 'combined.ds', 1)\n");
	    return;
	}

	/* If the input is already a cell array, duplicate it. */
	if (mxIsCell(prhs[0]))
	{
		if (mxIsChar(mxGetCell(prhs[0],0)))
		{
			int numRows = mxGetM(prhs[0]);
			int numCols = mxGetN(prhs[0]);
			
		    if (numCols == 1)
			    numFiles = numRows;
			else
				numFiles = numCols;
			
			if (numFiles < 2)
				mexErrMsgTxt("Must specify more than one input dataset name...");
			
			mexPrintf("combining datasets:\n");
			for (int k=0; k<numFiles; k++)
			{
				cell_element_ptr = mxGetCell(prhs[0], k);
				/* Find out how long the input string array is. */
				
				/* Allocate enough memory to hold the converted string. */
				buflen = (mxGetM(cell_element_ptr) *
						  mxGetN(cell_element_ptr)) + 1;
				
				buf[k] = (char *)mxCalloc(buflen, sizeof(char));
				if (buf[k] == NULL)
					mexErrMsgTxt("Not enough heap space to hold string");
				else
				{
					/* Copy the string data into buf. */
					status = mxGetString(cell_element_ptr, buf[k], 256);
				}
				if (status != 0)
					mexErrMsgTxt("Error getting string");
					
				sprintf(dsName, "%s", buf[k]);
				mexPrintf("%s\n", dsName);
			}
		}
		else
			mexErrMsgTxt("Input[0] must be a cell string array of filenames...");
	}
	else
		mexErrMsgTxt("Input[0] must be a cell string array of filenames...");
		
	
    /* get output filename */
	/* Input must be a string. */
  	if (mxIsChar(prhs[1]) != 1)
		mexErrMsgTxt("Input [1] must be a string.");
	
  	/* Input must be a row vector. */
  	if (mxGetM(prhs[1]) != 1)
		mexErrMsgTxt("Input [1] must be a row vector.");
	
  	/* Get the length of the input string. */
  	buflen = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 1;
	
	/* Allocate memory for input and output strings. */
  	saveName = (char *)mxCalloc(buflen, sizeof(char));

	/* Copy the string data from prhs[0] into a C string input_buf. */
  	status = mxGetString(prhs[1], saveName, buflen);
  	if (status != 0)
        mexWarnMsgTxt("Not enough space. String is truncated.");

	if (nrhs > 2)
	{
		val = mxGetPr(prhs[2]);
		useMeanHeadPos = (int)*val;
	}

    if (useMeanHeadPos)
        mexPrintf("Applying mean head posiition to %s...\n", saveName);
    else
        mexPrintf("Applying first dataset head posiition to %s...\n", saveName);
    
	mexPrintf("Saving combined datasets to %s...\n", saveName);

	
	// modified from combineDs...
	double rms = 0.0;
	int totalSamples = 0;
	
	for (int i=0; i<numFiles; i++)
	{
		
		// get params for this dataset
		sprintf(dsName, "%s", buf[i]);
		mexPrintf("Checking file sizes %d...\n", i);
		
		if ( !readMEGResFile( dsName, tempParams) )
		{
			mexPrintf("Error reading res4 file for dataset %s\n", dsName);
			return;
		}
		
		totalSamples += tempParams.numSamples;
	}
	
	// check if combined data will be too large.
	double fileSize = totalSamples * (double)tempParams.numChannels * 4.0;
	
	if (fileSize > pow(2.0, 32))
	{
		mexPrintf("Concatenated .meg4 file (%e bytes ) will exceed 4GB file size limit. Try downsampling data first...\n", fileSize);
		return;
	}
	

	for (int i=0; i<numFiles; i++)
	{
		
		// get params for this dataset
		sprintf(dsName, "%s", buf[i]);
		mexPrintf("Reading dataset %s...\n", dsName);
		
		if ( !readMEGResFile( dsName, tempParams) )
		{
			mexPrintf("Error reading res4 file for dataset %s\n", dsName);
			return;
		}
		
		if (i==0)
		{
			// save copy of first dataset to save header and compare params while looping...
			if ( !readMEGResFile( dsName, dsParams) )
			{
				mexPrintf("Error reading res4 file\n");
				return;
			}
		}
		else
		{
			sprintf(dsName_old, "%s", buf[i-1]);
			if (dsParams.numTrials > 1)
			{
				mexPrintf("*** Can only combine single trial datasets ***\n");
				return;
			}
			// other datasets have to match
			if (dsParams.numChannels != tempParams.numChannels)
			{
				mexPrintf("*** Cannot combine datasets --> number of channels of %s does match dataset %s\n", dsName_old, dsName);
				return;
			}
			if (dsParams.sampleRate != tempParams.sampleRate)
			{
				mexPrintf("*** Cannot combine datasets --> sampleRate of %s does match dataset %s\n", dsName_old, dsName);
				return;
			}
			
			// check channel name match and total sensor position differences
			double temp_rms = 0.0;
			
			for (int k=0; k<dsParams.numChannels; k++)
			{
				
				if (strcmp(dsParams.channel[k].name, tempParams.channel[k].name) != 0)
				{
					mexPrintf("*** Cannot combine datasets --> channel names do not match for dataset %s and dataset %s\n", dsName_old, dsName);
				}
				
				if (dsParams.channel[k].isSensor)
				{
					
					double dx = (dsParams.channel[k].xpos - tempParams.channel[k].xpos);
					double dy = (dsParams.channel[k].ypos - tempParams.channel[k].ypos);
					double dz = (dsParams.channel[k].zpos - tempParams.channel[k].zpos);
					temp_rms += sqrt( (dx*dx) + (dy * dy) + (dz * dz) );
				}
			}
			
			temp_rms /= dsParams.numSensors;  // mean difference across all sensors

			rms += temp_rms;				  // sum across datasets
            
            // check same gradient
            
            if (tempParams.gradientOrder != dsParams.gradientOrder)
            {
                sprintf(dsName_old, "%s", buf[0]);
	            mexPrintf("\n*** Warning: Converting gradient order of this dataset (g=%d) to match gradient of dataset %s (g=%d) ***\n\n",
                          tempParams.gradientOrder, dsName_old, dsParams.gradientOrder);
            }
            
		}
				
		// get fiducials for this dataset...
		if ( !readHeadCoilFile( dsName, na, le, re ))
		{
			mexPrintf("Error reading head coil file for %s\n", dsName);
			return;
		}
		
		mexPrintf("Fiducial locations for dataset %s:\n NA: %lf %lf %lf, LE: %lf %lf %lf,  RE: %lf %lf %lf, \n",
				  dsName, na.x, na.y, na.z, le.x, le.y, le.z, re.x, re.y, re.z );
		
        // *** bug fix in version 3.4 - previous version was if i==1
        if (i==0)
        {
            meanNa.x = na.x;
            meanNa.y = na.y;
            meanNa.z = na.z;
            
            meanLe.x = le.x;
            meanLe.y = le.y;
            meanLe.z = le.z;
            
            meanRe.x = re.x;
            meanRe.y = re.y;
            meanRe.z = re.z;
        }
        else
        {
            if (useMeanHeadPos)
            {
                meanNa.x = meanNa.x + na.x;
                meanNa.y = meanNa.y + na.y;
                meanNa.z = meanNa.z + na.z;

                meanLe.x = meanLe.x + le.x;
                meanLe.y = meanLe.y + le.y;
                meanLe.z = meanLe.z + le.z;
                
                meanRe.x = meanRe.x + re.x;
                meanRe.y = meanRe.y + re.y;
                meanRe.z = meanRe.z + re.z;
            }
        }
	}
	   
	rms /= numFiles;
	mexPrintf("--> Total RMS difference in sensor positions across all datasets is: %.2f cm\n", rms);
	
	
	dsParams.numTrials = 1;
	dsParams.numSamples = totalSamples;
				
	// fix time boundaries - eliminate preTrigSamples !
	dsParams.numPreTrig = 0;
	dsParams.trialDuration = dsParams.numSamples * dsParams.sampleRate;
	dsParams.epochMinTime = 0.0;
	dsParams.epochMaxTime = (dsParams.numSamples - 1) * dsParams.sampleRate;	 // less one sample for t = 0.0
				
	mexPrintf("\n... writing total of %d samples to %s\n", dsParams.numSamples, saveName);
	
	// allocate memory for all channels and samples
	totalDataArray = (double **)malloc( sizeof(double *) * dsParams.numChannels);
	if ( totalDataArray == NULL)
	{
		mexPrintf( "memory allocation failed for totalDataArray array" );
		return;
	}
	for (int j = 0; j < dsParams.numChannels; j++)
	{
		totalDataArray[j] = (double *)malloc( sizeof(double) * dsParams.numSamples );
		if ( totalDataArray[j] == NULL)
		{
			mexPrintf( "memory allocation failed for totalDataArray array" );
			return;
		}
	}
				
				
	// check if combined dataset exists - have to delete it as overwriting may fail..
	fp = fopen(saveName,"r");
	
	if (fp != NULL)
	{
		mexPrintf("Dataset %s already exists...\n", saveName);
		return;
	}
	
	
	// read and write the data
	int sampleCount = 0;
				
	for (int i=0; i<numFiles; i++)
	{
		// get params for this dataset
		sprintf(dsName, "%s", buf[i]);
		
		if ( !readMEGResFile( dsName, tempParams) )
		{
			mexPrintf("Error reading res4 file\n");
			return;
		}
		
		// allocate memory for this dataset
		trialDataArray = (double **)malloc( sizeof(double *) * tempParams.numChannels);
		if ( trialDataArray == NULL)
		{
			mexPrintf( "memory allocation failed for trial array" );
			return;
		}
		for (int j = 0; j < tempParams.numChannels; j++)
		{
			trialDataArray[j] = (double *)malloc( sizeof(double) * tempParams.numSamples );
			if ( trialDataArray[j] == NULL)
			{
				mexPrintf( "memory allocation failed for trial array" );
				return;
			}
		}
		
		printf("\nReading %d samples from dataset %s...\n", tempParams.numSamples, dsName);
		
		if ( !readMEGTrialData( dsName, tempParams, trialDataArray, 0, dsParams.gradientOrder, false) )
		{
			mexPrintf("Error reading .meg4 file\n");
			return;
		}
		
		// concatenate the data into one array
		for (int j = 0; j < tempParams.numChannels; j++)
		{
			for (int k = 0; k < tempParams.numSamples; k++)
			{
				totalDataArray[j][sampleCount + k] = trialDataArray[j][k];
			}
		}
		sampleCount += tempParams.numSamples;
		
		// avoid memory leak
		for (int j = 0; j < tempParams.numChannels; j++)
			free(trialDataArray[j]);
		free(trialDataArray);
		
	} // next datset

	// create the dataset .. using the first dataset header values including head position
	if ( !createDs( saveName, dsParams ) )
	{
		mexPrintf("Error creating new dataset %s\n", saveName);
		return;
	}
	
	// create the MEG4 file with IDENT string
	if ( !createMEG4File( saveName ) )
	{
		mexPrintf("Error creating new dataset %s\n", saveName);
		return;
	}
	
	// append all data to one meg4 file
	if ( !writeMEGTrialData( saveName, dsParams, totalDataArray) )
	{
		mexPrintf("Error writing combined data to .meg4 file\n");
		return;
	}
	
    if (useMeanHeadPos)
    {
        mexPrintf("\nUpdating sensor geometry using mean head position ...\n");
        //  use mean fiducials to update sensor positions - valid for CTF data only
        
        meanNa.x /= numFiles;
        meanNa.y /= numFiles;
        meanNa.z /= numFiles;
    
        meanLe.x /= numFiles;
        meanLe.y /= numFiles;
        meanLe.z /= numFiles;
    
        meanRe.x /= numFiles;
        meanRe.y /= numFiles;
        meanRe.z /= numFiles;
    
        mexPrintf("mean NA: %lf %lf %lf, mean LE: %lf %lf %lf, mean RE: %lf %lf %lf\n",
                  meanNa.x, meanNa.y, meanNa.z, meanLe.x, meanLe.y, meanLe.z, meanRe.x, meanRe.y, meanRe.z );

        updateSensorPositions( saveName, meanNa, meanLe, meanRe);
        
    }

    // ** create the corresponding head coil file
    mexPrintf("\nWriting head coil file for Fiducials...\n");
    writeHeadCoilFile( saveName, meanNa, meanLe, meanRe);
	
	mexPrintf("... all done\n");
	
	mxFree(saveName);
	for(int i=0; i<numFiles; i++)
		mxFree(buf[i]);

	return;
    
}
}
