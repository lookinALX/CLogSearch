#include <stdio.h>

#ifndef COMMON_H
#define COMMON_H

#define MAX_WORKERS 8

typedef struct inputs
{
  FILE* log_file;
  char* log_filepath;
  char* method_filter;
  char* status_filter;
  int num_workers;
} inputs_t;

typedef struct log_parse_struct
{
  char** lines;
  int lines_num;
} log_parse_struct_t;

#endif
