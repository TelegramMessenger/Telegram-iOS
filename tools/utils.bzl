OTHER_LINKER_FLAGS_KEY = 'OTHER_LDFLAGS'

def config_with_updated_linker_flags(config, other_linker_flags, config_key=OTHER_LINKER_FLAGS_KEY):
    new_config = { }
    config_key_found = False
    for key in config:
        if key == config_key:
            new_config[key] = config[key] + (" %s" % other_linker_flags)
            config_key_found = True
        else:
            new_config[key] = config[key]

    if config_key_found == False:
        # If `config` does not currently contain `config_key`, add it. Inherit for good measure.
        new_config[config_key] = '$(inherited) ' + other_linker_flags

    return new_config


def xcode_configs(config):
    return {
        "Debug": config,
        "Profile": config,
        "Release": config,
    }

def merge_maps(dicts):
    result = dict()
    for d in dicts:
        for key in d:
            if key in result and result[key] != d[key]:
                fail(
                    "Conflicting files in file search paths. " +
                    "\"%s\" maps to both \"%s\" and \"%s\"." %
                    (key, result[key], d[key]),
                )
        result.update(d)
    return result


def basename(p):
    return p.rpartition("/")[-1]


def glob_map(glob_results):
    result = dict()
    for path in glob_results:
        file_name = basename(path)
        if file_name in result:
            fail('\"%s\" maps to both \"%s\" and \"%s\"' % (file_name, result[file_name], path))
        result[file_name] = path
    return result


def glob_sub_map(prefix, glob_specs):
    result = dict()
    for path in native.glob(glob_specs):
        if not path.startswith(prefix):
            fail('\"%s\" does not start with \"%s\"' % (path, prefix))
        file_key = path[len(prefix):]
        if file_key in result:
            fail('\"%s\" maps to both \"%s\" and \"%s\"' % (file_key, result[file_key], path))
        result[file_key] = path
    return result


def gen_header_targets(header_paths, prefix, flavor, source_rule, source_path):
    result = dict()
    for header_path in header_paths:
        name = prefix + header_path.replace('/', '_sub_')
        native.genrule(
            name = name + flavor,
            cmd = 'cp $(location :' + source_rule + ')/' + source_path + '/' + header_path + ' $OUT',
            out = name,
        )
        result[header_path] = ':' + name + flavor
    return result


def lib_basename(name):
    result = name
    if result.startswith('lib'):
        result = result[3:]
    if result.endswith('.a'):
        result = result[:-2]
    return result


def combined_config(dicts):
    result = dict()
    for d in dicts:
        result.update(d)
    return result


valid_build_variants = ['project', 'release']

def get_build_variant():
    build_variant = native.read_config('build', 'variant', '')
    if build_variant not in valid_build_variants:
        fail('build_variant should be one of %s' % valid_build_variants)
    return build_variant

