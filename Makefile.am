AUTOMAKE_OPTIONS = foreign

CFLAGS = -Wall -DHAVE_CONFIG_H -Wno-unknown-pragmas

lib_LTLIBRARIES = libtgvoip.la

SRC = VoIPController.cpp \
Buffers.cpp \
CongestionControl.cpp \
EchoCanceller.cpp \
JitterBuffer.cpp \
logging.cpp \
MediaStreamItf.cpp \
MessageThread.cpp \
NetworkSocket.cpp \
OpusDecoder.cpp \
OpusEncoder.cpp \
PacketReassembler.cpp \
VoIPGroupController.cpp \
VoIPServerConfig.cpp \
audio/AudioIO.cpp \
audio/AudioInput.cpp \
audio/AudioOutput.cpp \
audio/Resampler.cpp \
os/posix/NetworkSocketPosix.cpp

TGVOIP_HDRS = \
VoIPController.h \
Buffers.h \
BlockingQueue.h \
PrivateDefines.h \
CongestionControl.h \
EchoCanceller.h \
JitterBuffer.h \
logging.h \
threading.h \
MediaStreamItf.h \
MessageThread.h \
NetworkSocket.h \
OpusDecoder.h \
OpusEncoder.h \
PacketReassembler.h \
VoIPServerConfig.h \
audio/AudioIO.h \
audio/AudioInput.h \
audio/AudioOutput.h \
audio/Resampler.h \
os/posix/NetworkSocketPosix.h

if TARGET_OS_OSX

SRC += \
os/darwin/AudioInputAudioUnit.cpp \
os/darwin/AudioOutputAudioUnit.cpp \
os/darwin/AudioUnitIO.cpp \
os/darwin/AudioInputAudioUnitOSX.cpp \
os/darwin/AudioOutputAudioUnitOSX.cpp \
os/darwin/DarwinSpecific.mm

TGVOIP_HDRS += \
os/darwin/AudioInputAudioUnit.h \
os/darwin/AudioOutputAudioUnit.h \
os/darwin/AudioUnitIO.h \
os/darwin/AudioInputAudioUnitOSX.h \
os/darwin/AudioOutputAudioUnitOSX.h \
os/darwin/DarwinSpecific.h

LDFLAGS += -framework Foundation -framework CoreFoundation -framework CoreAudio -framework AudioToolbox

else
# Linux-specific
if WITH_ALSA
SRC += \
os/linux/AudioInputALSA.cpp \
os/linux/AudioOutputALSA.cpp
TGVOIP_HDRS += \
os/linux/AudioInputALSA.h \
os/linux/AudioOutputALSA.h
endif

if WITH_PULSE
SRC += \
os/linux/AudioOutputPulse.cpp \
os/linux/AudioInputPulse.cpp \
os/linux/AudioPulse.cpp
TGVOIP_HDRS += \
os/linux/AudioOutputPulse.h \
os/linux/AudioInputPulse.h \
os/linux/AudioPulse.h \
os/linux/PulseFunctions.h
endif
endif

if ENABLE_DSP
CFLAGS += -DWEBRTC_POSIX -DWEBRTC_APM_DEBUG_DUMP=0 -I$(top_srcdir)/webrtc_dsp
CCASFLAGS += -I$(top_srcdir)/webrtc_dsp

SRC += \
webrtc_dsp/webrtc/common_audio/ring_buffer.c \
webrtc_dsp/webrtc/common_audio/signal_processing/auto_corr_to_refl_coef.c \
webrtc_dsp/webrtc/common_audio/signal_processing/auto_correlation.c \
webrtc_dsp/webrtc/common_audio/signal_processing/complex_fft.c \
webrtc_dsp/webrtc/common_audio/signal_processing/copy_set_operations.c \
webrtc_dsp/webrtc/common_audio/signal_processing/cross_correlation.c \
webrtc_dsp/webrtc/common_audio/signal_processing/division_operations.c \
webrtc_dsp/webrtc/common_audio/signal_processing/dot_product_with_scale.c \
webrtc_dsp/webrtc/common_audio/signal_processing/downsample_fast.c \
webrtc_dsp/webrtc/common_audio/signal_processing/energy.c \
webrtc_dsp/webrtc/common_audio/signal_processing/filter_ar.c \
webrtc_dsp/webrtc/common_audio/signal_processing/filter_ar_fast_q12.c \
webrtc_dsp/webrtc/common_audio/signal_processing/filter_ma_fast_q12.c \
webrtc_dsp/webrtc/common_audio/signal_processing/get_hanning_window.c \
webrtc_dsp/webrtc/common_audio/signal_processing/get_scaling_square.c \
webrtc_dsp/webrtc/common_audio/signal_processing/ilbc_specific_functions.c \
webrtc_dsp/webrtc/common_audio/signal_processing/levinson_durbin.c \
webrtc_dsp/webrtc/common_audio/signal_processing/lpc_to_refl_coef.c \
webrtc_dsp/webrtc/common_audio/signal_processing/min_max_operations.c \
webrtc_dsp/webrtc/common_audio/signal_processing/randomization_functions.c \
webrtc_dsp/webrtc/common_audio/signal_processing/real_fft.c \
webrtc_dsp/webrtc/common_audio/signal_processing/refl_coef_to_lpc.c \
webrtc_dsp/webrtc/common_audio/signal_processing/resample.c \
webrtc_dsp/webrtc/common_audio/signal_processing/resample_48khz.c \
webrtc_dsp/webrtc/common_audio/signal_processing/resample_by_2.c \
webrtc_dsp/webrtc/common_audio/signal_processing/resample_by_2_internal.c \
webrtc_dsp/webrtc/common_audio/signal_processing/resample_fractional.c \
webrtc_dsp/webrtc/common_audio/signal_processing/spl_init.c \
webrtc_dsp/webrtc/common_audio/signal_processing/spl_inl.c \
webrtc_dsp/webrtc/common_audio/signal_processing/spl_sqrt.c \
webrtc_dsp/webrtc/common_audio/signal_processing/splitting_filter_impl.c \
webrtc_dsp/webrtc/common_audio/signal_processing/sqrt_of_one_minus_x_squared.c \
webrtc_dsp/webrtc/common_audio/signal_processing/vector_scaling_operations.c

SRC += \
webrtc_dsp/webrtc/base/checks.cc \
webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_core.cc \
webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_core_c.cc \
webrtc_dsp/webrtc/modules/audio_processing/aecm/echo_control_mobile.cc \
webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator.cc \
webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator_wrapper.cc \
webrtc_dsp/webrtc/modules/audio_processing/three_band_filter_bank.cc \
webrtc_dsp/webrtc/modules/audio_processing/splitting_filter.cc \
webrtc_dsp/webrtc/system_wrappers/source/cpu_features.cc \
webrtc_dsp/webrtc/common_audio/sparse_fir_filter.cc \
webrtc_dsp/webrtc/common_audio/channel_buffer.cc \
webrtc_dsp/webrtc/common_audio/audio_util.cc

SRC += \
webrtc_dsp/webrtc/modules/audio_processing/utility/block_mean_calculator.cc \
webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft.cc \
webrtc_dsp/webrtc/modules/audio_processing/logging/apm_data_dumper.cc \
webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core.cc \
webrtc_dsp/webrtc/modules/audio_processing/aec/aec_resampler.cc \
webrtc_dsp/webrtc/modules/audio_processing/aec/echo_cancellation.cc \
webrtc_dsp/webrtc/common_audio/wav_header.cc \
webrtc_dsp/webrtc/common_audio/wav_file.cc \
webrtc_dsp/webrtc/base/stringutils.cc

if TARGET_CPU_X86
SRC += \
webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core_sse2.cc \
webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft_sse2.cc
endif

if TARGET_CPU_ARM
SRC += \
webrtc_dsp/webrtc/common_audio/signal_processing/complex_bit_reverse_arm.S \
webrtc_dsp/webrtc/common_audio/signal_processing/spl_sqrt_floor_arm.S
if TARGET_CPU_ARMV7
CFLAGS += -mfpu=neon -mfloat-abi=hard
CCASFLAGS += -mfpu=neon -mfloat-abi=hard
SRC += \
webrtc_dsp/webrtc/common_audio/signal_processing/cross_correlation_neon.c \
webrtc_dsp/webrtc/common_audio/signal_processing/downsample_fast_neon.c \
webrtc_dsp/webrtc/common_audio/signal_processing/min_max_operations_neon.c \
webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core_neon.cc \
webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_core_neon.cc \
webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_core_neon.c \
webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft_neon.cc
# webrtc_dsp/webrtc/common_audio/signal_processing/filter_ar_fast_q12_armv7.S
endif
else
SRC += \
webrtc_dsp/webrtc/common_audio/signal_processing/complex_bit_reverse.c \
webrtc_dsp/webrtc/common_audio/signal_processing/spl_sqrt_floor.c
endif

SRC += \
webrtc_dsp/webrtc/modules/audio_processing/ns/noise_suppression_x.c \
webrtc_dsp/webrtc/modules/audio_processing/ns/noise_suppression.c \
webrtc_dsp/webrtc/modules/audio_processing/ns/ns_core.c \
webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_core_c.c \
webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_core.c \
webrtc_dsp/webrtc/common_audio/fft4g.c

SRC += \
webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/analog_agc.c \
webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/digital_agc.c

# headers
SRC += \
webrtc_dsp/webrtc/base/array_view.h \
webrtc_dsp/webrtc/base/atomicops.h \
webrtc_dsp/webrtc/base/basictypes.h \
webrtc_dsp/webrtc/base/checks.h \
webrtc_dsp/webrtc/base/constructormagic.h \
webrtc_dsp/webrtc/base/safe_compare.h \
webrtc_dsp/webrtc/base/safe_conversions.h \
webrtc_dsp/webrtc/base/safe_conversions_impl.h \
webrtc_dsp/webrtc/base/sanitizer.h \
webrtc_dsp/webrtc/base/stringutils.h \
webrtc_dsp/webrtc/base/type_traits.h \
webrtc_dsp/webrtc/common_audio/channel_buffer.h \
webrtc_dsp/webrtc/common_audio/fft4g.h \
webrtc_dsp/webrtc/common_audio/include/audio_util.h \
webrtc_dsp/webrtc/common_audio/ring_buffer.h \
webrtc_dsp/webrtc/common_audio/signal_processing/complex_fft_tables.h \
webrtc_dsp/webrtc/common_audio/signal_processing/include/real_fft.h \
webrtc_dsp/webrtc/common_audio/signal_processing/include/signal_processing_library.h \
webrtc_dsp/webrtc/common_audio/signal_processing/include/spl_inl.h \
webrtc_dsp/webrtc/common_audio/signal_processing/include/spl_inl_armv7.h \
webrtc_dsp/webrtc/common_audio/signal_processing/include/spl_inl_mips.h \
webrtc_dsp/webrtc/common_audio/signal_processing/resample_by_2_internal.h \
webrtc_dsp/webrtc/common_audio/sparse_fir_filter.h \
webrtc_dsp/webrtc/common_audio/wav_file.h \
webrtc_dsp/webrtc/common_audio/wav_header.h \
webrtc_dsp/webrtc/modules/audio_processing/aec/aec_common.h \
webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core.h \
webrtc_dsp/webrtc/modules/audio_processing/aec/aec_core_optimized_methods.h \
webrtc_dsp/webrtc/modules/audio_processing/aec/aec_resampler.h \
webrtc_dsp/webrtc/modules/audio_processing/aec/echo_cancellation.h \
webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_core.h \
webrtc_dsp/webrtc/modules/audio_processing/aecm/aecm_defines.h \
webrtc_dsp/webrtc/modules/audio_processing/aecm/echo_control_mobile.h \
webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/analog_agc.h \
webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/digital_agc.h \
webrtc_dsp/webrtc/modules/audio_processing/agc/legacy/gain_control.h \
webrtc_dsp/webrtc/modules/audio_processing/logging/apm_data_dumper.h \
webrtc_dsp/webrtc/modules/audio_processing/ns/defines.h \
webrtc_dsp/webrtc/modules/audio_processing/ns/noise_suppression.h \
webrtc_dsp/webrtc/modules/audio_processing/ns/noise_suppression_x.h \
webrtc_dsp/webrtc/modules/audio_processing/ns/ns_core.h \
webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_core.h \
webrtc_dsp/webrtc/modules/audio_processing/ns/nsx_defines.h \
webrtc_dsp/webrtc/modules/audio_processing/ns/windows_private.h \
webrtc_dsp/webrtc/modules/audio_processing/splitting_filter.h \
webrtc_dsp/webrtc/modules/audio_processing/three_band_filter_bank.h \
webrtc_dsp/webrtc/modules/audio_processing/utility/block_mean_calculator.h \
webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator.h \
webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator_internal.h \
webrtc_dsp/webrtc/modules/audio_processing/utility/delay_estimator_wrapper.h \
webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft.h \
webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft_tables_common.h \
webrtc_dsp/webrtc/modules/audio_processing/utility/ooura_fft_tables_neon_sse2.h \
webrtc_dsp/webrtc/system_wrappers/include/asm_defines.h \
webrtc_dsp/webrtc/system_wrappers/include/compile_assert_c.h \
webrtc_dsp/webrtc/system_wrappers/include/cpu_features_wrapper.h \
webrtc_dsp/webrtc/system_wrappers/include/metrics.h \
webrtc_dsp/webrtc/typedefs.h

else
CFLAGS += -DTGVOIP_NO_DSP
endif

libtgvoip_la_SOURCES = $(SRC) $(TGVOIP_HDRS)
tgvoipincludedir = $(includedir)/tgvoip
nobase_tgvoipinclude_HEADERS = $(TGVOIP_HDRS)

CXXFLAGS += -std=gnu++0x $(CFLAGS)