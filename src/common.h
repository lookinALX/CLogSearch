#include <stdio.h>

#ifndef COMMON_H
#define COMMON_H

#define MAX_WORKERS 8
#define SHM_NAME "clogsearch_shm"
#define SHM_SIZE sizeof(shared_data_t)
#define SHARED_DATA_BUFFER_SIZE 64

#define SEM_FREE "clogsearch_sem_free"
#define SEM_USED "clogsearch_sem_used"
#define SEM_MUTEX "clogsearch_sem_mutex"

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

typedef struct shared_data
{
  log_parse_struct_t lines[SHARED_DATA_BUFFER_SIZE];
  int write_pos;
  int read_pos;
  volatile sig_atomic_t terminate;
} shared_data_t;

#endif
