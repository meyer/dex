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
	"runtime"
	"text/template"
	"time"
)

var (
	runPtr     = flag.Bool("run", false, "start dexd "+dexVersion)
	installPtr *bool
	dexVersion string
	dexPort    string
)

func DexHandler(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Log request
		glog.V(1).Info(r.Method, " ", r.URL)

		// Set common headers
		w.Header().Set("Dex-Version", dexVersion)
		w.Header().Set("Access-Control-Allow-Origin", "http://localhost:3000")
		h.ServeHTTP(w, r)
	})
}

func NeverExpire(f http.HandlerFunc) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Last-Modified", time.Date(2000, 1, 1, 12, 0, 0, 0, time.UTC).Format(time.RFC1123))
		w.Header().Set("Cache-Control", "public, max-age=2175984000")
		w.Header().Set("Expires", time.Now().AddDate(69, 0, 0).Format(time.RFC1123))
		f(w, r)
	})
}

func ImmediatelyExpire(f http.HandlerFunc) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Last-Modified", time.Now().AddDate(69, 0, 0).Format(time.RFC1123))
		w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, post-check=0, pre-check=0")
		w.Header().Set("Expires", time.Now().AddDate(-69, 0, 0).Format(time.RFC1123))
		f(w, r)
	})
}

func main() {
	if runtime.GOOS == "darwin" {
		installPtr = flag.Bool("install", false, "install launch agent")
	}

	flag.Parse()
	// hack to make glog log to stderr by default
	flag.Lookup("logtostderr").Value.Set("true")

	switch {
	case *runPtr:
		r := mux.NewRouter()

		r.HandleFunc("/", ImmediatelyExpire(indexHandler))
		r.HandleFunc("/{cachebuster:\\d+}/config.json", ImmediatelyExpire(configHandler))
		r.HandleFunc("/{cachebuster:\\d+}/empty.{ext:(js|css)}", NeverExpire(emptyHandler))
		r.HandleFunc("/{cachebuster:\\d+}/{hostname:(global|.+\\.[^\\.]+)}.{ext:(js|css)}", NeverExpire(dexfileHandler))

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
			Handler:   DexHandler(r),
			TLSConfig: tlsConfig,
			// Disable HTTP2
			TLSNextProto: make(map[string]func(*http.Server, *tls.Conn, http.Handler)),
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
