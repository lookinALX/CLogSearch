#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h> 
#include "common.h"


static void check_argument_number(char argument_name, int argument)
{
  if (argument > 1)
  {
    fprintf(stderr, "ERROR: argument %c defined multiple times, only one is allowed\n", argument_name);
    exit(EXIT_FAILURE);
  } 
}


static void print_help_string(void)
{
    fprintf(stderr, "Usage: logsearch -f <logfile> [options]\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Required:\n");
    fprintf(stderr, "  -f <file>       Log file to search\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Optional:\n");
    fprintf(stderr, "  -w <number>     Number of worker processes (default: 1, max: 32)\n");
    fprintf(stderr, "  -p <method>     Filter by HTTP method (GET, POST, PUT, DELETE, etc.)\n");
    fprintf(stderr, "  -s <code>       Filter by HTTP status code (200, 404, 500, etc.)\n");
    //fprintf(stderr, "  --ip <address>  Filter by IP address\n");
    //fprintf(stderr, "  --count         Show statistics only, don't print lines\n");
    fprintf(stderr, "  -h, --help      Show this help message\n");
    fprintf(stderr, "\n");
    fprintf(stderr, "Examples:\n");
    fprintf(stderr, "  logsearch -f access.log\n");
    fprintf(stderr, "  logsearch -f access.log -w 4 -p GET\n");
    fprintf(stderr, "  logsearch -f access.log -w 8 -s 404\n");
    fprintf(stderr, "  logsearch -f access.log -p POST -s 200 --count\n");
}

inputs_t parse_inputs(int argc, char **argv)
{
  int arg = -1;
  int opt_f = 0;
  int opt_w = 0; 
  int opt_p = 0;
  int opt_s = 0;
  
  inputs_t inputs = {
    .filepath = NULL,
    .method_filter = NULL,
    .status_filter = -1,
    .num_workers = 1
  }; 

  if(argc == 1)
  {
    fprintf(stderr, "ERROR: No arguments to parse\n");
    exit(EXIT_FAILURE); 
  }

  while((arg = getopt(argc, argv, "f:w:p:s:h")) != -1)
  {
    switch(arg)
    {
      case 'f':
        opt_f++;
        check_argument_number('f', opt_f);
        inputs.filepath = optarg;
        break;
      case 'w':
        opt_w++;
        check_argument_number('w', opt_w);
        inputs.num_workers = atoi(optarg);
        if (inputs.num_workers > MAX_WORKERS)
        {
          fprintf(stderr, "ERROR: it is allowed maximum %d workers", MAX_WORKERS);
          exit(EXIT_FAILURE);
        }
        break;
      case 'p':
        opt_p++;
        check_argument_number('p', opt_p);
        inputs.method_filter = optarg;
        break;
      case 's':
        opt_s++;
        check_argument_number('s', opt_s);
        inputs.status_filter = atoi(optarg);
        break;
      case 'h':
        print_help_string();
        exit(EXIT_SUCCESS);
        break;
      case '?':
        fprintf(stderr, "ERROR: Invalid argument\n");
        exit(EXIT_FAILURE);
        break;
    }
  }

  return inputs;
}


void print_inputs(inputs_t inputs)
{
  printf("The following inputs were read:\n");
  printf("File path: %s\n", inputs.filepath);
  printf("Number of workers; %d\n", inputs.num_workers);
  if(inputs.method_filter != NULL) 
  {
    printf("Filter by HTTP method: %s\n", inputs.method_filter);
  }
  else 
  {
    printf("No filter by HTTP method\n");
  }
  if(inputs.status_filter != -1)
  {
    printf("Filter by HTTP status: %d\n", inputs.status_filter);
  }
  else
  {
    printf("No HTTP status filter\n");
  }
}

