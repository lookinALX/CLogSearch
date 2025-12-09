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
#include "common.h"
#include "parser.h"


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
    exit(EXIT_SUCCESS);
  }
  else
  {
    printf("Parent PID=%d\n", getppid());
  }

  log_parse_struct_t result = parse_log_file(inputs, start, end);
  print_result(result);

  munmap(shared_data, SHM_SIZE);
  shm_unlink(SHM_NAME);

  return EXIT_SUCCESS;
}
