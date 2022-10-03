// *************************************
// mex routine to read single trial dataset and return the average waveforms for all sensor channels
//
// calling syntax is:
// [fdata] = sim_filter( data, hipass, lowpass, sampleRate, order, bidirectional );
//
// returns
//      fdata = [1 x nsamples] vector of filtered data
//
//		(c) Douglas O. Cheyne, 2004-2010  All rights reserved.
//
//		1.0  - first version
//		1.2	 - modified to be consistent with ctf_BWFilter.cc - fixed order and adds bandreject option
//
//      version 3.3 Dec 2016 - modified to adjust order for bidirectional - more consistent with CTF DataEditor filter
// ************************************

#include "mex.h"
#include "string.h"


#include "../../../ctflib/headers/datasetUtils.h"
#include "../../../ctflib/headers/BWFilter.h"

#define VERSION_NO 1.2

double	*buffer;

extern "C" 
{
void mexFunction( int nlhs, mxArray *plhs[], int nrhs, const mxArray*prhs[] )
{ 
    
	double			*data;
	double			*fdata;
	
	double			*dataPtr;
	double          *val;
	
	double			sampleRate;
	double          highPass;
	double          lowPass;
	int				numSamples;
	int				filterOrder = 4;
    int             maxOrder = 8;           // will limit coeffs to 4th order
	bool			bidirectional = true;
	bool			bandreject = false;
	
	filter_params 	fparams;

	/* Check for proper number of arguments */
	int n_inputs = 3;
	int n_outputs = 1;
	if ( nlhs != n_outputs | nrhs < n_inputs)
	{
		mexPrintf("sim_filter ver. %.1f (c) Douglas Cheyne, PhD. 2010. All rights reserved.\n", VERSION_NO); 
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n"); 
		mexPrintf("   [fdata] = sim_filter( data,sampleRate, [hipass lowpass], {options}  )\n");
		mexPrintf("   [data] must be 1 x nsamples array\n");
		mexPrintf("   [sampleRate] sample rate of data.\n");
		mexPrintf("   [highPass lowPass] high  and low pass cutoff frequency in Hz for bandpass. Enter 0 for highPass for lowPass only.\n");
		mexPrintf("Options:\n");
		mexPrintf("   [order]           - specify filter order. (4th order recommended)\n");
		mexPrintf("   [bidirectional]   - if true filter is bidirectional (two-pass non-phase shifting). Default = true\n");
		mexPrintf("   [bandreject]      - if true filter is band-reject. Default = band-pass\n");
		mexPrintf(" \n");
		return;
	}

	if (mxGetM(prhs[0]) != 1 && mxGetN(prhs[0]) != 1)
		mexErrMsgTxt("Input [1] must be a 1 by nsamples row vector of data.");
	if (mxGetM(prhs[0]) == 1)
		numSamples = (int)mxGetN(prhs[0]); 
	else
		numSamples = (int)mxGetM(prhs[0]); 
		
	data = mxGetPr(prhs[0]);

	val = mxGetPr(prhs[1]);
	sampleRate = *val;
	
	if (mxGetM(prhs[2]) != 1 || mxGetN(prhs[2]) != 2)
		mexErrMsgTxt("Input [2] must be a row vector [hipass lowpass].");
	dataPtr = mxGetPr(prhs[2]);
	highPass = dataPtr[0];
	lowPass = dataPtr[1];

	if (nrhs > 3)
	{
		val = mxGetPr(prhs[3]);
		filterOrder = (int)*val;
	}
	
	if (nrhs > 4)
	{
		val = mxGetPr(prhs[4]);
		bidirectional = (int)*val;
	}

	if (nrhs > 5)
	{
		val = mxGetPr(prhs[5]);
		bandreject = (int)*val;
	}

	plhs[0] = mxCreateDoubleMatrix(1, numSamples, mxREAL);
	fdata = mxGetPr(plhs[0]);
	
//	mexPrintf("Read %d samples, BW = %g %g Hz, sampleRate = %g, order = %d, bidirectional = %d\n", 
//			  numSamples, highPass, lowPass, sampleRate, filterOrder, bidirectional);
	
	fparams.enable = true;
	
	if ( highPass == 0.0 && lowPass == 0.0)
	{
		mexPrintf("invalid filter settings\n");
		return;
	}
	
	if ( highPass == 0.0 )
		fparams.type = BW_LOWPASS;
	else
		fparams.type = BW_BANDPASS;
	
	if (bandreject)
	{
		if ( highPass == 0.0 )
		{
			mexPrintf("high-pass frequency must be specified for band-reject filter.\n");
			return;
		}
		else
			fparams.type = BW_BANDREJECT;
	}
	else
	{
		if ( highPass == 0.0 )
			fparams.type = BW_LOWPASS;
		else if ( lowPass == 0.0 )
			fparams.type = BW_HIGHPASS;
		else
			fparams.type = BW_BANDPASS;
	}
    
    if ( filterOrder > maxOrder)
	{
		mexPrintf("filter order too high...\n");
		return;
	}
	
    if (bidirectional )
    {
        double t = filterOrder / 2.0;
        filterOrder = round(t);   // in case non multiple of 2
        if (filterOrder < 1)
            filterOrder = 1;
    }
    
    
	fparams.bidirectional = bidirectional;
	fparams.hc = lowPass;
	fparams.lc = highPass;
	fparams.fs = sampleRate;
	fparams.order = filterOrder;
	fparams.ncoeff = 0;
	
	
	if (build_filter (&fparams) == -1)
	{
		mexPrintf("memory allocation failed for trial array\n");
		return;
	}
	
	
	buffer = (double *)malloc( sizeof(double) * numSamples );
	if (buffer == NULL)
	{
		mexPrintf("memory allocation failed for buffer array");
		return;
	}
	
	for (int k=0; k< numSamples; k++)
		buffer[k] = data[k];
	
	applyFilter( buffer, fdata, numSamples, &fparams);
	 
	free(buffer);

	return;
         
}
    
}


