#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
 
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
 
//把N个数据点聚类，标出每个点属于哪个聚类
void cluster()
{
	int i,j;
	float min;
	float **distance=array(N,K);  //存放每个数据点到每个中心点的距离
	//float distance[N][K];  //也可使用C99变长数组
	FILE *fp2;
	if((fp2=fopen("result.txt","w"))==NULL) {
		printf("File cannot be opened/n");
		exit(0);
	}
    
    clock_t start,end;//生成时间戳
    start = clock();
    
	for(i=0;i<N;++i){
		min=9999.0;
		for(j=0;j<K;++j){
			distance[i][j] = getDistance(data[i],cluster_center[j],D);
			if(distance[i][j]<min){
				min=distance[i][j];
				in_cluster[i]=j;
			}
		}
		printf("data[%d] 属于类-%d\n",i,in_cluster[i]);
		fprintf(fp2,"%d \n",in_cluster[i]);//写入文件
	}
    end = clock();
	printf("------------time=%fms-----------------\n",(double)(end-start)/1000);//CLK_TCK =1000
	free(distance);
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
