<?php

abstract class TlDocumentationGenerator
{
    private $current_line = '';
    private $documentation = array();
    private $line_replacement = array();

    private function isBuiltInType($type)
    {
        if (in_array($type, array('Bool', 'int32', 'int53', 'int64', 'double', 'string', 'bytes'))) {
          return true;
        }
        return substr($type, 0, 7) === 'vector<' && substr($type, -1, 1) === '>' && $this->isBuiltInType(substr($type, 7, -1));
    }


    final protected function printError($error)
    {
        fwrite(STDERR, "$error near line \"".rtrim($this->current_line)."\"\n");
    }

    final protected function addDocumentation($code, $doc) {
        if (isset($this->documentation[$code])) {
            $this->printError("Duplicate documentation for \"$code\"");
        }

        $this->documentation[$code] = $doc;
        // $this->printError($code);
    }

    final protected function addLineReplacement($line, $new_line) {
        if (isset($this->line_replacement[$line])) {
            $this->printError("Duplicate line replacement for \"$line\"");
        }

        $this->line_replacement[$line] = $new_line;
    }

    final protected function addDot($str) {
        if (!$str) {
            return '';
        }

        $brackets = preg_replace("/[^[\\](){}'\"]/", '', preg_replace("/[a-z]'/", '', $str));
        while (strlen($brackets)) {
            $brackets = preg_replace(array('/[[]]/', '/[(][)]/', '/[{][}]/', "/''/", '/""/'), '', $brackets, -1, $replaced_bracket_count);
            if ($replaced_bracket_count == 0) {
                $this->printError('Unmatched bracket in '.$str);
                break;
            }
        }

        $len = strlen($str);
        if ($str[$len - 1] === '.') {
            return $str;
        }

        if ($str[$len - 1] === ')') {
            // trying to place dot inside the brackets
            $bracket_count = 1;
            for ($pos = $len - 2; $pos >= 0; $pos--) {
                if ($str[$pos] === ')') {
                    $bracket_count++;
                }
                if ($str[$pos] === '(') {
                    $bracket_count--;
                    if ($bracket_count === 0) {
                        break;
                    }
                }
            }
            if ($bracket_count === 0) {
                if (ord('A') <= ord($str[$pos + 1]) && ord($str[$pos + 1]) <= ord('Z')) {
                    return substr($str, 0, -1).'.)';
                }
            } else {
                $this->printError('Unmatched bracket');
            }
        }
        return $str.'.';
    }

    abstract protected function escapeDocumentation($doc);

    abstract protected function getFieldName($name, $class_name);

    abstract protected function getClassName($name);

    abstract protected function getTypeName($type);

    abstract protected function getBaseClassName($is_function);

    abstract protected function needRemoveLine($line);

    abstract protected function needSkipLine($line);

    abstract protected function isHeaderLine($line);

    abstract protected function extractClassName($line);

    abstract protected function fixLine($line);

    abstract protected function addGlobalDocumentation();

    abstract protected function addAbstractClassDocumentation($class_name, $value);

    abstract protected function getFunctionReturnTypeDescription($return_type, $for_constructor);

    abstract protected function addClassDocumentation($class_name, $base_class_name, $return_type, $description);

    abstract protected function addFieldDocumentation($class_name, $field_name, $type_name, $field_info, $may_be_null);

    abstract protected function addDefaultConstructorDocumentation($class_name, $class_description);

    abstract protected function addFullConstructorDocumentation($class_name, $class_description, $known_fields, $info);

    public function generate($tl_scheme_file, $source_file)
    {
        $lines = array_filter(array_map('trim', file($tl_scheme_file)));
        $description = '';
        $description_line_count = 0;
        $current_class = '';
        $is_function = false;
        $need_class_description = false;

        $this->addGlobalDocumentation();

        foreach ($lines as $line) {
            $this->current_line = $line;
            if ($line === '---types---') {
                $is_function = false;
            } elseif ($line === '---functions---') {
                $is_function = true;
                $current_class = '';
                $need_class_description = false;
            } elseif ($line[0] === '/') {
                if ($line[1] !== '/') {
                    $this->printError('Wrong comment');
                    continue;
                }
                if ($line[2] === '@') {
                    if (substr($line, 2, 7) !== '@class ') {
                      $description_line_count++;
                    }
                    $description .= trim(substr($line, 2)).' ';
                } elseif ($line[2] === '-') {
                    if (strpos($line, '@') !== false) {
                      $description_line_count += 100;
                    }
                    $description .= trim(substr($line, 3)).' ';
                } else {
                    $this->printError('Unexpected comment');
                }
            } elseif (strpos($line, '? =') || strpos($line, ' = Vector t;') || $line === 'boolFalse = Bool;' ||
                      $line === 'boolTrue = Bool;' || $line === 'bytes = Bytes;' || $line === 'int32 = Int32;' ||
                      $line === 'int53 = Int53;'|| $line === 'int64 = Int64;') {
                // skip built-in types
                continue;
            } else {
                $description = trim($description);
                if ($description[0] !== '@') {
                    $this->printError('Wrong description begin');
                }

                if (preg_match('/[^ ]@/', $description)) {
                    $this->printError("Wrong documentation '@' usage: $description");
                }
                $docs = explode('@', $description);
                array_shift($docs);
                $info = array();

                foreach ($docs as $doc) {
                    list($key, $value) = explode(' ', $doc, 2);
                    $value = trim($value);

                    if ($need_class_description) {
                        if ($key === 'description') {
                            $need_class_description = false;

                            $value = $this->escapeDocumentation($this->addDot($value));

                            $this->addAbstractClassDocumentation($current_class, $value);
                            continue;
                        } else {
                            $this->printError('Expected abstract class description');
                        }
                    }

                    if ($key === 'class') {
                        $current_class = $this->getClassName($value);
                        $need_class_description = true;

                        if ($is_function) {
                            $this->printError('Unexpected class definition');
                        }
                    } else {
                        if (isset($info[$key])) {
                            $this->printError("Duplicate info about `$key`");
                        }
                        $info[$key] = trim($value);
                    }
                }

                if (substr_count($line, '=') !== 1) {
                    $this->printError("Wrong '=' count");
                    continue;
                }

                list($fields, $type) = explode('=', $line);
                $type = $this->getClassName($type);
                $fields = explode(' ', trim($fields));
                $class_name = $this->getClassName(array_shift($fields));

                if ($type !== $current_class) {
                    $current_class = '';
                    $need_class_description = false;
                }

                if (!$is_function) {
                    $type_lower = strtolower($type);
                    $class_name_lower = strtolower($class_name);
                    if (empty($current_class) === ($type_lower !== $class_name_lower)) {
                        $this->printError('Wrong constructor name');
                    }
                    if (strpos($class_name_lower, $type_lower) !== 0) {
                        // $this->printError('Wrong constructor name');
                    }
                }

                $known_fields = array();
                foreach ($fields as $field) {
                    list ($field_name, $field_type) = explode(':', $field);
                    if (isset($info['param_'.$field_name])) {
                        $known_fields['param_'.$field_name] = $field_type;
                        continue;
                    }
                    if (isset($info[$field_name])) {
                        $known_fields[$field_name] = $field_type;
                        continue;
                    }
                    $this->printError("Have no documentation for field `$field_name`");
                }

                foreach ($info as $name => $value) {
                    if (!$value) {
                        $this->printError("Documentation for field $name of $class_name is empty");
                    } elseif (($value[0] < 'A' || $value[0] > 'Z') && ($value[0] < '0' || $value[0] > '9')) {
                        $this->printError("Documentation for field $name of $class_name doesn't begin with a capital letter");
                    }
                }

                foreach ($info as &$v) {
                    $v = $this->escapeDocumentation($this->addDot($v));
                }

                $description = $info['description'];
                unset($info['description']);

                if (!$description) {
                    $this->printError("Have no description for class `$class_name`");
                }

                foreach (array_diff_key($info, $known_fields) as $field_name => $field_info) {
                    $this->printError("Have info about nonexistent field `$field_name`");
                }

                if (array_keys($info) !== array_keys($known_fields)) {
                    $this->printError("Have wrong documentation for class `$class_name`");
                } else if ($description_line_count === 1 ? count($known_fields) >= 4 : $description_line_count !== count($known_fields) + 1) {
                    $this->printError("Documentation for fields of class `$class_name` must be split to different lines");
                }

                $base_class_name = $current_class ?: $this->getBaseClassName($is_function);
                $class_description = $description;
                $return_type = "";
                if ($is_function) {
                    $return_type = $this->getTypeName($type);
                    $class_description .= $this->getFunctionReturnTypeDescription($return_type, false);
                }
                $this->addClassDocumentation($class_name, $base_class_name, $return_type, $class_description);

                foreach ($known_fields as $name => $field_type) {
                    $may_be_null = stripos($info[$name], 'may be null') !== false;
                    $field_name = $this->getFieldName($name, $class_name);
                    $field_type_name = $this->getTypeName($field_type);
                    if ($this->isBuiltInType($field_type) && ($may_be_null || stripos($info[$name], '; pass null') !== false)) {
                        $this->printError("Field `$name` of class `$class_name` can't be marked as nullable");
                    }
                    $this->addFieldDocumentation($class_name, $field_name, $field_type_name, $info[$name], $may_be_null);
                }

                if ($is_function) {
                    $default_constructor_prefix = 'Default constructor for a function, which ';
                    $full_constructor_prefix = 'Creates a function, which ';
                    $class_description = lcfirst($description);
                    $class_description .= $this->getFunctionReturnTypeDescription($this->getTypeName($type), true);
                } else {
                    $default_constructor_prefix = '';
                    $full_constructor_prefix = '';
                }
                $this->addDefaultConstructorDocumentation($class_name, $default_constructor_prefix.$class_description);

                if ($known_fields) {
                    $this->addFullConstructorDocumentation($class_name, $full_constructor_prefix.$class_description, $known_fields, $info);
                }

                $description = '';
                $description_line_count = 0;
            }
        }

        $lines = file($source_file);
        $result = '';
        $current_class = '';
        $current_headers = '';
        foreach ($lines as $line) {
            $this->current_line = $line;
            if ($this->needRemoveLine($line)) {
                continue;
            }
            if ($this->needSkipLine($line)) {
                $result .= $current_headers.$line;
                $current_headers = '';
                continue;
            }
            if ($this->isHeaderLine($line)) {
                $current_headers .= $line;
                continue;
            }

            $current_class = $this->extractClassName($line) ?: $current_class;

            $fixed_line = rtrim($this->fixLine($line));

            $doc = '';
            if (isset($this->documentation[$fixed_line])) {
                $doc = $this->documentation[$fixed_line];
                // unset($this->documentation[$fixed_line]);
            } elseif (isset($this->documentation[$current_class.$fixed_line])) {
                $doc = $this->documentation[$current_class.$fixed_line];
                // unset($this->documentation[$current_class.$fixed_line]);
            } else {
                $this->printError('Have no docs for "'.$fixed_line.'"');
            }
            if ($doc) {
                $result .= $doc."\n";
            }
            if (isset($this->line_replacement[$fixed_line])) {
                $line = $this->line_replacement[$fixed_line];
            } elseif (isset($this->line_replacement[$current_class.$fixed_line])) {
                $line = $this->line_replacement[$current_class.$fixed_line];
            }
            $result .= $current_headers.$line;
            $current_headers = '';
        }

        if (file_get_contents($source_file) !== $result) {
            file_put_contents($source_file, $result);
        }

        if (count($this->documentation)) {
            // $this->printError('Have unused docs '.print_r(array_keys($this->documentation), true));
        }
    }
}
