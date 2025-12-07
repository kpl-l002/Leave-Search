import React, { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import { 
  BarChart3, 
  Database, 
  Activity, 
  RefreshCw, 
  Settings, 
  HardDrive, 
  Clock, 
  ArrowLeft,
  AlertTriangle
} from 'lucide-react'

interface IndexStats {
  index_name: string
  document_count: number
  index_size_bytes: number
  index_size_mb: number
  last_updated: string
  additional_stats: Record<string, any>
}

interface SystemMetrics {
  timestamp: string
  index_stats: IndexStats
  system_metrics: {
    memory_usage: number
    gc_collections: {
      gen0: number
      gen1: number
      gen2: number
    }
  }
}

interface SystemInfo {
  timestamp: string
  environment: {
    machine_name: string
    processor_count: number
    os_version: string
    clr_version: string
    working_set: number
    is_64bit: boolean
  }
  application: {
    base_directory: string
    entry_assembly: string
    entry_version: string
  }
}

const AdminDashboard: React.FC = () => {
  const navigate = useNavigate()
  const [activeTab, setActiveTab] = useState<'overview' | 'indexing' | 'monitoring' | 'settings'>('overview')
  const [indexStats, setIndexStats] = useState<IndexStats | null>(null)
  const [systemMetrics, setSystemMetrics] = useState<SystemMetrics | null>(null)
  const [systemInfo, setSystemInfo] = useState<SystemInfo | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [isUpdating, setIsUpdating] = useState(false)

  useEffect(() => {
    fetchData()
    const interval = setInterval(fetchData, 30000) // 每30秒刷新一次
    return () => clearInterval(interval)
  }, [])

  const fetchData = async () => {
    try {
      // 获取索引统计信息
      const statsResponse = await fetch('/api/admin/index/stats')
      if (statsResponse.ok) {
        const statsData = await statsResponse.json()
        setIndexStats(statsData)
      }

      // 获取系统指标
      const metricsResponse = await fetch('/api/admin/metrics')
      if (metricsResponse.ok) {
        const metricsData = await metricsResponse.json()
        setSystemMetrics(metricsData)
      }

      // 获取系统信息
      const infoResponse = await fetch('/api/admin/system/info')
      if (infoResponse.ok) {
        const infoData = await infoResponse.json()
        setSystemInfo(infoData)
      }
    } catch (err) {
      console.error('获取数据失败:', err)
      setError('获取数据失败')
    }
  }

  const handleUpdateIndex = async () => {
    setIsUpdating(true)
    setError('')
    
    try {
      const response = await fetch('/api/admin/index/update', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        }
      })

      if (response.ok) {
        await fetchData() // 刷新数据
      } else {
        throw new Error('索引更新失败')
      }
    } catch (err) {
      setError('索引更新失败')
      console.error('索引更新失败:', err)
    } finally {
      setIsUpdating(false)
    }
  }

  const handleOptimizeIndex = async () => {
    setLoading(true)
    setError('')
    
    try {
      const response = await fetch('/api/admin/index/optimize', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        }
      })

      if (response.ok) {
        await fetchData() // 刷新数据
      } else {
        throw new Error('索引优化失败')
      }
    } catch (err) {
      setError('索引优化失败')
      console.error('索引优化失败:', err)
    } finally {
      setLoading(false)
    }
  }

  const formatBytes = (bytes: number) => {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('zh-CN')
  }

  const StatCard: React.FC<{
    title: string
    value: string | number
    icon: React.ReactNode
    subtitle?: string
    trend?: 'up' | 'down' | 'neutral'
  }> = ({ title, value, icon, subtitle, trend }) => (
    <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="text-2xl font-semibold text-gray-900">{value}</p>
          {subtitle && <p className="text-sm text-gray-500">{subtitle}</p>}
        </div>
        <div className="text-blue-500">
          {icon}
        </div>
      </div>
      {trend && (
        <div className="mt-2 flex items-center text-sm">
          <span className={`${
            trend === 'up' ? 'text-green-600' : 
            trend === 'down' ? 'text-red-600' : 'text-gray-600'
          }`}>
            {trend === 'up' ? '↗' : trend === 'down' ? '↘' : '→'}
          </span>
          <span className="ml-1 text-gray-500">vs 上次</span>
        </div>
      )}
    </div>
  )

  return (
    <div className="min-h-screen bg-gray-50">
      {/* 顶部导航 */}
      <div className="bg-white shadow-sm border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4">
            <div className="flex items-center">
              <button
                onClick={() => navigate('/')}
                className="text-blue-600 hover:text-blue-800 mr-4"
              >
                <ArrowLeft size={20} />
              </button>
              <h1 className="text-xl font-semibold text-gray-900">搜索引擎管理后台</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-500">
                最后更新: {systemMetrics ? formatDate(systemMetrics.timestamp) : '加载中...'}
              </span>
              <button
                onClick={fetchData}
                disabled={loading}
                className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors"
              >
                <RefreshCw size={16} className={`${loading ? 'animate-spin' : ''}`} />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* 标签页导航 */}
      <div className="bg-white border-b">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <nav className="flex space-x-8">
            {[
              { id: 'overview', label: '概览', icon: <BarChart3 size={16} /> },
              { id: 'indexing', label: '索引管理', icon: <Database size={16} /> },
              { id: 'monitoring', label: '性能监控', icon: <Activity size={16} /> },
              { id: 'settings', label: '系统设置', icon: <Settings size={16} /> }
            ].map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`flex items-center space-x-2 py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === tab.id
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                {tab.icon}
                <span>{tab.label}</span>
              </button>
            ))}
          </nav>
        </div>
      </div>

      {/* 错误信息 */}
      {error && (
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 mt-4">
          <div className="bg-red-50 border border-red-200 rounded-lg p-4">
            <div className="flex items-center">
              <AlertTriangle className="text-red-400 mr-2" size={20} />
              <p className="text-red-700">{error}</p>
            </div>
          </div>
        </div>
      )}

      {/* 内容区域 */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'overview' && (
          <div className="space-y-6">
            {/* 统计卡片 */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
              <StatCard
                title="索引文档数"
                value={indexStats?.document_count.toLocaleString() || '0'}
                icon={<Database size={24} />}
                subtitle="总计"
              />
              <StatCard
                title="索引大小"
                value={indexStats ? `${indexStats.index_size_mb} MB` : '0 MB'}
                icon={<HardDrive size={24} />}
                subtitle={indexStats ? formatBytes(indexStats.index_size_bytes) : '0 Bytes'}
              />
              <StatCard
                title="最后更新"
                value={indexStats ? formatDate(indexStats.last_updated) : '从未更新'}
                icon={<Clock size={24} />}
                subtitle="索引更新时间"
              />
              <StatCard
                title="内存使用"
                value={systemMetrics ? formatBytes(systemMetrics.system_metrics.memory_usage) : '0 Bytes'}
                icon={<Activity size={24} />}
                subtitle="系统内存"
              />
            </div>

            {/* 系统信息 */}
            {systemInfo && (
              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">系统信息</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-2">环境信息</h4>
                    <dl className="space-y-1 text-sm">
                      <div className="flex justify-between">
                        <dt className="text-gray-500">机器名:</dt>
                        <dd className="text-gray-900">{systemInfo.environment.machine_name}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">处理器数:</dt>
                        <dd className="text-gray-900">{systemInfo.environment.processor_count}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">操作系统:</dt>
                        <dd className="text-gray-900">{systemInfo.environment.os_version}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">CLR版本:</dt>
                        <dd className="text-gray-900">{systemInfo.environment.clr_version}</dd>
                      </div>
                    </dl>
                  </div>
                  <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-2">应用程序信息</h4>
                    <dl className="space-y-1 text-sm">
                      <div className="flex justify-between">
                        <dt className="text-gray-500">应用名称:</dt>
                        <dd className="text-gray-900">{systemInfo.application.entry_assembly}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">版本:</dt>
                        <dd className="text-gray-900">{systemInfo.application.entry_version}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">64位系统:</dt>
                        <dd className="text-gray-900">{systemInfo.environment.is_64bit ? '是' : '否'}</dd>
                      </div>
                    </dl>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {activeTab === 'indexing' && (
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">索引管理</h3>
              
              <div className="space-y-4">
                <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div>
                    <h4 className="font-medium text-gray-900">手动更新索引</h4>
                    <p className="text-sm text-gray-500">触发索引更新操作，重新构建搜索索引</p>
                  </div>
                  <button
                    onClick={handleUpdateIndex}
                    disabled={isUpdating}
                    className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 transition-colors flex items-center"
                  >
                    <RefreshCw size={16} className={`mr-2 ${isUpdating ? 'animate-spin' : ''}`} />
                    {isUpdating ? '更新中...' : '更新索引'}
                  </button>
                </div>

                <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div>
                    <h4 className="font-medium text-gray-900">优化索引</h4>
                    <p className="text-sm text-gray-500">优化索引结构和性能</p>
                  </div>
                  <button
                    onClick={handleOptimizeIndex}
                    disabled={loading}
                    className="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 transition-colors flex items-center"
                  >
                    <Settings size={16} className="mr-2" />
                    {loading ? '优化中...' : '优化索引'}
                  </button>
                </div>
              </div>
            </div>

            {indexStats && (
              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">索引详细信息</h3>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-2">基本信息</h4>
                    <dl className="space-y-1 text-sm">
                      <div className="flex justify-between">
                        <dt className="text-gray-500">索引名称:</dt>
                        <dd className="text-gray-900">{indexStats.index_name}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">文档数量:</dt>
                        <dd className="text-gray-900">{indexStats.document_count.toLocaleString()}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">索引大小:</dt>
                        <dd className="text-gray-900">{indexStats.index_size_mb} MB</dd>
                      </div>
                    </dl>
                  </div>
                  <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-2">统计信息</h4>
                    <dl className="space-y-1 text-sm">
                      <div className="flex justify-between">
                        <dt className="text-gray-500">最后更新:</dt>
                        <dd className="text-gray-900">{formatDate(indexStats.last_updated)}</dd>
                      </div>
                      {Object.entries(indexStats.additional_stats).map(([key, value]) => (
                        <div key={key} className="flex justify-between">
                          <dt className="text-gray-500">{key}:</dt>
                          <dd className="text-gray-900">{value}</dd>
                        </div>
                      ))}
                    </dl>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {activeTab === 'monitoring' && (
          <div className="space-y-6">
            {systemMetrics && (
              <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
                <h3 className="text-lg font-medium text-gray-900 mb-4">性能监控</h3>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-2">内存使用情况</h4>
                    <div className="space-y-2">
                      <div className="flex justify-between text-sm">
                        <span className="text-gray-500">当前使用:</span>
                        <span className="text-gray-900">{formatBytes(systemMetrics.system_metrics.memory_usage)}</span>
                      </div>
                    </div>
                  </div>
                  
                  <div>
                    <h4 className="text-sm font-medium text-gray-700 mb-2">垃圾回收统计</h4>
                    <dl className="space-y-1 text-sm">
                      <div className="flex justify-between">
                        <dt className="text-gray-500">Gen0 回收次数:</dt>
                        <dd className="text-gray-900">{systemMetrics.system_metrics.gc_collections.gen0}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">Gen1 回收次数:</dt>
                        <dd className="text-gray-900">{systemMetrics.system_metrics.gc_collections.gen1}</dd>
                      </div>
                      <div className="flex justify-between">
                        <dt className="text-gray-500">Gen2 回收次数:</dt>
                        <dd className="text-gray-900">{systemMetrics.system_metrics.gc_collections.gen2}</dd>
                      </div>
                    </dl>
                  </div>
                </div>
              </div>
            )}
          </div>
        )}

        {activeTab === 'settings' && (
          <div className="space-y-6">
            <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">系统设置</h3>
              <p className="text-gray-500">系统配置功能正在开发中...</p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default AdminDashboard