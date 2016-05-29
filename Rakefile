require 'json'

PROJECT_DIR = File.dirname(__FILE__)

PKG_FILE = File.expand_path("./package.json", PROJECT_DIR)
PKG = JSON.parse(File.read(PKG_FILE))
BUILD_DIR = File.expand_path("build", PROJECT_DIR)

ENV["DEX_URL"] = "https://#{PKG["dex"]["host"]}:#{PKG["dex"]["port"]}"

def update_env
  ENV["NODE_ENV"] ||= "production"
  # regex strips off semver shit
  ENV["DEX_VERSION"] = "#{PKG["version"][/^\d+\.\d+\.\d+/]}.#{PKG["build"] - PKG["last_release"]}"
end

update_env

namespace :ext do
  load File.join(PROJECT_DIR, "extension/tasks.rake")
end

namespace :daemon do
  load File.join(PROJECT_DIR, "daemon/tasks.rake")
end

def update_pkg
  File.open(PKG_FILE, "w") {|f| f.puts(JSON.pretty_generate(PKG))}
end

task :set_dev_env do
  ENV["NODE_ENV"] = "development"
  PKG["build"] += 1
  update_pkg
  update_env
end

task :ask_for_new_version_number do
  ENV["NODE_ENV"] = "production"
  update_env

  puts "Current #{PKG["name"]} version: #{PKG["version"]}"
  print "New #{PKG["name"]} version: "
  new_version = STDIN.gets.chomp!

  if /\d+\.\d+\.\d+/.match(new_version)
    old_version_comp = Integer(PKG["version"].gsub(/\./, "000"))
    new_version_comp = Integer(new_version.gsub(/\./, "000"))
    if new_version_comp > old_version_comp
      puts "good"
      PKG["version"] = new_version
      PKG["last_release"] = PKG["build"]
      update_pkg
      update_env
    else
      puts "Error: new version number must be greater than #{PKG["version"]}"
    end
  else
    puts "Error: invalid version number!"
  end
end

task :build => [:set_dev_env, "ext:chrome:build", "daemon:build"]

task :release => [
  :ask_for_new_version_number,
  "ext:chrome:build",
  "ext:chrome:pack",
  "daemon:build"
]
