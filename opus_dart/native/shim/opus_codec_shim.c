/*
 * Fixed-signature CTL bridge, compiled into the opus_codec code asset.
 *
 * opus_encoder_ctl is variadic, which Dart FFI cannot call portably, so this
 * wrapper takes a single int value and forwards it.
 *
 * Only integer-valued setter requests are accepted. Getter requests write
 * their result through a pointer, so handing them an int would corrupt memory;
 * they are rejected with OPUS_BAD_ARG instead.
 */

#include <stddef.h>

#include "opus_codec_shim.h"

OPUS_EXPORT int opus_codec_encoder_ctl_int(OpusEncoder *st, int request,
                                           int value) {
  if (st == NULL) return OPUS_BAD_ARG;

  switch (request) {
    case OPUS_SET_APPLICATION_REQUEST:
    case OPUS_SET_BITRATE_REQUEST:
    case OPUS_SET_MAX_BANDWIDTH_REQUEST:
    case OPUS_SET_VBR_REQUEST:
    case OPUS_SET_BANDWIDTH_REQUEST:
    case OPUS_SET_COMPLEXITY_REQUEST:
    case OPUS_SET_INBAND_FEC_REQUEST:
    case OPUS_SET_PACKET_LOSS_PERC_REQUEST:
    case OPUS_SET_DTX_REQUEST:
    case OPUS_SET_VBR_CONSTRAINT_REQUEST:
    case OPUS_SET_FORCE_CHANNELS_REQUEST:
    case OPUS_SET_SIGNAL_REQUEST:
    case OPUS_SET_GAIN_REQUEST:
    case OPUS_SET_LSB_DEPTH_REQUEST:
    case OPUS_SET_EXPERT_FRAME_DURATION_REQUEST:
    case OPUS_SET_PREDICTION_DISABLED_REQUEST:
    case OPUS_SET_PHASE_INVERSION_DISABLED_REQUEST:
      return opus_encoder_ctl(st, request, value);
    default:
      return OPUS_BAD_ARG;
  }
}
