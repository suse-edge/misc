# Retrieve Digests Tool

## Overview

This tool is designed to retrieve container image digests between two registries: `registry.suse.de` and `registry.suse.com`. It dynamically fetches repositories and their respective tags from the given project path, retrieves the associated digests, and outputs the results into CSV files for comparison.

## Installation

1. Clone the repository
2. Build the tool:
   ```bash
   go build -o retrieve-digests
   ```

## Usage

Run the tool with the project path as an argument:

```bash
./retrieve-digests <PROJECT>
```

### Example

```bash
./retrieve-digests isv/suse/edge/3.2/totest
```

This will:

1. Fetch all repositories under the `isv/suse/edge/3.2/totest` path in `registry.suse.de`.
2. Retrieve the latest tags and digests for each image.
3. Adjust paths for `registry.suse.com` and retrieve the corresponding digests.
4. Output results to `suse_de.csv` and `suse_com.csv`.

## Output

The CSV files have the following structure:

| Image                           | Tag   | Digest            |
| ------------------------------- | ----- | ----------------- |
| isv/suse/edge/3.2/totest/image1 | 1.0.0 | sha256\:abc123... |
| edge/image1                     | 1.0.0 | sha256\:def456... |

- `suse_de.csv`: Contains data for images from `registry.suse.de`.
- `suse_com.csv`: Contains data for images from `registry.suse.com`.

## Development

This tool is modular and can be extended by:

- Adding support for additional registries.
- Enhancing the retrieval logic.
- Adding automated comparison logic.
- Introducing more detailed logging or reporting features.
