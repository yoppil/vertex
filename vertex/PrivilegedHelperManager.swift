import Foundation
import ServiceManagement

class PrivilegedHelperManager {
    static let shared = PrivilegedHelperManager()
    
    private var connection: NSXPCConnection?
    
    private init() {}
    
    func getConnection() -> NSXPCConnection? {
    if connection == nil {
        NSLog("[Manager] Creating new XPC connection to: com.yoppii.vertex.helper")
        connection = NSXPCConnection(machServiceName: "com.yoppii.vertex.helper", options: .privileged)
        connection?.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)
        
        connection?.invalidationHandler = { [weak self] in
            NSLog("[Manager] XPC connection invalidated")
            self?.connection = nil
        }
        
        connection?.interruptionHandler = { [weak self] in
            NSLog("[Manager] XPC connection interrupted")
            self?.connection = nil
        }
        
        connection?.resume()
        NSLog("[Manager] XPC connection resumed")
    }
    return connection
}
    
    // Note: Installation logic using SMAppService (macOS 13+)
    // This requires the Helper to be a "Daemon" bundle inside Contents/Library/LaunchServices usually,
    // or just a separate executable. For simplicity in this guide, we'll assume SMAppService.
    
    @available(macOS 13.0, *)
func installHelper() {
    let service = SMAppService.daemon(plistName: "com.yoppii.vertex.helper.plist")
    
    NSLog("[Manager] Current service status: \(service.status.rawValue)")
    
    if service.status == .notRegistered {
        do {
            try service.register()
            NSLog("[Manager] Helper registered successfully")
        } catch {
            NSLog("[Manager] Failed to register helper: \(error)")
        }
    } else {
        NSLog("[Manager] Helper already registered with status: \(service.status)")
    }
}
    
    func setFanSpeed(index: Int, speed: Double, completion: @escaping (Bool) -> Void) {
        print("[Manager] Requesting setFanSpeed: \(speed) for Fan \(index)")
        
        // Auto-install if needed (simple check)
        if #available(macOS 13.0, *) {
            installHelper()
        }
        
        guard let connection = getConnection() else {
            print("[Manager] Failed to get XPC connection")
            completion(false)
            return
        }
        
        let service = connection.remoteObjectProxyWithErrorHandler { error in
            print("[Manager] XPC Error: \(error)")
            completion(false)
        } as? HelperProtocol
        
        if service == nil {
            print("[Manager] Failed to cast remote object to HelperProtocol")
        }
        
        service?.setFanSpeed(index: index, speed: speed) { success in
            print("[Manager] setFanSpeed result: \(success)")
            completion(success)
        }
    }
}
