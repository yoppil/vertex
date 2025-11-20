import Foundation
import Combine
import Darwin

class CPUMonitor: ObservableObject {
    @Published var systemUsage: Double = 0.0
    @Published var userUsage: Double = 0.0
    @Published var idleUsage: Double = 0.0
    
    private var previousInfo = host_cpu_load_info()
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // Initial read
        getCPULoad()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCPUUsage()
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
        }
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
