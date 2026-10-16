#ifndef OPUS_CODEC_SHIM_H
#define OPUS_CODEC_SHIM_H

#include "opus.h"

/* Forwards an integer-valued setter to opus_encoder_ctl. Returns
 * OPUS_BAD_ARG for a NULL encoder or any other request. */
OPUS_EXPORT int opus_codec_encoder_ctl_int(OpusEncoder *st, int request,
                                           int value);

#endif
