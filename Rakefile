#!/usr/bin/env ruby
# encoding: utf-8

EXT_NAME = "dex"
EXT_VERSION = "1.0.1"

EXT_DISPLAY_NAME = "Dex"
EXT_DESC = IO.read("./source/extension/description.txt")
EXT_URL = "https://github.com/meyer/dex"
EXT_AUTHOR = "Mike Meyer"
EXT_BUNDLE_ID = "fm.meyer.dex"
EXT_CONTENT_SCRIPTS = ["main.coffee"]

# safari.extension.baseURI + "filename"
# chrome.extension.getURL("filename")
EXT_EXTRA_RESOURCES = ["dex.coffee","utils.coffee","lodash.min.js"]

EXT_BACKGROUND_PAGE = true
EXT_POPOVER_MENU = true

EXT_WHITELIST = ["http://*/*","https://*/*"]
EXT_ICONS = [32,48,64,96,128]
EXT_SAFARI_DEV_ID = "7ZCMA49A25"
EXT_SAFARI_UPDATE_URL = "https://raw.github.com/meyer/dex/master/extensions/dex-#{EXT_VERSION}.safariextz"
EXT_SAFARI_UPDATE_MANIFEST_URL = "https://raw.github.com/meyer/dex/master/extensions/safari-update-manifest.plist"

EXT_SOURCE_DIR = "./source/extension"
EXT_CERT_DIR = "../certificates"
EXT_RELEASE_DIR = "./extensions"

TEMP_DIR = "./build"

%w(INT TERM).each {|s| trap(s){puts "\ntake care out there \u{1f44b}"; abort}}

# Don’t increment version number unless a running a task
# TODO: Make this more awesome.
unless Rake.application.top_level_tasks == ["default"]
	# Stolen from http://www.ruby-doc.org/core-2.0.0/File.html#method-i-flock
	File.open("./source/build.txt", File::RDWR|File::CREAT, 0644) {|f|
		f.flock(File::LOCK_EX)
		EXT_BUILD_NUMBER = (f.read.to_i + 1)
		f.rewind
		f.write EXT_BUILD_NUMBER
		f.flush
		f.truncate(f.pos)
	}
end

# Server Config
DEX_DIR = File.join(ENV["HOME"], ".dex/")
DEX_PORT = 3131
DEX_DAEMON = "dexd"
DEX_HOSTNAME = "localhost"

DEX_URL = "https://#{DEX_HOSTNAME}:#{DEX_PORT}"

SERVER_SOURCE_DIR = "./source"
SERVER_RELEASE_DIR = TEMP_DIR

LAUNCHAGENT_SRC_FILENAME = "launchagent.xml"
LAUNCHAGENT_SRC_FILE = File.join(SERVER_RELEASE_DIR, LAUNCHAGENT_SRC_FILENAME)
LAUNCHAGENT_DEST_DIR = File.expand_path("~/Library/LaunchAgents")
LAUNCHAGENT_DEST_FILE = File.join(LAUNCHAGENT_DEST_DIR, "#{EXT_BUNDLE_ID}.plist")

DAEMON_SRC_FILENAME = "dexd.rb"
DAEMON_SRC_FILE = File.join(SERVER_RELEASE_DIR, DAEMON_SRC_FILENAME)
DAEMON_DEST_DIR = ENV["PREFIX"] || "/usr/local/bin"
DAEMON_DEST_FILE = File.join(DAEMON_DEST_DIR, DEX_DAEMON)

RakeFileUtils.verbose(false)

# Load extension building stuff
load "utils/helpers.rb"
load "utils/build.rb"

def dex_running()
	return system("curl -k #{DEX_URL} &> /dev/null")
end

def a_to_s(*a_or_s)
	if a_or_s.kind_of?(Array)
		a_or_s.join("\n")
	else
		a_or_s
	end
end

def nap; sleep(0.04); end
def puts_y(*msg) puts "✔ #{a_to_s msg}".console_green; nap; end
def print_y(*msg) print "✔ #{a_to_s msg}".console_green; nap; end
def puts_n(*msg) puts "✗ #{a_to_s msg}".console_red; nap; end
def puts_b(*msg) puts "• #{a_to_s msg}"; nap; end

def launchd_worked(launch_output)
	if launch_output.strip!
		if launch_output.include? "No such file"
			puts_n "dex daemon is not installed"
		elsif launch_output.include? "Already loaded"
			puts_y "dex daemon is already running"
		elsif launch_output.include? "Error unloading"
			puts_n "dex daemon could not be stopped."
		elsif launch_output.include? "Could not find specified service"
			puts_y "dex daemon is not running"
		elsif launch_output.include? "no plist was returned for"
			puts_n "launch agent file is blank"
		else
			puts "launchctl error: ".console_red+launch_output.sub("launchctl: ","")
			exit 1
		end
		return false
	end
	return true
end

# Gross.
task :default do
	system "rake -T"
end

task :release => ["extension:build_release", "daemon:build"]
task :dev => ["extension:build_dev", "daemon:build"]

desc "Compile and run the latest daemon"
task :runserver => ["daemon:stop", :dev] do
	system "ruby build/dexd.rb --verbose 2>/dev/null"
end

namespace :daemon do
	desc "Install dex daemon"
	task :install => [:preflight, :confirm_install, :install_daemon, :finish_setup]

	desc "Link dex daemon"
	task :link => [:preflight, :stop, :link_daemon, :finish_setup]

	desc "Build and install dex daemon"
	task :build_and_install => [:preflight, :confirm_install, :build, :install_daemon, :finish_setup]

	desc "Uninstall dex daemon"
	task :uninstall => [:preflight, :confirm_uninstall, :uninstall_daemon]

	desc "Check permissions and create missing folders"
	task :preflight => :no_root do
		puts
		[DAEMON_DEST_DIR, LAUNCHAGENT_DEST_DIR, DEX_DIR].each do |folder|
			perms_issue = 0
			puts folder.console_bold.console_underline
			begin
				unless File.exists? folder
					puts_n "Doesn’t exist.", ""
					print "Create folder and set correct permissions? (y/n): "
				else
					puts_y "Exists"
				end

				stat = File.stat(folder)

				if !stat.owned?
					perms_issue += 1
					puts_n "Not owned by user"
				else
					puts_y "Owned by user"
				end

				if !stat.writable?
					perms_issue += 1
					puts_n "Not writable"
				else
					puts_y "Writable"
				end

				if !stat.executable?
					perms_issue += 1
					puts_n "Not executable"
				else
					puts_y "Executable"
				end

				if perms_issue > 1
					puts
					print "Fix folder permissions? (y/n): "
					raise
				end
			rescue
				if $stdin.gets.chomp.downcase =~ /y/
					system "sudo mkdir -p #{folder}"
					system "sudo chown -R #{ENV["USER"]} #{folder}"
					chmod 0755, folder
					puts_y "Problems fixed"
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

		puts_b DEX_DAEMON.console_bold+" will be installed in "+DAEMON_DEST_DIR.console_bold+"."
		puts_b "#{EXT_BUNDLE_ID}.plist".console_bold+" will be installed in "+LAUNCHAGENT_DEST_DIR.console_bold+"."
		puts_b DEX_DIR.console_bold+" will be created." if !File.exist? DEX_DIR

		if File.exist?(LAUNCHAGENT_DEST_FILE) or File.exist?(DAEMON_DEST_FILE)
			puts_b "The existing installation of dex will be removed."
			if File.exist?(DEX_DIR)
				puts_b DEX_DIR.console_bold+" will not be touched."
			end
		end

		puts

		print "Ok? (y/n): "

		begin
			if answer = $stdin.gets.chomp.downcase =~ /y/
				puts
			else
				# raise Interrupt
				puts "See ya.",""
				exit 1
			end
		rescue Interrupt
			puts "","See ya.",""
			exit 1
		end
	end

	desc "Build dex daemon to #{SERVER_RELEASE_DIR}"
	task :build do
		puts "Building dex daemon to #{SERVER_RELEASE_DIR}".console_underline
		ext_copy_file(DAEMON_SRC_FILENAME, SERVER_SOURCE_DIR, SERVER_RELEASE_DIR, with_erb: true)
		puts
	end

	task :quick_uninstall => [:stop] do
		if File.exist?(LAUNCHAGENT_DEST_FILE) or File.exist?(DAEMON_DEST_FILE)
			rm LAUNCHAGENT_DEST_FILE, :force => true
			rm DAEMON_DEST_FILE, :force => true
			puts_y "Removed existing dex files"
		end
	end

	task :link_daemon => [:quick_uninstall, :rebuild_files] do
		# Copy latest launchagent.xml
		cp LAUNCHAGENT_SRC_FILE, LAUNCHAGENT_DEST_FILE, :preserve => true
		# Link daemon from TEMP_DIR
		ln_s File.expand_path(DAEMON_SRC_FILE), DAEMON_DEST_FILE
		# Make sure daemon is executable
		chmod 0755, DAEMON_SRC_FILE
		puts_y "Linked dex daemon"
	end

	task :install_daemon => [:quick_uninstall, :rebuild_files] do
		cp LAUNCHAGENT_SRC_FILE, LAUNCHAGENT_DEST_FILE, :preserve => true
		cp DAEMON_SRC_FILE, DAEMON_DEST_FILE, :preserve => true
		chmod 0755, DAEMON_DEST_FILE
		puts_y "Copied dex daemon files"
	end

	task :finish_setup => [:start, :set_daemon_permissions] do
		puts
		puts_y "Installation complete!"
		puts "If you haven’t already, open #{DEX_URL.console_bold} in your browser to enable SSL.", ""
	end

	task :confirm_uninstall => :no_root do
		puts "Uninstall #{EXT_DISPLAY_NAME} #{@ext_version}".console_underline

		puts "• "+DEX_DAEMON.console_bold+" will be removed from "+DAEMON_DEST_DIR.console_bold+"."
		puts "• "+"#{EXT_BUNDLE_ID}.plist".console_bold+" will be removed from "+LAUNCHAGENT_DEST_DIR.console_bold+"."
		puts "• "+DEX_DIR.console_bold+" will remain intact." if File.exist? DEX_DIR
		puts "• Browser extensions will need to be manually removed.", ""

		print "Ok? (y/n): "

		begin
			if answer = $stdin.gets.chomp.downcase =~ /y/
				puts
			else
				# raise Interrupt
				puts "See ya.",""
				exit 1
			end
		rescue Interrupt
			puts "","See ya.",""
			exit 1
		end
	end

	task :uninstall_daemon => :stop do
		not_installed = 0

		if File.exist?(LAUNCHAGENT_DEST_FILE)
			rm LAUNCHAGENT_DEST_FILE
			puts_y "Removed "+LAUNCHAGENT_DEST_FILE.console_bold
		else
			puts_n "#{LAUNCHAGENT_DEST_FILE.console_bold} does not exist"
			++not_installed
		end

		if File.exist?(DAEMON_DEST_FILE)
			rm DAEMON_DEST_FILE
			puts_y "Removed "+DAEMON_DEST_FILE.console_bold
		else
			puts_n "#{DAEMON_DEST_FILE.console_bold} does not exist"
			++not_installed
		end

		puts

		if not_installed > 0
			puts_y "Successfully cleaned up dex remnants!"
		else
			puts_y "Successfully uninstalled dex daemon!"
		end

		puts "Your #{DEX_DIR} folder was not touched.",""
	end

	desc "Stop dex daemon"
	task :stop => [:no_root] do
		if launchd_worked(`launchctl unload -w #{LAUNCHAGENT_DEST_FILE} 2>&1`)
			if dex_running()
				puts_n "Could not stop dex daemon"
			else
				puts_y "Stopped dex daemon"
			end
		end
	end

	desc "Start dex daemon"
	task :start => [:no_root, :require_daemon_install] do
		if launchd_worked(`launchctl load -w #{LAUNCHAGENT_DEST_FILE} 2>&1`)

			msg = "Starting dex daemon..."
			print "#{msg}\r"

			i = 0

			# Max wait time in seconds (takes about 12 on my rMBP)
			maxWaitTime = 20
			fps = 2

			# TODO: Hide the cursor, maybe with curses?
			# http://rosettacode.org/wiki/Terminal_control/Hiding_the_cursor#Ruby

			until dex_running()
				break if (i += 1) >= (maxWaitTime * fps)
				# msg += "."
				print "#{"+x"[i % 2]} #{msg}\r"
				sleep (1.0 / fps)
			end

			# Clear old line
			print "#{" " * (msg.length + 4)}\r"

			if dex_running()
				puts_y "Started dex daemon"
			else
				puts_n "Attempt to start dex daemon failed"
			end

		end
	end

	# Utilities
	task :set_daemon_permissions do
		chmod 0644, LAUNCHAGENT_DEST_FILE
		chmod 0755, DAEMON_DEST_FILE
	end

	task :require_daemon_install do
		if !File.exist?(DAEMON_DEST_FILE) and !File.exist?(LAUNCHAGENT_DEST_FILE)
			puts_n "Existing dex installation was not found"
			exit 1
		elsif !File.exist?(DAEMON_DEST_FILE) or !File.exist?(LAUNCHAGENT_DEST_FILE)
			puts_n "Incomplete dex installation found. Run daemon:install to fix."
			exit 1
		end
	end

	task :rebuild_files do
		puts_y "Built launch agent source file"
		ext_copy_file(LAUNCHAGENT_SRC_FILENAME, SERVER_SOURCE_DIR, SERVER_RELEASE_DIR, with_erb: true)

		puts_y "Built dex daemon source file"
		ext_copy_file(DAEMON_SRC_FILENAME, SERVER_SOURCE_DIR, SERVER_RELEASE_DIR, with_erb: true)
	end

	task :no_root do
		if Process.uid == 0
			puts_n Rake.application.top_level_tasks[0].console_bold+" cannot be run as root"
			exit 1
		end
	end
end