package ip

import (
	"net"
)

type Service struct {
	// 在实际生产中，这里会持有一个 IP 数据库的引用，例如 ip2region
}

func NewService() *Service {
	return &Service{}
}

// IsChinaMainland checks if the given IP belongs to China Mainland.
// Note: This is a simplified implementation for demonstration purposes.
// In a real production environment, you should use a reliable IP database like ip2region or GeoIP.
func (s *Service) IsChinaMainland(ipStr string) bool {
	// 处理 IPv6 本地回环
	if ipStr == "::1" {
		return true
	}

	ip := net.ParseIP(ipStr)
	if ip == nil {
		return false
	}

	// 1. 本地回环和私有 IP 视为中国大陆（方便本地测试）
	if ip.IsLoopback() || isPrivateIP(ip) {
		return true
	}

	// 2. 模拟：假设 1.x.x.x 到 100.x.x.x 范围内的 IP 是中国 IP (仅作演示)
	// 在实际项目中，这里应该查询数据库
	if ip4 := ip.To4(); ip4 != nil {
		if ip4[0] >= 1 && ip4[0] <= 100 {
			return true
		}
	}

	return false
}

func isPrivateIP(ip net.IP) bool {
	if ip4 := ip.To4(); ip4 != nil {
		return ip4[0] == 10 ||
			(ip4[0] == 172 && ip4[1] >= 16 && ip4[1] <= 31) ||
			(ip4[0] == 192 && ip4[1] == 168)
	}
	return false
}
