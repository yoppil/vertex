//
//  vertexApp.swift
//  vertex
//
//  Created by yoppii on 2025/11/20.
//

import SwiftUI

@main
struct vertexApp: App {
    var body: some Scene {
        MenuBarExtra("Vertex", systemImage: "cpu") {
            SystemInfoView()
        }
        .menuBarExtraStyle(.window) // Use .window style for a popover-like view
    }
}
