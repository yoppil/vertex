import SwiftUI

struct GraphView: View {
    let data: [[Double]]
    let colors: [Color]
    let minRange: Double
    let maxRange: Double? // If nil, auto-scale
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            let allValues = data.flatMap { $0 }
            let maxValue = maxRange ?? (allValues.max() ?? 1.0)
            let effectiveMax = maxValue == 0 ? 1.0 : maxValue // Avoid division by zero
            let range = effectiveMax - minRange
            
            ZStack {
                Color.black.opacity(0.2) // Background
                
                ForEach(0..<data.count, id: \.self) { index in
                    let lineData = data[index]
                    if lineData.count > 1 {
                        // Fill Path
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: height))
                            
                            for (i, value) in lineData.enumerated() {
                                let x = width * CGFloat(i) / CGFloat(lineData.count - 1)
                                let y = height - (height * CGFloat(value - minRange) / CGFloat(range))
                                
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: height)) // Start at bottom-left
                                    path.addLine(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            
                            path.addLine(to: CGPoint(x: width, y: height)) // Close at bottom-right
                            path.closeSubpath()
                        }
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [colors[index].opacity(0.5), colors[index].opacity(0.1)]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        
                        // Line Path
                        Path { path in
                            for (i, value) in lineData.enumerated() {
                                let x = width * CGFloat(i) / CGFloat(lineData.count - 1)
                                let y = height - (height * CGFloat(value - minRange) / CGFloat(range))
                                
                                if i == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(colors[index], style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }
                }
            }
        }
    }
}
