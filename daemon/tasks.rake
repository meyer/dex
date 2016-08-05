require "json"
require "shellwords"
require "tmpdir"

DAEMON_DIR = File.dirname(__FILE__)
CERT_DIR = File.expand_path("/usr/local/var/dexd")

def ldflags
  dexVersion = ENV["DEX_VERSION"]
  if ENV["NODE_ENV"] == "development"
    dexVersion = "#{dexVersion}.#{}"
  end
  {
    "dexVersion" => ENV["DEX_VERSION"],
    "dexPort" => ":#{PKG["dex"]["port"]}",
  }.map {|k,v| "-X main.#{k}=#{v}"}.join(" ")
end

task :pre_daemon do
  Dir.chdir DAEMON_DIR
end

desc "Build dexd binary"
task :build => ["build:osx", "build:win"]

namespace :build do
  task :osx => [:pre_daemon] do
    daemon_dest_osx = File.join(BUILD_DIR, "dexd")
    puts "Building OSX binary..."
    system "go build -o #{daemon_dest_osx.shellescape} -ldflags \"#{ldflags}\" *.go"
  end

  task :win => [:pre_daemon] do
    daemon_dest_win = File.join(BUILD_DIR, "dexd.exe")
    puts "Building Windows binary..."
    system "GOOS=windows GOARCH=386 go build -o #{daemon_dest_win.shellescape} -ldflags \"#{ldflags}\" *.go"
  end
end

desc "Run dexd from source"
task :run => [:increment_build_number, :print_info_header, :pre_daemon] do
  system "go run -ldflags \"#{ldflags}\" *.go -v=2 -logtostderr=true -cert_dir=#{CERT_DIR.shellescape}"
end

desc "Run dexd from source"
task :run_overwrite => [:increment_build_number, :print_info_header, :pre_daemon] do
  tmp_dir = Dir.mktmpdir("dex")
  system "go run -ldflags \"#{ldflags}\" *.go -v=2 -logtostderr=true -overwrite -cert_dir=#{tmp_dir.shellescape}"
end
