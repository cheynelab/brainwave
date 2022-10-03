// *************************************
// mex routine to get dataset parameters
// modified by Zhengkai Chen, 2012 to get all parameters and return as struct
//
// calling syntax is:
// params = ctf_GetParams( datasetname );
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
//		2.5		Dec, 2013 - copied version for BrainWave - renamed bw_CTFGetHeader to avoid confusion with old routine (CTFGetParams)
// ************************************

#include "mex.h"
#include "matrix.h"
#include <string.h>
#include "../../../ctflib/headers/datasetUtils.h"

#define VERSION_NO 2.5

#define NUMBER_OF_FIELDS (sizeof(field_names)/sizeof(*field_names))
#define NUMBER_OF_CHANNEL_FIELDS (sizeof(channel_field_names)/sizeof(*channel_field_names))

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

	// define dsParams structure field names
	const char *field_names[] = {"numSamples", "numPreTrig", "numChannels", "numTrials", "numSensors", "numReferences", 
		"numBalancingRefs", "gradientOrder", "sampleRate", "trialDuration", "lowPass", "highPass", "epochMinTime", "epochMaxTime",
	"numG1Coefs", "numG2Coefs", "numG3Coefs", "numG4Coefs", "hasBalancingCoefs", "no_trials_avgd", "versionStr",  "run_description",
	"run_title", "operator_id", "g1List", "g3List", "channel"};
    
	//define dsParams.channel structure field names
	const char *channel_field_names[] = {"name", "index", "sensorType", "isSensor", "isReference", "isBalancingRef", "isEEG", "gain", 
		"properGain", "qGain", "numCoils", "numTurns", "coilArea", "xpos", "ypos", "zpos", "xpos2", "ypos2", "zpos2", "p1x", "p1y", "p1z", 
	"p2x", "p2y", "p2z", "gradient", "g1Coefs", "g2Coefs", "g3Coefs", "g4Coefs", "sphereX", "sphereY", "sphereZ", "xpos_dewar", "ypos_dewar", 
	"zpos_dewar", "xpos2_dewar", "ypos2_dewar", "zpos2_dewar", "p1x_dewar", "p1y_dewar", "p1z_dewar", "p2x_dewar", "p2y_dewar", "p2z_dewar"};
	
	
	int numSamples_field, numPreTrig_field, numChannels_field, numTrials_field, numSensors_field, numReferences_field, numBalancingRefs_field, gradientOrder_field,
		sampleRate_field, trialDuration_field, lowPass_field, highPass_field, epochMinTime_field, epochMaxTime_field, numG1Coefs_field, numG2Coefs_field, numG3Coefs_field, 
		numG4Coefs_field, hasBalancingCoefs_field, no_trials_avgd_field, versionStr_field, run_description_field, run_title_field, operator_id_field, 
		g1List_field, g3List_field, channel_field;

	int name_field, index_field, sensorType_field, isSensor_field, isReference_field, isBalancingRef_field, isEEG_field, gain_field, properGain_field, qGain_field, numCoils_field, 
		numTurns_field, coilArea_field, xpos_field, ypos_field, zpos_field, xpos2_field, ypos2_field, zpos2_field, p1x_field, p1y_field, p1z_field, p2x_field, p2y_field, p2z_field,
		gradient_field, g1Coefs_field, g2Coefs_field, g3Coefs_field, g4Coefs_field, sphereX_field, sphereY_field, sphereZ_field, xpos_dewar_field, ypos_dewar_field, zpos_dewar_field,
		xpos2_dewar_field, ypos2_dewar_field, zpos2_dewar_field, p1x_dewar_field, p1y_dewar_field, p1z_dewar_field, p2x_dewar_field, p2y_dewar_field, p2z_dewar_field;
   	
	
	/* Check for proper number of arguments */
	int n_inputs = 1;
	int n_outputs = 1;
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("bw_CTFGetHeader ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO);
		mexPrintf("Modified by zhengkai May 2012\n"); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf(" [params] = bw_CTFGetHeader(datasetName)\n"); 				
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


	//create dsParams structure
	int dims[2] = {1,1};
	plhs[0] = mxCreateStructArray(2, dims,NUMBER_OF_FIELDS, field_names); 

	
    if ( !readMEGResFile( fileName, dsParams ) )
    {
		mexErrMsgTxt("Error reading res4 file for sensors\n");
    }
//     mexPrintf("dsParams.run_description is %s", dsParams.run_description);

    // Get field number for each field name
	numSamples_field = mxGetFieldNumber(plhs[0],"numSamples");
	numPreTrig_field = mxGetFieldNumber(plhs[0],"numPreTrig");
	numChannels_field = mxGetFieldNumber(plhs[0],"numChannels");
	numTrials_field = mxGetFieldNumber(plhs[0],"numTrials");
	numSensors_field = mxGetFieldNumber(plhs[0],"numSensors");	
	numReferences_field = mxGetFieldNumber(plhs[0],"numReferences");
	numBalancingRefs_field = mxGetFieldNumber(plhs[0],"numBalancingRefs");
	gradientOrder_field = mxGetFieldNumber(plhs[0],"gradientOrder");
	sampleRate_field = mxGetFieldNumber(plhs[0],"sampleRate");
	trialDuration_field = mxGetFieldNumber(plhs[0],"trialDuration");
	lowPass_field = mxGetFieldNumber(plhs[0],"lowPass");
	highPass_field = mxGetFieldNumber(plhs[0],"highPass");
	epochMinTime_field = mxGetFieldNumber(plhs[0],"epochMinTime");
	epochMaxTime_field = mxGetFieldNumber(plhs[0],"epochMaxTime");
	numG1Coefs_field = mxGetFieldNumber(plhs[0],"numG1Coefs");
	numG2Coefs_field = mxGetFieldNumber(plhs[0],"numG2Coefs");
	numG3Coefs_field = mxGetFieldNumber(plhs[0],"numG3Coefs");
	numG4Coefs_field = mxGetFieldNumber(plhs[0],"numG4Coefs");
	hasBalancingCoefs_field = mxGetFieldNumber(plhs[0],"hasBalancingCoefs");
	no_trials_avgd_field = mxGetFieldNumber(plhs[0],"no_trials_avgd");
	versionStr_field = mxGetFieldNumber(plhs[0],"versionStr");
	run_description_field = mxGetFieldNumber(plhs[0],"run_description");
	run_title_field = mxGetFieldNumber(plhs[0],"run_title");
	operator_id_field = mxGetFieldNumber(plhs[0],"operator_id");
	g1List_field = mxGetFieldNumber(plhs[0],"g1List");
	g3List_field = mxGetFieldNumber(plhs[0], "g3List");
	channel_field = mxGetFieldNumber(plhs[0], "channel");


	mxArray *field_value1,*field_value2,*field_value3,*field_value4,*field_value5,*field_value6,*field_value7,*field_value8,*field_value9,*field_value10;
	mxArray *field_value11,*field_value12,*field_value13,*field_value14,*field_value15,*field_value16,*field_value17,*field_value18,*field_value19,*field_value20;
	field_value1 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value2 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value3 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value4 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value5 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value6 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value7 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value8 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value9 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value10 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value11 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value12 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value13 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value14 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value15 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value16 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value17 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value18 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value19 = mxCreateDoubleMatrix(1,1,mxREAL);
	field_value20 = mxCreateDoubleMatrix(1,1,mxREAL);
	*mxGetPr(field_value1) = dsParams.numSamples;
	*mxGetPr(field_value2) = dsParams.numPreTrig;
	*mxGetPr(field_value3) = dsParams.numChannels;
	*mxGetPr(field_value4) = dsParams.numTrials;
	*mxGetPr(field_value5) = dsParams.numSensors;
	*mxGetPr(field_value6) = dsParams.numReferences;
	*mxGetPr(field_value7) = dsParams.numBalancingRefs;
	*mxGetPr(field_value8) = dsParams.gradientOrder;
	*mxGetPr(field_value9) = dsParams.sampleRate;
	*mxGetPr(field_value10) = dsParams.trialDuration;
	*mxGetPr(field_value11) = dsParams.lowPass;
	*mxGetPr(field_value12) = dsParams.highPass;
	*mxGetPr(field_value13) = dsParams.epochMinTime;
	*mxGetPr(field_value14) = dsParams.epochMaxTime;
	*mxGetPr(field_value15) = dsParams.numG1Coefs;
	*mxGetPr(field_value16) = dsParams.numG2Coefs;
	*mxGetPr(field_value17) = dsParams.numG3Coefs;
	*mxGetPr(field_value18) = dsParams.numG4Coefs;
	*mxGetPr(field_value19) = dsParams.hasBalancingCoefs;
	*mxGetPr(field_value20) = dsParams.no_trials_avgd;

	// set field values/strings
	mxSetFieldByNumber(plhs[0],0,numSamples_field,field_value1);
	mxSetFieldByNumber(plhs[0],0,numPreTrig_field,field_value2);
	mxSetFieldByNumber(plhs[0],0,numChannels_field,field_value3);
	mxSetFieldByNumber(plhs[0],0,numTrials_field,field_value4);
	mxSetFieldByNumber(plhs[0],0,numSensors_field,field_value5);
	mxSetFieldByNumber(plhs[0],0,numReferences_field,field_value6);
	mxSetFieldByNumber(plhs[0],0,numBalancingRefs_field,field_value7);
	mxSetFieldByNumber(plhs[0],0,gradientOrder_field,field_value8);
	mxSetFieldByNumber(plhs[0],0,sampleRate_field,field_value9);
	mxSetFieldByNumber(plhs[0],0,trialDuration_field,field_value10);
	mxSetFieldByNumber(plhs[0],0,lowPass_field,field_value11);
	mxSetFieldByNumber(plhs[0],0,highPass_field,field_value12);
	mxSetFieldByNumber(plhs[0],0,epochMinTime_field,field_value13);
	mxSetFieldByNumber(plhs[0],0,epochMaxTime_field,field_value14);
	mxSetFieldByNumber(plhs[0],0,numG1Coefs_field,field_value15);
	mxSetFieldByNumber(plhs[0],0,numG2Coefs_field,field_value16);
	mxSetFieldByNumber(plhs[0],0,numG3Coefs_field,field_value17);
	mxSetFieldByNumber(plhs[0],0,numG4Coefs_field,field_value18);
	mxSetFieldByNumber(plhs[0],0,hasBalancingCoefs_field,field_value19);
	mxSetFieldByNumber(plhs[0],0,no_trials_avgd_field,field_value20);

	mxSetFieldByNumber(plhs[0],0,versionStr_field,mxCreateString(dsParams.versionStr));
	mxSetFieldByNumber(plhs[0],0,run_description_field,mxCreateString(dsParams.run_description));	
	mxSetFieldByNumber(plhs[0],0,run_title_field,mxCreateString(dsParams.run_title));
	mxSetFieldByNumber(plhs[0],0,operator_id_field,mxCreateString(dsParams.operator_id));

	mxArray *g1list_cell, *g3list_cell;
	int dims1[2] ={MAX_BALANCING,1};
	g1list_cell = mxCreateCellArray(1,dims1);
	g3list_cell = mxCreateCellArray(1,dims1);
	mwIndex i,j;
	for (i=0; i<MAX_BALANCING; i++){
		
		mxSetCell(g1list_cell, i, mxCreateString(dsParams.g1List[i]));
		mxSetCell(g3list_cell, i, mxCreateString(dsParams.g3List[i]));
	}


	mxSetFieldByNumber(plhs[0],0,g1List_field,g1list_cell);
	mxSetFieldByNumber(plhs[0],0,g3List_field,g3list_cell);

    // define dsParams.channel structure
    int dims2[2] = {1,dsParams.numChannels};
    mxArray *channel_struct;
	channel_struct = mxCreateStructArray(2, dims2,NUMBER_OF_CHANNEL_FIELDS, channel_field_names);


	name_field = mxGetFieldNumber(channel_struct, "name");
	index_field = mxGetFieldNumber(channel_struct, "index");
	sensorType_field = mxGetFieldNumber(channel_struct, "sensorType");
	isSensor_field = mxGetFieldNumber(channel_struct, "isSensor");
	isReference_field = mxGetFieldNumber(channel_struct, "isReference");
	isBalancingRef_field = mxGetFieldNumber(channel_struct, "isBalancingRef");
	isEEG_field = mxGetFieldNumber(channel_struct, "isEEG");
	gain_field = mxGetFieldNumber(channel_struct, "gain");
	properGain_field = mxGetFieldNumber(channel_struct, "properGain");
	qGain_field = mxGetFieldNumber(channel_struct, "qGain");
	numCoils_field = mxGetFieldNumber(channel_struct, "numCoils");
	numTurns_field = mxGetFieldNumber(channel_struct, "numTurns");
	coilArea_field = mxGetFieldNumber(channel_struct, "coilArea");
	xpos_field = mxGetFieldNumber(channel_struct, "xpos");
	ypos_field = mxGetFieldNumber(channel_struct, "ypos");
	zpos_field = mxGetFieldNumber(channel_struct, "zpos");
	xpos2_field = mxGetFieldNumber(channel_struct, "xpos2");
	ypos2_field = mxGetFieldNumber(channel_struct, "ypos2");
	zpos2_field = mxGetFieldNumber(channel_struct, "zpos2");
	p1x_field = mxGetFieldNumber(channel_struct, "p1x");
	p1y_field = mxGetFieldNumber(channel_struct, "p1y");
	p1z_field = mxGetFieldNumber(channel_struct, "p1z");
	p2x_field = mxGetFieldNumber(channel_struct, "p2x");
	p2y_field = mxGetFieldNumber(channel_struct, "p2y");
	p2z_field = mxGetFieldNumber(channel_struct, "p2z");
	gradient_field = mxGetFieldNumber(channel_struct, "gradient");
	g1Coefs_field = mxGetFieldNumber(channel_struct, "g1Coefs");
	g2Coefs_field = mxGetFieldNumber(channel_struct, "g2Coefs");
	g3Coefs_field = mxGetFieldNumber(channel_struct, "g3Coefs");
	g4Coefs_field = mxGetFieldNumber(channel_struct, "g4Coefs");
	sphereX_field = mxGetFieldNumber(channel_struct, "sphereX");
	sphereY_field = mxGetFieldNumber(channel_struct, "sphereY");
	sphereZ_field = mxGetFieldNumber(channel_struct, "sphereZ");
	xpos_dewar_field = mxGetFieldNumber(channel_struct, "xpos_dewar");
	ypos_dewar_field = mxGetFieldNumber(channel_struct, "ypos_dewar");
	zpos_dewar_field = mxGetFieldNumber(channel_struct, "zpos_dewar");
	xpos2_dewar_field = mxGetFieldNumber(channel_struct, "xpos2_dewar");
	ypos2_dewar_field = mxGetFieldNumber(channel_struct, "ypos2_dewar");
	zpos2_dewar_field = mxGetFieldNumber(channel_struct, "zpos2_dewar");
	p1x_dewar_field = mxGetFieldNumber(channel_struct, "p1x_dewar");
	p1y_dewar_field = mxGetFieldNumber(channel_struct, "p1y_dewar");
	p1z_dewar_field = mxGetFieldNumber(channel_struct, "p1z_dewar");
	p2x_dewar_field = mxGetFieldNumber(channel_struct, "p2x_dewar");
	p2y_dewar_field = mxGetFieldNumber(channel_struct, "p2y_dewar");
	p2z_dewar_field = mxGetFieldNumber(channel_struct, "p2z_dewar");


	for (i=0; i<dsParams.numChannels; i++){
	mxArray  *channel_field_value1, *channel_field_value2, *channel_field_value3, *channel_field_value4, *channel_field_value5, *channel_field_value6,
		*channel_field_value7, *channel_field_value8, *channel_field_value9, *channel_field_value10, *channel_field_value11, *channel_field_value12, *channel_field_value13, 
		*channel_field_value14, *channel_field_value15, *channel_field_value16, *channel_field_value17, *channel_field_value18, *channel_field_value19, *channel_field_value20,
		*channel_field_value21, *channel_field_value22, *channel_field_value23, *channel_field_value24, *channel_field_value25, *channel_field_value26, *channel_field_value27,
		*channel_field_value28, *channel_field_value29, *channel_field_value30, *channel_field_value31, *channel_field_value32, *channel_field_value33, *channel_field_value34, 
		*channel_field_value35, *channel_field_value36, *channel_field_value37, *channel_field_value38, *channel_field_value39, *channel_field_value40, *channel_field_value41,
		*channel_field_value42, *channel_field_value43, *channel_field_value44;

	channel_field_value1 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value2 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value3 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value4 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value5 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value6 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value7 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value8 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value9 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value10 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value11 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value12 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value13 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value14 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value15 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value16 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value17 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value18 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value19 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value20 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value21 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value22 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value23 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value24 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value25 = mxCreateDoubleMatrix(1,1,mxREAL);
    
    int numG1, numG2, numG3, numG4;
        if (dsParams.numG1Coefs !=0){
	   
        numG1 =  dsParams.numG1Coefs;   
        }
        else{
           numG1 = 1;
        }

       int dims3[2] ={numG1,1};

    
        if (dsParams.numG2Coefs !=0){
	    
           numG2 =  dsParams.numG2Coefs;
        }
        else{
           numG2 = 1;
        }
        int dims4[2] ={numG2,1};
    
        if (dsParams.numG3Coefs !=0){
	    
           numG3 =  dsParams.numG3Coefs;
        }
        else{
            numG3 = 1;
        }
        int dims5[2] ={numG3,1};
        
        if (dsParams.numG4Coefs !=0){
	   
            numG4 =  dsParams.numG4Coefs;
        }
        else{
            numG4 = 1;
        }
        int dims6[2] ={numG4,1};

	
	channel_field_value26 = mxCreateCellArray(1,dims3);
	channel_field_value27 = mxCreateCellArray(1,dims4);
	channel_field_value28 = mxCreateCellArray(1,dims5);
    channel_field_value29 = mxCreateCellArray(1,dims6);

	channel_field_value30 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value31 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value32 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value33 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value34 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value35 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value36 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value37 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value38 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value39 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value40 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value41 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value42 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value43 = mxCreateDoubleMatrix(1,1,mxREAL);
	channel_field_value44 = mxCreateDoubleMatrix(1,1,mxREAL);

	*mxGetPr(channel_field_value1) = dsParams.channel[i].index;
	*mxGetPr(channel_field_value2) = dsParams.channel[i].sensorType;
	*mxGetPr(channel_field_value3) = dsParams.channel[i].isSensor;
	*mxGetPr(channel_field_value4) = dsParams.channel[i].isReference;
	*mxGetPr(channel_field_value5) = dsParams.channel[i].isBalancingRef;
	*mxGetPr(channel_field_value6) = dsParams.channel[i].isEEG;
	*mxGetPr(channel_field_value7) = dsParams.channel[i].gain;
	*mxGetPr(channel_field_value8) = dsParams.channel[i].properGain;
	*mxGetPr(channel_field_value9) = dsParams.channel[i].qGain;
	*mxGetPr(channel_field_value10) = dsParams.channel[i].numCoils;
	*mxGetPr(channel_field_value11) = dsParams.channel[i].numTurns;
	*mxGetPr(channel_field_value12) = dsParams.channel[i].coilArea;
	*mxGetPr(channel_field_value13) = dsParams.channel[i].xpos;
	*mxGetPr(channel_field_value14) = dsParams.channel[i].ypos;
	*mxGetPr(channel_field_value15) = dsParams.channel[i].zpos;
	*mxGetPr(channel_field_value16) = dsParams.channel[i].xpos2;
	*mxGetPr(channel_field_value17) = dsParams.channel[i].ypos2;
	*mxGetPr(channel_field_value18) = dsParams.channel[i].zpos2;
	*mxGetPr(channel_field_value19) = dsParams.channel[i].p1x;
	*mxGetPr(channel_field_value20) = dsParams.channel[i].p1y;
	*mxGetPr(channel_field_value21) = dsParams.channel[i].p1z;
	*mxGetPr(channel_field_value22) = dsParams.channel[i].p2x;
	*mxGetPr(channel_field_value23) = dsParams.channel[i].p2y;
	*mxGetPr(channel_field_value24) = dsParams.channel[i].p2z;
	*mxGetPr(channel_field_value25) = dsParams.channel[i].gradient;


    if (dsParams.numG1Coefs != 0){
	for (j=0; j<dsParams.numG1Coefs; j++){
		mxArray *g1Coefs_cell;
		g1Coefs_cell = mxCreateDoubleMatrix(1,1,mxREAL);		
        *mxGetPr(g1Coefs_cell) = dsParams.channel[i].g1Coefs[j];	    
		mxSetCell(channel_field_value26, j, g1Coefs_cell);		
	}
    }
    else{
       mxSetCell(channel_field_value26, 0, 0);
    }
    
    if (dsParams.numG2Coefs != 0){
	for (j=0; j<dsParams.numG2Coefs; j++){
		mxArray *g2Coefs_cell;
		g2Coefs_cell = mxCreateDoubleMatrix(1,1,mxREAL);		
        *mxGetPr(g2Coefs_cell) = dsParams.channel[i].g2Coefs[j];	    
		mxSetCell(channel_field_value27, j, g2Coefs_cell);		
	}
    }
    else{
        mxSetCell(channel_field_value27, 0, 0);
    }

    if (dsParams.numG3Coefs != 0){
	for (j=0; j<dsParams.numG3Coefs; j++){
		mxArray *g3Coefs_cell;
		g3Coefs_cell = mxCreateDoubleMatrix(1,1,mxREAL);		
        *mxGetPr(g3Coefs_cell) = dsParams.channel[i].g3Coefs[j];	    
		mxSetCell(channel_field_value28, j, g3Coefs_cell);		
	}
     }
     else{
        mxSetCell(channel_field_value28, 0, 0);
     }

     if (dsParams.numG4Coefs != 0){
	for (j=0; j<dsParams.numG4Coefs; j++){
		mxArray *g4Coefs_cell;
		g4Coefs_cell = mxCreateDoubleMatrix(1,1,mxREAL);		
        *mxGetPr(g4Coefs_cell) = dsParams.channel[i].g4Coefs[j];	    
		mxSetCell(channel_field_value29, j, g4Coefs_cell);		
	}
     }
     else{
        mxSetCell(channel_field_value29, 0, 0);
     }
	

	*mxGetPr(channel_field_value30) = dsParams.channel[i].sphereX;
	*mxGetPr(channel_field_value31) = dsParams.channel[i].sphereY;
	*mxGetPr(channel_field_value32) = dsParams.channel[i].sphereZ;
	*mxGetPr(channel_field_value33) = dsParams.channel[i].xpos_dewar;
	*mxGetPr(channel_field_value34) = dsParams.channel[i].ypos_dewar;
	*mxGetPr(channel_field_value35) = dsParams.channel[i].zpos_dewar;
	*mxGetPr(channel_field_value36) = dsParams.channel[i].xpos2_dewar;
	*mxGetPr(channel_field_value37) = dsParams.channel[i].ypos2_dewar;
	*mxGetPr(channel_field_value38) = dsParams.channel[i].zpos2_dewar;
	*mxGetPr(channel_field_value39) = dsParams.channel[i].p1x_dewar;
	*mxGetPr(channel_field_value40) = dsParams.channel[i].p1y_dewar;
	*mxGetPr(channel_field_value41) = dsParams.channel[i].p1z_dewar;
	*mxGetPr(channel_field_value42) = dsParams.channel[i].p2x_dewar;
	*mxGetPr(channel_field_value43) = dsParams.channel[i].p2y_dewar;
	*mxGetPr(channel_field_value44) = dsParams.channel[i].p2z_dewar;
	
	
	mxSetFieldByNumber(channel_struct,i,name_field,mxCreateString(dsParams.channel[i].name));
	mxSetFieldByNumber(channel_struct,i,index_field,channel_field_value1);
	mxSetFieldByNumber(channel_struct,i,sensorType_field,channel_field_value2);
	mxSetFieldByNumber(channel_struct,i,isSensor_field,channel_field_value3);
	mxSetFieldByNumber(channel_struct,i,isReference_field,channel_field_value4);
	mxSetFieldByNumber(channel_struct,i,isBalancingRef_field,channel_field_value5);
	mxSetFieldByNumber(channel_struct,i,isEEG_field,channel_field_value6);
	mxSetFieldByNumber(channel_struct,i,gain_field,channel_field_value7);
	mxSetFieldByNumber(channel_struct,i,properGain_field,channel_field_value8);
	mxSetFieldByNumber(channel_struct,i,qGain_field,channel_field_value9);
	mxSetFieldByNumber(channel_struct,i,numCoils_field,channel_field_value10);
	mxSetFieldByNumber(channel_struct,i,numTurns_field,channel_field_value11);
	mxSetFieldByNumber(channel_struct,i,coilArea_field,channel_field_value12);
	mxSetFieldByNumber(channel_struct,i,xpos_field,channel_field_value13);
	mxSetFieldByNumber(channel_struct,i,ypos_field,channel_field_value14);
	mxSetFieldByNumber(channel_struct,i,zpos_field,channel_field_value15);
	mxSetFieldByNumber(channel_struct,i,xpos2_field,channel_field_value16);
	mxSetFieldByNumber(channel_struct,i,ypos2_field,channel_field_value17);
	mxSetFieldByNumber(channel_struct,i,zpos2_field,channel_field_value18);
	mxSetFieldByNumber(channel_struct,i,p1x_field,channel_field_value19);
	mxSetFieldByNumber(channel_struct,i,p1y_field,channel_field_value20);
	mxSetFieldByNumber(channel_struct,i,p1z_field,channel_field_value21);
	mxSetFieldByNumber(channel_struct,i,p2x_field,channel_field_value22);
	mxSetFieldByNumber(channel_struct,i,p2y_field,channel_field_value23);
	mxSetFieldByNumber(channel_struct,i,p2z_field,channel_field_value24);
	mxSetFieldByNumber(channel_struct,i,gradient_field,channel_field_value25);
	mxSetFieldByNumber(channel_struct,i,g1Coefs_field,channel_field_value26);
	mxSetFieldByNumber(channel_struct,i,g2Coefs_field,channel_field_value27);
	mxSetFieldByNumber(channel_struct,i,g3Coefs_field,channel_field_value28);
	mxSetFieldByNumber(channel_struct,i,g4Coefs_field,channel_field_value29);
	mxSetFieldByNumber(channel_struct,i,sphereX_field,channel_field_value30);
	mxSetFieldByNumber(channel_struct,i,sphereY_field,channel_field_value31);
	mxSetFieldByNumber(channel_struct,i,sphereZ_field,channel_field_value32);
	mxSetFieldByNumber(channel_struct,i,xpos_dewar_field,channel_field_value33);
	mxSetFieldByNumber(channel_struct,i,ypos_dewar_field,channel_field_value34);
	mxSetFieldByNumber(channel_struct,i,zpos_dewar_field,channel_field_value35);
	mxSetFieldByNumber(channel_struct,i,xpos2_dewar_field,channel_field_value36);
	mxSetFieldByNumber(channel_struct,i,ypos2_dewar_field,channel_field_value37);
	mxSetFieldByNumber(channel_struct,i,zpos2_dewar_field,channel_field_value38);
	mxSetFieldByNumber(channel_struct,i,p1x_dewar_field,channel_field_value39);
	mxSetFieldByNumber(channel_struct,i,p1y_dewar_field,channel_field_value40);
	mxSetFieldByNumber(channel_struct,i,p1z_dewar_field,channel_field_value41);
	mxSetFieldByNumber(channel_struct,i,p2x_dewar_field,channel_field_value42);
	mxSetFieldByNumber(channel_struct,i,p2y_dewar_field,channel_field_value43);
	mxSetFieldByNumber(channel_struct,i,p2z_dewar_field,channel_field_value44);

	}

	
	mxSetFieldByNumber(plhs[0],0,channel_field,channel_struct);

		
	mxFree(fileName);

	
	 
	return;
         
}


    
}


