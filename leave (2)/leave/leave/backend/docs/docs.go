package docs

import "github.com/swaggo/swag"

const docTemplate = `{
    "schemes": {{ marshal .Schemes }},
    "swagger": "2.0",
    "info": {
        "description": "{{escape .Description}}",
        "title": "{{.Title}}",
        "contact": {},
        "version": "{{.Version}}"
    },
    "host": "{{.Host}}",
    "basePath": "{{.BasePath}}",
    "paths": {
        "/search": {
            "get": {
                "description": "Search for documents",
                "consumes": [
                    "application/json"
                ],
                "produces": [
                    "application/json"
                ],
                "tags": [
                    "search"
                ],
                "summary": "Search",
                "parameters": [
                    {
                        "type": "string",
                        "description": "Query string",
                        "name": "q",
                        "in": "query",
                        "required": true
                    },
                    {
                        "type": "integer",
                        "description": "Page number",
                        "name": "page",
                        "in": "query"
                    },
                    {
                        "type": "integer",
                        "description": "Page size",
                        "name": "size",
                        "in": "query"
                    }
                ],
                "responses": {
                    "200": {
                        "description": "OK",
                        "schema": {
                            "$ref": "#/definitions/search.SearchResult"
                        }
                    }
                }
            }
        },
        "/index": {
            "post": {
                "description": "Index a new document",
                "consumes": [
                    "application/json"
                ],
                "produces": [
                    "application/json"
                ],
                "tags": [
                    "admin"
                ],
                "summary": "Index Document",
                "parameters": [
                    {
                        "description": "Document",
                        "name": "document",
                        "in": "body",
                        "required": true,
                        "schema": {
                            "$ref": "#/definitions/search.Document"
                        }
                    }
                ],
                "responses": {
                    "200": {
                        "description": "OK",
                        "schema": {
                            "type": "object",
                            "additionalProperties": {
                                "type": "string"
                            }
                        }
                    }
                }
            }
        }
    },
    "definitions": {
        "search.Document": {
            "type": "object",
            "properties": {
                "content": {
                    "type": "string"
                },
                "id": {
                    "type": "string"
                },
                "score": {
                    "type": "number"
                },
                "timestamp": {
                    "type": "string"
                },
                "title": {
                    "type": "string"
                },
                "url": {
                    "type": "string"
                }
            }
        },
        "search.SearchResult": {
            "type": "object",
            "properties": {
                "hits": {
                    "type": "array",
                    "items": {
                        "$ref": "#/definitions/search.Document"
                    }
                },
                "suggestions": {
                    "type": "array",
                    "items": {
                        "type": "string"
                    }
                },
                "took": {
                    "type": "integer"
                },
                "total": {
                    "type": "integer"
                }
            }
        }
    }
}`

// SwaggerInfo holds exported Swagger Info so clients can modify it
var SwaggerInfo = &swag.Spec{
	Version:          "1.0",
	Host:             "localhost:8080",
	BasePath:         "/api",
	Schemes:          []string{},
	Title:            "Search Engine API",
	Description:      "High performance search engine API in Go",
	InfoInstanceName: "swagger",
	SwaggerTemplate:  docTemplate,
}

func init() {
	swag.Register(SwaggerInfo.InstanceName(), SwaggerInfo)
}
