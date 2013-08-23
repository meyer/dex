#!/usr/bin/env ruby
# encoding: utf-8

require 'erb'
require 'yaml'
require 'webrick'
require 'webrick/https'
require 'json'

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

# config_file = File.join(DEX_DIR,'enabled.txt')
config = YAML::load_file 'enabled.yaml'

# GLOBFEST
# $all_folders = {}
# $enabled_folders = {'global' => config.delete('global').map! {|s| "global/#{s}"}}
folders = config.delete('global').map! {|s| "global/#{s}"}

$css = {'global' => Dir.glob("global/{#{folders.join ','}}/*.css")}
$js = {'global' => Dir.glob("global/{#{folders.join ','}}/*.js")}

# Dir.glob('*/').each do |folder|
# 	folder = folder[0...-1]
# 	$all_folders[folder] = [folder]
# 	$all_folders[folder] += Dir.glob("#{folder}/*/").map! {|s| s[0...-1] }
# end

config.each do |hostname,folderList|
	glob_str = []
	$css[hostname] = Dir.glob "#{hostname}/*.css"
	$js[hostname] = Dir.glob "#{hostname}/*.js"
	# $enabled_folders[hostname] = [hostname]

	folderList.each do |folder|
		# Include a module from another site
		if folder.include? '/'
			$css[hostname] += Dir.glob "#{folder}/*.css"
			$js[hostname] += Dir.glob "#{folder}/*.js"
			# $enabled_folders[hostname].push "#{folder}"
		else
			glob_str.push folder
			# $enabled_folders[hostname].push "#{hostname}/#{folder}"
		end
	end

	unless glob_str.empty?
		$css[hostname] += Dir.glob "#{hostname}/{#{glob_str.join ','}}/*.css"
		$js[hostname] += Dir.glob "#{hostname}/{#{glob_str.join ','}}/*.js"
	end
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
				body = build_body(url, ext)
				response.status = 204 if body.empty?
				response.body = body
			elsif ext == 'html' || ext == 'json'
				if ext == 'html'
					response.body = ERB.new($site_template).result(binding)
				elsif ext == 'json'
					response.body = JSON.generate({})
				end
			end
		elsif path == ''
			puts 'INDEX PAGE'
			response.body = ERB.new($index_template).result(binding)
		else
			puts "404: #{path} not found".console_red
			response.status = 404
			response.body = "`#{path}` does not exist."
		end

		response['Content-Type'] = content_types[ext]+"; charset=utf-8"

	end

	def build_body(filename, ext)
		# files in ~/.dex/ and ~/.dex/example.com/
		files = []

		if ext == 'css'
			files += $css['global']
			files += $css[ filename ] if $css.has_key? filename
		else
			files += $js['global']
			files += $js[ filename ] if $js.has_key? filename
		end

		puts "Loading #{files.count} #{ext.upcase} file#{files.count>1 ? 's':''} for #{filename}".console_green

		body_prefix = "/* dexd #{DEX_VERSION} at your service.\n"
		body = ""

		files.each do |file|
			if File.file?(file)
				body_prefix << "\n[+] #{file}"
				body << "\n/* @start #{file} */\n" + IO.read(file) + "\n/* @end #{file} */\n\n"
			end
		end

		body_prefix << "\n\n*/\n"
		body_prefix + body

		# e = $enabled_folders['global']
		# e += $enabled_folders[filename] if $enabled_folders.has_key? filename
		#
		# a = $all_folders['global']
		# a += $all_folders[filename] if $all_folders.has_key? filename

		#glob_str = []
		#
		#body_prefix = "/* dexd #{DEX_VERSION} at your service.\n"
		#a.each do |folder|
		#	if e.include?(folder)
		#		glob_str << folder
		#		body_prefix << "\n[+] #{folder}"
		#	else
		#		body_prefix << "\n[ ] #{folder}"
		#	end
		#end
		#body_prefix << "\n\n*/\n"
		#
		#Dir.glob("{#{glob_str.join(',')}}/*.#{ext}").each do |file|
		#	if File.file?(file)
		#		body << "\n/* @start #{file} */\n" + IO.read(file) + "\n/* @end #{file} */\n\n"
		#	end
		#end
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