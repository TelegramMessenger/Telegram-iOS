include $(CLEAR_VARS)

LOCAL_MODULE := voip
LOCAL_CPPFLAGS := -Wall -std=c++11 -DANDROID -finline-functions -ffast-math -Os -fno-strict-aliasing -O3
LOCAL_CFLAGS := -O3 -DUSE_KISS_FFT -DFIXED_POINT

ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
    LOCAL_CPPFLAGS += -mfloat-abi=softfp -mfpu=neon
    LOCAL_CFLAGS += -mfloat-abi=softfp -mfpu=neon
else
    ifeq ($(TARGET_ARCH_ABI),armeabi)
		LOCAL_CPPFLAGS += -mfloat-abi=softfp -mfpu=neon
        LOCAL_CFLAGS += -mfloat-abi=softfp -mfpu=neon
    else
        ifeq ($(TARGET_ARCH_ABI),x86)

        endif
    endif
endif

MY_DIR := libtgvoip

LOCAL_C_INCLUDES := jni/opus/include jni/boringssl/include/

LOCAL_SRC_FILES := \
$(MY_DIR)/external/speex_dsp/buffer.c \
$(MY_DIR)/external/speex_dsp/fftwrap.c \
$(MY_DIR)/external/speex_dsp/filterbank.c \
$(MY_DIR)/external/speex_dsp/kiss_fft.c \
$(MY_DIR)/external/speex_dsp/kiss_fftr.c \
$(MY_DIR)/external/speex_dsp/mdf.c \
$(MY_DIR)/external/speex_dsp/preprocess.c \
$(MY_DIR)/external/speex_dsp/resample.c \
$(MY_DIR)/external/speex_dsp/scal.c \
$(MY_DIR)/external/speex_dsp/smallft.c \
$(MY_DIR)/VoIPController.cpp \
$(MY_DIR)/BufferInputStream.cpp \
$(MY_DIR)/BufferOutputStream.cpp \
$(MY_DIR)/BlockingQueue.cpp \
$(MY_DIR)/audio/AudioInput.cpp \
$(MY_DIR)/os/android/AudioInputOpenSLES.cpp \
$(MY_DIR)/MediaStreamItf.cpp \
$(MY_DIR)/audio/AudioOutput.cpp \
$(MY_DIR)/OpusEncoder.cpp \
$(MY_DIR)/os/android/AudioOutputOpenSLES.cpp \
$(MY_DIR)/JitterBuffer.cpp \
$(MY_DIR)/OpusDecoder.cpp \
$(MY_DIR)/BufferPool.cpp \
$(MY_DIR)/os/android/OpenSLEngineWrapper.cpp \
$(MY_DIR)/os/android/AudioInputAndroid.cpp \
$(MY_DIR)/EchoCanceller.cpp \


include $(BUILD_STATIC_LIBRARY)