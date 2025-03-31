//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "tl_writer_td.h"

#include <cassert>

namespace td {

const int TD_TL_writer::MAX_ARITY;

const std::string TD_TL_writer::base_type_class_names[MAX_ARITY + 1] = {"Object"};
const std::string TD_TL_writer::base_tl_class_name = "TlObject";
const std::string TD_TL_writer::base_function_class_name = "Function";

int TD_TL_writer::get_max_arity() const {
  return MAX_ARITY;
}

bool TD_TL_writer::is_built_in_simple_type(const std::string &name) const {
  return name == "True" || name == "Bool" || name == "Int" || name == "Long" || name == "Double" || name == "String" ||
         name == "Int32" || name == "Int53" || name == "Int64" || name == "Int128" || name == "Int256" ||
         name == "Int512" || name == "Bytes" || name == "SecureString" || name == "SecureBytes";
}

bool TD_TL_writer::is_built_in_complex_type(const std::string &name) const {
  return name == "Vector";
}

bool TD_TL_writer::is_type_bare(const tl::tl_type *t) const {
  return t->simple_constructors <= 1 || (is_built_in_simple_type(t->name) && t->name != "Bool") ||
         is_built_in_complex_type(t->name);
}

bool TD_TL_writer::is_combinator_supported(const tl::tl_combinator *constructor) const {
  if (!TL_writer::is_combinator_supported(constructor)) {
    return false;
  }

  for (std::size_t i = 0; i < constructor->args.size(); i++) {
    if (constructor->args[i].type->get_type() == tl::NODE_TYPE_VAR_TYPE) {
      return false;
    }
  }

  return true;
}

bool TD_TL_writer::is_default_constructor_generated(const tl::tl_combinator *t, bool can_be_parsed,
                                                    bool can_be_stored) const {
  return tl_name == "td_api" || tl_name == "TdApi" || (t->var_count > 0 && can_be_parsed) || t->name == "updates";
}

bool TD_TL_writer::is_full_constructor_generated(const tl::tl_combinator *t, bool can_be_parsed,
                                                 bool can_be_stored) const {
  return tl_name == "td_api" || tl_name == "TdApi" || can_be_stored || t->name == "phone.groupParticipants" ||
         t->name == "user" || t->name == "userProfilePhoto" || t->name == "channelForbidden" || t->name == "message" ||
         t->name == "photoSizeEmpty" || t->name == "photoSize" || t->name == "photoCachedSize" ||
         t->name == "document" || t->name == "updateDeleteMessages" || t->name == "updateEditChannelMessage" ||
         t->name == "encryptedChatWaiting" || t->name == "encryptedChatRequested" || t->name == "encryptedChat" ||
         t->name == "langPackString" || t->name == "langPackStringPluralized" || t->name == "langPackStringDeleted" ||
         t->name == "peerUser" || t->name == "peerChat" || t->name == "updateServiceNotification" ||
         t->name == "updateNewMessage" || t->name == "updateChannelTooLong" || t->name == "messages.stickerSet" ||
         t->name == "updates.differenceSlice" || t->name == "contacts.contactBirthdays";
}

int TD_TL_writer::get_storer_type(const tl::tl_combinator *t, const std::string &storer_name) const {
  return storer_name == "TlStorerToString";
}

tl::TL_writer::Mode TD_TL_writer::get_parser_mode(int type) const {
  if (tl_name == "td_api") {
#ifndef TD_ENABLE_JNI  // we need to parse all types in order to implement toString
    return Server;
#endif
  }
  if (tl_name == "telegram_api") {
    return Client;
  }
  return All;
}

tl::TL_writer::Mode TD_TL_writer::get_storer_mode(int type) const {
  if (type == 1) {
    return All;
  }

  if (tl_name == "td_api") {
    return Server;
  }
  if (tl_name == "telegram_api") {
    return Client;
  }
  return All;
}

std::vector<std::string> TD_TL_writer::get_parsers() const {
  std::vector<std::string> parsers;
  if (tl_name == "telegram_api") {
    parsers.push_back("TlBufferParser");
  } else if (tl_name == "mtproto_api" || tl_name == "secret_api" || tl_name == "e2e_api") {
    parsers.push_back("TlParser");
  }
  return parsers;
}

std::vector<std::string> TD_TL_writer::get_storers() const {
  std::vector<std::string> storers;
  if (tl_name == "telegram_api" || tl_name == "mtproto_api" || tl_name == "secret_api" || tl_name == "e2e_api") {
    storers.push_back("TlStorerCalcLength");
    storers.push_back("TlStorerUnsafe");
  }
  storers.push_back("TlStorerToString");
  return storers;
}

std::string TD_TL_writer::gen_import_declaration(const std::string &name, bool is_system) const {
  if (is_system) {
    return "#include <" + name + ">\n";
  } else {
    return "#include \"" + name + "\"\n";
  }
}

std::string TD_TL_writer::gen_package_suffix() const {
  return ".h";
}

std::string TD_TL_writer::gen_base_tl_class_name() const {
  return base_tl_class_name;
}

std::string TD_TL_writer::gen_base_type_class_name(int arity) const {
  assert(arity == 0);
  return base_type_class_names[arity];
}

std::string TD_TL_writer::gen_base_function_class_name() const {
  return base_function_class_name;
}

std::string TD_TL_writer::gen_class_name(std::string name) const {
  if (name == "Object") {
    assert(false);
  }
  if (name == "#") {
    return "int32";
  }
  for (std::size_t i = 0; i < name.size(); i++) {
    if (!is_alnum(name[i])) {
      name[i] = '_';
    }
  }
  return name;
}

std::string TD_TL_writer::gen_field_name(std::string name) const {
  for (std::size_t i = 0; i < name.size(); i++) {
    if (!is_alnum(name[i])) {
      name[i] = '_';
    }
  }
  assert(!name.empty());
  assert(name[name.size() - 1] != '_');
  return name + '_';
}

std::string TD_TL_writer::gen_var_name(const tl::var_description &desc) const {
  assert(!desc.is_type);

  if (desc.parameter_num != -1) {
    assert(false);
  }
  return "var" + int_to_string(desc.index);
}

std::string TD_TL_writer::gen_parameter_name(int index) const {
  assert(false);
  return std::string();
}

std::string TD_TL_writer::gen_type_name(const tl::tl_tree_type *tree_type) const {
  const tl::tl_type *t = tree_type->type;
  const std::string &name = t->name;

  if (name == "#") {
    return "int32";
  }
  if (name == "True") {
    return "bool";
  }
  if (name == "Bool") {
    return "bool";
  }
  if (name == "Int" || name == "Int32") {
    return "int32";
  }
  if (name == "Int53") {
    return "int53";
  }
  if (name == "Long" || name == "Int64") {
    return "int64";
  }
  if (name == "Double") {
    return "double";
  }
  if (name == "String") {
    return "string";
  }
  if (name == "Int128") {
    return "UInt128";
  }
  if (name == "Int256") {
    return "UInt256";
  }
  if (name == "Int512") {
    return "UInt512";
  }
  if (name == "Bytes") {
    return "bytes";
  }
  if (name == "SecureString") {
    return "secure_string";
  }
  if (name == "SecureBytes") {
    return "secure_bytes";
  }

  if (name == "Vector") {
    assert(t->arity == 1);
    assert(tree_type->children.size() == 1);
    assert(tree_type->children[0]->get_type() == tl::NODE_TYPE_TYPE);
    const tl::tl_tree_type *child = static_cast<const tl::tl_tree_type *>(tree_type->children[0]);

    return "array<" + gen_type_name(child) + ">";
  }

  assert(!is_built_in_simple_type(name) && !is_built_in_complex_type(name));

  for (std::size_t i = 0; i < tree_type->children.size(); i++) {
    assert(tree_type->children[i]->get_type() == tl::NODE_TYPE_NAT_CONST);
  }

  return "object_ptr<" + gen_main_class_name(t) + ">";
}

std::string TD_TL_writer::gen_array_type_name(const tl::tl_tree_array *arr, const std::string &field_name) const {
  assert(false);
  return std::string();
}

std::string TD_TL_writer::gen_var_type_name() const {
  return "object_ptr<" + gen_base_function_class_name() + ">";
}

std::string TD_TL_writer::gen_int_const(const tl::tl_tree *tree_c, const std::vector<tl::var_description> &vars) const {
  assert(false);
  return std::string();
}

std::string TD_TL_writer::gen_constructor_parameter(int field_num, const std::string &class_name, const tl::arg &a,
                                                    bool is_default) const {
  if (is_default) {
    return "";
  }

  std::string field_type = gen_field_type(a);
  if (field_type.empty()) {
    return "";
  }

  if (field_type[field_type.size() - 1] != ' ') {
    field_type += ' ';
  }

  std::string res = (field_num == 0 ? "" : ", ");
  if (field_type == "bool " || field_type == "int32 " || field_type == "int53 " || field_type == "int64 " ||
      field_type == "double ") {
    res += field_type;
  } else if (field_type == "UInt128 " || field_type == "UInt256 " || field_type == "UInt512 " ||
             field_type == "string " || (string_type == bytes_type && field_type == "bytes ") ||
             field_type == "secure_string " || (string_type == bytes_type && field_type == "secure_bytes ")) {
    res += field_type + "const &";
  } else if (field_type.compare(0, 5, "array") == 0 || field_type == "bytes " || field_type == "secure_bytes " ||
             field_type.compare(0, 10, "object_ptr") == 0) {
    res += field_type + "&&";
  } else {
    assert(false && "unreachable");
  }

  return res + gen_field_name(a.name);
}

}  // namespace td
