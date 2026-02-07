#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main(int argc,char*argv[])
{
  FILE *fd;
  int i, n;
  char ch;
  double d;
  long l;
  
  fd = fopen("test.txt", "wb");
  if (NULL == fd) {
    fprintf(stderr,"cannot write test.txt");
    exit(1);
  }
  for (i = 0; i < 256; i++) {
    fputc (i, fd);
  }
  fclose(fd);
  fd = fopen("test.txt","rb");
  if (NULL == fd) {
    fprintf(stderr,"cannot write test.txt");
    exit(1);
  }
  for (i = 0; i < 256; i++) {
    n = fgetc(fd); ch = n;
    printf(" %d %d", ch, n);
  }
  fclose(fd);
  printf("\n");

  if (argc > 1) {
    d = atof(argv[1]);
    l = ((long)floor(d));
    printf ("d=%ld\n", l);
  }
  return 0;
}
