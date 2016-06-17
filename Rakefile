require 'json'
require 'shellwords'

PROJECT_DIR = File.dirname(__FILE__)

PKG_FILE = File.expand_path("./package.json", PROJECT_DIR)
PKG = JSON.parse(File.read(PKG_FILE))
BUILD_DIR = File.expand_path("build", PROJECT_DIR)

ENV["DEX_URL"] = "https://#{PKG["dex"]["host"]}:#{PKG["dex"]["port"]}"
ENV["NODE_ENV"] ||= "development"

def update_version
  ENV["DEX_VERSION"] = "#{PKG["version"][/^\d+\.\d+\.\d+/]}.#{PKG["build"] - PKG["last_release"]}"
end
update_version

def update_pkg
  File.open(PKG_FILE, "w") {|f| f.puts(JSON.pretty_generate(PKG))}
end

namespace :ext do
  load File.join(PROJECT_DIR, "extension/tasks.rake")
end

namespace :daemon do
  load File.join(PROJECT_DIR, "daemon/tasks.rake")
end

task :set_dev_env do
  $env_set = true
  ENV["NODE_ENV"] = "development"
  PKG["build"] += 1

  update_pkg
  update_version
end

task :set_prod_env do
  $env_set = true
  ENV["NODE_ENV"] = "production"
  PKG["build"] += 1
  PKG["last_release"] = PKG["build"]

  update_pkg
  update_version
end

task :env_warn => [:print_info_header] do
  if !$env_set
    puts "Ayyyy, env methods haven't been set. Build number will not be incremented."
  end
end

task :print_info_header do
  puts "NODE_ENV:    #{ENV["NODE_ENV"]}"
  puts "DEX_VERSION: #{ENV["DEX_VERSION"]} (#{PKG["version"]})"
end

task :build => [
  :set_dev_env,
  :print_info_header,
  "ext:chrome:build",
  "ext:chrome:zip",
  "daemon:build",
]

task :release => [
  :set_prod_env,
  :print_info_header,
  "ext:chrome:build",
  "ext:chrome:zip",
  "daemon:build",
]
