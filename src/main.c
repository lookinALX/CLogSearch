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
  log_parse_struct_t result = parse_log_file(inputs);
  print_result(result);
  return 0;
}
