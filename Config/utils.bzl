OTHER_LINKER_FLAGS_KEY = 'OTHER_LDFLAGS'

def configs_with_config(config):
    return {
        "Debug": config,
        "Profile": config,
        "Release": config,
    }

def configs_with_updated_linker_flags(configs, other_linker_flags):
    if other_linker_flags == None:
        return configs
    else:
        updated_configs = { }
        for build_configuration in configs:
            updated_configs[build_configuration] = config_with_updated_linker_flags(
                configs[build_configuration],
                other_linker_flags)
        return updated_configs

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
