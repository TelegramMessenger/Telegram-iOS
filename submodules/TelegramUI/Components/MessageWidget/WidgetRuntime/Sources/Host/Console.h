// `console`: a plain namespace object (not IDL; M1b plan, Ruling 10). Each method joins its arguments' string forms
// with spaces and logs the line to the host at its level.
#pragma once

#include "quickjs.h"

namespace wr {

void installConsole(JSContext* ctx);

} // namespace wr
