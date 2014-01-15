#!/bin/env ruby
# encoding: utf-8

EXT_NAME = 'dex'
EXT_VERSION = '1.0.1'

EXT_DISPLAY_NAME = 'Dex'
EXT_DESC = IO.read('./source/extension/description.txt')
EXT_URL = 'https://github.com/meyer/dex'
EXT_AUTHOR = 'Mike Meyer'
EXT_BUNDLE_ID = 'fm.meyer.dex'
EXT_CONTENT_SCRIPTS = ['main.coffee']

# safari.extension.baseURI + 'filename'
# chrome.extension.getURL('filename')
EXT_EXTRA_RESOURCES = ['dex.coffee']

EXT_BACKGROUND_PAGE = true
EXT_POPOVER_MENU = true

EXT_WHITELIST = ['http://*/*','https://*/*']
EXT_ICONS = [32,48,64,96,128]
EXT_SAFARI_DEV_ID = '7ZCMA49A25'
EXT_SAFARI_UPDATE_URL = "https://raw.github.com/meyer/dex/master/extensions/dex-#{EXT_VERSION}.safariextz"
EXT_SAFARI_UPDATE_MANIFEST_URL = "https://raw.github.com/meyer/dex/master/extensions/safari-update-manifest.plist"

EXT_SOURCE_DIR = './source/extension'
EXT_CERT_DIR = '../certificates'
EXT_RELEASE_DIR = './extensions'

TEMP_DIR = './build'

# Server Config
DEX_DIR = File.join(ENV['HOME'], '.dex/')
DEX_PORT = 3131
DEX_DAEMON = 'dexd'
DEX_HOSTNAME = 'localhost'

DEX_URL = "https://#{DEX_HOSTNAME}:#{DEX_PORT}"

SERVER_SOURCE_DIR = './source'
SERVER_RELEASE_DIR = TEMP_DIR

LAUNCHAGENT_SRC_FILENAME = 'launchagent.xml'
LAUNCHAGENT_SRC_FILE = File.join(SERVER_RELEASE_DIR, LAUNCHAGENT_SRC_FILENAME)
LAUNCHAGENT_DEST_DIR = File.expand_path('~/Library/LaunchAgents')
LAUNCHAGENT_DEST_FILE = File.join(LAUNCHAGENT_DEST_DIR, "#{EXT_BUNDLE_ID}.plist")

DAEMON_SRC_FILENAME = 'dexd.rb'
DAEMON_SRC_FILE = File.join(SERVER_RELEASE_DIR, DAEMON_SRC_FILENAME)
DAEMON_DEST_DIR = ENV['PREFIX'] || "/usr/local/bin"
DAEMON_DEST_FILE = File.join(DAEMON_DEST_DIR, DEX_DAEMON)

RakeFileUtils.verbose(false)

# Load extension building stuff
load 'utils/helpers.rb'
load 'utils/build.rb'

def dex_running()
	return system("curl -k #{DEX_URL} &> /dev/null")
end

def launchd_worked(launch_output)
	if launch_output.strip!
		if launch_output.include? 'No such file'
			puts '✗ dex daemon is not installed'.console_red
		elsif launch_output.include? 'Already loaded'
			puts '✔ dex daemon is already running'.console_green
		elsif launch_output.include? 'Error unloading'
			puts '✗ dex daemon could not be stopped. Is it running?'.console_red
		elsif launch_output.include? 'no plist was returned for'
			puts '✗ launch agent file is blank'
		else
			puts '✗ launchctl error: '.console_red+launch_output.sub('launchctl: ','')
			exit 1
		end
		return false
	end
	return true
end

task :default => 'daemon:install'
task :release => ['extension:build_release', 'daemon:build']
task :dev => ['extension:build_dev', 'daemon:build']
task :runserver => ["daemon:stop", :dev] {system "ruby build/dexd.rb --verbose"}

namespace :daemon do
	desc 'Install dex daemon'
	task :install => [:preflight, :confirm_install, :install_daemon, :finish_install]

	desc 'Link dex daemon'
	task :link => [:preflight, :stop, :link_daemon, :finish_link]

	desc 'Build and install dex daemon'
	task :build_and_install => [:preflight, :confirm_install, :build, :install_daemon, :finish_install]

	desc 'Uninstall dex daemon'
	task :uninstall => [:preflight, :confirm_uninstall, :uninstall_daemon]

	desc 'Check permissions and create missing folders'
	task :preflight => :no_root do
		puts
		[DAEMON_DEST_DIR, LAUNCHAGENT_DEST_DIR, DEX_DIR].each do |folder|
			perms_issue = 0
			puts folder.console_bold.console_underline
			begin
				if !File.exists? folder
					puts '✗ Doesn’t exist.'.console_red, ''

					print "Create folder and set correct permissions? (y/n): "
				else
					puts '✔ Exists'.console_green
				end

				stat = File.stat(folder)

				if !stat.owned?
					perms_issue += 1
					puts '✗ Not owned by user'.console_red
				else
					puts '✔ Owned by user'.console_green
				end

				if !stat.writable?
					perms_issue += 1
					puts '✗ Not writable'.console_red
				else
					puts '✔ Writable'.console_green
				end

				if !stat.executable?
					perms_issue += 1
					puts '✗ Not executable'.console_red
				else
					puts '✔ Executable'.console_green
				end

				if perms_issue > 1
					puts
					print "Fix folder permissions? (y/n): "
					raise
				end
			rescue
				if $stdin.gets.chomp.downcase =~ /y/
					system "sudo mkdir -p #{folder}"
					system "sudo chown -R #{ENV['USER']} #{folder}"
					chmod 0755, folder
					puts '✔ Problems fixed'.console_green
				else
					# Don’t continue
					puts
					exit 1
				end
			end
			puts
		end
	end

	task :confirm_install => :no_root do
		puts "Install #{EXT_DISPLAY_NAME} #{@ext_version}".console_bold.console_underline

		puts "• "+DEX_DAEMON.console_bold+" will be installed in "+DAEMON_DEST_DIR.console_bold+"."
		puts "• "+"#{EXT_BUNDLE_ID}.plist".console_bold+" will be installed in "+LAUNCHAGENT_DEST_DIR.console_bold+"."
		puts "• "+DEX_DIR.console_bold+" will be created." if !File.exist? DEX_DIR

		if File.exist?(LAUNCHAGENT_DEST_FILE) or File.exist?(DAEMON_DEST_FILE)
			puts '• The existing installation of dex will be removed.'
			if File.exist?(DEX_DIR)
				puts '• '+DEX_DIR.console_bold+' will not be touched.'
			end
		end

		puts

		print "Ok? (y/n): "

		begin
			if answer = $stdin.gets.chomp.downcase =~ /y/
				puts
			else
				# raise Interrupt
				puts 'See ya.',''
				exit 1
			end
		rescue Interrupt
			puts '','See ya.',''
			exit 1
		end
	end

	desc "Build dex daemon to #{SERVER_RELEASE_DIR}"
	task :build do
		puts "Building dex daemon to #{SERVER_RELEASE_DIR}".console_underline
		erb_crunch(DAEMON_SRC_FILENAME, SERVER_SOURCE_DIR, SERVER_RELEASE_DIR)
		puts
	end

	task :quick_uninstall => [:stop] do
		if File.exist?(LAUNCHAGENT_DEST_FILE) or File.exist?(DAEMON_DEST_FILE)
			rm LAUNCHAGENT_DEST_FILE, :force => true
			rm DAEMON_DEST_FILE, :force => true
			puts "✔ Removed existing dex files"
		end
	end

	task :link_daemon => [:quick_uninstall, :rebuild_files] do
		# Copy latest launchagent.xml
		cp LAUNCHAGENT_SRC_FILE, LAUNCHAGENT_DEST_FILE, :preserve => true
		# Link daemon from TEMP_DIR
		ln_s File.expand_path(DAEMON_SRC_FILE), DAEMON_DEST_FILE
		# Make sure daemon is executable
		chmod 0755, DAEMON_SRC_FILE
		puts "✔ Linked dex daemon"
	end

	task :install_daemon => [:quick_uninstall, :rebuild_files] do
		cp LAUNCHAGENT_SRC_FILE, LAUNCHAGENT_DEST_FILE, :preserve => true
		cp DAEMON_SRC_FILE, DAEMON_DEST_FILE, :preserve => true
		chmod 0755, DAEMON_DEST_FILE
		puts "✔ Copied dex daemon files"
	end

	task :finish_link => [:start,:set_daemon_permissions] do
		puts
		if dex_running()
			puts "✔ dex daemon link complete!".console_green
			puts "If you haven’t already, open #{DEX_URL.console_bold} in your browser to enable SSL."
		else
			puts "✗ dex daemon link failed".console_red
			puts 'Gosh, uh… this is awkward. I wish I knew what to tell you.'
		end
		puts
	end

	task :finish_install => [:start,:set_daemon_permissions] do
		if dex_running()
			puts '', "✔ dex daemon installation complete!".console_green
			puts "If you haven’t already, open #{DEX_URL.console_bold} in your browser to enable SSL.", ''
		else
			puts '', "✗ dex daemon installation failed".console_red
			puts 'Gosh, uh… this is awkward. I wish I knew what to tell you.'
		end
	end

	task :confirm_uninstall => :no_root do
		puts "Uninstall #{EXT_DISPLAY_NAME} #{@ext_version}".console_underline

		puts "• "+DEX_DAEMON.console_bold+" will be removed from "+DAEMON_DEST_DIR.console_bold+"."
		puts "• "+"#{EXT_BUNDLE_ID}.plist".console_bold+" will be removed from "+LAUNCHAGENT_DEST_DIR.console_bold+"."
		puts "• "+DEX_DIR.console_bold+" will remain intact." if File.exist? DEX_DIR
		puts "• Browser extensions will need to be manually removed.", ''

		print 'Ok? (y/n): '

		begin
			if answer = $stdin.gets.chomp.downcase =~ /y/
				puts
			else
				# raise Interrupt
				puts 'See ya.',''
				exit 1
			end
		rescue Interrupt
			puts '','See ya.',''
			exit 1
		end
	end

	task :uninstall_daemon => :stop do
		not_installed = 0

		if File.exist?(LAUNCHAGENT_DEST_FILE)
			rm LAUNCHAGENT_DEST_FILE
			puts "✔ Removed "+LAUNCHAGENT_DEST_FILE.console_bold
		else
			puts "✗ #{LAUNCHAGENT_DEST_FILE.console_bold} does not exist"
			++not_installed
		end

		if File.exist?(DAEMON_DEST_FILE)
			rm DAEMON_DEST_FILE
			puts "✔ Removed "+DAEMON_DEST_FILE.console_bold
		else
			puts "✗ #{DAEMON_DEST_FILE.console_bold} does not exist"
			++not_installed
		end

		puts

		if not_installed > 0
			puts "✔ Successfully cleaned up dex remnants!".console_green
		else
			puts "✔ Successfully uninstalled dex daemon!".console_green
		end

		puts "Your #{DEX_DIR} folder was not touched.",''
	end

	desc 'Stop dex daemon'
	task :stop => [:no_root] do
		if launchd_worked(`launchctl unload -w #{LAUNCHAGENT_DEST_FILE} 2>&1`)
			puts "✔ Stopped dex daemon"
		end
	end

	desc 'Start dex daemon'
	task :start => [:no_root, :require_daemon_install] do
		if launchd_worked(`launchctl load -w #{LAUNCHAGENT_DEST_FILE} 2>&1`)
			sleep 1
			puts "✔ Started dex daemon"
		end
	end

	# Utilities
	task :set_daemon_permissions do
		chmod 0644, LAUNCHAGENT_DEST_FILE
		chmod 0755, DAEMON_DEST_FILE
	end

	task :require_daemon_install do
		if !File.exist?(DAEMON_DEST_FILE) and !File.exist?(LAUNCHAGENT_DEST_FILE)
			puts "✗ Existing dex installation was not found".console_red
			exit 1
		elsif !File.exist?(DAEMON_DEST_FILE) or !File.exist?(LAUNCHAGENT_DEST_FILE)
			puts 'Incomplete dex installation found. Run daemon:install to fix.'.console_red
			exit 1
		end
	end

	task :rebuild_files do
		puts "✔ Built launch agent source file"
		erb_crunch(LAUNCHAGENT_SRC_FILENAME, SERVER_SOURCE_DIR, SERVER_RELEASE_DIR)

		puts "✔ Built dex daemon source file"
		erb_crunch(DAEMON_SRC_FILENAME, SERVER_SOURCE_DIR, SERVER_RELEASE_DIR)
	end

	task :no_root do
		if Process.uid == 0
			abort '✗ '+Rake.application.top_level_tasks[0].console_bold+' cannot be run as root'
		end
	end
end