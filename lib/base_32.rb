# frozen_string_literal: true

require 'securerandom'

# A user-frendly encoding of bytes for tokens, coupons, and such.
# Strings generated with this method are all uppercase capital letters and numbers,
# with hard-to-differentiate characters such as O vs 0 removed.
module Base32
  ALPHABET = 'ABCDEFGHJKLMNPRSTUVWXYZ123456789'

  def self.secure_generate(length)
    byte_count = (Math.log2(32**length) / 8.0).ceil
    bytes = SecureRandom.random_bytes(byte_count)
    encode_bits(bytes.unpack1('B*').chars.take(5 * length).join)
  end

  def self.encode_bits(bits)
    unless (bits.length % 5).zero?
      raise StandardError, 'Number of bits must be divisible by 5, overflow is not supported'
    end

    bits.scan(/.{5}/).map { |b| ALPHABET[b.to_i(2)] }.join
  end

  def self.decode_bits(string)
    raise StandardError, "Invalid Base32 string: #{string}" unless valid?(string)

    string.chars.map { |c| format('%05d', Base32::ALPHABET.chars.index(c).to_s(2)) }.join
  end

  def self.valid?(string)
    string.present? && string.chars.all? { |c| ALPHABET.include?(c) }
  end
end
