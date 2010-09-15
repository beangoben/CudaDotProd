﻿
//texture for vector, which is used for matrix vector multiplication
//in SVM, when we have to compute many dot products (one vector with others)
texture<float,1,cudaReadModeElementType> mainVectorTexRef;

//texture fo labels assiociated with vectors
texture<float,1,cudaReadModeElementType> labelsTexRef;



#define BLOCK_SIZE 256

#define WARP_SIZE 32

/*
Based on cuda kernels from 
"Efcient Sparse Matrix-Vector Multiplication on CUDA" Nathan Bell and Michael Garlandy
December 11, 2008
*/
//
//cuda kernel funtion for computing SVM linear kernel, uses 
// CSR fromat for storing sparse matrix, labels and main vector are
//in texture cache
//Remarks: based on spmv_csr_vector_kernel from publication above
//Params:
//vals - array of vectors values
//idx  - array of vectros indexes in CSR fromat
//vecPointers -array of pointers(indexes) to idx and vals array to specific vectors
//results - array of results Linear Kernel
//num_rows - number of vectors, stored in CSR matrix format, each vector is stored in one row of matrix
//mainVecIndex - main vector index, needed for retriving its label
extern "C" __global__ void linearCsrFormatKernel(const float * vals,
									   const int * idx, 
									   const int * vecPointers, 
									   float * results,
									   const int num_rows,
									   int mainVecIndex)
{
    __shared__ float sdata[BLOCK_SIZE + 16];                          // padded to avoid reduction ifs
    __shared__ int ptrs[BLOCK_SIZE/WARP_SIZE][2];
    
    const int thread_id   = BLOCK_SIZE * blockIdx.x + threadIdx.x;  // global thread index
    const int thread_lane = threadIdx.x & (WARP_SIZE-1);            // thread index within the warp
    const int warp_id     = thread_id   / WARP_SIZE;                // global warp index
    const int warp_lane   = threadIdx.x / WARP_SIZE;                // warp index within the CTA
    const int num_warps   = (BLOCK_SIZE / WARP_SIZE) * gridDim.x;   // total number of active warps

    for(int row = warp_id; row < num_rows; row += num_warps){
        // use two threads to fetch vecPointers[row] and vecPointers[row+1]
        // this is considerably faster than the straightforward version
        if(thread_lane < 2)
            ptrs[warp_lane][thread_lane] = vecPointers[row + thread_lane];
        const int row_start = ptrs[warp_lane][0];                   //same as: row_start = vecPointers[row];
        const int row_end   = ptrs[warp_lane][1];                   //same as: row_end   = vecPointers[row+1];

        // compute local sum
        float sum = 0;
        for(int jj = row_start + thread_lane; jj < row_end; jj += WARP_SIZE)
            sum += vals[jj] * tex1D(mainVectorTexRef,idx[jj]);

        // reduce local sums to row sum (ASSUME: warpsize 32)
        sdata[threadIdx.x] = sum;
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x + 16]; __syncthreads(); 
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  8]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  4]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  2]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  1]; __syncthreads();
       


        // first thread writes warp result
        if (thread_lane == 0)
            //results[row] += sdata[threadIdx.x];
			results[row] =tex1D(labelsTexRef,mainVecIndex)*tex1D(labelsTexRef,row) * sdata[threadIdx.x];
		
			
    }
}



