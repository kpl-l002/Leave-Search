package crawler

import (
	"net/http"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"
)

type WebPage struct {
	URL         string
	Title       string
	Content     string
	Description string
	Keywords    []string
	CrawlTime   time.Time
}

type Cleaner struct {
	bannedDomains []string
}

func NewCleaner() *Cleaner {
	return &Cleaner{
		bannedDomains: []string{"ads.com", "tracker.com"},
	}
}

func (c *Cleaner) FetchAndClean(url string) (*WebPage, error) {
	// 1. Fetch
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	// 2. Parse
	doc, err := goquery.NewDocumentFromReader(resp.Body)
	if err != nil {
		return nil, err
	}

	// 3. Clean
	// Remove scripts, styles, and comments
	doc.Find("script, style, comment").Remove()

	// Extract Content
	title := strings.TrimSpace(doc.Find("title").Text())
	description, _ := doc.Find("meta[name=description]").Attr("content")
	
	// Extract text and remove extra whitespace
	content := strings.TrimSpace(doc.Find("body").Text())
	content = strings.Join(strings.Fields(content), " ")

	// Basic validation
	if len(content) < 50 {
		return nil, nil // Content too short, ignore
	}

	return &WebPage{
		URL:         url,
		Title:       title,
		Content:     content,
		Description: description,
		CrawlTime:   time.Now(),
	}, nil
}
