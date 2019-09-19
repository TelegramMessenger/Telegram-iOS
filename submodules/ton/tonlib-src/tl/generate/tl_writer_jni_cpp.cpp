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
#include "tl_writer_jni_cpp.h"

#include <cassert>
#include <cstdio>

namespace td {

bool TD_TL_writer_jni_cpp::is_built_in_simple_type(const std::string &name) const {
  return name == "Bool" || name == "Int32" || name == "Int53" || name == "Int64" || name == "Double" ||
         name == "String" || name == "Bytes" || name == "SecureString" || name == "SecureBytes";
}

bool TD_TL_writer_jni_cpp::is_built_in_complex_type(const std::string &name) const {
  return name == "Vector";
}

int TD_TL_writer_jni_cpp::get_parser_type(const tl::tl_combinator *t, const std::string &parser_name) const {
  return 1;
}

int TD_TL_writer_jni_cpp::get_additional_function_type(const std::string &additional_function_name) const {
  return 1;
}

std::vector<std::string> TD_TL_writer_jni_cpp::get_parsers() const {
  std::vector<std::string> parsers;
  parsers.push_back("JNIEnv *env, jobject");
  return parsers;
}

std::vector<std::string> TD_TL_writer_jni_cpp::get_storers() const {
  std::vector<std::string> storers;
  storers.push_back("JNIEnv *env, jobject");
  storers.push_back("td::TlStorerToString");
  return storers;
}

std::vector<std::string> TD_TL_writer_jni_cpp::get_additional_functions() const {
  std::vector<std::string> additional_functions;
  additional_functions.push_back("init_jni_vars");
  return additional_functions;
}

std::string TD_TL_writer_jni_cpp::gen_base_type_class_name(int arity) const {
  assert(arity == 0);
  return "Object";
}

std::string TD_TL_writer_jni_cpp::gen_base_tl_class_name() const {
  return "Object";
}

std::string TD_TL_writer_jni_cpp::gen_class_begin(const std::string &class_name, const std::string &base_class_name,
                                                  bool is_proxy) const {
  return "\n"
         "jclass " +
         class_name + "::Class;\n";
}

std::string TD_TL_writer_jni_cpp::gen_field_definition(const std::string &class_name, const std::string &type_name,
                                                       const std::string &field_name) const {
  return "jfieldID " + class_name + "::" + field_name + "fieldID;\n";
}

std::string TD_TL_writer_jni_cpp::gen_constructor_id_store(std::int32_t id, int storer_type) const {
  return "";
}

std::string TD_TL_writer_jni_cpp::gen_vector_fetch(std::string field_name, const tl::tl_tree_type *t,
                                                   const std::vector<tl::var_description> &vars,
                                                   int parser_type) const {
  std::string vector_type = gen_type_name(t);

  if (vector_type == "bool") {
    assert(false);  // TODO
  }

  std::string fetch_object = "td::jni::fetch_object(env, p, " + field_name + "fieldID)";
  std::string array_type;
  if (vector_type == "std::int32_t") {
    array_type = "jintArray";
  }
  if (vector_type == "std::int64_t") {
    array_type = "jlongArray";
  }
  if (vector_type == "double") {
    array_type = "jdoubleArray";
  }

  if (!array_type.empty()) {
    return "td::jni::fetch_vector(env, (" + array_type + ")" + fetch_object + ");";
  }

  std::string template_type;
  if (vector_type == string_type) {
    template_type = "std::string";
  } else if (vector_type == secure_string_type) {
    template_type = secure_string_type;
  } else if (vector_type.compare(0, 11, "std::vector") == 0) {
    const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(t->children[0]);
    template_type = gen_type_name(child);
    if (template_type.compare(0, 10, "object_ptr") == 0) {
      template_type = gen_main_class_name(child->type);
    }
    template_type = "std::vector<" + template_type + ">";
  } else if (vector_type == bytes_type) {
    std::fprintf(stderr, "Vector of Bytes is not supported\n");
    assert(false);
  } else {
    assert(vector_type.compare(0, 10, "object_ptr") == 0);
    template_type = gen_main_class_name(t->type);
  }
  return "td::jni::FetchVector<" + template_type + ">::fetch(env, (jobjectArray)" + fetch_object + ");";
}

std::string TD_TL_writer_jni_cpp::gen_type_fetch(const std::string &field_name, const tl::tl_tree_type *tree_type,
                                                 const std::vector<tl::var_description> &vars, int parser_type) const {
  const tl::tl_type *t = tree_type->type;
  const std::string &name = t->name;

  assert(!(t->flags & tl::FLAG_DEFAULT_CONSTRUCTOR));
  assert(parser_type == 1);

  if (!(tree_type->flags & tl::FLAG_BARE)) {
    if (is_type_bare(t)) {
      if (field_name != "") {
        std::fprintf(stderr, "Do not use non-bare fields with bare type %s\n", name.c_str());
        //        assert(false);
      }
    }
  } else {
    assert(is_type_bare(t));
  }

  std::string res_begin;
  if (!field_name.empty()) {
    res_begin = field_name + " = ";
  }

  std::string res;
  assert(name != "#");
  if (field_name.empty()) {
    if (name == "Bool") {
      return "env->CallObjectMethod(p, td::jni::BooleanGetValueMethodID)";
    } else if (name == "Int32") {
      return "env->CallObjectMethod(p, td::jni::IntegerGetValueMethodID)";
    } else if (name == "Int53" || name == "Int64") {
      return "env->CallObjectMethod(p, td::jni::LongGetValueMethodID)";
    } else if (name == "Double") {
      return "env->CallObjectMethod(p, td::jni::DoubleGetValueMethodID)";
    } else if (name == "String") {
      return "td::jni::from_jstring(env, (jstring)p)";
    } else if (name == "Bytes") {
      return "td::jni::from_bytes(env, (jbyteArray)p)";
    } else if (name == "SecureString") {
      return "td::jni::from_jstring_secure(env, (jstring)p)";
    } else if (name == "SecureBytes") {
      return "td::jni::from_bytes_secure(env, (jbyteArray)p)";
    }
  }

  if (name == "Bool") {
    res = "(env->GetBooleanField(p, " + field_name + "fieldID) != 0)";
  } else if (name == "Int32") {
    res = "env->GetIntField(p, " + field_name + "fieldID)";
  } else if (name == "Int53" || name == "Int64") {
    res = "env->GetLongField(p, " + field_name + "fieldID)";
  } else if (name == "Double") {
    res = "env->GetDoubleField(p, " + field_name + "fieldID)";
  } else if (name == "String") {
    res = "td::jni::fetch_string(env, p, " + field_name + "fieldID)";
  } else if (name == "Bytes") {
    res = "td::jni::from_bytes(env, (jbyteArray)td::jni::fetch_object(env, p, " + field_name + "fieldID))";
  } else if (name == "SecureString") {
    res = "td::jni::fetch_string_secure(env, p, " + field_name + "fieldID)";
  } else if (name == "SecureBytes") {
    res = "td::jni::from_bytes_secure(env, (jbyteArray)td::jni::fetch_object(env, p, " + field_name + "fieldID))";
  } else if (name == "Vector") {
    const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);
    res = gen_vector_fetch(field_name, child, vars, parser_type);
  } else {
    if (field_name == "") {
      return gen_main_class_name(tree_type->type) + "::fetch(env, p)";
    }
    res = "td::jni::fetch_tl_object<" + gen_main_class_name(tree_type->type) + ">(env, td::jni::fetch_object(env, p, " +
          field_name + "fieldID));";
  }
  return res_begin + res;
}

std::string TD_TL_writer_jni_cpp::gen_field_fetch(int field_num, const tl::arg &a,
                                                  std::vector<tl::var_description> &vars, bool flat,
                                                  int parser_type) const {
  assert(parser_type >= 0);
  std::string field_name = (parser_type == 0 ? (field_num == 0 ? ": " : ", ") : "res->") + gen_field_name(a.name);

  assert(a.exist_var_num == -1);
  if (a.type->get_type() == tl::NODE_TYPE_VAR_TYPE) {
    assert(parser_type == 1);

    const tl::tl_tree_var_type *t = static_cast<const tl::tl_tree_var_type *>(a.type);
    assert(a.flags == tl::FLAG_EXCL);

    assert(a.var_num == -1);

    assert(t->var_num >= 0);
    assert(vars[t->var_num].is_type);
    assert(!vars[t->var_num].is_stored);
    vars[t->var_num].is_stored = true;

    assert(false && "not supported");
    return "  " + field_name + " = " + gen_base_function_class_name() + "::fetch(env, p);\n";
  }

  assert(!(a.flags & tl::FLAG_EXCL));
  assert(!(a.flags & tl::FLAG_OPT_VAR));

  if (flat) {
    //    TODO
    //    return gen_field_fetch(const tl::arg &a, std::vector<tl::var_description> &vars, int num, bool flat);
  }

  assert(a.var_num == -1);

  assert(a.type->get_type() == tl::NODE_TYPE_TYPE);
  const tl::tl_tree_type *tree_type = static_cast<tl::tl_tree_type *>(a.type);

  assert(parser_type != 0);
  return "  " + gen_type_fetch(field_name, tree_type, vars, parser_type) + ";\n";
}

std::string TD_TL_writer_jni_cpp::get_pretty_field_name(std::string field_name) const {
  return gen_java_field_name(TD_TL_writer_cpp::get_pretty_field_name(field_name));
}

std::string TD_TL_writer_jni_cpp::get_pretty_class_name(std::string class_name) const {
  if (class_name == "vector") {
    return "Array";
  }
  return gen_basic_java_class_name(class_name);
}

std::string TD_TL_writer_jni_cpp::gen_vector_store(const std::string &field_name, const tl::tl_tree_type *t,
                                                   const std::vector<tl::var_description> &vars,
                                                   int storer_type) const {
  if (storer_type == 1) {
    return TD_TL_writer_cpp::gen_vector_store(field_name, t, vars, storer_type);
  }

  std::string vector_type = gen_type_name(t);

  if (vector_type == "bool") {
    assert(false);  // TODO
  }
  if (vector_type == "std::int32_t" || vector_type == "std::int64_t" || vector_type == "double" ||
      vector_type == string_type || vector_type == secure_string_type ||
      vector_type.compare(0, 11, "std::vector") == 0 || vector_type.compare(0, 10, "object_ptr") == 0) {
    return "{ "
           "auto arr_tmp_ = td::jni::store_vector(env, " +
           field_name +
           "); "
           "if (arr_tmp_) { "
           "env->SetObjectField(s, " +
           field_name +
           "fieldID, arr_tmp_); "
           "env->DeleteLocalRef(arr_tmp_); "
           "} }";
  }
  if (vector_type == bytes_type) {
    std::fprintf(stderr, "Vector of Bytes is not supported\n");
    assert(false);
  }

  assert(false);
  return "";
}

std::string TD_TL_writer_jni_cpp::gen_type_store(const std::string &field_name, const tl::tl_tree_type *tree_type,
                                                 const std::vector<tl::var_description> &vars, int storer_type) const {
  const tl::tl_type *t = tree_type->type;
  const std::string &name = t->name;

  assert(!field_name.empty());

  assert(!(t->flags & tl::FLAG_DEFAULT_CONSTRUCTOR));

  if (!(tree_type->flags & tl::FLAG_BARE)) {
    if (storer_type == 0) {
      if (is_type_bare(t)) {
        std::fprintf(stderr, "Do not use non-bare fields with bare type %s\n", name.c_str());
        //        assert(false);
      }
    }
  } else {
    assert(is_type_bare(t));
  }

  std::string res;
  if (name == "Int32" || name == "Int53" || name == "Int64" || name == "Double" || name == "Bool" || name == "String" ||
      name == "SecureString") {
    if (storer_type == 1) {
      res = "s.store_field(\"" + get_pretty_field_name(field_name) + "\", " + field_name + ");";
    } else if (name == "Bool") {
      res = "env->SetBooleanField(s, " + field_name + "fieldID, " + field_name + ");";
    } else if (name == "Int32") {
      res = "env->SetIntField(s, " + field_name + "fieldID, " + field_name + ");";
    } else if (name == "Int53" || name == "Int64") {
      res = "env->SetLongField(s, " + field_name + "fieldID, " + field_name + ");";
    } else if (name == "Double") {
      res = "env->SetDoubleField(s, " + field_name + "fieldID, " + field_name + ");";
    } else if (name == "String") {
      res = "{ jstring nextString = td::jni::to_jstring(env, " + field_name +
            "); if (nextString) { env->SetObjectField(s, " + field_name +
            "fieldID, nextString); env->DeleteLocalRef(nextString); } }";
    } else if (name == "SecureString") {
      res = "{ jstring nextString = td::jni::to_jstring_secure(env, " + field_name +
            "); if (nextString) { env->SetObjectField(s, " + field_name +
            "fieldID, nextString); env->DeleteLocalRef(nextString); } }";
    } else {
      assert(false);
    }
  } else if (name == "Bytes") {
    if (storer_type == 1) {
      res = "s.store_bytes_field(\"" + get_pretty_field_name(field_name) + "\", " + field_name + ");";
    } else {
      res = "{ jbyteArray nextBytes = td::jni::to_bytes(env, " + field_name +
            "); if (nextBytes) { env->SetObjectField(s, " + field_name +
            "fieldID, nextBytes); env->DeleteLocalRef(nextBytes); } }";
    }
  } else if (name == "SecureBytes") {
    if (storer_type == 1) {
      res = "s.store_bytes_field(\"" + get_pretty_field_name(field_name) + "\", " + field_name + ");";
    } else {
      res = "{ jbyteArray nextBytes = td::jni::to_bytes_secure(env, " + field_name +
            "); if (nextBytes) { env->SetObjectField(s, " + field_name +
            "fieldID, nextBytes); env->DeleteLocalRef(nextBytes); } }";
    }
  } else if (name == "Vector") {
    const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);
    res = gen_vector_store(field_name, child, vars, storer_type);
  } else {
    if (storer_type == 1) {
      res = "if (" + field_name + " == nullptr) { s.store_field(\"" + get_pretty_field_name(field_name) +
            "\", \"null\"); } else { " + field_name + "->store(s, \"" + get_pretty_field_name(field_name) + "\"); }";
    } else {
      res = "if (" + field_name + " != nullptr) { jobject next; " + field_name +
            "->store(env, next); if (next) { env->SetObjectField(s, " + field_name +
            "fieldID, next); env->DeleteLocalRef(next); } }";
    }
    assert(tree_type->children.empty());
  }
  return res;
}

std::string TD_TL_writer_jni_cpp::gen_field_store(const tl::arg &a, std::vector<tl::var_description> &vars, bool flat,
                                                  int storer_type) const {
  std::string field_name = gen_field_name(a.name);
  std::string shift = storer_type == 1 ? "    " : "  ";

  assert(a.exist_var_num == -1);
  if (a.type->get_type() == tl::NODE_TYPE_VAR_TYPE) {
    const tl::tl_tree_var_type *t = static_cast<const tl::tl_tree_var_type *>(a.type);
    assert(a.flags == tl::FLAG_EXCL);

    assert(a.var_num == -1);

    assert(t->var_num >= 0);
    assert(!vars[t->var_num].is_stored);
    vars[t->var_num].is_stored = true;
    assert(vars[t->var_num].is_type);

    assert(false && "not supported");
    return shift + field_name + "->store(env, s);\n";
  }

  assert(!(a.flags & tl::FLAG_EXCL));
  assert(!(a.flags & tl::FLAG_OPT_VAR));

  if (flat) {
    //    TODO
    //    return gen_field_store(const tl::arg &a, std::vector<tl::var_description> &vars, bool flat, int storer_type);
  }

  assert(a.var_num == -1);
  assert(a.type->get_type() == tl::NODE_TYPE_TYPE);
  const tl::tl_tree_type *tree_type = static_cast<tl::tl_tree_type *>(a.type);
  return shift + gen_type_store(field_name, tree_type, vars, storer_type) + "\n";
}

std::string TD_TL_writer_jni_cpp::gen_get_id(const std::string &class_name, std::int32_t id, bool is_proxy) const {
  if (is_proxy) {
    return "";
  }
  return "\nconst std::int32_t " + class_name + "::ID;\n";
}

std::string TD_TL_writer_jni_cpp::gen_fetch_function_begin(const std::string &parser_name,
                                                           const std::string &class_name,
                                                           const std::string &parent_class_name, int arity,
                                                           std::vector<tl::var_description> &vars,
                                                           int parser_type) const {
  for (std::size_t i = 0; i < vars.size(); i++) {
    assert(vars[i].is_stored == false);
  }

  std::string fetched_type = "object_ptr<" + class_name + "> ";
  std::string returned_type = "object_ptr<" + parent_class_name + "> ";
  assert(arity == 0);

  assert(parser_type != 0);

  return "\n" + returned_type + class_name + "::fetch(" + parser_name + " &p) {\n" +
         (parser_type == -1 ? ""
                            : "  if (p == nullptr) return nullptr;\n"
                              "  " +
                                  fetched_type + "res = make_object<" + class_name + ">();\n");
}

std::string TD_TL_writer_jni_cpp::gen_fetch_function_end(bool has_parent, int field_num,
                                                         const std::vector<tl::var_description> &vars,
                                                         int parser_type) const {
  for (std::size_t i = 0; i < vars.size(); i++) {
    assert(vars[i].is_stored);
  }

  assert(parser_type != 0);

  if (parser_type == -1) {
    return "}\n";
  }

  return "  return " + std::string(has_parent ? "std::move(res)" : "res") +
         ";\n"
         "}\n";
}

std::string TD_TL_writer_jni_cpp::gen_fetch_function_result_begin(const std::string &parser_name,
                                                                  const std::string &class_name,
                                                                  const tl::tl_tree *result) const {
  return "\n" + class_name + "::ReturnType " + class_name + "::fetch_result(" + parser_name +
         " &p) {\n"
         "  if (p == nullptr) return ReturnType();\n" +
         "  return ";
}

std::string TD_TL_writer_jni_cpp::gen_fetch_function_result_end() const {
  return ";\n"
         "}\n";
}

std::string TD_TL_writer_jni_cpp::gen_fetch_function_result_any_begin(const std::string &parser_name,
                                                                      const std::string &class_name,
                                                                      bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_jni_cpp::gen_fetch_function_result_any_end(bool is_proxy) const {
  return "";
}

std::string TD_TL_writer_jni_cpp::gen_store_function_begin(const std::string &storer_name,
                                                           const std::string &class_name, int arity,
                                                           std::vector<tl::var_description> &vars,
                                                           int storer_type) const {
  for (std::size_t i = 0; i < vars.size(); i++) {
    vars[i].is_stored = false;
  }

  if (storer_type == -1) {
    return "";
  }

  assert(arity == 0);
  return "\n"
         "void " +
         class_name + "::store(" + storer_name + " &s" +
         std::string(storer_type <= 0 ? "" : ", const char *field_name") + ") const {\n" +
         (storer_type <= 0 ? "  s = env->AllocObject(Class);\n"
                             "  if (!s) { return; }\n"
                           : "  if (!LOG_IS_STRIPPED(ERROR)) {\n"
                             "    s.store_class_begin(field_name, \"" +
                                 get_pretty_class_name(class_name) + "\");\n");
}

std::string TD_TL_writer_jni_cpp::gen_fetch_switch_begin() const {
  return "  if (p == nullptr) { return nullptr; }\n"
         "  auto id = env->CallIntMethod(p, td::jni::GetConstructorID);\n"
         "  switch (id) {\n";
}

std::string TD_TL_writer_jni_cpp::gen_fetch_switch_case(const tl::tl_combinator *t, int arity) const {
  assert(arity == 0);
  return "    case " + gen_class_name(t->name) +
         "::ID:\n"
         "      return " +
         gen_class_name(t->name) + "::fetch(env, p);\n";
}

std::string TD_TL_writer_jni_cpp::gen_fetch_switch_end() const {
  return "    default:\n"
         "      LOG(WARNING) << \"Unknown constructor found: \" << id;\n"
         "      return nullptr;\n"
         "  }\n";
}

std::string TD_TL_writer_jni_cpp::gen_java_field_name(std::string name) const {
  std::string result;
  bool next_to_upper = false;
  for (std::size_t i = 0; i < name.size(); i++) {
    if (!is_alnum(name[i])) {
      next_to_upper = true;
      continue;
    }
    if (next_to_upper) {
      result += to_upper(name[i]);
      next_to_upper = false;
    } else {
      result += name[i];
    }
  }
  return result;
}

std::string TD_TL_writer_jni_cpp::gen_basic_java_class_name(std::string name) const {
  std::string result;
  bool next_to_upper = true;
  for (std::size_t i = 0; i < name.size(); i++) {
    if (!is_alnum(name[i])) {
      next_to_upper = true;
      continue;
    }
    if (next_to_upper) {
      result += to_upper(name[i]);
      next_to_upper = false;
    } else {
      result += name[i];
    }
  }
  return result;
}

std::string TD_TL_writer_jni_cpp::gen_java_class_name(std::string name) const {
  return "(PSLICE() << package_name << \"/TonApi$" + gen_basic_java_class_name(name) + "\").c_str()";
}

std::string TD_TL_writer_jni_cpp::gen_type_signature(const tl::tl_tree_type *tree_type) const {
  const tl::tl_type *t = tree_type->type;
  const std::string &name = t->name;

  assert(name != "#");
  assert(name != gen_base_tl_class_name());
  if (name == "Bool") {
    return "Z";
  } else if (name == "Int32") {
    return "I";
  } else if (name == "Int53" || name == "Int64") {
    return "J";
  } else if (name == "Double") {
    return "D";
  } else if (name == "String" || name == "SecureString") {
    return "Ljava/lang/String;";
  } else if (name == "Bytes" || name == "SecureBytes") {
    return "[B";
  } else if (name == "Vector") {
    const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);
    return "[" + gen_type_signature(child);
  } else {
    return "L%PACKAGE_NAME%/TonApi$" + gen_basic_java_class_name(gen_main_class_name(t)) + ";";
  }
  assert(false);
  return "";
}

std::string TD_TL_writer_jni_cpp::gen_additional_function(const std::string &function_name, const tl::tl_combinator *t,
                                                          bool is_function) const {
  assert(function_name == "init_jni_vars");
  std::string class_name = gen_class_name(t->name);
  std::string class_name_class = "Class";
  std::string res =
      "\n"
      "void " +
      class_name + "::" + function_name +
      "(JNIEnv *env, const char *package_name) {\n"
      "  " +
      class_name_class + " = td::jni::get_jclass(env, " + gen_java_class_name(gen_class_name(t->name)) + ");\n";

  if (t->args.size()) {
    for (std::size_t i = 0; i < t->args.size(); i++) {
      const tl::arg &a = t->args[i];
      assert(a.type->get_type() == tl::NODE_TYPE_TYPE);
      const tl::tl_tree_type *tree_type = static_cast<tl::tl_tree_type *>(a.type);

      std::string field_name = gen_field_name(a.name);
      assert(field_name.size());
      std::string java_field_name = gen_java_field_name(std::string(field_name, 0, field_name.size() - 1));

      std::string type_signature = gen_type_signature(tree_type);
      if (type_signature.find("%PACKAGE_NAME%") == std::string::npos) {
        type_signature = '"' + type_signature + '"';
      } else {
        std::string new_type_signature = "(PSLICE()";
        std::size_t pos = type_signature.find("%PACKAGE_NAME%");
        while (pos != std::string::npos) {
          new_type_signature += " << \"" + type_signature.substr(0, pos) + "\" << package_name";
          type_signature = type_signature.substr(pos + 14);
          pos = type_signature.find("%PACKAGE_NAME%");
        }
        if (!type_signature.empty()) {
          new_type_signature += " << \"" + type_signature + "\"";
        }
        type_signature = new_type_signature + ").c_str()";
      }
      res += "  " + field_name + "fieldID = td::jni::get_field_id(env, " + class_name_class + ", \"" + java_field_name +
             "\", " + type_signature + ");\n";
    }
  }
  res += "}\n";
  return res;
}

std::string TD_TL_writer_jni_cpp::gen_additional_proxy_function_begin(const std::string &function_name,
                                                                      const tl::tl_type *type,
                                                                      const std::string &class_name, int arity,
                                                                      bool is_function) const {
  assert(function_name == "init_jni_vars");
  assert(arity == 0);
  return "\n"
         "void " +
         class_name + "::" + function_name +
         "(JNIEnv *env, const char *package_name) {\n"
         "  Class = td::jni::get_jclass(env, " +
         gen_java_class_name(class_name) + ");\n";
}

std::string TD_TL_writer_jni_cpp::gen_additional_proxy_function_case(const std::string &function_name,
                                                                     const tl::tl_type *type,
                                                                     const std::string &class_name, int arity) const {
  assert(function_name == "init_jni_vars");
  assert(arity == 0);
  return "  " + class_name + "::" + function_name + "(env, package_name);\n";
}

std::string TD_TL_writer_jni_cpp::gen_additional_proxy_function_case(const std::string &function_name,
                                                                     const tl::tl_type *type,
                                                                     const tl::tl_combinator *t, int arity,
                                                                     bool is_function) const {
  assert(function_name == "init_jni_vars");
  assert(arity == 0);
  return "  " + gen_class_name(t->name) + "::" + function_name + "(env, package_name);\n";
}

std::string TD_TL_writer_jni_cpp::gen_additional_proxy_function_end(const std::string &function_name,
                                                                    const tl::tl_type *type, bool is_function) const {
  assert(function_name == "init_jni_vars");
  return "}\n";
}

}  // namespace td
