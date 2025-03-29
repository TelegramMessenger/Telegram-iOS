//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "tl_writer_jni_h.h"

#include <cassert>

namespace td {

bool TD_TL_writer_jni_h::is_built_in_simple_type(const std::string &name) const {
  return name == "Bool" || name == "Int32" || name == "Int53" || name == "Int64" || name == "Double" ||
         name == "String" || name == "Bytes";
}

bool TD_TL_writer_jni_h::is_built_in_complex_type(const std::string &name) const {
  return name == "Vector";
}

int TD_TL_writer_jni_h::get_additional_function_type(const std::string &additional_function_name) const {
  if (additional_function_name == "init_jni_vars") {
    return 1;
  }
  return TD_TL_writer_h::get_additional_function_type(additional_function_name);
}

int TD_TL_writer_jni_h::get_parser_type(const tl::tl_combinator *t, const std::string &parser_name) const {
  return 1;
}

std::vector<std::string> TD_TL_writer_jni_h::get_parsers() const {
  std::vector<std::string> parsers;
  parsers.push_back("JNIEnv *env, jobject");
  return parsers;
}

std::vector<std::string> TD_TL_writer_jni_h::get_storers() const {
  std::vector<std::string> storers;
  storers.push_back("JNIEnv *env, jobject");
  storers.push_back("TlStorerToString");
  return storers;
}

std::vector<std::string> TD_TL_writer_jni_h::get_additional_functions() const {
  std::vector<std::string> additional_functions = TD_TL_writer_h::get_additional_functions();
  additional_functions.push_back("init_jni_vars");
  return additional_functions;
}

std::string TD_TL_writer_jni_h::gen_base_type_class_name(int arity) const {
  assert(arity == 0);
  return "Object";
}

std::string TD_TL_writer_jni_h::gen_base_tl_class_name() const {
  return "Object";
}

std::string TD_TL_writer_jni_h::gen_output_begin(const std::string &additional_imports) const {
  std::string ext_include_str;
  for (auto &it : ext_include) {
    ext_include_str += "#include " + it + "\n";
  }
  return "#pragma once\n\n"
         "#include \"td/tl/TlObject.h\"\n\n"
         "#include <cstdint>\n"
         "#include <utility>\n"
         "#include <vector>\n\n"
         "#include <jni.h>\n\n" +
         ext_include_str + "\n" + additional_imports +

         "namespace td {\n" + forward_declaration("TlStorerToString") +
         "\n"
         "namespace " +
         tl_name + " {\n\n";
}

std::string TD_TL_writer_jni_h::gen_output_begin_once() const {
  std::string result = TD_TL_writer_h::gen_output_begin_once();
  std::string old_base_object = "using BaseObject = ::td::TlObject";
  std::size_t pos = result.find(old_base_object);
  assert(pos != std::string::npos);
  result.replace(pos, old_base_object.size(),
                 "class " + gen_base_tl_class_name() +
                     ";\n"
                     "using BaseObject = " +
                     gen_base_tl_class_name());
  return result + "const char *&get_package_name_ref();\nconst char *get_git_commit_hash();\n\n";
}

std::string TD_TL_writer_jni_h::gen_class_begin(const std::string &class_name, const std::string &base_class_name,
                                                bool is_proxy, const tl::tl_tree *result) const {
  if (class_name == gen_base_tl_class_name()) {
    return "class " + class_name +
           " {\n"
           " public:\n"
           "  virtual ~" +
           class_name +
           "() {\n"
           "  }\n\n"
           "  virtual void store(JNIEnv *env, jobject &s) const {\n"
           "  }\n\n"
           "  virtual void store(TlStorerToString &s, const char *field_name) const = 0;\n\n"
           "  static jclass Class;\n";
  }
  return TD_TL_writer_h::gen_class_begin(class_name, base_class_name, is_proxy, result) + "  static jclass Class;\n";
}

std::string TD_TL_writer_jni_h::gen_field_definition(const std::string &class_name, const std::string &type_name,
                                                     const std::string &field_name) const {
  return TD_TL_writer_h::gen_field_definition(class_name, type_name, field_name) + "  static jfieldID " + field_name +
         "fieldID;\n";
}

std::string TD_TL_writer_jni_h::gen_additional_function(const std::string &function_name, const tl::tl_combinator *t,
                                                        bool is_function) const {
  if (function_name == "init_jni_vars") {
    return "\n"
           "  static void " +
           function_name + "(JNIEnv *env);\n";
  }

  return TD_TL_writer_h::gen_additional_function(function_name, t, is_function);
}

std::string TD_TL_writer_jni_h::gen_additional_proxy_function_begin(const std::string &function_name,
                                                                    const tl::tl_type *type,
                                                                    const std::string &class_name, int arity,
                                                                    bool is_function) const {
  if (function_name == "init_jni_vars") {
    return "\n"
           "  static void " +
           function_name + "(JNIEnv *env);\n";
  }

  return TD_TL_writer_h::gen_additional_proxy_function_begin(function_name, type, class_name, arity, is_function);
}

std::string TD_TL_writer_jni_h::gen_additional_proxy_function_case(const std::string &function_name,
                                                                   const tl::tl_type *type,
                                                                   const std::string &class_name, int arity) const {
  if (function_name == "init_jni_vars") {
    return "";
  }

  return TD_TL_writer_h::gen_additional_proxy_function_case(function_name, type, class_name, arity);
}

std::string TD_TL_writer_jni_h::gen_additional_proxy_function_case(const std::string &function_name,
                                                                   const tl::tl_type *type, const tl::tl_combinator *t,
                                                                   int arity, bool is_function) const {
  if (function_name == "init_jni_vars") {
    return "";
  }

  return TD_TL_writer_h::gen_additional_proxy_function_case(function_name, type, t, arity, is_function);
}

std::string TD_TL_writer_jni_h::gen_additional_proxy_function_end(const std::string &function_name,
                                                                  const tl::tl_type *type, bool is_function) const {
  if (function_name == "init_jni_vars") {
    return "";
  }

  return TD_TL_writer_h::gen_additional_proxy_function_end(function_name, type, is_function);
}

}  // namespace td
