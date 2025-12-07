package search

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"search-engine-backend/internal/config"

	"github.com/elastic/go-elasticsearch/v8"
	"github.com/elastic/go-elasticsearch/v8/esapi"
	"github.com/go-redis/redis/v8"
)

type Service struct {
	esClient    *elasticsearch.Client
	redisClient *redis.Client
	cfg         *config.Config
}

type SearchResult struct {
	Total       int64      `json:"total"`
	Hits        []Document `json:"hits"`
	Took        int        `json:"took"`
	Suggestions []string   `json:"suggestions"`
}

type Document struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Content   string    `json:"content"`
	URL       string    `json:"url"`
	Score     float64   `json:"score"`
	Timestamp time.Time `json:"timestamp"`
}

func NewService(cfg *config.Config) (*Service, error) {
	esCfg := elasticsearch.Config{
		Addresses: []string{cfg.ElasticsearchURL},
	}
	esClient, err := elasticsearch.NewClient(esCfg)
	if err != nil {
		return nil, fmt.Errorf("error creating elasticsearch client: %s", err)
	}

	rdb := redis.NewClient(&redis.Options{
		Addr:     cfg.RedisAddr,
		Password: cfg.RedisPassword,
		DB:       0,
	})

	return &Service{
		esClient:    esClient,
		redisClient: rdb,
		cfg:         cfg,
	}, nil
}

func (s *Service) Close() {
	s.redisClient.Close()
}

func (s *Service) Search(ctx context.Context, query string, page, size int) (*SearchResult, error) {
	// 1. Check Cache
	cacheKey := fmt.Sprintf("search:%s:%d:%d", query, page, size)
	val, err := s.redisClient.Get(ctx, cacheKey).Result()
	if err == nil {
		var result SearchResult
		if err := json.Unmarshal([]byte(val), &result); err == nil {
			return &result, nil
		}
	}

	// 2. Simple Segmentation (Whitespace) - Replacing Jieba to avoid CGO dependency
	// In a real Windows environment without GCC, pure Go tokenizers like "github.com/wangbin/jiebago"
	// or "github.com/go-ego/gse" are recommended over CGO-based ones.
	// For now, we use simple splitting to ensure compilation succeeds.
	words := strings.Fields(query)
	finalQuery := strings.Join(words, " ")

	// 3. Build ES Query
	var buf bytes.Buffer
	queryMap := map[string]interface{}{
		"from": (page - 1) * size,
		"size": size,
		"query": map[string]interface{}{
			"multi_match": map[string]interface{}{
				"query":  finalQuery,
				"fields": []string{"title^3", "content"},
			},
		},
		"highlight": map[string]interface{}{
			"fields": map[string]interface{}{
				"title":   map[string]interface{}{},
				"content": map[string]interface{}{},
			},
		},
	}
	if err := json.NewEncoder(&buf).Encode(queryMap); err != nil {
		return nil, err
	}

	// 4. Execute Search
	res, err := s.esClient.Search(
		s.esClient.Search.WithContext(ctx),
		s.esClient.Search.WithIndex("webpages"),
		s.esClient.Search.WithBody(&buf),
		s.esClient.Search.WithTrackTotalHits(true),
	)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	if res.IsError() {
		return nil, fmt.Errorf("search request failed: %s", res.String())
	}

	// 5. Parse Response
	var r map[string]interface{}
	if err := json.NewDecoder(res.Body).Decode(&r); err != nil {
		return nil, err
	}

	hits := r["hits"].(map[string]interface{})
	total := int64(hits["total"].(map[string]interface{})["value"].(float64))
	took := int(r["took"].(float64))

	var documents []Document
	for _, hit := range hits["hits"].([]interface{}) {
		h := hit.(map[string]interface{})
		source := h["_source"].(map[string]interface{})
		doc := Document{
			ID:      h["_id"].(string),
			Title:   source["title"].(string),
			Content: source["content"].(string),
			URL:     source["url"].(string),
			Score:   h["_score"].(float64),
		}
		documents = append(documents, doc)
	}

	result := &SearchResult{
		Total:       total,
		Hits:        documents,
		Took:        took,
		Suggestions: s.getSuggestions(query),
	}

	// 6. Cache Result (Async)
	go func() {
		data, _ := json.Marshal(result)
		s.redisClient.Set(context.Background(), cacheKey, data, 5*time.Minute)
	}()

	return result, nil
}

func (s *Service) getSuggestions(query string) []string {
	// Simplified suggestion logic
	// In production, this would query ES completion suggester or Redis sorted sets
	return []string{query + " tutorial", query + " example", query + " docs"}
}

func (s *Service) IndexDocument(ctx context.Context, doc *Document) error {
	data, err := json.Marshal(doc)
	if err != nil {
		return err
	}

	req := esapi.IndexRequest{
		Index:      "webpages",
		DocumentID: doc.ID,
		Body:       bytes.NewReader(data),
		Refresh:    "true",
	}

	res, err := req.Do(ctx, s.esClient)
	if err != nil {
		return err
	}
	defer res.Body.Close()

	if res.IsError() {
		return fmt.Errorf("error indexing document: %s", res.String())
	}
	return nil
}
