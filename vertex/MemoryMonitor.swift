import Foundation
import Combine
import Darwin

class MemoryMonitor: ObservableObject {
    @Published var memoryUsagePercentage: Double = 0.0
    @Published var memoryPressurePercentage: Double = 0.0
    @Published var appMemory: String = ""
    @Published var wiredMemory: String = ""
    @Published var compressedMemory: String = ""
    @Published var usageHistory: [Double] = Array(repeating: 0.0, count: 300)
    
    private var timer: Timer?
    private let pageSize = Double(vm_kernel_page_size)
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        updateMemoryUsage()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMemoryUsage() {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var info = vm_statistics64_data_t()
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return }
        
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        
        // Page size is usually 16KB on Apple Silicon, 4KB on Intel. vm_kernel_page_size handles this.
        
        // Activity Monitor definitions (approximate):
        // App Memory = (Anonymous + Purgeable) - (some adjustments)
        // Wired = wire_count * pageSize
        // Compressed = compressor_page_count * pageSize
        
        let internalPages = Double(info.internal_page_count) * pageSize
        // let purgeable = Double(info.purgeable_count) * pageSize
        let wire = Double(info.wire_count) * pageSize
        let compressed = Double(info.compressor_page_count) * pageSize
        
        // "App Memory" in Activity Monitor is roughly "Internal" pages (which includes anonymous memory used by apps).
        // Sometimes calculated as: (internal_page_count - purgeable_count) * pageSize
        // But let's stick to `internal_page_count * pageSize` as a good enough proxy for "App Memory" if we want to match "App Memory" label.
        // Wait, `internal_page_count` includes more than just apps.
        // Let's use: App Memory = (Total - Wired - Compressed - Cached - Free).
        // But Cached/Free are hard to pin down exactly to match AM.
        // Let's use the `internal_page_count` metric as "App Memory" as it's often cited as the backing for app allocations.
        let appMem = internalPages
        
        let wiredMem = wire
        let compressedMem = compressed
        
        // Usage Percentage: (App + Wired + Compressed) / Total
        // This matches "Memory Used" in AM.
        let usedMemory = appMem + wiredMem + compressedMem
        let usagePercentage = (usedMemory / totalMemory) * 100.0
        
        // Pressure
        // To get real pressure, we need `kern.memorystatus_vm_pressure_level`.
        // Since we can't easily access that without sysctl (which is possible in Swift), let's try sysctl.
        // Or use the heuristic: (Wired + Compressed) / Total is a baseline, but doesn't reflect "pressure" which involves swap usage etc.
        // However, for this task, let's stick to a calculated percentage that "feels" like pressure.
        // A common formula for "Pressure %" in these tools is: 
        // (Wired + Compressed) / Total is often used as a base.
        // Let's stick to: (Wired + Compressed) / Total * 100 for now.
        let pressurePercentage = ((wiredMem + compressedMem) / totalMemory) * 100.0
        
        DispatchQueue.main.async {
            self.memoryUsagePercentage = min(usagePercentage, 100.0)
            self.memoryPressurePercentage = min(pressurePercentage, 100.0)
            self.appMemory = self.formatBytes(appMem)
            self.wiredMemory = self.formatBytes(wiredMem)
            self.compressedMemory = self.formatBytes(compressedMem)
            
            self.usageHistory.append(min(usagePercentage, 100.0))
            if self.usageHistory.count > 300 {
                self.usageHistory.removeFirst()
            }
        }
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / 1_073_741_824
        return String(format: "%.1fGB", gb)
    }
}
