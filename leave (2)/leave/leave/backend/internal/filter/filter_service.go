package filter

import (
	"strings"
	"sync"
	"search-engine-backend/internal/search"
)

type Service struct {
	blockedDomains map[string]bool
	mu             sync.RWMutex
}

func NewService() *Service {
	s := &Service{
		blockedDomains: make(map[string]bool),
	}
	// 初始化默认黑名单
	s.loadDefaultBlacklist()
	return s
}

func (s *Service) loadDefaultBlacklist() {
	// 示例黑名单
	domains := []string{
		"example-adult-site.com",
		"bad-content.org",
		"xxx-test.net",
		"adult.com",
		"porn.com",
		// 在实际系统中，这里会从数据库或配置文件加载大量域名
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	for _, d := range domains {
		s.blockedDomains[d] = true
	}
}

// Filter 处理搜索结果，移除违规内容
func (s *Service) Filter(results []search.Document) ([]search.Document, int) {
	filteredCount := 0
	var safeResults []search.Document

	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, doc := range results {
		if s.isBlocked(doc) {
			filteredCount++
			continue
		}
		safeResults = append(safeResults, doc)
	}

	return safeResults, filteredCount
}

func (s *Service) isBlocked(doc search.Document) bool {
	// 1. 检查域名
	// 简单的域名包含检查。实际可能需要更严格的解析。
	for domain := range s.blockedDomains {
		if strings.Contains(doc.URL, domain) || strings.Contains(doc.Title, domain) {
			return true
		}
	}

	// 2. 简单的关键词检查 (实际项目中关键词过滤通常更复杂，涉及 AC 自动机等算法)
	sensitiveKeywords := []string{"成人", "色情", "赌博", "xxx", "porn"}
	for _, kw := range sensitiveKeywords {
		if strings.Contains(doc.Title, kw) || strings.Contains(doc.Content, kw) {
			return true
		}
	}

	return false
}
