<?php
    if ($argc !== 2) {
        exit();
    }
    $file = file_get_contents($argv[1]);

    if (strpos($file, 'androidx.annotation.IntDef') !== false) {
        exit();
    }

    $file = str_replace('import androidx.annotation.Nullable;', 'import androidx.annotation.IntDef;'.PHP_EOL.
                                                                'import androidx.annotation.Nullable;'.PHP_EOL.
                                                                PHP_EOL.
                                                                'import java.lang.annotation.Retention;'.PHP_EOL.
                                                                'import java.lang.annotation.RetentionPolicy;'.PHP_EOL, $file);

    preg_match_all('/public static class ([A-Za-z0-9]+) extends ([A-Za-z0-9]+)/', $file, $matches, PREG_SET_ORDER);
    $children = [];
    foreach ($matches as $val) {
        if ($val[2] === 'Object') {
            continue;
        }

        $children[$val[2]][] = '            '.$val[1].'.CONSTRUCTOR';
    }

    $file = preg_replace_callback('/public abstract static class ([A-Za-z0-9]+)(<R extends Object>)? extends Object [{]/',
        function ($val) use ($children) {
            $values = implode(','.PHP_EOL, $children[$val[1]]);
            return $val[0].<<<EOL

        /**
         * Describes possible values returned by getConstructor().
         */
        @Retention(RetentionPolicy.SOURCE)
        @IntDef({
$values
        })
        public @interface Constructors {}

        /**
         * @return identifier uniquely determining type of the object.
         */
        @Constructors
        @Override
        public abstract int getConstructor();
EOL;
        },
        $file);

    file_put_contents($argv[1], $file);
