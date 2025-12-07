package main

import (
	"log"

	"search-engine-backend/internal/api"
	"search-engine-backend/internal/config"
	"search-engine-backend/internal/filter"
	"search-engine-backend/internal/ip"
	"search-engine-backend/internal/search"
	_ "search-engine-backend/docs" // For Swagger
)

// @title Search Engine API
// @version 1.0
// @description High performance search engine API in Go
// @host localhost:8080
// @BasePath /api
// func main() {
func main() {
	cfg := config.Load()

	svc, err := search.NewService(cfg)
	if err != nil {
		log.Fatalf("Failed to initialize search service: %v", err)
	}
	defer svc.Close()

	// 初始化 IP 识别服务
	ipSvc := ip.NewService()

	// 初始化内容过滤服务
	filterSvc := filter.NewService()

	handler := api.NewHandler(svc, ipSvc, filterSvc)
	r := api.SetupRouter(handler)

	log.Printf("Server starting on port %s", cfg.ServerPort)
	if err := r.Run(":" + cfg.ServerPort); err != nil {
		log.Fatalf("Server failed to start: %v", err)
	}
}
