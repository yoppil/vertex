import SwiftUI

struct SystemInfoView: View {
    @StateObject private var vm = SystemMonitorViewModel()
    @State private var isSettingsOpen = false
    
    // Visibility Settings
    @AppStorage("showCPU") private var showCPU = true
    @AppStorage("showCPUGraph") private var showCPUGraph = true

    @AppStorage("showGPU") private var showGPU = true
    @AppStorage("showGPUGraph") private var showGPUGraph = true
    
    @AppStorage("showMemory") private var showMemory = true
    @AppStorage("showMemoryGraph") private var showMemoryGraph = true
    
    @AppStorage("showStorage") private var showStorage = true
    @AppStorage("showStorageGraph") private var showStorageGraph = true
    
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("showBatteryGraph") private var showBatteryGraph = true
    
    @AppStorage("showNetwork") private var showNetwork = true
    @AppStorage("showNetworkGraph") private var showNetworkGraph = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            Group {
                if isSettingsOpen {
                    SettingsView
                        .transition(.opacity)
                } else {
                    MonitorView
                        .transition(.opacity)
                }
            }
            .padding(12)
            .animation(.easeInOut(duration: 0.2), value: isSettingsOpen)
            
            Divider()
            
            // Footer with Settings Button
            HStack {
                Spacer()
                Button(action: {
                    withAnimation {
                        isSettingsOpen.toggle()
                    }
                }) {
                    Image(systemName: isSettingsOpen ? "checkmark.circle.fill" : "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isSettingsOpen ? "設定を閉じる" : "設定を開く")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .frame(width: 220)
    }
    
    var SettingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("表示設定")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                ToggleRow(icon: "cpu", title: "CPU", isOn: $showCPU, showGraph: $showCPUGraph)
                ToggleRow(icon: "cpu.fill", title: "GPU", isOn: $showGPU, showGraph: $showGPUGraph)
                ToggleRow(icon: "memorychip", title: "メモリ", isOn: $showMemory, showGraph: $showMemoryGraph)
                ToggleRow(icon: "internaldrive", title: "ストレージ", isOn: $showStorage, showGraph: $showStorageGraph)
                ToggleRow(icon: "battery.100", title: "バッテリー", isOn: $showBattery, showGraph: $showBatteryGraph)
                ToggleRow(icon: "network", title: "ネットワーク", isOn: $showNetwork, showGraph: $showNetworkGraph)
            }
            
            Spacer()
        }
    }
    
    var MonitorView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // CPU
            if showCPU {
                SectionView(
                    icon: "cpu",
                    title: "CPU",
                    value: String(format: "%.1f%%", vm.cpu.systemUsage + vm.cpu.userUsage),
                    graphData: showCPUGraph ? [vm.cpu.usageHistory] : nil,
                    graphColors: [.blue],
                    graphMax: 100
                ) {
                    DetailRow(label: "システム", value: String(format: "%.1f%%", vm.cpu.systemUsage))
                    DetailRow(label: "ユーザ", value: String(format: "%.1f%%", vm.cpu.userUsage))
                    DetailRow(label: "アイドル", value: String(format: "%.1f%%", vm.cpu.idleUsage))
                    DetailRow(label: "温度", value: String(format: "%.1f°C", vm.cpu.temperature))
                }
                
                if showMemory || showGPU || showStorage || showBattery || showNetwork { Divider() }
            }

            // GPU
            if showGPU {
                SectionView(
                    icon: "cpu.fill",
                    title: "GPU",
                    value: String(format: "%.1f%%", vm.gpu.gpuUsage),
                    graphData: showGPUGraph ? [vm.gpu.usageHistory] : nil,
                    graphColors: [.orange],
                    graphMax: 100
                ) {
                    DetailRow(label: "メモリ", value: ByteCountFormatter.string(fromByteCount: vm.gpu.memoryUsage, countStyle: .memory))
                    if vm.gpu.powerUsage > 0 {
                        DetailRow(label: "電力", value: String(format: "%.1fW", vm.gpu.powerUsage))
                    }
                    if vm.gpu.temperature > 0 {
                        DetailRow(label: "温度", value: String(format: "%.1f°C", vm.gpu.temperature))
                    }
                }
                
                if showMemory || showStorage || showBattery || showNetwork { Divider() }
            }
            
            // Memory
            if showMemory {
                SectionView(
                    icon: "memorychip",
                    title: "メモリ",
                    value: String(format: "%.0f%%", vm.memory.memoryUsagePercentage),
                    graphData: showMemoryGraph ? [vm.memory.usageHistory] : nil,
                    graphColors: [.purple],
                    graphMax: 100
                ) {
                    DetailRow(label: "プレッシャー", value: String(format: "%.1f%%", vm.memory.memoryPressurePercentage))
                    DetailRow(label: "アプリ", value: vm.memory.appMemory)
                    DetailRow(label: "確保", value: vm.memory.wiredMemory)
                    DetailRow(label: "圧縮", value: vm.memory.compressedMemory)
                }
                
                if showStorage || showBattery || showNetwork { Divider() }
            }
            
            // Storage
            if showStorage {
                SectionView(
                    icon: "internaldrive",
                    title: "ストレージ",
                    value: String(format: "%.1f%%", vm.storage.usagePercentage),
                    graphData: showStorageGraph ? [vm.storage.readHistory, vm.storage.writeHistory] : nil,
                    graphColors: [.cyan, .red],
                    graphMax: nil
                ) {
                    Text("\(vm.storage.usedSpace) / \(vm.storage.totalSpace)")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 8)).foregroundColor(.cyan)
                            Text(vm.storage.readSpeed).font(.system(size: 9))
                        }
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 8)).foregroundColor(.red)
                            Text(vm.storage.writeSpeed).font(.system(size: 9))
                        }
                    }
                }
                
                if showBattery || showNetwork { Divider() }
            }
            
            // Battery
            if showBattery {
                SectionView(
                    icon: "battery.100",
                    title: "バッテリー",
                    value: String(format: "%.1f%%", vm.battery.batteryLevel),
                    graphData: showBatteryGraph ? [vm.battery.levelHistory] : nil,
                    graphColors: [.green],
                    graphMax: 100
                ) {
                    DetailRow(label: "供給源", value: vm.battery.powerSource)
                    if vm.battery.adapterWattage > 0 {
                        DetailRow(label: "アダプター", value: "\(vm.battery.adapterWattage)W")
                    }
                    DetailRow(label: "最大容量", value: String(format: "%.1f%%", vm.battery.maxCapacity))
                    DetailRow(label: "充放電回数", value: "\(vm.battery.cycleCount)")
                    DetailRow(label: "温度", value: String(format: "%.1f°C", vm.battery.temperature))
                }
                
                if showNetwork { Divider() }
            }
            
            // Network
            if showNetwork {
                SectionView(
                    icon: "network",
                    title: "ネットワーク",
                    value: vm.network.interfaceName,
                    graphData: showNetworkGraph ? [vm.network.downloadHistory, vm.network.uploadHistory] : nil,
                    graphColors: [.cyan, .red],
                    graphMax: nil
                ) {
                    DetailRow(label: "IP", value: vm.network.localIP)
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down.circle.fill").font(.system(size: 8)).foregroundColor(.cyan)
                            Text(vm.network.downloadSpeed).font(.system(size: 9))
                        }
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up.circle.fill").font(.system(size: 8)).foregroundColor(.red)
                            Text(vm.network.uploadSpeed).font(.system(size: 9))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Helper Views

struct SectionView<Content: View>: View {
    let icon: String
    let title: String
    let value: String
    let graphData: [[Double]]?
    let graphColors: [Color]
    let graphMax: Double?
    let content: Content
    
    init(icon: String, title: String, value: String, graphData: [[Double]]? = nil, graphColors: [Color] = [], graphMax: Double? = nil, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.value = value
        self.graphData = graphData
        self.graphColors = graphColors
        self.graphMax = graphMax
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
            }
            
            if let data = graphData {
                GraphView(data: data, colors: graphColors, minRange: 0, maxRange: graphMax)
                    .frame(height: 30)
                    .padding(.vertical, 2)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                content
            }
            .padding(.leading, 2) // Reduced indentation for cleaner look
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label + "：")
                .foregroundColor(.secondary)
            Text(value)
                .foregroundColor(.primary)
        }
        .font(.system(size: 9))
    }
}

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    @Binding var showGraph: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 16)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            
            if isOn {
                HStack {
                    Spacer().frame(width: 24) // Indent
                    Toggle(isOn: $showGraph) {
                        Text("グラフを表示")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}

#Preview {
    SystemInfoView()
}
