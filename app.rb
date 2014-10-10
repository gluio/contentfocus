require 'rest_client'
require "open-uri"
require "yajl"
require 'fileutils'

module Nesta
  module Plugin
    module Drop
      class Client
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

        def self.files
          files = RestClient.get "https://#{ENV["NDROP_KEY"]}:@nestadrop.herokuapp.com/files", { accept: :json }
          Yajl::Parser.parse files
        rescue RestClient::Unauthorized
          return []
        end

        def self.cache_file(file)
          confirm_linked!
          local_path = [Nesta::App.root, file].join("/")
          FileUtils.mkdir_p(File.dirname(local_path))
          File.open(local_path, 'w') do |fo|
            fo.write open("https://nestadrop.herokuapp.com/file?file=#{file}",
                           http_basic_authentication: [ENV["NDROP_KEY"], ""]).read
          end
        end

        def self.cache_files
          Client.files.each do |file, status|
            cache_file(file)
          end
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
          redirect to("http://nestadrop.herokuapp.com/?domain=#{request.host}&key=#{ENV["NDROP_KEY"]}")
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

    post "/nestadrop" do
      if !nestadrop_request?
        status 404
      else
        if params["file"]
          Nesta::Plugin::Drop::Client.cache_file(params["file"])
        else
          Nesta::Plugin::Drop::Client.cache_files
        end
        status 200
        ""
      end
    end
  end
end

Nesta::Plugin::Drop::Client.bootstrap!
