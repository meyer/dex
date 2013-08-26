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
	site_urls = ['global']

	if hostname == '*'
		# All site directories
		site_urls += Dir.glob('*.*/').map {|s| s[0...-1]}
	else
		# Just the hostname site directory
		site_urls.push "#{hostname}"
	end

	all_yaml_modules = YAML::load_file('enabled.yaml') || Hash.new

	ret = {}
	rejected = []

	site_urls.each do |url|
		# Include `utilities` for site folders only
		glob_str = "{#{url},utilities}/*/"
		glob_str = "#{url}/*/" if url == 'global'

		available = Dir.glob(glob_str).map {|s| s[0...-1]}
		enabled = []
		disabled = []

		if all_yaml_modules.has_key? url

			all_yaml_modules[url].delete_if do |mod|
				modPath = mod.include?('/') ? mod : "#{url}/#{mod}"
				if available.include? modPath
					enabled.push modPath
					false
				else
					rejected.push modPath
					true
				end
			end

			disabled = available - enabled
		end

		ret[url] = {
			'available' => available,
			'enabled' => enabled,
			'disabled' => disabled
		}

		# puts "# Loading #{enabled.size} dexfile#{if enabled.size != 1 then 's' end} for #{url}".console_green
		# puts ret[url].to_yaml

	end

	ret['all'] = all_yaml_modules
	ret['rejected'] = rejected

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
				folder = request.query['toggle']

				hostname, moduleDir = folder.split('/',2)

				if File.directory? folder
					puts "Folder `#{folder}` exists"

					modules = accio_modules('*')

					# Global or site module?
					if folder.include? 'global/'
						file_hash = global_dexfiles
						mod = modules['all']['global']
						module_key = 'global'
					else
						file_hash = site_dexfiles
						mod = (modules['all'].has_key? url) ? modules['all'][url] : []
						module_key = 'site'
					end

					folder_name = folder.to_s.gsub(/^(#{url}|global)\//,'')

					# The dirty work
					if file_hash.delete folder
						puts "`#{folder}` toggled off"
						disabled_dexfiles.push folder

						if mod.include? folder_name
							mod.delete(folder_name)
							puts "Folder `#{folder}` is an active #{module_key} module. Deactivate it!"
						else
							puts "Folder `#{folder}` is already an active #{module_key} module.", mod.to_yaml
						end
					else
						puts "`#{folder}` toggled on"
						file_hash.push folder
						disabled_dexfiles.delete folder

						unless mod.include? folder_name
							mod.push(folder_name.to_s)
							puts "Folder `#{folder}` is an inactive #{module_key} module. Activate it!"
						else
							puts "Folder `#{folder}` is already an inactive #{module_key} module. Carry on…", mod.to_yaml
						end
					end

					File.open('enabled.yaml','w+') do |f|
						puts "Save modified config file…"
						YAML::dump(modules['all'],f)
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