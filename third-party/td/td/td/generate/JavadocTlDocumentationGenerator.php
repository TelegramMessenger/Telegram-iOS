<?php

require_once 'TlDocumentationGenerator.php';

class JavadocTlDocumentationGenerator extends TlDocumentationGenerator
{
    private $nullable_type;
    private $nullable_annotation;
    private $java_version;

    protected function escapeDocumentation($doc)
    {
        $doc = preg_replace_callback('/(?<!["A-Za-z_\/])[A-Za-z]*_[A-Za-z_]*/',
            function ($word_matches)
            {
                return preg_replace_callback('/_([A-Za-z])/', function ($matches) {return strtoupper($matches[1]);}, $word_matches[0]);
            }, $doc);
        $doc = htmlspecialchars($doc, ENT_COMPAT, 'UTF-8');
        $doc = str_replace('*/', '*&#47;', $doc);
        return $doc;
    }

    protected function getFieldName($name, $class_name)
    {
        if (substr($name, 0, 6) === 'param_') {
            $name = substr($name, 6);
        }
        return preg_replace_callback('/_([A-Za-z])/', function ($matches) {return strtoupper($matches[1]);}, trim($name));
    }

    protected function getClassName($type)
    {
        return implode(array_map('ucfirst', explode('.', trim($type, "\r\n ;"))));
    }

    protected function getTypeName($type)
    {
        switch ($type) {
            case 'Bool':
                return 'boolean';
            case 'int32':
                return 'int';
            case 'int53':
            case 'int64':
                return 'long';
            case 'double':
                return $type;
            case 'string':
                return 'String';
            case 'bytes':
                return 'byte[]';
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
                    return $this->getTypeName(substr($type, 7, -1)).'[]';
                }

                if (preg_match('/[^A-Za-z0-9.]/', $type)) {
                    $this->printError("Wrong type $type");
                    return '';
                }
                return $this->getClassName($type);
        }
    }

    protected function getBaseClassName($is_function)
    {
        return $is_function ? 'Function' : 'Object';
    }

    protected function needRemoveLine($line)
    {
        return strpos(trim($line), '/**') === 0 || strpos(trim($line), '*') === 0 ||
            ($this->nullable_type && strpos($line, $this->nullable_type) > 0);
    }

    protected function needSkipLine($line)
    {
        $line = $this->fixLine(trim($line));
        return (strpos($line, 'public') !== 0 && !$this->isHeaderLine($line)) || $line === 'public @interface Constructors {}';
    }

    protected function isHeaderLine($line)
    {
        return trim($line) === '@Override' || trim($line) === '@Constructors';
    }

    protected function extractClassName($line)
    {
        if (strpos($line, 'public static class ') > 0) {
            return preg_split('/( |<|>)/', trim($line))[3];
        }
        return '';
    }

    protected function fixLine($line)
    {
        if (strpos($line, 'CONSTRUCTOR = ') > 0) {
            return substr($line, 0, strpos($line, '='));
        }

        return $this->nullable_annotation ? str_replace($this->nullable_annotation.' ', '', $line) : $line;
    }

    protected function addGlobalDocumentation()
    {
        if ($this->nullable_type) {
            $nullable_type_import = "import $this->nullable_type;".PHP_EOL;
        } else {
            $nullable_type_import = '';
        }

        $this->addDocumentation('public class TdApi {', <<<EOT
$nullable_type_import/**
 * This class contains as static nested classes all other TDLib interface
 * type-classes and function-classes.
 * <p>
 * It has no inner classes, functions or public members.
 */
EOT
);

        $this->addDocumentation('    public abstract static class Object {', <<<EOT
    /**
     * This class is a base class for all TDLib interface classes.
     */
EOT
);

        $this->addDocumentation("        public Object() {", <<<EOT
        /**
         * Default Object constructor.
         */
EOT
);

        $this->addDocumentation('        public abstract int getConstructor();', <<<EOT
        /**
         * Returns an identifier uniquely determining type of the object.
         *
         * @return a unique identifier of the object type.
         */
EOT
);

        $this->addDocumentation('        public native String toString();', <<<EOT
        /**
         * Returns a string representation of the object.
         *
         * @return a string representation of the object.
         */
EOT
);

        $this->addDocumentation('    public abstract static class Function<R extends Object> extends Object {', <<<EOT
    /**
     * This class is a base class for all TDLib interface function-classes.
     *
     * @param <R> The object type that is returned by the function
     */
EOT
);

        $this->addDocumentation("        public Function() {", <<<EOT
        /**
         * Default Function constructor.
         */
EOT
);

        $this->addDocumentation('        public static final int CONSTRUCTOR', <<<EOT
        /**
         * Identifier uniquely determining type of the object.
         */
EOT
);

        $this->addDocumentation('        public int getConstructor() {', <<<EOT
        /**
         * @return this.CONSTRUCTOR
         */
EOT
);
    }

    protected function addAbstractClassDocumentation($class_name, $documentation)
    {
        $this->addDocumentation("    public abstract static class $class_name extends Object {", <<<EOT
    /**
     * This class is an abstract base class.
     * $documentation
     */
EOT
);
        $this->addDocumentation("        public $class_name() {", <<<EOT
        /**
         * Default class constructor.
         */
EOT
);
    }

    protected function getFunctionReturnTypeDescription($return_type, $for_constructor)
    {
        $shift = $for_constructor ? '         ' : '     ';
        return PHP_EOL.$shift.'*'.PHP_EOL.$shift."* <p> Returns {@link $return_type $return_type} </p>";
    }

    protected function addClassDocumentation($class_name, $base_class_name, $return_type, $description)
    {
        $this->addDocumentation("    public static class $class_name extends ".$base_class_name.(empty($return_type) ? "" : "<".$return_type.">")." {", <<<EOT
    /**
     * $description
     */
EOT
);
    }

    protected function addFieldDocumentation($class_name, $field_name, $type_name, $field_info, $may_be_null)
    {
        $full_line = $class_name."        public $type_name $field_name;";
        $this->addDocumentation($full_line, <<<EOT
        /**
         * $field_info
         */
EOT
);
        if ($may_be_null && $this->nullable_annotation && ($this->java_version >= 8 || substr($type_name, -1) != ']')) {
            $this->addLineReplacement($full_line, "        $this->nullable_annotation public $type_name $field_name;".PHP_EOL);
        }
    }

    protected function addDefaultConstructorDocumentation($class_name, $class_description)
    {
        $this->addDocumentation("        public $class_name() {", <<<EOT
        /**
         * $class_description
         */
EOT
);
    }

    protected function addFullConstructorDocumentation($class_name, $class_description, $known_fields, $info)
    {
        $full_constructor = "        public $class_name(";
        $colon = '';
        foreach ($known_fields as $name => $type) {
            $full_constructor .= $colon.$this->getTypeName($type).' '.$this->getFieldName($name, $class_name);
            $colon = ', ';
        }
        $full_constructor .= ') {';

        $full_doc = <<<EOT
        /**
         * $class_description
         *

EOT;
        foreach ($known_fields as $name => $type) {
            $full_doc .= '         * @param '.$this->getFieldName($name, $class_name).' '.$info[$name].PHP_EOL;
        }
        $full_doc .= '         */';
        $this->addDocumentation($full_constructor, $full_doc);
    }

    public function __construct($nullable_type, $nullable_annotation, $java_version) {
        $this->nullable_type = trim($nullable_type);
        $this->nullable_annotation = trim($nullable_annotation);
        $this->java_version = intval($java_version);
    }
}

$nullable_type = isset($argv[3]) ? $argv[3] : '';
$nullable_annotation = isset($argv[4]) ? $argv[4] : '';
$java_version = isset($argv[5]) ? intval($argv[5]) : 7;

$generator = new JavadocTlDocumentationGenerator($nullable_type, $nullable_annotation, $java_version);
$generator->generate($argv[1], $argv[2]);
