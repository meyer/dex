require "json"
require "shellwords"

DAEMON_DIR = File.dirname(__FILE__)
CERT_DIR = File.expand_path("/usr/local/var/dexd")

def ldflags
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
  task :osx => [:pre_daemon, :set_dev_env] do
    daemon_dest_osx = File.join(BUILD_DIR, "dexd")
    puts "Building OSX binary..."
    system "go build -o #{daemon_dest_osx.shellescape} -ldflags \"#{ldflags}\" *.go"
  end

  task :win => [:pre_daemon, :set_dev_env] do
    daemon_dest_win = File.join(BUILD_DIR, "dexd.exe")
    puts "Building Windows binary..."
    system "GOOS=windows GOARCH=386 go build -o #{daemon_dest_win.shellescape} -ldflags \"#{ldflags}\" *.go"
  end
end

desc "Run dexd from source"
task :run => [:pre_daemon, :set_dev_env] do
  system "go run -ldflags \"#{ldflags}\" *.go -v=2 -logtostderr=true -cert_dir=#{CERT_DIR.shellescape}"
end

desc "Compile ./ssl/ to ./ssl.go"
task :generate_assets => [:pre_daemon] do
  # go get -u github.com/jteeuwen/go-bindata/...
  system "$GOPATH/bin/go-bindata -o assets.go assets/"
end

desc "Generate SSL certs"
task :ssl => [:pre_daemon] do
  system [
    "go",
    "run",
    "$(go env GOROOT)/src/crypto/tls/generate_cert.go",
    "-ca",
    "-start-date=\"Jan 1 00:00:00 2000\"",
    "-duration=#{69 * 24 * 365}h0m0s",
    "-host=\"localhost,127.0.0.1\"",
  ].shelljoin
end
