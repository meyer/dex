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
	def console_red; colorize(self, "\e[31m"); end
	def console_green; colorize(self, "\e[32m"); end

	def console_bold; colorize(self, "\e[1m"); end
	def console_underline; colorize(self, "\e[4m"); end

	def colorize(text, color_code)  "#{color_code}#{text}\e[0m" end
end

# http://www.dzone.com/snippets/generating-yaml-hashes-sorted
class Hash
	def to_yaml( opts = {} )
		YAML::quick_emit( object_id, opts ) do |out|
			out.map( taguri, to_yaml_style ) do |map|
				sort.each do |k, v|
					map.add( k, v )
				end
			end
		end
	end
end


# Command line flags
if (%w( -h --help -help help ) & ARGV).length > 0
	puts "usage: dexd [-hv]"
	puts "starts dex server in the foreground. kill with <Control>C"
	exit
end

if ARGV.include? '-v'
	puts "dexd #{DEX_VERSION}"
	exit
end

# Verbose mode
DEX_VERBOSE = ARGV.include? '--verbose'
def puts_maybe(*args) puts args if DEX_VERBOSE end

Dir.chdir(DEX_DIR)

# TODO: Cache modules unless the ~/.dex folder changes. Maybe? Performance?
def accio_modules(hostname=false)
	if !hostname
		puts_maybe "No hostname specified. Ignoring site folders."
	elsif hostname.include?('*') or !hostname.include?('.')
		puts_maybe "Hostname `#{hostname}` is invalid."
		return {}
	end

	dex_modules = {
		'rejected' => [],
		'enabled' => {
			'global' => []
		},
		'disabled' => {
			'global' => Dir.glob("global/*/").map {|s| s[0...-1]}
		}
	}

	if hostname
		dex_modules['disabled']['site'] = Dir.glob("{utilities,#{hostname}}/*/").map {|s| s[0...-1]}
		dex_modules['enabled']['site'] = []
	end

	site_modules = []
	global_modules = []

	# TODO: Make sure this actually works.
	begin
		config = YAML::load_file('enabled.yaml')
	rescue SyntaxError
		config = {}
	end

	available = Dir.glob("{global,utilities,*.*}/*/").map {|s| s[0...-1]}

	puts_maybe "  "+"Inspecting config".console_underline
	config.delete_if do |url, modList|

		# Only keep dotted folders and `global`
		if url.include?('.') or url == 'global'

			# Prune non-existent folders
			modList.delete_if do |mod|

				modPath = false

				# modList can only contain site and utilities folders
				# `global` module cannot contain utilities
				if !mod.include?('/')
					modPath = "#{url}/#{mod}"
				elsif mod.match(/^utilities\//) and url != 'global'
					modPath = mod
				end

				# If `modPath` isn’t in `available`, it doesn’t exist.
				if modPath and available.include?(modPath)
					puts_maybe "  ✔ #{url} => #{mod}"

					# Enabled!
					if hostname and url == hostname
						dex_modules['enabled']['site'].push modPath
						dex_modules['disabled']['site'].delete modPath
					elsif url == 'global'
						dex_modules['enabled']['global'].push modPath
						dex_modules['disabled']['global'].delete modPath
					end
					false
				else
					modPath = mod unless modPath
					puts_maybe "  ✗ #{url} => #{mod}".console_red
					dex_modules['rejected'].push(modPath)
					true
				end

			end

			if !modList.empty?
				config[url] = modList
				false
			else
				true
			end
		else
			puts_maybe "  ✗ #{url} (invalid URL)".console_red
			dex_modules['rejected'].push(url)
			true
		end
	end

	unless dex_modules['rejected'].empty?
		puts_maybe "  • #{dex_modules['rejected'].length} rejected key#{if dex_modules['rejected'].length != 1 then 's' end} will be deleted next time config is modified.".console_red
	end

	dex_modules['all'] = config

	dex_modules

end

class DexServer < WEBrick::HTTPServlet::AbstractServlet
	def do_GET(request, response)
		puts_maybe '','=' * 64,''
		puts "GET: #{Time.now.asctime} - #{request.path}".console_bold

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
				puts_maybe "Loading index page…"
				dex_modules = accio_modules()
				response['Content-Type'] = "text/html; charset=utf-8"
				response.body = ERB.new($index_template).result(binding)
			else
				puts "404: #{path} not found".console_red
				response.status = 404
				response.body = "`#{path}` does not exist."
			end
		end
	end

	def generate_response(url,ext,request,response)

		dex_modules = accio_modules(url)

		if ext == 'css' or ext == 'js'
			# Add root URL folder to the front of the glob string
			dex_modules['enabled']['site'].unshift url

			site_files = {
				'enabled' => Dir.glob("{#{(dex_modules['enabled']['site']).join(',')}}/*.#{ext}"),
				'disabled' => Dir.glob("{#{dex_modules['disabled']['site'].join(',')}}/*.#{ext}")
			}
			global_files = {
				'enabled' => Dir.glob("{#{(dex_modules['enabled']['global']).join(',')}}/*.#{ext}"),
				'disabled' => Dir.glob("{#{dex_modules['disabled']['global'].join(',')}}/*.#{ext}")
			}

			e = global_files['enabled'] + site_files['enabled']
			d = global_files['disabled'] + site_files['disabled']

			if DEX_VERBOSE
				puts "","  "+"Loading #{e.length} #{ext.upcase} file#{if e.length!=1 then 's' end} for #{url.console_bold}".console_underline
				e.each {|f| puts "  ✔ #{f}"}
				d.each {|f| puts "  ✗ #{f}"}
			end

			body_prefix = "/* Dex #{DEX_VERSION} at your service.\n"
			body = ""

			e.each do |file|
				body_prefix << "\n[+] #{file}"
				body << "\n/* @start #{file} */\n#{IO.read(file)}\n/* @end #{file} */\n\n"
			end

			d.each do |file|
				body_prefix << "\n[ ] #{file}"
			end

			body_prefix << "\n\n*/\n"

			if body.empty?
				response.body = "/* No dexfiles to load for #{url}. I feel… empty. */"
			else
				response.body = "#{body_prefix}#{body}"
			end

		elsif ext == 'html'

			if request.query['toggle'] and request.query['toggle'].include?('/')

				if File.directory? request.query['toggle']
					folder = request.query['toggle'].to_s

					puts_maybe "  > Folder `#{folder}` exists"

					module_folder, module_name = folder.split('/',2)
					module_scope = 'site'

					if ['global','utilities',url].include? module_folder

						module_scope = 'global' if module_folder == 'global'

						if module_folder == 'utilities'
							module_folder = url
							module_name = folder
						end

						dex_modules['all'][module_folder] ||= []
						site_config = dex_modules['all'][module_folder]

						# The dirty work
						if dex_modules['enabled'][module_scope].delete(folder)
							dex_modules['disabled'][module_scope].push folder

							if site_config.include?(module_name)
								puts_maybe "  > Folder `#{folder}` is an active #{module_scope} module. Deactivate it!"
								site_config.delete(module_name)

								if site_config.length == 0
									puts_maybe "Module key `#{url}` is empty. Deleting!"
									dex_modules['all'].delete url
								end
							else
								puts_maybe "  > Folder `#{folder}` is already an active #{module_scope} module.", site_config.to_yaml
							end
						else
							dex_modules['enabled'][module_scope].push folder
							dex_modules['disabled'][module_scope].delete folder

							unless site_config.include?(module_name)
								puts_maybe "  > Folder `#{folder}` is an inactive #{module_scope} module. Activate it!"
								site_config.push module_name
							else
								puts_maybe "  > Folder `#{folder}` is already an inactive #{module_scope} module. Carry on…", site_config.to_yaml
							end
						end

						File.open('enabled.yaml','w+') do |file|
							puts_maybe "  > Save modified config file…"

							# # Ghetto alphabetical YAML::dump.
							# file_contents = '# Hi mom!!'
							# file_contents << "\n---"
							#
							# keys = dex_modules['all'].keys
							# keys.sort.each do |k|
							# 	file_contents << "\n#{k}:"
							# 	dex_modules['all'][k].each do |v|
							# 		file_contents << "\n- #{v}"
							# 	end
							# end

							# file_contents << "\n..."

							file.write "# #{Time.now.asctime}\n"+dex_modules['all'].to_yaml
						end

					end

				else
					puts_maybe "Folder `#{folder}` does not exist"
				end
			end

			response.body = ERB.new($site_template).result(binding)
		end
		response
	end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

$site_template = <<-site_template<%= "\n"+(File.read File.join(SERVER_SOURCE_DIR,'site.html'))+"\n" %>site_template

$index_template = <<-index_template<%= "\n"+(File.read File.join(SERVER_SOURCE_DIR,'index.html'))+"\n" %>index_template

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

server_options[:Logger] = WEBrick::Log.new("/dev/null") unless DEX_VERBOSE

server = WEBrick::HTTPServer.new(server_options)
server.mount('/', DexServer)

trap 'INT' do server.shutdown end
trap 'TERM' do server.shutdown end

puts "dexd #{DEX_VERSION} at your service…".console_green
server.start

__END__
<%= File.read File.join(SERVER_SOURCE_DIR,DEX_HOSTNAME+'.pem') %>