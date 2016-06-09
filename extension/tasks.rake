require 'shellwords'
require 'json'

EXT_DIR = File.dirname(__FILE__)

EXT_BUILD_DIR = File.join(BUILD_DIR, "extension-temp")

task :pre_ext do
  puts "NODE_ENV: #{ENV["NODE_ENV"]}"
  Dir.chdir EXT_DIR
end

task :reset => [:pre_ext] do
  puts "Resetting build directory..."
  rm_rf BUILD_DIR
  mkdir_p File.join(EXT_BUILD_DIR, "popover")
end

task :generate_popover => [:pre_ext, :reset] do
  if ENV["DEX_ENABLE_HOT_RELOADING"]
    puts "Generating skeleton index.html..."
    puts "(Don't forget to run `npm run rwb serve`)"
    File.open(File.join(EXT_BUILD_DIR, "popover/index.html"), "w") { |f|
      f.write <<-WOW
<!doctype html>
<meta charset="utf-8">
<title>rwb</title>
<div id="#{PKG["rwb"]["dom_node"][1..-1]}"></div>
<script src="http://localhost:3000/bundle.js"></script>
    WOW
    }
  else
    puts "Generating popover with rwb..."
    system(["npm", "run", "rwb", "static", File.join(EXT_BUILD_DIR, "popover")].shelljoin)
  end
end

namespace :chrome do
  desc "Build extension for Google Chrome"
  task :build => [:generate_popover, :webpack, :copy_assets, "chrome:update_manifest"]

  task :zip => [:pre_ext] do
    Dir.chdir BUILD_DIR
    system "zip -r extension-temp.zip extension-temp"
  end

  task :update_manifest => [:pre_ext] do
    puts "Generating manifest.json..."

    # TODO: maybe just load config.js?
    manifest = JSON.parse(`node -e "console.log(JSON.stringify(require('./lib/manifest.js'), null, '  '))"`)
    manifest["web_accessible_resources"] = Dir.glob(File.join(EXT_BUILD_DIR, "popover/*.{css,js}")).map {|e| e.sub(EXT_BUILD_DIR, "")}

    File.open(File.join(EXT_BUILD_DIR, "manifest.json"), "w") {|f| f.write(JSON.pretty_generate(manifest))}
  end
end

task :copy_assets => [:pre_ext] do
  cp_r "./assets", EXT_BUILD_DIR
end

task :webpack => [:pre_ext] do
  Dir.glob("./*.js").reject {|f| File.basename(f).start_with? "_"}.each do |jsFile|
    basename = File.basename(jsFile)

    src_file = File.join(EXT_DIR, jsFile)
    dest_file = File.join(EXT_BUILD_DIR, basename)

    puts "Bundling '#{jsFile}' with webpack..."
    unless system(["npm", "run", "webpack", src_file, dest_file].shelljoin)
      puts "Error running webpack for '#{jsFile}'"
    end
  end
end
