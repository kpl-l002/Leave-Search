package config

import (
	"os"
)

type Config struct {
	ServerPort       string
	ElasticsearchURL string
	RedisAddr        string
	RedisPassword    string
	JiebaDictPath    string
}

func Load() *Config {
	return &Config{
		ServerPort:       getEnv("SERVER_PORT", "8080"),
		ElasticsearchURL: getEnv("ELASTICSEARCH_URL", "http://localhost:9200"),
		RedisAddr:        getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPassword:    getEnv("REDIS_PASSWORD", ""),
		JiebaDictPath:    getEnv("JIEBA_DICT_PATH", "dict"),
	}
}

func getEnv(key, fallback string) string {
	if value, ok := os.LookupEnv(key); ok {
		return value
	}
	return fallback
}
