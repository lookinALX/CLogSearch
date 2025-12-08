#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include "common.h"
#include "parser.h"


void print_result(log_parse_struct_t log)
{
  printf("Parsing is finisched\nLines found: %d\n", log.lines_num);
  printf("#####################################################\n");
  printf("LINES: \n");
  for(int i = 0; i < log.lines_num; i++)
  {
    printf("%s\n", log.lines[i]);
  }
}


int main(int argc, char **argv)
{  
  inputs_t inputs = parse_inputs(argc, argv);
  print_inputs(inputs);
  
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
  if (used_space == SEM_USED)
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
      write_mutex = sem_open(SEM_MUTEX, O_CREAT | O_EXCL, 0666, 1;
    }
    if (write_mutex == SEM_FAILED) 
    {
      printf("ERROR: sem_open write_mutex\n");
      return EXIT_FAILURE;
    }
  }


  log_parse_struct_t result = parse_log_file(inputs);
  print_result(result);

  munmap(shared_data, SHM_SIZE);
  shm_unlink(SHM_NAME);

  return EXIT_SUCCESS;
}
