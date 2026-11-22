import base64
import hashlib


# FIPS-197 AES S-box and inverse S-box.
_SBOX = bytes.fromhex(
    "637c777bf26b6fc53001672bfed7ab76"
    "ca82c97dfa5947f0add4a2af9ca472c0"
    "b7fd9326363ff7cc34a5e5f171d83115"
    "04c723c31896059a071280e2eb27b275"
    "09832c1a1b6e5aa0523bd6b329e32f84"
    "53d100ed20fcb15b6acbbe394a4c58cf"
    "d0efaafb434d338545f9027f503c9fa8"
    "51a3408f929d38f5bcb6da2110fff3d2"
    "cd0c13ec5f974417c4a77e3d645d1973"
    "60814fdc222a908846eeb814de5e0bdb"
    "e0323a0a4906245cc2d3ac629195e479"
    "e7c8376d8dd54ea96c56f4ea657aae08"
    "ba78252e1ca6b4c6e8dd741f4bbd8b8a"
    "703eb5664803f60e613557b986c11d9e"
    "e1f8981169d98e949b1e87e9ce5528df"
    "8ca1890dbfe6426841992d0fb054bb16"
)

_INV_SBOX = bytes.fromhex(
    "52096ad53036a538bf40a39e81f3d7fb"
    "7ce339829b2fff87348e4344c4dee9cb"
    "547b9432a6c2233dee4c950b42fac34e"
    "082ea16628d924b2765ba2496d8bd125"
    "72f8f66486689816d4a45ccc5d65b692"
    "6c704850fdedb9da5e154657a78d9d84"
    "90d8ab008cbcd30af7e45805b8b34506"
    "d02c1e8fca3f0f02c1afbd0301138a6b"
    "3a9111414f67dcea97f2cfcef0b4e673"
    "96ac7422e7ad3585e2f937e81c75df6e"
    "47f11a711d29c5896fb7620eaa18be1b"
    "fc563e4bc6d279209adbc0fe78cd5af4"
    "1fdda8338807c731b11210592780ec5f"
    "60517fa919b54a0d2de57a9f93c99cef"
    "a0e03b4dae2af5b0c8ebbb3c83539961"
    "172b047eba77d626e169146355210c7d"
)

_RCON = bytes.fromhex("01020408102040801b36")


def _xtime(a):
    return (((a << 1) ^ 0x1b) & 0xff) if (a & 0x80) else (a << 1)


def _gf_mul(a, b):
    r = 0
    for _ in range(8):
        if b & 1:
            r ^= a
        b >>= 1
        a = _xtime(a)
    return r


def _key_expansion_256(key):
    # AES-256: Nk=8, Nr=14, total 4 * (Nr + 1) = 60 words = 240 bytes.
    if len(key) != 32:
        raise ValueError("AES-256 key must be 32 bytes")
    w = bytearray(240)
    w[:32] = key
    i = 32
    while i < 240:
        t = bytearray(w[i - 4:i])
        if i % 32 == 0:
            t = bytearray([t[1], t[2], t[3], t[0]])
            for j in range(4):
                t[j] = _SBOX[t[j]]
            t[0] ^= _RCON[i // 32 - 1]
        elif i % 32 == 16:
            for j in range(4):
                t[j] = _SBOX[t[j]]
        for j in range(4):
            w[i + j] = w[i - 32 + j] ^ t[j]
        i += 4
    return [bytes(w[r * 16:(r + 1) * 16]) for r in range(15)]


def _add_round_key(state, rk):
    return bytes(s ^ k for s, k in zip(state, rk))


def _sub_bytes(state):
    return bytes(_SBOX[b] for b in state)


def _inv_sub_bytes(state):
    return bytes(_INV_SBOX[b] for b in state)


# Column-major state: state[r + 4 * c], r = 0..3 (row), c = 0..3 (column).
def _shift_rows(state):
    s = bytearray(state)
    s[1], s[5], s[9], s[13] = s[5], s[9], s[13], s[1]
    s[2], s[6], s[10], s[14] = s[10], s[14], s[2], s[6]
    s[3], s[7], s[11], s[15] = s[15], s[3], s[7], s[11]
    return bytes(s)


def _inv_shift_rows(state):
    s = bytearray(state)
    s[1], s[5], s[9], s[13] = s[13], s[1], s[5], s[9]
    s[2], s[6], s[10], s[14] = s[10], s[14], s[2], s[6]
    s[3], s[7], s[11], s[15] = s[7], s[11], s[15], s[3]
    return bytes(s)


def _mix_columns(state):
    s = bytearray(16)
    for c in range(4):
        a0, a1, a2, a3 = state[4 * c], state[4 * c + 1], state[4 * c + 2], state[4 * c + 3]
        s[4 * c]     = _xtime(a0) ^ (_xtime(a1) ^ a1) ^ a2 ^ a3
        s[4 * c + 1] = a0 ^ _xtime(a1) ^ (_xtime(a2) ^ a2) ^ a3
        s[4 * c + 2] = a0 ^ a1 ^ _xtime(a2) ^ (_xtime(a3) ^ a3)
        s[4 * c + 3] = (_xtime(a0) ^ a0) ^ a1 ^ a2 ^ _xtime(a3)
    return bytes(s)


def _inv_mix_columns(state):
    s = bytearray(16)
    for c in range(4):
        a0, a1, a2, a3 = state[4 * c], state[4 * c + 1], state[4 * c + 2], state[4 * c + 3]
        s[4 * c]     = _gf_mul(a0, 0x0e) ^ _gf_mul(a1, 0x0b) ^ _gf_mul(a2, 0x0d) ^ _gf_mul(a3, 0x09)
        s[4 * c + 1] = _gf_mul(a0, 0x09) ^ _gf_mul(a1, 0x0e) ^ _gf_mul(a2, 0x0b) ^ _gf_mul(a3, 0x0d)
        s[4 * c + 2] = _gf_mul(a0, 0x0d) ^ _gf_mul(a1, 0x09) ^ _gf_mul(a2, 0x0e) ^ _gf_mul(a3, 0x0b)
        s[4 * c + 3] = _gf_mul(a0, 0x0b) ^ _gf_mul(a1, 0x0d) ^ _gf_mul(a2, 0x09) ^ _gf_mul(a3, 0x0e)
    return bytes(s)


def _aes_encrypt_block(block, round_keys):
    state = _add_round_key(block, round_keys[0])
    for r in range(1, 14):
        state = _sub_bytes(state)
        state = _shift_rows(state)
        state = _mix_columns(state)
        state = _add_round_key(state, round_keys[r])
    state = _sub_bytes(state)
    state = _shift_rows(state)
    state = _add_round_key(state, round_keys[14])
    return state


def _aes_decrypt_block(block, round_keys):
    state = _add_round_key(block, round_keys[14])
    for r in range(13, 0, -1):
        state = _inv_shift_rows(state)
        state = _inv_sub_bytes(state)
        state = _add_round_key(state, round_keys[r])
        state = _inv_mix_columns(state)
    state = _inv_shift_rows(state)
    state = _inv_sub_bytes(state)
    state = _add_round_key(state, round_keys[0])
    return state


def _evp_bytes_to_key(password, salt, hash_name, key_len=32, iv_len=16):
    # OpenSSL EVP_BytesToKey with count=1, matching Ruby's
    # Cipher#pkcs5_keyivgen(password, salt, 1, hash).
    if isinstance(password, str):
        password = password.encode('utf-8')
    required = key_len + iv_len
    material = b""
    prev = b""
    while len(material) < required:
        h = hashlib.new(hash_name)
        h.update(prev + password + salt)
        prev = h.digest()
        material += prev
    return material[:key_len], material[key_len:key_len + iv_len]


def _aes_cbc_decrypt(ciphertext, key, iv):
    if len(ciphertext) == 0 or len(ciphertext) % 16 != 0:
        raise ValueError("V1 ciphertext length must be a non-zero multiple of 16")
    round_keys = _key_expansion_256(key)
    out = bytearray()
    prev = iv
    for i in range(0, len(ciphertext), 16):
        block = ciphertext[i:i + 16]
        decrypted = _aes_decrypt_block(block, round_keys)
        out.extend(bytes(d ^ p for d, p in zip(decrypted, prev)))
        prev = block
    pad = out[-1]
    if pad < 1 or pad > 16 or not all(b == pad for b in out[-pad:]):
        raise ValueError("V1 PKCS#7 padding check failed")
    return bytes(out[:-pad])


def _ghash(h_bytes, data):
    # GHASH over GF(2^128) with reduction polynomial x^128 + x^7 + x^2 + x + 1,
    # using GCM's bit-reversed convention (top-bit-first when encoded as bytes).
    h = int.from_bytes(h_bytes, 'big')
    y = 0
    reduction = 0xe1 << 120
    for i in range(0, len(data), 16):
        block = data[i:i + 16].ljust(16, b"\x00")
        y ^= int.from_bytes(block, 'big')
        z = 0
        v = y
        for bit in range(127, -1, -1):
            if (h >> bit) & 1:
                z ^= v
            if v & 1:
                v = (v >> 1) ^ reduction
            else:
                v >>= 1
        y = z
    return y.to_bytes(16, 'big')


def _aes_gcm_decrypt(ciphertext, key, iv, aad, auth_tag):
    if len(iv) != 12:
        raise ValueError("V2 requires a 96-bit IV")
    round_keys = _key_expansion_256(key)
    H = _aes_encrypt_block(b"\x00" * 16, round_keys)
    j0 = iv + b"\x00\x00\x00\x01"

    plaintext = bytearray()
    j0_int = int.from_bytes(j0, 'big')
    mask32 = (1 << 32) - 1
    counter_high = j0_int & ~mask32
    counter_low = j0_int & mask32
    n_blocks = (len(ciphertext) + 15) // 16
    for i in range(n_blocks):
        counter_low = (counter_low + 1) & mask32
        ctr_bytes = (counter_high | counter_low).to_bytes(16, 'big')
        keystream = _aes_encrypt_block(ctr_bytes, round_keys)
        block = ciphertext[i * 16:(i + 1) * 16]
        plaintext.extend(bytes(c ^ k for c, k in zip(block, keystream[:len(block)])))

    aad_pad = b"\x00" * ((16 - len(aad) % 16) % 16)
    ct_pad = b"\x00" * ((16 - len(ciphertext) % 16) % 16)
    length_block = (len(aad) * 8).to_bytes(8, 'big') + (len(ciphertext) * 8).to_bytes(8, 'big')
    s = _ghash(H, aad + aad_pad + ciphertext + ct_pad + length_block)
    e_j0 = _aes_encrypt_block(j0, round_keys)
    computed_tag = bytes(a ^ b for a, b in zip(s, e_j0))
    if computed_tag != auth_tag:
        raise ValueError("V2 GCM auth tag mismatch")
    return bytes(plaintext)


_V1_PREFIX = b"Salted__"
_V2_PREFIX = b"match_encrypted_v2__"


def _decrypt_stored(stored_data, password):
    if stored_data.startswith(_V2_PREFIX):
        salt = stored_data[20:28]
        auth_tag = stored_data[28:44]
        ciphertext = stored_data[44:]
        material = hashlib.pbkdf2_hmac(
            'sha256',
            password.encode('utf-8'),
            salt,
            10_000,
            dklen=32 + 12 + 24,
        )
        key = material[0:32]
        iv = material[32:44]
        aad = material[44:68]
        return _aes_gcm_decrypt(ciphertext, key, iv, aad, auth_tag)
    if stored_data.startswith(_V1_PREFIX):
        salt = stored_data[8:16]
        ciphertext = stored_data[16:]
        try:
            key, iv = _evp_bytes_to_key(password, salt, 'md5', 32, 16)
            return _aes_cbc_decrypt(ciphertext, key, iv)
        except ValueError:
            key, iv = _evp_bytes_to_key(password, salt, 'sha256', 32, 16)
            return _aes_cbc_decrypt(ciphertext, key, iv)
    raise ValueError("Unrecognized fastlane match payload (missing V1 'Salted__' or V2 'match_encrypted_v2__' prefix)")


def decrypt_match_data(source_path: str, destination_path: str, password: str):
    with open(source_path, 'rb') as f:
        raw = f.read()
    stored_data = base64.b64decode(raw)
    decrypted = _decrypt_stored(stored_data, password)
    with open(destination_path, 'wb') as f:
        f.write(decrypted)


if __name__ == '__main__':
    import sys
    if len(sys.argv) != 4:
        print('Usage: DecryptMatch.py <password> <source_path> <destination_path>')
        sys.exit(1)
    decrypt_match_data(source_path=sys.argv[2], destination_path=sys.argv[3], password=sys.argv[1])
