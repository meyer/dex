#!/usr/bin/env ruby
# encoding: utf-8

require "cgi"
require "erb"
require "uri"
require "json"
require "yaml"
require "webrick"
require "webrick/https"

DEX_DIR = "<%= DEX_DIR %>"
DEX_VERSION = "<%= @ext_version %>"
DEX_PORT = "<%= DEX_PORT %>"
DEX_HOSTNAME = "<%= DEX_HOSTNAME %>"

Dir.chdir DEX_DIR

# Print help
if (%w(-h --help -help) & ARGV).length > 0
	puts "usage: dexd [-hv]"
	puts "starts dex server in the foreground. kill with <Control>C"
	exit
end

# Print version number
if (%w(-v --version -version) & ARGV).length > 0
	puts "dexd #{DEX_VERSION}"
	exit
end

# --config /path/to/dex-config.yaml
dex_config_file = File.realpath(File.expand_path( "~/.dex-enabled" ))

if ARGV.length == 2
	case ARGV[0]
	when '-c', '--config', '-config'
		dex_config_file = File.realpath(File.expand_path( ARGV[1] ))

		unless File.exists? dex_config_file
			File.open(dex_config_file, "w", 0644) {|file|
				file.puts "# Generated by Dex #{DEX_VERSION}"
				file.puts "# #{Time.now.asctime}"
				file.puts "---"
			}

		end
	end
end

DEX_CONFIG = dex_config_file

# String formatting methods for the console
class String
	def console_red; colorize(self, "\e[31m"); end
	def console_green; colorize(self, "\e[32m"); end
	def console_bold; colorize(self, "\e[1m"); end
	def console_underline; colorize(self, "\e[4m"); end
	def colorize(text, color_code)  "#{color_code}#{text}\e[0m" end
	def markitdown
		# TODO: Use lookahead/lookbehind magic to match pairs
		self.gsub! %r{\*\*(\w|[^\s][^*]*?[^\s])\*\*}x, '<strong>\1</strong>'
		self.gsub! %r{  \*(\w|[^\s][^*]*?[^\s])\*  }x, '<em>\1</em>'
		self.gsub! %r{   `(\w|[^\s][^`]*?[^\s])`   }x, '<code>\1</code>'
		return self
	end
end

class DexServer < WEBrick::HTTPServlet::AbstractServlet
	def do_GET(request, response)
		puts "#{Time.now}: #{request.path}"
		begin
			config = YAML::load_file(DEX_CONFIG) || {}
			# Normalise config file
			config.values.map! do |arr|
				arr.map! {|v| v.to_s}.keep_if{|d| File.directory? d}.sort
			end
		rescue
			puts "Something went wrong while loading #{DEX_CONFIG}"
			response.body "x___x"
			return
		end

		content_types = {
			"css"  => "text/css; charset=utf-8",
			"html" => "text/html; charset=utf-8",
			"js"   => "application/javascript; charset=utf-8",
			"json" => "application/javascript; charset=utf-8",
			"svg"  => "image/svg+xml; charset=utf-8",
			"png"  => "image/png"
		}

		rgx = {
			"rsrc" => '(?<filename>[\w \-_\.@]+)\.(?<ext>png|svg|js|css)$',
			"url" =>  '(?<url>[\w\-_.]+\.\w{2,})',
			"mod" =>  '(?<mod>[\w\s\-]+)',
			"ext" =>  '(?<ext>css|js|json)'
		}

		# Info
		if request.path == "/"
			response.body = config.to_json
			return

		# Site-specific actions
		# /url.com.{css,js,json}
		elsif /^\/#{rgx["url"]}\.#{rgx["ext"]}$/.match request.path
			url, ext = $~.captures
			response["Content-Type"] = content_types[ext]

			# TODO: Get original array in map? "h" sux.
			h = url.split(".")
			hostnames = h.each_with_index.map {|v,k| h[k..h.length].join "."}[0...-1]

			available = {}
			enabled = {}

			available["global"] = Dir.glob("global/*/").map {|s| s[0...-1]}
			available["site"] = Dir.glob("{utilities,#{hostnames.join(",")}}/*/").map {|s| s[0...-1]}
			available["all"] = available["global"] | available["site"]

			enabled["global"] = available["global"] & (config["global"] || [])
			enabled["site"] = available["site"] & (config[url] || [])
			enabled["all"] = enabled["global"] | enabled["site"]

			case ext

			when "json"

				metadata = {}

				# Get all available modules
				Dir.glob("{global,utilities,*.*}/*/").each do |k|
					k = k[0...-1]
					metadata[k] = {
						"Author" => nil,
						"Description" => nil,
						"URL" => nil,
						"Title" => k.rpartition("/")[2]
					}
				end

				# Replace lame data with nifty metadata
				Dir.glob("{global,utilities,*.*}/*/info.yaml").each do |y|
					k = y[0...-10]

					# Load key-value YAML file
					YAML::load_file(y).each do |ik,iv|
						case ik
						when "Title"
							puts "Ignoring Title metadata"
						else
							if iv.class == String
								metadata[k][ik] = CGI::escapeHTML(iv).markitdown
							else
								metadata[k][ik] = iv
							end
						end
					end

				end

				if request["Referer"]
					ref = URI(request["Referer"])
					if ["localhost", "dexfiles.org"].include? ref.host
						response["Access-Control-Allow-Origin"] = URI.join(ref, "/").to_s[0...-1]
						puts "Access-Control-Allow-Origin = #{response["Access-Control-Allow-Origin"]}"
					end
				else
					puts 'request["Referer"] was not set'
				end

				toggle = request.query["toggle"].to_s.encode('utf-8')

				if toggle and available["all"].include?(toggle)

					scope = available["global"].include?(toggle) ? "global" : "site"

					action = "disabled"
					if enabled[scope].delete(toggle)
						puts " - `#{toggle}` was in `enabled[#{scope}]` so it was deleted"
					else
						puts " - `#{toggle}` was NOT in `enabled[#{scope}]` so it was added"
						enabled[scope].push(toggle).sort!
						action = "enabled"
					end

					# Delete empty
					puts " - Amending config[#{url}]"
					if enabled[scope].empty?
						if scope == "site"
							puts " - `enabled[#{scope}]` is empty and therefore `config[#{url}]` will be deleted"
							config.delete(url)
						else
							puts " - `enabled[#{scope}]` is empty and therefore `config[#{scope}]` will be deleted"
							config.delete(scope)
						end
					else
						if scope == "site"
							config[url] = enabled[scope]
						else
							config[scope] = enabled[scope]
						end
					end

					config = Hash[config.sort]

					# Global modules up front
					if gc = config.delete("global")
						config = {"global" => gc}.merge(config)
					end

					# TODO: Do this somewhere else. Maybe.
					config.delete_if{ |k, v| v.empty?}

					# Write the changes
					File.open(DEX_CONFIG,"w") do |file|
						file.puts "# Generated by Dex #{DEX_VERSION}"
						file.puts "# #{Time.now.asctime}"
						file.puts YAML::dump(config)
					end

					response.body = [action, toggle].to_json
					return
				end

				response.body = {
					"metadata" => metadata,
					"site_url" => url,
					"site_available" => available["site"].map!{|v| CGI::escapeHTML(v.to_s)},
					"site_enabled" => enabled["site"].map!{|v| CGI::escapeHTML(v.to_s)},
					"global_available" => available["global"].map!{|v| CGI::escapeHTML(v.to_s)},
					"global_enabled" => enabled["global"].map!{|v| CGI::escapeHTML(v.to_s)}
				}.to_json

			when "css", "js"
				body_prefix = ["/* Dex #{DEX_VERSION} at your service."]
				body = []

				unless enabled["all"].empty?
					body_prefix << "\nEnabled Modules:"
					body_prefix.push *enabled["all"].map {|e| "[+] #{e}"}
					body_prefix << "\nEnabled Files:"

					load_me = Dir.glob("{#{enabled["all"].join(",")}}/*.#{ext}")
					load_me.unshift *Dir.glob("{global,#{url}}/*.js") if ext == "js"

					load_me.each do |file|
						body_prefix << "[+] #{file}"

						if ext == "js"
							body << "\nconsole.group('#{file}');\n"
						else
							body << "/* @start #{file} */"
						end

						body << IO.read(file)

						if ext == "js"
							body << "\nconsole.groupEnd();\n"
						else
							body << "/* @end #{file} */"
						end
					end
				end

				body_prefix << "[x] No #{ext.upcase} files to load." if body.empty?
				body_prefix << "\n*/\n"

				response.body = (body_prefix + body).join "\n"
			end

			return

		# Edit path
		elsif /^\/edit\/(?<path>.*+)$/.match request.path
			path = $~.captures
			file_path = File.join(DEX_DIR, path)

			if File.exist?(file_path)
				puts "Opening '#{file_path}'"
				`open "#{file_path}"`
				response.body = "Opening '#{file_path}'..."
			else
				response.body = "'#{file_path}' does not exist."
			end

			return

		# Create module
		elsif /^\/create\/(?<site>(?:global|utilities|[^\/]+\.[^\/]+))\/(?<modulename>[^\/]+)$/.match request.path
			site, module_name = $~.captures

			file_path = File.join(DEX_DIR, site, module_name)

			unless File.directory?(file_path)
				FileUtils.mkdir_p file_path

				File.open(File.join(file_path, "info.yaml"), "w") {|f|
					f.puts "---"
					f.puts "Author: null"
					f.puts "Description: \"Write a concise description for `#{module_name}`\" here."
				}

				response.body = "Created module at '#{file_path}'."
			else
				response.body = "Path '#{file_path}' already exists."
			end

			puts response.body

			puts "Opening '#{file_path}'"
			`open "#{file_path}"`

			return

		# Load a resource if it exists
		# /url.com/module/resource.{css,js,png,svg,html}
		elsif /^\/#{rgx["url"]}\/#{rgx["mod"]}\/#{rgx["rsrc"]}$/.match request.path
			url, mod, filename, ext = $~.captures

			file_path = File.join(DEX_DIR, request.path)

			if File.exist?(file_path)
				response["Content-Type"] = content_types[ext]
				response.body = IO.read(file_path)
				return
			end
		end

		response.status = 404
		response.body = "'#{request.path}' does not exist."
	end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

server_options = {
	:Host => DEX_HOSTNAME,
	:BindAddress => "127.0.0.1",
	:Port => DEX_PORT,
	:Logger => WEBrick::Log.new("/dev/null"),
	:AccessLog => [],
	:SSLEnable => true,
	:SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
	:SSLPrivateKey => OpenSSL::PKey::RSA.new(ssl_key),
	:SSLCertificate => OpenSSL::X509::Certificate.new(ssl_cert),
	:SSLCertName => [["CN", WEBrick::Utils::getservername]]
}

server = WEBrick::HTTPServer.new(server_options)
server.mount("/", DexServer)

%w(INT TERM).each {|s| trap(s) { server.shutdown }}

puts "dexd #{DEX_VERSION} at your service…".console_green
server.start
__END__
<%= File.read File.join(SERVER_SOURCE_DIR, "#{DEX_HOSTNAME}.pem") %>