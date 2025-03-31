//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#ifdef TD_JSON_JAVA
#include <td/telegram/td_json_client.h>
#else
#include <td/telegram/Client.h>
#include <td/telegram/td_api.h>
#endif

#include <td/tl/tl_jni_object.h>

#include <cstdint>
#include <cstdlib>
#include <string>
#include <utility>

namespace td_jni {

#ifdef TD_JSON_JAVA
static jint JsonClient_createClientId(JNIEnv *env, jclass clazz) {
  return static_cast<jint>(td_create_client_id());
}

static void JsonClient_send(JNIEnv *env, jclass clazz, jint client_id, jstring request) {
  td_send(static_cast<int>(client_id), td::jni::from_jstring(env, request).c_str());
}

static jstring JsonClient_receive(JNIEnv *env, jclass clazz, jdouble timeout) {
  auto result = td_receive(timeout);
  if (result == nullptr) {
    return nullptr;
  }
  return td::jni::to_jstring(env, result);
}

static jstring JsonClient_execute(JNIEnv *env, jclass clazz, jstring request) {
  auto result = td_execute(td::jni::from_jstring(env, request).c_str());
  if (result == nullptr) {
    return nullptr;
  }
  return td::jni::to_jstring(env, result);
}
#else
static td::td_api::object_ptr<td::td_api::Function> fetch_function(JNIEnv *env, jobject function) {
  td::jni::reset_parse_error();
  auto result = td::td_api::Function::fetch(env, function);
  if (td::jni::have_parse_error()) {
    std::abort();
  }
  return result;
}

static td::ClientManager *get_manager() {
  return td::ClientManager::get_manager_singleton();
}

static jint Client_createNativeClient(JNIEnv *env, jclass clazz) {
  return static_cast<jint>(get_manager()->create_client_id());
}

static void Client_nativeClientSend(JNIEnv *env, jclass clazz, jint client_id, jlong id, jobject function) {
  get_manager()->send(static_cast<std::int32_t>(client_id), static_cast<std::uint64_t>(id),
                      fetch_function(env, function));
}

static jint Client_nativeClientReceive(JNIEnv *env, jclass clazz, jintArray client_ids, jlongArray ids,
                                       jobjectArray events, jdouble timeout) {
  jsize events_size = env->GetArrayLength(ids);  // client_ids, ids and events must be of equal size
  if (events_size == 0) {
    return 0;
  }
  jsize result_size = 0;

  auto *manager = get_manager();
  auto response = manager->receive(timeout);
  while (response.object) {
    auto client_id = static_cast<jint>(response.client_id);
    env->SetIntArrayRegion(client_ids, result_size, 1, &client_id);

    auto request_id = static_cast<jlong>(response.request_id);
    env->SetLongArrayRegion(ids, result_size, 1, &request_id);

    jobject object;
    response.object->store(env, object);
    env->SetObjectArrayElement(events, result_size, object);
    env->DeleteLocalRef(object);

    result_size++;
    if (result_size == events_size) {
      break;
    }

    response = manager->receive(0);
  }
  return result_size;
}

static jobject Client_nativeClientExecute(JNIEnv *env, jclass clazz, jobject function) {
  jobject result;
  td::ClientManager::execute(fetch_function(env, function))->store(env, result);
  return result;
}

static jstring Object_toString(JNIEnv *env, jobject object) {
  return td::jni::to_jstring(env, to_string(td::td_api::Object::fetch(env, object)));
}

static jstring Function_toString(JNIEnv *env, jobject object) {
  return td::jni::to_jstring(env, to_string(td::td_api::Function::fetch(env, object)));
}
#endif

static constexpr jint JAVA_VERSION = JNI_VERSION_1_6;
static JavaVM *java_vm;
static jobject log_message_handler;

static void on_log_message(int verbosity_level, const char *log_message) {
  auto env = td::jni::get_jni_env(java_vm, JAVA_VERSION);
  if (env == nullptr) {
    return;
  }

  jobject handler = env->NewLocalRef(log_message_handler);
  if (!handler) {
    return;
  }

  jclass handler_class = env->GetObjectClass(handler);
  if (handler_class) {
    jmethodID on_log_message_method = env->GetMethodID(handler_class, "onLogMessage", "(ILjava/lang/String;)V");
    if (on_log_message_method) {
      jstring log_message_str = td::jni::to_jstring(env.get(), log_message);
      if (log_message_str) {
        env->CallVoidMethod(handler, on_log_message_method, static_cast<jint>(verbosity_level), log_message_str);
        env->DeleteLocalRef((jobject)log_message_str);
      }
    }
    env->DeleteLocalRef((jobject)handler_class);
  }

  env->DeleteLocalRef(handler);
}

static void Client_nativeClientSetLogMessageHandler(JNIEnv *env, jclass clazz, jint max_verbosity_level,
                                                    jobject new_log_message_handler) {
  if (log_message_handler) {
#ifdef TD_JSON_JAVA
    td_set_log_message_callback(0, nullptr);
#else
    td::ClientManager::set_log_message_callback(0, nullptr);
#endif
    jobject old_log_message_handler = log_message_handler;
    log_message_handler = jobject();
    env->DeleteGlobalRef(old_log_message_handler);
  }

  if (new_log_message_handler) {
    log_message_handler = env->NewGlobalRef(new_log_message_handler);
    if (!log_message_handler) {
      // out of memory
      return;
    }

#ifdef TD_JSON_JAVA
    td_set_log_message_callback(static_cast<int>(max_verbosity_level), on_log_message);
#else
    td::ClientManager::set_log_message_callback(static_cast<int>(max_verbosity_level), on_log_message);
#endif
  }
}

static jint register_native(JavaVM *vm) {
  JNIEnv *env;
  if (vm->GetEnv(reinterpret_cast<void **>(&env), JAVA_VERSION) != JNI_OK) {
    return -1;
  }

  java_vm = vm;

  auto register_method = [env](jclass clazz, std::string name, std::string signature, auto function_ptr) {
    td::jni::register_native_method(env, clazz, std::move(name), std::move(signature),
                                    reinterpret_cast<void *>(function_ptr));
  };

#ifdef TD_JSON_JAVA
  auto client_class = td::jni::get_jclass(env, PACKAGE_NAME "/JsonClient");

  register_method(client_class, "createClientId", "()I", JsonClient_createClientId);
  register_method(client_class, "send", "(ILjava/lang/String;)V", JsonClient_send);
  register_method(client_class, "receive", "(D)Ljava/lang/String;", JsonClient_receive);
  register_method(client_class, "execute", "(Ljava/lang/String;)Ljava/lang/String;", JsonClient_execute);
  register_method(client_class, "setLogMessageHandler", "(IL" PACKAGE_NAME "/JsonClient$LogMessageHandler;)V",
                  Client_nativeClientSetLogMessageHandler);
#else
  auto td_api_class = td::jni::get_jclass(env, PACKAGE_NAME "/TdApi");
  jfieldID commit_hash_field_id =
      td::jni::get_static_field_id(env, td_api_class, "GIT_COMMIT_HASH", "Ljava/lang/String;");
  std::string td_api_version = td::jni::fetch_static_string(env, td_api_class, commit_hash_field_id);
  std::string tdjni_version = td::td_api::get_git_commit_hash();
  if (tdjni_version != td_api_version) {
    td::jni::set_fatal_error(env, "Mismatched TdApi.java (" + td_api_version + ") and tdjni shared library (" +
                                      tdjni_version + ") versions");
    return JAVA_VERSION;
  }

  auto client_class = td::jni::get_jclass(env, PACKAGE_NAME "/Client");
  auto object_class = td::jni::get_jclass(env, PACKAGE_NAME "/TdApi$Object");
  auto function_class = td::jni::get_jclass(env, PACKAGE_NAME "/TdApi$Function");

#define TD_OBJECT "L" PACKAGE_NAME "/TdApi$Object;"
#define TD_FUNCTION "L" PACKAGE_NAME "/TdApi$Function;"
  register_method(client_class, "createNativeClient", "()I", Client_createNativeClient);
  register_method(client_class, "nativeClientSend", "(IJ" TD_FUNCTION ")V", Client_nativeClientSend);
  register_method(client_class, "nativeClientReceive", "([I[J[" TD_OBJECT "D)I", Client_nativeClientReceive);
  register_method(client_class, "nativeClientExecute", "(" TD_FUNCTION ")" TD_OBJECT, Client_nativeClientExecute);
  register_method(client_class, "nativeClientSetLogMessageHandler", "(IL" PACKAGE_NAME "/Client$LogMessageHandler;)V",
                  Client_nativeClientSetLogMessageHandler);

  register_method(object_class, "toString", "()Ljava/lang/String;", Object_toString);

  register_method(function_class, "toString", "()Ljava/lang/String;", Function_toString);
#undef TD_FUNCTION
#undef TD_OBJECT

  td::jni::init_vars(env, PACKAGE_NAME);
  td::td_api::get_package_name_ref() = PACKAGE_NAME;
#endif

  return JAVA_VERSION;
}

}  // namespace td_jni

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *reserved) {
  static jint jni_version = td_jni::register_native(vm);  // call_once
  return jni_version;
}
