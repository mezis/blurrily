#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include "tokeniser.h"

#define BASE 28

#define DEBUG 0

#if DEBUG
#define LOG(...) fprintf(__VA_ARGS__)
#else
#define LOG(...)
#endif

static int ipow(int a, int b)
{
  int result = 1;
  
  while (b-- > 0) result = result * a;
  return result;
}

static void string_to_code(char* input, trigram_t *output)
{
  trigram_t result = 0;

  for (int k = 0 ; k < 3; ++k) {
    if (input[k] == '*') continue;
    result += ipow(BASE, k) * (input[k] - 'a' + 1);
  }

  *output = result;
}

static void code_to_string(trigram_t input, char* output)
{
  for (int k = 0 ; k < 3; ++k) {
    uint16_t elem = input / ipow(BASE, k) % BASE;
    if (elem == 0) {
      output[k] = '*';
    } else {
      output[k] = ('a' + elem - 1);
    }
  }
  output[3] = 0;
}

static int blurrily_compare_trigrams(const void* left_p, const void* right_p)
{
  trigram_t* left  = (trigram_t*)left_p;
  trigram_t* right = (trigram_t*)right_p;
  return (int)*left - (int)*right;
}

int blurrily_tokeniser_parse_string(char* input, trigram_t* output)
{
  int   length     = strlen(input);
  char* normalized = (char*) malloc(length+5);
  int   duplicates = 0;

  snprintf(normalized, length+4, "**%s*", input);

  // replace spaces with '*'
  for (int k = 0; k < length+3; ++k) {
    if (normalized[k] == ' ') normalized[k] = '*';
  }

  // compute trigrams
  for (int k = 0; k <= length; ++k) {
    string_to_code(normalized+k, output+k);
  }

  // print results
  LOG(stderr, "-- normalization\n");
  LOG(stderr, "%s -> %s\n", input, normalized);
  LOG(stderr, "-- tokenisation\n");
  for (int k = 0; k <= length; ++k) {
    char res[4];

    code_to_string(output[k], res);

    LOG(stderr,
      "%c%c%c -> %d -> %s\n",
      normalized[k], normalized[k+1], normalized[k+2],
      output[k], res
    );
  }

  // sort
  qsort((void*)output, length+1, sizeof(trigram_t), &blurrily_compare_trigrams);

  // remove duplicates
  for (int k = 1; k <= length; ++k) {
    trigram_t* previous = output + k - 1;
    trigram_t* current  = output + k;

    if (*previous == *current) {
      *previous = 32768;
      ++duplicates;
    }
  }

  // compact
  qsort((void*)output, length+1, sizeof(trigram_t), &blurrily_compare_trigrams);

  // print again
  LOG(stderr, "-- after sort/compact\n");
  for (int k = 0; k <= length-duplicates; ++k) {
    char res[4];
    code_to_string(output[k], res);
    LOG(stderr, "%d -> %s\n", output[k], res);
  }

  free((void*)normalized);
  return length+1 - duplicates;
}

int blurrily_tokeniser_trigram(trigram_t input, char* output)
{
  return 0;
}
