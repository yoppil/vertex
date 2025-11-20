import Foundation

class VertexHelper: NSObject, HelperProtocol, NSXPCListenerDelegate {
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Verify the connection is from our app
        // In a real app, you should check code signing here!
        
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
    
    func setFanSpeed(index: Int, speed: Double, withReply reply: @escaping (Bool) -> Void) {
        NSLog("[VertexHelper] Received setFanSpeed request: Fan \(index), Speed \(speed)")
        
        // Use SMCKit to write to SMC
        // Based on debug, Apple Silicon uses 'flt ' (Float32) Little Endian for F{n}Tg
        
        // 1. Set Manual Mode (F{n}Md = 1)
        let modeKey = "F\(index)Md"
        let modeBytes: [UInt8] = [1]
        let modeSuccess = SMCKit.writeKey(modeKey, bytes: modeBytes)
        NSLog("[VertexHelper] Set Manual Mode (\(modeKey)): \(modeSuccess)")
        
        // 2. Set Target Speed
        let floatValue = Float(speed)
        let bitPattern = floatValue.bitPattern
        
        // Little Endian: LSB first
        let bytes: [UInt8] = [
            UInt8(bitPattern & 0xFF),
            UInt8((bitPattern >> 8) & 0xFF),
            UInt8((bitPattern >> 16) & 0xFF),
            UInt8((bitPattern >> 24) & 0xFF)
        ]
        
        let key = "F\(index)Tg"
        let success = SMCKit.writeKey(key, bytes: bytes)
        NSLog("[VertexHelper] Set Target Speed (\(key)): \(success)")
        
        reply(success)
    }
    
    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply("1.0.0")
    }
}
