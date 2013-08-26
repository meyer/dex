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

# TODO: Cache modules unless the ~/.dex folder changes. Maybe? Performance?
def accio_modules(hostname)
	urls = ['global']

	if hostname == '*'
		# All site directories
		urls += Dir.glob('*.*/').map {|s| s[0...-1]}
	else
		# Just the hostname site directory
		urls.push "#{hostname}"
	end

	orig_yaml_modules = YAML::load_file('enabled.yaml')
	all_yaml_modules = orig_yaml_modules.reject {|k,v| !urls.include? k}

	ret = {}

	urls.each do |url|
		# Include `utilities` for site folders only
		glob_str = "{#{url},utilities}/*/"
		glob_str = "#{url}/*/" if url == 'global'

		available = Dir.glob(glob_str).map {|s| s[0...-1]}
		enabled = []
		disabled = []
		rejected = []

		if all_yaml_modules.has_key? url
			yaml_modules = all_yaml_modules[url].map {|mod|
				if mod.include?('/') then mod else "#{url}/#{mod}" end
			}

			enabled = yaml_modules.select {|mod| available.include? mod}
			disabled = available - yaml_modules
			rejected = yaml_modules - available
		end

		ret[url] = {
			'available' => available,
			'enabled' => enabled,
			'disabled' => disabled,
			'rejected' => rejected
		}

		puts "# Loading #{enabled.size} dexfile#{if enabled.size != 1 then 's' end} for #{url}".console_green
		puts ret[url].to_yaml

	end

	ret['all'] = orig_yaml_modules

	ret

end

class DexServer < WEBrick::HTTPServlet::AbstractServlet
	def do_GET(request, response)
		path = request.path.gsub!(/^\//,'')

		/^([\w\-_]+\.[\w\-_\.]+)\.(css|html|js)$/ =~ path

		response.status = 200

		content_types = {
			'css' => 'text/css',
			'html' => 'text/html',
			'js' => 'application/javascript'
		}

		if Regexp.last_match
			url = Regexp.last_match[1]
			ext = Regexp.last_match[2]
			response['Content-Type'] = "#{content_types[ext]}; charset=utf-8"
			response = generate_response(url,ext,request,response)
		else
			if path == ''
				response = generate_response('*',ext,request,response)
			else
				puts "404: #{path} not found".console_red
				response.status = 404
				response.body = "`#{path}` does not exist."
			end
		end
	end

	def generate_response(url,ext,request,response)

		m = accio_modules(url)
		modules = m['global']['enabled'] + ["#{url}"] + m[url]['enabled']

		if ext == 'css' || ext == 'js'
			files = Dir.glob "{#{modules.join(',')}}/*.#{ext}"

			puts "","Loading #{ext.upcase} for #{url}".console_green
			puts modules.to_yaml

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

			response.status = 204 if body.empty?
			response.body = "#{body_prefix}#{body}"

		elsif ext == 'html'

			global_dexfiles = m['global']['enabled']
			site_dexfiles = m[url]['enabled']
			disabled_dexfiles = m['global']['disabled'] + m[url]['disabled']

			if request.query['toggle'] and request.query['toggle'].include? '/'
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

			tpl = (url == '*') ? $index_template : $site_template
			response.body = ERB.new(tpl).result(binding)
		end
		response
	end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

$index_template = <<-index_template<%= "\n"+(File.read File.join(SERVER_SOURCE_DIR,'index.html'))+"\n" %>index_template

$site_template = <<-site_template<%= "\n"+(File.read File.join(SERVER_SOURCE_DIR,'site.html'))+"\n" %>site_template

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