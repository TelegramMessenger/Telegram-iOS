//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include <jni.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace td {
namespace td_api {
class keyboardButton;
class inlineKeyboardButton;
class pageBlockTableCell;
}  // namespace td_api

namespace jni {

extern thread_local bool parse_error;

extern jclass ArrayKeyboardButtonClass;
extern jclass ArrayInlineKeyboardButtonClass;
extern jclass ArrayPageBlockTableCellClass;
extern jmethodID GetConstructorID;
extern jmethodID BooleanGetValueMethodID;
extern jmethodID IntegerGetValueMethodID;
extern jmethodID LongGetValueMethodID;
extern jmethodID DoubleGetValueMethodID;

void set_fatal_error(JNIEnv *env, const std::string &error);

jclass get_jclass(JNIEnv *env, const char *class_name);

jmethodID get_method_id(JNIEnv *env, jclass clazz, const char *name, const char *signature);

jfieldID get_field_id(JNIEnv *env, jclass clazz, const char *name, const char *signature);

jfieldID get_static_field_id(JNIEnv *env, jclass clazz, const char *name, const char *signature);

void register_native_method(JNIEnv *env, jclass clazz, std::string name, std::string signature, void *function_ptr);

class JvmThreadDetacher {
  JavaVM *java_vm_;

  void detach() {
    if (java_vm_ != nullptr) {
      java_vm_->DetachCurrentThread();
      java_vm_ = nullptr;
    }
  }

 public:
  explicit JvmThreadDetacher(JavaVM *java_vm) : java_vm_(java_vm) {
  }

  JvmThreadDetacher(const JvmThreadDetacher &) = delete;
  JvmThreadDetacher &operator=(const JvmThreadDetacher &) = delete;
  JvmThreadDetacher(JvmThreadDetacher &&other) : java_vm_(other.java_vm_) {
    other.java_vm_ = nullptr;
  }
  JvmThreadDetacher &operator=(JvmThreadDetacher &&) = delete;
  ~JvmThreadDetacher() {
    detach();
  }

  void operator()(JNIEnv *env) {
    detach();
  }
};

std::unique_ptr<JNIEnv, JvmThreadDetacher> get_jni_env(JavaVM *java_vm, jint jni_version);

std::string fetch_string(JNIEnv *env, jobject o, jfieldID id);

std::string fetch_static_string(JNIEnv *env, jclass clazz, jfieldID id);

inline jobject fetch_object(JNIEnv *env, const jobject &o, const jfieldID &id) {
  // null return object is implicitly allowed
  return env->GetObjectField(o, id);
}

inline bool have_parse_error() {
  return parse_error;
}

inline void reset_parse_error() {
  parse_error = false;
}

std::string from_jstring(JNIEnv *env, jstring s);

jstring to_jstring(JNIEnv *env, const std::string &s);

std::string from_bytes(JNIEnv *env, jbyteArray arr);

jbyteArray to_bytes(JNIEnv *env, const std::string &b);

void init_vars(JNIEnv *env, const char *td_api_java_package);

jintArray store_vector(JNIEnv *env, const std::vector<std::int32_t> &v);

jlongArray store_vector(JNIEnv *env, const std::vector<std::int64_t> &v);

jdoubleArray store_vector(JNIEnv *env, const std::vector<double> &v);

jobjectArray store_vector(JNIEnv *env, const std::vector<std::string> &v);

template <class T>
jobjectArray store_vector(JNIEnv *env, const std::vector<T> &v) {
  auto length = static_cast<jint>(v.size());
  T::element_type::init_jni_vars(env);
  jobjectArray arr = env->NewObjectArray(length, T::element_type::Class, jobject());
  if (arr != nullptr) {
    for (jint i = 0; i < length; i++) {
      if (v[i] != nullptr) {
        jobject stored_object;
        v[i]->store(env, stored_object);
        if (stored_object) {
          env->SetObjectArrayElement(arr, i, stored_object);
          env->DeleteLocalRef(stored_object);
        }
      }
    }
  }
  return arr;
}

template <class T>
class get_array_class {
  static jclass get();
};

template <>
class get_array_class<td_api::keyboardButton> {
 public:
  static jclass get() {
    return ArrayKeyboardButtonClass;
  }
};

template <>
class get_array_class<td_api::inlineKeyboardButton> {
 public:
  static jclass get() {
    return ArrayInlineKeyboardButtonClass;
  }
};

template <>
class get_array_class<td_api::pageBlockTableCell> {
 public:
  static jclass get() {
    return ArrayPageBlockTableCellClass;
  }
};

template <class T>
jobjectArray store_vector(JNIEnv *env, const std::vector<std::vector<T>> &v) {
  auto length = static_cast<jint>(v.size());
  jobjectArray arr = env->NewObjectArray(length, get_array_class<typename T::element_type>::get(), 0);
  if (arr != nullptr) {
    for (jint i = 0; i < length; i++) {
      auto stored_array = store_vector(env, v[i]);
      if (stored_array) {
        env->SetObjectArrayElement(arr, i, stored_array);
        env->DeleteLocalRef(stored_array);
      }
    }
  }
  return arr;
}

template <class T>
auto fetch_tl_object(JNIEnv *env, jobject obj) {
  decltype(T::fetch(env, obj)) result;
  if (obj != nullptr) {
    result = T::fetch(env, obj);
    env->DeleteLocalRef(obj);
  }
  return result;
}

std::vector<std::int32_t> fetch_vector(JNIEnv *env, jintArray arr);

std::vector<std::int64_t> fetch_vector(JNIEnv *env, jlongArray arr);

std::vector<double> fetch_vector(JNIEnv *env, jdoubleArray arr);

template <class T>
struct FetchVector {
  static auto fetch(JNIEnv *env, jobjectArray arr) {
    std::vector<decltype(fetch_tl_object<T>(env, jobject()))> result;
    if (arr != nullptr) {
      jsize length = env->GetArrayLength(arr);
      result.reserve(length);
      for (jsize i = 0; i < length; i++) {
        result.push_back(fetch_tl_object<T>(env, env->GetObjectArrayElement(arr, i)));
      }
      env->DeleteLocalRef(arr);
    }
    return result;
  }
};

template <>
struct FetchVector<std::string> {
  static std::vector<std::string> fetch(JNIEnv *env, jobjectArray arr) {
    std::vector<std::string> result;
    if (arr != nullptr) {
      jsize length = env->GetArrayLength(arr);
      result.reserve(length);
      for (jsize i = 0; i < length; i++) {
        jstring str = (jstring)env->GetObjectArrayElement(arr, i);
        result.push_back(from_jstring(env, str));
        if (str) {
          env->DeleteLocalRef(str);
        }
      }
      env->DeleteLocalRef(arr);
    }
    return result;
  }
};

template <>
struct FetchVector<jbyteArray> {
  static std::vector<std::string> fetch(JNIEnv *env, jobjectArray arr) {
    std::vector<std::string> result;
    if (arr != nullptr) {
      jsize length = env->GetArrayLength(arr);
      result.reserve(length);
      for (jsize i = 0; i < length; i++) {
        jbyteArray bytes = (jbyteArray)env->GetObjectArrayElement(arr, i);
        result.push_back(from_bytes(env, bytes));
        if (bytes) {
          env->DeleteLocalRef(bytes);
        }
      }
      env->DeleteLocalRef(arr);
    }
    return result;
  }
};

template <class T>
struct FetchVector<std::vector<T>> {
  static auto fetch(JNIEnv *env, jobjectArray arr) {
    std::vector<decltype(FetchVector<T>::fetch(env, jobjectArray()))> result;
    if (arr != nullptr) {
      jsize length = env->GetArrayLength(arr);
      result.reserve(length);
      for (jsize i = 0; i < length; i++) {
        result.push_back(FetchVector<T>::fetch(env, (jobjectArray)env->GetObjectArrayElement(arr, i)));
      }
      env->DeleteLocalRef(arr);
    }
    return result;
  }
};

}  // namespace jni
}  // namespace td
