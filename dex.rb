#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'optparse'
require 'shellwords'
require 'time'
require 'webrick'
require 'webrick/https'
require 'yaml'

DEX_VERSION = '1.0.0'
DEX_CONFIG_FILE = File.expand_path('~/.dex-config.yaml')

# neato string utils
class String
  def console_red; colorise(self, "\e[31m"); end
  def console_green; colorise(self, "\e[32m"); end
  def console_grey; colorise(self, "\e[30m"); end
  def console_bold; colorise(self, "\e[1m"); end
  def console_underline; colorise(self, "\e[4m"); end
  def colorise(text, color_code)  "#{color_code}#{text}\e[0m" end
  def comment_out; indent(self, "# ").console_grey; end
  def indent(t,p); t.split("\n").map {|s| p+s}.join("\n"); end
  def indent_arrow; indent(self, "#{">".console_green} "); end
  def indent_timestamp; indent(self, "[#{Time.now.strftime("%H:%M:%S")}] "); end
end

launchagent_template = <<-WOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>%{label}</string>

    <key>KeepAlive</key>
    <true/>

    <key>ProgramArguments</key>
    <array>
      <string>%{script}</string>
    </array>

    <key>RunAtLoad</key>
    <true/>
  </dict>
</plist>
WOW

@default_config = {
  # defaults
  'port' => 3131,
  'hostname' => 'localhost',
  'dir' => '',

  # SASS/CoffeeScript compile commands
  # Set to false/nil to disable
  'compile-sass' => 'node-sass %{file}',
  'compile-scss' => 'node-sass %{file}',
  'compile-coffee' => 'cat %{file} | coffee -sc'
}.freeze

$dex_config = @default_config.dup.merge YAML.load_file(DEX_CONFIG_FILE) || {} rescue {}

def yaml_header
  <<-HEADER
# Generated by Dex #{DEX_VERSION}
# #{Time.now.asctime}
  HEADER
end

def update_config(dict)
  puts "UPDATING CONFIG:\n#{dict.to_yaml}"
  File.open(DEX_CONFIG_FILE, 'w+') do |f|
    write_me = $dex_config.merge!(dict).delete_if {|k,v| @default_config[k] == v}
    f.write yaml_header + (write_me.empty? ? "---\n" : write_me.to_yaml)
  end
end

OptionParser.new do |opts|
  opts.separator "Starts dex server in the foreground. kill with <Control>C"

  opts.on('-d', '--dir [file]', 'Set path to dexfile directory') do |c|
    dex_dir = File.expand_path(c)
    # Expand symlink
    if File.exists? dex_dir
      dex_dir = File.realpath(dex_dir)
    end
    enabled_file = File.join(dex_dir, "enabled.yaml")
    unless File.exists? enabled_file
      puts "No 'enabled.yaml' file located at #{dex_dir}, creating...".comment_out
      FileUtils.touch enabled_file
    end
    update_config({'dir' => dex_dir})
    exit
  end

  opts.on(nil, '--install', 'Install launchagent') do |l|
    puts launchagent_template % {
      label: "fm.meyer.dex",
      script: File.expand_path(__FILE__)
    }
    exit
  end
end.parse!

Dir.chdir $dex_config['dir']

DEX_ENABLED_FILE = File.join($dex_config['dir'], 'enabled.yaml')

class DexSite
  def initialize(url)
    @dex_enabled = {
      'global' => [],
      @url => []
    }.merge YAML.load_file(DEX_ENABLED_FILE) || {} rescue {}

    @url = url
    domains = [@url]

    unless @url == 'global'
      @url.gsub!(/^ww[w\d]\./, '')
      domains = @url.split('.')
      domains.map!.with_index {|k,i| domains[i..-1].join('.')}.reverse!
      domains.unshift 'utilities'
    end

    @has_dexfiles = @dex_enabled.include? @url
    @available = Dir.glob("./{#{domains.join(',')}}/*/").map {|f| f[2..-2]}
    @global_available = Dir.glob("./global/*/").map {|f| f[2..-2]}
    @enabled = [@url].concat @dex_enabled[@url]
  end

  attr_reader :url, :has_dexfiles

  def get_file(ext)
    if ext == 'json'
      metadata = {}

      # Get all available modules
      Dir.glob("./{global,utilities,*.*}/*/").each do |k|
        category, title = k[2..-2].split("/")

        metadata["#{category}/#{title}"] = {
          "Title" => title,
          "Category" => category
        }
      end

      return JSON.pretty_generate({
        'site_available' =>   @available,
        'site_enabled' =>     @enabled,
        'global_available' => @global_available,
        'global_enabled' =>   @enabled,
        'metadata' => metadata
      })
    end

    case ext
    when 'css' then exts = ['css', 'scss', 'sass']
    when 'js'  then exts = ['js', 'coffee']
    else return "Unsupported extension: #{ext}"
    end

    files = Dir.glob("./{#{@enabled.join(',')}}/*.{#{exts.join(',')}}").select {|f| File.file? f}

    files.map! do |file|
      _ext = file.rpartition('.')[2]
        file_contents = case
        when ['css', 'js'].include?(_ext)
          IO.read(file)
        when $dex_config.include?("compile-#{_ext}")
          begin
            Open3.popen3($dex_config["compile-#{_ext}"] % {
              file: File.expand_path(file).shellescape
            }) {|stdin, stdout, stderr, wait| stdout.read }
          rescue
            "/* compile-#{_ext} error, could not load '#{file}' */"
          end
        else
          "/* set 'compile-#{_ext}' in your config to enable compilation of #{_ext} files */"
        end

      <<-FILE.chomp
/* @begin #{file} */

#{file_contents}

/* @end #{file} */
      FILE
    end

    <<-THING
/*
Modules for #{@url}
#{@available.map do |e|
  y = @enabled.include?(e) ? "x" : " "
  "[#{y}] #{e}"
end.join("\n")}
*/

#{files.join("\n\n")}
    THING
  end

  def write
    File.open(DEX_ENABLED_FILE, 'w+') do |f|
      f.puts yaml_header + @enabled.to_yaml
    end
  end
end

class DexServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    puts "#{Time.now.strftime "%H:%M:%S"} - #{request.request_method} #{request.unparsed_uri}"

    # set content-type
    response['Content-Type'] = case request.path[/\.(css|js|json)$/, 1]
      when 'css' then 'text/css'
      when 'js', 'json' then 'application/javascript'
      else 'text/plain'
    end + '; charset=utf-8'

    # set body contents
    response.body = case request.path[1..-1]
    # index
    when '' then DexSite.new('default').get_file('json')

    when %r{
      ^
      (\d+\/)? # cachebuster
      ([^\/]+\.[^\/]+|global)
      \.
      (css|json|js)
      $
    }x
      cachebuster, url, ext = $~.captures
      dex_site = DexSite.new(url)

      if dex_site.has_dexfiles
        puts "URL '#{dex_site.url}' has dexfiles".comment_out
      else
        puts "URL '#{dex_site.url}' doesn’t have dexfiles, but here, have a 404".comment_out
        response.status = 404
        return "No dexfiles for '#{dex_site.url}' :...("
      end

      if cachebuster
        puts "Loading '#{request.path}' and caching".comment_out
        # Cache for 69 years
        response['Last-Modified'] = Time.new(2000,1,1).rfc2822
        response['Cache-Control'] = "public, max-age=#{60*60*24*365*69}"
        response['Expires'] = (Time.now + 60*60*24*365*69).rfc2822
      else
        puts "Loading uncached version of '#{request.path}'".comment_out
        response['Last-Modified'] = (Time.now + 60*60*24*365*69).rfc2822
        response['Cache-Control'] = 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0'
        response['Expires'] = (Time.now - 60*60*24*365*69).rfc2822
      end

      dex_site.get_file(ext)

    else
      response.status = 404
      '404 not found'
    end
  end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

server_options = {
  :Host => $dex_config['hostname'],
  :BindAddress => "127.0.0.1",
  :Port => $dex_config['port'],
  :Logger => WEBrick::Log.new("/dev/null"),
  :AccessLog => [],
  :SSLEnable => true,
  :SSLVerifyClient => OpenSSL::SSL::VERIFY_NONE,
  :SSLPrivateKey => OpenSSL::PKey::RSA.new(ssl_key),
  :SSLCertificate => OpenSSL::X509::Certificate.new(ssl_cert),
  :SSLCertName => [["CN", WEBrick::Utils::getservername]]
}

server = WEBrick::HTTPServer.new(server_options)
server.mount("/", DexServer)

%w(INT TERM).each {|s| trap(s) { server.shutdown }}

puts "dexd 1.0.0 at your service…".console_green
server.start
__END__

-----BEGIN CERTIFICATE-----
MIICHTCCAYYCCQClZE2IvNWbtDANBgkqhkiG9w0BAQUFADBTMQswCQYDVQQGEwJV
UzETMBEGA1UECBMKQ2FsaWZvcm5pYTELMAkGA1UEBxMCTEExDjAMBgNVBAoTBWRv
dGpzMRIwEAYDVQQDEwlsb2NhbGhvc3QwHhcNMTMwMjIwMjMzNzUzWhcNMjIxMTIw
MjMzNzUzWjBTMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTELMAkG
A1UEBxMCTEExDjAMBgNVBAoTBWRvdGpzMRIwEAYDVQQDEwlsb2NhbGhvc3QwgZ8w
DQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAMNgNijoFmD5TX7NMd2pGEeEmwRifWRc
45jVS1a5kUncfRfgr4ehygPQDS2XrUkd+OYneFIXOcANW9WAWAlfeLs8DiSgs+9m
tuVjZ58RAsRXkW7H3vqQv5sAxmmwwVGN9WfKW+II/xLhpMtVGQH+MOucGbssODzk
0vwXEGSeEqYdAgMBAAEwDQYJKoZIhvcNAQEFBQADgYEAgCW2RBZgDMikQenSF3sz
u7KDe8+t8qnEFvrwCEpLUzvedSZxkaKzHrrCnIYlDnXRZBveKngWoejGzqtyIXup
YKzBZaZWH8cV72RdDwgM1owWi3KZBKpxfphYkWSRRx59djHZY/Yjudnb3oT/3c8/
NHsFbLbrZaGriLshIwrjEGs=
-----END CERTIFICATE-----
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQDDYDYo6BZg+U1+zTHdqRhHhJsEYn1kXOOY1UtWuZFJ3H0X4K+H
ocoD0A0tl61JHfjmJ3hSFznADVvVgFgJX3i7PA4koLPvZrblY2efEQLEV5Fux976
kL+bAMZpsMFRjfVnylviCP8S4aTLVRkB/jDrnBm7LDg85NL8FxBknhKmHQIDAQAB
AoGAZDw9LRl9Ob1No+t0VOuG+FIxEbvR5ya84dE0OMc1ofZL+28bvvMjaHdZ+3Ug
wy1sX/AKC9u8liqEXfHduNlRX59WfhS1DBIqpezpg3Hj35sCmuGvtiJVMHbZBX0I
S0P14vXxaGJ/Sw04CgbGJs08P5ITTleZ9HioHhCkUObP5kUCQQD3auQTo/oqbNXz
FbL1ckP65wUz7ean+YcXDYgKM2jnyEfATMWjjQkMEzO4MJdfuLi+5UbEfup1c1zB
SmIijzN7AkEAyicud3X+HoV2dwRPzsquvR27fjEsIttzjNJ0Kcm+YAtIQcJQti9e
E9OMjSsxa8LQ1V8HMWmDYyoAEhdYG1BtRwJAczlTmJYANmvTQ87yNf6ODDY0pReB
GO9La4AAwAdrLq6GQ9c9H8rZ0MbMilYO2SRU3Yo3Z+FXXXVpWBdFFqUsKwJAKNYn
bdx5HENLvhkx4g1RpUR3VrOqPdRlEEKHUtW9TnuY+ie91D/XWlv23aGnFyTAuQm8
U0AEWajnYMA0fTgPCwJBAI1J6nOjlE5jcKKzBAE33iL8lXj5FlGX3hhPM4jm3BCN
bpmhcfRVwyhqWwYChEQ5Y25Lv0i7Lxpud/UbLE0x/x8=
-----END RSA PRIVATE KEY-----