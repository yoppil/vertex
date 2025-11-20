import Foundation
import Combine

struct Fan: Identifiable, Equatable {
    let id: Int
    var name: String
    var currentRPM: Double
    var minRPM: Double
    var maxRPM: Double
    var targetRPM: Double
    var isManual: Bool = false
}

class FanMonitor: ObservableObject {
    @Published var fans: [Fan] = []
    private var timer: Timer?
    
    init() {
        // Initialize SMC connection
        _ = SMCKit.open()
        
        // Initial fetch to populate fans
        fetchFans()
        
        // Start polling
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
        SMCKit.close()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateFanSpeeds()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func fetchFans() {
        let count = SMCKit.getFanCount()
        var newFans: [Fan] = []
        
        for i in 0..<count {
            // Try reading current speed
            // Note: On Apple Silicon, F0Ac might be 'flt ' (Float32)
            var current = SMCKit.readKey("F\(i)Ac") ?? 0
            var minVal = SMCKit.readKey("F\(i)Mn") ?? 0
            var maxVal = SMCKit.readKey("F\(i)Mx") ?? 0
            var target = SMCKit.readKey("F\(i)Tg") ?? minVal
            
            // Safety checks to prevent Slider crash (min...max must be valid)
            if maxVal <= minVal {
                maxVal = Swift.max(minVal + 1000, 6000)
            }
            
            if target < minVal { target = minVal }
            if target > maxVal { target = maxVal }
            
            newFans.append(Fan(
                id: i,
                name: "Fan \(i + 1)",
                currentRPM: current,
                minRPM: minVal,
                maxRPM: maxVal,
                targetRPM: target
            ))
        }
        
        DispatchQueue.main.async {
            self.fans = newFans
        }
    }
    
    private func updateFanSpeeds() {
        // We only update current RPM to avoid resetting user's slider while dragging
        // unless we want to reflect external changes.
        // For now, let's just update currentRPM.
        
        for i in 0..<fans.count {
            if let current = SMCKit.readKey("F\(i)Ac") {
                DispatchQueue.main.async {
                    if i < self.fans.count {
                        self.fans[i].currentRPM = current
                    }
                }
            }
        }
    }
    
    // MARK: - Control Logic (To be connected to Helper)
    
    func setFanSpeed(index: Int, rpm: Double) {
        print("Requesting to set Fan \(index) to \(rpm) RPM")
        
        // Optimistic update for UI
        if index < fans.count {
            fans[index].targetRPM = rpm
        }
        
        PrivilegedHelperManager.shared.setFanSpeed(index: index, speed: rpm) { success in
            if success {
                print("Fan speed set successfully")
            } else {
                print("Failed to set fan speed")
            }
        }
    }
}
