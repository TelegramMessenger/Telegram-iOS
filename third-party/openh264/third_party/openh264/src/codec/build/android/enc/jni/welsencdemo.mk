# Generate the libwelsencdemo.so file
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE    := wels
LOCAL_SRC_FILES := ../../../../../libopenh264.so
ifneq (,$(wildcard $(LOCAL_PATH)/$(LOCAL_SRC_FILES)))
include $(PREBUILT_SHARED_LIBRARY)
endif



include $(CLEAR_VARS)

#
# Module Settings
#
LOCAL_MODULE := welsencdemo

#
# Source Files
#
CODEC_PATH := ../../../../
CONSOLE_ENC_PATH := ../../../../console/enc
CONSOLE_COMMON_PATH := ../../../../console/common
LOCAL_SRC_FILES := \
            $(CONSOLE_ENC_PATH)/src/welsenc.cpp \
            $(CONSOLE_COMMON_PATH)/src/read_config.cpp \
            myjni.cpp

#
# Header Includes
#
LOCAL_C_INCLUDES := \
            $(LOCAL_PATH)/../../../../api/wels \
            $(LOCAL_PATH)/../../../../console/enc/inc \
            $(LOCAL_PATH)/../../../../console/common/inc \
            $(LOCAL_PATH)/../../../../encoder/core/inc \
            $(LOCAL_PATH)/../../../../processing/interface \
            $(LOCAL_PATH)/../../../../common/inc


#
# Compile Flags and Link Libraries
#
LOCAL_CFLAGS := -DANDROID_NDK

LOCAL_LDLIBS := -llog
LOCAL_SHARED_LIBRARIES := wels

include $(BUILD_SHARED_LIBRARY)
