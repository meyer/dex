#!/usr/bin/env ruby
# encoding: utf-8

EXT_NAME = "dex"
EXT_VERSION = "1.0.1"

EXT_DISPLAY_NAME = "Dex"
EXT_DESC = IO.read("./source/extension/description.txt")
EXT_URL = "https://github.com/meyer/dex-extension"
EXT_AUTHOR = "Mike Meyer"
EXT_BUNDLE_ID = "com.meyermade.dex"
EXT_CONTENT_SCRIPTS = ["main.coffee"]

# safari.extension.baseURI + "filename"
# chrome.extension.getURL("filename")
EXT_EXTRA_RESOURCES = ["dex.coffee","utils.coffee","lodash.min.js"]

EXT_BACKGROUND_PAGE = true
EXT_POPOVER_MENU = true

EXT_WHITELIST = ["http://*/*","https://*/*"]
EXT_ICONS = [32,48,64,96,128]
EXT_SAFARI_DEV_ID = "7ZCMA49A25"
EXT_SAFARI_UPDATE_URL = "https://raw.github.com/meyer/dex-extension/master/extensions/dex-#{EXT_VERSION}.safariextz"
EXT_SAFARI_UPDATE_MANIFEST_URL = "https://raw.github.com/meyer/dex-extension/master/extensions/safari-update-manifest.plist"

EXT_SOURCE_DIR = "./source/extension"
EXT_CERT_DIR = "../certificates"
EXT_RELEASE_DIR = "./extensions"

TEMP_DIR = "./build"

%w(INT TERM).each {|s| trap(s){puts "\ntake care out there \u{1f44b}"; abort}}

DEX_URL = "https://localhost:3131"

RakeFileUtils.verbose(false)

# Load extension building stuff
load "utils/helpers.rb"
load "utils/build.rb"

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

task :increment_build_number do
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

task :default => [:increment_build_number, "extension:build_dev"]