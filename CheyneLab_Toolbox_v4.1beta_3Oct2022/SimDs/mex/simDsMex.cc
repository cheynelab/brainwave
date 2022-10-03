// D. Cheyne March 2020
//    -edited for release version
//    -removed checking for bad channels and commented out code
//
const double	VERSION_NO = 1.4;

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mex.h>
#include <math.h>
#include <matrix.h>
#include <dirent.h>

#include "../../../ctflib/headers/datasetUtils.h"
#include "../../../ctflib/headers/BWFilter.h"
#include "../../../ctflib/headers/sourceUtils.h"
#include "../../../ctflib/headers/path.h"

// Globals

const int		MAX_SOURCES = 100000;
enum			{SINEWAVE, SQUAREWAVE, SINEWAVE_SQUARED, SOURCE_FILE};
const char		SIM_VERSION[32] = "SIM_FILE_VER_2";

typedef struct sim_params
{
	double		frequency;
	double		onsetTime;
	double		duration;
	double		onsetJitter;
	double		amplitudeJitter;
	int			sourceType;
	char		sourceFile[256];
} sim_params;

double 		**dataArray;    
double 		**simulatedTrialData;   
double		**simData;
double		**dipPatterns;
double		*trialBuffer;
double		*sourceData;

dip_params	*dipoles;
sim_params	*params;

// D. Cheyne March 2020 - moved these from local declaration in function to avoid stack overlow ! å
ds_params        dsParams;
ds_params        originalParams;

// Prototypes
//void 	printUsage ();
bool	readSimGeomFile( char *fileName, ds_params & params);
bool	initSimFile (char *simFileName, int *numSources);
bool 	readSimFile( char *simFileName, dip_params * dipoles, sim_params * params, bool verbose);
bool	generateSourceData (double *sourceData, sim_params & params, int numSamples, double sampleRate, int numPreTrig);
bool 	simulation_Ds(int gotData,char dsName[256],int gotGeomFile, char geomFileName[256],int gotSim, char simFileName[256], int gotFile, char newDsName[256],int addBrainNoise,
		 int hasOrigin, vectorCart sphereOrigin,int addNoise,double	peakNoise,double highPassFreq,double lowPassFreq,int rotateDipoles,int selectedGradient, int gotTrials, int numTrials,
		 int gotSamples, int numSamples, int gotSampleRate,double sampleRate,int useSingleSphere, char headModelFile[256],int dumpForward, char dumpFileName[256],
		 int verbose, int forceOverwrite, int computeMagnetic, int writeADC);


extern "C"
{
void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]){


	int gotData;
	char *dsName;

	int gotGeomFile;
	char *geomFileName;

	int gotSim;
	char *simFileName;

	int gotFile;
	char *newDsName;

	int addBrainNoise;
	int hasOrigin;
	vectorCart sphereOrigin;

	int addNoise;
	double	peakNoise;
	double highPassFreq;
	double lowPassFreq;

	int rotateDipoles;
	int selectedGradient;
	int gotTrials;
	int numTrials;
	int gotSamples;
	int numSamples;
	int gotSampleRate;
	double sampleRate;

	int useSingleSphere;
	char *headModelFile;
	int dumpForward;
	char *dumpFileName;
	int verbose;
	int forceOverwrite;
	int computeMagnetic;
	int writeADC;

	int buflen;
	int status;
	double	*dataPtr;
	double *errCode;
	int err;
	

	dataPtr = mxGetPr(prhs[0]);
	gotData = (int)dataPtr[0];

	/* Input must be a string. */
	if (mxIsChar(prhs[1]) != 1)
		mexErrMsgTxt("Input2 must be a string.");

	/* Input must be a row vector. */
	if (mxGetM(prhs[1]) != 1)
		mexErrMsgTxt("Input2 must be a row vector.");

	/* Get the length of the input string. */
	buflen = (mxGetM(prhs[1]) * mxGetN(prhs[1])) + 1;

	/* Allocate memory for input and output strings. */
	dsName = (char *)mxCalloc(buflen, sizeof(char));

	/* Copy the string data from prhs[0] into a C string input_buf. */
	status = mxGetString(prhs[1], dsName, buflen);
	if (status != 0)
		mexWarnMsgTxt("Not enough space. String is truncated.");

	dataPtr = mxGetPr(prhs[2]);
	gotGeomFile = (int)dataPtr[0];

	if (mxIsChar(prhs[3]) != 1)
		mexErrMsgTxt("Input4 must be a string.");
	if (mxGetM(prhs[3]) != 1)
		mexErrMsgTxt("Input4 must be a row vector.");
	buflen = (mxGetM(prhs[3]) * mxGetN(prhs[3])) + 1;
	geomFileName = (char *)mxCalloc(buflen, sizeof(char));
	status = mxGetString(prhs[3], geomFileName, buflen);
	if (status != 0)
		mexWarnMsgTxt("Not enough space. String is truncated.");

	dataPtr = mxGetPr(prhs[4]);
	gotSim = (int)dataPtr[0];

	if (mxIsChar(prhs[5]) != 1)
		mexErrMsgTxt("Input6 must be a string.");
	if (mxGetM(prhs[5]) != 1)
		mexErrMsgTxt("Input6 must be a row vector.");
	buflen = (mxGetM(prhs[5]) * mxGetN(prhs[5])) + 1;
	simFileName = (char *)mxCalloc(buflen, sizeof(char));
	status = mxGetString(prhs[5], simFileName, buflen);
	if (status != 0)
		mexWarnMsgTxt("Not enough space. String is truncated.");

	dataPtr = mxGetPr(prhs[6]);
	gotFile = (int)dataPtr[0];

	if (mxIsChar(prhs[7]) != 1)
		mexErrMsgTxt("Input8 must be a string.");
	if (mxGetM(prhs[7]) != 1)
		mexErrMsgTxt("Input8 must be a row vector.");
	buflen = (mxGetM(prhs[7]) * mxGetN(prhs[7])) + 1;
	newDsName = (char *)mxCalloc(buflen, sizeof(char));
	status = mxGetString(prhs[7], newDsName, buflen);
	if (status != 0)
		mexWarnMsgTxt("Not enough space. String is truncated.");

	dataPtr = mxGetPr(prhs[8]);
	addBrainNoise = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[9]);
	hasOrigin = (int)dataPtr[0];

	if (mxGetM(prhs[10]) != 1 || mxGetN(prhs[10]) != 3)
	mexErrMsgTxt("Input [11] must be a row vector [sphereOrigin.x sphereOrigin.y sphereOrigin.z].");
	dataPtr = mxGetPr(prhs[10]);
	sphereOrigin.x = dataPtr[0];
	sphereOrigin.y = dataPtr[1];
	sphereOrigin.z = dataPtr[2];

	dataPtr = mxGetPr(prhs[11]);
	addNoise = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[12]);
	peakNoise = dataPtr[0];
	
	dataPtr = mxGetPr(prhs[13]);
	highPassFreq = dataPtr[0];
	
	dataPtr = mxGetPr(prhs[14]);
	lowPassFreq = dataPtr[0];

	dataPtr = mxGetPr(prhs[15]);
	rotateDipoles = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[16]);
	selectedGradient = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[17]);
	gotTrials = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[18]);
	numTrials = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[19]);
	gotSamples = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[20]);
	numSamples = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[21]);
	gotSampleRate = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[22]);
	sampleRate = dataPtr[0];

	dataPtr = mxGetPr(prhs[23]);
	useSingleSphere = (int)dataPtr[0];
	
	if (mxIsChar(prhs[24]) != 1)
		mexErrMsgTxt("Input23 must be a string.");
	if (mxGetM(prhs[24]) != 1)
		mexErrMsgTxt("Input23 must be a row vector.");
	buflen = (mxGetM(prhs[24]) * mxGetN(prhs[24])) + 1;
	headModelFile = (char *)mxCalloc(buflen, sizeof(char));
	status = mxGetString(prhs[24], headModelFile, buflen);
	if (status != 0)
		mexWarnMsgTxt("Not enough space. String is truncated.");

	dataPtr = mxGetPr(prhs[25]);
	dumpForward = (int)dataPtr[0];

	if (mxIsChar(prhs[26]) != 1)
		mexErrMsgTxt("Input25 must be a string.");
	if (mxGetM(prhs[26]) != 1)
		mexErrMsgTxt("Input25 must be a row vector.");
	buflen = (mxGetM(prhs[26]) * mxGetN(prhs[26])) + 1;
	dumpFileName = (char *)mxCalloc(buflen, sizeof(char));
	status = mxGetString(prhs[26], dumpFileName, buflen);
	if (status != 0)
		mexWarnMsgTxt("Not enough space. String is truncated.");

	dataPtr = mxGetPr(prhs[27]);
	verbose = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[28]);
	forceOverwrite = (int)dataPtr[0];

	dataPtr = mxGetPr(prhs[29]);
	computeMagnetic = (int)dataPtr[0];
	
	dataPtr = mxGetPr(prhs[30]);
	writeADC = (int)dataPtr[0];
	
	
	plhs[0] = mxCreateDoubleMatrix(1, 1, mxREAL);
	errCode = mxGetPr(plhs[0]);


	err = simulation_Ds(gotData,dsName,gotGeomFile, geomFileName,gotSim, simFileName, gotFile, newDsName,addBrainNoise,
						hasOrigin, sphereOrigin,addNoise,peakNoise,highPassFreq,lowPassFreq,rotateDipoles,selectedGradient,gotTrials,numTrials,
						gotSamples, numSamples, gotSampleRate, sampleRate,useSingleSphere, headModelFile,dumpForward, dumpFileName,
						verbose, forceOverwrite, computeMagnetic, writeADC);

	errCode[0] = err;

	mxFree(dsName);
	mxFree(geomFileName);
	mxFree(simFileName);
	mxFree(newDsName);
	mxFree(headModelFile);
	mxFree(dumpFileName);

	return;

}

}

bool simulation_Ds(int gotData,char dsName[256],int gotGeomFile, char geomFileName[256],int gotSim, char simFileName[256], int gotFile, char newDsName[256],int addBrainNoise,
		 int hasOrigin, vectorCart sphereOrigin,int addNoise,double peakNoise,double highPassFreq,double lowPassFreq,int rotateDipoles,int selectedGradient, int gotTrials, int numTrials,
		 int gotSamples, int numSamples, int gotSampleRate,double sampleRate,int useSingleSphere, char headModelFile[256],int dumpForward, char dumpFileName[256],
		 int verbose, int forceOverwrite, int computeMagnetic, int writeADC)
{
    
	char			basePath[256];
	char			cmd[512];

	FILE			*fp;
	DIR             *dp;
	
	char			channelName[256];
	char			s[256];	
	
	int				numSources;
	int				numMEGChannels;
	

	FILE			*dumpFile;	
	double			pie = acos(-1.0);

	double			noiseSD;
	
	
	noiseSD = peakNoise/3.0;
	filter_params	fparams;

	// defaults
	
	// dataset parameters - initialize to defaults..
    if (!gotTrials)
		numTrials = 100;
    if (!gotSamples)
		numSamples = 1250;
	if (!gotSampleRate)
		sampleRate = 625;				
    
	int	numPreTrig = 0;

	if (!hasOrigin)
	{
	   sphereOrigin.x = 0.0;
	   sphereOrigin.y = 0.0;
	   sphereOrigin.z = 5.0;
	}

	mexPrintf("simDs Version %1.1f\n", VERSION_NO);
	mexPrintf("(c) D. Cheyne, Hospital for Sick Children. All rights reserved.\n\n");

	if (!gotSim || !gotFile )
	{
		mexErrMsgTxt("Insufficient input arguments: Need to specify a sim file and output filename...\n");
		return(false);     
	}
	
	if (addBrainNoise && !gotData )
	{
		mexErrMsgTxt("Must specify a CTF dataset for brain noise...\n");
		return(false);     
	}	
#if _WIN32||WIN64
	dp = opendir(newDsName);
	if ( dp != NULL)
	{
		//fclose(dp);
		if (forceOverwrite)
		{
			printf("overwriting dataset %s ...\n", newDsName);
			sprintf(cmd, "rm -rf %s", newDsName );
			system(cmd);	
		}
		else
		{
			printf("Dataset %s already exists.  Use -f option to replace...\n", newDsName);
			return (false);
		}
	}
#else
	fp = fopen(newDsName, "r");
	if ( fp != NULL)
	{
		fclose(fp);
		if (forceOverwrite)
		{
			printf("overwriting dataset %s ...\n", newDsName);
			sprintf(cmd, "rm -rf %s", newDsName );
			system(cmd);	
		}
		else
		{
			printf("Dataset %s already exists.  Use -f option to replace...\n", newDsName);
			return (false);
		}
	}
#endif	
	
	// force use of either geom or dataset - problem with applying brain noise to .geom simulation 
	// is that channel mapping would have to be done and .meg4 file organized accordingly...
	
	if ((gotGeomFile && gotData) || (!gotGeomFile && !gotData) )
	{
		printf("Must specify either a .geom file or a CTF dataset...\n");
		return(false);     
	}	
	
	if (gotGeomFile)
	{		
		if (!readSimGeomFile(geomFileName, dsParams))
		{
			printf("Error reading geometry file <%s>\n", geomFileName);
			return(false);
		}
		
		dsParams.numSamples = numSamples;
		dsParams.numTrials = numTrials;
		dsParams.sampleRate = sampleRate;
		dsParams.numPreTrig = numPreTrig;
		dsParams.gradientOrder = 0;
		dsParams.trialDuration = numSamples * (1.0/sampleRate);
		
		printDsParams(dsParams, false, false);
		
		if (selectedGradient > 0 && dsParams.numBalancingRefs == 0)
		{
			printf("No references channels.  Cannot generate higher order gradients.\n");
			return(false);
		}// else set gradient order to selected Gradient ?????

	}

	if (gotData)  
	{
		// Check if Dataset file exists        

 #if _WIN32||WIN64
	dp = opendir(dsName);
		
		if (dp == NULL)
		{
			printf("Requested dataset %s does not exist.\n", dsName);
			return(false);			
		}	
#else
	fp = fopen(dsName,"r");
		
		if (fp == NULL)
		{
			fclose(fp);
            printf("Requested dataset %s does not exist.\n", dsName);
			return(false);			
		}
       	
#endif    
      
		if ( !readMEGResFile( dsName, dsParams) )
		{
			printf("Error reading res4 file\n");
			return(false);			
		}

		
		if ( !readMEGResFile( dsName, originalParams) )		// keep copy of original dsParams for reading data
		{
			printf("Error reading res4 file\n");
			return(false);
		}

		mexPrintf("Read following parameters from dataset: %s\n", dsName);
		printDsParams(dsParams, false, false);
			
		// when reading a dataset, only chaange these params if specified on command line - then check below if valid when adding brain data		
		if (gotTrials)
			dsParams.numTrials = numTrials;
		if (gotSamples)
			dsParams.numSamples = numSamples;
		if (gotSampleRate)
			dsParams.sampleRate = sampleRate;
		
		if (addBrainNoise)
		{

			numPreTrig = dsParams.numPreTrig;
			
			if (dsParams.numTrials > originalParams.numTrials)
			{
				printf("Insufficient trials in original dataset (=%d) to add brain noise for %d trials...\n", originalParams.numTrials, dsParams.numTrials);
				return(false);     
			}			
			if (dsParams.numSamples > originalParams.numSamples)
			{
				printf("Insufficient samples in dataset (=%d) to add brain noise for %d samples...\n", originalParams.numSamples, dsParams.numSamples);
				return(false);     
			}			
			if (dsParams.sampleRate != originalParams.sampleRate)
			{
				printf("sample rate must match data used for brain noise (=%g Samples/s)..\n", originalParams.sampleRate);
				return(false);     
			}			
		}		
	}
	
	// **  read sim file and init parameters prior to initializing data to get correct channel count
	
	if ( !initSimFile(simFileName,  &numSources) )
	{
		printf("invalid sim file...\n");
		return(false);
	}
	
	// make memory allocation for dipoles and params dynamic for large number of sources
	
	dipoles = (dip_params *)malloc( sizeof(struct dip_params) * numSources);
	if (dipoles == NULL)
	{
		printf("memory allocation failed ");
		return(false);
	}
	params = (sim_params *)malloc( sizeof(struct sim_params) * numSources);
	if (params == NULL)
	{
		printf("memory allocation failed ");
		return(false);
	}
	
	printf("Reading sim file %s...\n", simFileName);
	if ( !readSimFile(simFileName, dipoles, params, verbose) )
	{
		printf("Couldn't read sim file %s\n", simFileName);
		return(false);
	}
	// if saving source data, create additional ADC channels (starting at UADC100, UADC101 ... )
	if ( writeADC )
	{
		char 	channelName[32];
		
		for (int j=0; j<numSources; j++)
		{
			int channelIndex = dsParams.numChannels+j;
			sprintf(channelName, "UADC1%02d",j+1);
			printf("Saving activation function for source #%d in ADC channel %d (%s)\n", j+1, channelIndex, channelName);
			sprintf(dsParams.channel[channelIndex].name,"%s", channelName);
			dsParams.channel[channelIndex].index = channelIndex;
			dsParams.channel[channelIndex].sensorType = 18;		// UADC channel type
			dsParams.channel[channelIndex].properGain = 1.0;
			dsParams.channel[channelIndex].qGain = 1.0;			//
			dsParams.channel[channelIndex].ioGain = 1e8;		// cannot be zero - added to ctflib to read res4 !
			dsParams.channel[channelIndex].gain = 1e8;			// match typical ADC dynamic range
			dsParams.channel[channelIndex].numCoils = 1;
			dsParams.channel[channelIndex].gradient = 0;
			dsParams.channel[channelIndex].coilArea = 1.0;
			dsParams.channel[channelIndex].numTurns = 1;
		}
		dsParams.numChannels += numSources;
	}
	
	//
	// make sure local variables match the dsParams values
	//
	numMEGChannels = dsParams.numSensors + dsParams.numBalancingRefs;
	numTrials = dsParams.numTrials;
	numSamples = dsParams.numSamples;
	sampleRate = dsParams.sampleRate;
	numPreTrig = dsParams.numPreTrig;
	
	printf("*** Using following parameters for simulation ***\n");
	printDsParams(dsParams, false, false);

	fparams.enable = true;
	fparams.type = BW_BANDPASS;
	fparams.bidirectional = true;
	fparams.hc = lowPassFreq;
	fparams.lc = highPassFreq;
	fparams.fs = sampleRate;
	fparams.order = 4;	//
	fparams.ncoeff = 0;	// init filter?

	if (build_filter (&fparams) == -1)
	{
		printf("Could not build filter.  Exiting\n");
		return(0);
	}
	
	if (addNoise)
		mexPrintf("Adding Gaussian noise with peak-to-peak amplitude of %g fT (sd = %.1f fT) to simulated data...\n", peakNoise, noiseSD);

	mexPrintf("Bandpass filtering data from %g to %g Hz...\n", highPassFreq, lowPassFreq);

	
	/////// memory allocation //////////

	if (addBrainNoise)
	{
		// need to allocate array for reading data for original number of samples
		dataArray = (double **)malloc( sizeof(double *) * originalParams.numChannels);
		if ( dataArray == NULL)
		{
			printf( "memory allocation failed for dataArray " );
			return(false);
		}
		for (int j = 0; j < originalParams.numChannels; j++)
		{
			dataArray[j] = (double *)malloc( sizeof(double) * originalParams.numSamples );
			if ( dataArray[j] == NULL)
			{
				printf( "memory allocation failed for dataArray " );
				return(false);
			}
		}
	}
	// Allocate Memory for the simulated data for one trial
	trialBuffer = (double *)malloc( sizeof(double) * numSamples);
	if (trialBuffer == NULL)
	{
		printf("memory allocation failed for trial buffer");
		return(false);
	}

	// Allocate Memory for the simulated data for one trial
	sourceData = (double *)malloc( sizeof(double) * numSamples);
	if (sourceData == NULL)
	{
		printf("memory allocation failed for waveform Buffer");
		return(false);
	}
	
	// Allocate Memory for the simulated data for one trial
	simulatedTrialData = (double **)malloc( sizeof(double *) * dsParams.numChannels);
	if (simulatedTrialData == NULL)
	{
		printf("memory allocation failed for trial array");
		return(false);
	}

	for (int i = 0; i < dsParams.numChannels; i++)
	{
		simulatedTrialData[i] = (double *)malloc( sizeof(double) * numSamples);
		if ( simulatedTrialData[i] == NULL)
		{
			printf( "memory allocation failed for trial array" );
			return(false);
		}
   	}

	//  Sept, 2010 -  use new routine to init head model

	
	bool usehdmFile = !useSingleSphere;
	
	if ( !init_dsParams( dsParams, &sphereOrigin.x, &sphereOrigin.y, &sphereOrigin.z, headModelFile, !useSingleSphere) )
	{
		printf("Error initializing dsParams\n");
		return(false);
	}
	
	if ( rotateDipoles )
	{
		vectorCart orient;
		vectorCart normal;             
        printf("Rotating dipoles into tangential plane...\n");
        for (int j=0; j<numSources; j++)
        {
			normal.x = dipoles[j].xpos - sphereOrigin.x;
			normal.y = dipoles[j].ypos - sphereOrigin.y;
			normal.z = dipoles[j].zpos - sphereOrigin.z;
			// get orientation
			orient.x = dipoles[j].xori;
			orient.y = dipoles[j].yori;
			orient.z = dipoles[j].zori;
			
			// correct orientation
			orient = makeOrthogonalTo(orient, normal);
			orient = unitVector(orient);
			
			if (verbose)
			{
				printf("Dipole %d:  original orientation: %g, %g, %g --> new orientation: %g %g %g\n", 
				   j+1,  dipoles[j].xori, dipoles[j].yori, dipoles[j].zori, orient.x, orient.y, orient.z);
			}
			dipoles[j].xori = orient.x;
			dipoles[j].yori = orient.y;		
			dipoles[j].zori = orient.z;	
        
		}
	}

        
	// seed random number generator	
	if ( addNoise )
		initGaussianDeviate();

	
	// create array for forward solutions for both primary and reference channels
	dipPatterns = (double **)malloc( sizeof(double *) * numSources);
	for (int i=0; i<numSources; i++ )
	{
		dipPatterns[i] = (double *)malloc( sizeof(double) * numMEGChannels);
		if (dipPatterns[i] == NULL)
		{
			printf("memory allocation failed ");
			return(false);
		}
	}

	mexPrintf("Computing forward solutions for %d source(s) (gradient = %d)\n",  numSources, selectedGradient);

	// simulate field at sensor array including balancing reference channels
	for (int j=0; j<numSources; j++)
	{
		if (computeMagnetic == 1)
		{
			if ( !computeForwardSolution( dsParams, dipoles[j], dipPatterns[j], true, selectedGradient, true, false ) )
			{
				printf("computeForwardSolution() returned error\n");
				return(false);
			}
		}
		else
		{
			if ( !computeForwardSolution( dsParams, dipoles[j], dipPatterns[j], true, selectedGradient, false, false ) )
			{
				printf("computeForwardSolution() returned error\n");
				return(false);
			}
		}
	}

     

	// write forward solution to text file -- primary sensors only...
	// note that dipPatterns contains sensors and balancing ref data only, but channel indices don't match
	// the same indices in this array, since they include all other channels
	if ( dumpForward )
	{
		printf("writing forward solution to text file %s\n", dumpFileName);
		dumpFile = fopen(dumpFileName,"w");
		if ( dumpFile == NULL )
		{
			printf("Could not open text file\n");		
			return(false);
		}
		
		for (int j=0; j<numSources; j++)
		{
			for (int k=0; k<numMEGChannels; k++)
			{
				double fval = dipPatterns[j][k];
				fprintf(dumpFile, "%g\n", fval);
			}
		}

		fclose(dumpFile);

	}

	mexPrintf("Simulating %d trials of data...\n", numTrials);

	        
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//////////                   new method for creating ds                                           //////////  
	
	
	// fill in some header values for simulation data..
	if (gotData)
		sprintf(dsParams.run_description,"Simulated data using simDs Version %g, simFile: %s, original dataset: %s", VERSION_NO, simFileName, dsName);
	else
		sprintf(dsParams.run_description,"Simulated data using simDs Version %g, simFile: %s, geomFile: %s", VERSION_NO, simFileName, geomFileName);

	sprintf(dsParams.run_title,"Simulated data %g %s", VERSION_NO, simFileName);
	sprintf(dsParams.operator_id,"none");
	
	for (int i=0; i<dsParams.numChannels; i++)
	{
		if (dsParams.channel[i].isSensor)
			dsParams.channel[i].gradient = selectedGradient;
	}
	
	dsParams.highPass = highPassFreq;
	dsParams.lowPass = lowPassFreq;
	
	
	// create new dataset
	// Step 1. create a new datset folder and create the .res4 file
	//

	if ( !createDs( newDsName, dsParams ) )
	{
		printf("Error creating new dataset %s\n", newDsName);
		return(false);		
	}

     
	
	// Step 2. create the MEG4 file with IDENT string
	// this allows it to be appended to by writeMEGTrialData in a loop below...
	
	if ( !createMEG4File( newDsName ) )
	{
		printf("Error creating new dataset %s\n", newDsName);
		return(false);		
	}	


	
	// Step 3.  If reading dataset copy it's .hc file and marker file if it exists
	//
	if (gotData)
	{
		char	dsBaseName[256];
		char	newDsBaseName[256];
		
		removeFilePath( dsName, dsBaseName);
		dsBaseName[strlen(dsBaseName)-3] = '\0';
	
		removeFilePath( newDsName, newDsBaseName);
		newDsBaseName[strlen(newDsBaseName)-3] = '\0';
	
		sprintf(cmd, "cp %s%s%s.hc %s%s%s.hc", dsName,FILE_SEPARATOR, dsBaseName, newDsName,FILE_SEPARATOR, newDsBaseName );
		printf("copying head coil file ...\n");
		system(cmd);	
		
		// Step 4.  Copy the MarkerFile.mrk if it exists

#if _WIN32||WIN64
	dp = opendir(newDsName);
		if (dp != NULL)		{
			
			sprintf(cmd, "cp %s%sMarkerFile.mrk %s%sMarkerFile.mrk", dsName, FILE_SEPARATOR, newDsName, FILE_SEPARATOR );
			printf("copying MarkerFile.mrk ...\n");
			system(cmd);	
		}
	}
	else
	{	
		// create dummy .hc file for simulation from geom file 
		vectorCart	na;
		vectorCart	le;
		vectorCart	re;
		na.x = 5;
		na.y = 5;
		na.z = -22;
		le.x = -5;
		le.y = 5;
		le.z = -24;
		re.x = 5;
		re.y = -5;
		re.z = -24;	
		writeHeadCoilFile(newDsName, na, le, re);
	}
#else
	fp = fopen(newDsName, "r");
		if (fp != NULL)
		{
			fclose (fp);
			sprintf(cmd, "cp %s%sMarkerFile.mrk %s%sMarkerFile.mrk", dsName, FILE_SEPARATOR, newDsName, FILE_SEPARATOR );
			printf("copying MarkerFile.mrk ...\n");
			system(cmd);	
		}
	}
	else
	{	
		// create dummy .hc file for simulation from geom file 
		vectorCart	na;
		vectorCart	le;
		vectorCart	re;
		na.x = 5;
		na.y = 5;
		na.z = -22;
		le.x = -5;
		le.y = 5;
		le.z = -24;
		re.x = 5;
		re.y = -5;
		re.z = -24;	
		writeHeadCoilFile(newDsName, na, le, re);
	}
#endif				
		//
        
	
	mexPrintf("Computing simulated data:\n");
	for (int trial=0; trial<numTrials; trial++)
	{
		if (verbose)
		{
			printf("%c%c%c%c%c%c%c%c%c%c",0x08, 0x08,0x08,0x08,0x08, 0x08, 0x08,0x08,0x08,0x08 );
			printf("trial#%4d", trial+1);
			fflush(stdout);
		}
		
	    // zero data array for each trial - note in Version 2.2 and earlier zeroed all channels including STIM etc...
		for (int i=0; i < dsParams.numChannels; i++)
		{
			// zero MEG channels
			if ( dsParams.channel[i].isSensor || dsParams.channel[i].isBalancingRef )
			{
				for (int k=0; k< numSamples; k++)
					simulatedTrialData[i][k] = 0.0;
			}
		}
	

		if (addNoise)
		{
			for (int i=0; i < dsParams.numChannels; i++)
			{
				// add gaussian noise to data - will be filtered before saving
				if ( dsParams.channel[i].isSensor || dsParams.channel[i].isBalancingRef ) 
				{
					for (int k=0; k< numSamples; k++)
					{
						double dev = getGaussianDeviate();
						double noiseVal = dev * noiseSD * 1e-15;
						simulatedTrialData[i][k] = noiseVal;
					}
				}
			}
		}

		// add modulated source activity  
		// now calls subroutine that uses params or reads from file
		// D. Cheyne, Nov 2008
             
		for (int j=0; j<numSources; j++)
		{
			// get normalized activation function for this source and trials
			if (!generateSourceData(sourceData, params[j], numSamples, sampleRate, numPreTrig))
			{
				printf("Error getting activation function for source %d\n", j);
				return(false);
			}                        

			
			// add modulated forward solution to sim data array
			int sensorCount = 0;
			for (int i=0; i < dsParams.numChannels; i++)
			{
				// skip other channels
				if ( dsParams.channel[i].isSensor || dsParams.channel[i].isBalancingRef ) 
				{			
					double peakField = dipPatterns[j][sensorCount++];					
					for (int k=0; k<numSamples; k++)
						simulatedTrialData[i][k] += sourceData[k] * peakField;						
				}
			}
			
			// save activation functions in dummy ADC channels at end of original data
			// memory for simulatedTrialData should have been allocated for enough channels !
			// if using geom file original number of channels not saved in originalParams
			if (writeADC)
			{
				int ADCchannel = dsParams.numChannels - numSources + j;
				for (int k=0; k< numSamples; k++)
					simulatedTrialData[ADCchannel][k] = sourceData[k];
			}

		}

		// add simulated data + noise data to trialData array for this trial
	
		if ( addBrainNoise )
		{
			//  load existing data
			mexPrintf(" => Adding existing data from dataset %s, (trial %d, gradient order = %d) to simulated data ...\n", dsName, trial+1,selectedGradient);
						
			if ( !readMEGTrialData( dsName, originalParams, dataArray, trial, selectedGradient, false) )
			{
				printf("Error reading .meg4 file\n");
				return(false);
			}
			
			//printf("originalParams: numChannels = %d numSensors = %d numReferences = %d numBalancingRefs = %d\n",originalParams.numChannels, originalParams.numSensors, originalParams.numReferences, originalParams.numBalancingRefs);
	
			// add to simulated data up to number of requested samples
			for (int i=0; i < originalParams.numChannels; i++)
			{
				if ( originalParams.channel[i].isSensor || originalParams.channel[i].isBalancingRef ) 
				{
					for (int k=0; k< numSamples; k++)
						simulatedTrialData[i][k] += dataArray[i][k];
				}
			}
		}

		// filter data prior to saving...
		for (int i=0; i < dsParams.numChannels; i++)
		{
			// only filter MEG data
			if ( dsParams.channel[i].isSensor || dsParams.channel[i].isBalancingRef )
			{
				for (int k=0; k< numSamples; k++)
					trialBuffer[k] = simulatedTrialData[i][k];
				applyFilter( trialBuffer, simulatedTrialData[i], numSamples, &fparams);
			}
		}
		
		
		// append this trial to meg4 file
  		if ( !writeMEGTrialData( newDsName, dsParams, simulatedTrialData) )
		{
			printf("Error writing new .meg4 file\n");
			return(false);
		}

		
	} // next trial

	printf("\n...done\n");

	return(true);
}

// combined source and param file 
bool generateSourceData (double *sourceData, sim_params & params, int numSamples, double sampleRate, int numPreTrig)
{
	double 		pie = acos(-1.0);
	double		*waveform_data;
	int			nsamples;
	
	// zero buffer
	for (int k=0; k< numSamples; k++)
		sourceData[k] = 0.0;

	// array to hold waveform - can't be longer than trial
	waveform_data = (double *)malloc( sizeof(double) * numSamples);
	if (waveform_data == NULL)
	{
		printf("memory allocation failed for waveform_data");
		return(false);
	}
		
	// get number of samples for source activity window, truncate if exceeds trial length
	if (params.duration == 0.0)
	{
		printf("ERROR: duration of source activity is zero.  \n");
		return(false);
	}	
	nsamples = (int)(params.duration * sampleRate);	
	if ( nsamples > numSamples)
	{
		printf("WARNING: duration of source activity exceeds trial length, truncating...  \n");
		nsamples = numSamples;
	}	

	if (params.sourceType == SOURCE_FILE)
	{
		FILE *fp;
		
		if ( ( fp = fopen(params.sourceFile, "ra") ) == NULL )
		{
			printf("Couldn't open waveform data file %s\n", params.sourceFile);
			return (false);
		}
		
		for (int k=0; k< nsamples; k++)
		{
			double fval;
			bool outOfSamples = false;
			waveform_data[k] = 0.0;		

			if (feof(fp))
				outOfSamples = true;
			
			int errCode = fscanf(fp, "%lf", &fval) ;   // add Marc's check for bad values 
			if (errCode == EOF)
				outOfSamples = true;
		
			if (errCode == 0 || outOfSamples)
			{
				printf("Error reading samples from <%s>: check that file contains %d valid data samples...\n", params.sourceFile, nsamples);
				return(false);
			}
			else
				waveform_data[k] = fval;
		}
		
		// make sure source waveform is not zero and is normalized to 1.0;
		double maxVal = 0.0;
		for (int k=0; k< nsamples; k++)
		{
			if (fabs(waveform_data[k]) > maxVal)
				maxVal = fabs(waveform_data[k]);
		}	
		if (maxVal == 0)
		{
			printf(" ** Warning waveform values are all zero ** \n");
			return(false);
		}
		for (int k=0; k < nsamples; k++)	
		{
			waveform_data[k] = waveform_data[k]/maxVal;
		}
		fclose(fp);
	}	
	else if ( params.sourceType == SINEWAVE_SQUARED || params.sourceType == SINEWAVE || params.sourceType == SQUAREWAVE) 
	{
		// create waveform data over the duration of the function
		int sampleCount = 0;

		for (int k=0; k< nsamples; k++)
		{
			// compute modulation function;
			double t = sampleCount * (1.0/sampleRate);
			if ( params.sourceType == SINEWAVE_SQUARED) 
				waveform_data[k] = (sin(2.0 * pie * t * params.frequency)) * (sin(2.0 * pie * t * params.frequency));
			if ( params.sourceType == SINEWAVE)
				waveform_data[k] = sin(2.0 * pie * t * params.frequency);
			if (params.sourceType == SQUAREWAVE)
				waveform_data[k] = 1.0;	
			sampleCount++;
		}
	}	
	else 
	{
		printf("invalid source type...\n");
		return(false);
	}
	
	// randomize onset time ?
	double onsetTime = params.onsetTime;
	if ( params.onsetJitter > 0.0 )
	{
		double ranTime = ( ( getRandom() * 2.0) - 1.0 ) * params.onsetJitter;
		onsetTime += ranTime;
	}
	
	// randomize amplitude ?
	if ( params.amplitudeJitter > 0.0 )
	{
		double inc = ( ( getRandom() * 2.0) - 1.0 ) * params.amplitudeJitter;
		inc = 1.0 + (inc * 0.01);  // jitter is specified in percent
		for (int k=0; k < numSamples; k++)	
		{
			waveform_data[k] *= inc;
		}
	}
	
	// add waveform data to trial buffer 
	int startSample = (int)(onsetTime * sampleRate) + numPreTrig;
	if (startSample < 0)
		startSample = 0;
	int endSample = startSample + nsamples;
	if (endSample > numSamples)
		endSample = numSamples;
	
	int sampleCount = 0;
	for (int k=startSample; k< endSample; k++)	
		sourceData[k] = waveform_data[sampleCount++];
	
	free(waveform_data);

	return(true);
}


// combined source and param file 
bool initSimFile (char *simFileName, int *numSources)
{
	char		inputStr[256];
	FILE		*fp;
	char		strIndex[16];
	char		typeStr[256];
	
	// get dip params
	// 
	if ( ( fp = fopen(simFileName, "ra") ) == NULL )
	{
		printf("Couldn't open sim file %s\n", simFileName);
		return (false);
	}
	
	// check for correct file type
	bool validFile = false;
	while ( !feof(fp) )
	{
		fgets( inputStr, 256, fp);
		if ( !strncmp( inputStr, SIM_VERSION, strlen(SIM_VERSION)) )
		{
			validFile = true;
			break;
		}	
	}
	
	if (!validFile)
	{
		printf("sim file %s  does not appear to be correct version [%s]\n",simFileName, SIM_VERSION);
		return (false);
	}
	
	
	// get dipoles
	rewind(fp);
	int count = 0;
	while( !feof(fp) )
	{
		fgets( inputStr, 256, fp);
		// check for sources
		if ( !strncmp( inputStr, "Dipoles", 7) ) 
		{
			fgets( inputStr, 256, fp);  // skip '{'
			while(!feof(fp) )
			{
				fgets( inputStr, 256, fp);
				
				if ( !strncmp( inputStr, "}", 1) )
					break;
				else
				{
					count++;
				}
			}
		}
	}	
	*numSources = count;
	return (true);
}


// combined source and param file 
bool readSimFile (char *simFileName, dip_params *dipoles, sim_params *params, bool verbose)
{
	char		inputStr[256];
	FILE		*fp;
	char		strIndex[16];
	char		sourceStr[256];
	char		tStr[256];
	char		typeStr[256];

	// get dip params
	// 
	if ( ( fp = fopen(simFileName, "ra") ) == NULL )
	{
		printf("Couldn't open sim file %s\n", simFileName);
		return (false);
	}

	if (dipoles == NULL || params == NULL)
	{
		printf("NULL pointer passed to readSimFile\n");
		return(false);
	}
	
	int sourceCount = 0;
	while( !feof(fp) )
	{
		fgets( inputStr, 256, fp);
		// check for sources
		if ( !strncmp( inputStr, "Dipoles", 7) ) 
		{
			fgets( inputStr, 256, fp);  // skip '{'
			while(!feof(fp) )
			{
				fgets( inputStr, 256, fp);
				
				if ( !strncmp( inputStr, "}", 1) )
					break;
				else
				{
					sscanf(inputStr, "%s %lf %lf %lf %lf %lf %lf %lf",
					       strIndex,
					       &dipoles[sourceCount].xpos,
					       &dipoles[sourceCount].ypos,
					       &dipoles[sourceCount].zpos,
					       &dipoles[sourceCount].xori,
					       &dipoles[sourceCount].yori,
					       &dipoles[sourceCount].zori,
					       &dipoles[sourceCount].moment);
					sourceCount++;
				}
			}
		}
	}	
	
	// get parameters 

	bool foundParams = false;
	rewind(fp);
	while (!feof(fp) )
	{
		fgets( inputStr, 256, fp);
		if ( !strncmp( inputStr, "Params", 6) )
		{
			foundParams = true;
			break;
		}	
	}
	if (!foundParams )
	{
		printf("Could not find Params keyword in sim file.\n");
		return (false);
	}
	
	rewind(fp);
	
	int		paramCount = 0;
	
	while( !feof(fp) )
	{
		fgets( inputStr, 256, fp);
		// check for sources
		if ( !strncmp( inputStr, "Params", 6) ) 
		{
			fgets( inputStr, 256, fp);  // skip '{'
			while(!feof(fp) )
			{
				fgets( inputStr, 256, fp);
				
				if ( !strncmp( inputStr, "}", 1) )
					break;
				else
				{
					sscanf(inputStr, "%s %lf %lf %lf %lf %lf %s",
							strIndex,
				       		&params[paramCount].frequency,
				       		&params[paramCount].onsetTime,
							&params[paramCount].duration,
							&params[paramCount].onsetJitter,
							&params[paramCount].amplitudeJitter,
					        sourceStr);					
					
					// decode source type
					if (!strcmp(sourceStr,"sine-squared"))
						params[paramCount].sourceType = SINEWAVE_SQUARED;
					else if (!strcmp(sourceStr,"sine"))
						params[paramCount].sourceType = SINEWAVE;
					else if (!strcmp(sourceStr,"square"))
						params[paramCount].sourceType = SQUAREWAVE;
					else if (!strncmp(sourceStr,"file:", 5))
					{
						char *idx;
						char filePath[512];						
						params[paramCount].sourceType = SOURCE_FILE;
						// extract source file name
						idx = &sourceStr[5];
						sprintf(params[paramCount].sourceFile,"%s",idx);
					}
					else
					{
						params[paramCount].sourceType = -1;
						printf("Error: unknown activation type <%s> specified in .sim file \n", sourceStr);
						return(false);
					}	
					paramCount++;
					// next source....
				}
			}
		}
	}
	fclose(fp);
	
	if ( sourceCount != paramCount )
	{
		printf("Number of parameter lines %d are not the same as number of sources %d\n", sourceCount, paramCount);
		return(false);
	}
	
	// make sure orientation vector is unit
	for (int j=0; j<sourceCount; j++)
	{
		vectorCart orient;
		orient.x = dipoles[j].xori;
		orient.y = dipoles[j].yori;                
		orient.z = dipoles[j].zori;
		orient = unitVector(orient);
		dipoles[j].xori = orient.x;
		dipoles[j].yori = orient.y;              
		dipoles[j].zori = orient.z;                
	}
	
	if (verbose)
	{
		printf("Dipole parameters:\n");
		for (int j=0; j<sourceCount; j++)
		{
			printf("Source %d:  position: %g, %g, %g cm, orientation: %g, %g, %g,  moment: %g nAm\n", 
				   j+1, dipoles[j].xpos, dipoles[j].ypos, dipoles[j].zpos, dipoles[j].xori, dipoles[j].yori, dipoles[j].zori, dipoles[j].moment);

		}
		
		printf("Activation parameters:\n");
		for (int j=0; j<sourceCount; j++)
		{
			switch(params[j].sourceType)
			{
				case SINEWAVE_SQUARED:
					sprintf(tStr,"squared sine wave");
					break;
				case SINEWAVE:
					sprintf(tStr,"sine wave");
					break;
				case SQUAREWAVE:
					sprintf(tStr,"square wave");
					break;
				case SOURCE_FILE:
					sprintf(tStr,"waveform data from %s", params[j].sourceFile);
					break;
			}
			printf("Source %d:  freq: %g Hz, onset %g s, duration %g s, phase jitter %g s, amplitude jitter %g %% sourceType = %s\n", 
				   j+1, params[j].frequency, params[j].onsetTime, params[j].duration, params[j].onsetJitter, params[j].amplitudeJitter, tStr);
		}
	}
	
	
	return (true);
}

// D. Cheyne March 2020 - made local copy of "readGeomFile" for easier debugging

bool readSimGeomFile( char *fileName, ds_params & params)
{
    FILE        *fp;
    char        tStr[256];
    char        inStr[256];
    int            numChannels;
    char        name[256];
    char        previousName[256];
    double        gain1;
    double        gain2;
    int            numCoils;
    int            numTurns;
    double        area;
    double        x;
    double        y;
    double        z;
    double        xo;
    double        yo;
    double        zo;
    
    // write sensor geometry for a CTF dataset.
    printf("Reading sensor geometry from file [%s]\n", fileName);
    if ( ( fp = fopen( fileName, "r") ) == NULL )
    {
        printf("couldn't open [%s]\n", fileName);
        return(false);
    }
    
    numChannels = 0;
    while (!feof(fp))
    {
        fgets(inStr, 256, fp);
        
        sscanf(inStr,"%s",tStr);  // check input
        
        // skip comment lines starting with pound sign
        if (!strncmp(tStr,"#",1))
        continue;
        
        sscanf(inStr, "%s %lf %lf %d %d %lf %lf %lf %lf %lf %lf %lf",
               name, &gain1,&gain2,&numCoils,
               &numTurns, &area, &x, &y, &z, &xo, &yo, &zo);
        
        // this avoids duplicate entries due to linefeeds at end of file ...
        if (!strcmp(name, previousName))
            continue;

        sprintf(params.channel[numChannels].name, "%s", name);
        params.channel[numChannels].qGain = gain1;
        params.channel[numChannels].properGain = gain2;
		params.channel[numChannels].ioGain = 1.0;  // ** now has exist for new ctflib !!
        params.channel[numChannels].numCoils = numCoils;
        params.channel[numChannels].numTurns = numTurns;
        params.channel[numChannels].coilArea = area;
        params.channel[numChannels].xpos = x;
        params.channel[numChannels].ypos = y;
        params.channel[numChannels].zpos = z;
        params.channel[numChannels].p1x = xo;
        params.channel[numChannels].p1y = yo;
        params.channel[numChannels].p1z = zo;
        
        if (numCoils == 2)
        {
            sscanf(inStr, "%s %lf %lf %d %d %lf %lf %lf %lf %lf %lf %lf %d %lf %lf %lf %lf %lf %lf %lf",
                   name, &gain1,&gain2,&numCoils,
                   &numTurns, &area, &x, &y, &z, &xo, &yo, &zo,
                   &numTurns, &area, &x, &y, &z, &xo, &yo, &zo);
            
            params.channel[numChannels].xpos2 = x;
            params.channel[numChannels].ypos2 = y;
            params.channel[numChannels].zpos2 = z;
            params.channel[numChannels].p2x = xo;
            params.channel[numChannels].p2y = yo;
            params.channel[numChannels].p2z = zo;
        }
        
        // set other channel info
        params.channel[numChannels].index = numChannels;
        params.channel[numChannels].isSensor = true;
        params.channel[numChannels].isReference = false;
        params.channel[numChannels].isBalancingRef = false;
        params.channel[numChannels].gradient = 0;
        params.channel[numChannels].gain = params.channel[numChannels].properGain * params.channel[numChannels].qGain;
        if (params.channel[numChannels].numCoils == 1)
        params.channel[numChannels].sensorType = 4;
        else if (params.channel[numChannels].numCoils == 2)
        params.channel[numChannels].sensorType = 5;
        
        numChannels++;
        
        sprintf(previousName, "%s",name);
        
        
    }
    
    // set some critical header values for CTF datasets.
    sprintf(params.versionStr, "MEG42RS");
    
    printf("read info for %d MEG sensor channels\n", numChannels);
    params.numChannels = numChannels;
    params.numSensors = numChannels;
    params.numReferences = 0;
    params.numBalancingRefs = 0;
    
    fclose(fp);
    
    return(true);
}
