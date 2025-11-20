import Foundation
import Combine
import IOKit
import IOKit.storage

class StorageMonitor: ObservableObject {
    @Published var usagePercentage: Double = 0.0
    @Published var usedSpace: String = ""
    @Published var totalSpace: String = ""
    @Published var readSpeed: String = "0.0 MB/s"
    @Published var writeSpeed: String = "0.0 MB/s"
    
    private var timer: Timer?
    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0
    private var previousTime: TimeInterval = 0
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        updateStorageUsage()
        updateDiskIO() // Initial read
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStorageUsage()
            self?.updateDiskIO()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateStorageUsage() {
        let fileURL = URL(fileURLWithPath: "/")
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            if let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity {
                let used = Int64(total) - Int64(available)
                let percentage = Double(used) / Double(total) * 100.0
                
                DispatchQueue.main.async {
                    self.usagePercentage = percentage
                    self.usedSpace = self.formatBytes(Double(used))
                    self.totalSpace = self.formatBytes(Double(total))
                }
            }
        } catch {
            print("Error retrieving storage info: \(error)")
        }
    }
    
    private func updateDiskIO() {
        // Simple IOKit approach to get total bytes read/written
        // We iterate over IOBlockStorageDriver and sum up statistics
        
        var iterator: io_iterator_t = 0
        let matchDict = IOServiceMatching("IOBlockStorageDriver")
        
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator)
        
        if result == KERN_SUCCESS {
            var totalRead: UInt64 = 0
            var totalWrite: UInt64 = 0
            
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var parent: io_registry_entry_t = 0
                let kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent)
                
                if kernResult == KERN_SUCCESS {
                    // Check if it's the internal disk (often has "Internal" property or similar, but summing all is usually okay for "System" stats)
                    // For now, we sum all block storage drivers which usually covers the main disk.
                    
                    if let statistics = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                        if let read = statistics["Bytes (Read)"] as? UInt64 {
                            totalRead += read
                        }
                        if let write = statistics["Bytes (Write)"] as? UInt64 {
                            totalWrite += write
                        }
                    }
                    IOObjectRelease(parent)
                }
                
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
            
            let currentTime = Date().timeIntervalSince1970
            
            if previousTime > 0 {
                let timeDiff = currentTime - previousTime
                if timeDiff > 0 {
                    let readDiff = Double(totalRead - previousReadBytes)
                    let writeDiff = Double(totalWrite - previousWriteBytes)
                    
                    let readSpeedVal = readDiff / timeDiff
                    let writeSpeedVal = writeDiff / timeDiff
                    
                    DispatchQueue.main.async {
                        self.readSpeed = self.formatSpeed(readSpeedVal)
                        self.writeSpeed = self.formatSpeed(writeSpeedVal)
                    }
                }
            }
            
            previousReadBytes = totalRead
            previousWriteBytes = totalWrite
            previousTime = currentTime
        }
    }
    
    private func formatBytes(_ bytes: Double) -> String {
        let gb = bytes / 1_073_741_824
        return String(format: "%.1fGB", gb)
    }
    
    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1fMB/s", bytesPerSec / 1_048_576)
        } else {
            return String(format: "%.1fKB/s", bytesPerSec / 1024)
        }
    }
}
