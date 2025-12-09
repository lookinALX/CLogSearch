#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>
#include <signal.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <semaphore.h>
#include <sys/stat.h>
#include <string.h>
#include "common.h"
#include "parser.h"


volatile sig_atomic_t should_terminate = 0;


void signal_handler(int sig)
{
  (void)sig;
  should_terminate = 1;
}


static void print_result(log_parse_struct_t log)
{
  printf("Parsing is finisched\nLines found: %d\n", log.lines_num);
  printf("#####################################################\n");
  printf("LINES: \n");
  for(int i = 0; i < log.lines_num; i++)
  {
    printf("%s\n", log.lines[i]);
  }
}


static off_t get_file_size(char* filename)
{
  struct stat st;
  if(stat(filename, &st) == -1)
  {
    fprintf(stderr, "ERROR: cannot get file stats\n");
  }
  return st.st_size;
}


static void combine_results(log_parse_struct_t* result, log_parse_struct_t* tmp_result)
{
  if (result->lines == NULL)
  {
    result->lines = malloc(tmp_result->lines_num * sizeof(char *));
    result->lines_num = 0; 
  }
  else 
  {
    result->lines = realloc(result->lines, (result->lines_num + tmp_result->lines_num) * sizeof(char *));
  }
  
  if (result->lines == NULL)
  {
    fprintf(stderr, "ERROR: mamory allocation is not possible\n");
    exit(EXIT_FAILURE);
  }
  
  for (int j = 0; j < tmp_result->lines_num; j++)
  {
    int i = result->lines_num + j;

    result->lines[i] = malloc(strlen(tmp_result->lines[j]) + 1);  
    if (result->lines[i] == NULL)
    {
      fprintf(stderr, "ERROR: cannot allocate for string\n");
      exit(EXIT_FAILURE);
    }
    strcpy(result->lines[i], tmp_result->lines[j]);
  }

  result->lines_num += tmp_result->lines_num;
}


int main(int argc, char **argv)
{  
  inputs_t inputs = parse_inputs(argc, argv);
  print_inputs(inputs);

  pid_t pid; 
  
  int shm_fd = shm_open(SHM_NAME, O_CREAT | O_RDWR, 0666);
  if (shm_fd < 0)
  {
    fprintf(stderr, "ERROR: cannot create shared memory object\n");
    return EXIT_FAILURE;
  }
  
  if(ftruncate(shm_fd, SHM_SIZE) < 0)
  {
    printf("ERROR: cannot set shared memory size\n");
    return EXIT_FAILURE;
  }

  shared_data_t* shared_data = mmap(NULL, SHM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);

  if (shared_data == MAP_FAILED)
  {
    printf("ERROR: cannot map shared memory in CPU adress space\n");
    return EXIT_FAILURE;   
  }

  shared_data->write_pos = 0;
  shared_data->read_pos = 0;
  shared_data->terminate = 0;

  sem_t* free_space = sem_open(SEM_FREE, O_CREAT | O_EXCL, 0666, SHARED_DATA_BUFFER_SIZE);
  if (free_space == SEM_FAILED)
  {
    if (errno == EEXIST)
    {
      sem_unlink(SEM_FREE);
      free_space = sem_open(SEM_FREE, O_CREAT | O_EXCL, 0666, SHARED_DATA_BUFFER_SIZE);
    }
    if (free_space == SEM_FAILED)
    {
      fprintf(stderr, "ERROR: sem_open free_space\n");
      return EXIT_FAILURE;
    }
  }

  sem_t* used_space = sem_open(SEM_USED,  O_CREAT | O_EXCL, 0666, 0);
  if (used_space == SEM_FAILED)
  {
    if (errno == EEXIST)
    {
      sem_unlink(SEM_USED);
      used_space = sem_open(SEM_USED, O_CREAT | O_EXCL, 0666, 0);
    }
    if (used_space == SEM_FAILED)
    {
      fprintf(stderr, "ERROR: sem_open free_space\n");
      return EXIT_FAILURE;
    }
  }

  sem_t* write_mutex = sem_open(SEM_MUTEX, O_CREAT | O_EXCL, 0666, 1);
  if (write_mutex == SEM_FAILED) 
  {
    if (errno == EEXIST) 
    {
      sem_unlink(SEM_MUTEX);
      write_mutex = sem_open(SEM_MUTEX, O_CREAT | O_EXCL, 0666, 1);
    }
    if (write_mutex == SEM_FAILED) 
    {
      printf("ERROR: sem_open write_mutex\n");
      return EXIT_FAILURE;
    }
  }
  
  
  off_t start;
  off_t end;
  off_t file_size = get_file_size(inputs.log_filepath);
  off_t chunk_size = file_size/inputs.num_workers;

  signal(SIGINT, signal_handler);
  signal(SIGTERM, signal_handler);

  for(int i = 0; i < inputs.num_workers; i++)
  {  
    start = i * chunk_size;
    if (i == inputs.num_workers - 1 ) {end = file_size;}
    else {end = (i + 1) * chunk_size;}
    pid = fork();
    if (pid == 0) break;
  }
  
  if (pid == 0) 
  {
    printf("Child PID=%d, parent=%d\n", getpid(), getppid());
    printf("My range: start=%ld, end=%ld\n", start, end);
    log_parse_struct_t result = parse_log_file(inputs, start, end);
    
    if (shared_data->terminate) exit(EXIT_SUCCESS);
    
    if(sem_wait(free_space) < 0)
    {
      fprintf(stderr, "ERROR: sem_trywait\n");
    }
    
    if (shared_data->terminate) exit(EXIT_SUCCESS);
    
    if(sem_wait(write_mutex) < 0)
    {
      fprintf(stderr, "ERROR: sem_trywait\n");
    }

    if (shared_data->terminate) exit(EXIT_SUCCESS);
    
    int wp = shared_data->write_pos;
    
    shared_data->lines[wp].lines_num = result.lines_num;
    shared_data->lines[wp].lines = malloc(result.lines_num * sizeof(char*));
    
    if (!shared_data->lines[wp].lines) 
    {
      fprintf(stderr, "ERROR: malloc in shm deep copy\n");
      exit(EXIT_FAILURE);
    }

    for (int i = 0; i < result.lines_num; i++) 
    {
      size_t len = strlen(result.lines[i]) + 1;
      shared_data->lines[wp].lines[i] = malloc(len);
      if (!shared_data->lines[wp].lines[i]) 
      {
        fprintf(stderr, "ERROR: malloc in shm deep copy\n");
        exit(EXIT_FAILURE);
      }
      memcpy(shared_data->lines[wp].lines[i], result.lines[i], len);
    }

    shared_data->write_pos = (shared_data->write_pos + 1) % SHARED_DATA_BUFFER_SIZE;

    sem_post(write_mutex);
    sem_post(used_space);

    exit(EXIT_SUCCESS);
  }
  else
  {
    printf("Parent PID=%d\n", getppid());
    int results_read = 0;
    
    log_parse_struct_t result = {
    .lines = NULL,
    .lines_num = 0
    };

    while(!should_terminate && (results_read < inputs.num_workers))
    {

      if (sem_wait(used_space) < 0)
      {
        fprintf(stderr, "ERROR: sem_trywait\n");
      }
      
      if (should_terminate) break;

      log_parse_struct_t tmp_result = shared_data->lines[shared_data->read_pos];
      shared_data->read_pos = (shared_data->read_pos+1) % SHARED_DATA_BUFFER_SIZE;
      
      combine_results(&result, &tmp_result);

      sem_post(free_space);
      results_read++;
    }

    sem_wait(write_mutex);
    shared_data->terminate = 1;
    sem_post(write_mutex);
    
    sem_close(free_space);
    sem_close(used_space);
    sem_close(write_mutex);

    sem_unlink(SEM_FREE);
    sem_unlink(SEM_USED);
    sem_unlink(SEM_MUTEX);

    munmap(shared_data, SHM_SIZE);
    shm_unlink(SHM_NAME);
    
    print_result(result);
  }

  return EXIT_SUCCESS;
}

