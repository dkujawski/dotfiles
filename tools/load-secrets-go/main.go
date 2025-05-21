package main

import (
	"context"
	"crypto/md5"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	op "github.com/1password/onepassword-sdk-go"
	"gopkg.in/yaml.v3"
)

// Config represents the configuration file structure
type Config struct {
	Paths []PathConfig `yaml:"paths"`
}

// PathConfig represents a single 1Password path configuration
type PathConfig struct {
	URI     string   `yaml:"uri"`
	Env     string   `yaml:"env"`
	IsRef   bool     `yaml:"is_ref"`
	Aliases []string `yaml:"aliases,omitempty"`
}

// CachedSecret represents a cached secret with timestamp
type CachedSecret struct {
	Timestamp int64  `json:"timestamp"`
	Value     string `json:"value"`
}

// SecretCache handles caching of secrets
type SecretCache struct {
	CacheDir   string
	TTLMinutes int64
}

// NewSecretCache creates a new secret cache
func NewSecretCache(cacheDir string, ttlMinutes int64) (*SecretCache, error) {
	if cacheDir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return nil, fmt.Errorf("failed to get home directory: %w", err)
		}
		cacheDir = filepath.Join(home, ".cache", "op-secrets")
	}

	if err := os.MkdirAll(cacheDir, 0700); err != nil {
		return nil, fmt.Errorf("failed to create cache directory: %w", err)
	}

	return &SecretCache{
		CacheDir:   cacheDir,
		TTLMinutes: ttlMinutes,
	}, nil
}

// Get retrieves a secret from cache
func (c *SecretCache) Get(item string) (string, bool) {
	cachePath := filepath.Join(c.CacheDir, fmt.Sprintf("%x.json", md5.Sum([]byte(item))))
	data, err := os.ReadFile(cachePath)
	if err != nil {
		return "", false
	}

	var cached CachedSecret
	if err := json.Unmarshal(data, &cached); err != nil {
		return "", false
	}

	if time.Now().Unix()-cached.Timestamp > c.TTLMinutes*60 {
		os.Remove(cachePath)
		return "", false
	}

	return cached.Value, true
}

// Set stores a secret in cache
func (c *SecretCache) Set(item, value string) error {
	cachePath := filepath.Join(c.CacheDir, fmt.Sprintf("%x.json", md5.Sum([]byte(item))))
	cached := CachedSecret{
		Timestamp: time.Now().Unix(),
		Value:     value,
	}

	data, err := json.Marshal(cached)
	if err != nil {
		return fmt.Errorf("failed to marshal cache data: %w", err)
	}

	if err := os.WriteFile(cachePath, data, 0600); err != nil {
		return fmt.Errorf("failed to write cache file: %w", err)
	}

	return nil
}

// loadConfig loads the configuration from a file
func loadConfig(configPath string) (*Config, error) {
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	return &config, nil
}

func main() {
	debug := os.Getenv("DEBUG") == "1" || os.Getenv("DEBUG") == "true"
	if debug {
		fmt.Fprintln(os.Stderr, "[DEBUG] Starting 1Password secrets loading")
	}

	// Check for required 1Password service account token
	token := os.Getenv("OP_SERVICE_ACCOUNT_TOKEN")
	if token == "" {
		fmt.Fprintln(os.Stderr, "Error: OP_SERVICE_ACCOUNT_TOKEN environment variable is not set. Please export your 1Password service account token and try again.")
		os.Exit(1)
	}

	// Parse command line arguments
	configPath := flag.String("config", "config.yaml", "Path to configuration file")
	customPath := flag.String("path", "", "Custom 1Password path to load (format: op://vault/item/field)")
	customEnv := flag.String("env", "", "Environment variable name for custom path")
	flag.Parse()

	// Set up 1Password account
	os.Setenv("OP_ACCOUNT", "foxcorporation.1password.com")
	if debug {
		fmt.Fprintf(os.Stderr, "[DEBUG] Using 1Password account: %s\n", os.Getenv("OP_ACCOUNT"))
	}

	// Set email
	user := os.Getenv("USER")
	foxEmail := fmt.Sprintf("%s@fox.com", user)
	os.Setenv("FOX_EMAIL", foxEmail)
	if debug {
		fmt.Fprintf(os.Stderr, "[DEBUG] Set FOX_EMAIL to: %s\n", foxEmail)
	}

	// Initialize cache
	cache, err := NewSecretCache("", 30)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize cache: %v\n", err)
		os.Exit(1)
	}

	// Initialize 1Password client
	ctx := context.Background()
	client, err := op.NewClient(
		ctx,
		op.WithServiceAccountToken(token),
		op.WithIntegrationInfo("Load Secrets Tool", "1.0.0"),
	)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize 1Password client: %v\n", err)
		os.Exit(1)
	}

	// Load paths to process
	var pathsToProcess []PathConfig

	// Add custom path if provided
	if *customPath != "" {
		if *customEnv == "" {
			fmt.Fprintln(os.Stderr, "Error: --env flag is required when using --path")
			os.Exit(1)
		}
		pathsToProcess = append(pathsToProcess, PathConfig{
			URI:   *customPath,
			Env:   *customEnv,
			IsRef: true,
		})
	} else {
		// Load from config file
		config, err := loadConfig(*configPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to load config: %v\n", err)
			os.Exit(1)
		}
		pathsToProcess = config.Paths
	}

	// Process each item
	for _, item := range pathsToProcess {
		if debug {
			fmt.Fprintf(os.Stderr, "[DEBUG] Processing: %s\n", item.URI)
		}

		// Try cache first
		if value, ok := cache.Get(item.URI); ok {
			if debug {
				fmt.Fprintf(os.Stderr, "[DEBUG] Cache hit for: %s\n", item.URI)
			}
			fmt.Printf("export %s='%s'\n", item.Env, value)
			for _, alias := range item.Aliases {
				fmt.Printf("export %s='%s'\n", alias, value)
			}
			continue
		}

		// Read from 1Password
		var value string
		var err error
		if item.IsRef {
			value, err = client.Secrets().Resolve(ctx, item.URI)
		} else {
			// Handle direct item access if needed
			// This would require parsing the URI and using the appropriate SDK methods
			err = fmt.Errorf("direct item access not implemented")
		}

		if err != nil {
			if debug {
				fmt.Fprintf(os.Stderr, "[DEBUG] Failed to read %s: %v\n", item.URI, err)
			}
			continue
		}

		// Cache the value
		if err := cache.Set(item.URI, value); err != nil && debug {
			fmt.Fprintf(os.Stderr, "[DEBUG] Failed to cache %s: %v\n", item.URI, err)
		}

		// Export the value
		fmt.Printf("export %s='%s'\n", item.Env, value)
		for _, alias := range item.Aliases {
			fmt.Printf("export %s='%s'\n", alias, value)
		}
	}

	if debug {
		fmt.Fprintln(os.Stderr, "[DEBUG] Completed loading all secrets")
	}
}
