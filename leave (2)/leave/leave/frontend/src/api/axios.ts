import axios from 'axios';

// 创建 axios 实例
const api = axios.create({
  baseURL: 'http://localhost:8080/api', // 指向 Go 后端
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器
api.interceptors.request.use(
  (config) => {
    // 可以在这里添加 token
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// 响应拦截器
api.interceptors.response.use(
  (response) => {
    return response;
  },
  (error) => {
    // 统一错误处理
    if (error.response) {
      console.error('API Error:', error.response.data);
    }
    return Promise.reject(error);
  }
);

export default api;
