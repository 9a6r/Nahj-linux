#include <ply-image.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
static double now(clockid_t clock) {struct timespec t; clock_gettime(clock,&t); return t.tv_sec+t.tv_nsec/1e9;}
int main(int argc,char **argv) {
 if(argc!=3) return 2;
 puts("round,frame,format,wall_ms,cpu_ms");
 for(int round=0;round<3;round++) for(int n=0;n<240;n++) {
  const char *phase=n<132?"intro":"loop"; int frame=n<132?n:n-132;
  ply_image_t *images[2];
  for(int order=0;order<2;order++) {
   int f=(order+round)%2; char path[4096]; const char *ext=f?"bmp":"png";
   snprintf(path,sizeof path,"%s/%s-%d.%s",argv[f+1],phase,frame,ext);
   double t=now(CLOCK_MONOTONIC),c=now(CLOCK_PROCESS_CPUTIME_ID);
   images[f]=ply_image_new(path);
   if(!ply_image_load(images[f])) {fprintf(stderr,"Cannot load %s\n",path);return 3;}
   printf("%d,%s-%d,%s,%.6f,%.6f\n",round,phase,frame,ext,1000*(now(CLOCK_MONOTONIC)-t),1000*(now(CLOCK_PROCESS_CPUTIME_ID)-c));
  }
  if(ply_image_get_width(images[0])!=1280 || ply_image_get_height(images[0])!=720 || ply_image_get_width(images[1])!=1280 || ply_image_get_height(images[1])!=720 || memcmp(ply_image_get_data(images[0]),ply_image_get_data(images[1]),1280*720*4)) {fprintf(stderr,"Decoded pixel mismatch %s-%d\n",phase,frame);return 4;}
  ply_image_free(images[0]);ply_image_free(images[1]);
 }
 return 0;
}
