#ifndef COMMON_H
#define COMMON_H

#define MAX_WORKERS 8

typedef struct inputs
{
  char* filepath;
  char* method_filter;
  int status_filter;
  int num_workers;
} inputs_t;

#endif
