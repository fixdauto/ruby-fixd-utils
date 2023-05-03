# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UriBuilder do
  describe 'build' do
    it 'parses with only a host' do
      uri = described_class.build(host: 'fixdapp.com')
      expect(uri.to_s).to eq 'http://fixdapp.com'
    end

    it 'allows port to be in the host property' do
      uri = described_class.build(host: 'localhost:5000', path: 'something/rotten')
      expect(uri.to_s).to eq 'http://localhost:5000/something/rotten'
    end

    it 'allows https schema and port in host' do
      uri = described_class.build(host: 'https://localhost:5000', path: 'something/rotten')
      expect(uri.to_s).to eq 'https://localhost:5000/something/rotten'
    end

    it 'allows hash input for query property' do
      uri = described_class.build(host: 'https://www.fixdapp.com:5432',
                                  path: 'something/rotten', query: { a: 'AA', b: 'BC!@F' })
      expect(uri.to_s).to eq 'https://www.fixdapp.com:5432/something/rotten?a=AA&b=BC%21%40F'
    end
  end
end
