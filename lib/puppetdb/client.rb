require 'httparty'
require 'logger'

module PuppetDB
  class APIError < Exception
    attr_reader :code, :response
    def initialize(response)
      @response = response
    end
  end

  class FixSSLConnectionAdapter < HTTParty::ConnectionAdapter
    def attach_ssl_certificates(http, options)
      http.cert    = OpenSSL::X509::Certificate.new(File.read(options[:pem]['cert']))
      http.key     = OpenSSL::PKey::RSA.new(File.read(options[:pem]['key']))
      http.ca_file = options[:pem]['ca_file']
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
  end

  class Client
    include HTTParty
    attr_reader :use_ssl
    attr_writer :logger

    def hash_get(hash, key)
      untouched = hash[key]
      return untouched if untouched

      sym = hash[key.to_sym()]
      return sym if sym

      str = hash[key.to_s()]
      return str if str

      nil
    end

    def hash_includes?(hash, *sought_keys)
      sought_keys.each {|x| return false unless hash.include?(x)}
      true
    end

    def debug(msg)
      if @logger
        @logger.debug(msg)
      end
    end

    def initialize(settings, version=3)
      @version = version

      server = hash_get(settings, 'server')
      pem    = hash_get(settings, 'pem')
      @puppetdb_majversion = hash_get(settings, 'puppetdb_majversion')
      if @puppetdb_majversion.nil? || @puppetdb_majversion.empty?
        @legacy_url = false
      elsif @puppetdb_majversion == '2'
        @legacy_url = true
      end

      scheme = URI.parse(server).scheme

      unless ['http', 'https'].include? scheme
        error_msg = "Configuration error: :server must specify a protocol of either http or https"
        raise error_msg
      end

      @use_ssl = scheme == 'https'
      if @use_ssl
        unless pem && hash_includes?(pem, 'key', 'cert', 'ca_file')
          error_msg = 'Configuration error: https:// specified but pem is missing or incomplete. It requires cert, key, and ca_file.'
          raise error_msg
        end

        self.class.default_options = {:pem => pem}
        self.class.connection_adapter(FixSSLConnectionAdapter)
      end

      self.class.base_uri(server)
    end

    def raise_if_error(response)
      if response.code.to_s() =~ /^[4|5]/
        raise response
      end
    end

    def request(endpoint, query, opts={})
      query = PuppetDB::Query.maybe_promote(query)
      json_query = query.build()
      if @legacy_url
        path = '/v' + @version.to_s() + '/'  + endpoint
      else
        path = '/pdb/query/v' + @version.to_s() +'/' + endpoint
      end

      filtered_opts = {'query' => json_query}
      opts.each do |k,v|
        if k == :counts_filter
          filtered_opts['counts-filter'] = JSON.dump(v)
        else
          if @puppetdb_majversion == "2"
            filtered_opts[k.to_s.sub("_", "-")] = v
          else
            filtered_opts[k.to_s.sub("-", "_")] = v
          end
        end
      end

      debug("#{path} #{json_query} #{opts}")
      ret = self.class.get(path, :query => filtered_opts)
      raise_if_error(ret)

      total = ret.headers['X-Records']
      if total.nil?
        total = ret.parsed_response.length
      end

      Response.new(ret.parsed_response, total)
    end

  end
end
