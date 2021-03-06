﻿


#define VEC_SIZE  200

typedef struct  strSparseVec
{
	int size;
	float* values;
	int* indices;
} SparseVec;



//simple kernel for adding two vectors
extern "C" __global__ void VecAdd(const float* A, const float* B, float* C, int N)
{
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < N)
        C[i] = A[i] + B[i];
}


//kernel only for testing how to pass pointer to STRUCT from .net 
extern "C" __global__ void StructPass(const SparseVec* vec,float* out,int N)
{

    int i = blockDim.x * blockIdx.x + threadIdx.x;
	
	if (i < N){

		/*out[i]+=vec[i].size+N;

		int idx = vec[i].indices[0];
		out[i]+=idx;*/

		 for(int k=0;k<vec[i].size;k++)
		 {
			 //int idx = vec[i].indices[k];
			 out[i] += vec[i].values[k];
		 }
	}
}


//Kernel with pointer to Struct which contains sparse vector values and indices
//not efficient
extern "C" __global__ void DotProd(const SparseVec* vec,float* out,int mainIdx, int N)
{
	__shared__ SparseVec  vec1;
	
	if(threadIdx.x==0){
		vec1= vec[mainIdx];
	}

	int i = blockDim.x * blockIdx.x + threadIdx.x;
	if (i >= N){
		return;
	}
	SparseVec vec2 = vec[i];

	__syncthreads();

	int curr1=0;
	int curr2=0;

	int idx1=0;
	int idx2=0;
	float result =0;
	while (curr1 < vec1.size && curr2 < vec2.size)
	{
		idx1 = vec1.indices[curr1];
		idx2 = vec2.indices[curr2];

		if (idx1 == idx2)
		{
			result += vec1.values[curr1] * vec2.values[curr2];
			curr1++; curr2++;
		}
		else if (idx1 < idx2)
		{
			curr1++;
		}
		else
		{
			curr2++;
		}
	}

	out[i]=result;

}

//
extern "C" __global__ void DotProd2(const SparseVec* vec,float* out,int mainIdx, int N)
{
	__shared__ SparseVec  vec1;
	__shared__ float vec1Values[VEC_SIZE];
	__shared__ int vec1Indices[VEC_SIZE];
	__shared__ int vec1Size;

	if(threadIdx.x==0){
		vec1= vec[mainIdx];
		vec1Size =vec1.size;

		for(int k=0;k<vec1Size;k++)
		{
			vec1Values[k]=vec1.values[k];

			vec1Indices[k]=vec1.indices[k];

		}

	}

	int i = blockDim.x * blockIdx.x + threadIdx.x;
	if (i >= N){
		return;
	}
	SparseVec vec2 = vec[i];

	__syncthreads();

	int curr1=0;
	int curr2=0;

	int idx1=0;
	int idx2=0;
	float result =0;
	while (curr1 < vec1Size && curr2 < vec2.size)
	{
		idx1 = vec1Indices[curr1];
		idx2 = vec2.indices[curr2];

		if (idx1 == idx2)
		{
			result += vec1Values[curr1] * vec2.values[curr2];
			curr1++; curr2++;
		}
		else if (idx1 < idx2)
		{
			curr1++;
		}
		else
		{
			curr2++;
		}
	}

	out[i]=result;

}


//bad IDEA !!
//extern "C" __global__ void DotProd3(const SparseVec* vec,float* out,int mainIdx, int N)
//{
//	__shared__ SparseVec  vec1;
//	__shared__ float vec1Values[VEC_SIZE];
//	__shared__ int vec1Indices[VEC_SIZE];
//	__shared__ int vec1Size;
//
//	__shared__ float vecVals[BLOCK_SIZE][VEC_SIZE];
//	__shared__ int vecIdx[BLOCK_SIZE][VEC_SIZE];
//	__shared__ int vecSizes[BLOCK_SIZE];
//
//	if(threadIdx.x==0){
//		vec1= vec[mainIdx];
//		vec1Size =vec1.size;
//
//		for(int k=0;k<vec1Size;k++)
//		{
//			vec1Values[k]=vec1.values[k];
//
//			vec1Indices[k]=vec1.indices[k];
//		}
//
//	}
//
//	int i = blockDim.x * blockIdx.x + threadIdx.x;
//	if (i >= N){
//		return;
//	}
//	for(int j=0;j<BLOCK_SIZE;j++)
//	{
//		int ii = blockDim.x * blockIdx.x + j;
//		if(ii<N){
//		SparseVec vector= vec[ii];
//
//		if(threadIdx.x<vector.size)
//		{
//			vecVals[j][threadIdx.x]=vector.values[threadIdx.x];
//			vecIdx[j][threadIdx.x]=vector.indices[threadIdx.x];
//			vecSizes[j]=vector.size;
//		}
//		}
//	}
//	
//
//	__syncthreads();
//
//	int curr1=0;
//	int curr2=0;
//
//	int idx1=0;
//	int idx2=0;
//	float result =0;
//	while (curr1 < vec1Size && curr2 < vecSizes[i])
//	{
//		idx1 = vec1Indices[curr1];
//		idx2 = vecIdx[i][curr2];
//
//		if (idx1 == idx2)
//		{
//			result += vec1Values[curr1] * vecVals[i][curr2];
//			curr1++; curr2++;
//		}
//		else if (idx1 < idx2)
//		{
//			curr1++;
//		}
//		else
//		{
//			curr2++;
//		}
//	}
//
//	out[i]=result;
//
//}



//sparse matrix vector multiplication matrix in ELLPack format
extern "C" __global__ void DotProdEllPack(const float* vals,
										  const int* idx,
										  const float* mainVec,
										  float* out,
										  int maxRowSize,
										  int N)
{


	int row = blockDim.x*blockIdx.x+threadIdx.x;

	if(row<N){
		float dot=0;
		for(int i=0;i<maxRowSize;i++)
		{
			int col = idx[N*i+row];
			float val = vals[N*i+row];

			if(val!=0)
			{
				dot+=val*mainVec[col];
			}
		}

		out[row]+=dot;
	}
}

texture<float,1,cudaReadModeElementType> texRef;

//sparse matrix vector multiplication matrix in ELLPack format, vector in texture "cache"
//better preformace than previous DotProdEllPack kernel
extern "C" __global__ void DotProdEllPackCached(const float* vals,
										  const int* idx,
										  float* out,
										  int maxRowSize,
										  int N)
{


	int row = blockDim.x*blockIdx.x+threadIdx.x;

	if(row<N){
		float dot=0;
		for(int i=0;i<maxRowSize;i++)
		{
			int col = idx[N*i+row];
			float val = vals[N*i+row];

			if(val!=0)
			{
				dot+=val* tex1D(texRef,col); 
			}
		}

		out[row]+=dot;
	}
}


//simple multiplication one element from matrix times one element from vector,
//only for testing multiplciation speed - its realy fast!
extern "C" __global__ void SegmentedMulCached(const float* vals,
										  const int* idx,
										  float* out,
										  int N)
{

	int row = blockDim.x*blockIdx.x+threadIdx.x;

	if(row<N){
		
		out[row]=vals[row]*tex1D(texRef,idx[row]);
		
	}
}


//sparse matrix-vector multiplication based one experiments from above kernel, 
//quite fast
extern "C" __global__ void DotProdSegmentedCached(const float* vals,
										  const int* idx,
										  const int* vecLenght,
										  float* temp,
										  float* dotArr,
										  int numRows,
										  int numElements)
{

	int row = blockDim.x*blockIdx.x+threadIdx.x;

	if(row<numElements){

		temp[row]=vals[row]*tex1D(texRef,idx[row]);

		__syncthreads();


		if(row<numRows){
			float dot=0;

			for(int k=vecLenght[row];k<vecLenght[row+1];k++)
			{
				dot+=temp[k];
			}

			dotArr[row]=dot;
		}
	}
}



#define BLOCK_SIZE 256

#define WARP_SIZE 32


//cuda kernel for linerar dot product with writecombined memory
extern "C" __global__ void spmv_csr_vector_kernel_wc(const float * Ax,
									   const int * Aj, 
									   const int * Ap, 
									   const float * mainVector,
									   float * y,
									   const int num_rows,
									   int numElements)
{
    __shared__ float sdata[BLOCK_SIZE + 16];                          // padded to avoid reduction ifs
    __shared__ int ptrs[BLOCK_SIZE/WARP_SIZE][2];
    
    const int thread_id   = BLOCK_SIZE * blockIdx.x + threadIdx.x;  // global thread index
    const int thread_lane = threadIdx.x & (WARP_SIZE-1);            // thread index within the warp
    const int warp_id     = thread_id   / WARP_SIZE;                // global warp index
    const int warp_lane   = threadIdx.x / WARP_SIZE;                // warp index within the CTA
    const int num_warps   = (BLOCK_SIZE / WARP_SIZE) * gridDim.x;   // total number of active warps

    for(int row = warp_id; row < num_rows; row += num_warps){
        // use two threads to fetch Ap[row] and Ap[row+1]
        // this is considerably faster than the straightforward version
        if(thread_lane < 2)
            ptrs[warp_lane][thread_lane] = Ap[row + thread_lane];
        const int row_start = ptrs[warp_lane][0];                   //same as: row_start = Ap[row];
        const int row_end   = ptrs[warp_lane][1];                   //same as: row_end   = Ap[row+1];

        // compute local sum
        float sum = 0;
        for(int jj = row_start + thread_lane; jj < row_end; jj += WARP_SIZE)
            sum += Ax[jj] * mainVector[Aj[jj]];

        // reduce local sums to row sum (ASSUME: warpsize 32)
        sdata[threadIdx.x] = sum;
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x + 16]; __syncthreads(); 
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  8]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  4]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  2]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  1]; __syncthreads();
       


        // first thread writes warp result
        if (thread_lane == 0)
            //y[row] += sdata[threadIdx.x];
			y[row] = sdata[threadIdx.x];
		
			
    }
}




extern "C" __global__ void spmv_csr_scalar_kernel(const float * Ax,
									   const int * Aj, 
									   const int * Ap, 
									   float * y,
									   const int num_rows)
{

	//#define large_grid_thread_id(void) ((blockDim.x * (blockIdx.x + blockIdx.y*gridDim.x) + threadIdx.x))
    //#define large_grid_thread_id(void) ((__umul24(blockDim.x,blockIdx.x + __umul24(blockIdx.y,gridDim.x)) + threadIdx.x))
    // row index
    //const int row = blockDim.x * (blockIdx.x + blockIdx.y*gridDim.x) + threadIdx.x;
    
	const int row=blockDim.x*blockIdx.x+2*threadIdx.x;
	const int row2=blockDim.x*blockIdx.x+2*threadIdx.x+1;

	//!!this is mistake, can't check ony row2<num_rows
    if(row2 < num_rows){     
        float sum = 0;//y[row];
		float sum2=0;

        const int row_start = Ap[row];
        const int row_end   = Ap[row+1];
		const int rowDiff = row_end - row_start;

		const int row_end2   = Ap[row+2];
    
		float xVec=0;
        for (int jj = row_start; jj < row_end2; jj++){   
			xVec = tex1Dfetch(texRef,Aj[jj]);

			if(xVec!=0)
			{
				if(jj<row_end)
					sum += Ax[jj] * xVec;
				if( (jj+rowDiff)<row_end2)
					sum2+= Ax[jj+rowDiff] * xVec;
					
			}
            //sum += Ax[jj] * tex1Dfetch(texRef,Aj[jj]);
        }

        y[row] = sum;
		y[row2] = sum2;
    }
}


//csr vector kernel for linear dot product
extern "C" __global__ void spmv_csr_vector_kernel(const float * Ax,
									   const int * Aj, 
									   const int * Ap, 
									   float * y,
									   const int num_rows,
									   int numElements)
{
    __shared__ float sdata[BLOCK_SIZE + 16];                          // padded to avoid reduction ifs
    __shared__ int ptrs[BLOCK_SIZE/WARP_SIZE][2];
    
    const int thread_id   = BLOCK_SIZE * blockIdx.x + threadIdx.x;  // global thread index
    const int thread_lane = threadIdx.x & (WARP_SIZE-1);            // thread index within the warp
    const int warp_id     = thread_id   / WARP_SIZE;                // global warp index
    const int warp_lane   = threadIdx.x / WARP_SIZE;                // warp index within the CTA
    const int num_warps   = (BLOCK_SIZE / WARP_SIZE) * gridDim.x;   // total number of active warps

    for(int row = warp_id; row < num_rows; row += num_warps){
        // use two threads to fetch Ap[row] and Ap[row+1]
        // this is considerably faster than the straightforward version
        if(thread_lane < 2)
            ptrs[warp_lane][thread_lane] = Ap[row + thread_lane];
        const int row_start = ptrs[warp_lane][0];                   //same as: row_start = Ap[row];
        const int row_end   = ptrs[warp_lane][1];                   //same as: row_end   = Ap[row+1];

        // compute local sum
        float sum = 0;
        for(int jj = row_start + thread_lane; jj < row_end; jj += WARP_SIZE)
            sum += Ax[jj] * tex1Dfetch(texRef,Aj[jj]);

        // reduce local sums to row sum (ASSUME: warpsize 32)
        sdata[threadIdx.x] = sum;
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x + 16]; __syncthreads(); 
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  8]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  4]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  2]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  1]; __syncthreads();
       


        // first thread writes warp result
        if (thread_lane == 0)
            //y[row] += sdata[threadIdx.x];
			y[row] = sdata[threadIdx.x];
		
			
    }
}




extern "C" __global__ void RBFspmv_csr_vector(const float * Ax,
									   const int * Aj, 
									   const int * Ap, 
									   const float* selfDot,
									   float * y,
									   const int num_rows,
									   const int yIdx,
									   const float gamma,
									   int numElements)
{
    __shared__ float sdata[BLOCK_SIZE + 16];                          // padded to avoid reduction ifs
    __shared__ int ptrs[BLOCK_SIZE/WARP_SIZE][2];
    
    const int thread_id   = BLOCK_SIZE * blockIdx.x + threadIdx.x;  // global thread index
    const int thread_lane = threadIdx.x & (WARP_SIZE-1);            // thread index within the warp
    const int warp_id     = thread_id   / WARP_SIZE;                // global warp index
    const int warp_lane   = threadIdx.x / WARP_SIZE;                // warp index within the CTA
    const int num_warps   = (BLOCK_SIZE / WARP_SIZE) * gridDim.x;   // total number of active warps

    for(int row = warp_id; row < num_rows; row += num_warps){
        // use two threads to fetch Ap[row] and Ap[row+1]
        // this is considerably faster than the straightforward version
        if(thread_lane < 2)
            ptrs[warp_lane][thread_lane] = Ap[row + thread_lane];
        const int row_start = ptrs[warp_lane][0];                   //same as: row_start = Ap[row];
        const int row_end   = ptrs[warp_lane][1];                   //same as: row_end   = Ap[row+1];

        // compute local sum
        float sum = 0;
        for(int jj = row_start + thread_lane; jj < row_end; jj += WARP_SIZE)
            sum += Ax[jj] * tex1D(texRef,Aj[jj]);

        // reduce local sums to row sum (ASSUME: warpsize 32)
        sdata[threadIdx.x] = sum;
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x + 16]; __syncthreads(); 
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  8]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  4]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  2]; __syncthreads();
        sdata[threadIdx.x] = sum = sum + sdata[threadIdx.x +  1]; __syncthreads();
       


        // first thread writes warp result
		if (thread_lane == 0){
         //   y[row] += sdata[threadIdx.x];
			y[row]=expf(-gamma*(selfDot[row]+selfDot[yIdx]-2*sdata[threadIdx.x]));
		}
    }
}




extern "C" __global__ void RBFEllPackCached(const float* vals,
										  const int* idx,
										  const float* selfDot,
										  float* out,
										  int maxRowSize,
										  const int N,
										  
										  const int yIdx,
										  const float gamma)
{

	__shared__ float yDot;

	int row = blockDim.x*blockIdx.x+threadIdx.x;
	if(threadIdx.x==0)
		yDot=selfDot[yIdx];

	if(row<N){
		float dot=0;
		for(int i=0;i<maxRowSize;i++)
		{
			int col = idx[N*i+row];
			float val = vals[N*i+row];

			if(val!=0)
			{
				dot+=val* tex1D(texRef,col); 
			}
		}

		//__syncthreads();
		//out[row]=expf(-gamma*(selfDot[row]+selfDot[yIdx]-2*dot));
		out[row]=expf(-gamma*(selfDot[row]+yDot-2*dot));
	}
}
