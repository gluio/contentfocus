require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

use Rack::ConditionalGet
use Rack::ETag

require 'nesta/env'
base_path = ::File.expand_path('.', ::File.dirname(__FILE__))
Nesta::Env.root = ::File.expand_path('.', ::File.dirname(__FILE__))

require 'nesta-plugin-contentfocus'
require 'nesta-theme-median'
require 'nesta/app'
Nesta::ContentFocus::Paths.add_view_path(File.join(base_path, "views"))
Nesta::ContentFocus::Paths.add_sass_path(File.join(base_path, "views"))
Nesta::ContentFocus::Rack.mount_assets(self)
run Nesta::App
