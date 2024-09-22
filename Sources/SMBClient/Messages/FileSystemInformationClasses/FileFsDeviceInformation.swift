import Foundation

public struct FileFsDeviceInformation {
  public let deviceType: UInt32
  public let characteristics: Characteristics

  public enum DeviceType: UInt32 {
    case cdRom = 0x00000002
    case disk = 0x00000007
  }

  public struct Characteristics: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let removableMedia = Characteristics(rawValue: 0x00000001)
    public static let readOnlyDevice = Characteristics(rawValue: 0x00000002)
    public static let floppyDiskette = Characteristics(rawValue: 0x00000004)
    public static let writeOnceMedia = Characteristics(rawValue: 0x00000008)
    public static let remoteDevice = Characteristics(rawValue: 0x00000010)
    public static let deviceIsMounted = Characteristics(rawValue: 0x00000020)
    public static let virtualVolume = Characteristics(rawValue: 0x00000040)
    public static let deviceSecureOpen = Characteristics(rawValue: 0x00000100)
    public static let characteristicTsDevice = Characteristics(rawValue: 0x00001000)
    public static let characteristicWebDavDevice = Characteristics(rawValue: 0x00002000)
    public static let deviceAllowAppContainerTraversal = Characteristics(rawValue: 0x00020000)
    public static let portableDevice = Characteristics(rawValue: 0x00004000)
  }

  public init(data: Data) {
    let reader = ByteReader(data)

    deviceType = reader.read()
    characteristics = Characteristics(rawValue: reader.read())
  }
}
