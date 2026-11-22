#ifndef COPUS_HELPERS_H
#define COPUS_HELPERS_H

#include <opus.h>

/* Non-variadic wrappers around opus_encoder_ctl, which is C-variadic and thus
   not callable from Swift. Each returns the underlying ctl status (OPUS_OK on
   success). */
int copus_set_bitrate(OpusEncoder *st, opus_int32 bitrate);
int copus_set_vbr(OpusEncoder *st, int onoff);
int copus_set_complexity(OpusEncoder *st, opus_int32 complexity);
int copus_set_signal(OpusEncoder *st, opus_int32 signal);

#endif
