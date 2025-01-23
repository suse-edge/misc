package pkg

import (
	"context"
	"fmt"
	"log"
	"strings"
)

// ProcessRepositories processes images for two registries and writes digests to CSV files
func ProcessRepositories(ctx context.Context, registry1, registry2, project1, project2 string, repoFetcher RepositoryFetcher, writer1, writer2 *CSVWriter) (int, int, error) {
	// Fetch repositories from the first registry
	images, err := repoFetcher.FetchRepositories(ctx, registry1, project1)
	if err != nil {
		return 0, 0, err
	}

	// Track success and failure counts
	successful := 0
	failed := 0

	// Process each image
	for _, image := range images {
		// Fetch the latest tag for each image
		tag, err := repoFetcher.FetchLatestTag(ctx, registry1, image)
		if err != nil {
			log.Printf("Failed to fetch tags for image %s (tag: %s): %v", image, tag, err)
			failed++
			continue
		}

		// Fetch digest for registry.suse.de
		digestDe, err := repoFetcher.FetchDigest(ctx, registry1, image, tag)
		if err != nil {
			log.Printf("Failed to fetch digest for image %s (tag: %s) from registry.suse.de: %v", image, tag, err)
			failed++
			continue
		}
		log.Printf("Successfully fetched digest for image %s (tag: %s, digest: %s) from registry.suse.de", image, tag, digestDe)
		successful++

		// Write to the first CSV (suse_de.csv)
		rowDe := []string{image, tag, digestDe}
		if err := writer1.WriteRow(rowDe); err != nil {
			log.Printf("Failed to write to suse_de.csv for image %s (tag: %s): %v", image, tag, err)
			failed++
			continue
		}

		// Prepare the image for registry.suse.com
		stem := strings.TrimPrefix(image, project1+"/")
		if strings.HasPrefix(stem, "images/") {
			stem = strings.TrimPrefix(stem, "images/")
		}

		// Fetch digest for registry.suse.com
		digestCom, err := repoFetcher.FetchDigest(ctx, registry2, fmt.Sprintf("edge/%s", stem), tag)
		if err != nil {
			log.Printf("Failed to fetch digest for image %s (tag: %s) from registry.suse.com: %v", stem, tag, err)
			failed++
			continue
		}
		log.Printf("Successfully fetched digest for image %s (tag: %s, digest: %s) from registry.suse.com", stem, tag, digestCom)
		successful++

		// Write to the second CSV (suse_com.csv)
		rowCom := []string{stem, tag, digestCom}
		if err := writer2.WriteRow(rowCom); err != nil {
			log.Printf("Failed to write to suse_com.csv for image %s (tag: %s): %v", stem, tag, err)
			failed++
			continue
		}
	}

	return successful, failed, nil
}
