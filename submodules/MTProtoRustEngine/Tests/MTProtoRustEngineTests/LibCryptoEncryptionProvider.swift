import Foundation
import EncryptionProvider

/// MtProtoKit's key exchange needs a real `EncryptionProvider`. The app links OpenSSL for it; the tests
/// load an installed libcrypto at run time instead (`MTPROTO_TEST_LIBCRYPTO`, or Homebrew's OpenSSL 3),
/// and the tests that need it are skipped without one.
final class LibCryptoEncryptionProvider: NSObject, EncryptionProvider {
    fileprivate let library: LibCrypto

    init?(path: String? = ProcessInfo.processInfo.environment["MTPROTO_TEST_LIBCRYPTO"]) {
        let candidates = [path, "/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib", "/usr/local/opt/openssl@3/lib/libcrypto.3.dylib"].compactMap { $0 }
        guard let library = candidates.lazy.compactMap(LibCrypto.init(path:)).first else {
            return nil
        }
        self.library = library
    }

    func createBignumContext() -> MTBignumContext {
        return LibCryptoBignumContext(library: self.library)
    }

    func rsaEncrypt(withPublicKey publicKey: String, data: Data) -> Data? {
        let key = self.parseKey(publicKey)
        guard key.rsa != nil else {
            return nil
        }
        let context = LibCryptoBignumContext(library: self.library)
        let value = context.create()
        context.assignBin(to: value, value: data)
        let result = context.create()
        guard context.modExp(into: result, a: value, b: context.rsaGetE(key), mod: context.rsaGetN(key)) else {
            return nil
        }
        return context.getBin(result)
    }

    func rsaEncryptPKCS1OAEP(withPublicKey publicKey: String, data: Data) -> Data? {
        return nil
    }

    func parseRSAPublicKey(_ publicKey: String) -> MTRsaPublicKey {
        return self.parseKey(publicKey)
    }

    func macosRSAEncrypt(_ publicKey: String, data: Data) -> Data {
        return self.rsaEncrypt(withPublicKey: publicKey, data: data) ?? Data()
    }

    private func parseKey(_ publicKey: String) -> LibCryptoRsaPublicKey {
        let library = self.library
        guard let bio = library.BIO_new(library.BIO_s_mem()) else {
            return LibCryptoRsaPublicKey(library: library, rsa: nil)
        }
        defer {
            _ = library.BIO_free(bio)
        }
        let bytes = Array(publicKey.utf8)
        _ = bytes.withUnsafeBytes { library.BIO_write(bio, $0.baseAddress, Int32($0.count)) }
        return LibCryptoRsaPublicKey(library: library, rsa: library.PEM_read_bio_RSAPublicKey(bio, nil, nil, nil))
    }
}

fileprivate final class LibCrypto {
    typealias Pointer = OpaquePointer

    let BN_CTX_new: @convention(c) () -> Pointer?
    let BN_CTX_free: @convention(c) (Pointer?) -> Void
    let BN_new: @convention(c) () -> Pointer?
    let BN_dup: @convention(c) (Pointer?) -> Pointer?
    let BN_clear_free: @convention(c) (Pointer?) -> Void
    let BN_set_flags: @convention(c) (Pointer?, Int32) -> Void
    let BN_set_word: @convention(c) (Pointer?, UInt) -> Int32
    let BN_hex2bn: @convention(c) (UnsafeMutablePointer<Pointer?>?, UnsafePointer<CChar>?) -> Int32
    let BN_bin2bn: @convention(c) (UnsafeRawPointer?, Int32, Pointer?) -> Pointer?
    let BN_is_one: @convention(c) (Pointer?) -> Int32
    let BN_is_zero: @convention(c) (Pointer?) -> Int32
    let BN_num_bits: @convention(c) (Pointer?) -> Int32
    let BN_bn2bin: @convention(c) (Pointer?, UnsafeMutableRawPointer?) -> Int32
    let BN_is_prime_ex: @convention(c) (Pointer?, Int32, Pointer?, Pointer?) -> Int32
    let BN_cmp: @convention(c) (Pointer?, Pointer?) -> Int32
    let BN_mod_add: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?, Pointer?) -> Int32
    let BN_mod_sub: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?, Pointer?) -> Int32
    let BN_mod_mul: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?, Pointer?) -> Int32
    let BN_mod_exp: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?, Pointer?) -> Int32
    let BN_add: @convention(c) (Pointer?, Pointer?, Pointer?) -> Int32
    let BN_sub: @convention(c) (Pointer?, Pointer?, Pointer?) -> Int32
    let BN_mul: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?) -> Int32
    let BN_exp: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?) -> Int32
    let BN_mod_inverse: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?) -> Pointer?
    let BN_mod_word: @convention(c) (Pointer?, UInt) -> UInt
    let BN_rshift1: @convention(c) (Pointer?, Pointer?) -> Int32
    let BIO_s_mem: @convention(c) () -> Pointer?
    let BIO_new: @convention(c) (Pointer?) -> Pointer?
    let BIO_write: @convention(c) (Pointer?, UnsafeRawPointer?, Int32) -> Int32
    let BIO_free: @convention(c) (Pointer?) -> Int32
    let PEM_read_bio_RSAPublicKey: @convention(c) (Pointer?, UnsafeMutablePointer<Pointer?>?, UnsafeRawPointer?, UnsafeMutableRawPointer?) -> Pointer?
    let RSA_get0_n: @convention(c) (Pointer?) -> Pointer?
    let RSA_get0_e: @convention(c) (Pointer?) -> Pointer?
    let RSA_free: @convention(c) (Pointer?) -> Void

    init?(path: String) {
        guard let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) else {
            return nil
        }
        func load<T>(_ name: String) -> T? {
            return dlsym(handle, name).map { unsafeBitCast($0, to: T.self) }
        }
        guard let BN_CTX_new: @convention(c) () -> Pointer? = load("BN_CTX_new"),
              let BN_CTX_free: @convention(c) (Pointer?) -> Void = load("BN_CTX_free"),
              let BN_new: @convention(c) () -> Pointer? = load("BN_new"),
              let BN_dup: @convention(c) (Pointer?) -> Pointer? = load("BN_dup"),
              let BN_clear_free: @convention(c) (Pointer?) -> Void = load("BN_clear_free"),
              let BN_set_flags: @convention(c) (Pointer?, Int32) -> Void = load("BN_set_flags"),
              let BN_set_word: @convention(c) (Pointer?, UInt) -> Int32 = load("BN_set_word"),
              let BN_hex2bn: @convention(c) (UnsafeMutablePointer<Pointer?>?, UnsafePointer<CChar>?) -> Int32 = load("BN_hex2bn"),
              let BN_bin2bn: @convention(c) (UnsafeRawPointer?, Int32, Pointer?) -> Pointer? = load("BN_bin2bn"),
              let BN_is_one: @convention(c) (Pointer?) -> Int32 = load("BN_is_one"),
              let BN_is_zero: @convention(c) (Pointer?) -> Int32 = load("BN_is_zero"),
              let BN_num_bits: @convention(c) (Pointer?) -> Int32 = load("BN_num_bits"),
              let BN_bn2bin: @convention(c) (Pointer?, UnsafeMutableRawPointer?) -> Int32 = load("BN_bn2bin"),
              let BN_is_prime_ex: @convention(c) (Pointer?, Int32, Pointer?, Pointer?) -> Int32 = load("BN_is_prime_ex"),
              let BN_cmp: @convention(c) (Pointer?, Pointer?) -> Int32 = load("BN_cmp"),
              let BN_mod_add: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?, Pointer?) -> Int32 = load("BN_mod_add"),
              let BN_mod_sub: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?, Pointer?) -> Int32 = load("BN_mod_sub"),
              let BN_mod_mul: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?, Pointer?) -> Int32 = load("BN_mod_mul"),
              let BN_mod_exp: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?, Pointer?) -> Int32 = load("BN_mod_exp"),
              let BN_add: @convention(c) (Pointer?, Pointer?, Pointer?) -> Int32 = load("BN_add"),
              let BN_sub: @convention(c) (Pointer?, Pointer?, Pointer?) -> Int32 = load("BN_sub"),
              let BN_mul: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?) -> Int32 = load("BN_mul"),
              let BN_exp: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?) -> Int32 = load("BN_exp"),
              let BN_mod_inverse: @convention(c) (Pointer?, Pointer?, Pointer?, Pointer?) -> Pointer? = load("BN_mod_inverse"),
              let BN_mod_word: @convention(c) (Pointer?, UInt) -> UInt = load("BN_mod_word"),
              let BN_rshift1: @convention(c) (Pointer?, Pointer?) -> Int32 = load("BN_rshift1"),
              let BIO_s_mem: @convention(c) () -> Pointer? = load("BIO_s_mem"),
              let BIO_new: @convention(c) (Pointer?) -> Pointer? = load("BIO_new"),
              let BIO_write: @convention(c) (Pointer?, UnsafeRawPointer?, Int32) -> Int32 = load("BIO_write"),
              let BIO_free: @convention(c) (Pointer?) -> Int32 = load("BIO_free"),
              let PEM_read_bio_RSAPublicKey: @convention(c) (Pointer?, UnsafeMutablePointer<Pointer?>?, UnsafeRawPointer?, UnsafeMutableRawPointer?) -> Pointer? = load("PEM_read_bio_RSAPublicKey"),
              let RSA_get0_n: @convention(c) (Pointer?) -> Pointer? = load("RSA_get0_n"),
              let RSA_get0_e: @convention(c) (Pointer?) -> Pointer? = load("RSA_get0_e"),
              let RSA_free: @convention(c) (Pointer?) -> Void = load("RSA_free") else {
            return nil
        }
        self.BN_CTX_new = BN_CTX_new
        self.BN_CTX_free = BN_CTX_free
        self.BN_new = BN_new
        self.BN_dup = BN_dup
        self.BN_clear_free = BN_clear_free
        self.BN_set_flags = BN_set_flags
        self.BN_set_word = BN_set_word
        self.BN_hex2bn = BN_hex2bn
        self.BN_bin2bn = BN_bin2bn
        self.BN_is_one = BN_is_one
        self.BN_is_zero = BN_is_zero
        self.BN_num_bits = BN_num_bits
        self.BN_bn2bin = BN_bn2bin
        self.BN_is_prime_ex = BN_is_prime_ex
        self.BN_cmp = BN_cmp
        self.BN_mod_add = BN_mod_add
        self.BN_mod_sub = BN_mod_sub
        self.BN_mod_mul = BN_mod_mul
        self.BN_mod_exp = BN_mod_exp
        self.BN_add = BN_add
        self.BN_sub = BN_sub
        self.BN_mul = BN_mul
        self.BN_exp = BN_exp
        self.BN_mod_inverse = BN_mod_inverse
        self.BN_mod_word = BN_mod_word
        self.BN_rshift1 = BN_rshift1
        self.BIO_s_mem = BIO_s_mem
        self.BIO_new = BIO_new
        self.BIO_write = BIO_write
        self.BIO_free = BIO_free
        self.PEM_read_bio_RSAPublicKey = PEM_read_bio_RSAPublicKey
        self.RSA_get0_n = RSA_get0_n
        self.RSA_get0_e = RSA_get0_e
        self.RSA_free = RSA_free
    }
}

fileprivate final class LibCryptoBignum: NSObject, MTBignum {
    let library: LibCrypto
    var value: OpaquePointer?

    init(library: LibCrypto, value: OpaquePointer?) {
        self.library = library
        self.value = value
    }

    deinit {
        self.library.BN_clear_free(self.value)
    }
}

fileprivate final class LibCryptoRsaPublicKey: NSObject, MTRsaPublicKey {
    let library: LibCrypto
    let rsa: OpaquePointer?

    init(library: LibCrypto, rsa: OpaquePointer?) {
        self.library = library
        self.rsa = rsa
    }

    deinit {
        if let rsa = self.rsa {
            self.library.RSA_free(rsa)
        }
    }
}

fileprivate final class LibCryptoBignumContext: NSObject, MTBignumContext {
    private let library: LibCrypto
    private let context: OpaquePointer?

    init(library: LibCrypto) {
        self.library = library
        self.context = library.BN_CTX_new()
    }

    deinit {
        self.library.BN_CTX_free(self.context)
    }

    private func value(_ bignum: MTBignum) -> OpaquePointer? {
        return (bignum as! LibCryptoBignum).value
    }

    func create() -> MTBignum {
        return LibCryptoBignum(library: self.library, value: self.library.BN_new())
    }

    func clone(_ other: MTBignum) -> MTBignum {
        return LibCryptoBignum(library: self.library, value: self.library.BN_dup(self.value(other)))
    }

    func setConstantTime(_ other: MTBignum) {
        self.library.BN_set_flags(self.value(other), 0x04)
    }

    func assignWord(to bignum: MTBignum, value: UInt) {
        _ = self.library.BN_set_word(self.value(bignum), value)
    }

    func assignHex(to bignum: MTBignum, value: String) {
        let target = bignum as! LibCryptoBignum
        var pointer = target.value
        _ = value.withCString { self.library.BN_hex2bn(&pointer, $0) }
        target.value = pointer
    }

    func assignBin(to bignum: MTBignum, value: Data) {
        _ = value.withUnsafeBytes { self.library.BN_bin2bn($0.baseAddress, Int32($0.count), self.value(bignum)) }
    }

    func assignOne(to bignum: MTBignum) {
        _ = self.library.BN_set_word(self.value(bignum), 1)
    }

    func assignZero(to bignum: MTBignum) {
        _ = self.library.BN_set_word(self.value(bignum), 0)
    }

    func isOne(_ bignum: MTBignum) -> Bool {
        return self.library.BN_is_one(self.value(bignum)) != 0
    }

    func isZero(_ bignum: MTBignum) -> Bool {
        return self.library.BN_is_zero(self.value(bignum)) != 0
    }

    func getBin(_ bignum: MTBignum) -> Data {
        var data = Data(count: Int((self.library.BN_num_bits(self.value(bignum)) + 7) / 8))
        _ = data.withUnsafeMutableBytes { self.library.BN_bn2bin(self.value(bignum), $0.baseAddress) }
        return data
    }

    func isPrime(_ bignum: MTBignum, numberOfChecks: Int32) -> Int32 {
        return self.library.BN_is_prime_ex(self.value(bignum), numberOfChecks, self.context, nil)
    }

    func compare(_ a: MTBignum, with b: MTBignum) -> Int32 {
        return self.library.BN_cmp(self.value(a), self.value(b))
    }

    func modAdd(into result: MTBignum, a: MTBignum, b: MTBignum, mod: MTBignum) -> Bool {
        return self.library.BN_mod_add(self.value(result), self.value(a), self.value(b), self.value(mod), self.context) != 0
    }

    func modSub(into result: MTBignum, a: MTBignum, b: MTBignum, mod: MTBignum) -> Bool {
        return self.library.BN_mod_sub(self.value(result), self.value(a), self.value(b), self.value(mod), self.context) != 0
    }

    func modMul(into result: MTBignum, a: MTBignum, b: MTBignum, mod: MTBignum) -> Bool {
        return self.library.BN_mod_mul(self.value(result), self.value(a), self.value(b), self.value(mod), self.context) != 0
    }

    func modExp(into result: MTBignum, a: MTBignum, b: MTBignum, mod: MTBignum) -> Bool {
        return self.library.BN_mod_exp(self.value(result), self.value(a), self.value(b), self.value(mod), self.context) != 0
    }

    func add(into result: MTBignum, a: MTBignum, b: MTBignum) -> Bool {
        return self.library.BN_add(self.value(result), self.value(a), self.value(b)) != 0
    }

    func sub(into result: MTBignum, a: MTBignum, b: MTBignum) -> Bool {
        return self.library.BN_sub(self.value(result), self.value(a), self.value(b)) != 0
    }

    func mul(into result: MTBignum, a: MTBignum, b: MTBignum) -> Bool {
        return self.library.BN_mul(self.value(result), self.value(a), self.value(b), self.context) != 0
    }

    func exp(into result: MTBignum, a: MTBignum, b: MTBignum) -> Bool {
        return self.library.BN_exp(self.value(result), self.value(a), self.value(b), self.context) != 0
    }

    func modInverse(into result: MTBignum, a: MTBignum, mod: MTBignum) -> Bool {
        return self.library.BN_mod_inverse(self.value(result), self.value(a), self.value(mod), self.context) != nil
    }

    func modWord(_ a: MTBignum, mod: UInt) -> UInt {
        return self.library.BN_mod_word(self.value(a), mod)
    }

    func rightShift1Bit(_ result: MTBignum, a: MTBignum) -> Bool {
        return self.library.BN_rshift1(self.value(result), self.value(a)) != 0
    }

    func rsaGetE(_ publicKey: MTRsaPublicKey) -> MTBignum {
        let key = publicKey as! LibCryptoRsaPublicKey
        return LibCryptoBignum(library: self.library, value: self.library.BN_dup(self.library.RSA_get0_e(key.rsa)))
    }

    func rsaGetN(_ publicKey: MTRsaPublicKey) -> MTBignum {
        let key = publicKey as! LibCryptoRsaPublicKey
        return LibCryptoBignum(library: self.library, value: self.library.BN_dup(self.library.RSA_get0_n(key.rsa)))
    }
}
