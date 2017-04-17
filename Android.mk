LOCAL_MODULE    := WebRtcAec

LOCAL_SRC_FILES := ./libtgvoip/external/libWebRtcAec_android_$(TARGET_ARCH_ABI).a

include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := voip
LOCAL_CPPFLAGS := -Wall -std=c++11 -DANDROID -finline-functions -ffast-math -Os -fno-strict-aliasing -O3
LOCAL_CFLAGS := -O3 -DUSE_KISS_FFT -fexceptions

ifeq ($(TARGET_ARCH_ABI),armeabi-v7a)
#    LOCAL_CPPFLAGS += -mfloat-abi=softfp -mfpu=neon
#    LOCAL_CFLAGS += -mfloat-abi=softfp -mfpu=neon -DFLOATING_POINT
#	LOCAL_ARM_NEON := true
else
	LOCAL_CFLAGS += -DFIXED_POINT
    ifeq ($(TARGET_ARCH_ABI),armeabi)
#		LOCAL_CPPFLAGS += -mfloat-abi=softfp -mfpu=neon
#        LOCAL_CFLAGS += -mfloat-abi=softfp -mfpu=neon
    else
        ifeq ($(TARGET_ARCH_ABI),x86)

        endif
    endif
endif

MY_DIR := libtgvoip

LOCAL_C_INCLUDES := jni/opus/include jni/boringssl/include/

LOCAL_SRC_FILES := \
./libtgvoip/logging.cpp \
./libtgvoip/VoIPController.cpp \
./libtgvoip/BufferInputStream.cpp \
./libtgvoip/BufferOutputStream.cpp \
./libtgvoip/BlockingQueue.cpp \
./libtgvoip/audio/AudioInput.cpp \
./libtgvoip/os/android/AudioInputOpenSLES.cpp \
./libtgvoip/MediaStreamItf.cpp \
./libtgvoip/audio/AudioOutput.cpp \
./libtgvoip/OpusEncoder.cpp \
./libtgvoip/os/android/AudioOutputOpenSLES.cpp \
./libtgvoip/JitterBuffer.cpp \
./libtgvoip/OpusDecoder.cpp \
./libtgvoip/BufferPool.cpp \
./libtgvoip/os/android/OpenSLEngineWrapper.cpp \
./libtgvoip/os/android/AudioInputAndroid.cpp \
./libtgvoip/os/android/AudioOutputAndroid.cpp \
./libtgvoip/EchoCanceller.cpp \
./libtgvoip/CongestionControl.cpp \
./libtgvoip/VoIPServerConfig.cpp \
./libtgvoip/NetworkSocket.cpp

include $(BUILD_STATIC_LIBRARY)

include $(CLEAR_VARS)
