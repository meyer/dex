load "./extension/Rakefile"

desc "Generate SSL certs"
task :generate_ssl do
  system [
    "go",
    "run",
    "$(go env GOROOT)/src/crypto/tls/generate_cert.go",
    "-ca",
    "-start-date=\"Jan 1 00:00:00 2000\"",
    "-duration=#{69 * 24 * 365}h0m0s",
    "-host=\"localhost,127.0.0.1\"",
  ].join(" ")
end
