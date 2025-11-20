import Foundation
import Combine
import Darwin

class CPUMonitor: ObservableObject {
    @Published var systemUsage: Double = 0.0
    @Published var userUsage: Double = 0.0
    @Published var idleUsage: Double = 0.0
    @Published var temperature: Double = 0.0
    @Published var usageHistory: [Double] = Array(repeating: 0.0, count: 300)
    
    private var previousInfo = host_cpu_load_info()
    private var timer: Timer?
    // private var smcConnection: io_connect_t = 0 // Managed by SMCKit
    
    init() {
        openSMC()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
        closeSMC()
    }
    
    func startMonitoring() {
        // Initial read
        _ = getCPULoad()
        updateTemperature()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCPUUsage()
            self?.updateTemperature()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateCPUUsage() {
        let (system, user, idle) = getCPULoad()
        DispatchQueue.main.async {
            self.systemUsage = system
            self.userUsage = user
            self.idleUsage = idle
            
            self.usageHistory.append(system + user)
            if self.usageHistory.count > 300 {
                self.usageHistory.removeFirst()
            }
        }
    }
    
    private func updateTemperature() {
        // Try to read CPU temperature keys
        // Common keys: TC0P (CPU Proximity), TC0D (CPU Die), TC0E, TC0F
        // On Apple Silicon, standard SMC keys might not work or be different.
        // This is a best-effort implementation using standard SMC keys.
        
        let temp = readSMCKey("TC0P") ?? readSMCKey("TC0D") ?? readSMCKey("TC0E") ?? 0.0
        
        DispatchQueue.main.async {
            self.temperature = temp
        }
    }
    
    // MARK: - SMC Logic
    
    private func openSMC() {
        SMCKit.open()
    }
    
    private func closeSMC() {
        SMCKit.close()
    }
    
    private func readSMCKey(_ key: String) -> Double? {
        return SMCKit.readKey(key)
    }
    
    private func getCPULoad() -> (system: Double, user: Double, idle: Double) {
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info()
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, 0, 0) }
        
        let userDiff = Double(info.cpu_ticks.0 - previousInfo.cpu_ticks.0)
        let systemDiff = Double(info.cpu_ticks.1 - previousInfo.cpu_ticks.1)
        let idleDiff = Double(info.cpu_ticks.2 - previousInfo.cpu_ticks.2)
        let niceDiff = Double(info.cpu_ticks.3 - previousInfo.cpu_ticks.3)
        
        let totalTicks = userDiff + systemDiff + idleDiff + niceDiff
        
        previousInfo = info
        
        if totalTicks == 0 { return (0, 0, 0) }
        
        // nice is usually counted as user
        let user = ((userDiff + niceDiff) / totalTicks) * 100.0
        let system = (systemDiff / totalTicks) * 100.0
        let idle = (idleDiff / totalTicks) * 100.0
        
        return (system, user, idle)
    }
}
