//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/tl/tl_writer.h"

#include <cassert>
#include <cstdint>
#include <sstream>
#include <string>
#include <vector>

namespace td {

class TlWriterCCommon final : public tl::TL_writer {
  int is_header_;

 public:
  TlWriterCCommon(const std::string &name, int is_header) : TL_writer(name), is_header_(is_header) {
  }

  int get_max_arity() const final {
    return 0;
  }

  bool is_built_in_simple_type(const std::string &name) const final {
    return name == "Bool" || name == "Int32" || name == "Int53" || name == "Int64" || name == "Double" ||
           name == "String" || name == "Bytes";
  }
  bool is_built_in_complex_type(const std::string &name) const final {
    return name == "Vector";
  }
  bool is_type_bare(const tl::tl_type *t) const final {
    return t->simple_constructors <= 1 || (is_built_in_simple_type(t->name) && t->name != "Bool") ||
           is_built_in_complex_type(t->name);
  }

  std::vector<std::string> get_parsers() const final {
    return {};
  }
  int get_parser_type(const tl::tl_combinator *t, const std::string &name) const final {
    return 0;
  }
  std::vector<std::string> get_storers() const final {
    return {};
  }
  std::vector<std::string> get_additional_functions() const final {
    return {"TdConvertToInternal", "TdConvertFromInternal", "TdSerialize",    "TdToString",
            "TdDestroyObject",     "TdStackStorer",         "TdStackFetcher", "enum"};
  }
  int get_storer_type(const tl::tl_combinator *t, const std::string &name) const final {
    return name == "to_string" || name == "to_cpp_string";
  }

  std::string gen_base_tl_class_name() const final {
    return "Object";
  }
  std::string gen_base_type_class_name(int arity) const final {
    assert(arity == 0);
    return "Object";
  }
  std::string gen_base_function_class_name() const final {
    return "Function";
  }

  static std::string to_camelCase(const std::string &name) {
    return to_cCamelCase(name, false);
  }
  static std::string to_CamelCase(const std::string &name) {
    return to_cCamelCase(name, true);
  }
  static std::string to_cCamelCase(const std::string &name, bool flag) {
    bool next_to_upper = flag;
    std::string result;
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

  std::string gen_native_field_name(std::string name) const {
    for (std::size_t i = 0; i < name.size(); i++) {
      if (!is_alnum(name[i])) {
        name[i] = '_';
      }
    }
    assert(name.size() > 0);
    assert(name[name.size() - 1] != '_');
    return name + "_";
  }

  std::string gen_native_class_name(std::string name) const {
    if (name == "Object") {
      assert(false);
    }
    if (name == "#") {
      return "int";
    }
    for (std::size_t i = 0; i < name.size(); i++) {
      if (!is_alnum(name[i])) {
        name[i] = '_';
      }
    }
    return name;
  }

  std::string gen_class_name(std::string name) const final {
    if (name == "Object" || name == "#") {
      assert(false);
    }
    return to_CamelCase(name);
  }
  std::string gen_field_name(std::string name) const final {
    return gen_native_field_name(name);
  }

  std::string gen_native_type_name(const tl::tl_tree_type *tree_type, bool storage) const {
    const tl::tl_type *t = tree_type->type;
    const std::string &name = t->name;

    if (name == "#") {
      assert(false);
    }
    if (name == "Bool") {
      return "bool";
    }
    if (name == "Int32") {
      return "std::int32_t";
    }
    if (name == "Int53" || name == "Int64") {
      return "std::int64_t";
    }
    if (name == "Double") {
      return "double";
    }
    if (name == "String") {
      return "std::string";
    }
    if (name == "Bytes") {
      return "std::string";
    }

    if (name == "Vector") {
      assert(t->arity == 1);
      assert(tree_type->children.size() == 1);
      assert(tree_type->children[0]->get_type() == tl::NODE_TYPE_TYPE);
      const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);

      return "std::vector<" + gen_native_type_name(child, storage) + ">";
    }

    assert(!is_built_in_simple_type(name) && !is_built_in_complex_type(name));

    for (std::size_t i = 0; i < tree_type->children.size(); i++) {
      assert(tree_type->children[i]->get_type() == tl::NODE_TYPE_NAT_CONST);
    }

    std::string native_class_name = gen_native_class_name(t->name);
    if (t->constructors_num == 1) {
      native_class_name = gen_native_class_name(t->constructors[0]->name);
    }
    return storage ? "td::td_api::object_ptr<td::td_api::" + native_class_name + ">"
                   : "td::td_api::" + native_class_name + "";
  }

  std::string gen_type_name(const tl::tl_tree_type *tree_type, bool force) const {
    const tl::tl_type *t = tree_type->type;
    const std::string &name = t->name;

    if (name == "#") {
      assert(false);
    }
    if (name == "Bool") {
      return force ? "Int" : "int ";
    }
    if (name == "Int32") {
      return force ? "Int" : "int ";
    }
    if (name == "Int53" || name == "Int64") {
      return force ? "Long" : "long long ";
    }
    if (name == "Double") {
      return force ? "Double" : "double ";
    }
    if (name == "String") {
      return force ? "String" : "char *";
    }
    if (name == "Bytes") {
      return force ? "Bytes" : "struct TdBytes ";
    }

    if (name == "Vector") {
      assert(t->arity == 1);
      assert(tree_type->children.size() == 1);
      assert(tree_type->children[0]->get_type() == tl::NODE_TYPE_TYPE);
      const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);

      return !force ? ("struct TdVector" + gen_type_name(child, true) + " *") : ("Vector" + gen_type_name(child, true));
    }

    assert(!is_built_in_simple_type(name) && !is_built_in_complex_type(name));

    for (std::size_t i = 0; i < tree_type->children.size(); i++) {
      assert(tree_type->children[i]->get_type() == tl::NODE_TYPE_NAT_CONST);
    }

    return !force ? ("struct Td" + gen_main_class_name(t) + " *") : gen_main_class_name(t);
  }
  std::string gen_type_name(const tl::tl_tree_type *tree_type) const final {
    return gen_type_name(tree_type, false);
  }
  std::string gen_output_begin(const std::string &additional_imports) const final {
    if (is_header_ == 1) {
      return "#pragma once\n\n" + additional_imports +
             "#ifdef __cplusplus\n"
             "extern \"C\" {\n"
             "#endif\n";
    }
    if (is_header_ == -1) {
      return "#pragma once\n\n" + gen_import_declaration("td/telegram/td_tdc_api.h", false) +
             gen_import_declaration("td/telegram/td_api.h", false) + "\n" + additional_imports;
    }
    return gen_import_declaration("td/telegram/td_tdc_api_inner.h", false) + "\n" +
           gen_import_declaration("td/utils/format.h", false) + gen_import_declaration("td/utils/logging.h", false) +
           gen_import_declaration("td/utils/misc.h", false) + gen_import_declaration("td/utils/Slice.h", false) + "\n" +
           additional_imports;
  }

  std::string gen_output_begin_once() const final {
    if (is_header_ == 1) {
      return "struct TdBytes {\n"
             "  unsigned char *data;\n"
             "  int len;\n"
             "};\n"
             "#define TDC_VECTOR(tdc_type_name,tdc_type) \\\n"
             "   struct TdVector ## tdc_type_name { \\\n"
             "     int len;\\\n"
             "     tdc_type *data;\\\n"
             "   };\\\n"
             "\n"
             "TDC_VECTOR(Int,int)\n"
             "TDC_VECTOR(Long,long long)\n"
             "TDC_VECTOR(String,char *)\n"
             "TDC_VECTOR(Bytes,struct TdBytes)\n"
             "struct TdStackStorerMethods {\n"
             "  void (*pack_string)(const char *s);\n"
             "  void (*pack_bytes)(const unsigned char *s, int len);\n"
             "  void (*pack_long)(long long x);\n"
             "  void (*pack_double)(double x);\n"
             "  void (*pack_bool)(int x);\n"
             "  void (*new_table)(void);\n"
             "  void (*new_array)(void);\n"
             "  void (*new_field)(const char *name);\n"
             "  void (*new_arr_field)(int idx);\n"
             "};\n"
             "struct TdStackFetcherMethods {\n"
             "  char *(*get_string)(void);\n"
             "  unsigned char *(*get_bytes)(int *len);\n"
             "  long long (*get_long)(void);\n"
             "  double (*get_double)(void);\n"
             "  void (*pop)(void);\n"
             "  void (*get_field)(const char *name);\n"
             "  void (*get_arr_field)(int idx);\n"
             "  int (*get_arr_size)(void);\n"
             "  int (*is_nil)(void);\n"
             "};\n";
    }
    return std::string();
  }

  std::string gen_output_end() const final {
    if (is_header_ == 1) {
      return "#ifdef __cplusplus\n"
             "}\n"
             "#endif\n";
    } else if (is_header_ == -1) {
      return "";
    }
    return "";
  }

  std::string gen_import_declaration(const std::string &name, bool is_system) const final {
    if (is_system) {
      return "#include <" + name + ">\n";
    } else {
      return "#include \"" + name + "\"\n";
    }
  }

  std::string gen_package_suffix() const final {
    return ".h";
  }

  std::string gen_forward_class_declaration(const std::string &class_name, bool is_proxy) const final {
    if (is_header_ != 1 || class_name == "") {
      return "";
    }
    return "struct Td" + class_name +
           ";\n"
           "struct TdVector" +
           class_name +
           ";\n"
           "struct TdVectorVector" +
           class_name + ";\n";
  }

  std::string gen_class_begin(const std::string &class_name, const std::string &base_class_name, bool is_proxy,
                              const tl::tl_tree *result) const final {
    if (is_header_ != 1 || class_name == "") {
      return "";
    }

    std::string tail = "";
    if (class_name == "Function" || class_name == "Object") {
      tail = "};\n";
    }
    return "TDC_VECTOR(" + class_name + ", struct Td" + class_name +
           " *);\n"
           "TDC_VECTOR(Vector" +
           class_name + ", struct TdVector" + class_name +
           " *);\n"
           "struct Td" +
           class_name + " {\n" + "  int ID;\n  int refcnt;\n" + tail;
  }
  std::string gen_class_end() const final {
    return "";
  }

  std::string gen_field_definition(const std::string &class_name, const std::string &type_name,
                                   const std::string &field_name) const final {
    if (is_header_ != 1 || class_name == "") {
      return "";
    }
    return "  " + type_name + field_name + ";\n";
  }

  std::string gen_store_function_begin(const std::string &storer_name, const std::string &class_name, int arity,
                                       std::vector<tl::var_description> &vars, int storer_type) const final {
    return "";
  }
  std::string gen_store_function_end(const std::vector<tl::var_description> &vars, int storer_type) const final {
    return "";
  }

  std::string gen_constructor_begin(int field_count, const std::string &class_name, bool is_default) const final {
    if (!is_default || is_header_ == -1 || class_name == "") {
      return "";
    }
    std::stringstream ss;
    if (is_header_ == 1) {
      ss << "};\n";
    }
    ss << "struct Td" + gen_class_name(class_name) + " *TdCreateObject" + gen_class_name(class_name) + " (" +
              (field_count ? "" : "void");
    return ss.str();
  }
  std::string gen_constructor_parameter(int field_num, const std::string &class_name, const tl::arg &a,
                                        bool is_default) const final {
    if (!is_default || is_header_ == -1) {
      return "";
    }
    std::stringstream ss;
    auto field_type = gen_field_type(a);
    ss << (field_num == 0 ? "" : ", ");
    ss << field_type << gen_field_name(a.name);
    return ss.str();
  }
  std::string gen_constructor_field_init(int field_num, const std::string &class_name, const tl::arg &a,
                                         bool is_default) const final {
    return "";
  }
  std::string gen_constructor_end(const tl::tl_combinator *t, int field_count, bool is_default) const final {
    if (!is_default || is_header_ == -1) {
      return "";
    }
    if (is_header_ == 1) {
      return ");\n";
    }
    std::stringstream ss;
    ss << ") {\n";
    auto type_name = "struct Td" + gen_class_name(t->name);
    ss << "  auto var = new " << type_name << " ();\n";
    ss << "  var->ID = CODE_" << gen_class_name(t->name) << ";\n";
    ss << "  var->refcnt = 1;\n";
    for (auto &it : t->args) {
      const tl::tl_tree_type *T = static_cast<const tl::tl_tree_type *>(it.type);
      auto field_name = gen_field_name(it.name);
      if (T->type->name == "String") {
        ss << "  var->" << field_name << " = (" << field_name << ") ? td::str_dup (td::Slice (" << field_name
           << ")) : nullptr;\n";
      } else {
        ss << "  var->" << field_name << " = " << field_name << ";\n";
      }
    }
    ss << "  return var;\n}\n";
    return ss.str();
  }
  std::string gen_additional_function(const std::string &function_name, const tl::tl_combinator *t,
                                      bool is_function) const final {
    std::stringstream ss;
    if (function_name == "enum") {
      return ss.str();
    }
    if (function_name == "TdDestroyObject") {
      auto class_name = gen_class_name(t->name);
      if (is_header_ == 1) {
        ss << "void TdDestroyObject" + class_name + " (struct Td" + class_name + " *var);\n";
        return ss.str();
      }
      if (is_header_ == -1) {
        ss << "void TdDestroyObject (struct Td" + class_name + " *var);\n";
        return ss.str();
      }
      ss << "void TdDestroyObject" + class_name + " (struct Td" + class_name + " *var) {\n";
      ss << "  TdDestroyObject (var);\n";
      ss << "}\n";
      ss << "void TdDestroyObject (struct Td" + class_name + " *var)";

      file_store_methods_destroy M(this);
      gen_object_store(ss, t, M);
      return ss.str();
    }
    if (function_name == "TdSerialize" && is_header_ != -1) {
      auto class_name = gen_class_name(t->name);
      ss << "char *TdSerialize" + class_name + " (struct Td" + class_name + " *var)";
      if (is_header_ == 1) {
        ss << ";\n";
        return ss.str();
      }
      ss << " {\n";
      ss << "  return td::str_dup (TdToString (var));\n";
      ss << "}\n";
      return ss.str();
    }
    if (function_name == "TdToString" && is_header_ != 1) {
      auto class_name = gen_class_name(t->name);
      ss << "std::string TdToString (struct Td" + class_name + " *var)";
      if (is_header_ == -1) {
        ss << ";\n";
        return ss.str();
      }
      ss << " {\n";
      ss << "  return to_string (TdConvertToInternal (var));\n";
      ss << "}\n";
      return ss.str();
    }
    if (function_name == "TdConvertToInternal" && is_header_ != 1) {
      auto class_name = gen_class_name(t->name);
      auto native_class_name = gen_native_class_name(t->name);
      ss << "td::td_api::object_ptr<td::td_api::" << native_class_name
         << "> TdConvertToInternal (struct Td" + class_name + " *var)";
      if (is_header_ == -1) {
        ss << ";\n";
        return ss.str();
      }
      file_store_methods_to_td M(this);
      gen_object_store(ss, t, M);
      return ss.str();
    }
    if (function_name == "TdConvertFromInternal" && is_header_ != 1) {
      auto class_name = gen_class_name(t->name);
      auto native_class_name = gen_native_class_name(t->name);
      ss << "struct Td" << class_name << " *TdConvertFromInternal (const td::td_api::" << native_class_name
         << " &from)";
      if (is_header_ == -1) {
        ss << ";\n";
        return ss.str();
      }
      file_fetch_methods_from_td M(this);
      gen_object_fetch(ss, t, M);
      return ss.str();
    }
    if (function_name == "TdStackStorer") {
      auto class_name = gen_class_name(t->name);
      if (is_header_ == 1) {
        ss << "void TdStackStorer" + class_name + " (struct Td" + class_name +
                  " *var, struct TdStackStorerMethods *M);\n";
        return ss.str();
      }
      if (is_header_ == -1) {
        ss << "void TdStackStorer (struct Td" + class_name + " *var, struct TdStackStorerMethods *M);\n";
        return ss.str();
      }
      ss << "void TdStackStorer" + class_name + " (struct Td" + class_name +
                " *var, struct TdStackStorerMethods *M) {\n";
      ss << "  TdStackStorer (var, M);\n";
      ss << "}\n";
      ss << "void TdStackStorer (struct Td" + class_name + " *var, struct TdStackStorerMethods *M)";

      file_store_methods_stack M(this);
      gen_object_store(ss, t, M);
      return ss.str();
    }
    if (function_name == "TdStackFetcher" && is_header_ != -1) {
      auto class_name = gen_class_name(t->name);
      ss << "struct Td" << class_name << " *TdStackFetcher" + class_name + " (struct TdStackFetcherMethods *M)";
      if (is_header_ == 1) {
        ss << ";\n";
        return ss.str();
      }

      file_fetch_methods_stack M(this);
      gen_object_fetch(ss, t, M);
      return ss.str();
    }
    return ss.str();
  }

  struct file_store_methods {
    file_store_methods() = default;
    file_store_methods(const file_store_methods &) = delete;
    file_store_methods &operator=(const file_store_methods &) = delete;
    virtual ~file_store_methods() = default;
    virtual void store_simple_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                   std::string type_name) const {
      assert(false);
    }
    virtual void store_common_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                   std::string type_name) const {
      assert(false);
    }
    virtual void store_array_start(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                   const tl::tl_tree_type *tree_type) const {
      assert(false);
    }
    virtual void store_array_el(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                std::string idx) const {
      assert(false);
    }
    virtual void store_array_finish(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                    const tl::tl_tree_type *tree_type) const {
      assert(false);
    }
    virtual void store_nil(std::stringstream &ss, std::string offset) const {
      assert(false);
    }
    virtual std::string store_field_start(std::stringstream &ss, std::string offset, int depth,
                                          const tl::tl_tree_type *tree_type) const {
      assert(false);
      return "";
    }
    virtual void store_field_finish(std::stringstream &ss, std::string offset, std::string res_var) const {
      assert(false);
    }
    virtual void store_arg_finish(std::stringstream &ss, std::string offset, std::string arg_name,
                                  std::string res_var) const {
      assert(false);
    }
    virtual void store_constructor_start(std::stringstream &ss, std::string offset, const tl::tl_combinator *t) const {
    }
    virtual void store_constructor_finish(std::stringstream &ss, std::string offset, const tl::tl_combinator *t,
                                          std::vector<std::string> res_var) const {
      assert(false);
    }
  };

  struct file_store_methods_to_td final : public file_store_methods {
    explicit file_store_methods_to_td(const class TlWriterCCommon *cl) : cl(cl) {
    }
    void store_simple_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           std::string type_name) const final {
      if (type_name == "String") {
        ss << offset << res_var << " = (" << var << ") ? " << var << ": \"\";\n";
      } else if (type_name == "Bytes") {
        ss << offset << res_var << " = std::string ((char *)" << var << ".data, " << var << ".len);\n";
      } else if (type_name == "Bool") {
        ss << offset << res_var << " = " << var << " != 0;\n";
      } else {
        ss << offset << res_var << " = " << var << ";\n";
      }
    }
    void store_common_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           std::string type_name) const final {
      ss << offset << res_var << " = TdConvertToInternal (" << var << ");\n";
    }
    void store_array_start(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           const tl::tl_tree_type *tree_type) const final {
    }
    void store_array_el(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                        std::string idx) const final {
      ss << offset << res_var << ".push_back (std::move (" << var << "));\n";
    }
    void store_array_finish(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                            const tl::tl_tree_type *tree_type) const final {
    }
    void store_nil(std::stringstream &ss, std::string offset) const final {
      ss << offset << "return nullptr;\n";
    }
    std::string store_field_start(std::stringstream &ss, std::string offset, int depth,
                                  const tl::tl_tree_type *tree_type) const final {
      std::string res_var = "v" + int_to_string(depth);
      ss << offset << cl->gen_native_type_name(tree_type, true) << " " << res_var << ";\n";
      return res_var;
    }
    void store_field_finish(std::stringstream &ss, std::string offset, std::string res_var) const final {
    }
    void store_arg_finish(std::stringstream &ss, std::string offset, std::string arg_name,
                          std::string res_var) const final {
    }
    void store_constructor_finish(std::stringstream &ss, std::string offset, const tl::tl_combinator *t,
                                  std::vector<std::string> res_var) const final {
      auto native_class_name = cl->gen_native_class_name(t->name);
      ss << offset << "return td::td_api::make_object<td::td_api::" << native_class_name << ">(";
      bool is_first = true;
      for (auto &var_name : res_var) {
        if (is_first) {
          is_first = false;
        } else {
          ss << ", ";
        }

        ss << "std::move (" << var_name << ")";
      }
      ss << ");\n";
    }
    const class TlWriterCCommon *cl;
  };

  struct file_store_methods_destroy final : public file_store_methods {
    explicit file_store_methods_destroy(const class TlWriterCCommon *cl) : cl(cl) {
    }
    void store_simple_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           std::string type_name) const final {
      if (type_name == "String") {
        ss << offset << "free (" << var << ");\n";
      } else if (type_name == "Bytes") {
        ss << offset << "delete[]" << var << ".data;\n";
      }
    }
    void store_common_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           std::string type_name) const final {
      ss << offset << "TdDestroyObject (" << var << ");\n";
    }
    void store_array_start(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           const tl::tl_tree_type *tree_type) const final {
    }
    void store_array_el(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                        std::string idx) const final {
    }
    void store_array_finish(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                            const tl::tl_tree_type *tree_type) const final {
      ss << offset << "delete[] " << var << "->data;\n" << offset << "delete " << var << ";\n";
    }
    void store_nil(std::stringstream &ss, std::string offset) const final {
      ss << offset << "return;\n";
    }
    std::string store_field_start(std::stringstream &ss, std::string offset, int depth,
                                  const tl::tl_tree_type *tree_type) const final {
      return "";
    }
    void store_field_finish(std::stringstream &ss, std::string offset, std::string res_var) const final {
    }
    void store_arg_finish(std::stringstream &ss, std::string offset, std::string arg_name,
                          std::string res_var) const final {
    }
    void store_constructor_start(std::stringstream &ss, std::string offset, const tl::tl_combinator *t) const final {
      ss << "#if TD_MSVC\n";
      ss << offset << "static_assert (sizeof (long) == sizeof (var->refcnt), \"Illegal InterlockedDecrement\");\n";
      ss << offset << "int ref = InterlockedDecrement (reinterpret_cast<long *>(&var->refcnt));\n";
      ss << "#else\n";
      ss << offset << "int ref = __sync_add_and_fetch (&var->refcnt, -1);\n";
      ss << "#endif\n";
      ss << offset << "if (ref < 0) {\n";
      ss << offset << "  LOG(FATAL) << \"Negative reference counter in Td C object struct\";\n";
      ss << offset << "}\n";
      ss << offset << "if (ref > 0) {\n";
      ss << offset << "  return;\n";
      ss << offset << "}\n";
    }
    void store_constructor_finish(std::stringstream &ss, std::string offset, const tl::tl_combinator *t,
                                  std::vector<std::string> res_var) const final {
      ss << offset << "delete var;\n";
    }
    const class TlWriterCCommon *cl;
  };
  struct file_store_methods_stack final : public file_store_methods {
    explicit file_store_methods_stack(const class TlWriterCCommon *cl) : cl(cl) {
    }
    void store_simple_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           std::string type_name) const final {
      if (type_name == "String") {
        ss << offset << "M->pack_string (" << var << ");\n";
      } else if (type_name == "Bytes") {
        ss << offset << "M->pack_bytes (" << var << ".data, " << var << ".len);\n";
      } else if (type_name == "Int32" || type_name == "Int53" || type_name == "Int64") {
        ss << offset << "M->pack_long (" << var << ");\n";
      } else if (type_name == "Bool") {
        ss << offset << "M->pack_bool (" << var << ");\n";
      } else if (type_name == "Double") {
        ss << offset << "M->pack_double (" << var << ");\n";
      } else {
        ss << "????" << type_name << "\n";
      }
    }
    void store_common_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           std::string type_name) const final {
      ss << offset << "TdStackStorer (" << var << ", M);\n";
    }
    void store_array_start(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           const tl::tl_tree_type *tree_type) const final {
      ss << offset << "M->new_array ();\n";
    }
    void store_array_el(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                        std::string idx) const final {
      ss << offset << "M->new_arr_field (" << idx << ");\n";
    }
    void store_array_finish(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                            const tl::tl_tree_type *tree_type) const final {
    }
    void store_nil(std::stringstream &ss, std::string offset) const final {
      ss << offset << "M->pack_bool (0);\n" << offset << "return;\n";
    }
    std::string store_field_start(std::stringstream &ss, std::string offset, int depth,
                                  const tl::tl_tree_type *tree_type) const final {
      return "";
    }
    void store_field_finish(std::stringstream &ss, std::string offset, std::string res_var) const final {
    }
    void store_arg_finish(std::stringstream &ss, std::string offset, std::string arg_name,
                          std::string res_var) const final {
      ss << offset << "M->new_field (\"" << arg_name << "\");\n";
    }
    void store_constructor_start(std::stringstream &ss, std::string offset, const tl::tl_combinator *t) const final {
      ss << offset << "M->new_table ();\n";
      auto class_name = cl->gen_class_name(t->name);
      ss << offset << "M->pack_string (\"" << class_name << "\");\n";
      ss << offset << "M->new_field (\"ID\");\n";
    }
    void store_constructor_finish(std::stringstream &ss, std::string offset, const tl::tl_combinator *t,
                                  std::vector<std::string> res_var) const final {
    }
    const class TlWriterCCommon *cl;
  };

  struct file_fetch_methods {
    file_fetch_methods() = default;
    file_fetch_methods(const file_fetch_methods &) = delete;
    file_fetch_methods &operator=(const file_fetch_methods &) = delete;

    virtual ~file_fetch_methods() = default;

    virtual std::string fetch_field_start(std::stringstream &ss, std::string offset, int depth,
                                          const tl::tl_tree_type *tree_type) const {
      assert(false);
      return "";
    }
    virtual void fetch_simple_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                   std::string type_name) const {
      assert(false);
    }
    virtual void fetch_common_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                   const tl::tl_tree_type *tree_type) const {
      assert(false);
    }
    virtual void fetch_array_size(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                  const tl::tl_tree_type *tree_type) const {
      assert(false);
    }
    virtual std::string fetch_array_field_start(std::stringstream &ss, std::string offset, std::string res_var,
                                                std::string var, std::string idx,
                                                const tl::tl_tree_type *tree_type) const {
      assert(false);
      return "";
    }
    virtual std::string fetch_dict_field_start(std::stringstream &ss, std::string offset, std::string res_var,
                                               std::string var, std::string key,
                                               const tl::tl_tree_type *tree_type) const {
      assert(false);
      return "";
    }
    virtual void fetch_field_finish(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                    const tl::tl_tree_type *tree_type) const {
      assert(false);
    }
  };

  struct file_fetch_methods_from_td final : public file_fetch_methods {
    explicit file_fetch_methods_from_td(const class TlWriterCCommon *cl) : cl(cl) {
    }
    std::string fetch_field_start(std::stringstream &ss, std::string offset, int depth,
                                  const tl::tl_tree_type *tree_type) const final {
      return "";
    }
    void fetch_simple_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           std::string type_name) const final {
      if (type_name == "String") {
        ss << offset << res_var << " = (" << var << ".length ()) ? td::str_dup (" << var << ") : nullptr;\n";
      } else if (type_name == "Bytes") {
        ss << offset << res_var << ".len = (int)" << var << ".length ();\n";
        ss << offset << "if (" << res_var << ".len) {\n";
        ss << offset << "  " << res_var << ".data = new unsigned char[" << res_var << ".len];\n";
        ss << offset << "  memcpy (" << res_var << ".data, " << var << ".c_str (), " << res_var << ".len);\n";
        ss << offset << "} else {\n";
        ss << offset << "  " << res_var << ".data = nullptr;\n";
        ss << offset << "}\n";
      } else {
        ss << offset << res_var << " = " << var << ";\n";
      }
    }
    void fetch_common_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           const tl::tl_tree_type *tree_type) const final {
      auto native_type_name = cl->gen_native_type_name(tree_type, false);
      ss << offset << "if (!" << var << ") {\n"
         << offset << "  " << res_var << " = nullptr;\n"
         << offset << "} else {\n"
         << offset << "  " << res_var << " = TdConvertFromInternal (static_cast<const " << native_type_name << " &>(*"
         << var << "));\n"
         << offset << "}\n";
    }
    void fetch_array_size(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                          const tl::tl_tree_type *tree_type) const final {
      ss << offset << res_var << " = (int)" << var << ".size ();\n";
    }
    std::string fetch_array_field_start(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                        std::string idx, const tl::tl_tree_type *tree_type) const final {
      return var + "[" + idx + "]";
    }
    std::string fetch_dict_field_start(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                       std::string key, const tl::tl_tree_type *tree_type) const final {
      return var + "." + key;
    }
    void fetch_field_finish(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                            const tl::tl_tree_type *tree_type) const final {
    }
    const class TlWriterCCommon *cl;
  };

  struct file_fetch_methods_stack final : public file_fetch_methods {
    explicit file_fetch_methods_stack(const class TlWriterCCommon *cl) : cl(cl) {
    }
    std::string fetch_field_start(std::stringstream &ss, std::string offset, int depth,
                                  const tl::tl_tree_type *tree_type) const final {
      return "";
    }
    void fetch_simple_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           std::string type_name) const final {
      if (type_name == "String") {
        ss << offset << res_var << " = M->get_string ();\n";
      } else if (type_name == "Bytes") {
        ss << offset << res_var << ".data = M->get_bytes (&" << res_var << ".len);\n";
      } else if (type_name == "Int32" || type_name == "Bool") {
        ss << offset << res_var << " = (int)M->get_long ();\n";
      } else if (type_name == "Int53" || type_name == "Int64") {
        ss << offset << res_var << " = M->get_long ();\n";
      } else if (type_name == "Double") {
        ss << offset << res_var << " = M->get_double ();\n";
      } else {
        ss << "??????" << type_name << "\n";
      }
    }
    void fetch_common_type(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                           const tl::tl_tree_type *tree_type) const final {
      auto class_name = cl->gen_main_class_name(tree_type->type);
      ss << offset << "if (M->is_nil ()) {\n"
         << offset << "  " << res_var << " = nullptr;\n"
         << offset << "} else {\n"
         << offset << "  " << res_var << " = TdStackFetcher" << class_name << " (M);\n"
         << offset << "}\n";
    }
    void fetch_array_size(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                          const tl::tl_tree_type *tree_type) const final {
      ss << offset << res_var << " = M->get_arr_size ();\n";
    }
    std::string fetch_array_field_start(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                        std::string idx, const tl::tl_tree_type *tree_type) const final {
      ss << offset << "  M->get_arr_field (" << idx << ");\n";
      return "";
    }
    std::string fetch_dict_field_start(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                                       std::string key, const tl::tl_tree_type *tree_type) const final {
      ss << offset << "M->get_field (\"" << key << "\");\n";
      return "";
    }
    void fetch_field_finish(std::stringstream &ss, std::string offset, std::string res_var, std::string var,
                            const tl::tl_tree_type *tree_type) const final {
      ss << offset << "M->pop ();\n";
    }
    const class TlWriterCCommon *cl;
  };

  std::string gen_field_store(std::stringstream &ss, std::string offset, std::string var, int depth,
                              const tl::tl_tree_type *tree_type, const file_store_methods &M) const {
    std::string res_var = M.store_field_start(ss, offset, depth, tree_type);
    if (is_built_in_simple_type(tree_type->type->name)) {
      M.store_simple_type(ss, offset, res_var, var, tree_type->type->name);
    } else if (!is_built_in_complex_type(tree_type->type->name)) {
      M.store_common_type(ss, offset, res_var, var, tree_type->type->name);
    } else {
      const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);

      std::string it = "i" + int_to_string(depth);

      M.store_array_start(ss, offset, res_var, var, tree_type);
      ss << offset << "for (int " << it << " = 0; " << it << " < " << var << "->len; " << it << "++) {\n";
      auto f_res_var = gen_field_store(ss, offset + "  ", var + "->data[" + it + "]", depth + 1, child, M);
      M.store_array_el(ss, offset + "  ", res_var, f_res_var, it);
      ss << offset << "}\n";
      M.store_array_finish(ss, offset, res_var, var, tree_type);
    }
    M.store_field_finish(ss, offset, res_var);
    return res_var;
  }
  void gen_object_store(std::stringstream &ss, const tl::tl_combinator *t, const file_store_methods &M) const {
    ss << " {\n"
       << "  if (!var) {\n";
    M.store_nil(ss, "    ");
    ss << "  }\n";
    M.store_constructor_start(ss, "  ", t);

    std::vector<std::string> flds;
    int d = 0;
    for (auto &it : t->args) {
      const tl::tl_tree_type *tree_type = static_cast<const tl::tl_tree_type *>(it.type);
      flds.push_back(gen_field_store(ss, "  ", "var->" + gen_field_name(it.name), 100 * d, tree_type, M));
      d++;
      M.store_arg_finish(ss, "  ", gen_field_name(it.name), flds[d - 1]);
    }
    M.store_constructor_finish(ss, "  ", t, flds);
    ss << "}\n";
  }
  void gen_field_fetch(std::stringstream &ss, std::string offset, std::string res_var, std::string var, int depth,
                       const tl::tl_tree_type *tree_type, const file_fetch_methods &M) const {
    if (is_built_in_simple_type(tree_type->type->name)) {
      M.fetch_simple_type(ss, offset, res_var, var, tree_type->type->name);
    } else if (!is_built_in_complex_type(tree_type->type->name)) {
      M.fetch_common_type(ss, offset, res_var, var, tree_type);
    } else {
      const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);

      ss << offset << res_var << " = new Td" << gen_type_name(tree_type, true) << " ();\n";
      M.fetch_array_size(ss, offset, res_var + "->len", var, tree_type);
      ss << offset << res_var << "->data = new " << gen_type_name(child) << " [" << res_var << "->len];\n";

      std::string it = "i" + int_to_string(depth);
      ss << offset << "for (int " << it << " = 0; " << it << " < " << res_var << "->len; " << it << "++) {\n";
      auto new_var = M.fetch_array_field_start(ss, offset, res_var, var, it, child);
      gen_field_fetch(ss, offset + "  ", res_var + "->data[" + it + "]", new_var, depth + 1, child, M);
      ss << offset << "}\n";
    }
    M.fetch_field_finish(ss, offset, res_var, var, tree_type);
  }
  void gen_object_fetch(std::stringstream &ss, const tl::tl_combinator *t, const file_fetch_methods &M) const {
    auto type_name = gen_class_name(t->name);
    ss << " {\n"
       << "  auto res = new Td" << type_name << " ();\n"
       << "  res->ID = CODE_" << type_name << ";\n"
       << "  res->refcnt = 1;\n";
    int d = 0;
    for (auto &it : t->args) {
      const tl::tl_tree_type *tree_type = static_cast<const tl::tl_tree_type *>(it.type);
      auto new_var = M.fetch_dict_field_start(ss, "  ", "res", "from", gen_field_name(it.name), tree_type);
      gen_field_fetch(ss, "  ", "res->" + gen_field_name(it.name), new_var, 100 * d, tree_type, M);
      d++;
    }
    ss << "  return res;\n"
       << "}\n";
  }

  std::string gen_array_type_name(const tl::tl_tree_array *arr, const std::string &field_name) const final {
    assert(false);
    return std::string();
  }
  std::string gen_var_type_name() const final {
    assert(false);
    return std::string();
  }

  std::string gen_int_const(const tl::tl_tree *tree_c, const std::vector<tl::var_description> &vars) const final {
    assert(false);
    return std::string();
  }

  std::string gen_var_name(const tl::var_description &desc) const final {
    assert(false);
    return "";
  }
  std::string gen_parameter_name(int index) const final {
    assert(false);
    return "";
  }

  std::string gen_class_alias(const std::string &class_name, const std::string &alias_name) const final {
    return "";
  }

  std::string gen_vars(const tl::tl_combinator *t, const tl::tl_tree_type *result_type,
                       std::vector<tl::var_description> &vars) const final {
    assert(vars.empty());
    return "";
  }
  std::string gen_function_vars(const tl::tl_combinator *t, std::vector<tl::var_description> &vars) const final {
    assert(vars.empty());
    return "";
  }
  std::string gen_uni(const tl::tl_tree_type *result_type, std::vector<tl::var_description> &vars,
                      bool check_negative) const final {
    assert(result_type->children.empty());
    return "";
  }
  std::string gen_constructor_id_store(std::int32_t id, int storer_type) const final {
    return "";
  }
  std::string gen_field_fetch(int field_num, const tl::arg &a, std::vector<tl::var_description> &vars, bool flat,
                              int parser_type) const final {
    return "";
  }
  std::string gen_field_store(const tl::arg &a, const std::vector<tl::arg> &args,
                              std::vector<tl::var_description> &vars, bool flat, int storer_type) const final {
    return "";
  }
  std::string gen_type_fetch(const std::string &field_name, const tl::tl_tree_type *tree_type,
                             const std::vector<tl::var_description> &vars, int parser_type) const final {
    assert(vars.empty());
    return "";
  }

  std::string gen_type_store(const std::string &field_name, const tl::tl_tree_type *tree_type,
                             const std::vector<tl::var_description> &vars, int storer_type) const final {
    return "";
  }
  std::string gen_var_type_fetch(const tl::arg &a) const final {
    assert(false);
    return "";
  }

  std::string gen_get_id(const std::string &class_name, std::int32_t id, bool is_proxy) const final {
    if (is_proxy || is_header_ != 1) {
      return "";
    }
    return "";
  }

  std::string gen_function_result_type(const tl::tl_tree *result) const final {
    return "";
  }

  std::string gen_fetch_function_begin(const std::string &parser_name, const std::string &class_name,
                                       const std::string &parent_class_name, int arity, int field_count,
                                       std::vector<tl::var_description> &vars, int parser_type) const final {
    return "";
  }
  std::string gen_fetch_function_end(bool has_parent, int field_count, const std::vector<tl::var_description> &vars,
                                     int parser_type) const final {
    return "";
  }

  std::string gen_fetch_function_result_begin(const std::string &parser_name, const std::string &class_name,
                                              const tl::tl_tree *result) const final {
    return "";
  }
  std::string gen_fetch_function_result_end() const final {
    return "";
  }
  std::string gen_fetch_function_result_any_begin(const std::string &parser_name, const std::string &class_name,
                                                  bool is_proxy) const final {
    return "";
  }
  std::string gen_fetch_function_result_any_end(bool is_proxy) const final {
    return "";
  }

  std::string gen_fetch_switch_begin() const final {
    return "";
  }
  std::string gen_fetch_switch_case(const tl::tl_combinator *t, int arity) const final {
    return "";
  }
  std::string gen_fetch_switch_end() const final {
    return "";
  }

  std::string gen_additional_proxy_function_begin(const std::string &function_name, const tl::tl_type *type,
                                                  const std::string &name, int arity, bool is_function) const final {
    std::stringstream ss;
    std::string class_name;
    std::string native_class_name;

    if (type != nullptr) {
      class_name = gen_main_class_name(type);
      native_class_name = gen_native_class_name(type->name);
    } else {
      if (is_function) {
        class_name = "Function";
        native_class_name = "Function";
      } else {
        class_name = "Object";
        native_class_name = "Object";
      }
    }
    if (is_header_ == 1 && function_name == "TdConvertToInternal" && type != nullptr && !is_function) {
      ss << "};\n";
    }

    if (function_name == "enum") {
      if (is_header_ != 1) {
        return ss.str();
      }
      ss << "enum List_" + class_name << " {\n";
      return ss.str();
    }

    if (function_name == "TdDestroyObject") {
      if (is_header_ == 1) {
        ss << "void TdDestroyObject" + class_name + " (struct Td" + class_name + " *var);\n";
        return ss.str();
      }
      if (is_header_ == -1) {
        ss << "void TdDestroyObject (struct Td" + class_name + " *var);\n";
        return ss.str();
      }
      ss << "void TdDestroyObject" + class_name + " (struct Td" + class_name + " *var) {\n";
      ss << "  TdDestroyObject (var);\n";
      ss << "}\n";
      ss << "void TdDestroyObject (struct Td" + class_name + " *var)";
    }
    if (function_name == "TdSerialize" && is_header_ != -1) {
      ss << "char *TdSerialize" + class_name + " (struct Td" + class_name + " *var)";
      if (is_header_ == 1) {
        ss << ";\n";
        return ss.str();
      }
      ss << " {\n";
      ss << "  return td::str_dup (TdToString (var));\n";
      ss << "}\n";
      return ss.str();
    }
    if (function_name == "TdToString" && is_header_ != 1) {
      ss << "std::string TdToString (struct Td" + class_name + " *var)";
      if (is_header_ == -1) {
        ss << ";\n";
        return ss.str();
      }
      ss << " {\n";
      ss << "  return to_string (TdConvertToInternal (var));\n";
      ss << "}\n";
      return ss.str();
    }
    if (function_name == "TdConvertToInternal" && is_header_ != 1) {
      ss << "td::td_api::object_ptr<td::td_api::" << native_class_name
         << "> TdConvertToInternal (struct Td" + class_name + " *var)";
      if (is_header_ == -1) {
        ss << ";\n";
        return ss.str();
      }
    }
    if (function_name == "TdConvertFromInternal" && is_header_ != 1) {
      ss << "struct Td" << class_name << " *TdConvertFromInternal (const td::td_api::" << native_class_name
         << " &from)";
      if (is_header_ == -1) {
        ss << ";\n";
        return ss.str();
      }
    }
    if (function_name == "TdStackStorer") {
      if (is_header_ == 1) {
        ss << "void TdStackStorer" + class_name + " (struct Td" + class_name +
                  " *var, struct TdStackStorerMethods *M);\n";
        return ss.str();
      }
      if (is_header_ == -1) {
        ss << "void TdStackStorer (struct Td" + class_name + " *var, struct TdStackStorerMethods *M);\n";
        return ss.str();
      }
      ss << "void TdStackStorer" + class_name + " (struct Td" + class_name +
                " *var, struct TdStackStorerMethods *M) {\n";
      ss << "  TdStackStorer (var, M);\n";
      ss << "}\n";
      ss << "void TdStackStorer (struct Td" + class_name + " *var, struct TdStackStorerMethods *M)";
    }
    if (function_name == "TdStackFetcher" && is_header_ != -1) {
      ss << "struct Td" << class_name << " *TdStackFetcher" + class_name + " (struct TdStackFetcherMethods *M)";
      if (is_header_ == 1) {
        ss << ";\n";
        return ss.str();
      }
    }
    if (is_header_ != 0) {
      return ss.str();
    }

    if (function_name == "TdDestroyObject" || function_name == "TdConvertToInternal" ||
        function_name == "TdStackStorer") {
      ss << " {\n";
      std::string prefix = "";
      if (function_name == "TdConvertToInternal") {
        prefix = "  if (!var) { return nullptr; }\n";
      } else if (function_name == "TdDestroyObject") {
        prefix = "  if (!var) { return; }\n";
      }
      if (function_name == "TdStackStorer") {
        prefix = "  if (!var) { M->pack_bool (0); return; }\n";
      }
      ss << prefix
         << "  int constructor = var->ID;\n"
            "  switch (constructor) {\n";
    } else if (function_name == "TdConvertFromInternal") {
      ss << " {\n"
            //"  if (!from) { return nullptr; }\n"
            "  int constructor = from.get_id ();\n"
            "  switch (constructor) {\n";
    } else if (function_name == "TdStackFetcher") {
      ss << " {\n"
            "  M->get_field (\"ID\");\n"
            "  char *constructor_old = M->get_string ();\n"
            "  M->pop ();\n"
            "  std::string constructor = constructor_old;\n"
            "  free (constructor_old);\n"
            "  ";
    } else {
      ss << "??????";
    }

    return ss.str();
  }

  std::string gen_additional_proxy_function_case(const std::string &function_name, const tl::tl_type *type,
                                                 const std::string &class_name, int arity) const final {
    if (is_header_ != (function_name == "enum" ? 1 : 0)) {
      return "";
    }

    assert(type != nullptr);
    if (function_name == "TdDestroyObject" || function_name == "TdConvertToInternal" ||
        function_name == "TdStackStorer") {
      std::string extra_arg = "";
      if (function_name == "TdStackStorer") {
        extra_arg = ", M";
      }
      return "    case CODE_" + class_name + ": return " + function_name + " ((struct Td" + class_name + " *)var" +
             extra_arg + ");\n";
    } else if (function_name == "TdConvertFromInternal") {
      std::string native_class_name = class_name;
      native_class_name[0] = to_lower(native_class_name[0]);
      return "    case CODE_" + class_name + ": return (struct TdNullaryObject *)" + function_name +
             "(static_cast<const td::td_api::" + native_class_name + " &>(from));\n";
    } else if (function_name == "TdStackFetcher") {
      return "if (constructor == \"" + class_name +
             "\") {\n"
             "    return (struct TdNullaryObject *)TdStackFetcher" +
             class_name +
             " (M);\n"
             "  }\n  ";
    } else if (function_name == "enum") {
      // return "  CODE_" + class_name + " = " + int_to_string (t->id) + ",\n";
      return "????\n";
    } else {
      return "";
    }
  }

  std::string gen_additional_proxy_function_case(const std::string &function_name, const tl::tl_type *type,
                                                 const tl::tl_combinator *t, int arity, bool is_function) const final {
    if (is_header_ != (function_name == "enum" ? 1 : 0)) {
      return "";
    }

    if (function_name == "TdDestroyObject" || function_name == "TdConvertToInternal" ||
        function_name == "TdStackStorer") {
      auto class_name = gen_class_name(t->name);
      std::string extra_arg = "";
      if (function_name == "TdStackStorer") {
        extra_arg = ", M";
      }
      return "    case CODE_" + gen_class_name(t->name) + ": return " + function_name + " ((struct Td" + class_name +
             " *)var" + extra_arg + ");\n";
    } else if (function_name == "TdConvertFromInternal") {
      const tl::tl_tree_type *tree_type = static_cast<const tl::tl_tree_type *>(t->result);

      auto native_class_name = gen_native_class_name(t->name);
      auto class_name = gen_main_class_name(tree_type->type);
      if (type == nullptr) {
        if (is_function) {
          class_name = "Function";
        } else {
          class_name = "Object";
        }
      }
      return "    case CODE_" + gen_class_name(t->name) + ": return (struct Td" + class_name + " *)" + function_name +
             "(static_cast<const td::td_api::" + native_class_name + " &>(from));\n";
    } else if (function_name == "enum") {
      const tl::tl_tree_type *tree_type = static_cast<const tl::tl_tree_type *>(t->result);

      auto native_class_name = gen_native_class_name(t->name);
      auto class_name = gen_main_class_name(tree_type->type);
      if (type == nullptr) {
        if (is_function) {
          class_name = "Function";
        } else {
          class_name = "Object";
        }
      }

      int flat = 0;
      if (!is_function) {
        if (tree_type->type->constructors_num == 1) {
          flat = 1;
        }
      }

      if (class_name == "Object" && !flat) {
        return "  CODE_Copy_" + gen_class_name(t->name) + " = " + int_to_string(t->id) + ",\n";
      } else {
        return "  CODE_" + gen_class_name(t->name) + " = " + int_to_string(t->id) + ",\n";
      }
    } else if (function_name == "TdStackFetcher") {
      const tl::tl_tree_type *tree_type = static_cast<const tl::tl_tree_type *>(t->result);

      auto native_class_name = gen_native_class_name(t->name);
      auto class_name = gen_main_class_name(tree_type->type);
      if (type == nullptr) {
        if (is_function) {
          class_name = "Function";
        } else {
          class_name = "Object";
        }
      }

      return "if (constructor == \"" + gen_class_name(t->name) +
             "\") {\n"
             "    return (struct Td" +
             class_name + " *)TdStackFetcher" + gen_class_name(t->name) +
             " (M);\n"
             "  }\n  ";
    } else {
      return "";
    }
  }
  std::string gen_additional_proxy_function_end(const std::string &function_name, const tl::tl_type *type,
                                                bool is_function) const final {
    if (is_header_ != (function_name == "enum" ? 1 : 0)) {
      return "";
    }

    if (function_name == "TdDestroyObject" || function_name == "TdConvertToInternal" ||
        function_name == "TdConvertFromInternal" || function_name == "TdStackStorer") {
      std::string retval = "";
      if (function_name == "TdConvertToInternal" || function_name == "TdConvertFromInternal") {
        retval = "nullptr";
      }
      return "    default:\n"
             "      LOG(FATAL) << \"Unknown constructor found \" << td::format::as_hex(constructor);\n"
             "      return " +
             retval +
             ";\n"
             "  }\n"
             "}\n";
    } else if (function_name == "TdStackFetcher") {
      return "{\n"
             "    LOG(FATAL) << \"Unknown constructor found \" << constructor;\n"
             "    return nullptr;\n"
             "  }\n"
             "}\n";
    } else if (function_name == "enum") {
      return "};\n";
    } else {
      return "";
    }
  }

  int get_additional_function_type(const std::string &additional_function_name) const final {
    return 2;
  }
};

}  // namespace td
