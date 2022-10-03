// mex routine to compute normal vectors for a list of mesh vertices and faces
//
// written by Zhengkai Chen. Jan, 2013
// modified by Douglas Cheyne, Nov 2013
//
// calling syntax is:
// [normals] = bw_computeFaceNormals( vertices, faces);
//
//  Version 2.1 - modified by D. Cheyne - precompute all face normals for faster execution

double VERSION_NO = 2.1;

#include "math.h"
#include "mex.h"


void ccodeCross(double a[3], double b[3], double c[3]);
void bw_computeFaceNormals(double *surface_points_orien_RPI,double *surface_points_RPI, double *surface_faces,int numberofpoint, int numberofface);


void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]){


	double *surface_points_orien_RPI,*surface_points_RPI;
	double *surface_faces;
	
	int numberofpoint,numberofface;

	int n_inputs = 2;
	int n_outputs = 1;
	
	if ( nlhs != n_outputs | nrhs != n_inputs)
	{
		mexPrintf("bw_computeFaceNormals ver. %.1f (c) Douglas Cheyne and Zhengkai Chen. 2010-2011. All rights reserved.\n", VERSION_NO);
		mexPrintf("Incorrect number of input or output arguments\n");
		mexPrintf("Usage:\n");
		mexPrintf("   [normals] = bw_ComputeFaceNormals(vertices, faces) \n");
		mexPrintf("   input is numVertices x 3 vector array and numFaces x 3 face indices \n");
		mexPrintf("   returns numSensors x 3 vectors which are the normals to the vertices (average of surrounding faces)\n");
		return;
	}
	
	numberofpoint = mxGetN(prhs[0]);
	numberofface = mxGetN(prhs[1]);

    surface_points_RPI = mxGetPr(prhs[0]);
    surface_faces = mxGetPr(prhs[1]);

    plhs[0] = mxCreateDoubleMatrix(3,numberofpoint,mxREAL);

    surface_points_orien_RPI = mxGetPr(plhs[0]);

	bw_computeFaceNormals(surface_points_orien_RPI, surface_points_RPI, surface_faces, numberofpoint, numberofface);
}

void bw_computeFaceNormals( double *surface_points_orien_RPI,double *surface_points_RPI, double *surface_faces,int numberofpoint, int numberofface){
    
	 
	 int faceidx[12] = {0};
	 int i,j,k;
	 int r = 0;
	 double meanvertex[3]={0};
	 double meanvertex_norm[3]={0};
	 double v[3]={0};
	 double v1[3]={0};
	 double v2[3]={0};
	 double v3[3]={0};
	 double w1[3]={0};
	 double w2[3]={0};
	 double u[3]={0};
	
    double  *normalBuffer_x[32];
    double  *normalBuffer_y[32];
    double  *normalBuffer_z[32];
    int     *normalCount;
    
    // D. Cheyne  Dec, 2013
    // faster way of computing N vertex normals without searching through all faces N times
    // loop through triangles and get the face normal and add that
    // to an array for each vertex.  Then loop through all vertices
    // and sum and normalize all the normals for that vertex
    
    // since we are not using growing arrays in C++ have to keep our own counter for each buffer
    
    // create array to hold max number of normals
    for (i=0; i<32; i++)
    {
        normalBuffer_x[i] = (double *)malloc( sizeof(double) * numberofpoint );
        if (normalBuffer_x[i] == NULL)
        {
            mexPrintf("memory allocation failed for normalBuffer array");
            return;
        }
    }
    for (i=0; i<32; i++)
    {
        normalBuffer_y[i] = (double *)malloc( sizeof(double) * numberofpoint );
        if (normalBuffer_y[i] == NULL)
        {
            mexPrintf("memory allocation failed for normalBuffer array");
            return;
        }
    }
    for (i=0; i<32; i++)
    {
        normalBuffer_z[i] = (double *)malloc( sizeof(double) * numberofpoint );
        if (normalBuffer_z[i] == NULL)
        {
            mexPrintf("memory allocation failed for normalBuffer array");
            return;
        }
    }
    
    normalCount = (int *)malloc( sizeof(int) * numberofpoint );
    if (normalCount == NULL)
    {
        mexPrintf("memory allocation failed for normalCount array");
        return;
    }
    for (i=0; i<numberofpoint; i++)
        normalCount[i] = 0;  // reset counters to zero
	 
    for (j=0;j<numberofface;j++)
    {
        // odd indexing has to do with how multidimensional arrays are passed to mex function as
        // one dimensinal arrays
        
        // get vertex indices for this triangle (numbered from zero to N-1)
        int v1Index = (int)(surface_faces[j*3]);
        int v2Index = (int)(surface_faces[j*3+1]);
        int v3Index = (int)(surface_faces[j*3+2]);
                
        v1[0] = surface_points_RPI[(int)(v1Index*3)];
        v1[1] = surface_points_RPI[(int)(v1Index*3+1)];
        v1[2] = surface_points_RPI[(int)(v1Index*3+2)];
        
        v2[0] = surface_points_RPI[(int)(v2Index*3)];
        v2[1] = surface_points_RPI[(int)(v2Index*3+1)];
        v2[2] = surface_points_RPI[(int)(v2Index*3+2)];
        
        v3[0] = surface_points_RPI[(int)(v3Index*3)];
        v3[1] = surface_points_RPI[(int)(v3Index*3+1)];
        v3[2] = surface_points_RPI[(int)(v3Index*3+2)];
    
        for (k=0; k<3; k++)
        {
            w1[k] = v1[k]-v2[k];
            w2[k] = v2[k]-v3[k];
        }
        
        // take cross-product of two edges
        ccodeCross(w1,w2, v);
        
        // make unit vect
        for (k=0;k<3;k++)
        {
            u[k] = v[k]/sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2]);
        }
        
        int idx;
        
        // add to this normal to the buffer for each of the 3 vertices making up this triangle
        // and increment the number of normals for each, checking that we dont' exceed max number of 32

        idx = normalCount[v1Index];
        if (idx < 32)
        {
            normalBuffer_x[idx][v1Index] = u[0];
            normalBuffer_y[idx][v1Index] = u[1];
            normalBuffer_z[idx][v1Index] = u[2];
            normalCount[v1Index]++;
        }
        idx = normalCount[v2Index];
        if (idx < 32)
        {
            normalBuffer_x[idx][v2Index] = u[0];
            normalBuffer_y[idx][v2Index] = u[1];
            normalBuffer_z[idx][v2Index] = u[2];
            normalCount[v2Index]++;
        }
        idx = normalCount[v3Index];
        if (idx < 32)
        {
            normalBuffer_x[idx][v3Index] = u[0];
            normalBuffer_y[idx][v3Index] = u[1];
            normalBuffer_z[idx][v3Index] = u[2];
            normalCount[v3Index]++;
        }
    
    }
    
    // loop through all vertices and get mean of the normals in each buffer
    
	 for (i=0; i<numberofpoint;i++)
	 {
         for (k=0;k<3;k++)
         {
             meanvertex[k] = 0;
         }
         
         // compute mean of count normals
         int count = normalCount[i];
                  
		 for (j=0;j<count;j++)
		 {
             meanvertex[0] += normalBuffer_x[j][i];
             meanvertex[1] += normalBuffer_y[j][i];
             meanvertex[2] += normalBuffer_z[j][i];
         }
		 
         // get mean of count vertices
         for (k=0;k<3;k++)
         {
             meanvertex[k] = meanvertex[k]/count;
         }

         // normalize to unit
		 for (k=0; k<3; k++)
		 {
            meanvertex_norm[k] = meanvertex[k]/sqrt(meanvertex[0]*meanvertex[0]+meanvertex[1]*meanvertex[1]+meanvertex[2]*meanvertex[2]);

		 }		

		 surface_points_orien_RPI[3*i] = meanvertex_norm[0];
		 surface_points_orien_RPI[3*i+1] = meanvertex_norm[1];
		 surface_points_orien_RPI[3*i+2] = meanvertex_norm[2];
	 }
    
    for (i=0; i<12; i++)
    {
        free(normalBuffer_x[i]);
        free(normalBuffer_y[i]);
        free(normalBuffer_z[i]);
    }
    free( normalCount );
    
    return;
}

void ccodeCross(double a[3], double b[3], double c[3]){
    
        c[0] = a[1] * b[2] - b[1] * a[2];
        c[1] = a[2] * b[0] - b[2] * a[0];
        c[2] = a[0] * b[1] - b[0] * a[1];  
   
        return;
}
