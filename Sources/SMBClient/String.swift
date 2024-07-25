import Foundation

extension String {
  func encoded() -> Data {
    data(using: .utf16LittleEndian, allowLossyConversion: true)!
  }
}
