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

config_file = File.join(DEX_DIR,'enabled.txt')
$enabled_files = []

IO.foreach(config_file, File::CREAT) do |line|
	$enabled_files << line.chomp
end

$index_template = <<-index_template
<%= File.read File.join(SERVER_SOURCE_DIR,'index.html') %>
index_template

$site_template = <<-site_template
<%= File.read File.join(SERVER_SOURCE_DIR,'site.html') %>
site_template

class DexServer < WEBrick::HTTPServlet::AbstractServlet
	def do_GET(request, response)
		path = request.path.gsub!(/^\//,'')

		# response.status = 302
		# response['Location'] = 'http://google.com'
		# return

		# Won’t match non-dot URLs (ex: localhost) or URLs with port numbers
		/^(?<url>[\w\-_]+\.[\w\-_\.]+)\.(?<ext>css|html|json|js)$/ =~ path

		response.status = 200

		content_types = {
			'css' => 'text/css',
			'html' => 'text/html',
			'json' => 'application/json',
			'js' => 'application/javascript'
		}
		ext = 'html'

		if Regexp.last_match
			url = Regexp.last_match[:url]
			ext = Regexp.last_match[:ext]

			if ext == 'css' || ext == 'js'
				body = build_body(path, ext, url)
				response.status = 204 if body.empty?
				response.body = body
			elsif ext == 'html'
				puts "HTML PAGE FOR #{url}".console_green
				dexfiles = Dir.glob("*.{css,js}").sort + Dir.glob("#{url}/*.{css,js}").sort
				# dexfiles.map! { |f| "[#{($enabled_files.include? f) ? '+':' '}] #{f}"}

				response.body = ERB.new($site_template).result(binding)
			elsif ext == 'json'
				puts "JSON RESPONSE FOR #{url}".console_green
			end
		elsif path == ''
			puts 'INDEX PAGE'
			dexfiles = Dir.glob "{*.{css,js},#{url}/*.{css,js}}"
			response.body = ERB.new($index_template).result(binding)
		else
			puts "404: #{path} not found".console_red
			response.status = 404
			response.body = "`#{path}` does not exist."
		end

		response['Content-Type'] = content_types[ext]+"; charset=utf-8"

	end

	def build_body(path, ext, filename)
		# files in ~/.dex/ and ~/.dex/example.com/
		files = Dir.glob "{*.#{ext},#{filename}/*.#{ext}}"

		# files.delete_if {|f| !$enabled_files.include? f }

		# Move dex/jQuery to the front of the array, if it existed.
		files.unshift "dex.#{ext}" if files.delete "dex.#{ext}"
		# files.unshift "jquery.js" if files.delete "jquery.js"

		body = ""
		body_prefix = "/* dexd #{DEX_VERSION} at your service.\n"

		puts "Loading #{files.count} #{ext.upcase} file#{files.count>1 ? 's':''} for #{filename}".console_green

		files.each do |file|
			short_file = file.sub(File.expand_path('')+'/', '')

			if $enabled_files.include?(file) && File.file?(file)
				body_prefix << "\n[+] "
				body << "\n/* @start #{short_file} */\n" + IO.read(file) + "\n/* @end #{short_file} */\n\n"
			else
				body_prefix << "\n[ ] "
			end
			body_prefix << short_file
		end

		body_prefix << "\n\n*/\n"
		body_prefix + body
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