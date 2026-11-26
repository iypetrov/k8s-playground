package main

import (
	"log"
	"net/http"
	"time"
)

const prometheusURL = "https://prometheus.demo.prometheus.io/api/v1/metadata"

func main() {
	log.Println("batch-job starting")

	for i := 1; i <= 10; i++ {
		log.Printf("%d/10 batches are processed", i)

		resp, err := http.Get(prometheusURL)
		if err != nil {
			log.Printf("request failed: %v", err)
		} else {
			resp.Body.Close()
		}
		time.Sleep(2 * time.Second)
	}

	log.Println("batch-job batch done")
}
