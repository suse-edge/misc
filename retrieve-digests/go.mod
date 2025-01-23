module github.com/suse-edge/misc/retrieve-digests

go 1.23.4

require oras.land/oras-go/v2 v2.5.0

replace github.com/suse-edge/misc/retrieve-digests/pkg => ./pkg

require (
	github.com/opencontainers/go-digest v1.0.0 // indirect
	github.com/opencontainers/image-spec v1.1.0 // indirect
	golang.org/x/sync v0.10.0 // indirect
)
