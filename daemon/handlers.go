package main

import (
	"fmt"
	"github.com/gorilla/mux"
	"net/http"
)

var contentTypes = map[string]string{
	"js":   "application/javascript; charset=utf-8",
	"css":  "text/css; charset=utf-8",
	"json": "application/json; charset=utf-8",
}

func dexfileHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)

	hostname, hasHostname := vars["hostname"]
	ext, hasExt := vars["ext"]
	_, hasCB := vars["cachebuster"]

	if !hasHostname || !hasExt {
		panic("Required URL params `hostname` and `ext` both need to be set")
		return
	}

	site := DexSite{}
	site.init()

	w.Header().Set("Content-Type", contentTypes[ext])

	switch ext {
	case "js", "css":
		fileContents := site.getFileForHostname(ext, hostname)
		if fileContents == nil {
			if hasCB {
				http.Redirect(w, r, "/69/empty."+ext, http.StatusMovedPermanently)
			} else {
				http.Redirect(w, r, "/69/empty."+ext, http.StatusFound)
			}
			return
		}
		w.Write(fileContents)

	default:
		panic(fmt.Sprintf("Unrecognised extension: %s", ext))
	}
}

func configHandler(w http.ResponseWriter, r *http.Request) {
	site := DexSite{}
	site.init()

	w.Header().Set("Content-Type", contentTypes["json"])

	if moduleName := r.FormValue("toggle"); moduleName != "" {
		if hostname := r.FormValue("hostname"); hostname != "" {
			w.Write(site.toggleModuleForHostname(moduleName, hostname))
		} else {
			panic("Hostname must be set for site.toggleModuleForHostname")
		}
	} else {
		w.Write(site.getConfigAsJSON())
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
