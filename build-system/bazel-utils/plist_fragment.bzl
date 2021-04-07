
def _plist_fragment(ctx):
    output = ctx.outputs.out

    found_keys = list()
    template = ctx.attr.template
    current_start = 0
    for i in range(len(template)):
        start_index = template.find("{", current_start)
        if start_index == -1:
            break
        end_index = template.find("}", start_index + 1)
        if end_index == -1:
            fail("Could not find the matching '}' for the '{' at {}".format(start_index))
        found_keys.append(template[start_index + 1:end_index])
        current_start = end_index + 1

    resolved_values = dict()
    for key in found_keys:
        value = ctx.var.get(key, None)
        if value == None:
            fail("Expected value for --define={} was not found".format(key))
        resolved_values[key] = value

    plist_string = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    """ + template.format(**resolved_values) + """
    </dict>
    </plist>
    """

    ctx.actions.write(
        output = output,
        content = plist_string,
    )

plist_fragment = rule(
    implementation = _plist_fragment,
    attrs = {
        "extension": attr.string(mandatory = True),
        "template": attr.string(mandatory = True),
    },
    outputs = {
        "out": "%{name}.%{extension}"
    },
)
