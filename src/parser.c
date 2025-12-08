#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include "common.h"
#include "parser.h"


static void check_argument_number(char argument_name, int argument)
{
  if (argument > 1)
  {
    fprintf(stderr, "ERROR: argument %c defined multiple times, only one is allowed\n", argument_name);
    exit(EXIT_FAILURE);
  } 
}

static int is_number(const char* s)
{
  if(*s == '\0') return 0;
  while (*s) 
  {
    if (!isdigit((unsigned char)*s)) return 0;
    s++;
  }
  return 1;
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
    .log_file = NULL,
    .log_filepath = NULL,
    .method_filter = NULL,
    .status_filter = NULL,
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
        inputs.log_file = fopen(optarg, "r");
        if (inputs.log_file == NULL)
        {
          fprintf(stderr, "fopen failed: %s\n", strerror(errno));
          exit(EXIT_FAILURE);
        }
        inputs.log_filepath = optarg;
        break;
      case 'w':
        opt_w++;
        check_argument_number('w', opt_w);
        inputs.num_workers = atoi(optarg);
        if (inputs.num_workers > MAX_WORKERS)
        {
          fprintf(stderr, "ERROR: it is allowed maximum %d workers\n", MAX_WORKERS);
          exit(EXIT_FAILURE);
        }
        if (inputs.num_workers < 1) 
        {
          fprintf(stderr, "ERROR: invalid number of workers\n");
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
        if (is_number(optarg))
        {
          inputs.status_filter = optarg;
        }
        else
        {
          fprintf(stderr, "ERROR: status is not a number\n");
        }
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
  printf("File path: %s\n", inputs.log_filepath);
  printf("Number of workers: %d\n", inputs.num_workers);
  if(inputs.method_filter != NULL) 
  {
    printf("Filter by HTTP method: %s\n", inputs.method_filter);
  }
  else 
  {
    printf("No filter by HTTP method\n");
  }
  if(inputs.status_filter != NULL)
  {
    printf("Filter by HTTP status: %s\n", inputs.status_filter);
  }
  else
  {
    printf("No HTTP status filter\n");
  }
}


log_parse_struct_t parse_log_file(inputs_t inputs)
{
  char* method = inputs.method_filter;
  char* status = inputs.status_filter;

  int need_to_filter = (method != NULL || status != NULL);

  FILE* stream = inputs.log_file;
  
  int result_lines_cap = 20;
  log_parse_struct_t result = {
    .lines = malloc(result_lines_cap*sizeof(char *)),
    .lines_num = 0
  };
  
  if(result.lines == NULL)
  {
    fprintf(stderr, "ERROR: mamory allocation is not possible\n");
    exit(EXIT_FAILURE);
  }

  char* buffer = NULL;
  size_t buffer_cap = 0;
  ssize_t read_len_str;
   
  int i = 0;

  while ((read_len_str = getline(&buffer, &buffer_cap, stream)) != -1 )
  {
    int passed = 0;
    
    if (need_to_filter)
    {
      passed = filter_line(buffer, method, status);
    }
    
    if (need_to_filter == 0 || passed)
    {
      if (i >= result_lines_cap) 
      {
        result_lines_cap *= 2;
        result.lines = realloc(result.lines, result_lines_cap*sizeof(char *));
        if (result.lines == NULL)
        {
          fprintf(stderr, "ERROR: mamory allocation is not possible\n");
          exit(EXIT_FAILURE);
        }
      }
      *(result.lines + i) = malloc((read_len_str+1)*sizeof(char));
      if (*(result.lines) == NULL)
      {
        fprintf(stderr, "ERROR: mamory allocation is not possible\n");
        exit(EXIT_FAILURE);
      }
      strcpy(result.lines[i++], buffer);
    }
  }
  
  result.lines_num = i;

  free(buffer);
  fclose(stream);

  return result;
}


int filter_line(char* target, char* method, char* status)
{
  if (target == NULL) return 0;

  if (method != NULL && strstr(target, method) == NULL) 
  {
    return 0;
  }
  if (status != NULL && strstr(target, status) == NULL) 
  {
    return 0;
  }
  
  return 1;
}

