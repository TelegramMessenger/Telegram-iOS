/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include <jni.h>

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

#include "td/utils/Slice.h"
#include "td/utils/SharedSlice.h"

namespace td {
namespace jni {

extern thread_local bool parse_error;

extern jmethodID GetConstructorID;
extern jmethodID BooleanGetValueMethodID;
extern jmethodID IntegerGetValueMethodID;
extern jmethodID LongGetValueMethodID;
extern jmethodID DoubleGetValueMethodID;

jclass get_jclass(JNIEnv *env, const char *class_name);

jmethodID get_method_id(JNIEnv *env, jclass clazz, const char *name, const char *signature);

jfieldID get_field_id(JNIEnv *env, jclass clazz, const char *name, const char *signature);

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

  JvmThreadDetacher(const JvmThreadDetacher &other) = delete;
  JvmThreadDetacher &operator=(const JvmThreadDetacher &other) = delete;
  JvmThreadDetacher(JvmThreadDetacher &&other) : java_vm_(other.java_vm_) {
    other.java_vm_ = nullptr;
  }
  JvmThreadDetacher &operator=(JvmThreadDetacher &&other) = delete;
  ~JvmThreadDetacher() {
    detach();
  }

  void operator()(JNIEnv *env) {
    detach();
  }
};

std::unique_ptr<JNIEnv, JvmThreadDetacher> get_jni_env(JavaVM *java_vm, jint jni_version);

std::string fetch_string(JNIEnv *env, jobject o, jfieldID id);
SecureString fetch_string_secure(JNIEnv *env, jobject o, jfieldID id);

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
SecureString from_jstring_secure(JNIEnv *env, jstring s);

jstring to_jstring(JNIEnv *env, const std::string &s);
jstring to_jstring_secure(JNIEnv *env, Slice s);

std::string from_bytes(JNIEnv *env, jbyteArray arr);
SecureString from_bytes_secure(JNIEnv *env, jbyteArray arr);

jbyteArray to_bytes(JNIEnv *env, Slice b);
jbyteArray to_bytes_secure(JNIEnv *env, Slice b);

void init_vars(JNIEnv *env, const char *td_api_java_package);

jintArray store_vector(JNIEnv *env, const std::vector<std::int32_t> &v);

jlongArray store_vector(JNIEnv *env, const std::vector<std::int64_t> &v);

jdoubleArray store_vector(JNIEnv *env, const std::vector<double> &v);

jobjectArray store_vector(JNIEnv *env, const std::vector<std::string> &v);

jobjectArray store_vector(JNIEnv *env, const std::vector<SecureString> &v);

template <class T>
jobjectArray store_vector(JNIEnv *env, const std::vector<T> &v) {
  jint length = static_cast<jint>(v.size());
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

template <class T>
jobjectArray store_vector(JNIEnv *env, const std::vector<std::vector<T>> &v) {
  jint length = static_cast<jint>(v.size());
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
        result.push_back(jni::from_jstring(env, str));
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
struct FetchVector<SecureString> {
  static std::vector<SecureString> fetch(JNIEnv *env, jobjectArray arr) {
    std::vector<SecureString> result;
    if (arr != nullptr) {
      jsize length = env->GetArrayLength(arr);
      result.reserve(length);
      for (jsize i = 0; i < length; i++) {
        jstring str = (jstring)env->GetObjectArrayElement(arr, i);
        result.push_back(jni::from_jstring_secure(env, str));
        if (str) {
          env->DeleteLocalRef(str);
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
