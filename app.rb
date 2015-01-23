require 'rest_client'
require "open-uri"
require "yajl"
require "uri"
require 'fileutils'

module OpenURI
  class <<self
    alias_method :open_uri_original, :open_uri
    alias_method :redirectable_cautious?, :redirectable?

    def redirectable_baller? uri1, uri2
      valid = /\A(?:https?|ftp)\z/i
      valid =~ uri1.scheme.downcase && valid =~ uri2.scheme
    end
  end

  # The original open_uri takes *args but then doesn't do anything with them.
  # Assume we can only handle a hash.
  def self.open_uri name, options = {}
    value = options.delete :allow_unsafe_redirects
    if value
      class <<self
        remove_method :redirectable?
        alias_method :redirectable?, :redirectable_baller?
       end
     else
       class <<self
         remove_method :redirectable?
         alias_method :redirectable?, :redirectable_cautious?
       end
     end
     self.open_uri_original name, options
  end
end

module Nesta
  module Plugin
    module Drop
      class Client
        def self.host(key = nil)
          if key
            "https://#{key}:@api.nestadrop.io"
	  else
            "https://api.nestadrop.io"
	  end
        end

        def self.confirm_linked!
          return true if File.exists?("/tmp/.nestadropped")
          File.open("/tmp/.nestadropped", "w+") do |f|
            f.write "linked"
          end
        end

        def self.nestadrop_configured?
          return true if File.exists?("/tmp/.nestadropped")
          false
        end

        def self.bounce_server!
          puts "Restarting server..."
          ppid = Process.ppid
          Process.kill("HUP", ppid)
        end

        def self.files
          files = RestClient.get "#{host(ENV["NDROP_KEY"])}/files", { accept: :json }
          Yajl::Parser.parse files
        rescue RestClient::Unauthorized
          return []
        end

        def self.cache_file(file)
          confirm_linked!
          local_path = [Nesta::App.root, file].join("/")
	  puts "Caching: #{local_path}"
          FileUtils.mkdir_p(File.dirname(local_path))
          file_contents = open("#{host}/file?file=#{URI.encode(file)}",
            http_basic_authentication: [ENV["NDROP_KEY"], ""]).read
          File.open(local_path, 'w') do |fo|
            fo.write file_contents
          end
          bounce_server!
        rescue OpenURI::HTTPError => ex
          puts ex
        rescue RuntimeError => ex
          puts ex
        end

        def self.cache_files
          threads = []
          filenames = Client.files
          return unless filenames.size > 0
	  slice_size = filenames.size/3
	  puts "Slice size is: #{slice_size}"
          filenames.each_slice(slice_size).each do |slice|
            threads << Thread.new do
              slice.each do |file, status|
                cache_file(file)
              end
            end
          end
          threads.each(&:join)
        end

        def self.remove_file(file)
          local_path = [Nesta::App.root, file].join("/")
          FileUtils.rm_r(File.dirname(local_path), secure: true)
          bounce_server!
        end

        def self.bootstrap!
          unless nestadrop_configured?
            cache_files
          end
        end
      end

      module Helpers
        def nestadrop_configured?
          Client.nestadrop_configured?
        end

        def setup_nestadrop
          redirect to("#{Nesta::Plugin::Drop::Client.host}/?domain=#{request.host}&key=#{ENV["NDROP_KEY"]}")
        end

        def check_nestadrop
          return if request.path_info =~ %r{\A/nestadrop\z}
          setup_nestadrop unless nestadrop_configured?
        end

        def nestadrop_request?
          params["KEY"] == ENV["NDROP_KEY"]
        end
      end
    end
  end
  class App
    helpers Nesta::Plugin::Drop::Helpers
    before do
      check_nestadrop
    end

    error do
      Bugsnag.auto_notify($!)
      set_common_variables
      haml(:error)
    end

    post "/nestadrop" do
      if !nestadrop_request?
        status 404
      else
        if params["file"]
	  Thread.new do
            Nesta::Plugin::Drop::Client.cache_file(params["file"])
	  end
        else
	  Thread.new do
            Nesta::Plugin::Drop::Client.cache_files
	  end
        end
        status 200
        ""
      end
    end

    delete "/nestadrop" do
      if !nestadrop_request?
        status 404
      else
        if params["file"]
          Thread.new do
            Nesta::Plugin::Drop::Client.remove_file(params["file"])
          end
        end
        status 200
        ""
      end
    end
  end
end

Nesta::Plugin::Drop::Client.bootstrap!
