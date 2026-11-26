package main

import (
	"log"
	"time"
)

func main() {
	log.Println("batch-job starting")

	log.Println("batch-job processing batch")
	log.Println("1/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("2/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("3/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("4/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("5/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("6/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("7/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("8/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("9/10 batches are processed")
	time.Sleep(1 * time.Second)
	log.Println("10/10 batches are processed")
	log.Println("batch-job batch done")
	time.Sleep(2 * time.Second)
}
