import SwiftUI

struct SystemInfoView: View {
    @StateObject private var vm = SystemMonitorViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // CPU
            Group {
                HStack {
                    Text("CPU：")
                    Text(String(format: "%.1f%%", vm.cpu.systemUsage + vm.cpu.userUsage))
                }
                .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("システム：")
                        Text(String(format: "%.1f%%", vm.cpu.systemUsage))
                    }
                    HStack {
                        Text("ユーザ：")
                        Text(String(format: "%.1f%%", vm.cpu.userUsage))
                    }
                    HStack {
                        Text("アイドル状態：")
                        Text(String(format: "%.1f%%", vm.cpu.idleUsage))
                    }
                }
                .padding(.leading, 16)
                .font(.system(size: 12))
            }
            
            Divider()
            
            // Memory
            Group {
                HStack {
                    Text("メモリ：")
                    Text(String(format: "%.0f%%", vm.memory.memoryUsagePercentage))
                }
                .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("プレッシャー：")
                        Text(String(format: "%.1f%%", vm.memory.memoryPressurePercentage))
                    }
                    HStack {
                        Text("アプリメモリ：")
                        Text(vm.memory.appMemory)
                    }
                    HStack {
                        Text("確保されているメモリ：") // Wired
                        Text(vm.memory.wiredMemory)
                    }
                    HStack {
                        Text("圧縮：")
                        Text(vm.memory.compressedMemory)
                    }
                }
                .padding(.leading, 16)
                .font(.system(size: 12))
            }
            
            Divider()
            
            // Storage
            Group {
                HStack {
                    Text("ストレージ：")
                    Text(String(format: "%.1f%%", vm.storage.usagePercentage))
                }
                .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(vm.storage.usedSpace)/\(vm.storage.totalSpace)")
                    HStack {
                        Text("Read：")
                        Text(vm.storage.readSpeed)
                    }
                    HStack {
                        Text("Write：")
                        Text(vm.storage.writeSpeed)
                    }
                }
                .padding(.leading, 16)
                .font(.system(size: 12))
            }
            
            Divider()
            
            // Battery
            Group {
                HStack {
                    Text("バッテリー：")
                    Text(String(format: "%.1f%%", vm.battery.batteryLevel))
                }
                .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("供給源：")
                        Text(vm.battery.powerSource)
                    }
                    HStack {
                        Text("最大容量：")
                        Text(String(format: "%.1f%%", vm.battery.maxCapacity))
                    }
                    HStack {
                        Text("充放電回数：")
                        Text("\(vm.battery.cycleCount)")
                    }
                    HStack {
                        Text("温度：")
                        Text(String(format: "%.1f°C", vm.battery.temperature))
                    }
                }
                .padding(.leading, 16)
                .font(.system(size: 12))
            }
            
            Divider()
            
            // Network
            Group {
                HStack {
                    Text("ネットワーク：")
                    Text(vm.network.interfaceName)
                }
                .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("ローカルIP：")
                        Text(vm.network.localIP)
                    }
                    HStack {
                        Text("アップロード：")
                        Text(vm.network.uploadSpeed)
                    }
                    HStack {
                        Text("ダウンロード：")
                        Text(vm.network.downloadSpeed)
                    }
                }
                .padding(.leading, 16)
                .font(.system(size: 12))
            }
            
            Divider()
            
            Button("Quit Vertex") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
            .padding(.top, 4)
        }
        .padding()
        .frame(width: 280)
    }
}

#Preview {
    SystemInfoView()
}
