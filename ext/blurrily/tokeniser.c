#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>
#include "tokeniser.h"
#include "blurrily.h"


/******************************************************************************/

static int ipow(int a, int b)
{
  int result = 1;
  
  while (b-- > 0) result = result * a;
  return result;
}

/******************************************************************************/

static void string_to_code(const char* input, trigram_t *output)
{
  trigram_t result = 0;

  for (int k = 0 ; k < 3; ++k) {
    if (input[k] == '*' || input[k] < 'a' || input[k] > 'z') continue;
    result += ipow(TRIGRAM_BASE, k) * (input[k] - 'a' + 1);
  }

  *output = result;
}

/******************************************************************************/

static void code_to_string(trigram_t input, char* output)
{
  for (int k = 0 ; k < 3; ++k) {
    uint16_t elem = input / ipow(TRIGRAM_BASE, k) % TRIGRAM_BASE;
    if (elem == 0) {
      output[k] = '*';
    } else {
      output[k] = ('a' + elem - 1);
    }
  }
  output[3] = 0;
}

/******************************************************************************/

static int blurrily_compare_trigrams(const void* left_p, const void* right_p)
{
  trigram_t* left  = (trigram_t*)left_p;
  trigram_t* right = (trigram_t*)right_p;
  return (int)*left - (int)*right;
}

/******************************************************************************/

int blurrily_tokeniser_parse_string(const char* input, trigram_t* output)
{
  size_t length     = strlen(input);
  char*  normalized = (char*) malloc(length+5);
  size_t duplicates = 0;

  snprintf(normalized, length+4, "**%s*", input);

  /* replace spaces with '*' */
  for (size_t k = 0; k < length+3; ++k) {
    if (normalized[k] == ' ') normalized[k] = '*';
  }

  /* compute trigrams */
  for (size_t k = 0; k <= length; ++k) {
    string_to_code(normalized+k, output+k);
  }

  /* print results */
  LOG("-- normalization\n");
  LOG("%s -> %s\n", input, normalized);
  LOG("-- tokenisation\n");
  for (size_t k = 0; k <= length; ++k) {
    char res[4];

    code_to_string(output[k], res);

    LOG("%c%c%c -> %d -> %s\n",
      normalized[k], normalized[k+1], normalized[k+2],
      output[k], res
    );
  }

  /* sort */
  qsort((void*)output, length+1, sizeof(trigram_t), &blurrily_compare_trigrams);

  /* remove duplicates */
  for (size_t k = 1; k <= length; ++k) {
    trigram_t* previous = output + k - 1;
    trigram_t* current  = output + k;

    if (*previous == *current) {
      *previous = 32768;
      ++duplicates;
    }
  }

  /* compact */
  qsort((void*)output, length+1, sizeof(trigram_t), &blurrily_compare_trigrams);

  /* print again */
  LOG("-- after sort/compact\n");
  for (size_t k = 0; k <= length-duplicates; ++k) {
    char res[4];
    code_to_string(output[k], res);
    LOG("%d -> %s\n", output[k], res);
  }

  free((void*)normalized);
  return (int) (length + 1 - duplicates);
}

/******************************************************************************/

int blurrily_tokeniser_trigram(trigram_t UNUSED(input), char* UNUSED(output))
{
  return 0;
}
