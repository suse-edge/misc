package main

import (
	"fmt"
	"log"
	"os"

	"github.com/suse-edge/misc/retrieve-digests/pkg"
)

func main() {
	// Check if a project path is provided
	if len(os.Args) < 2 {
		log.Fatalf("Usage: %s <PROJECT>", os.Args[0])
	}

	project := os.Args[1]

	successful, failed, err := pkg.RunRetrieveDigests(project)

	if err != nil {
		log.Fatalf("Error processing repositories: %v", err)
	}

	fmt.Printf("Processing complete. Successful fetches: %d, Failed fetches: %d\n", successful, failed)
}
