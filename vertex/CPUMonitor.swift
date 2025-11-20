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
        // Most temp sensors are sp78 (signed fixed point 8.8)
        // We assume sp78 for simplicity for temperature keys
        
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
