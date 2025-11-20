import Foundation

let delegate = VertexHelper()
let listener = NSXPCListener(machServiceName: "com.yoppii.vertex.helper")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
