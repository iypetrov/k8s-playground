package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("healthz called from %s", r.RemoteAddr)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	log.Println("http-server listening on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
