package main

import (
	"github.com/golang/glog"
	"net/http"
	"time"
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
