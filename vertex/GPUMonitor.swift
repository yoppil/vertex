import Foundation
import Combine
import IOKit

class GPUMonitor: ObservableObject {
    @Published var gpuUsage: Double = 0.0
    @Published var memoryUsage: Int64 = 0 // Bytes
    @Published var powerUsage: Double = 0.0 // Watts
    @Published var temperature: Double = 0.0 // Celsius
    
    @Published var usageHistory: [Double] = Array(repeating: 0.0, count: 300)
    
    private var timer: Timer?
    private var smcConnection: io_connect_t = 0
    
    init() {
        openSMC()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
        closeSMC()
    }
    
    func startMonitoring() {
        updateMetrics()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMetrics() {
        updateGPUUsageAndMemory()
        updatePowerAndTemperature()
    }
    
    private func updateGPUUsageAndMemory() {
        // Get all accelerators
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator)
        
        guard result == kIOReturnSuccess else { return }
        
        var totalUsage: Double = 0.0
        var totalMemory: Int64 = 0
        var deviceCount: Int = 0
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess {
                if let properties = props?.takeRetainedValue() as? [String: Any] {
                    if let stats = properties["PerformanceStatistics"] as? [String: Any] {
                        if let usage = stats["Device Utilization %"] as? Int {
                            totalUsage += Double(usage)
                            deviceCount += 1
                        }
                        
                        // Memory usage for Apple Silicon (Unified Memory)
                        if let usedMem = stats["In use system memory"] as? Int64 {
                            totalMemory += usedMem
                        } else if let vram = stats["vramUsedBytes"] as? Int64 {
                            totalMemory += vram
                        } else if let vram = stats["used_vram_bytes"] as? Int64 {
                            totalMemory += vram
                        }
                    }
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        
        let finalUsage = deviceCount > 0 ? totalUsage / Double(deviceCount) : 0.0
        
        DispatchQueue.main.async {
            self.gpuUsage = finalUsage
            self.memoryUsage = totalMemory
            
            self.usageHistory.append(finalUsage)
            if self.usageHistory.count > 300 {
                self.usageHistory.removeFirst()
            }
        }
    }
    
    private func updatePowerAndTemperature() {
        // Best effort keys for Apple Silicon and Intel
        // Temperature: TG0P (GPU Proximity), TG0D (GPU Die), Tg0P, Tg0D
        let temp = readSMCKey("TG0P") ?? readSMCKey("TG0D") ?? readSMCKey("Tg0P") ?? readSMCKey("Tg0D") ?? 0.0
        
        // Power: PCPG (GPU Power - Intel), Pg0C (GPU 0 Power - Apple Silicon?)
        // Note: Apple Silicon power metrics are often complex and might not be exposed via simple SMC keys easily without root or private frameworks.
        // We will try common keys.
        let power = readSMCKey("PCPG") ?? readSMCKey("Pg0C") ?? readSMCKey("PHPC") ?? 0.0
        
        DispatchQueue.main.async {
            self.temperature = temp
            self.powerUsage = power
        }
    }
    
    // MARK: - SMC Logic (Duplicated from CPUMonitor for self-containment)
    
    private func openSMC() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        if service != 0 {
            IOServiceOpen(service, mach_task_self_, 0, &smcConnection)
            IOObjectRelease(service)
        }
    }
    
    private func closeSMC() {
        if smcConnection != 0 {
            IOServiceClose(smcConnection)
            smcConnection = 0
        }
    }
    
    private func readSMCKey(_ key: String) -> Double? {
        guard smcConnection != 0 else { return nil }
        
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToSMCKey(key)
        inputStruct.data8 = 9 // kSMCGetKeyInfo
        
        var outputStruct = SMCParamStruct()
        var outputStructSize = MemoryLayout<SMCParamStruct>.size
        
        // Get Key Info
        var result = IOConnectCallStructMethod(smcConnection, 2, &inputStruct, MemoryLayout<SMCParamStruct>.size, &outputStruct, &outputStructSize)
        
        guard result == kIOReturnSuccess else { return nil }
        
        let keyInfo = outputStruct.keyInfo
        
        // Read Key Value
        inputStruct.keyInfo = keyInfo
        inputStruct.data8 = 5 // kSMCReadBytes
        
        result = IOConnectCallStructMethod(smcConnection, 2, &inputStruct, MemoryLayout<SMCParamStruct>.size, &outputStruct, &outputStructSize)
        
        guard result == kIOReturnSuccess else { return nil }
        
        // Convert bytes to double based on type
        // We assume sp78 (signed fixed point 8.8) or flt (float) or similar.
        // For simplicity, we handle sp78 which is common for sensors.
        // If it's different, this might need adjustment.
        
        let value = Int(outputStruct.bytes.0) * 256 + Int(outputStruct.bytes.1)
        return Double(value) / 256.0
    }
    
    private func stringToSMCKey(_ string: String) -> UInt32 {
        var key: UInt32 = 0
        for (index, char) in string.utf8.enumerated() {
            if index < 4 {
                key |= UInt32(char) << (24 - (8 * index))
            }
        }
        return key
    }
    
    struct SMCParamStruct {
        var key: UInt32 = 0
        var vers: UInt8 = 0
        var pLimitData: UInt8 = 0
        var keyInfo: SMCKeyInfoData = SMCKeyInfoData()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }
    
    struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }
}
