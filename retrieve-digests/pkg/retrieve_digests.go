package pkg

import (
	"context"
	"strings"
)

const (
	registrySuseDe  = "registry.suse.de"
	registrySuseCom = "registry.suse.com"
	HeaderImage     = "Image"
	HeaderTag       = "Tag"
	HeaderDigest    = "Digest"
	outputFileDe    = "suse_de.csv"
	outputFileCom   = "suse_com.csv"
)

// RunRetrieveDigests contains the core logic for processing repositories
func RunRetrieveDigests(project string) (successful int, failed int, err error) {
	projectURI := strings.ReplaceAll(strings.ToLower(project), ":", "/")

	// Create CSV writers
	writerDe := NewCSVWriter(outputFileDe)
	defer writerDe.Close()

	writerCom := NewCSVWriter(outputFileCom)
	defer writerCom.Close()

	// Write headers to the CSV files
	writerDe.WriteHeader([]string{HeaderImage, HeaderTag, HeaderDigest})
	writerCom.WriteHeader([]string{HeaderImage, HeaderTag, HeaderDigest})

	repoFetcher := &ORASRepositoryFetcher{}

	// Process repositories and log the result
	successful, failed, err = ProcessRepositories(
		context.Background(),
		registrySuseDe,
		registrySuseCom,
		projectURI,
		projectURI,
		repoFetcher,
		writerDe,
		writerCom,
	)

	if err != nil {
		return 0, 0, err
	}

	return successful, failed, nil
}
