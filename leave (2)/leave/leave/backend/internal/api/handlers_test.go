package api

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestValidateSearchInput(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected string
		valid    bool
	}{
		{"Normal query", "hello", "hello", true},
		{"Trim spaces", "  hello  ", "hello", true},
		{"Empty query", "   ", "", false},
		{"XSS attempt", "<script>alert(1)</script>", "&lt;script&gt;alert(1)&lt;/script&gt;", true},
		{"Too long query", string(make([]byte, 150)), string(make([]byte, 100)), true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			res, valid := validateSearchInput(tt.input)
			if tt.name == "Too long query" {
				assert.Equal(t, 100, len(res))
			} else {
				assert.Equal(t, tt.expected, res)
			}
			assert.Equal(t, tt.valid, valid)
		})
	}
}

func TestValidatePagination(t *testing.T) {
	tests := []struct {
		name         string
		pageStr      string
		sizeStr      string
		expectedPage int
		expectedSize int
	}{
		{"Default values", "", "", 1, 10},
		{"Valid values", "2", "20", 2, 20},
		{"Invalid page", "abc", "10", 1, 10},
		{"Negative page", "-1", "10", 1, 10},
		{"Max size limit", "1", "100", 1, 50},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			page, size := validatePagination(tt.pageStr, tt.sizeStr)
			assert.Equal(t, tt.expectedPage, page)
			assert.Equal(t, tt.expectedSize, size)
		})
	}
}
