require 'net/http'
require 'uri'

module KnowledgeArchive
  class Fetcher
    ALLOWED_HOSTS = %w[www.gracelife.com.tw gracelife.com.tw].freeze

    def get(url, limit: 5)
      raise 'too many redirects' if limit.zero?
      uri = URI(url)
      raise "blocked host: #{uri.host}" unless ALLOWED_HOSTS.include?(uri.host)
      response = Net::HTTP.get_response(uri)
      return get(URI.join(url, response['location']).to_s, limit: limit - 1) if response.is_a?(Net::HTTPRedirection)
      raise "HTTP #{response.code}: #{url}" unless response.is_a?(Net::HTTPSuccess)
      response.body.force_encoding('UTF-8')
    end

    def download(url)
      get(url).b
    end
  end
end
