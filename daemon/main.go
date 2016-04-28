package main

import (
	"github.com/gorilla/mux"
	"log"
	"net/http"
)

func main() {
	log.Println("dexd " + DexVersion + " at your service")
	r := mux.NewRouter()
	r.HandleFunc("/", indexHandler)
	r.HandleFunc("/{url:[^\\.]+\\.[^\\.]+}.{ext:json}", siteHandler)
	r.HandleFunc("/{cachebuster:\\d+}/empty.{ext:(js|css)}", emptyHandler)
	r.HandleFunc("/{cachebuster:\\d+}/{url:(global|[^\\.]+\\.[^\\.]+)}.{ext:(js|css)}", siteHandler)
	http.ListenAndServeTLS(":3132", "cert.pem", "key.pem", r)
}
