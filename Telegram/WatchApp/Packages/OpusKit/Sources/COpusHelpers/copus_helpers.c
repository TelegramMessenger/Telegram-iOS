#include "copus_helpers.h"

int copus_set_bitrate(OpusEncoder *st, opus_int32 bitrate) {
    return opus_encoder_ctl(st, OPUS_SET_BITRATE_REQUEST, bitrate);
}

int copus_set_vbr(OpusEncoder *st, int onoff) {
    return opus_encoder_ctl(st, OPUS_SET_VBR_REQUEST, onoff);
}

int copus_set_complexity(OpusEncoder *st, opus_int32 complexity) {
    return opus_encoder_ctl(st, OPUS_SET_COMPLEXITY_REQUEST, complexity);
}

int copus_set_signal(OpusEncoder *st, opus_int32 signal) {
    return opus_encoder_ctl(st, OPUS_SET_SIGNAL_REQUEST, signal);
}
