import Foundation

enum Pathname {
  public static func join(_ paths: String...) -> String {
    guard let first = paths.first else { return "" }
    if first.isEmpty {
      return paths.dropFirst().joined(separator: #"\"#)
    } else {
      return paths.joined(separator: #"\"#)
    }
  }

  static func normalize(_ path: String) -> String {
    path
      .trimmingCharacters(in: CharacterSet(charactersIn: #"/\"#))
      .replacingOccurrences(of: "/", with: #"\"#)
  }
}
