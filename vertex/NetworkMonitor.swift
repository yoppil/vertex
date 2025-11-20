import Foundation
import Combine
import Network

class NetworkMonitor: ObservableObject {
    @Published var interfaceName: String = "Unknown"
    @Published var localIP: String = "Unknown"
    @Published var uploadSpeed: String = "0.0 KB/s"
    @Published var downloadSpeed: String = "0.0 KB/s"
    
    private var monitor: NWPathMonitor?
    private var timer: Timer?
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousTime: TimeInterval = 0
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // Monitor interface type
        monitor = NWPathMonitor()
        monitor?.pathUpdateHandler = { [weak self] path in
            self?.updateInterfaceType(path)
        }
        let queue = DispatchQueue(label: "NetworkMonitor")
        monitor?.start(queue: queue)
        
        // Monitor speed
        updateNetworkSpeed()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNetworkSpeed()
        }
    }
    
    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
        timer?.invalidate()
        timer = nil
    }
    
    private func updateInterfaceType(_ path: NWPath) {
        var name = "No Connection"
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                name = "Wi-Fi"
            } else if path.usesInterfaceType(.wiredEthernet) {
                name = "Ethernet"
            } else if path.usesInterfaceType(.cellular) {
                name = "Cellular"
            } else if path.usesInterfaceType(.loopback) {
                name = "Loopback"
            } else {
                name = "Other"
            }
        }
        
        DispatchQueue.main.async {
            self.interfaceName = name
        }
        
        // Update IP
        updateLocalIP()
    }
    
    private func updateLocalIP() {
        var address = "Unknown"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    // Filter for en0, en1, etc. usually.
                    // We want the IP of the active interface.
                    // This is a simplification; getting the *routed* IP is harder.
                    // We'll just pick the first non-loopback IPv4.
                    if addrFamily == UInt8(AF_INET) && name != "lo0" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        if getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                       &hostname, socklen_t(hostname.count),
                                       nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                            address = String(cString: hostname)
                            // Break on first found IPv4 for now
                             break 
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        DispatchQueue.main.async {
            self.localIP = address
        }
    }
    
    private func updateNetworkSpeed() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            var totalBytesIn: UInt64 = 0
            var totalBytesOut: UInt64 = 0
            
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                
                // Check for AF_LINK (link layer) to get stats
                if interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                    let name = String(cString: interface.ifa_name)
                    // Sum up all non-loopback interfaces or just en*?
                    // Let's sum all active physical interfaces (usually en*)
                    if name.hasPrefix("en") {
                        let data = unsafeBitCast(interface.ifa_data, to: UnsafeMutablePointer<if_data>.self)
                        totalBytesIn += UInt64(data.pointee.ifi_ibytes)
                        totalBytesOut += UInt64(data.pointee.ifi_obytes)
                    }
                }
            }
            freeifaddrs(ifaddr)
            
            let currentTime = Date().timeIntervalSince1970
            
            if previousTime > 0 {
                let timeDiff = currentTime - previousTime
                if timeDiff > 0 {
                    let bytesInDiff = Double(totalBytesIn - previousBytesIn)
                    let bytesOutDiff = Double(totalBytesOut - previousBytesOut)
                    
                    let downSpeed = bytesInDiff / timeDiff
                    let upSpeed = bytesOutDiff / timeDiff
                    
                    DispatchQueue.main.async {
                        self.downloadSpeed = self.formatSpeed(downSpeed)
                        self.uploadSpeed = self.formatSpeed(upSpeed)
                    }
                }
            }
            
            previousBytesIn = totalBytesIn
            previousBytesOut = totalBytesOut
            previousTime = currentTime
        }
    }
    
    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fMB/s", bytesPerSec / 1_048_576)
        } else {
            return String(format: "%.1fKB/s", bytesPerSec / 1024)
        }
    }
}
