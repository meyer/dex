#!/usr/bin/env ruby
# encoding: utf-8

require 'shellwords'
require 'json'

RakeFileUtils.verbose(false)

WEBPACK = './node_modules/.bin/webpack'
RWB = './node_modules/.bin/rwb'
NODE_ENV = ENV['DEV_MODE'] ? 'development' : 'production'
puts "NODE_ENV: #{NODE_ENV}"

task :reset do
  puts 'Resetting build directory...'
  rm_rf 'build'
  mkdir_p 'build/popover'
end

task :rwb => [:reset] do
  puts 'Generating popover with rwb...'
  system({'NODE_ENV' => NODE_ENV}, [RWB, 'static', 'build/popover'].shelljoin)
end

namespace :chrome do
  task :update_manifest do
    puts 'Generating manifest.json...'

    # TODO: maybe just load config.js?
    manifest = JSON.parse(`node -e "console.log(JSON.stringify(require('./lib/manifest.js'), null, '  '))"`)
    manifest['web_accessible_resources'] = Dir.glob('build/popover/*.{css,js}').map {|e| e.sub('build/', '')}

    File.open('build/manifest.json', 'w') {|f| f.write(JSON.pretty_generate(manifest))}
  end
end

task :copy_assets do
  cp_r 'src/assets', 'build'
end

task :webpack do
  Dir.glob('src/*.js').reject {|f| File.basename(f).start_with? '_'}.each do |jsFile|
    puts "Bundling '#{jsFile}' with webpack..."
    basename = File.basename(jsFile)
    system({'NODE_ENV' => NODE_ENV}, [WEBPACK, jsFile, File.join('build', basename)].shelljoin)
  end
end

desc 'Build extension for Chrome'
task :build_chrome => [:rwb, :webpack, :copy_assets, 'chrome:update_manifest']

task :default => [:build_chrome]
