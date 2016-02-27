#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'optparse'
require 'shellwords'
require 'time'
require 'yaml'
require 'fileutils'

DEX_NAME = File.basename(__FILE__, '.rb')
DEX_VERSION = '1.0.0'
DEX_DIR = File.expand_path('~/.dex')
DEX_ENABLED_FILE = File.join(DEX_DIR, 'enabled.yaml')

DEX_HOST = 'localhost'
$dex_port = 3131

LAUNCHAGENT_LABEL = 'fm.meyer.dex'
LAUNCHAGENT_FILE = File.expand_path("~/Library/LaunchAgents/#{LAUNCHAGENT_LABEL}.plist")

%w(INT TERM).each {|s| trap(s){puts "\ntake care out there \u{1f44b}"; abort}}

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

ARGV.push('--help') if ARGV.empty?

OptionParser.new do |opts|
  opts.separator "Starts dex server in the foreground. kill with <Control>C"

  opts.on('-r', '--run [port]', 'Run dex server') do |p|
    if p
      begin
        $dex_port = Integer(p)
        abort "Port number must be greater than 1024" unless $dex_port > 1024
      rescue
        abort 'Invalid port number'
      end
    end
    $run_dex = true
  end

  opts.on(nil, '--status', 'Show status of launchagent') do |l|
    if system("curl -I --ipv4 --referer nope https://#{DEX_HOST}:#{$dex_port}/is-this-thing-on &> /dev/null")
      puts "#{DEX_NAME} is running!"
      system('launchctl list | grep fm.meyer.dex')
    else
      puts "#{DEX_NAME} is not running"
    end
  end

  opts.on(nil, '--load', 'Load launchagent') {|l| launchctl('load')}
  opts.on(nil, '--unload', 'Unload launchagent') {|l| launchctl('unload')}

  opts.on(nil, '--uninstall', 'Uninstall launchagent') do |l|
    abort 'Already uninstalled!' unless File.exist?(LAUNCHAGENT_FILE)
    launchctl('unload')
    FileUtils.rm_f(LAUNCHAGENT_FILE)
  end

  opts.on(nil, '--install', 'Install launchagent') do |l|
    launchctl('unload')

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
      <string>--run</string>
    </array>

    <key>StandardOutPath</key>
    <string>#{File.expand_path('~/Library/Logs/dex.log')}</string>

    <key>StandardErrorPath</key>
    <string>#{File.expand_path('~/Library/Logs/dex-error.log')}</string>

    <key>WorkingDirectory</key>
    <string>#{DEX_DIR}</string>

    <key>RunAtLoad</key>
    <true/>
  </dict>
</plist>
    PLIST

    File.open(LAUNCHAGENT_FILE, 'w', 0755) {|f| f.write(plist)}
    launchctl('load')
  end

  opts.on_tail('-h', '--help', 'Show this message') do
    puts opts
  end

end.parse!

exit unless $run_dex

abort("#{DEX_NAME} expects a directory or symlink at ~/.dex") unless File.exist?(DEX_DIR)
Dir.chdir(DEX_DIR)

class DexSite
  def initialize(url)
    @url = url.to_s.force_encoding("utf-8")

    # Load enabled files from YAML, remove falsey/empty values
    @dex_config = (begin YAML.load_file(DEX_ENABLED_FILE) rescue {} end || {}).select {|k,v| v && v != []}

    # All modules that exist on the filesystem
    @valid_modules = Dir.glob("./{global,utilities,*.*}/*/").map {|f| f[2..-2]}

    if @url === 'global'
      @available = Dir.glob("./global/*/").map {|f| f[2..-2]}
    else
      domains = []

      if @url != 'empty'
        @url.gsub!(/^ww[w\d]\./, '')

        # Build array of domain parts from TLD all the way to full subdomain
        domains = @url.split('.')
        domains.map!.with_index {|k,i| domains[i..-1].join('.')}.reverse!
      end

      # Add utils to the front of the array
      domains.unshift 'utilities'
      @available = Dir.glob("./{#{domains.join(',')}}/*/").map {|f| f[2..-2]}
    end

    # Remove invalid modules
    @dex_config[@url] = (@dex_config[@url] || []) & @valid_modules

    # Ensure special case modules are included (i.e. a util module in global)
    @all_available = @available | @dex_config[@url]
  end

  def get_object
    Hash[@all_available.map do |k|
      category, title = k.split("/")
      [
        k,
        {
          title: title,
          category: category,
          enabled: @dex_config[@url].include?(k),
        }.tap {|h| h[:weirdo] = true if !@available.include?(k)}
      ]
    end]
  end

  def get_file(ext)
    if @url === 'empty'
      if ['js', 'css'].include?(ext)
        return <<-WOW
/*
Available Modules
=================
#{(@available).map {|a| "- #{a}"}.join("\n")}
*/
        WOW
      else
        return ''
      end
    end

    return nil unless @dex_config[@url] && @dex_config[@url].length > 0
    return nil unless ['js', 'css'].include?(ext)

    # Load setup files for exact domain matches
    files = Dir.glob("./{#{[@url].concat(@dex_config[@url]).join(',')}}/*.#{ext}").select {|f| File.file? f}

    # Return nil if no files exist for this module + file extension combo
    return nil if files.length === 0

    files.map! do |file|
      file_contents = IO.read(file).chomp

      if ext === 'js'
        # Wrap javascript in a closure
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
Modules (#{@url})
#{@all_available.map {|e| "[#{@dex_config[@url].include?(e) ? "x" : " "}] #{e}"}.join("\n")}
*/

#{files.join("\n\n")}
    THING
  end

  def toggle_site(mod)
    mod = mod.to_s.force_encoding("utf-8")
    status = 'error'
    message = "Module '#{mod}' does not exist :("
    action = false

    if @available.include?(mod)
      status = 'success'
      if @dex_config[@url].delete(mod)
        message = "Module '#{mod}' was disabled for #{@url}"
        action = 'disabled'
      else
        message = "Module '#{mod}' was enabled for #{@url}"
        action = 'enabled'
        @dex_config[@url].push(mod)
        @dex_config[@url].sort!
      end

      @dex_config.delete(@url) if @dex_config[@url].empty?

      # Sort global modules to the top
      @dex_config = Hash[@dex_config.sort {|a,b| a[0] === 'global' ? -1 : a <=> b}]

      puts "#{status.upcase}: #{message}".indent_timestamp
      File.open(DEX_ENABLED_FILE, 'w+') do |f|
        f.puts "# Generated by #{DEX_NAME} #{DEX_VERSION}"
        f.puts "# #{Time.now.asctime}"
        f.puts @dex_config.to_yaml
      end

    elsif @all_available.include?(mod)
      message = "Module '#{mod}' cannot be toggled from the Dex popover"
    elsif @valid_modules.include?(mod)
      message = "Module '#{mod}' is not available for this domain"
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
require 'webrick'
require 'webrick/https'

puts 'Running server...'.indent_timestamp

class DexServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    puts "#{request.request_method} #{request.unparsed_uri}".indent_timestamp

    # set content-type
    response['Content-Type'] = if File.extname(request.path) === '.css'
      'text/css'
    else
      'application/javascript'
    end + '; charset=utf-8'

    # set body contents
    response.body = case request.path[1..-1]

    # default: return global JSON
    when '' then {global: DexSite.new('global').get_object}.to_json

    # Return JSON config for specified hostname
    when %r{
      ^
      ([^\/]+)
      \.
      json
      $
    }x
      url = $~.captures[0]
      dexObj = {url => DexSite.new(url)}
      dexObj['global'] = DexSite.new('global') if url != 'global'

      if request.query['toggle']
        dexObj[url].toggle_site(request.query['toggle']).to_json
      else
        Hash[dexObj.map {|k,v| [k, v.get_object]}].to_json
      end

    when %r{
      ^
      ([^\/]+\/)? # optional cachebuster
      ([^\/]+)
      \.
      (css|js)
      $
    }x
      cachebuster, url, ext = $~.captures
      dex_site = DexSite.new(url)

      file_contents = dex_site.get_file(ext)

      unless file_contents || url === 'empty'
        puts "No enabled #{ext.upcase} files for '#{url}', redirecting...".comment_out
        response.set_redirect(
          cachebuster ? WEBrick::HTTPStatus::MovedPermanently : WEBrick::HTTPStatus::TemporaryRedirect,
          "/69/empty.#{ext}"
        )
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
  :Port => $dex_port,
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

puts "#{DEX_NAME} #{DEX_VERSION} running at https://#{DEX_HOST}:#{$dex_port}".console_green.indent_timestamp
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
