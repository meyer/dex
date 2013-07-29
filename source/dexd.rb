#!/usr/bin/env ruby

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

require 'webrick'
require 'webrick/https'

server_object = Class.new(WEBrick::HTTPServlet::AbstractServlet) do
	def do_GET(request, response)
		response.body = '/* DEX */'
		filename, sep, ext = request.path.gsub('/', '').rpartition('.')

		return if filename.include? 'localhost'

		unless ext == ''
			if ext == 'css'
				response['Content-Type'] = 'text/css; charset=utf-8'
			elsif ext == 'js'
				response['Content-Type'] = 'application/javascript; charset=utf-8'
			else
				response.body = "no .#{ext} file 4 u"
				return
			end
		else
			response.body = 'wat r u looking @'
			return
		end

		body = build_body(request.path, ext, filename)
		response.status = body.empty? ? 204 : 200

		response.body = body
	end

	def build_body(path, ext, filename)
		# files in ~/.dex/ and ~/.dex/example.com/, dex first
		files = Dir.glob "{*.#{ext},#{filename}/*.#{ext}}"

		# Move dex to the front of the array, if it existed.
		if files.delete "dex.#{ext}"
			files.unshift "dex.#{ext}"
		end

		body = ""
		body_prefix = "/* dexd #{DEX_VERSION} at your service.\n"

		puts "Loading #{files.count} #{ext.upcase} file#{files.count>1 ? 's':''} for #{filename}".console_red

		files.each do |file|
			short_file = file.sub(File.expand_path('')+'/', '')
			if short_file.include? '.disabled'
				body_prefix << "\n[ ] "
			elsif File.file?(file)
				body_prefix << "\n[+] "
				body << "\n/* @start #{short_file} */\n" + IO.read(file) + "\n/* @end #{short_file} */\n\n"
			end
			body_prefix << short_file
		end

		body_prefix << "\n\n*/\n"
		body_prefix + body
	end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key	 = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

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
server.mount('/', server_object)

trap 'INT' do server.shutdown end
trap 'TERM' do server.shutdown end

server.start

__END__
<%= File.read File.join(SERVER_SOURCE_DIR,DEX_HOSTNAME+'.pem') %>