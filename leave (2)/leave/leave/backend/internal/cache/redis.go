package cache

import (
	"context"
	"encoding/json"
	"time"

	"github.com/go-redis/redis/v8"
)

type CacheService struct {
	client *redis.Client
}

func NewCacheService(addr, password string) *CacheService {
	rdb := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: password,
		DB:       0,
	})
	return &CacheService{client: rdb}
}

// GetOrSet implements a cache-aside pattern
func (c *CacheService) GetOrSet(ctx context.Context, key string, ttl time.Duration, fetch func() (interface{}, error)) (interface{}, error) {
	// 1. Try Get
	val, err := c.client.Get(ctx, key).Result()
	if err == nil {
		// Cache Hit
		// Record hit metric here (e.g. Prometheus)
		return val, nil
	}

	// 2. Cache Miss - Fetch Data
	data, err := fetch()
	if err != nil {
		return nil, err
	}

	// 3. Set Cache (Async)
	go func() {
		bytes, _ := json.Marshal(data)
		c.client.Set(context.Background(), key, bytes, ttl)
	}()

	return data, nil
}

// AddHotQuery adds a query to the hot list (Sorted Set)
func (c *CacheService) AddHotQuery(ctx context.Context, query string) {
	c.client.ZIncrBy(ctx, "hot_queries", 1, query)
}

// GetHotQueries retrieves top N queries
func (c *CacheService) GetHotQueries(ctx context.Context, n int64) ([]string, error) {
	return c.client.ZRevRange(ctx, "hot_queries", 0, n-1).Result()
}
