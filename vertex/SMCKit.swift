import Foundation
import IOKit

struct SMCKit {
    private static var connection: io_connect_t = 0
    
    // MARK: - Connection Management
    
    @discardableResult
    static func open() -> Bool {
        guard connection == 0 else { return true }
        
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        
        return result == kIOReturnSuccess
    }
    
    static func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }
    
    // MARK: - Key Reading/Writing
    
    static func readKey(_ key: String) -> Double? {
        guard open() else { return nil }
        
        guard let keyInfo = getKeyInfo(key) else { return nil }
        guard let bytes = readBytes(key, size: Int(keyInfo.dataSize)) else { return nil }
        
        return parseBytes(bytes, type: keyInfo.dataType)
    }
    
    static func readBytes(_ key: String, size: Int = 32) -> [UInt8]? {
        guard open() else { return nil }
        
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToSMCKey(key)
        inputStruct.data8 = 5 // kSMCReadBytes
        inputStruct.keyInfo.dataSize = UInt32(size)
        
        var outputStruct = SMCParamStruct()
        var outputStructSize = MemoryLayout<SMCParamStruct>.size
        
        let result = IOConnectCallStructMethod(connection, 2, &inputStruct, MemoryLayout<SMCParamStruct>.size, &outputStruct, &outputStructSize)
        
        if result == kIOReturnSuccess {
            var bytes = [UInt8]()
            let mirror = Mirror(reflecting: outputStruct.bytes)
            for child in mirror.children {
                if let value = child.value as? UInt8 {
                    bytes.append(value)
                }
            }
            // The struct has 32 bytes, but we only need 'size' bytes
            return Array(bytes.prefix(size))
        }
        
        return nil
    }
    
    // NOTE: Writing requires root privileges usually
    static func writeKey(_ key: String, bytes: [UInt8]) -> Bool {
        guard open() else { return false }
        
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToSMCKey(key)
        inputStruct.data8 = 6 // kSMCWriteBytes
        inputStruct.keyInfo.dataSize = UInt32(bytes.count)
        
        // Fill inputStruct.bytes with data
        // This is a bit hacky because we can't easily iterate over the tuple
        // We'll just copy up to 32 bytes
        var tupleBytes = inputStruct.bytes
        // Unsafe pointer magic to copy array to tuple
        withUnsafeMutableBytes(of: &tupleBytes) { ptr in
            for (index, byte) in bytes.enumerated() {
                if index < ptr.count {
                    ptr[index] = byte
                }
            }
        }
        inputStruct.bytes = tupleBytes
        
        var outputStruct = SMCParamStruct()
        var outputStructSize = MemoryLayout<SMCParamStruct>.size
        
        let result = IOConnectCallStructMethod(connection, 2, &inputStruct, MemoryLayout<SMCParamStruct>.size, &outputStruct, &outputStructSize)
        
        return result == kIOReturnSuccess
    }
    
    // MARK: - Fan Specifics
    
    static func getFanCount() -> Int {
        guard let bytes = readBytes("FNum", size: 1) else { return 0 }
        return Int(bytes[0])
    }
    
    // MARK: - Helpers
    
    private static func getKeyInfo(_ key: String) -> SMCKeyInfoData? {
        var inputStruct = SMCParamStruct()
        inputStruct.key = stringToSMCKey(key)
        inputStruct.data8 = 9 // kSMCGetKeyInfo
        
        var outputStruct = SMCParamStruct()
        var outputStructSize = MemoryLayout<SMCParamStruct>.size
        
        let result = IOConnectCallStructMethod(connection, 2, &inputStruct, MemoryLayout<SMCParamStruct>.size, &outputStruct, &outputStructSize)
        
        if result == kIOReturnSuccess {
            return outputStruct.keyInfo
        }
        return nil
    }
    
    private static func stringToSMCKey(_ string: String) -> UInt32 {
        var key: UInt32 = 0
        for (index, char) in string.utf8.enumerated() {
            if index < 4 {
                key |= UInt32(char) << (24 - (8 * index))
            }
        }
        return key
    }
    
    private static func parseBytes(_ bytes: [UInt8], type: UInt32) -> Double? {
        // Convert type UInt32 back to string to check type
        let typeStr = smcKeyToString(type)
        
        switch typeStr {
        case "ui8 ":
            return Double(bytes[0])
        case "ui16":
            return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        case "ui32":
            let val = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
            return Double(val)
        case "fpe2":
            let intVal = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
            return Double(intVal) / 4.0
        case "flt ":
             // Float32 - Appears to be Little Endian on Apple Silicon for these keys
             let val = (UInt32(bytes[3]) << 24) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[1]) << 8) | UInt32(bytes[0])
             return Double(Float(bitPattern: val))
        default:
            // Fallback for unknown types, try to interpret as integer if small enough
            if bytes.count == 1 { return Double(bytes[0]) }
            if bytes.count == 2 { return Double((UInt16(bytes[0]) << 8) | UInt16(bytes[1])) }
            return nil
        }
    }
    
    private static func smcKeyToString(_ key: UInt32) -> String {
        let bytes = [
            UInt8((key >> 24) & 0xFF),
            UInt8((key >> 16) & 0xFF),
            UInt8((key >> 8) & 0xFF),
            UInt8(key & 0xFF)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }
    
    // MARK: - Structs
    
    // MARK: - Structs
    
    struct SMCVersion {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    struct SMCParamStruct {
        var key: UInt32 = 0
        var vers: SMCVersion = SMCVersion()
        var pLimitData: SMCPLimitData = SMCPLimitData()
        var keyInfo: SMCKeyInfoData = SMCKeyInfoData()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }
}
