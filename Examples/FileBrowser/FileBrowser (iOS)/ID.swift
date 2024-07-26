import Foundation

struct ID: RawRepresentable, Codable {
  var rawValue: String

  init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension ID: ExpressibleByStringLiteral {
  init(stringLiteral value: String) {
    self.init(value)
  }
}

extension ID: Hashable {
  static func == (lhs: ID, rhs: ID) -> Bool {
    Data(lhs.rawValue.utf8) == Data(rhs.rawValue.utf8)
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(Data(rawValue.utf8))
  }
}
