import Foundation

@objc(HelperProtocol)
protocol HelperProtocol {
    func setFanSpeed(index: Int, speed: Double, withReply reply: @escaping (Bool) -> Void)
    func getVersion(withReply reply: @escaping (String) -> Void)
}
