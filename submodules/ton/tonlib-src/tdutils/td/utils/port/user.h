#pragma once

#include "td/utils/port/config.h"
#include "td/utils/port/platform.h"
#include "td/utils/Status.h"

namespace td {

td::Status change_user(td::Slice username);

}
