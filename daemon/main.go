package main

import (
	"crypto/tls"
	"flag"
	"fmt"
	"github.com/golang/glog"
	"github.com/gorilla/mux"
	"net/http"
	"os"
)

var (
	certPtr    = flag.String("cert_dir", "", "path to the folder that contains cert.pem and key.pem")
	dexVersion string
	dexPort    string
)

func main() {
	flag.Parse()

	// hack to make glog log to stderr by default
	flag.Lookup("logtostderr").Value.Set("true")

	certDir := *certPtr

	if certDir == "" {
		fmt.Fprintf(os.Stderr, "cert_dir is a required flag")
		os.Exit(420)
	}

	if _, err := os.Stat(certDir); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Cert directory '%s' does not exist", certDir)
		os.Exit(69)
	}

	r := mux.NewRouter()

	r.HandleFunc("/", ImmediatelyExpire(indexHandler))
	r.HandleFunc("/{cachebuster:\\d+}/config.json", ImmediatelyExpire(configHandler))
	r.HandleFunc("/{cachebuster:\\d+}/empty.{ext:(js|css)}", NeverExpire(emptyHandler))
	r.HandleFunc("/{cachebuster:\\d+}/{hostname:(global|.+\\.[^\\.]+)}.{ext:(js|css)}", NeverExpire(dexfileHandler))

	tlsConfig := &tls.Config{
		Certificates: make([]tls.Certificate, 1),
	}

	tlsConfig.Certificates[0] = getSSLCert(certDir)

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
}
