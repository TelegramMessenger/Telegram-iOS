/*
    This file is part of tl-parser

    tl-parser is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    tl-parser is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this tl-parser. If not, see <http://www.gnu.org/licenses/>.

    Copyright Vitaly Valtman 2014

    It is derivative work of VK/KittenPHP-DB-Engine (https://github.com/vk-com/kphp-kdb/)
    Copyright 2012-2013 Vkontakte Ltd
              2012-2013 Vitaliy Valtman

*/

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "tl-parser.h"

#ifndef _WIN32
#include <unistd.h>
#endif

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <signal.h>

#ifdef HAVE_EXECINFO_H
#include <execinfo.h>
#endif
#include <stdarg.h>

int verbosity;
int output_expressions;
void usage (void) {
  printf ("usage: tl-parser [-v] [-h] <TL-schema-file>\n"
      "\tTL compiler\n"
      "\t-v\toutput statistical and debug information into stderr\n"
      "\t-E\twhenever is possible output to stdout expressions\n"
      "\t-e <file>\texport serialized schema to file\n"
       );
  exit (2);
}

int vkext_write (const char *filename) {
  FILE *f = fopen(filename, "wb");
  assert (f != NULL);
  write_types (f);
  fclose (f);
  return 0;
}

void logprintf (const char *format, ...) __attribute__ ((format (printf, 1, 2)));
void logprintf (const char *format __attribute__ ((unused)), ...) {
  va_list ap;
  va_start (ap, format);
  vfprintf (stderr, format, ap);
  va_end (ap);
}

void hexdump (int *in_ptr, int *in_end) {
  int *ptr = in_ptr;
  while (ptr < in_end) { printf (" %08x", *(ptr ++)); }
  printf ("\n");
}

#ifdef HAVE_EXECINFO_H
void print_backtrace (void) {
  void *buffer[255];
  const int calls = backtrace (buffer, sizeof (buffer) / sizeof (void *));
  backtrace_symbols_fd (buffer, calls, 1);
}
#else
void print_backtrace (void) {
  if (fwrite ("No libexec. Backtrace disabled\n", 32, 1, stderr) != 1) {
    // Sad thing
  }
}
#endif

void sig_segv_handler (int signum __attribute__ ((unused))) {
  if (fwrite ("SIGSEGV received\n", 18, 1, stderr) != 1) {
    // Sad thing
  }
  print_backtrace ();
  exit (EXIT_FAILURE);
}

void sig_abrt_handler (int signum __attribute__ ((unused))) {
  if (fwrite ("SIGABRT received\n", 18, 1, stderr) != 1) {
    // Sad thing
  }
  print_backtrace ();
  exit (EXIT_FAILURE);
}

int main (int argc, char **argv) {
  signal (SIGSEGV, sig_segv_handler);
  signal (SIGABRT, sig_abrt_handler);
  int i;
  char *vkext_file = 0;
  while ((i = getopt (argc, argv, "Ehve:w:")) != -1) {
    switch (i) {
    case 'E':
      output_expressions++;
      break;
    case 'h':
      usage ();
      return 2;
    case 'e':
      vkext_file = optarg;
      break;
    case 'v':
      verbosity++;
      break;
    }
  }

  if (argc != optind + 1) {
    usage ();
  }
 

  struct parse *P = tl_init_parse_file (argv[optind]);
  if (!P) {
    return 1;
  }
  struct tree *T;
  if (!(T = tl_parse_lex (P))) {
    fprintf (stderr, "Error in parse:\n");
    tl_print_parse_error ();
    return 1;
  } else {
    if (verbosity) {
      fprintf (stderr, "Parse ok\n");
    }
    if (!tl_parse (T)) {
      if (verbosity) {
        fprintf (stderr, "Fail\n");
      }
      return 1;
    } else {
      if (verbosity) {
        fprintf (stderr, "Ok\n");
      }
    }
  }
  if (vkext_file) {
    vkext_write (vkext_file);
  }
  return 0;
}
