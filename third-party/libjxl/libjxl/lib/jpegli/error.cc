// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jpegli/error.h"

#include <setjmp.h>
#include <stdlib.h>
#include <string.h>

#include <string>

#include "lib/jpegli/common.h"

namespace jpegli {

const char* const kErrorMessageTable[] = {
    "Message codes are not supported, error message is in msg_parm.s string",
};

bool FormatString(char* buffer, const char* format, ...) {
  va_list args;
  va_start(args, format);
  vsnprintf(buffer, JMSG_STR_PARM_MAX, format, args);
  va_end(args);
  return false;
}

void ExitWithAbort(j_common_ptr cinfo) {
  (*cinfo->err->output_message)(cinfo);
  jpegli_destroy(cinfo);
  exit(EXIT_FAILURE);
}

void EmitMessage(j_common_ptr cinfo, int msg_level) {
  if (msg_level < 0) {
    if (cinfo->err->num_warnings <= 5 || cinfo->err->trace_level >= 3) {
      (*cinfo->err->output_message)(cinfo);
    }
    ++cinfo->err->num_warnings;
  } else if (cinfo->err->trace_level >= msg_level) {
    (*cinfo->err->output_message)(cinfo);
  }
}

void OutputMessage(j_common_ptr cinfo) {
  char buffer[JMSG_LENGTH_MAX];
  (*cinfo->err->format_message)(cinfo, buffer);
  fprintf(stderr, "%s\n", buffer);
}

void FormatMessage(j_common_ptr cinfo, char* buffer) {
  jpeg_error_mgr* err = cinfo->err;
  int code = err->msg_code;
  if (code == 0) {
    memcpy(buffer, cinfo->err->msg_parm.s, JMSG_STR_PARM_MAX);
  } else if (err->addon_message_table != nullptr &&
             code >= err->first_addon_message &&
             code <= err->last_addon_message) {
    std::string msg(err->addon_message_table[code - err->first_addon_message]);
    if (msg.find("%s") != std::string::npos) {
      snprintf(buffer, JMSG_LENGTH_MAX, msg.data(), err->msg_parm.s);
    } else {
      snprintf(buffer, JMSG_LENGTH_MAX, msg.data(), err->msg_parm.i[0],
               err->msg_parm.i[1], err->msg_parm.i[2], err->msg_parm.i[3],
               err->msg_parm.i[4], err->msg_parm.i[5], err->msg_parm.i[6],
               err->msg_parm.i[7]);
    }
  } else {
    snprintf(buffer, JMSG_LENGTH_MAX, "%s", kErrorMessageTable[0]);
  }
}

void ResetErrorManager(j_common_ptr cinfo) {
  memset(cinfo->err->msg_parm.s, 0, JMSG_STR_PARM_MAX);
  cinfo->err->msg_code = 0;
  cinfo->err->num_warnings = 0;
}

}  // namespace jpegli

struct jpeg_error_mgr* jpegli_std_error(struct jpeg_error_mgr* err) {
  err->error_exit = jpegli::ExitWithAbort;
  err->emit_message = jpegli::EmitMessage;
  err->output_message = jpegli::OutputMessage;
  err->format_message = jpegli::FormatMessage;
  err->reset_error_mgr = jpegli::ResetErrorManager;
  memset(err->msg_parm.s, 0, JMSG_STR_PARM_MAX);
  err->trace_level = 0;
  err->num_warnings = 0;
  // We don't support message codes and message table, but we define one here
  // in case the application has a custom format_message and tries to access
  // these fields there.
  err->msg_code = 0;
  err->jpeg_message_table = jpegli::kErrorMessageTable;
  err->last_jpeg_message = 0;
  err->addon_message_table = nullptr;
  err->first_addon_message = 0;
  err->last_addon_message = 0;
  return err;
}
