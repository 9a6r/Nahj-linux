/* Diagnostic interposer only; never packaged in the ISO. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <string.h>
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t); return t.tv_sec+t.tv_nsec/1e9; }
static void record(const char *kind, const char *name, double value) {
 static int fd=-1; char line[512];
 if(fd<0) fd=open("/build/plymouth-cadence.tsv",O_WRONLY|O_CREAT|O_APPEND,0644);
 int n=snprintf(line,sizeof line,"%.9f\t%s\t%s\t%.9f\n",now(),kind,name,value);
 if(fd>=0 && n>0 && n<(int)sizeof line) (void)write(fd,line,n);
}
FILE *fopen64(const char *path,const char *mode) {
 static FILE *(*original)(const char*,const char*);
 if(!original) original=dlsym(RTLD_NEXT,"fopen64");
 if(strstr(path,"/themes/nahj/") && strstr(path,".png")) record("open",strrchr(path,'/')+1,0);
 return original(path,mode);
}
