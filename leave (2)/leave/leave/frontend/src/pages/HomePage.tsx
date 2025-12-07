import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { Search, Settings, TrendingUp } from 'lucide-react'
import api from '../api/axios'

const HomePage: React.FC = () => {
  const [query, setQuery] = useState('')
  const [suggestions, setSuggestions] = useState<string[]>([])
  const [showSuggestions, setShowSuggestions] = useState(false)
  const [loading, setLoading] = useState(false)
  const navigate = useNavigate()

  // 热门搜索词部分已移除

  useEffect(() => {
    if (query.length > 1) {
      const timeoutId = setTimeout(() => {
        fetchSuggestions(query)
      }, 300)
      return () => clearTimeout(timeoutId)
    } else {
      setSuggestions([])
      setShowSuggestions(false)
    }
  }, [query])

  const fetchSuggestions = async (prefix: string) => {
    try {
      setLoading(true)
      const response = await api.get(`/search?q=${encodeURIComponent(prefix)}&size=0`) 
      if (response.data) {
        setSuggestions(response.data.suggestions || [])
        setShowSuggestions(true)
      }
    } catch (error) {
      console.error('获取搜索建议失败:', error)
      setSuggestions([])
    } finally {
      setLoading(false)
    }
  }

  const handleSearch = (searchQuery?: string) => {
    const finalQuery = searchQuery || query
    if (finalQuery.trim()) {
      navigate(`/search?q=${encodeURIComponent(finalQuery.trim())}`)
    }
  }

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSearch()
    }
  }

  const handleSuggestionClick = (suggestion: string) => {
    setQuery(suggestion)
    setShowSuggestions(false)
    handleSearch(suggestion)
  }

  return (
    <div className="min-h-screen bg-white flex flex-col items-center justify-center px-4 relative">
      {/* 管理后台入口 */}
      <button 
        onClick={() => navigate('/admin')}
        className="absolute top-6 right-6 text-gray-400 hover:text-search-blue transition-colors p-2"
        title="管理后台"
      >
        <Settings size={20} />
      </button>

      {/* Logo */}
      <div className="mb-12 text-center">
        <h1 className="text-5xl font-light text-gray-800 mb-4 tracking-tight">leave-search</h1>
      </div>

      {/* 搜索框 */}
      <div className="relative w-full max-w-2xl">
        <div className="relative group">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyPress={handleKeyPress}
            onFocus={() => query.length > 1 && setShowSuggestions(true)}
            onBlur={() => setTimeout(() => setShowSuggestions(false), 200)}
            placeholder="搜索..."
            className="w-full px-6 py-4 text-lg bg-white border border-gray-200 rounded-full shadow-sm hover:shadow-md focus:shadow-md focus:border-gray-300 outline-none transition-all duration-300 placeholder-gray-400"
          />
          <button
            onClick={() => handleSearch()}
            disabled={!query.trim() || loading}
            className="absolute right-3 top-1/2 transform -translate-y-1/2 p-3 text-gray-400 hover:text-search-blue rounded-full transition-colors"
          >
            {loading ? (
              <div className="animate-spin rounded-full h-5 w-5 border-2 border-gray-300 border-t-search-blue"></div>
            ) : (
              <Search size={22} />
            )}
          </button>
        </div>

        {/* 搜索建议 */}
        {showSuggestions && suggestions.length > 0 && (
          <div className="absolute top-full left-4 right-4 bg-white border border-gray-100 rounded-2xl shadow-xl mt-2 z-10 overflow-hidden py-2">
            {suggestions.map((suggestion, index) => (
              <button
                key={index}
                onClick={() => handleSuggestionClick(suggestion)}
                className="w-full text-left px-6 py-2.5 hover:bg-gray-50 transition-colors flex items-center"
              >
                <Search size={14} className="text-gray-300 mr-4" />
                <span className="text-gray-700">{suggestion}</span>
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}

export default HomePage