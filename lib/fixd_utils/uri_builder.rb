# frozen_string_literal: true

# A utility class for creating a url from an options hash. Why this isn't built into rails idk
module FixdUtils
  class UriBuilder
    def self.build(opts)
      host = opts[:host]
      host = "http://#{host}" unless host.start_with?('http')
      base = URI.parse(host)
      build_opts = {}
      build_opts[:host] = base.host
      build_opts[:port] = base.port
      build_opts[:path] = opts[:path]
      build_opts[:path] = "/#{build_opts[:path]}" if build_opts[:path] && !build_opts[:path].start_with?('/')

      case opts[:query]
      when String
        build_opts[:query] = opts[:query]
      when Hash
        build_opts[:query] = URI.encode_www_form(opts[:query])
      end

      if base.scheme == 'https'
        URI::HTTPS.build(build_opts)
      else
        URI::HTTP.build(build_opts)
      end
    end
  end
end
