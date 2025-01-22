package pkg

import (
	"context"
	"log"
	"strings"
)

// RunRetrieveDigests contains the core logic for processing repositories
func RunRetrieveDigests(project string) (int, int, error) {
	projectURI := strings.ToLower(project)
	projectURI = strings.ReplaceAll(projectURI, ":", "/")

	// Output files
	outputFileDe := "suse_de.csv"
	outputFileCom := "suse_com.csv"

	// Create CSV writers
	writerDe := NewCSVWriter(outputFileDe)
	defer writerDe.Close()

	writerCom := NewCSVWriter(outputFileCom)
	defer writerCom.Close()

	// Write headers to the CSV files
	writerDe.WriteHeader([]string{"Image", "Tag", "Digest"})
	writerCom.WriteHeader([]string{"Image", "Tag", "Digest"})

	repoFetcher := &ORASRepositoryFetcher{}

	// Process repositories and log the result
	successful, failed, err := ProcessRepositories(
		context.Background(),
		"registry.suse.de",
		"registry.suse.com",
		projectURI,
		projectURI,
		repoFetcher,
		writerDe,
		writerCom,
	)

	if err != nil {
		return 0, 0, err
	}

	log.Printf("Processing complete. Successful fetches: %d, Failed fetches: %d", successful, failed)
	return successful, failed, nil
}
