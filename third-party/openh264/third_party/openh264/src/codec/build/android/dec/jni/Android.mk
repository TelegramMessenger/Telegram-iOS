
LOCAL_PATH := $(call my-dir)
MY_LOCAL_PATH := $(LOCAL_PATH)

# Step3
#Generate the libwelsdecdemo.so file
include $(LOCAL_PATH)/welsdecdemo.mk
LOCAL_PATH := $(MY_LOCAL_PATH)

