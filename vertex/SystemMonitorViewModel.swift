import Foundation
import Combine

class SystemMonitorViewModel: ObservableObject {
    @Published var cpu = CPUMonitor()
    @Published var memory = MemoryMonitor()
    @Published var storage = StorageMonitor()
    @Published var battery = BatteryMonitor()
    @Published var network = NetworkMonitor()
    @Published var fan = FanMonitor()
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Forward objectWillChange from children to self
        cpu.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        memory.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        storage.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        battery.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        network.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        fan.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }
}
