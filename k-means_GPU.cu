#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

#include "cuda_runtime.h"
#include "device_launch_parameters.h"
 
int K,N,D;  //聚类的数目，数据量，数据的维数
float **data;  //存放数据
int *in_cluster;  //标记每个点属于哪个聚类
float **cluster_center;  //存放每个聚类的中心点
 
float **array(int m,int n);
void freearray(float **p);
float **loadData(int *k,int *d,int *n);
float getDistance(float avector[],float bvector[],int n);
void cluster();
float getDifference();
void getCenter(int in_cluster[]);
void cluster1();


int  main()
{
	int i,j,count=0;
	float temp1,temp2;
	data=loadData(&K,&D,&N);
	printf("Data sets:\n");
	for(i=0;i<N;i++)
		for(j=0;j<D;j++){
			printf("%-8.2f",data[i][j]);
			if((j+1)%D==0)    putchar('\n');
		}
		printf("-----------------------------\n");
 
		srand((unsigned int)(time(NULL)));  //随机初始化k个中心点
		for(i=0;i<K;i++)
			for(j=0;j<D;j++)
				cluster_center[i][j]=data[(int)((double)N*rand()/(RAND_MAX+1.0))][j];
 
		cluster();  //用随机k个中心点进行聚类
		temp1=getDifference();  //第一次中心点和所属数据点的距离之和
		count++;
		printf("The difference between data and center is: %.2f\n\n", temp1);
 
		getCenter(in_cluster);
		
        cluster();  //用新的k个中心点进行第二次聚类
    
		temp2=getDifference();
		count++;
		printf("The difference between data and center is: %.2f\n\n",temp2);
 
		while(fabs(temp2-temp1)!=0){   //比较前后两次迭代，若不相等继续迭代
			temp1=temp2;
			getCenter(in_cluster);
			cluster();
			temp2=getDifference();
			count++;
			printf("The %dth difference between data and center is: %.2f\n\n",count,temp2);
		}

		printf("\nThe total number of cluster is: %d\n",count);  //统计迭代次数
		//system("pause");  //gcc编译需删除 
		return 0;
       
}
 
 
//动态创建二维数组
float **array(int m,int n)
{
	int i;
	float **p;
	p=(float **)malloc(m*sizeof(float *));
	p[0]=(float *)malloc(m*n*sizeof(float));
	for(i=1;i<m;i++)    p[i]=p[i-1]+n;
	return p;
}
 
//释放二维数组所占用的内存
void freearray(float **p)
{
	free(*p);
	free(p);
}
 
//从data.txt导入数据，要求首行格式：K=聚类数目,D=数据维度,N=数据量
float **loadData(int *k,int *d,int *n)
{
	int i,j; 
	float **arraydata;
	FILE *fp;
	if((fp=fopen("iris.data","r"))==NULL)    fprintf(stderr,"cannot open data!\n");
	if(fscanf(fp,"K=%d D=%d N=%d\n",k,d,n)!=3)        fprintf(stderr,"load error!\n");
	arraydata=array(*n,*d);  //生成数据数组
	cluster_center=array(*k,*d);  //聚类的中心点
	in_cluster=(int *)malloc(*n * sizeof(int));  //每个数据点所属聚类的标志数组
	for(i=0;i<*n;i++)
		for(j=0;j<*d;j++)
			fscanf(fp,"%f,",&arraydata[i][j]);  //读取数据点
	return arraydata;
}
 
//计算欧氏距离
float getDistance(float avector[],float bvector[],int n)
{
	int i;
	float sum=0.0;
	for(i=0;i<n;i++)
		sum+=pow(avector[i]-bvector[i],2);
	return sqrt(sum);
}
 

__device__ float GetDistance(float avector[],float bvector[],int n)
{
	int i;
	float sum=0.0;
	for(i=0;i<n;i++)
    {
		sum+=(avector[i]-bvector[i])*(avector[i]-bvector[i]);
    }
	return sqrt(sum);
}

__global__ void ComputeDistance(float* distance,float **data_2d,float **cc_2d,int d)
{
    int i = blockIdx.x;
    int j = threadIdx.x;
        //printf("第%d与聚类%d的距离是",i,j);
        distance[i*blockDim.x+j] = GetDistance(data_2d[i],cc_2d[j],d);
        //printf("属于聚类%d\n",in_cluster_h[i]);
}


//把N个数据点聚类，标出每个点属于哪个聚类
__host__ void cluster()
{
    float *distance;
    cudaMalloc((void**)&distance,sizeof(float)*N*K);//在GPU中申请distance的内存
    
	//float **distance=array(N,K);  //存放每个数据点到每个中心点的距离
	//float distance[N][K];  //也可使用C99变长数组
    float **data_2d,**cc_2d;
    float **host_data_2d = array(N,K);
    float **host_cc_2d = array(K,D);
    for(int i = 0;i < N; i++)
    {
        //float *host_data_1d = (float*)malloc(sizeof(float)*K);
        float *data_1d;
        cudaMalloc((void**)&data_1d,sizeof(float)*D);
        cudaMemcpy(data_1d,data[i],sizeof(float)*D,cudaMemcpyHostToDevice);
        host_data_2d[i] = data_1d;
    }
    cudaMalloc((void**)&data_2d,sizeof(float*)*N);
    cudaMemcpy(data_2d,host_data_2d,sizeof(float*)*N,cudaMemcpyHostToDevice);
    //将二维数组data传入GPU
    for(int i = 0;i < K; i++)
    {
        //float *host_data_1d = (float*)malloc(sizeof(float)*K);
        
        float *cc_1d;
        cudaMalloc((void**)&cc_1d,sizeof(float)*D);
        cudaMemcpy(cc_1d,cluster_center[i],sizeof(float)*D,cudaMemcpyHostToDevice);
        host_cc_2d[i] = cc_1d;
    }
    cudaMalloc((void**)&cc_2d,sizeof(float*)*K);
    cudaMemcpy(cc_2d,host_cc_2d,sizeof(float*)*K,cudaMemcpyHostToDevice);
    

    //float tmp=9999.0;
    //cudaMemcpyToSymbol(mi, &tmp, sizeof(float)); //在cuda中设置全局常量
    

    
    dim3 GridSize(N,1,1);
    dim3 BlockSize(K,1,1);
    
    clock_t start,end;//生成时间戳
    start = clock();

    ComputeDistance<<<GridSize,BlockSize>>>(distance,data_2d,cc_2d,D);
    cudaDeviceSynchronize();
    
    end = clock();
    
    float* dis = (float*)malloc(sizeof(float)*N*K);
    cudaMemcpy(dis,distance,sizeof(int)*N,cudaMemcpyDeviceToHost);
    
    
    FILE *fp2;
    if((fp2=fopen("result.txt","w"))==NULL) 
    {
		printf("File cannot be opened/n");
		exit(0);
	}
    
	for(int i=0;i<N;++i){
		float min=9999.0;
		for(int j=0;j<K;++j){
			dis[i*K+j] = getDistance(data[i],cluster_center[j],D);
			if(dis[i*K+j]<min){
				min=dis[i*K+j];
				in_cluster[i]=j;
			}
		}
		printf("data[%d] 属于类-%d\n",i,in_cluster[i]);
		fprintf(fp2,"%d \n",in_cluster[i]);//写入文件
	}
	printf("------------time=%fms-----------------\n",(double)(end-start)/1000);//CLK_TCK =1000
	cudaFree(distance);
    cudaFree(data_2d);
    cudaFree(cc_2d);
}
 
//计算所有聚类的中心点与其数据点的距离之和
float getDifference()
{
	int i,j;
	float sum=0.0;
	for(i=0;i<K;++i){
		for(j=0;j<N;++j){
			if(i==in_cluster[j])
				sum+=getDistance(data[j],cluster_center[i],D);
		}
	}
	return sum;
}
 
//计算每个聚类的中心点
void getCenter(int in_cluster[])
{
	float **sum=array(K,D);  //存放每个聚类中心点
	//float sum[K][D];  //也可使用C99变长数组
	int i,j,q,count;
	for(i=0;i<K;i++)
		for(j=0;j<D;j++)
			sum[i][j]=0.0;
	for(i=0;i<K;i++){
		count=0;  //统计属于某个聚类内的所有数据点
		for(j=0;j<N;j++){
			if(i==in_cluster[j]){
				for(q=0;q<D;q++)
					sum[i][q]+=data[j][q];  //计算所属聚类的所有数据点的相应维数之和
				count++;
			}
		}
		for(q=0;q<D;q++)
			cluster_center[i][q]=sum[i][q]/count;
	}
	printf("The new center of cluster is:\n");
	for(i = 0; i < K; i++)
		for(q=0;q<D;q++){
			printf("%-8.2f",cluster_center[i][q]);
			if((q+1)%D==0)    putchar('\n');
		}
		free(sum);
}
