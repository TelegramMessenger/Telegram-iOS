require 'base64'
require 'openssl'
require 'securerandom'

class EncryptionV1
  ALGORITHM = 'aes-256-cbc'

  def decrypt(encrypted_data:, password:, salt:, hash_algorithm: "MD5")
    cipher = ::OpenSSL::Cipher.new(ALGORITHM)
    cipher.decrypt

    keyivgen(cipher, password, salt, hash_algorithm)

    data = cipher.update(encrypted_data)
    data << cipher.final
  end

  private

  def keyivgen(cipher, password, salt, hash_algorithm)
    cipher.pkcs5_keyivgen(password, salt, 1, hash_algorithm)
  end
end

# The newer encryption mechanism, which features a more secure key and IV generation.
#
# The IV is randomly generated and provided unencrypted.
# The salt should be randomly generated and provided unencrypted (like in the current implementation).
# The key is generated with OpenSSL::KDF::pbkdf2_hmac with properly chosen parameters.
#
# Short explanation about salt and IV: https://stackoverflow.com/a/1950674/6324550
class EncryptionV2
  ALGORITHM = 'aes-256-gcm'

  def decrypt(encrypted_data:, password:, salt:, auth_tag:)
    cipher = ::OpenSSL::Cipher.new(ALGORITHM)
    cipher.decrypt

    keyivgen(cipher, password, salt)

    cipher.auth_tag = auth_tag

    data = cipher.update(encrypted_data)
    data << cipher.final
  end

  private

  def keyivgen(cipher, password, salt)
    keyIv = ::OpenSSL::KDF.pbkdf2_hmac(password, salt: salt, iterations: 10_000, length: 32 + 12 + 24, hash: "sha256")
    key = keyIv[0..31]
    iv = keyIv[32..43]
    auth_data = keyIv[44..-1]

    puts "key: #{key.inspect}"
    puts "iv: #{iv.inspect}"
    puts "auth_data: #{auth_data.inspect}"

    cipher.key = key
    cipher.iv = iv
    cipher.auth_data = auth_data
  end
end

class MatchDataEncryption
  V1_PREFIX = "Salted__"
  V2_PREFIX = "match_encrypted_v2__"

  def decrypt(base64encoded_encrypted:, password:)
    stored_data = Base64.decode64(base64encoded_encrypted)
    if stored_data.start_with?(V2_PREFIX)
      salt = stored_data[20..27]
      auth_tag = stored_data[28..43]
      data_to_decrypt = stored_data[44..-1]

      e = EncryptionV2.new
      e.decrypt(encrypted_data: data_to_decrypt, password: password, salt: salt, auth_tag: auth_tag)
    else
      salt = stored_data[8..15]
      data_to_decrypt = stored_data[16..-1]
      e = EncryptionV1.new
      begin
        # Note that we are not guaranteed to catch the decryption errors here if the password or the hash is wrong
        # as there's no integrity checks.
        # see https://github.com/fastlane/fastlane/issues/21663
        e.decrypt(encrypted_data: data_to_decrypt, password: password, salt: salt)
        # With the wrong hash_algorithm, there's here 0.4% chance that the decryption failure will go undetected
      rescue => _ex
        # With a wrong password, there's a 0.4% chance it will decrypt garbage and not fail
        fallback_hash_algorithm = "SHA256"
        e.decrypt(encrypted_data: data_to_decrypt, password: password, salt: salt, hash_algorithm: fallback_hash_algorithm)
      end
    end
  end
end


class MatchFileEncryption
  def decrypt(file_path:, password:, output_path: nil)
    output_path = file_path unless output_path
    content = File.read(file_path)
    e = MatchDataEncryption.new
    decrypted_data = e.decrypt(base64encoded_encrypted: content, password: password)
    File.binwrite(output_path, decrypted_data)
  end
end


if ARGV.length != 3
  print 'Invalid command line'
else
  dec = MatchFileEncryption.new
  dec.decrypt(file_path: ARGV[1], password: ARGV[0], output_path: ARGV[2])
end
