#!/usr/bin/env ruby

DEX_DIR = "<%= DEX_DIR %>"
DEX_VERSION = "<%= @ext_version %>"
DEX_PORT = "<%= DEX_PORT %>"

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

# Development: serve dexfiles out of current directory
# TODO: check site subfolder
if not Dir.glob(File.join(DEX_DIR, "*.{css,js}")).empty?
	Dir.chdir(DEX_DIR)
end

require 'webrick'
require 'webrick/https'

server_object = Class.new(WEBrick::HTTPServlet::AbstractServlet) do
	def do_GET(request, response)
		filename, sep, ext = request.path.gsub('/', '').rpartition('.')

		if filename.include? 'localhost'
			response.body = '/* Disabled for localhost */'
			return
		end

		if !['js','css'].include? ext
			response.body = "no #{ext} file 4 u"
			return
		end

		puts ''

		body = build_body(request.path, ext, filename)
		response.status = body.empty? ? 204 : 200

		if origin = detect_origin(request, ext)
			response['Access-Control-Allow-Origin'] = origin
		end

		response['Content-Type'] = 'application/javascript; charset=utf-8'
		if ext == 'css'
			response['Content-Type'] = 'text/css; charset=utf-8'
		end

		response.body = body
	end

	def build_body(path, ext, filename)
		files = [File.expand_path("common.#{ext}")]
		paths = path.gsub('/', '').split('.')

		until paths.empty?
			file = File.expand_path(paths.join('.'))
			files << file if File.file?(file)
			paths.shift
		end

		# Add site folders
		files += Dir.glob(File.expand_path("#{filename}/*.#{ext}"))

		body = ""
		body_prefix = "/* dexd #{DEX_VERSION} at your service.\n"

		puts "Loading #{files.count} #{ext.upcase} file#{files.count>1 ? 's':''} for #{filename}".console_red

		files.each do |file|
			short_file = file.sub(File.expand_path('')+'/', '')
			if short_file.include? '.disabled'
				body_prefix << "\n[ ] "
			elsif File.file?(file)
				puts short_file
				body_prefix << "\n[+] "
				body << "\n/* @start #{short_file} */\n" + IO.read(file) + "\n/* @end #{short_file} */\n\n"
			end
			body_prefix << short_file
		end

		body_prefix << "\n\n*/\n"

		body_prefix + body
	end

	def detect_origin(req, ext)
		# ["https://site.com"]
		origin = req.header['origin']

		# /site.com.(css|js)
		path = req.path

		# 'site.com'
		search = path.gsub('/','').gsub(/\.#{ext}$/,'') + '$'

		# If the search URL is in the requesting URL, return `origin[0]`
		if origin.length == 1 && path.length != 1 && origin[0].match(search)
			origin[0]
		end
	end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key	 = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

server_options = {
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

%w( INT TERM ).each do |sig|
	trap(sig) { server.shutdown }
end

server.start

__END__
-----BEGIN CERTIFICATE-----
MIICHTCCAYYCCQClZE2IvNWbtDANBgkqhkiG9w0BAQUFADBTMQswCQYDVQQGEwJV
UzETMBEGA1UECBMKQ2FsaWZvcm5pYTELMAkGA1UEBxMCTEExDjAMBgNVBAoTBWRv
dGpzMRIwEAYDVQQDEwlsb2NhbGhvc3QwHhcNMTMwMjIwMjMzNzUzWhcNMjIxMTIw
MjMzNzUzWjBTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTELMAkG
A1UEBxMCTEExDjAMBgNVBAoTBWRvdGpzMRIwEAYDVQQDEwlsb2NhbGhvc3QwgZ8w
DQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAMNgNijoFmD5TX7NMd2pGEeEmwRifWRc
45jVS1a5kUncfRfgr4ehygPQDS2XrUkd+OYneFIXOcANW9WAWAlfeLs8DiSgs+9m
tuVjZ58RAsRXkW7H3vqQv5sAxmmwwVGN9WfKW+II/xLhpMtVGQH+MOucGbssODzk
0vwXEGSeEqYdAgMBAAEwDQYJKoZIhvcNAQEFBQADgYEAgCW2RBZgDMikQenSF3sz
u7KDe8+t8qnEFvrwCEpLUzvedSZxkaKzHrrCnIYlDnXRZBveKngWoejGzqtyIXup
YKzBZaZWH8cV72RdDwgM1owWi3KZBKpxfphYkWSRRx59djHZY/Yjudnb3oT/3c8/
NHsFbLbrZaGriLshIwrjEGs=
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQDDYDYo6BZg+U1+zTHdqRhHhJsEYn1kXOOY1UtWuZFJ3H0X4K+H
ocoD0A0tl61JHfjmJ3hSFznADVvVgFgJX3i7PA4koLPvZrblY2efEQLEV5Fux976
kL+bAMZpsMFRjfVnylviCP8S4aTLVRkB/jDrnBm7LDg85NL8FxBknhKmHQIDAQAB
AoGAZDw9LRl9Ob1No+t0VOuG+FIxEbvR5ya84dE0OMc1ofZL+28bvvMjaHdZ+3Ug
wy1sX/AKC9u8liqEXfHduNlRX59WfhS1DBIqpezpg3Hj35sCmuGvtiJVMHbZBX0I
S0P14vXxaGJ/Sw04CgbGJs08P5ITTleZ9HioHhCkUObP5kUCQQD3auQTo/oqbNXz
FbL1ckP65wUz7ean+YcXDYgKM2jnyEfATMWjjQkMEzO4MJdfuLi+5UbEfup1c1zB
SmIijzN7AkEAyicud3X+HoV2dwRPzsquvR27fjEsIttzjNJ0Kcm+YAtIQcJQti9e
E9OMjSsxa8LQ1V8HMWmDYyoAEhdYG1BtRwJAczlTmJYANmvTQ87yNf6ODDY0pReB
GO9La4AAwAdrLq6GQ9c9H8rZ0MbMilYO2SRU3Yo3Z+FXXXVpWBdFFqUsKwJAKNYn
bdx5HENLvhkx4g1RpUR3VrOqPdRlEEKHUtW9TnuY+ie91D/XWlv23aGnFyTAuQm8
U0AEWajnYMA0fTgPCwJBAI1J6nOjlE5jcKKzBAE33iL8lXj5FlGX3hhPM4jm3BCN
bpmhcfRVwyhqWwYChEQ5Y25Lv0i7Lxpud/UbLE0x/x8=
-----END RSA PRIVATE KEY-----
