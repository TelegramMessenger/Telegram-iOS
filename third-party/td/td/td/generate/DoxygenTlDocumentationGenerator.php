<?php

require_once 'TlDocumentationGenerator.php';

class DoxygenTlDocumentationGenerator extends TlDocumentationGenerator
{
    private function getParameterTypeName($type)
    {
        switch ($type) {
            case 'Bool':
                return 'bool ';
            case 'int32':
                return 'int32 ';
            case 'int53':
                return 'int53 ';
            case 'int64':
                return 'int64 ';
            case 'double':
                return 'double ';
            case 'string':
                return 'string const &';
            case 'bytes':
                return 'bytes const &';

            default:
                if (substr($type, 0, 6) === 'vector') {
                    if ($type[6] !== '<' || $type[strlen($type) - 1] !== '>') {
                        return '';
                    }
                    return 'array<'.$this->getTypeName(substr($type, 7, -1)).'> &&';
                }

                if (preg_match('/[^A-Za-z0-9.]/', $type)) {
                    return '';
                }
                return 'object_ptr<'.$this->getClassName($type).'> &&';
        }
    }

    protected function escapeDocumentation($doc)
    {
        $doc = htmlspecialchars($doc, ENT_COMPAT, 'UTF-8');
        $doc = preg_replace_callback('/&quot;((http|https|tg):\/\/[^" ]*)&quot;/',
            function ($quoted_link)
            {
                return "&quot;<a href=\"".$quoted_link[1]."\">".$quoted_link[1]."</a>&quot;";
            }, $doc);
        $doc = str_replace('*/', '*&#47;', $doc);
        $doc = str_replace('#', '\#', $doc);
        return $doc;
    }

    protected function getFieldName($name, $class_name)
    {
        if (substr($name, 0, 6) === 'param_') {
            $name = substr($name, 6);
        }
        return $name.'_';
    }

    protected function getClassName($type)
    {
        return implode(explode('.', trim($type, "\r\n ;")));
    }

    protected function getTypeName($type)
    {
        switch ($type) {
            case 'Bool':
                return 'bool';
            case 'int32':
                return 'int32';
            case 'int53':
                return 'int53';
            case 'int64':
                return 'int64';
            case 'double':
                return 'double';
            case 'string':
                return 'string';
            case 'bytes':
                return 'bytes';
            case 'bool':
            case 'int':
            case 'long':
            case 'Int':
            case 'Long':
            case 'Int32':
            case 'Int53':
            case 'Int64':
            case 'Double':
            case 'String':
            case 'Bytes':
                $this->printError("Wrong type $type");
                return '';
            default:
                if (substr($type, 0, 6) === 'vector') {
                    if ($type[6] !== '<' || $type[strlen($type) - 1] !== '>') {
                        $this->printError("Wrong vector subtype in $type");
                        return '';
                    }
                    return 'array<'.$this->getTypeName(substr($type, 7, -1)).'>';
                }

                if (preg_match('/[^A-Za-z0-9.]/', $type)) {
                    $this->printError("Wrong type $type");
                    return '';
                }
                return 'object_ptr<'.$this->getClassName($type).'>';
        }
    }

    protected function getBaseClassName($is_function)
    {
        return $is_function ? 'Function' : 'Object';
    }

    protected function needRemoveLine($line)
    {
        $line = trim($line);
        return strpos($line, '/**') === 0 || strpos($line, '*') === 0 || strpos($line, '///') === 0;
    }

    protected function needSkipLine($line)
    {
        $tline = trim($line);
        return empty($tline) || $tline[0] === '}' || $tline === 'public:' || strpos($line, '#pragma ') === 0 ||
            strpos($line, '#include <') === 0 || strpos($tline, 'return ') === 0 || strpos($tline, 'namespace') === 0 ||
            preg_match('/class [A-Za-z0-9_]*;/', $line) || $tline === 'if (value == nullptr) {' ||
            strpos($tline, 'result += ') === 0 || strpos($tline, 'result = ') || strpos($tline, ' : values') ||
            strpos($line, 'JNIEnv') || strpos($line, 'jfieldID') || $tline === 'virtual ~Object() {' ||
            $tline === 'virtual void store(TlStorerToString &s, const char *field_name) const = 0;' ||
            $tline === 'const char *&get_package_name_ref();' || $tline === 'const char *get_git_commit_hash();';
    }

    protected function isHeaderLine($line)
    {
        return strpos($line, 'template <') === 0;
    }

    protected function extractClassName($line)
    {
        if (strpos($line, 'class ') === 0) {
            return explode(' ', trim($line))[1];
        }
        return '';
    }

    protected function fixLine($line)
    {
        if (strpos($line, 'ID = ') > 0 || strpos($line, 'ReturnType = ') > 0 || strpos($line, 'using BaseObject = ') === 0) {
            return substr($line, 0, strpos($line, '='));
        }
        if (strpos($line, 'class Function: ') === 0) {
            return 'class Function';
        }
        if (strpos($line, 'class Object {') === 0 || strpos($line, 'class Object: public TlObject {') === 0) {
            return 'class Object';
        }

        return $line;
    }

    protected function addGlobalDocumentation()
    {
        $this->addDocumentation('#include "td/tl/TlObject.h"', <<<EOT
/**
 * \\file
 * Contains declarations of all functions and types which represent a public TDLib interface.
 */
EOT
);

        $this->addDocumentation('using int32 = std::int32_t;', <<<EOT
/**
 * This type is used to store 32-bit signed integers, which can be represented as Number in JSON.
 */
EOT
);

        $this->addDocumentation('using int53 = std::int64_t;', <<<EOT
/**
 * This type is used to store 53-bit signed integers, which can be represented as Number in JSON.
 */
EOT
);

        $this->addDocumentation('using int64 = std::int64_t;', <<<EOT
/**
 * This type is used to store 64-bit signed integers, which can't be represented as Number in JSON and are represented as String instead.
 */
EOT
);

        $this->addDocumentation('using string = std::string;', <<<EOT
/**
 * This type is used to store UTF-8 strings.
 */
EOT
);

        $this->addDocumentation('using bytes = std::string;', <<<EOT
/**
 * This type is used to store arbitrary sequences of bytes. In JSON interface the bytes are base64-encoded.
 */
EOT
);

        $this->addDocumentation('using array = std::vector<Type>;', <<<EOT
/**
 * This type is used to store a list of objects of any type and is represented as Array in JSON.
 */
EOT
);

        $this->addDocumentation('using BaseObject', <<<EOT
/**
 * This class is a base class for all TDLib API classes and functions.
 */
EOT
);

        $this->addDocumentation('using object_ptr = ::td::tl_object_ptr<Type>;', <<<EOT
/**
 * A smart wrapper to store a pointer to a TDLib API object. Can be treated as an analogue of std::unique_ptr.
 */
EOT
);

        $this->addDocumentation('object_ptr<Type> make_object(Args &&... args) {', <<<EOT
/**
 * A function to create a dynamically allocated TDLib API object. Can be treated as an analogue of std::make_unique.
 * Usage example:
 * \\code
 * auto get_me_request = td::td_api::make_object<td::td_api::getMe>();
 * auto message_text = td::td_api::make_object<td::td_api::formattedText>("Hello, world!!!",
 *                     td::td_api::array<td::td_api::object_ptr<td::td_api::textEntity>>());
 * auto send_message_request = td::td_api::make_object<td::td_api::sendMessage>(chat_id, 0, nullptr, nullptr, nullptr,
 *      td::td_api::make_object<td::td_api::inputMessageText>(std::move(message_text), nullptr, true));
 * \\endcode
 *
 * \\tparam Type Type of object to construct.
 * \\param[in] args Arguments to pass to the object constructor.
 * \\return Wrapped pointer to the created object.
 */
EOT
);

        $this->addDocumentation('object_ptr<ToType> move_object_as(FromType &&from) {', <<<EOT
/**
 * A function to cast a wrapped in td::td_api::object_ptr TDLib API object to its subclass or superclass.
 * Casting an object to an incorrect type will lead to undefined behaviour.
 * Usage example:
 * \\code
 * td::td_api::object_ptr<td::td_api::callState> call_state = ...;
 * switch (call_state->get_id()) {
 *   case td::td_api::callStatePending::ID: {
 *     auto state = td::td_api::move_object_as<td::td_api::callStatePending>(call_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::callStateExchangingKeys::ID: {
 *     // no additional fields, no casting is needed
 *     break;
 *   }
 *   case td::td_api::callStateReady::ID: {
 *     auto state = td::td_api::move_object_as<td::td_api::callStateReady>(call_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::callStateHangingUp::ID: {
 *     // no additional fields, no casting is needed
 *     break;
 *   }
 *   case td::td_api::callStateDiscarded::ID: {
 *     auto state = td::td_api::move_object_as<td::td_api::callStateDiscarded>(call_state);
 *     // use state
 *     break;
 *   }
 *   case td::td_api::callStateError::ID: {
 *     auto state = td::td_api::move_object_as<td::td_api::callStateError>(call_state);
 *     // use state
 *     break;
 *   }
 *   default:
 *     assert(false);
 * }
 * \\endcode
 *
 * \\tparam ToType Type of TDLib API object to move to.
 * \\tparam FromType Type of TDLib API object to move from, this is auto-deduced.
 * \\param[in] from Wrapped in td::td_api::object_ptr pointer to a TDLib API object.
 */
EOT
);

        $this->addDocumentation('std::string to_string(const BaseObject &value);', <<<EOT
/**
 * Returns a string representation of a TDLib API object.
 * \\param[in] value The object.
 * \\return Object string representation.
 */
EOT
);

        $this->addDocumentation('std::string to_string(const object_ptr<T> &value) {', <<<EOT
/**
 * Returns a string representation of a TDLib API object.
 * \\tparam T Object type, auto-deduced.
 * \\param[in] value The object.
 * \\return Object string representation.
 */
EOT
);

        $this->addDocumentation('std::string to_string(const std::vector<object_ptr<T>> &values) {', <<<EOT
/**
 * Returns a string representation of a list of TDLib API objects.
 * \\tparam T Object type, auto-deduced.
 * \\param[in] values The objects.
 * \\return Objects string representation.
 */
EOT
);

        $this->addDocumentation('  void store(TlStorerToString &s, const char *field_name) const final;', <<<EOT
  /**
   * Helper function for to_string method. Appends string representation of the object to the storer.
   * \\param[in] s Storer to which object string representation will be appended.
   * \\param[in] field_name Object field_name if applicable.
   */
EOT
);

        $this->addDocumentation('class Object', <<<EOT
/**
 * This class is a base class for all TDLib API classes.
 */
EOT
);

        $this->addDocumentation('class Function', <<<EOT
/**
 * This class is a base class for all TDLib API functions.
 */
EOT
);

        $this->addDocumentation('  static const std::int32_t ID', <<<EOT
  /// Identifier uniquely determining a type of the object.
EOT
);

        $this->addDocumentation('  std::int32_t get_id() const final {', <<<EOT
  /**
   * Returns identifier uniquely determining a type of the object.
   * \\return this->ID.
   */
EOT
);

        $this->addDocumentation('  virtual std::int32_t get_id() const = 0;', <<<EOT
  /**
   * Returns identifier uniquely determining a type of the object.
   * \\return this->ID.
   */
EOT
);

        $this->addDocumentation('  using ReturnType', <<<EOT
  /// Typedef for the type returned by the function.
EOT
);
    }

    protected function addAbstractClassDocumentation($class_name, $documentation)
    {
        $this->addDocumentation("class $class_name: public Object {", <<<EOT
/**
 * This class is an abstract base class.
 * $documentation
 */
EOT
);
    }

    protected function getFunctionReturnTypeDescription($return_type, $for_constructor)
    {
        $shift = $for_constructor ? '   ' : ' ';
        return PHP_EOL.$shift.'*'.PHP_EOL.$shift."* Returns $return_type.";
    }

    protected function addClassDocumentation($class_name, $base_class_name, $return_type, $description)
    {
        $this->addDocumentation("class $class_name final : public $base_class_name {", <<<EOT
/**
 * $description
 */
EOT
);
    }

    protected function addFieldDocumentation($class_name, $field_name, $type_name, $field_info, $may_be_null)
    {
        $this->addDocumentation($class_name."  $type_name $field_name;", <<<EOT
  /// $field_info
EOT
);
    }

    protected function addDefaultConstructorDocumentation($class_name, $class_description)
    {
        $this->addDocumentation("  $class_name();", <<<EOT
  /**
   * $class_description
   */
EOT
);
    }

    protected function addFullConstructorDocumentation($class_name, $class_description, $known_fields, $info)
    {
        $explicit = count($known_fields) === 1 ? 'explicit ' : '';
        $full_constructor = "  $explicit$class_name(";
        $colon = '';
        foreach ($known_fields as $name => $type) {
            $full_constructor .= $colon.$this->getParameterTypeName($type).$this->getFieldName($name, $class_name);
            $colon = ', ';
        }
        $full_constructor .= ');';

        $full_doc = <<<EOT
  /**
   * $class_description
   *

EOT;
        foreach ($known_fields as $name => $type) {
            $full_doc .= '   * \\param[in] '.$this->getFieldName($name, $class_name).' '.$info[$name].PHP_EOL;
        }
        $full_doc .= '   */';
        $this->addDocumentation($full_constructor, $full_doc);
    }
}

$generator = new DoxygenTlDocumentationGenerator();
$generator->generate($argv[1], $argv[2]);
