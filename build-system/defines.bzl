def string_value(ctx, define_name):
    """Looks up a define on ctx for a string value.

    Will also report an error if the value is not defined.

    Args:
      ctx: A skylark context.
      define_name: The name of the define to look up.

    Returns:
      The value of the define.
    """
    value = ctx.var.get(define_name, None)
    if value != None:
        return value
    fail("Expected value for --define={} was not found".format(
        define_name,
    ))

def _file_from_define(ctx):
    output = ctx.outputs.out
    ctx.actions.write(
        output = output,
        content = "profile_data",
    )

file_from_define = rule(
    implementation = _file_from_define,
    attrs = {
        "define_name": attr.string(mandatory = True),
        "extension": attr.string(mandatory = True),
    },
    outputs = {
        "out": "%{name}.%{extension}"
    },
)
