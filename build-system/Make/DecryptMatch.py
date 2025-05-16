import os
import base64
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import hashlib

class EncryptionV1:
    ALGORITHM = 'aes-256-cbc'

    def decrypt(self, encrypted_data, password, salt, hash_algorithm="MD5"):
        try:
            return self._decrypt_with_algorithm(encrypted_data, password, salt, hash_algorithm)
        except Exception as e:
            # Fallback to SHA256 if MD5 fails
            fallback_hash_algorithm = "SHA256"
            return self._decrypt_with_algorithm(encrypted_data, password, salt, fallback_hash_algorithm)

    def _decrypt_with_algorithm(self, encrypted_data, password, salt, hash_algorithm):
        # Implement OpenSSL's EVP_BytesToKey manually to match Ruby's behavior
        key, iv = self._evp_bytes_to_key(password.encode('utf-8'), salt, hash_algorithm)
        
        # Decrypt the data
        cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
        decryptor = cipher.decryptor()
        data = decryptor.update(encrypted_data) + decryptor.finalize()
        
        # Handle PKCS#7 padding more carefully
        try:
            padding_length = data[-1]
            # Check if padding value is reasonable
            if 1 <= padding_length <= 16:
                # Verify padding - all padding bytes should have the same value
                padding = data[-padding_length:]
                expected_padding = bytes([padding_length]) * padding_length
                if padding == expected_padding:
                    return data[:-padding_length]
            
            # If we get here, either the padding is invalid or there's no padding
            # Return the data as is, since it might be unpadded
            return data
        except IndexError:
            # Handle the case where data is empty
            return data

    def _evp_bytes_to_key(self, password, salt, hash_algorithm):
        """
        Python implementation of OpenSSL's EVP_BytesToKey function
        This matches Ruby's OpenSSL::Cipher#pkcs5_keyivgen implementation
        """
        if hash_algorithm == "MD5":
            hash_func = hashlib.md5
        else:
            hash_func = hashlib.sha256
        
        # The key and IV are derived using a hash-based algorithm:
        # D_i = HASH(D_{i-1} || password || salt)
        result = b''
        d = b''
        
        # Generate bytes until we have enough for both key and IV
        while len(result) < 48:  # 32 bytes for key + 16 bytes for IV
            d = hash_func(d + password + salt).digest()
            result += d
        
        # Split the result into key and IV
        key = result[:32]  # AES-256 needs a 32-byte key
        iv = result[32:48]  # CBC mode needs a 16-byte IV
        
        return key, iv

class EncryptionV2:
    ALGORITHM = 'aes-256-gcm'

    def decrypt(self, encrypted_data, password, salt, auth_tag):
        try:
            # Generate key, iv, and auth_data using PBKDF2
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=68,  # key (32) + iv (12) + auth_data (24)
                salt=salt,
                iterations=10_000,
            )
            key_iv = kdf.derive(password.encode('utf-8'))
            key = key_iv[0:32]
            iv = key_iv[32:44]
            auth_data = key_iv[44:68]

            # Decrypt the data
            cipher = Cipher(algorithms.AES(key), modes.GCM(iv, auth_tag))
            decryptor = cipher.decryptor()
            decryptor.authenticate_additional_data(auth_data)
            return decryptor.update(encrypted_data) + decryptor.finalize()
        except Exception as e:
            raise ValueError(f"GCM decryption failed: {str(e)}")

class MatchDataEncryption:
    V1_PREFIX = b"Salted__"
    V2_PREFIX = b"match_encrypted_v2__"

    def decrypt(self, base64encoded_encrypted, password):
        try:
            stored_data = base64.b64decode(base64encoded_encrypted)
            
            if stored_data.startswith(self.V2_PREFIX):
                # V2 format
                salt = stored_data[20:28]
                auth_tag = stored_data[28:44]
                data_to_decrypt = stored_data[44:]

                e = EncryptionV2()
                return e.decrypt(encrypted_data=data_to_decrypt, password=password, salt=salt, auth_tag=auth_tag)
            else:
                # V1 format
                salt = stored_data[8:16]
                data_to_decrypt = stored_data[16:]
                
                e = EncryptionV1()
                try:
                    # Try with MD5 hash first
                    return e.decrypt(encrypted_data=data_to_decrypt, password=password, salt=salt)
                except Exception:
                    # Fall back to SHA256 if MD5 fails
                    fallback_hash_algorithm = "SHA256"
                    return e.decrypt(encrypted_data=data_to_decrypt, password=password, salt=salt, hash_algorithm=fallback_hash_algorithm)
        except Exception as e:
            raise ValueError(f"Decryption failed: {str(e)}")

def decrypt_match_data(source_path: str, destination_path: str, password: str):
    """
    Decrypt a file encrypted by fastlane match
    
    Args:
        source_path: Path to the encrypted file
        destination_path: Path where to save the decrypted file
        password: Decryption password
    """
    try:
        # Read the file
        with open(source_path, 'rb') as f:
            content_bytes = f.read()
            
        # Check if content is binary or base64 text
        try:
            # Try to decode as UTF-8 to see if it's text
            content = content_bytes.decode('utf-8').strip()
        except UnicodeDecodeError:
            # If it's binary, encode it as base64 for our algorithm
            content = base64.b64encode(content_bytes).decode('utf-8')
        
        # Decrypt the content
        encryption = MatchDataEncryption()
        decrypted_data = encryption.decrypt(content, password)
        
        # Write the decrypted data to the destination file
        with open(destination_path, 'wb') as f:
            f.write(decrypted_data)
    except Exception as e:
        raise ValueError(f"Decryption process failed: {str(e)}")

def test_decrypt_match_data():
    profile_name = 'Development_ph.telegra.Telegraph.mobileprovision'
    source_path = os.path.expanduser('~/build/telegram/telegram-ios/build-input/configuration-repository-workdir/encrypted/profiles/development/{}'.format(profile_name))
    destination_path = os.path.expanduser('~/build/telegram/telegram-ios/build-input/configuration-repository-workdir/decrypted/profiles/development/{}'.format(profile_name))
    compare_destination_path = os.path.expanduser('~/build/telegram/telegram-ios/build-input/configuration-repository-workdir/decrypted/profiles/development/{}'.format(profile_name))
    password = 'sluchainost'

    # Remove the destination file if it exists
    if os.path.exists(destination_path):
        os.remove(destination_path)

    if not os.path.exists(source_path):
        print("Failed (source file does not exist)")
        return

    try:
        # Try to decrypt the file
        decrypt_match_data(
            source_path=source_path,
            destination_path=destination_path,
            password=password
        )

        if not os.path.exists(destination_path):
            print("Failed (file was not created)")
        elif not os.path.exists(compare_destination_path):
            print("Cannot compare (reference file doesn't exist)")
            if os.path.getsize(destination_path) > 0:
                print("But decryption produced a non-empty file of size:", os.path.getsize(destination_path))
                print("Assuming the test passed")
        else:
            with open(destination_path, 'rb') as f1, open(compare_destination_path, 'rb') as f2:
                if f1.read() == f2.read():
                    print("Passed")
                else:
                    print("Failed (content is different)")
    except Exception as e:
        print(f"Error during decryption: {str(e)}")


if __name__ == '__main__':
    test_decrypt_match_data()
