import Foundation
import Combine
import IOKit
import IOKit.ps

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Double = 0.0
    @Published var powerSource: String = "Unknown"
    @Published var maxCapacity: Double = 0.0
    @Published var cycleCount: Int = 0
    @Published var temperature: Double = 0.0
    @Published var levelHistory: [Double] = Array(repeating: 0.0, count: 60)
    
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        updateBatteryStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBatteryStatus()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateBatteryStatus() {
        // 1. Basic Info from IOPS (Power Source, Current Level, Charging State)
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        
        var currentLevel = 0.0
        var source = "Battery"
        
        for ps in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, ps).takeUnretainedValue() as? [String: Any] {
                if let type = info[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                    if let capacity = info[kIOPSCurrentCapacityKey] as? Int,
                       let max = info[kIOPSMaxCapacityKey] as? Int {
                        currentLevel = Double(capacity) / Double(max) * 100.0
                    }
                    
                    if let state = info[kIOPSPowerSourceStateKey] as? String {
                        source = (state == kIOPSACPowerValue) ? "AC Adapter" : "Battery"
                    }
                }
            }
        }
        
        // 2. Detailed Info from IORegistry (Cycles, Temperature, Design Capacity for Health)
        var cycles = 0
        var temp = 0.0
        var health = 100.0 // Default to 100% if we can't find design capacity
        
        let matchDict = IOServiceMatching("AppleSmartBattery")
        var iterator: io_iterator_t = 0
        
        if IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == KERN_SUCCESS {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var properties: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS {
                    if let props = properties?.takeRetainedValue() as? [String: Any] {
                        
                        if let cyclesVal = props["CycleCount"] as? Int {
                            cycles = cyclesVal
                        }
                        
                        if let tempVal = props["Temperature"] as? Int {
                            // Temperature is usually in centi-Celsius (e.g. 3000 = 30.0 C)
                            temp = Double(tempVal) / 100.0
                        }
                        
                        // Calculate Health: (Current Max Capacity / Design Capacity) * 100
                        // "AppleRawMaxCapacity" is often the current true max capacity.
                        // "DesignCapacity" is the factory capacity.
                        if let currentMax = props["AppleRawMaxCapacity"] as? Int ?? props["MaxCapacity"] as? Int,
                           let designCap = props["DesignCapacity"] as? Int, designCap > 0 {
                            health = Double(currentMax) / Double(designCap) * 100.0
                        }
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        
        DispatchQueue.main.async {
            self.batteryLevel = currentLevel
            self.powerSource = source
            self.maxCapacity = health // User requested "Max Capacity: 81.0%", which implies health
            self.cycleCount = cycles
            self.temperature = temp
            
            self.levelHistory.append(currentLevel)
            if self.levelHistory.count > 60 {
                self.levelHistory.removeFirst()
            }
        }
    }
}
