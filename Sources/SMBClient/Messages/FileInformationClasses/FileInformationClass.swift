import Foundation

public protocol FileInformationClass {
  var infoClass: FileInfoClass { get }
  func encoded() -> Data
}
