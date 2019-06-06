OTHER_LINKER_FLAGS_KEY = 'OTHER_LDFLAGS'

# Either appends or assigns `other_linker_flags` to `config` under `config_key`.
# Params:
# - config: A dictionary of config names and their values
# - additional_linker_flags: A string-representable value of additional linker flags
# - config_key: The key to which to append or assign the additional linker flags
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

# Creates a dictionary where the top level keys are the supported build configurations and the value of each key is `config`.
def configs_with_config(config):
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
    """Returns the basename (i.e., the file portion) of a path.
    Note that if `p` ends with a slash, this function returns an empty string.
    This matches the behavior of Python's `os.path.basename`, but differs from
    the Unix `basename` command (which would return the path segment preceding
    the final slash).
    Args:
    p: The path whose basename should be returned.
    Returns:
    The basename of the path, which includes the extension.
    """
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

def gen_header_targets(header_paths, prefix, source_rule, source_path):
    result = dict()
    for header_path in header_paths:
        name = prefix + header_path.replace('/', '_sub_')
        native.genrule(
            name = name,
            cmd = 'cp $(location :' + source_rule + ')/' + source_path + '/' + header_path + ' $OUT',
            out = name,
        )
        result[header_path] = ':' + name
    return result

def lib_basename(name):
    result = name
    if result.startswith('lib'):
        result = result[3:]
    if result.endswith('.a'):
        result = result[:-2]
    return result

def gen_lib_targets(lib_paths, prefix, source_rule, source_path):
    result = []
    for lib_path in lib_paths:
        name = lib_path.replace('/', '_sub_')
        native.genrule(
            name = name,
            cmd = 'cp $(location :' + source_rule + ')/' + source_path + '/' + lib_path + ' $OUT',
            out = name
        )
        result.append(name)
    return result
