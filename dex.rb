#!/usr/bin/env ruby

require 'webrick'
require 'webrick/https'
require 'yaml'
require 'json'
require 'shellwords'
require 'time'

DEX_CONFIG_FILE = File.expand_path('~/.dex-config.yaml')

class DexConfig
  def initialize
    begin
      FileUtils.touch(DEX_CONFIG_FILE)
      raise unless @config = YAML.load(IO.read(DEX_CONFIG_FILE))
    rescue
      @config = {}
    end
    @config = {
      # defaults
      'port' => 3131,
      'hostname' => 'localhost',
      'dir' => File.expand_path('~/.dex')
    }.merge(@config)
  end

  attr_reader :config

  def to_s; @config.to_yaml; end
  def update(new_hash); @config.merge!(new_hash); end
  def write; File.open(DEX_CONFIG_FILE, 'w+') {|f| f.write @config.to_yaml}; end
end

DEX_CONFIG = DexConfig.new
DEX_ENABLED_FILE = File.join(DEX_CONFIG.config['dir'], 'enabled.yaml')

Dir.chdir DEX_CONFIG.config['dir']

class DexSite
  def initialize(url)
    # Read enabled files from DEX_ENABLED_FILE
    FileUtils.touch(DEX_ENABLED_FILE)
    begin
      @dex_enabled = YAML.load(IO.read(DEX_ENABLED_FILE)) || {}
    rescue
      @dex_enabled = {}
    end

    if url == 'default'
      @url = false
      @has_dexfiles = true
      domains = []
    else
      @url = url.gsub(/^ww[w\d]\./, '')
      @has_dexfiles = @dex_enabled.include? @url
      domains = @url.split('.')
      # Correct order: com, google.com, mail.google.com
      domains.map!.with_index {|k,i| domains[i..-1].join('.')}.reverse!
    end

    domains.unshift 'utilities'

    @site_available = Dir.glob("./{#{domains.join(',')}}/*/").map {|f| f[2..-2]}
    @site_enabled = @url ? (@dex_enabled[@url] || []) : []
    @global_available = Dir.glob("./global/*/").map {|f| f[2..-2]}
    @global_enabled = (@dex_enabled['global'] || [])

  end

  def get_json
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
      'site_available' =>   @site_available,
      'site_enabled' =>     @site_enabled,
      'global_available' => @global_available,
      'global_enabled' =>   @global_enabled,
      'metadata' => metadata
    })
  end

  def get_file(ext)
    case ext
    when 'css' then exts = ['css', 'scss']
    when 'js'  then exts = ['js', 'coffee']
    else return "Unsupported extension: #{ext}"
    end

    enabled = @global_enabled + [@url] + @site_enabled

    files = Dir.glob("./{#{enabled.join(',')}}/*.{#{exts.join(',')}}")

    files.map! do |file|
      file_contents = case file.rpartition('.')[2]
      when 'coffee'
        begin
          `cat #{Shellwords.escape file} | coffee -sc`
        rescue
          "/* coffeescript error, could not load '#{file}' */"
        end
      when 'scss'
        begin
          `node-sass #{Shellwords.escape file}`
        rescue
          "/* node-sass error, could not load '#{file}' */"
        end
      when 'css', 'js'
        IO.read(file)
      end

      <<-FILE.chomp
/* @begin #{file} */

#{file_contents}

/* @end #{file} */
      FILE
    end

    <<-THING
/*
Global Modules
#{@global_available.map do |e|
  y = @global_enabled.include?(e) ? "x" : " "
  "[#{y}] #{e}"
end.join("\n")}

Site Modules
#{@site_available.map do |e|
  y = @site_enabled.include?(e) ? "x" : " "
  "[#{y}] #{e}"
end.join("\n")}
*/

#{files.join("\n\n")}
    THING
  end

  attr_reader :site_enabled, :site_available, :global_enabled, :global_available, :has_dexfiles

  def write
    File.open(DEX_ENABLED_FILE, 'w+') do |f|
      f.puts "# Generated by Dex #{DEX_VERSION}"
      f.puts "# #{Time.now.asctime}"
      f.puts "---"
      f.puts @dex_enabled.to_yaml
    end
  end
end

class DexServer < WEBrick::HTTPServlet::AbstractServlet
  def do_GET(request, response)
    puts "#{Time.now.strftime "%H:%M:%S"} - #{request.request_method} #{request.unparsed_uri}"

    if /\.(?<ext>css|js|json)$/ =~ request.path
      response["Content-Type"] = case $~["ext"]
        when 'css' then 'text/css'
        when 'js', 'json' then 'application/javascript'
      end + '; charset=utf-8'
    end

    case request.path[1..-1]
    when ''
      dex_site = DexSite.new('default')
      response.body = dex_site.get_json
      return

    when %r{
      ^
      (\d+\/)? # cachebuster
      ([^\/]+\.[^\/]+|default)
      \.
      (css|json|js)
      $
    }x
      cachebuster, url, ext = $~.captures

      dex_site = DexSite.new(url)

      if dex_site.has_dexfiles
        puts "URL '#{url}' has dexfiles"
      else
        puts "URL '#{url}' doesn’t have dexfiles, redirecting to default.#{ext}"
        response.set_redirect(
          WEBrick::HTTPStatus[301], # moved permanently
          "/#{cachebuster}default.#{ext}"
        )
      end

      if cachebuster
        puts "Loading '#{request.path}' and caching"
        # Cache for 69 years
        response['Last-Modified'] = Time.new(2000,1,1).rfc2822
        response['Cache-Control'] = "public, max-age=#{60*60*24*365*69}"
        response['Expires'] = (Time.now + 60*60*24*365*69).rfc2822
      else
        puts "Loading uncached version of '#{request.path}'"
        response['Last-Modified'] = (Time.now + 60*60*24*365*69).rfc2822
        response['Cache-Control'] = 'no-store, no-cache, must-revalidate, post-check=0, pre-check=0'
        response['Expires'] = (Time.now - 60*60*24*365*69).rfc2822
      end

      response.body = ext == 'json' ? dex_site.get_json : dex_site.get_file(ext)
      return

    end

    response.body = '404 not found'
    response.status = 404
  end
end

ssl_info = DATA.read
ssl_cert = ssl_info.scan(/(-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----)/m)[0][0]
ssl_key = ssl_info.scan(/(-----BEGIN RSA PRIVATE KEY-----.+?-----END RSA PRIVATE KEY-----)/m)[0][0]

server_options = {
  :Host => DEX_CONFIG.config['hostname'],
  :BindAddress => "127.0.0.1",
  :Port => DEX_CONFIG.config['port'],
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

puts "dexd 1.0.0 at your service…"
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