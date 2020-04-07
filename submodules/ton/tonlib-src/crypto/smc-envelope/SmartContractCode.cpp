/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "SmartContractCode.h"

#include "vm/boc.h"
#include <map>

#include "td/utils/base64.h"

namespace ton {
namespace {
// WALLET_REVISION = 2;
// WALLET2_REVISION = 2;
// WALLET3_REVISION = 2;
// HIGHLOAD_WALLET_REVISION = 2;
// HIGHLOAD_WALLET2_REVISION = 2;
// DNS_REVISION = 1;
const auto& get_map() {
  static auto map = [] {
    std::map<std::string, td::Ref<vm::Cell>, std::less<>> map;
    auto with_tvm_code = [&](auto name, td::Slice code_str) {
      map[name] = vm::std_boc_deserialize(td::base64_decode(code_str).move_as_ok()).move_as_ok();
    };
#include "smartcont/auto/multisig-code.cpp"
#include "smartcont/auto/simple-wallet-ext-code.cpp"
#include "smartcont/auto/simple-wallet-code.cpp"
#include "smartcont/auto/wallet-code.cpp"
#include "smartcont/auto/highload-wallet-code.cpp"
#include "smartcont/auto/highload-wallet-v2-code.cpp"
#include "smartcont/auto/dns-manual-code.cpp"

    with_tvm_code("highload-wallet-r1",
                  "te6ccgEBBgEAhgABFP8A9KQT9KDyyAsBAgEgAgMCAUgEBQC88oMI1xgg0x/TH9Mf+CMTu/Jj7UTQ0x/TH9P/"
                  "0VEyuvKhUUS68qIE+QFUEFX5EPKj9ATR+AB/jhghgBD0eG+hb6EgmALTB9QwAfsAkTLiAbPmWwGkyMsfyx/L/"
                  "8ntVAAE0DAAEaCZL9qJoa4WPw==");
    with_tvm_code("highload-wallet-r2",
                  "te6ccgEBCAEAlwABFP8A9KQT9LzyyAsBAgEgAgMCAUgEBQC48oMI1xgg0x/TH9Mf+CMTu/Jj7UTQ0x/TH9P/"
                  "0VEyuvKhUUS68qIE+QFUEFX5EPKj9ATR+AB/jhYhgBD0eG+lIJgC0wfUMAH7AJEy4gGz5lsBpMjLH8sfy//"
                  "J7VQABNAwAgFIBgcAF7s5ztRNDTPzHXC/+AARuMl+1E0NcLH4");
    with_tvm_code("highload-wallet-v2-r1",
                  "te6ccgEBBwEA1gABFP8A9KQT9KDyyAsBAgEgAgMCAUgEBQHu8oMI1xgg0x/TP/gjqh9TILnyY+1E0NMf0z/T//"
                  "QE0VNggED0Dm+hMfJgUXO68qIH+QFUEIf5EPKjAvQE0fgAf44YIYAQ9HhvoW+"
                  "hIJgC0wfUMAH7AJEy4gGz5luDJaHIQDSAQPRDiuYxyBLLHxPLP8v/9ADJ7VQGAATQMABBoZfl2omhpj5jpn+n/"
                  "mPoCaKkQQCB6BzfQmMktv8ld0fFADgggED0lm+hb6EyURCUMFMDud4gkzM2AZIyMOKz");
    with_tvm_code("highload-wallet-v2-r2",
                  "te6ccgEBCQEA5QABFP8A9KQT9LzyyAsBAgEgAgMCAUgEBQHq8oMI1xgg0x/TP/gjqh9TILnyY+1E0NMf0z/T//"
                  "QE0VNggED0Dm+hMfJgUXO68qIH+QFUEIf5EPKjAvQE0fgAf44WIYAQ9HhvpSCYAtMH1DAB+wCRMuIBs+"
                  "ZbgyWhyEA0gED0Q4rmMcgSyx8Tyz/L//QAye1UCAAE0DACASAGBwAXvZznaiaGmvmOuF/8AEG+X5dqJoaY+Y6Z/p/"
                  "5j6AmipEEAgegc30JjJLb/JXdHxQANCCAQPSWb6UyURCUMFMDud4gkzM2AZIyMOKz");
    with_tvm_code("simple-wallet-r1",
                  "te6ccgEEAQEAAAAAUwAAov8AIN0gggFMl7qXMO1E0NcLH+Ck8mCBAgDXGCDXCx/tRNDTH9P/"
                  "0VESuvKhIvkBVBBE+RDyovgAAdMfMSDXSpbTB9QC+wDe0aTIyx/L/8ntVA==");
    with_tvm_code("simple-wallet-r2",
                  "te6ccgEBAQEAXwAAuv8AIN0gggFMl7ohggEznLqxnHGw7UTQ0x/XC//jBOCk8mCBAgDXGCDXCx/tRNDTH9P/"
                  "0VESuvKhIvkBVBBE+RDyovgAAdMfMSDXSpbTB9QC+wDe0aTIyx/L/8ntVA==");
    with_tvm_code("wallet-r1",
                  "te6ccgEBAQEAVwAAqv8AIN0gggFMl7qXMO1E0NcLH+Ck8mCDCNcYINMf0x8B+CO78mPtRNDTH9P/0VExuvKhA/"
                  "kBVBBC+RDyovgAApMg10qW0wfUAvsA6NGkyMsfy//J7VQ=");
    with_tvm_code("wallet-r2",
                  "te6ccgEBAQEAYwAAwv8AIN0gggFMl7ohggEznLqxnHGw7UTQ0x/XC//jBOCk8mCDCNcYINMf0x8B+CO78mPtRNDTH9P/"
                  "0VExuvKhA/kBVBBC+RDyovgAApMg10qW0wfUAvsA6NGkyMsfy//J7VQ=");
    with_tvm_code("wallet3-r1",
                  "te6ccgEBAQEAYgAAwP8AIN0gggFMl7qXMO1E0NcLH+Ck8mCDCNcYINMf0x/TH/gjE7vyY+1E0NMf0x/T/"
                  "9FRMrryoVFEuvKiBPkBVBBV+RDyo/gAkyDXSpbTB9QC+wDo0QGkyMsfyx/L/8ntVA==");
    with_tvm_code("wallet3-r2",
                  "te6ccgEBAQEAcQAA3v8AIN0gggFMl7ohggEznLqxn3Gw7UTQ0x/THzHXC//jBOCk8mCDCNcYINMf0x/TH/gjE7vyY+1E0NMf0x/"
                  "T/9FRMrryoVFEuvKiBPkBVBBV+RDyo/gAkyDXSpbTB9QC+wDo0QGkyMsfyx/L/8ntVA==");
    with_tvm_code(
        "dns-manual-r1",
        "te6ccgECGAEAAtAAART/APSkE/S88sgLAQIBIAIDAgFIBAUC7PLbPAWDCNcYIPkBAdMf0z/"
        "4I6ofUyC58mNTKoBA9A5voTHyYFKUuvKiVBNG+RDyo/gAItcLBcAzmDQBdtch0/"
        "8wjoVa2zxAA+"
        "IDgyWhyEAHgED0Q44aIIBA9JZvpTJREJQwUwe53iCTMzUBkjIw4rPmNVUD8AQREgICxQYHAgEgDA0CAc8ICQAIqoJfAwIBSAoLACHWQK5Y+"
        "J5Z/l//oAegBk9qpAAFF8DgABcyPQAydBBM/Rw8qGAAF72c52omhpr5jrhf/"
        "AIBIA4PABG7Nz7UTQ1wsfgD+"
        "7owwh10kglF8DcG3hIHew8l4ieNci1wsHnnDIUATPFhPLB8nQAqYI3iDACJRfA3Bt4Ns8FF8EI3ADqwKY0wcBwAAToQLkIG2OnF8DIcjLBiTPF"
        "snQhAlUQgHbPAWlFbIgwQEVQzDmMzUilF8FcG3hMgHHAJMxfwHfAtdJpvmBEVEAAYIcAAkjEB4AKAEPRqABztRNDTH9M/0//"
        "0BPQE0QE2cFmOlNs8IMcBnCDXSpPUMNCTMn8C4t4i5jAxEwT20wUhwQqOLCGRMeEhwAGXMdMH1AL7AOABwAmOFNQh+wTtQwLQ7R7tU1RiA/"
        "EGgvIA4PIt4HAiwRSUMNIPAd5tbSTBHoreJMEUjpElhAkj2zwzApUyxwDyo5Fb4t4kwAuOEzQC9ARQJIAQ9G4wECOECVnwAQHgJMAMiuAwFBUW"
        "FwCEMQLTAAHAAZPUAdCY0wUBqgLXGAHiINdJwg/"
        "ypiB41yLXCwfyaHBTEddJqTYCmNMHAcAAEqEB5DDIywYBzxbJ0FADACBZ9KhvpSCUAvQEMJIybeICACg0A4AQ9FqZECOECUBE8AEBkjAx4gBmM"
        "SLAFZwy9AQQI4QJUELwAQHgIsAWmDIChAn0czAB4DAyIMAfkzD0BODAIJJtAeDyLG0B");
    return map;
  }();
  return map;
}
}  // namespace

td::Result<td::Ref<vm::Cell>> SmartContractCode::load(td::Slice name) {
  LOG(ERROR) << "LOAD " << name;
  auto& map = get_map();
  auto it = map.find(name);
  if (it == map.end()) {
    return td::Status::Error(PSLICE() << "Can't load td::Ref<vm::Cell> " << name);
  }
  return it->second;
}

td::Span<int> SmartContractCode::get_revisions(Type type) {
  switch (type) {
    case Type::WalletV1: {
      static int res[] = {1, 2};
      return res;
    }
    case Type::WalletV2: {
      static int res[] = {1, 2};
      return res;
    }
    case Type::WalletV3: {
      static int res[] = {1, 2};
      return res;
    }
    case Type::WalletV1Ext: {
      static int res[] = {-1};
      return res;
    }
    case Type::HighloadWalletV1: {
      static int res[] = {-1, 1, 2};
      return res;
    }
    case Type::HighloadWalletV2: {
      static int res[] = {-1, 1, 2};
      return res;
    }
    case Type::Multisig: {
      static int res[] = {-1};
      return res;
    }
    case Type::ManualDns: {
      static int res[] = {-1, 1};
      return res;
    }
  }
  UNREACHABLE();
  return {};
}

td::Result<int> SmartContractCode::validate_revision(Type type, int revision) {
  auto revisions = get_revisions(type);
  if (revision == -1) {
    if (revisions[0] == -1) {
      return -1;
    }
    return revisions[revisions.size() - 1];
  }
  if (revision == 0) {
    return revisions[revisions.size() - 1];
  }
  for (auto x : revisions) {
    if (x == revision) {
      return revision;
    }
  }
  return td::Status::Error("No such revision");
}

td::Ref<vm::Cell> SmartContractCode::get_code(Type type, int ext_revision) {
  auto revision = validate_revision(type, ext_revision).move_as_ok();
  auto basename = [](Type type) -> td::Slice {
    switch (type) {
      case Type::WalletV1:
        return "simple-wallet";
      case Type::WalletV2:
        return "wallet";
      case Type::WalletV3:
        return "wallet3";
      case Type::WalletV1Ext:
        return "simple-wallet-ext";
      case Type::HighloadWalletV1:
        return "highload-wallet";
      case Type::HighloadWalletV2:
        return "highload-wallet-v2";
      case Type::Multisig:
        return "multisig";
      case Type::ManualDns:
        return "dns-manual";
    }
    UNREACHABLE();
    return "";
  }(type);
  if (revision == -1) {
    return load(basename).move_as_ok();
  }
  return load(PSLICE() << basename << "-r" << revision).move_as_ok();
}

}  // namespace ton
