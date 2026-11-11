// widget-sandbox v0.5.0 (docs/sdk-v1.md §2.18): a wallet call's argument and a request's options as the SDK policy
// checks them. Upstream's shim checks the JS value itself (sdk-policy.ts); the policy's C++ twin, which this runtime
// runs, checks JSON. This converter gives the twin exactly what decides the shim's answer.
#pragma once

#include <optional>

#include "quickjs.h"
#include "twidget/json.h"

namespace wr {

/// `value` as JSON for the SDK policy's checkWalletTransaction, checkSignDataPayload and checkRequestOptions, or nullopt
/// where the shim's checks refuse it whatever it holds. The shim's rules:
/// - the value itself must be a non-null, non-array object that is not a function (`isPlainObject`);
/// - an object below it gives its own enumerable string keys (`Object.keys`), each value read as the shim reads it
///   (getters and proxies run); an array (`Array.isArray`) the values of its iterator, as the shim's `for…of` over a
///   transaction's messages, once its `length` is from 1 to 255;
/// - `undefined` is null with its key kept, so a check's `onlyKeys` still sees the key;
/// - a function, symbol or bigint is `{}`, which every check refuses where the shim's `typeof` would;
/// - an object deeper than any check reads (a message's field) is `{}`, unread.
/// A value no check can pass is refused before it is read further: an object with more keys than any check allows
/// (5), an array whose `length` or iterator gives fewer than 1 or more than 255 values (a transaction's messages), a
/// string longer than 65,536 UTF-16 code units.
/// Throws Thrown when script the conversion runs throws.
std::optional<twidget::Json> walletArgumentJson(JSContext* ctx, JSValueConst value);

} // namespace wr
