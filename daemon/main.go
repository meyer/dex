package main

import (
	"flag"
	"github.com/gorilla/mux"
	"log"
	"net/http"
)

func main() {
	runPtr := flag.Bool("run", false, "start dexd "+DexVersion)
	installPtr := flag.Bool("install", false, "install launch agent")
	flag.Parse()

	switch {
	case *runPtr:
		log.Println("dexd " + DexVersion + " at your service")
		r := mux.NewRouter()
		r.HandleFunc("/", indexHandler)
		r.HandleFunc("/{url:[^\\.]+\\.[^\\.]+}.{ext:json}", siteHandler)
		r.HandleFunc("/{cachebuster:\\d+}/empty.{ext:(js|css)}", emptyHandler)
		r.HandleFunc("/{cachebuster:\\d+}/{url:(global|[^\\.]+\\.[^\\.]+)}.{ext:(js|css)}", siteHandler)
		http.ListenAndServeTLS(":3131", "cert.pem", "key.pem", r)
	case *installPtr:
		log.Println("Install!")
	default:
		flag.PrintDefaults()
	}
}
