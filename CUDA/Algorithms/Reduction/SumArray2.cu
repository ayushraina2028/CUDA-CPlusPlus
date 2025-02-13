#include <bits/stdc++.h>

#define threadsPerBlock 16

using namespace std;
using namespace chrono;

/*
Interleaved Addressing - Optimization 1
1. Replace divergent branch in inner loop.
2. With strided index and non divergent branch.

This introduces a new problem: Shared Memory Bank Conflicts.
*/

__global__ void Reduce1(int* device_input, int* device_output, int N) {
    
    __shared__ int s_data[threadsPerBlock];
    int tid = threadIdx.x;
    int gid = blockIdx.x * blockDim.x + threadIdx.x;

    s_data[tid] = (gid < N) ? device_input[gid] : 0;
    __syncthreads();

    for(int stride = 1; stride < blockDim.x; stride *= 2) {
        
        int index = 2 * stride * tid;
        if(index < blockDim.x) {
            s_data[index] += s_data[index + stride];
        }
        __syncthreads();

    }

    if(tid == 0) {
        device_output[blockIdx.x] = s_data[0];
    }
}

high_resolution_clock::time_point getTime() {
    return high_resolution_clock::now();
}   

int main() {
    int N = 1 << 28;
    size_t bytes = N*sizeof(int);

    int* host_input = new int[N];
    int* host_output = (int*) malloc((N/threadsPerBlock)*sizeof(int));

    // Initialize the input array to 1
    for(int i = 0;i < N; i++) {
        host_input[i] = 1;
    }

    // Pointers for GPU
    int* device_input; cudaMalloc((void**)&device_input,bytes); cudaMemcpy(device_input, host_input, bytes, cudaMemcpyHostToDevice);
    int* device_output; cudaMalloc((void**)&device_output,(N/threadsPerBlock)*sizeof(int));

    // Each thread Handles 2 Elements
    int blocksPerGrid = (N + threadsPerBlock - 1) / threadsPerBlock;
    cout << "Blocks Per Grid: " << blocksPerGrid << endl; cout << "Threads Per Block: " << threadsPerBlock << endl;

    // Kernel Call to Reduce the Array

    auto start = getTime();

    Reduce1<<<blocksPerGrid,threadsPerBlock>>>(device_input,device_output,N);
    cudaDeviceSynchronize();

    while(blocksPerGrid > 1) {

        int newBlocksPerGrid = (blocksPerGrid + threadsPerBlock - 1) / threadsPerBlock;
        cout << "Entered While Loop!, Next Blocks Per Grid: " << newBlocksPerGrid << endl;
        
        Reduce1<<<newBlocksPerGrid,threadsPerBlock>>>(device_output, device_output, N);
        cudaDeviceSynchronize();

        blocksPerGrid = newBlocksPerGrid;
    }

    auto stop = getTime();
    milliseconds duration = duration_cast<milliseconds>(stop - start);
    cout << "Time Taken: " << duration.count() << " ms" << endl;

    cudaMemcpy(host_output,device_output,(N/threadsPerBlock)*sizeof(int),cudaMemcpyDeviceToHost);
    cudaFree(device_input); cudaFree(device_output);

    cout << "Array Sum: " << host_output[0] << endl;
    int sumCPU = 0; for(int i = 0;i < N; i++) sumCPU += host_input[i]; 
    
    if(sumCPU == host_output[0]) cout << "CPU and GPU Sums Match!" << endl;
    else cout << "CPU and GPU Sums Do Not Match!" << endl;

    // cout << "Host Output Array: "; for(int i = 0;i < N/threadsPerBlock; i++) cout << host_output[i] << " "; cout << endl;

    delete[] host_input; free(host_output);
    return 0;
}