package main

import (
	// "encoding/json"
	"fmt"
	"github.com/gorilla/mux"
	"log"
	"net/http"
	"time"
)

func siteHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)

	url, hasURL := vars["url"]
	_, hasExt := vars["ext"]

	if !hasURL || !hasExt {
		panic("Required URL params `url` and `ext` both need to be set")
		return
	}

	site := DexSite{url: url}
	site.loadConfig()
	fmt.Println("dexPath", site.dexPath)

	// config := make(map[string]Array)
	// config[site.url] = site.modules

	// Set expiration headers
	if cachebuster, hasCB := vars["cachebuster"]; hasCB {
		log.Printf("cachebuster: %s", cachebuster)
		w.Header().Set("Last-Modified", time.Date(2000, 1, 1, 12, 0, 0, 0, time.UTC).Format(time.RFC1123))
		w.Header().Set("Cache-Control", fmt.Sprintf("public, max-age=%d", 60*60*24*365*69))
		w.Header().Set("Expires", time.Now().AddDate(69, 0, 0).Format(time.RFC1123))
	} else {
		log.Println("no cachebuster set")
		w.Header().Set("Last-Modified", time.Now().AddDate(69, 0, 0).Format(time.RFC1123))
		w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, post-check=0, pre-check=0")
		w.Header().Set("Expires", time.Now().AddDate(-69, 0, 0).Format(time.RFC1123))
	}

	w.Write([]byte("Gorilla!\n"))
}
