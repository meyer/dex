#!/usr/bin/env ruby
# encoding: utf-8

require 'erb'
require 'yaml'
require 'webrick'
require 'webrick/https'

DEX_DIR = "<%= DEX_DIR %>"
DEX_VERSION = "<%= @ext_version %>"
DEX_PORT = "<%= DEX_PORT %>"
DEX_HOSTNAME = "<%= DEX_HOSTNAME %>"

# Yoinked from Github
class String
	def console_red; colorize(self, "\e[1m\e[31m"); end
	def console_green; colorize(self, "\e[1m\e[32m"); end
	def console_bold; colorize(self, "\e[1m"); end

	def colorize(text, color_code)  "#{color_code}#{text}\e[0m" end
end

# Command line flags
if (%w( -h --help -help help ) & ARGV).length > 0
	puts "usage: dexd [-hv]"
	puts "starts dex server in the foreground. kill with <Control>C"
	exit
end

if ARGV.include?('-v')
	puts "dexd #{DEX_VERSION}"
	exit
end

Dir.chdir(DEX_DIR)

$modules = YAML::load_file 'enabled.yaml'
# $all_modules = Dir.glob("{*/,*/*/}").sort.map {|s| s[0...-1]}
$disabled_modules = {}

$css = {'global' => Dir.glob("{#{$modules['global'].join ','}}/*.css")}
$js = {'global' => Dir.glob("{#{$modules['global'].join ','}}/*.js")}

$modules.map do |hostname,moduleList|
	glob_str = [hostname]
	$modules[hostname] = []
	disabled = []

	moduleList.map! do |m|
		# Include a module from another site, i.e. utilities/blackout
		mod = if m.include? '/' then m else "#{hostname}/#{m}" end
		if File.directory? mod
			glob_str.push mod
			$modules[hostname].push m
		else
			disabled.push mod
		end
	end

	unless disabled.empty?
		$disabled_modules[hostname] = disabled
	end

	$css[hostname] = Dir.glob "{#{glob_str.join ','}}/*.css"
	$js[hostname] = Dir.glob "{#{glob_str.join ','}}/*.js"

	moduleList
end

puts "Disabled modules (to be deleted from enabled.yaml):\n#{$disabled_modules.to_yaml}\n"

$index_template = <<-index_template
<%= File.read File.join(SERVER_SOURCE_DIR,'index.html') %>
index_template

$site_template = <<-site_template
<%= File.read File.join(SERVER_SOURCE_DIR,'site.html') %>
site_template

class DexServer < WEBrick::HTTPServlet::AbstractServlet
	def do_GET(request, response)
		path = request.path.gsub!(/^\//,'')

		# Won’t match non-dot URLs (ex: localhost) or URLs with port numbers
		/^([\w\-_]+\.[\w\-_\.]+)\.(css|html|js)$/ =~ path

		response.status = 200

		content_types = {
			'css' => 'text/css',
			'html' => 'text/html',
			'json' => 'application/json',
			'js' => 'application/javascript'
		}
		ext = 'html'

		if Regexp.last_match
			url = Regexp.last_match[1]
			ext = Regexp.last_match[2]
			dexfiles = []

			if ext == 'css' || ext == 'js'

				if ext == 'css'
					dexfiles += $css['global']
					dexfiles += $css[ url ] if $css.has_key? url
				else
					dexfiles += $js['global']
					dexfiles += $js[ url ] if $js.has_key? url
				end

				puts "Loading #{dexfiles.count} #{ext.upcase} file#{dexfiles.count>1 ? 's':''} for #{url}".console_green
				body = build_dexfile(dexfiles)

				response.status = 204 if body.empty?
				response.body = body

			elsif ext == 'html'

				GC.start

				global_dexfiles = $modules['global']
				site_dexfiles = []
				site_dexfiles = $modules[ url ] if $modules.has_key? url

				global_dexfiles.map! {|s| "global/#{s}"}
				site_dexfiles.map! {|s| "#{url}/#{s}"}

				all_global_dexfiles = Dir.glob('global/*/').map {|s| s[0...-1]}
				all_site_dexfiles = Dir.glob("{#{url}/*/,utilities/*/}").map {|s| s[0...-1]}

				if request.query['toggle']
					folder = request.query['toggle'].to_s

					k, mod = folder.split('/',2)

					if File.directory? folder
						puts "Folder `#{folder}` exists"

						if site_dexfiles.delete folder
							puts "`#{folder}` toggled off"
						else
							puts "`#{folder}` toggled on (1)"
							site_dexfiles.push(folder).sort
						end

					else
						puts "Folder `#{folder}` does not exist"
					end
				end

				puts site_dexfiles.to_yaml
				puts all_site_dexfiles.to_yaml
				puts global_dexfiles.to_yaml
				puts all_global_dexfiles.to_yaml

				response.body = ERB.new($site_template).result(binding)
			end

		else
			if path == ''
				puts 'INDEX PAGE'
				response.body = ERB.new($index_template).result(binding)
			else
				puts "404: #{path} not found".console_red
				response.status = 404
				response.body = "`#{path}` does not exist."
			end
		end

		response['Content-Type'] = "#{content_types[ext]}; charset=utf-8"

	end

	def build_dexfile(files)
		body_prefix = "/* dexd #{DEX_VERSION} at your service.\n"
		body = ""

		files.each do |file|
			if File.file?(file)
				body_prefix << "\n[+] #{file}"
				body << "\n/* @start #{file} */\n#{IO.read(file)}\n/* @end #{file} */\n\n"
			else
				body_prefix << "\n[ ] #{file}"
			end
		end

		body_prefix << "\n\n*/\n"
		"#{body_prefix}#{body}"
	end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

server_options = {
	:Host => DEX_HOSTNAME,
	:BindAddress => "127.0.0.1",
	:Port => DEX_PORT,
	:AccessLog => [],
	:SSLEnable => true,
	:SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
	:SSLPrivateKey => OpenSSL::PKey::RSA.new(ssl_key),
	:SSLCertificate => OpenSSL::X509::Certificate.new(ssl_cert),
	:SSLCertName => [["CN", WEBrick::Utils::getservername]],
}

server = WEBrick::HTTPServer.new(server_options)
server.mount('/', DexServer)

trap 'INT' do server.shutdown end
trap 'TERM' do server.shutdown end

server.start

__END__
<%= File.read File.join(SERVER_SOURCE_DIR,DEX_HOSTNAME+'.pem') %>