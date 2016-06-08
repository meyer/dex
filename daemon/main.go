package main

import (
	"bytes"
	"crypto/tls"
	"flag"
	"github.com/golang/glog"
	"github.com/gorilla/mux"
	"github.com/kardianos/osext"
	"net/http"
	"os"
	"os/user"
	"path/filepath"
	"text/template"
)

var (
	runPtr     = flag.Bool("run", false, "start dexd "+dexVersion)
	installPtr = flag.Bool("install", false, "install launch agent")
	dexVersion string
	dexPort    string
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

		certPem, _ := Asset("assets/cert.pem")
		keyPem, _ := Asset("assets/key.pem")
		keyPair, _ := tls.X509KeyPair(certPem, keyPem)

		tlsConfig := &tls.Config{
			Certificates: make([]tls.Certificate, 1),
		}
		tlsConfig.Certificates[0] = keyPair

		glog.Info("dexd " + dexVersion + " at your service")
		server := &http.Server{
			Addr:      dexPort,
			Handler:   r,
			TLSConfig: tlsConfig,
		}
		err := server.ListenAndServeTLS("", "")
		glog.Fatal(err)

	case *installPtr:
		glog.Info("Installing launch agent to ~/Library/LaunchAgents")
		plist_asset, _ := Asset("assets/launchagent.plist")
		plist_template, err := template.New("launchagent").Parse(string(plist_asset))
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
		plist_template.Execute(&doc, map[string]string{
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
		glog.Info("Wrote to "+launchAgentFile+":\n", s)
		glog.Info("\nTo start dexd:\n  launchctl load -w " + launchAgentFile)

	default:
		flag.PrintDefaults()
	}
}
