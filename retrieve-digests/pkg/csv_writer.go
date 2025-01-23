package pkg

import (
	"encoding/csv"
	"log"
	"os"
)

// CSVWriter handles writing data to a CSV file
type CSVWriter struct {
	file   *os.File
	writer *csv.Writer
}

// NewCSVWriter creates a new CSVWriter
func NewCSVWriter(filename string) *CSVWriter {
	file, err := os.Create(filename)
	if err != nil {
		log.Fatalf("Failed to create file %s: %v", filename, err)
	}
	return &CSVWriter{
		file:   file,
		writer: csv.NewWriter(file),
	}
}

// WriteHeader writes the header to the CSV file
func (c *CSVWriter) WriteHeader(header []string) {
	if err := c.writer.Write(header); err != nil {
		log.Fatalf("Failed to write header: %v", err)
	}
}

// WriteRow writes a row to the CSV file
func (c *CSVWriter) WriteRow(row []string) error {
	if err := c.writer.Write(row); err != nil {
		log.Printf("Failed to write row %v: %v", row, err)
		return err
	}
	c.writer.Flush()
	return nil
}

// Close closes the CSV file
func (c *CSVWriter) Close() {
	c.writer.Flush()
	c.file.Close()
}
