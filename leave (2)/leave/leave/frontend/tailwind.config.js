/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        'chinese': ['Microsoft YaHei', 'PingFang SC', 'Hiragino Sans GB', 'sans-serif'],
      },
      colors: {
        'search-blue': '#0066CC',
        'search-gray': '#5F6368',
        'search-border': '#DFE1E5',
      }
    },
  },
  plugins: [],
}