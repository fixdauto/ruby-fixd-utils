# frozen_string_literal: true

require "spec_helper"
require "base64"

RSpec.describe Base32 do
  describe "secure_generate" do
    let(:token) { described_class.secure_generate(8) }

    it "generates a random string of the provided length" do
      expect(token.length).to eq 8
    end

    it "generates a token from the alphabet" do
      expect(token.chars).to all(satisfy { |c| Base32::ALPHABET.include?(c) })
    end

    it "is stable" do
      allow(SecureRandom).to receive(:random_bytes).and_return(Base64.decode64("Hzz3sRo="))
      expect(described_class.secure_generate(8)).to eq "D68SSNJ4"
    end
  end
end
