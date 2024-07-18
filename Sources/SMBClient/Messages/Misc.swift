import Foundation

let temporaryUUID = Data(repeating: 0xFF, count: 16)

extension UUID {
  var data: Data {
    withUnsafeBytes(of: uuid) { Data($0) }
  }

  init(data: Data) {
    self = data.withUnsafeBytes { $0.load(as: UUID.self) }
  }
}
