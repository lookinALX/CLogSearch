#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include "common.h"
#include "parser.h"

int main(int argc, char **argv)
{   
  inputs_t inputs = parse_inputs(argc, argv);
  print_inputs(inputs);
  return 0;
}
