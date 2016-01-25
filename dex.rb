#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'optparse'
require 'shellwords'
require 'time'
require 'yaml'
require 'fileutils'

DEX_VERSION = '1.0.0'
DEX_DIR = File.expand_path('~/.dex')
DEX_ENABLED_FILE = File.join(DEX_DIR, 'enabled.yaml')

DEX_HOST = 'localhost'
DEX_PORT = 3131

LAUNCHAGENT_LABEL = 'fm.meyer.dex'
LAUNCHAGENT_FILE = File.expand_path("~/Library/LaunchAgents/#{LAUNCHAGENT_LABEL}.plist")

def launchctl(l); system('launchctl', l, '-w', LAUNCHAGENT_FILE.shellescape); end

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
  def indent_timestamp; indent(self, "[#{Time.now.strftime("%H:%M:%S.%L")}] "); end
end

OptionParser.new do |opts|
  opts.separator "Starts dex server in the foreground. kill with <Control>C"

  opts.on(nil, '--load', 'Load launchagent') {|l| launchctl('load'); exit}
  opts.on(nil, '--unload', 'Unload launchagent') {|l| launchctl('unload'); exit}

  opts.on(nil, '--uninstall', 'Uninstall launchagent') do |l|
    abort 'Already uninstalled!' unless File.exist?(LAUNCHAGENT_FILE)
    launchctl('unload')
    FileUtils.rm_f(LAUNCHAGENT_FILE)
    exit
  end

  opts.on(nil, '--install', 'Install launchagent') do |l|
    plist = <<-PLIST.chomp
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>#{LAUNCHAGENT_LABEL}</string>

    <key>KeepAlive</key>
    <true/>

    <key>ProgramArguments</key>
    <array>
      <string>#{File.expand_path(__FILE__)}</string>
    </array>

    <key>WorkingDirectory</key>
    <string>#{DEX_DIR}</string>

    <key>RunAtLoad</key>
    <true/>
  </dict>
</plist>
    PLIST

    File.open(LAUNCHAGENT_FILE, 'w', 0755) {|f| f.write(plist)}
    exit
  end

end.parse!

abort('Dex expect a directory or symlink at ~/.dex') unless File.exist?(DEX_DIR)

Dir.chdir(DEX_DIR)

class DexSite
  def initialize(url)
    @url = url
    @domains = [@url]

    # Load enabled files from YAML, remove falsey/empty values
    @dex_enabled = (begin YAML.load_file(DEX_ENABLED_FILE) rescue {} end || {}).select {|k,v| v && v != []}

    @available = []
    @enabled = []

    unless @url === 'global'
      @url.gsub!(/^ww[w\d]\./, '')
      @domains = @url.split('.')
      # Build array of domain parts from tld all the way to full subdomain
      @domains.map!.with_index {|k,i| @domains[i..-1].join('.')}.reverse!
      @domains.unshift 'utilities'
    end

    @available = Dir.glob("./{#{@domains.join(',')}}/*/").map {|f| f[2..-2]}
    @enabled = @dex_enabled[@url] || []

    @global_available = Dir.glob("./global/*/").map {|f| f[2..-2]}
    @global_enabled = @dex_enabled['global'] || []
  end

  attr_reader :domains

  def get_file(ext)
    puts "EXT: #{ext}. #{ext === 'json'}"
    if ext === 'json'
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
        'global_enabled' =>   @global_enabled,
        'metadata' => metadata
      })
    end

    puts @dex_enabled[@url]

    return nil unless @dex_enabled[@url] && @dex_enabled[@url].length > 0
    return nil unless ['js', 'css'].include?(ext)

    # Always load setup files for domains
    files = Dir.glob("./{#{[@url].concat(@enabled).join(',')}}/*.#{ext}").select {|f| File.file? f}

    return nil if files.length === 0

    files.map! do |file|
      file_contents = IO.read(file).chomp

      if ext === 'js'
        file_contents = <<-JS.chomp
(function(){

#{file_contents}

})();
        JS
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
#{@available.map {|e| "[#{@enabled.include?(e) ? "x" : " "}] #{e}"}.join("\n")}
*/

#{files.join("\n\n")}
    THING
  end

  def toggle_site(mod)
    mod = mod.to_s
    status = 'error'
    message = "Module '#{mod}' does not exist :("
    action = false

    if (@available + @global_available).include?(mod)
      status = 'success'
      if @enabled.delete(mod)
        message = "Module '#{mod}' was disabled for #{@url}"
        action = 'disabled'
        @dex_enabled.delete(@url) if @enabled.empty?
      else
        message = "Module '#{mod}' was enabled for #{@url}"
        action = 'enabled'
        @enabled.push(mod)
        @enabled.sort!
        @dex_enabled[@url] = @enabled
      end

      global_modules = @dex_enabled.delete('global')

      @dex_enabled = @dex_enabled.sort.to_h
      @dex_enabled = {'global' => global_modules}.merge(@dex_enabled) if global_modules

      puts "#{status.upcase}: #{message}".indent_timestamp
      File.open(DEX_ENABLED_FILE, 'w+') do |f|
        f.puts "# Generated by Dex #{DEX_VERSION}"
        f.puts "# #{Time.now.asctime}"
        f.puts @dex_enabled.to_yaml
      end
    end

    {
      :module => mod,
      :status => status,
      :action => action,
      :message => message,
    }
  end
end

puts 'Requiring webrick...'.indent_timestamp

# TODO: figure out why requiring webrick adds 5-10 seconds to startup time
require 'webrick'
require 'webrick/https'

puts 'Running server...'.indent_timestamp

class DexServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    puts "#{request.request_method} #{request.unparsed_uri}".indent_timestamp

    # set content-type
    response['Content-Type'] = case request.path[/\.(css|js|json)$/, 1]
      when 'css' then 'text/css'
      when 'js', 'json' then 'application/javascript'
      else 'text/plain'
    end + '; charset=utf-8'

    # set body contents
    response.body = case request.path[1..-1]

    # index
    when '' then DexSite.new('nope').get_file('json')

    when %r{
      ^
      ([^\/]+\/)? # optional cachebuster
      ([^\/]+)
      \.
      (css|json|js)
      $
    }x
      cachebuster, url, ext = $~.captures
      dex_site = DexSite.new(url)

      if ext === 'json' && request.query['toggle']
        dex_site.toggle_site(request.query['toggle']).to_json
      else
        file_contents = dex_site.get_file(ext)

        if !file_contents
          puts "URL '#{url}' doesn’t have any enabled dexfiles, but here, have a 404".comment_out
          response.status = 404
          file_contents = '/* 404 */'
        end

        if cachebuster
          response['Last-Modified'] = Time.new(2000,1,1).rfc2822
          response['Cache-Control'] = "public, max-age=#{60*60*24*365*69}"
          response['Expires'] = (Time.now + 60*60*24*365*69).rfc2822
        else
          response['Last-Modified'] = (Time.now + 60*60*24*365*69).rfc2822
          response['Cache-Control'] = 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0'
          response['Expires'] = (Time.now - 60*60*24*365*69).rfc2822
        end

        file_contents
      end
    else
      response.status = 404
      '/* 404 */'
    end

    puts "RES #{response.status} #{request.unparsed_uri} (#{cachebuster ? 'cached' : 'uncached'})".indent_timestamp
  end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

server_options = {
  :Host => DEX_HOST,
  :BindAddress => "127.0.0.1",
  :Port => DEX_PORT,
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

puts "dexd #{DEX_VERSION} running at https://#{DEX_HOST}:#{DEX_PORT}".console_green.indent_timestamp
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