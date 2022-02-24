# frozen_string_literal: true

require 'spec_helper'
require 'base64'

RSpec.describe FixdUtils::Base32 do
  describe 'secure_generate' do
    it 'should generate a random string of the provided length' do
      token = FixdUtils::Base32.secure_generate(8)

      expect(token.length).to eq 8
      expect(token.chars).to all(satisfy { |c| FixdUtils::Base32::ALPHABET.include?(c) })
    end

    it 'should be stable' do
      allow(SecureRandom).to receive(:random_bytes).and_return(Base64.decode64('Hzz3sRo='))
      expect(FixdUtils::Base32.secure_generate(8)).to eq 'D68SSNJ4'
    end
  end
end
