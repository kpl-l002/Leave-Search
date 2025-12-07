import React, { useState, useEffect } from 'react'
import { useSearchParams, useNavigate } from 'react-router-dom'
import { Search, ChevronLeft, ChevronRight } from 'lucide-react'
import api from '../api/axios'

interface SearchResult {
  id: string
  title: string
  content: string
  url: string
  domain: string
  score: number
  crawlTime: string
  keywords: string[]
  snippet: string
}

interface SearchResponse {
  total: number
  hits: SearchResult[]
  suggestions: string[]
  took: number
  filtered?: boolean
  message?: string
}

const SearchResultsPage: React.FC = () => {
  const [searchParams, setSearchParams] = useSearchParams()
  const navigate = useNavigate()
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [currentPage, setCurrentPage] = useState(1)
  const [totalPages, setTotalPages] = useState(0)
  const [filterMessage, setFilterMessage] = useState('')

  useEffect(() => {
    const q = searchParams.get('q') || ''
    const page = parseInt(searchParams.get('page') || '1')
    
    if (q) {
      setQuery(q)
      setCurrentPage(page)
      search(q, page)
    } else {
      navigate('/')
    }
  }, [searchParams])

  const search = async (searchQuery: string, page: number) => {
    setLoading(true)
    setError('')
    setFilterMessage('')
    
    try {
      const response = await api.get('/search', {
        params: {
          q: searchQuery,
          page: page,
          size: 10
        }
      })

      const data: SearchResponse = response.data
      setResults(data.hits || [])
      setTotalPages(Math.ceil(data.total / 10))
      
      if (data.filtered && data.message) {
        setFilterMessage(data.message)
      }
    } catch (err) {
      setError('搜索出错，请稍后重试')
      console.error('搜索错误:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleSearch = (newQuery?: string) => {
    const searchQuery = newQuery || query
    if (searchQuery.trim()) {
      setSearchParams({ q: searchQuery.trim(), page: '1' })
    }
  }

  const handlePageChange = (newPage: number) => {
    if (newPage >= 1 && newPage <= totalPages) {
      setSearchParams({ q: query, page: newPage.toString() })
    }
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch()
    }
  }

  const formatDate = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diffTime = Math.abs(now.getTime() - date.getTime())
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
    
    if (diffDays === 1) return '昨天'
    if (diffDays < 7) return `${diffDays}天前`
    if (diffDays < 30) return `${Math.floor(diffDays / 7)}周前`
    return date.toLocaleDateString('zh-CN')
  }

  const highlightText = (text: string, query: string) => {
    if (!query) return text
    
    const regex = new RegExp(`(${query})`, 'gi')
    return text.replace(regex, '<mark class="bg-yellow-100 text-gray-900 font-medium">$1</mark>')
  }

  if (loading && results.length === 0) {
    return (
      <div className="min-h-screen bg-white">
        <div className="border-b border-gray-100 sticky top-0 bg-white/90 backdrop-blur-sm z-10">
          <div className="max-w-6xl mx-auto px-4 py-4 flex items-center gap-4">
            <button onClick={() => navigate('/')} className="text-2xl font-light text-search-blue tracking-tight">
              leave-search
            </button>
            <div className="flex-1 max-w-2xl relative">
               <input
                type="text"
                value={query}
                readOnly
                className="w-full px-5 py-2.5 bg-gray-50 border-transparent rounded-full text-gray-800 focus:bg-white focus:shadow-md transition-all outline-none"
              />
            </div>
          </div>
        </div>
        <div className="max-w-4xl mx-auto px-4 py-12">
           <div className="animate-pulse space-y-8">
             {[1, 2, 3].map(i => (
               <div key={i} className="space-y-3">
                 <div className="h-5 bg-gray-100 rounded w-1/3"></div>
                 <div className="h-4 bg-gray-50 rounded w-3/4"></div>
                 <div className="h-4 bg-gray-50 rounded w-1/2"></div>
               </div>
             ))}
           </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-white text-gray-900">
      {/* 顶部搜索栏 */}
      <div className="border-b border-gray-100 sticky top-0 bg-white/95 backdrop-blur-sm z-10">
        <div className="max-w-6xl mx-auto px-4 py-4 flex items-center gap-6">
          <button 
            onClick={() => navigate('/')} 
            className="text-2xl font-light text-search-blue tracking-tight hover:opacity-80 transition-opacity hidden sm:block"
          >
            leave-search
          </button>
          
          <div className="flex-1 max-w-2xl relative group">
            <input
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyPress={handleKeyPress}
              className="w-full px-5 py-2.5 bg-gray-100 border-transparent rounded-full text-gray-800 focus:bg-white focus:shadow-md focus:ring-1 focus:ring-gray-200 transition-all outline-none placeholder-gray-400"
            />
            <button
              onClick={() => handleSearch()}
              className="absolute right-3 top-1/2 transform -translate-y-1/2 p-1.5 text-search-blue hover:bg-blue-50 rounded-full transition-colors"
            >
              <Search size={18} />
            </button>
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto px-4 py-8">
        {/* 错误信息 */}
        {error && (
          <div className="bg-red-50 text-red-600 px-4 py-3 rounded-lg mb-6 text-sm">
            {error}
          </div>
        )}

        {/* 过滤提示信息 */}
        {filterMessage && (
          <div className="bg-yellow-50 text-yellow-800 px-4 py-3 rounded-lg mb-6 text-sm border border-yellow-200">
            {filterMessage}
          </div>
        )}

        {/* 搜索结果列表 */}
        <div className="space-y-8">
          {results.map((result) => (
            <div key={result.id} className="group">
              <div className="flex items-center text-xs text-gray-500 mb-1.5 space-x-2">
                 <span className="font-medium text-gray-700">{result.domain}</span>
                 <span className="text-gray-300">•</span>
                 <span>{formatDate(result.crawlTime)}</span>
              </div>
              <h3 className="text-xl font-normal mb-2 leading-snug">
                <a 
                  href={result.url} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-blue-700 hover:underline decoration-blue-700/30"
                  dangerouslySetInnerHTML={{ 
                    __html: highlightText(result.title, query) 
                  }}
                />
              </h3>
              <div 
                className="text-sm text-gray-600 leading-relaxed line-clamp-3"
                dangerouslySetInnerHTML={{ 
                  __html: highlightText(result.snippet, query) 
                }}
              />
            </div>
          ))}
        </div>

        {/* 无结果 */}
        {!loading && results.length === 0 && (
          <div className="py-12 text-center">
            <h3 className="text-lg text-gray-900 mb-2">未找到相关结果</h3>
            <p className="text-gray-500 text-sm">请尝试缩短关键词或改用其他词汇</p>
          </div>
        )}

        {/* 分页 */}
        {totalPages > 1 && (
          <div className="flex justify-center items-center space-x-2 mt-12 mb-12">
            <button
              onClick={() => handlePageChange(currentPage - 1)}
              disabled={currentPage <= 1}
              className="p-2 rounded-full hover:bg-gray-100 disabled:opacity-30 disabled:hover:bg-transparent transition-colors"
            >
              <ChevronLeft size={20} />
            </button>
            
            <div className="flex items-center space-x-1">
              <span className="text-sm text-gray-500">
                第 {currentPage} 页 / 共 {totalPages} 页
              </span>
            </div>
            
            <button
              onClick={() => handlePageChange(currentPage + 1)}
              disabled={currentPage >= totalPages}
              className="p-2 rounded-full hover:bg-gray-100 disabled:opacity-30 disabled:hover:bg-transparent transition-colors"
            >
              <ChevronRight size={20} />
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

export default SearchResultsPage