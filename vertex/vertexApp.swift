//
//  vertexApp.swift
//  vertex
//
//  Created by yoppii on 2025/11/20.
//

import SwiftUI

@main
struct vertexApp: App {
    @StateObject private var battery = BatteryMonitor()
    
    var body: some Scene {
        MenuBarExtra {
            SystemInfoView()
        } label: {
            Text("\(battery.adapterWattage)W")
        }
        .menuBarExtraStyle(.window)
    }
}
