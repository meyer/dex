package main

import (
	"bytes"
	"crypto/tls"
	"flag"
	"github.com/gorilla/mux"
	"github.com/kardianos/osext"
	"log"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"text/template"
)

var (
	runPtr     = flag.Bool("run", false, "start dexd "+DexVersion)
	installPtr = flag.Bool("install", false, "install launch agent")
)

func main() {
	flag.Parse()

	switch {
	case *runPtr:
		r := mux.NewRouter()

		r.HandleFunc("/", indexHandler)
		r.HandleFunc("/{url:.+\\.[^\\.]+}.{ext:json}", siteHandler)
		r.HandleFunc("/{cachebuster:\\d+}/empty.{ext:(js|css)}", emptyHandler)
		r.HandleFunc("/{cachebuster:\\d+}/{url:(global|.+\\.[^\\.]+)}.{ext:(js|css)}", siteHandler)

		certPem, _ := Asset("ssl/cert.pem")
		keyPem, _ := Asset("ssl/key.pem")
		keyPair, _ := tls.X509KeyPair(certPem, keyPem)

		tlsConfig := &tls.Config{
			Certificates: make([]tls.Certificate, 1),
		}
		tlsConfig.Certificates[0] = keyPair

		log.Println("dexd " + DexVersion + " at your service")
		server := &http.Server{Addr: ":3131", Handler: r, TLSConfig: tlsConfig}
		err := server.ListenAndServeTLS("", "")
		log.Fatal(err)

	case *installPtr:
		log.Println("Installing launch agent to ~/Library/LaunchAgents")
		plist, err := template.ParseFiles("launchagent.plist")
		if err != nil {
			panic(err)
		}

		usr, _ := user.Current()
		dexBinPath, _ := osext.Executable()
		dexPath, _ := filepath.EvalSymlinks(filepath.Join(usr.HomeDir, ".dex"))
		stdoutLogPath := filepath.Join(usr.HomeDir, "/Library/Logs/dex.log")
		stderrLogPath := filepath.Join(usr.HomeDir, "/Library/Logs/dex-error.log")
		launchAgentFile := filepath.Join(usr.HomeDir, "/Library/LaunchAgents/fm.meyer.dex.plist")

		var doc bytes.Buffer
		plist.Execute(&doc, map[string]string{
			"dexBinPath":    dexBinPath,
			"dexPath":       dexPath,
			"stdoutLogPath": stdoutLogPath,
			"stderrLogPath": stderrLogPath,
		})
		s := doc.String()

		f, err := os.Create(launchAgentFile)
		if err != nil {
			panic(err)
		}
		defer f.Close()

		f.WriteString(s)
		log.Println("Wrote to "+launchAgentFile+":\n", s)
		log.Println("\nTo start dexd:\n  launchctl load -w " + launchAgentFile)

	default:
		flag.PrintDefaults()
	}
}
