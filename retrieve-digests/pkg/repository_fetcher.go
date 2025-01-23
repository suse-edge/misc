package pkg

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"oras.land/oras-go/v2"
	"oras.land/oras-go/v2/registry/remote"
	"sort"
	"strings"
)

type RepositoryFetcher interface {
	FetchRepositories(ctx context.Context, registry, basePath string) ([]string, error)
	FetchLatestTag(ctx context.Context, registry, image string) (string, error)
	FetchDigest(ctx context.Context, registry, image, tag string) (string, error)
}

type ORASRepositoryFetcher struct{}

func (o *ORASRepositoryFetcher) FetchRepositories(ctx context.Context, registry, basePath string) ([]string, error) {
	url := fmt.Sprintf("https://%s/v2/_catalog", strings.TrimPrefix(registry, "https://"))
	resp, err := http.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch catalog: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch catalog: %s", resp.Status)
	}

	var catalog struct {
		Repositories []string `json:"repositories"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&catalog); err != nil {
		return nil, fmt.Errorf("failed to parse catalog response: %w", err)
	}

	var filtered []string
	for _, repo := range catalog.Repositories {
		if strings.HasPrefix(repo, basePath) {
			filtered = append(filtered, repo)
		}
	}

	sort.Strings(filtered) // Sort repositories for consistency
	return filtered, nil
}

func (o *ORASRepositoryFetcher) FetchLatestTag(ctx context.Context, registry, image string) (string, error) {
	repo, err := remote.NewRepository(fmt.Sprintf("%s/%s", registry, image))
	if err != nil {
		return "", fmt.Errorf("failed to connect to repository: %w", err)
	}

	var tags []string
	err = repo.Tags(ctx, "", func(foundTags []string) error {
		tags = append(tags, foundTags...)
		return nil
	})
	if err != nil {
		return "", fmt.Errorf("failed to fetch tags: %w", err)
	}

	if len(tags) == 0 {
		return "", fmt.Errorf("no tags found for image %s", image)
	}

	sort.Strings(tags) // Ensure sorted order
	return tags[0], nil
}

func (o *ORASRepositoryFetcher) FetchDigest(ctx context.Context, registry, image, tag string) (string, error) {
	repo, err := remote.NewRepository(fmt.Sprintf("%s/%s", registry, image))
	if err != nil {
		return "", fmt.Errorf("failed to connect to repository: %w", err)
	}

	descriptor, _, err := oras.Fetch(ctx, repo, tag, oras.DefaultFetchOptions)
	if err != nil {
		return "", fmt.Errorf("failed to fetch digest: %w", err)
	}

	return descriptor.Digest.String(), nil
}
