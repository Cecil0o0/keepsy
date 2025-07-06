package main

import (
	"net/http"
	// https://pkg.go.dev/net/http/pprof
	_ "net/http/pprof"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Hello World!"))
	})

	http.ListenAndServe("localhost:6060", nil)
}
