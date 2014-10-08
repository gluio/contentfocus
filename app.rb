require 'rest_client'
require "open-uri"
require "yajl"
require 'fileutils'

module Nesta
  class App
    helpers do
      def nestadrop_configured?
        return true if File.exists?("/tmp/.nestadropped")
        false
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

      def dropbox_files
        files = RestClient.get "https://#{ENV["NDROP_KEY"]}:@nestadrop.herokuapp.com/files", { accept: :json }
        Yajl::Parser.parse files
      end

      def confirm_linked!
        File.open("/tmp/.nestadropped", "w+") do |f|
          f.write "linked"
        end
      end

      def cache_dropbox_file(file)
        local_path = [Nesta::App.root, file].join("/")
        STDOUT.puts "Writing out #{file} to #{local_path}"
        FileUtils.mkdir_p(File.dirname(local_path))
        File.open(local_path, 'w') do |fo|
          fo.write open("https://nestadrop.herokuapp.com/file?file=#{file}",
                         http_basic_authentication: [ENV["NDROP_KEY"], ""]).read
        end
      end

      def fetch_dropbox_files
        files = dropbox_files
        confirm_linked!
        files.each do |file, status|
          cache_dropbox_file(file)
        end
      end
    end

    before do
      check_nestadrop
    end

    post "/nestadrop" do
      if !nestadrop_request?
        status 404
      else
        fetch_dropbox_files
        status 200
        ""
      end
    end
  end
end
