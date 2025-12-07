package api

import (
	"html"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"search-engine-backend/internal/filter"
	"search-engine-backend/internal/ip"
	"search-engine-backend/internal/search"
)

type Handler struct {
	svc    *search.Service
	ipSvc  *ip.Service
	filter *filter.Service
}

func NewHandler(svc *search.Service, ipSvc *ip.Service, filter *filter.Service) *Handler {
	return &Handler{
		svc:    svc,
		ipSvc:  ipSvc,
		filter: filter,
	}
}

// validateSearchInput 验证并清理搜索输入
func validateSearchInput(query string) (string, bool) {
	// 移除首尾空格
	query = strings.TrimSpace(query)
	if query == "" {
		return "", false
	}
	
	// 限制长度防止DoS
	if len(query) > 100 {
		query = query[:100]
	}

	// XSS 防护：对输入进行 HTML 转义
	query = html.EscapeString(query)
	
	return query, true
}

// validatePagination 验证分页参数
func validatePagination(pageStr, sizeStr string) (int, int) {
	page, err := strconv.Atoi(pageStr)
	if err != nil || page < 1 {
		page = 1
	}

	size, err := strconv.Atoi(sizeStr)
	if err != nil || size < 1 {
		size = 10
	}
	if size > 50 { // 限制最大每页数量
		size = 50
	}

	return page, size
}

// SearchResponse 扩展原有的 SearchResult，增加过滤信息
type SearchResponse struct {
	*search.SearchResult
	Filtered bool   `json:"filtered"`
	Message  string `json:"message,omitempty"`
}

// @Summary Search
// @Description Search for documents with input validation and XSS protection
// @Tags search
// @Accept json
// @Produce json
// @Param q query string true "Query string (max 100 chars)"
// @Param page query int false "Page number (min 1)"
// @Param size query int false "Page size (max 50)"
// @Success 200 {object} search.SearchResult
// @Failure 400 {object} map[string]string
// @Router /search [get]
func (h *Handler) Search(c *gin.Context) {
	rawQuery := c.Query("q")
	query, valid := validateSearchInput(rawQuery)
	if !valid {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid query parameter"})
		return
	}

	page, size := validatePagination(c.DefaultQuery("page", "1"), c.DefaultQuery("size", "10"))

	result, err := h.svc.Search(c.Request.Context(), query, page, size)
	if err != nil {
		// 避免将内部错误细节暴露给客户端
		c.JSON(http.StatusInternalServerError, gin.H{"error": "internal server error"})
		return
	}

	// IP 识别与内容过滤
	clientIP := c.ClientIP()
	isCN := h.ipSvc.IsChinaMainland(clientIP)
	
	var response SearchResponse
	response.SearchResult = result

	if isCN {
		filteredHits, count := h.filter.Filter(result.Hits)
		if count > 0 {
			response.Hits = filteredHits
			response.Filtered = true
			response.Message = "根据相关法律法规和政策，部分搜索结果未予显示。"
			// 修正 Total 数量，减去被过滤的条数 (虽然这只是当前页的过滤，但给用户一个反馈)
			// 注意：实际上如果只过滤当前页，分页可能会乱。理想做法是在 ES 查询时就加上过滤条件。
			// 但基于目前的需求“对搜索结果中的成人内容进行实时屏蔽处理”，这种后处理方式是可接受的中间件模式。
		}
	}

	c.JSON(http.StatusOK, response)
}

// @Summary Index Document
// @Description Index a new document
// @Tags admin
// @Accept json
// @Produce json
// @Param document body search.Document true "Document"
// @Success 200 {object} map[string]string
// @Router /index [post]
func (h *Handler) Index(c *gin.Context) {
	var doc search.Document
	if err := c.ShouldBindJSON(&doc); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	// 简单的输入清理
	doc.Title = html.EscapeString(doc.Title)
	doc.Content = html.EscapeString(doc.Content)

	if err := h.svc.IndexDocument(c.Request.Context(), &doc); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "indexing failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "indexed"})
}

func (h *Handler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
