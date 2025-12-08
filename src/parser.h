#include "common.h"

inputs_t parse_inputs(int argc, char **argv);

void print_inputs(inputs_t inputs);

log_parse_struct_t parse_log_file(inputs_t inputs);

int filter_line(char* target, char* method, char* status);
