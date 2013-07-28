#!/bin/env ruby
# encoding: utf-8

EXT_NAME = 'dex'

EXT_DISPLAY_NAME = 'Dex'
EXT_DESC = IO.read('./source/extension/description.txt')
EXT_URL = 'https://github.com/meyer/dex'
EXT_AUTHOR = 'Mike Meyer'
EXT_BUNDLE_ID = 'fm.meyer.dex'
EXT_FILES = ['jquery.js','main.coffee']
EXT_WHITELIST = ['http://*/*','https://*/*']
EXT_ICONS = [48,128]

@ext_version = [
	`cat "./source/version.txt"`, # Hard-coded version…
	`git rev-list HEAD | wc -l | xargs -n1 printf %d` # …plus git commit number
].join('.')

EXT_SOURCE_DIR = './source/extension'
EXT_CERT_DIR = '../certificates'
EXT_BUILD_PREFIX = "#{EXT_NAME}-#{@ext_version}"
EXT_RELEASE_DIR = './bin'

TEMP_DIR = './temp'

# Server Config
DEX_DIR = File.join(ENV['HOME'], '.dex/')
DEX_PORT = 3131
DEX_DAEMON = 'dexd'

SERVER_SOURCE_DIR = './source'
SERVER_RELEASE_DIR = './bin'

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
	return system("curl -k https://localhost:#{DEX_PORT} &> /dev/null")
end

def launchd_worked(launch_output)
	if launch_output.strip!
		# puts 'launchctl error: '.console_red+launch_output
		if launch_output.include? 'No such file'
			puts '✗ dex daemon is not installed'
		end
		return false
	end
	return true
end

task :default => 'daemon:install'

namespace :daemon do
	desc 'Install dex daemon'
	task :install => [:preflight, :confirm_install, :install_daemon, :finish_install]

	desc 'Build and install dex daemon'
	task :build_and_install => [:preflight, :confirm_install, :build, :install_daemon, :finish_install]

	desc 'Uninstall dex daemon'
	task :uninstall => [:preflight, :confirm_uninstall, :uninstall_daemon]

	desc 'Check permissions and create missing folders'
	task :preflight => :no_root do
		puts
		[DAEMON_DEST_DIR, LAUNCHAGENT_DEST_DIR].each do |folder|
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
		puts '',"Building dex daemon to #{SERVER_RELEASE_DIR}".console_underline.console_bold
		erb_crunch(LAUNCHAGENT_SRC_FILENAME, SERVER_SOURCE_DIR, SERVER_RELEASE_DIR)
		erb_crunch(DAEMON_SRC_FILENAME, SERVER_SOURCE_DIR, SERVER_RELEASE_DIR)
		puts
	end

	task :link_daemon => :server_files_exist do
		ln_s LAUNCHAGENT_SRC_FILE, LAUNCHAGENT_DEST_FILE
		ln_s DAEMON_SRC_FILE, DAEMON_DEST_FILE
	end

	task :install_daemon => [:stop, :server_files_exist] do
		# Quick uninstall
		if File.exist?(LAUNCHAGENT_DEST_FILE) or File.exist?(DAEMON_DEST_FILE)
			rm LAUNCHAGENT_DEST_FILE, :force => true
			rm DAEMON_DEST_FILE, :force => true
			puts "✔ Removed existing dex install"
		end

		cp LAUNCHAGENT_SRC_FILE, LAUNCHAGENT_DEST_FILE, :preserve => true
		cp DAEMON_SRC_FILE, DAEMON_DEST_FILE, :preserve => true
		puts "✔ Copied dex daemon files"
	end

	task :finish_install => [:start,:set_daemon_permissions] do
		mkdir_p DEX_DIR
		chmod 0755, DEX_DIR

		if dex_running()
			puts '', "✔ dex daemon installation complete!".console_green
			puts "Open https://localhost:#{DEX_PORT} in your browser to enable SSL", ''
		else
			puts '', "✗ dex daemon installation failed".console_red
			puts 'Gosh, uh… this is awkward. I wish I knew what to tell you.'
		end
	end

	task :confirm_uninstall => :no_root do
		puts "Uninstall #{EXT_DISPLAY_NAME} #{@ext_version}".console_bold.console_underline

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
			++not_installed
		end

		if File.exist?(DAEMON_DEST_FILE)
			rm DAEMON_DEST_FILE
			puts "✔ Removed "+DAEMON_DEST_FILE.console_bold
		else
			++not_installed
		end

		if not_installed > 0
			puts "✔ Successfully cleaned up dex remnants.".console_green
		else
			puts "✔ Successfully uninstalled dex daemon.".console_green
		end

		puts "• Your #{DEX_DIR} folder was not touched.",''
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
			puts "✔ Started dex daemon"
			sleep 2
		end
	end

	# Utilities
	task :set_daemon_permissions do
		chmod 0644, LAUNCHAGENT_DEST_FILE
		chmod 0755, DAEMON_DEST_FILE
	end

	task :require_daemon_install do
		if !File.exist?(DAEMON_DEST_FILE) and !File.exist?(LAUNCHAGENT_DEST_FILE)
			puts "✗ dex daemon is not installed".console_red
			exit 1
		elsif !File.exist?(DAEMON_DEST_FILE) or !File.exist?(LAUNCHAGENT_DEST_FILE)
			puts 'Incomplete dex installation found. Run daemon:install to fix.'.console_red
			exit 1
		end
	end

	task :server_files_exist do
		if !File.exist?(DAEMON_SRC_FILE) or !File.exist?(LAUNCHAGENT_SRC_FILE)
			puts '✗ dex daemon files haven’t been built! Run rake daemon:build.'.console_red,''
			exit 1
		end
	end

	task :no_root do
		if Process.uid == 0
			abort '✗ '+Rake.application.top_level_tasks[0].console_bold+' cannot be run as root'
		end
	end
end