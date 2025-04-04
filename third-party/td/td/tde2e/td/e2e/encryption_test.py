import os
from Crypto.Cipher import AES
from Crypto.Hash import SHA256, HMAC, SHA512
import binascii
import random

def generate_deterministic_padding(data_size, min_padding):
    # Calculate padding size to make total size multiple of 16
    padding_size = ((min_padding + 15 + data_size) & -16) - data_size
    padding = bytearray(padding_size)
    
    # Only set the first byte to padding size, leave rest as zeros
    padding[0] = padding_size
    
    return padding


def hmac_sha512(a, b):
    # Combine two secrets using HMAC-SHA512
    if isinstance(a, str):
        a = a.encode('utf-8')
    if isinstance(b, str):
        b = b.encode('utf-8')
    hmac = HMAC.new(a, b, SHA512)
    return hmac.digest()

def kdf(key, info):
    return hmac_sha512(key, info)

def encrypt_data_with_prefix(data, secret):
    # Ensure data is multiple of 16 bytes
    assert len(data) % 16 == 0
    
    # Generate encryption and HMAC secrets
    large_secret = kdf(secret, "tde2e_encrypt_data")
    encrypt_secret = large_secret[:32]
    hmac_secret = large_secret[32:64]

    # Generate message ID using HMAC
    large_msg_id = hmac_sha512(hmac_secret, data)
    msg_id = large_msg_id[:16]  # Use first 16 bytes as message ID
    
    # Create result buffer
    result = bytearray(len(data) + 16)
    result[0:16] = msg_id
    
    # Generate key and IV for encryption
    encryption_secret = hmac_sha512(encrypt_secret, msg_id)
    key = encryption_secret[:32]
    iv = encryption_secret[32:48]
    
    # Encrypt data
    cipher = AES.new(key, AES.MODE_CBC, iv)
    encrypted = cipher.encrypt(data)
    result[16:] = encrypted
    
    return bytes(result)

def encrypt_data_with_deterministic_padding(data, secret):
    # Generate deterministic padding
    padding = generate_deterministic_padding(len(data), 16)

    # Combine padding and data
    combined = bytearray(len(padding) + len(data))
    combined[0:len(padding)] = padding
    combined[len(padding):] = data

    # Encrypt the combined data
    return encrypt_data_with_prefix(combined, secret)

def encrypt_header(header, encrypted_message, secret):
    # Verify inputs
    assert len(header) == 32
    assert len(encrypted_message) >= 16
    
    # Get msg_id from the beginning of encrypted message
    msg_id = encrypted_message[0:16]

    encryption_key = kdf(secret, "tde2e_encrypt_header")[:32]
    
    # Generate encryption key and IV from secret and message ID
    encryption_secret = kdf(encryption_key, msg_id)
    key = encryption_secret[:32]
    iv = encryption_secret[32:48]
    
    # Encrypt header with AES-CBC
    cipher = AES.new(key, AES.MODE_CBC, iv)
    encrypted_header = cipher.encrypt(header)
    
    return encrypted_header

def decrypt_data(encrypted_data, secret):
    # Verify input size
    if len(encrypted_data) < 17:
        raise ValueError("Failed to decrypt: data is too small")
    if len(encrypted_data) % 16 != 0:
        raise ValueError("Failed to decrypt: data size is not divisible by 16")
    
    # Extract msg_id and encrypted part
    msg_id = encrypted_data[0:16]
    encrypted_part = encrypted_data[16:]
    
    # Generate encryption and HMAC secrets
    large_secret = kdf(secret, "tde2e_encrypt_data")
    hmac_secret = large_secret[32:64]
    encrypt_secret = large_secret[:32]
    
    # Generate key and IV for decryption
    encryption_secret = hmac_sha512(encrypt_secret, msg_id)
    key = encryption_secret[:32]
    iv = encryption_secret[32:48]
    
    # Decrypt with AES-CBC
    cipher = AES.new(key, AES.MODE_CBC, iv)
    decrypted_data = cipher.decrypt(encrypted_part)
    
    # Verify msg_id
    large_msg_id = hmac_sha512(hmac_secret, decrypted_data)
    expected_msg_id = large_msg_id[:16]
    if msg_id != expected_msg_id:
        raise ValueError("Failed to decrypt: msg_id mismatch")
    
    # Extract actual data by removing padding
    prefix_size = decrypted_data[0]
    if prefix_size > len(decrypted_data) or prefix_size < 16:
        raise ValueError("Failed to decrypt: invalid prefix size")
    
    return decrypted_data[prefix_size:]

def decrypt_header(encrypted_header, encrypted_message, secret):
    # Verify inputs
    if len(encrypted_header) != 32:
        raise ValueError("Failed to decrypt: invalid header size")
    if len(encrypted_message) < 16:
        raise ValueError("Failed to decrypt: invalid message size")
    
    # Get msg_id from the beginning of encrypted message
    msg_id = encrypted_message[0:16]
    encryption_key = kdf(secret, "tde2e_encrypt_header")[:32]
    
    # Generate encryption key and IV from secret and msg_id
    encryption_secret = kdf(encryption_key, msg_id)
    key = encryption_secret[:32]
    iv = encryption_secret[32:48]
    
    # Decrypt header with AES-CBC
    cipher = AES.new(key, AES.MODE_CBC, iv)
    decrypted_header = cipher.decrypt(encrypted_header)
    
    return decrypted_header

def generate_random_bytes(length):
    return bytes(random.getrandbits(8) for _ in range(length))

def generate_test_vectors():
    # Generate random secrets and headers for each test
    secret = generate_random_bytes(32)
    header = generate_random_bytes(32)
    
    # Test vectors with different data patterns
    test_vectors = [
        {
            "name": "empty_message",
            "secret": binascii.hexlify(secret).decode('ascii'),
            "data": "",
            "header": binascii.hexlify(header).decode('ascii')
        },
        {
            "name": "simple_message",
            "secret": binascii.hexlify(secret).decode('ascii'),
            "data": binascii.hexlify(b"Hello, World!").decode('ascii'),
            "header": binascii.hexlify(header).decode('ascii')
        },
        {
            "name": "long_message",
            "secret": binascii.hexlify(secret).decode('ascii'),
            "data": binascii.hexlify(b"x" * 200).decode('ascii'),
            "header": binascii.hexlify(header).decode('ascii')
        },
        {
            "name": "random_message",
            "secret": binascii.hexlify(secret).decode('ascii'),
            "data": binascii.hexlify(generate_random_bytes(64)).decode('ascii'),
            "header": binascii.hexlify(header).decode('ascii')
        },
        {
            "name": "very_long_message",
            "secret": binascii.hexlify(secret).decode('ascii'),
            "data": binascii.hexlify(generate_random_bytes(300)).decode('ascii'),
            "header": binascii.hexlify(header).decode('ascii')
        },
        {
            "name": "message_with_special_chars",
            "secret": binascii.hexlify(secret).decode('ascii'),
            "data": binascii.hexlify(bytes([i for i in range(33, 64)])).decode('ascii'),
            "header": binascii.hexlify(header).decode('ascii')
        },
        {
            "name": "message_with_unicode",
            "secret": binascii.hexlify(secret).decode('ascii'),
            "data": binascii.hexlify("Hello, 世界!".encode('utf-8')).decode('ascii'),
            "header": binascii.hexlify(header).decode('ascii')
        },
    ]
    
    # Generate encrypted data and headers for each test vector
    for vec in test_vectors:
        secret = binascii.unhexlify(vec["secret"])
        data = binascii.unhexlify(vec["data"])
        header = binascii.unhexlify(vec["header"])
        
        encrypted = encrypt_data_with_deterministic_padding(data, secret)
        encrypted_header = encrypt_header(header, encrypted, secret)
        
        # Test decryption
        decrypted = decrypt_data(encrypted, secret)
        if decrypted != data:
            raise ValueError(f"Decryption failed for test vector: {vec['name']}")
            
        # Test header decryption
        decrypted_header = decrypt_header(encrypted_header, encrypted, secret)
        if decrypted_header != header:
            raise ValueError(f"Header decryption failed for test vector: {vec['name']}")
        
        vec["encrypted"] = binascii.hexlify(encrypted).decode('ascii')
        vec["encrypted_header"] = binascii.hexlify(encrypted_header).decode('ascii')
    
    return test_vectors

def print_cpp_header(test_vectors):
    print("#pragma once")
    print("\n#include <string>")
    print("#include <vector>")
    print("\nnamespace tde2e_core {")
    print("\nstruct TestVector {")
    print("    std::string name;")
    print("    std::string secret;")
    print("    std::string data;")
    print("    std::string header;")
    print("    std::string encrypted;")
    print("    std::string encrypted_header;")
    print("};")
    print("\ninline std::vector<TestVector> get_test_vectors() {")
    print("    return {")
    
    for vec in test_vectors:
        print("        {")
        print(f'            "{vec["name"]}",')
        print(f'            "{vec["secret"]}",')
        print(f'            "{vec["data"]}",')
        print(f'            "{vec["header"]}",')
        print(f'            "{vec["encrypted"]}",')
        print(f'            "{vec["encrypted_header"]}"')
        print("        },")
    
    print("    };")
    print("}")
    print("\n} // namespace tde2e_core")

if __name__ == "__main__":
    test_vectors = generate_test_vectors()
    
    # Get the directory of the current script
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # Go up two levels to reach the tde2e directory
    tde2e_dir = os.path.dirname(os.path.dirname(script_dir))
    # Create the test directory if it doesn't exist
    test_dir = os.path.join(tde2e_dir, "test")
    os.makedirs(test_dir, exist_ok=True)
    
    # Write the header file
    header_path = os.path.join(test_dir, "EncryptionTestVectors.h")
    with open(header_path, "w") as f:
        # Redirect print output to the file
        import sys
        old_stdout = sys.stdout
        sys.stdout = f
        print_cpp_header(test_vectors)
        sys.stdout = old_stdout 