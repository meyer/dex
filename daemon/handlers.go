package main

import (
	"fmt"
	"github.com/gorilla/mux"
	"net/http"
	"time"
)

const DexVersion = "2.0.0"

var contentTypes = map[string]string{
	"js":   "application/javascript; charset=utf-8",
	"css":  "text/css; charset=utf-8",
	"json": "application/json; charset=utf-8",
}

func siteHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)

	url, hasURL := vars["url"]
	ext, hasExt := vars["ext"]
	cachebuster, hasCB := vars["cachebuster"]

	if !hasURL || !hasExt {
		panic("Required URL params `url` and `ext` both need to be set")
		return
	}

	site := DexSite{url: url}
	site.init()

	// Set expiration headers
	if hasCB {
		w.Header().Set("Last-Modified", time.Date(2000, 1, 1, 12, 0, 0, 0, time.UTC).Format(time.RFC1123))
		w.Header().Set("Cache-Control", fmt.Sprintf("public, max-age=%d", 60*60*24*365*69))
		w.Header().Set("Expires", time.Now().AddDate(69, 0, 0).Format(time.RFC1123))
	} else {
		w.Header().Set("Last-Modified", time.Now().AddDate(69, 0, 0).Format(time.RFC1123))
		w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, post-check=0, pre-check=0")
		w.Header().Set("Expires", time.Now().AddDate(-69, 0, 0).Format(time.RFC1123))
	}

	w.Header().Set("Content-Type", contentTypes[ext])

	switch ext {
	case "js", "css":
		fileContents := site.getFile(ext)
		if fileContents == nil {
			if cachebuster != "" {
				http.Redirect(w, r, "/69/empty."+ext, http.StatusMovedPermanently)
			} else {
				http.Redirect(w, r, "/69/empty."+ext, http.StatusFound)
			}
			return
		}
		w.Write(fileContents)

	case "json":
		if moduleName := r.FormValue("toggle"); moduleName != "" {
			w.Write(site.toggleModule(moduleName))
		} else {
			w.Write(site.getConfigAsJSON())
		}

	default:
		panic(fmt.Sprintf("Unrecognised extension: %s", ext))
	}
}

func emptyHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	ext, _ := vars["ext"]
	w.Header().Set("Content-Type", contentTypes[ext])
	w.Write([]byte("/* nothing here, sorryyyy */"))
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("helloooo\n"))
}
