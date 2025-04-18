
LOCAL_PATH := $(call my-dir)
MY_LOCAL_PATH := $(LOCAL_PATH)

# Step3
#Generate the libwelsdecdemo.so file
include $(LOCAL_PATH)/welsencdemo.mk
LOCAL_PATH := $(MY_LOCAL_PATH)

