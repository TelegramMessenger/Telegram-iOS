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

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "tl_jni_object.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/Slice.h"

#include <memory>

namespace td {
namespace jni {

thread_local bool parse_error;

static jclass BooleanClass;
static jclass IntegerClass;
static jclass LongClass;
static jclass DoubleClass;
static jclass StringClass;
static jclass ObjectClass;
jmethodID GetConstructorID;
jmethodID BooleanGetValueMethodID;
jmethodID IntegerGetValueMethodID;
jmethodID LongGetValueMethodID;
jmethodID DoubleGetValueMethodID;

static void fatal_error(JNIEnv *env, CSlice error) {
  LOG(ERROR) << error;
  env->FatalError(error.c_str());
}

jclass get_jclass(JNIEnv *env, const char *class_name) {
  jclass clazz = env->FindClass(class_name);
  if (!clazz) {
    fatal_error(env, PSLICE() << "Can't find class [" << class_name << "]");
  }
  jclass clazz_global = (jclass)env->NewGlobalRef(clazz);

  env->DeleteLocalRef(clazz);

  if (!clazz_global) {
    fatal_error(env, PSLICE() << "Can't create global reference to [" << class_name << "]");
  }

  return clazz_global;
}

jmethodID get_method_id(JNIEnv *env, jclass clazz, const char *name, const char *signature) {
  jmethodID res = env->GetMethodID(clazz, name, signature);
  if (!res) {
    fatal_error(env, PSLICE() << "Can't find method [" << name << "] with signature [" << signature << "]");
  }
  return res;
}

jfieldID get_field_id(JNIEnv *env, jclass clazz, const char *name, const char *signature) {
  jfieldID res = env->GetFieldID(clazz, name, signature);
  if (!res) {
    fatal_error(env, PSLICE() << "Can't find field [" << name << "] with signature [" << signature << "]");
  }
  return res;
}

void register_native_method(JNIEnv *env, jclass clazz, std::string name, std::string signature, void *function_ptr) {
  JNINativeMethod native_method{&name[0], &signature[0], function_ptr};
  if (env->RegisterNatives(clazz, &native_method, 1) != 0) {
    fatal_error(env, PSLICE() << "RegisterNatives failed for " << name << " with signature " << signature);
  }
}

std::unique_ptr<JNIEnv, JvmThreadDetacher> get_jni_env(JavaVM *java_vm, jint jni_version) {
  JNIEnv *env = nullptr;
  if (java_vm->GetEnv(reinterpret_cast<void **>(&env), jni_version) == JNI_EDETACHED) {
#ifdef JDK1_2  // if not Android JNI
    auto p_env = reinterpret_cast<void **>(&env);
#else
    auto p_env = &env;
#endif
    java_vm->AttachCurrentThread(p_env, nullptr);
  } else {
    java_vm = nullptr;
  }

  return std::unique_ptr<JNIEnv, JvmThreadDetacher>(env, JvmThreadDetacher(java_vm));
}

void init_vars(JNIEnv *env, const char *td_api_java_package) {
  BooleanClass = get_jclass(env, "java/lang/Boolean");
  IntegerClass = get_jclass(env, "java/lang/Integer");
  LongClass = get_jclass(env, "java/lang/Long");
  DoubleClass = get_jclass(env, "java/lang/Double");
  StringClass = get_jclass(env, "java/lang/String");
  ObjectClass = get_jclass(env, (PSLICE() << td_api_java_package << "/TonApi$Object").c_str());
  GetConstructorID = get_method_id(env, ObjectClass, "getConstructor", "()I");
  BooleanGetValueMethodID = get_method_id(env, BooleanClass, "booleanValue", "()Z");
  IntegerGetValueMethodID = get_method_id(env, IntegerClass, "intValue", "()I");
  LongGetValueMethodID = get_method_id(env, LongClass, "longValue", "()J");
  DoubleGetValueMethodID = get_method_id(env, DoubleClass, "doubleValue", "()D");
}

static size_t get_utf8_from_utf16_length(const jchar *p, jsize len) {
  size_t result = 0;
  for (jsize i = 0; i < len; i++) {
    unsigned int cur = p[i];
    if ((cur & 0xF800) == 0xD800) {
      if (i < len) {
        unsigned int next = p[++i];
        if ((next & 0xFC00) == 0xDC00 && (cur & 0x400) == 0) {
          result += 4;
          continue;
        }
      }

      // TODO wrong UTF-16, it is possible
      return 0;
    }
    result += 1 + (cur >= 0x80) + (cur >= 0x800);
  }
  return result;
}

static void utf16_to_utf8(const jchar *p, jsize len, char *res) {
  for (jsize i = 0; i < len; i++) {
    unsigned int cur = p[i];
    // TODO conversion unsigned int -> signed char is implementation defined
    if (cur <= 0x7f) {
      *res++ = static_cast<char>(cur);
    } else if (cur <= 0x7ff) {
      *res++ = static_cast<char>(0xc0 | (cur >> 6));
      *res++ = static_cast<char>(0x80 | (cur & 0x3f));
    } else if ((cur & 0xF800) != 0xD800) {
      *res++ = static_cast<char>(0xe0 | (cur >> 12));
      *res++ = static_cast<char>(0x80 | ((cur >> 6) & 0x3f));
      *res++ = static_cast<char>(0x80 | (cur & 0x3f));
    } else {
      // correctness is already checked
      unsigned int next = p[++i];
      unsigned int val = ((cur - 0xD800) << 10) + next - 0xDC00 + 0x10000;

      *res++ = static_cast<char>(0xf0 | (val >> 18));
      *res++ = static_cast<char>(0x80 | ((val >> 12) & 0x3f));
      *res++ = static_cast<char>(0x80 | ((val >> 6) & 0x3f));
      *res++ = static_cast<char>(0x80 | (val & 0x3f));
    }
  }
}

static jsize get_utf16_from_utf8_length(const char *p, size_t len, jsize *surrogates) {
  // UTF-8 correctness is supposed
  jsize result = 0;
  for (size_t i = 0; i < len; i++) {
    result += ((p[i] & 0xc0) != 0x80);
    *surrogates += ((p[i] & 0xf8) == 0xf0);
  }
  return result;
}

static void utf8_to_utf16(const char *p, size_t len, jchar *res) {
  // UTF-8 correctness is supposed
  for (size_t i = 0; i < len;) {
    unsigned int a = static_cast<unsigned char>(p[i++]);
    if (a >= 0x80) {
      unsigned int b = static_cast<unsigned char>(p[i++]);
      if (a >= 0xe0) {
        unsigned int c = static_cast<unsigned char>(p[i++]);
        if (a >= 0xf0) {
          unsigned int d = static_cast<unsigned char>(p[i++]);
          unsigned int val = ((a & 0x07) << 18) + ((b & 0x3f) << 12) + ((c & 0x3f) << 6) + (d & 0x3f) - 0x10000;
          *res++ = static_cast<jchar>(0xD800 + (val >> 10));
          *res++ = static_cast<jchar>(0xDC00 + (val & 0x3ff));
        } else {
          *res++ = static_cast<jchar>(((a & 0x0f) << 12) + ((b & 0x3f) << 6) + (c & 0x3f));
        }
      } else {
        *res++ = static_cast<jchar>(((a & 0x1f) << 6) + (b & 0x3f));
      }
    } else {
      *res++ = static_cast<jchar>(a);
    }
  }
}

std::string fetch_string(JNIEnv *env, jobject o, jfieldID id) {
  jstring s = (jstring)env->GetObjectField(o, id);
  if (s == nullptr) {
    // treat null as an empty string
    return std::string();
  }
  std::string res = from_jstring(env, s);
  env->DeleteLocalRef(s);
  return res;
}

SecureString fetch_string_secure(JNIEnv *env, jobject o, jfieldID id) {
  jstring s = (jstring)env->GetObjectField(o, id);
  if (s == nullptr) {
    // treat null as an empty string
    return {};
  }
  auto res = from_jstring_secure(env, s);
  env->DeleteLocalRef(s);
  return res;
}

template <class T>
T do_from_jstring(JNIEnv *env, jstring s) {
  if (!s) {
    return T{};
  }
  jsize s_len = env->GetStringLength(s);
  const jchar *p = env->GetStringChars(s, nullptr);
  if (p == nullptr) {
    parse_error = true;
    return T{};
  }
  size_t len = get_utf8_from_utf16_length(p, s_len);
  T res(len, '\0');
  if (len) {
    utf16_to_utf8(p, s_len, as_mutable_slice(res).begin());
  }
  env->ReleaseStringChars(s, p);
  return res;
}

std::string from_jstring(JNIEnv *env, jstring s) {
  return do_from_jstring<std::string>(env, s);
}

jstring do_to_jstring(JNIEnv *env, CSlice s) {
  jsize surrogates = 0;
  jsize unicode_len = get_utf16_from_utf8_length(s.c_str(), s.size(), &surrogates);
  if (surrogates == 0) {
    // TODO '\0'
    return env->NewStringUTF(s.c_str());
  }
  jsize result_len = surrogates + unicode_len;
  if (result_len <= 256) {
    jchar result[256];
    utf8_to_utf16(s.c_str(), s.size(), result);
    return env->NewString(result, result_len);
  }

  auto result = std::make_unique<jchar[]>(result_len);
  utf8_to_utf16(s.c_str(), s.size(), result.get());
  return env->NewString(result.get(), result_len);
}

jstring to_jstring(JNIEnv *env, const std::string &s) {
  return do_to_jstring(env, s);
}

template <class T>
T do_from_bytes(JNIEnv *env, jbyteArray arr) {
  T b;
  if (arr != nullptr) {
    jsize length = env->GetArrayLength(arr);
    if (length != 0) {
      b = T(narrow_cast<size_t>(length), '\0');
      env->GetByteArrayRegion(arr, 0, length, reinterpret_cast<jbyte *>(as_mutable_slice(b).begin()));
    }
    env->DeleteLocalRef(arr);
  }
  return b;
}
std::string from_bytes(JNIEnv *env, jbyteArray arr) {
  return do_from_bytes<std::string>(env, arr);
}

jbyteArray to_bytes(JNIEnv *env, Slice b) {
  static_assert(sizeof(char) == sizeof(jbyte), "Mismatched jbyte size");
  jsize length = narrow_cast<jsize>(b.size());
  jbyteArray arr = env->NewByteArray(length);
  if (arr != nullptr && length != 0) {
    env->SetByteArrayRegion(arr, 0, length, reinterpret_cast<const jbyte *>(b.data()));
  }
  return arr;
}

SecureString from_jstring_secure(JNIEnv *env, jstring s) {
  return do_from_jstring<SecureString>(env, s);
}

jstring to_jstring_secure(JNIEnv *env, Slice s) {
  SecureString cstr(s.size() + 1);
  cstr.as_mutable_slice().copy_from(s);
  cstr.as_mutable_slice().back() = 0;
  return do_to_jstring(env, CSlice(cstr.data(), cstr.data() + s.size()));
}

SecureString from_bytes_secure(JNIEnv *env, jbyteArray arr) {
  return do_from_bytes<SecureString>(env, arr);
}

jbyteArray to_bytes_secure(JNIEnv *env, Slice b) {
  return to_bytes(env, b);
}

jintArray store_vector(JNIEnv *env, const std::vector<std::int32_t> &v) {
  static_assert(sizeof(std::int32_t) == sizeof(jint), "Mismatched jint size");
  jsize length = narrow_cast<jsize>(v.size());
  jintArray arr = env->NewIntArray(length);
  if (arr != nullptr && length != 0) {
    env->SetIntArrayRegion(arr, 0, length, reinterpret_cast<const jint *>(&v[0]));
  }
  return arr;
}

jlongArray store_vector(JNIEnv *env, const std::vector<std::int64_t> &v) {
  static_assert(sizeof(std::int64_t) == sizeof(jlong), "Mismatched jlong size");
  jsize length = narrow_cast<jsize>(v.size());
  jlongArray arr = env->NewLongArray(length);
  if (arr != nullptr && length != 0) {
    env->SetLongArrayRegion(arr, 0, length, reinterpret_cast<const jlong *>(&v[0]));
  }
  return arr;
}

jdoubleArray store_vector(JNIEnv *env, const std::vector<double> &v) {
  static_assert(sizeof(double) == sizeof(jdouble), "Mismatched jdouble size");
  jsize length = narrow_cast<jsize>(v.size());
  jdoubleArray arr = env->NewDoubleArray(length);
  if (arr != nullptr && length != 0) {
    env->SetDoubleArrayRegion(arr, 0, length, reinterpret_cast<const jdouble *>(&v[0]));
  }
  return arr;
}

jobjectArray store_vector(JNIEnv *env, const std::vector<std::string> &v) {
  jsize length = narrow_cast<jsize>(v.size());
  jobjectArray arr = env->NewObjectArray(length, StringClass, 0);
  if (arr != nullptr) {
    for (jsize i = 0; i < length; i++) {
      jstring str = to_jstring(env, v[i]);
      if (str) {
        env->SetObjectArrayElement(arr, i, str);
        env->DeleteLocalRef(str);
      }
    }
  }
  return arr;
}

jobjectArray store_vector(JNIEnv *env, const std::vector<SecureString> &v) {
  jsize length = narrow_cast<jsize>(v.size());
  jobjectArray arr = env->NewObjectArray(length, StringClass, 0);
  if (arr != nullptr) {
    for (jsize i = 0; i < length; i++) {
      jstring str = to_jstring_secure(env, v[i]);
      if (str) {
        env->SetObjectArrayElement(arr, i, str);
        env->DeleteLocalRef(str);
      }
    }
  }
  return arr;
}

std::vector<std::int32_t> fetch_vector(JNIEnv *env, jintArray arr) {
  std::vector<std::int32_t> result;
  if (arr != nullptr) {
    jsize length = env->GetArrayLength(arr);
    if (length != 0) {
      result.resize(length);
      env->GetIntArrayRegion(arr, 0, length, reinterpret_cast<jint *>(&result[0]));
    }
    env->DeleteLocalRef(arr);
  }
  return result;
}

std::vector<std::int64_t> fetch_vector(JNIEnv *env, jlongArray arr) {
  std::vector<std::int64_t> result;
  if (arr != nullptr) {
    jsize length = env->GetArrayLength(arr);
    if (length != 0) {
      result.resize(length);
      env->GetLongArrayRegion(arr, 0, length, reinterpret_cast<jlong *>(&result[0]));
    }
    env->DeleteLocalRef(arr);
  }
  return result;
}

std::vector<double> fetch_vector(JNIEnv *env, jdoubleArray arr) {
  std::vector<double> result;
  if (arr != nullptr) {
    jsize length = env->GetArrayLength(arr);
    if (length != 0) {
      result.resize(length);
      env->GetDoubleArrayRegion(arr, 0, length, reinterpret_cast<jdouble *>(&result[0]));
    }
    env->DeleteLocalRef(arr);
  }
  return result;
}

}  // namespace jni
}  // namespace td
