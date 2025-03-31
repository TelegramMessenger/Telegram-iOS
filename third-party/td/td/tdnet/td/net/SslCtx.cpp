//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/net/SslCtx.h"

#include "td/utils/common.h"
#include "td/utils/crypto.h"
#include "td/utils/FlatHashMap.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"
#include "td/utils/port/path.h"
#include "td/utils/port/wstring_convert.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

#if !TD_EMSCRIPTEN
#include <openssl/err.h>
#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <openssl/x509_vfy.h>

#include <cstring>
#include <memory>
#include <mutex>

#if TD_PORT_WINDOWS
#include <wincrypt.h>
#endif

namespace td {

namespace detail {
namespace {
int verify_callback(int preverify_ok, X509_STORE_CTX *ctx) {
  if (!preverify_ok) {
    char buf[256];
    X509_NAME_oneline(X509_get_subject_name(X509_STORE_CTX_get_current_cert(ctx)), buf, 256);

    int err = X509_STORE_CTX_get_error(ctx);
    auto warning = PSTRING() << "verify error:num=" << err << ":" << X509_verify_cert_error_string(err)
                             << ":depth=" << X509_STORE_CTX_get_error_depth(ctx) << ":" << Slice(buf, std::strlen(buf));
    double now = Time::now();

    static std::mutex warning_mutex;
    {
      std::lock_guard<std::mutex> lock(warning_mutex);
      static FlatHashMap<string, double> next_warning_time;
      double &next = next_warning_time[warning];
      if (next <= now) {
        next = now + 300;  // one warning per 5 minutes
        LOG(WARNING) << warning;
      }
    }
  }

  return preverify_ok;
}

X509_STORE *load_system_certificate_store() {
  int32 cert_count = 0;
  int32 file_count = 0;
  LOG(DEBUG) << "Begin to load system certificate store";
  SCOPE_EXIT {
    LOG(DEBUG) << "End to load " << cert_count << " certificates from " << file_count << " files from system store";
    if (ERR_peek_error() != 0) {
      auto error = create_openssl_error(-22, "Have unprocessed errors");
      LOG(INFO) << error;
    }
  };
#if TD_PORT_WINDOWS
  auto flags = CERT_STORE_OPEN_EXISTING_FLAG | CERT_STORE_READONLY_FLAG | CERT_SYSTEM_STORE_CURRENT_USER;
  HCERTSTORE system_store =
      CertOpenStore(CERT_STORE_PROV_SYSTEM_W, X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, HCRYPTPROV_LEGACY(), flags,
                    static_cast<const void *>(to_wstring("ROOT").ok().c_str()));
  if (!system_store) {
    return nullptr;
  }
  X509_STORE *store = X509_STORE_new();
  if (store == nullptr) {
    return nullptr;
  }

  for (PCCERT_CONTEXT cert_context = CertEnumCertificatesInStore(system_store, nullptr); cert_context != nullptr;
       cert_context = CertEnumCertificatesInStore(system_store, cert_context)) {
    const unsigned char *in = cert_context->pbCertEncoded;
    X509 *x509 = d2i_X509(nullptr, &in, static_cast<long>(cert_context->cbCertEncoded));
    if (x509 != nullptr) {
      if (X509_STORE_add_cert(store, x509) != 1) {
        auto error_code = ERR_peek_error();
        auto error = create_openssl_error(-20, "Failed to add certificate");
        if (ERR_GET_REASON(error_code) != X509_R_CERT_ALREADY_IN_HASH_TABLE) {
          LOG(ERROR) << error;
        } else {
          LOG(INFO) << error;
        }
      } else {
        cert_count++;
      }

      X509_free(x509);
    } else {
      LOG(ERROR) << create_openssl_error(-21, "Failed to load X509 certificate");
    }
  }

  CertCloseStore(system_store, 0);
#else
  X509_STORE *store = X509_STORE_new();
  if (store == nullptr) {
    return nullptr;
  }

  auto add_file = [&](CSlice path) {
    if (X509_STORE_load_locations(store, path.c_str(), nullptr) != 1) {
      auto error = create_openssl_error(-20, "Failed to add certificate");
      LOG(INFO) << path << ": " << error;
    } else {
      file_count++;
    }
  };

  string default_cert_dir = X509_get_default_cert_dir();
  for (auto cert_dir : full_split(default_cert_dir, ':')) {
    walk_path(cert_dir, [&](CSlice path, WalkPath::Type type) {
      if (type != WalkPath::Type::RegularFile && type != WalkPath::Type::Symlink) {
        return type == WalkPath::Type::EnterDir && path != cert_dir ? WalkPath::Action::SkipDir
                                                                    : WalkPath::Action::Continue;
      }
      add_file(path);
      return WalkPath::Action::Continue;
    }).ignore();
  }

  string default_cert_path = X509_get_default_cert_file();
  if (!default_cert_path.empty()) {
    add_file(default_cert_path);
  }

#if OPENSSL_VERSION_NUMBER >= 0x10100000L
  auto objects = X509_STORE_get0_objects(store);
  cert_count = objects == nullptr ? 0 : sk_X509_OBJECT_num(objects);
#else
  cert_count = -1;
#endif
#endif

  return store;
}

using SslCtxPtr = std::shared_ptr<SSL_CTX>;

Result<SslCtxPtr> do_create_ssl_ctx(CSlice cert_file, SslCtx::VerifyPeer verify_peer) {
  auto ssl_method =
#if OPENSSL_VERSION_NUMBER >= 0x10100000L
      TLS_client_method();
#else
      SSLv23_client_method();
#endif
  if (ssl_method == nullptr) {
    return create_openssl_error(-6, "Failed to create an SSL client method");
  }
  auto ssl_ctx = SSL_CTX_new(ssl_method);
  if (!ssl_ctx) {
    return create_openssl_error(-7, "Failed to create an SSL context");
  }
  auto ssl_ctx_ptr = SslCtxPtr(ssl_ctx, SSL_CTX_free);
  long options = 0;
#ifdef SSL_OP_NO_SSLv2
  options |= SSL_OP_NO_SSLv2;
#endif
#ifdef SSL_OP_NO_SSLv3
  options |= SSL_OP_NO_SSLv3;
#endif
  SSL_CTX_set_options(ssl_ctx, options);
#if OPENSSL_VERSION_NUMBER >= 0x10100000L
  SSL_CTX_set_min_proto_version(ssl_ctx, TLS1_VERSION);
#endif
  SSL_CTX_set_mode(ssl_ctx, SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER | SSL_MODE_ENABLE_PARTIAL_WRITE);

  if (cert_file.empty()) {
    auto *store = load_system_certificate_store();
    if (store == nullptr) {
      auto error = create_openssl_error(-8, "Failed to load system certificate store");
      if (verify_peer == SslCtx::VerifyPeer::On) {
        return std::move(error);
      } else {
        LOG(ERROR) << error;
      }
    } else {
      SSL_CTX_set_cert_store(ssl_ctx, store);
    }
  } else {
    if (SSL_CTX_load_verify_locations(ssl_ctx, cert_file.c_str(), nullptr) == 0) {
      return create_openssl_error(-8, "Failed to set custom certificate file");
    }
  }

  if (verify_peer == SslCtx::VerifyPeer::On) {
    SSL_CTX_set_verify(ssl_ctx, SSL_VERIFY_PEER, verify_callback);

    constexpr int DEFAULT_VERIFY_DEPTH = 10;
    SSL_CTX_set_verify_depth(ssl_ctx, DEFAULT_VERIFY_DEPTH);
  } else {
    SSL_CTX_set_verify(ssl_ctx, SSL_VERIFY_NONE, nullptr);
  }

  string cipher_list;
  if (SSL_CTX_set_cipher_list(ssl_ctx, cipher_list.empty() ? "DEFAULT" : cipher_list.c_str()) == 0) {
    return create_openssl_error(-9, PSLICE() << "Failed to set cipher list \"" << cipher_list << '"');
  }

  return std::move(ssl_ctx_ptr);
}

Result<SslCtxPtr> get_default_ssl_ctx() {
  static auto ctx = do_create_ssl_ctx(CSlice(), SslCtx::VerifyPeer::On);
  if (ctx.is_error()) {
    return ctx.error().clone();
  }

  return ctx.ok();
}

Result<SslCtxPtr> get_default_unverified_ssl_ctx() {
  static auto ctx = do_create_ssl_ctx(CSlice(), SslCtx::VerifyPeer::Off);
  if (ctx.is_error()) {
    return ctx.error().clone();
  }

  return ctx.ok();
}

}  // namespace

class SslCtxImpl {
 public:
  Status init(CSlice cert_file, SslCtx::VerifyPeer verify_peer) {
    SslCtx::init_openssl();

    clear_openssl_errors("Before SslCtx::init");

    if (cert_file.empty()) {
      if (verify_peer == SslCtx::VerifyPeer::On) {
        TRY_RESULT_ASSIGN(ssl_ctx_ptr_, get_default_ssl_ctx());
      } else {
        TRY_RESULT_ASSIGN(ssl_ctx_ptr_, get_default_unverified_ssl_ctx());
      }
      return Status::OK();
    }

    auto start_time = Time::now();
    auto r_ssl_ctx_ptr = do_create_ssl_ctx(cert_file, verify_peer);
    auto elapsed_time = Time::now() - start_time;
    if (elapsed_time >= 0.1) {
      LOG(WARNING) << "SSL context creation took " << elapsed_time << " seconds";
    }
    if (r_ssl_ctx_ptr.is_error()) {
      return r_ssl_ctx_ptr.move_as_error();
    }
    ssl_ctx_ptr_ = r_ssl_ctx_ptr.move_as_ok();
    return Status::OK();
  }

  void *get_openssl_ctx() const {
    return static_cast<void *>(ssl_ctx_ptr_.get());
  }

 private:
  SslCtxPtr ssl_ctx_ptr_;
};

}  // namespace detail

SslCtx::SslCtx() = default;

SslCtx::SslCtx(const SslCtx &other) {
  if (other.impl_) {
    impl_ = make_unique<detail::SslCtxImpl>(*other.impl_);
  }
}

SslCtx &SslCtx::operator=(const SslCtx &other) {
  if (other.impl_) {
    impl_ = make_unique<detail::SslCtxImpl>(*other.impl_);
  } else {
    impl_ = nullptr;
  }
  return *this;
}

SslCtx::SslCtx(SslCtx &&) noexcept = default;

SslCtx &SslCtx::operator=(SslCtx &&) noexcept = default;

SslCtx::~SslCtx() = default;

void SslCtx::init_openssl() {
  static bool is_inited = [] {
#if OPENSSL_VERSION_NUMBER >= 0x10100000L
    return OPENSSL_init_ssl(0, nullptr) != 0;
#else
    OpenSSL_add_all_algorithms();
    SSL_load_error_strings();
    return OpenSSL_add_ssl_algorithms() != 0;
#endif
  }();
  CHECK(is_inited);
}

Result<SslCtx> SslCtx::create(CSlice cert_file, VerifyPeer verify_peer) {
  auto impl = make_unique<detail::SslCtxImpl>();
  TRY_STATUS(impl->init(cert_file, verify_peer));
  return SslCtx(std::move(impl));
}

void *SslCtx::get_openssl_ctx() const {
  return impl_ == nullptr ? nullptr : impl_->get_openssl_ctx();
}

SslCtx::SslCtx(unique_ptr<detail::SslCtxImpl> impl) : impl_(std::move(impl)) {
}

}  // namespace td

#else

namespace td {

namespace detail {
class SslCtxImpl {};
}  // namespace detail

SslCtx::SslCtx() = default;

SslCtx::SslCtx(const SslCtx &other) {
  UNREACHABLE();
}

SslCtx &SslCtx::operator=(const SslCtx &other) {
  UNREACHABLE();
  return *this;
}

SslCtx::SslCtx(SslCtx &&) noexcept = default;

SslCtx &SslCtx::operator=(SslCtx &&) noexcept = default;

SslCtx::~SslCtx() = default;

void SslCtx::init_openssl() {
}

Result<SslCtx> SslCtx::create(CSlice cert_file, VerifyPeer verify_peer) {
  return Status::Error("Not supported in Emscripten");
}

void *SslCtx::get_openssl_ctx() const {
  return nullptr;
}

SslCtx::SslCtx(unique_ptr<detail::SslCtxImpl> impl) : impl_(std::move(impl)) {
}

}  // namespace td

#endif
