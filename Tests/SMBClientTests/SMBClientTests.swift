import XCTest
@testable import SMBClient

final class SMBClientTests: XCTestCase {
  let alice = ServerConfig(username: "Alice", password: "alipass", share: "Alice Share", sharePath: "shares/alice")
  let bob = ServerConfig(username: "Bob", password: "bobpass", share: "Bob Share", sharePath: "shares/bob")

  struct ServerConfig {
    let username: String
    let password: String
    let share: String
    let sharePath: String
  }

  func testLoginSucceeded() async throws {
    let users = [alice, bob]
    for user in users {
      let client = SMBClient(host: "localhost", port: 4445)
      try await client.login(username: user.username, password: user.password)
      try await client.logoff()
    }
  }

  func testLoginFailed() async throws {
    let credentials = [
      "Alice": "wrongpass",
      "Bob": "wrongpass",
      "Carol": "carolpass",
    ]

    for (username, password) in credentials {
      let client = SMBClient(host: "localhost", port: 4445)

      do {
        try await client.login(username: username, password: password)
        XCTFail("Login should fail")
      } catch let error as ErrorResponse {
        XCTAssertEqual(error.header.status, NTStatus.logonFailure)
      } catch {
        XCTFail("Unexpected error: \(error)")
      }
    }
  }

  func testListShares() async throws {
    let users = [alice, bob]

    let expectedShares: [String: [Share]] = [
      "Alice": [
        Share(name: "Public", comment: "", type: .diskDrive),
        Share(name: "Alice Share", comment: "", type: .diskDrive),
        Share(name: "IPC$", comment: "IPC Service (Samba Server)", type: .ipcAdmin),
      ],
      "Bob": [
        Share(name: "Public", comment: "", type: .diskDrive),
        Share(name: "Bob Share", comment: "", type: .diskDrive),
        Share(name: "IPC$", comment: "IPC Service (Samba Server)", type: .ipcAdmin),
      ],
    ]

    for user in users {
      let client = SMBClient(host: "localhost", port: 4445)
      try await client.login(username: user.username, password: user.password)
      let shares = try await client.listShares()

      for (expectedShare, actualShare) in zip(expectedShares[user.username]!, shares) {
        XCTAssertEqual(expectedShare.name, actualShare.name)
        XCTAssertEqual(expectedShare.comment, actualShare.comment)
        XCTAssertEqual(expectedShare.type, actualShare.type)
      }

      try await client.logoff()
    }
  }

  func testListDirectory01() async throws {
    let user = alice

    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let files = try await client.listDirectory(path: "")
      .filter { $0.name != "." && $0.name != ".." }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    let fileManager = FileManager()
    let testFiles = try fileManager.contentsOfDirectory(atPath: root.appending(component: user.sharePath).path(percentEncoded: false))
      .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

    for (actualFile, expectedFile) in zip(files, testFiles) {
      XCTAssertEqual(actualFile.name, expectedFile)

      var isDirectory: ObjCBool = false
      fileManager.fileExists(atPath: root.appending(component: "\(user.sharePath)/\(expectedFile)").path(percentEncoded: false), isDirectory: &isDirectory)
      XCTAssertEqual(actualFile.isDirectory, isDirectory.boolValue)
    }

    try await client.treeDisconnect()
    try await client.logoff()
  }

  func testListDirectory02() async throws {
    let user = alice

    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)

    let share = user.share
    let shareDirectory = user.sharePath
    try await client.treeConnect(path: share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    func listDirectory(share: String, shareDirectory: String, path: String) async throws {
      let files = try await client.listDirectory(path: path)
        .filter { $0.name != "." && $0.name != ".." }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

      let fileManager = FileManager()
      let testFiles = try fileManager.contentsOfDirectory(atPath: root.appending(component: "\(shareDirectory)/\(path)").path(percentEncoded: false))
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

      for (actualFile, expectedFile) in zip(files, testFiles) {
        XCTAssertEqual(actualFile.name, expectedFile)

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: root.appending(component: "\(shareDirectory)/\(path)/\(expectedFile)").path(percentEncoded: false), isDirectory: &isDirectory)
        XCTAssertEqual(actualFile.isDirectory, isDirectory.boolValue)

        if actualFile.isDirectory {
          if path.isEmpty {
            try await listDirectory(share: share, shareDirectory: shareDirectory, path: actualFile.name)
          } else {
            try await listDirectory(share: share, shareDirectory: shareDirectory, path: "\(path)/\(actualFile.name)")
          }
        }
      }
    }

    try await listDirectory(share: share, shareDirectory: shareDirectory, path: "")

    try await client.treeDisconnect()
    try await client.logoff()
  }

  func testListDirectory03() async throws {
    let user = bob
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)

    let share = user.share
    let shareDirectory = user.sharePath
    try await client.treeConnect(path: share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    func listDirectory(share: String, shareDirectory: String, path: String) async throws {
      let files = try await client.listDirectory(path: path)
        .filter { $0.name != "." && $0.name != ".." }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

      let fileManager = FileManager()
      let testFiles = try fileManager.contentsOfDirectory(atPath: root.appending(component: "\(shareDirectory)/\(path)").path(percentEncoded: false))
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

      for (actualFile, expectedFile) in zip(files, testFiles) {
        XCTAssertEqual(actualFile.name, expectedFile)

        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: root.appending(component: "\(shareDirectory)/\(path)/\(expectedFile)").path(percentEncoded: false), isDirectory: &isDirectory)
        XCTAssertEqual(isDirectory.boolValue, actualFile.isDirectory)

        if actualFile.isDirectory {
          if path.isEmpty {
            try await listDirectory(share: share, shareDirectory: shareDirectory, path: actualFile.name)
          } else {
            try await listDirectory(share: share, shareDirectory: shareDirectory, path: "\(path)/\(actualFile.name)")
          }
        }
      }
    }

    try await listDirectory(share: share, shareDirectory: shareDirectory, path: "")

    try await client.treeDisconnect()
    try await client.logoff()
  }

  func testListDirectory04() async throws {
    let users = [alice, bob]

    for user in users {
      let client = SMBClient(host: "localhost", port: 4445)
      try await client.login(username: user.username, password: user.password)

      do {
        try await client.treeConnect(path: "Nonexistent Share")
        XCTFail("Tree connect should fail")
      } catch let error as ErrorResponse {
        XCTAssertEqual(error.header.status, ErrorCodes.badNetworkName)
      } catch {
        XCTFail("Unexpected error: \(error)")
      }

      try await client.logoff()
    }
  }

  func testListDirectory05() async throws {
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: "Alice", password: "alipass")
    try await client.treeConnect(path: "Alice Share")

    do {
      _ = try await client.listDirectory(path: "Nonexistent Directory")
      XCTFail("List directory should fail")
    } catch let error as ErrorResponse {
      XCTAssertEqual(error.header.status, ErrorCodes.objectNameNotFound)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    try await client.treeDisconnect()
    try await client.logoff()
  }

  func testCreateDirectory() async throws {
    let user = alice
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let directoryName = #function
    try await client.createDirectory(path: directoryName)

    try await assertDirectoryExists(at: directoryName, client: client)

    try await client.deleteDirectory(path: directoryName)

    try await assertDirectoryDoesNotExist(at: directoryName, client: client)

    try await client.treeDisconnect()
    try await client.logoff()
  }

  func testUpload() async throws {
    let user = alice
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let length = 1024
    var data = Data(count: length)
    for i in 0..<length {
      data[i] = UInt8(arc4random_uniform(256))
    }

    let filename = #function
    try await client.upload(content: data, path: filename)

    try await assertFileExists(at: filename, client: client)

    let downloadData = try await client.download(path: filename)
    XCTAssertEqual(downloadData, data)

    try await client.deleteFile(path: filename)
    try await assertFileDoesNotExist(at: filename, client: client)

    try await client.treeDisconnect()
    try await client.logoff()
  }

  func testDownload() async throws {
    let user = bob
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let data = try await client.download(path: "test_files/file_example_JPG_1MB.jpg")

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!
    XCTAssertEqual(data, try Data(contentsOf: root.appending(component: "\(user.sharePath)/test_files/file_example_JPG_1MB.jpg")))
  }

  func testRandomRead01() async throws {
    let user = bob
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let data = try Data(contentsOf: root.appending(component: "\(user.sharePath)/test_files/file_example_TIFF_10MB.tiff"))
    let fileReader = client.fileReader(path: "test_files/file_example_TIFF_10MB.tiff")

    do {
      let readData = try await fileReader.read(offset: 0, length: 1024)
      XCTAssertEqual(readData, data[0..<1024])
    }
    do {
      let readData = try await fileReader.read(offset: 1024, length: 1024)
      XCTAssertEqual(readData, data[1024..<2048])
    }
    do {
      let readData = try await fileReader.read(offset: UInt64(data.count) - 1024, length: 1024)
      XCTAssertEqual(readData, data[(data.count - 1024)..<data.count])
    }
    do {
      let readData = try await fileReader.read(offset: UInt64(data.count) - 512, length: 1024)
      XCTAssertEqual(readData, data[(data.count - 512)..<data.count])
    }
  }

  func testRandomRead02() async throws {
    let user = bob
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let data = try Data(contentsOf: root.appending(component: "\(user.sharePath)/test_files/file_example_TIFF_10MB.tiff"))
    let fileReader = client.fileReader(path: "test_files/file_example_TIFF_10MB.tiff")

    do {
      let readData = try await fileReader.read(offset: 0)
      XCTAssertEqual(readData, data[0..<client.session.maxReadSize])
    }
    do {
      let readData = try await fileReader.read(offset: UInt64(data.count) - 4096)
      XCTAssertEqual(readData, data[(data.count - 4096)..<data.count])
    }
  }

  func testRandomRead03() async throws {
    let user = bob
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let data = try Data(contentsOf: root.appending(component: "\(user.sharePath)/test_files/file_example_MP4_1920_18MG.mp4"))
    let fileReader = client.fileReader(path: "test_files/file_example_MP4_1920_18MG.mp4")

    let maxReadSize = client.session.maxReadSize
    let megaByte: UInt32 = 1024 * 1024
    do {
      let readData = try await fileReader.read(offset: 0, length: maxReadSize + megaByte)
      XCTAssertEqual(readData, data[0..<maxReadSize + megaByte])
    }
    do {
      let readData = try await fileReader.read(offset: UInt64(megaByte), length: maxReadSize + megaByte)
      XCTAssertEqual(readData, data[megaByte..<megaByte + maxReadSize + megaByte])
    }
  }

  func testUploadFile() async throws {
    let user = alice

    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let directoryName: String = #function
    try await client.createDirectory(path: directoryName)
    try await client.upload(
      localPath: root.appending(component: "shares/bob/test_files/zip_10MB.zip"),
      remotePath: "\(directoryName)/uploaded.zip"
    )

    try await assertFileExists(at: "\(directoryName)/uploaded.zip", client: client)

    let downloadData = try await client.download(path: "\(directoryName)/uploaded.zip")

    XCTAssertEqual(
      downloadData,
      try Data(contentsOf: root.appending(component: "shares/bob/test_files/zip_10MB.zip"))
    )

    try await client.deleteDirectory(path: directoryName)
    try await assertDirectoryDoesNotExist(at: directoryName, client: client)
  }

  func testUploadDirectory01() async throws {
    let user = bob
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let directoryName = #function
    try await client.upload(
      localPath: root.appending(component: "shares/alice/test_data/dir1"),
      remotePath: "test_files/\(directoryName)"
    )

    try await assertDirectoryExists(at: "test_files/\(directoryName)", client: client)
    // let fileManager = FileManager()
    // XCTAssert(fileManager.contentsEqual(atPath: "shares/alice/test_data/dir1", andPath: "\(user.sharePath)/test_files/\(directoryName)"))

    try await client.deleteDirectory(path: "test_files/\(directoryName)")
    try await assertDirectoryDoesNotExist(at: "test_files/\(directoryName)", client: client)
  }

  func testUploadDirectory02() async throws {
    let user = bob
    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let directoryName = #function
    try await client.createDirectory(path: "test_files/\(directoryName)")

    let localPath = root.appending(component: "shares/alice/test_data/dir1")
    let remotePath = "test_files/\(directoryName)"
    try await client.upload(
      localPath: localPath,
      remotePath: "\(remotePath)/\(localPath.lastPathComponent)"
    )

    try await assertDirectoryExists(at: remotePath, client: client)

    // let fileManager = FileManager()
    // XCTAssert(
    //   fileManager.contentsEqual(atPath: localPath.path(percentEncoded: false), andPath: "\(user.sharePath)/\(remotePath)/\(localPath.lastPathComponent)")
    // )

    try await client.deleteDirectory(path: remotePath)
    try await assertDirectoryDoesNotExist(at: remotePath, client: client)
  }

  func testDeleteFile() async throws {
    let user = alice

    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let directoryName: String = #function
    try await client.createDirectory(path: directoryName)
    try await client.upload(
      localPath: root.appending(component: "shares/bob/test_files/file_example_PPT_1MB.ppt"),
      remotePath: "\(directoryName)/uploaded.ppt"
    )

    try await assertFileExists(at: "\(directoryName)/uploaded.ppt", client: client)

    let downloadData = try await client.download(path: "\(directoryName)/uploaded.ppt")
    XCTAssertEqual(
      downloadData,
      try Data(contentsOf: root.appending(component: "shares/bob/test_files/file_example_PPT_1MB.ppt"))
    )

    try await client.deleteFile(path: "\(directoryName)/uploaded.ppt")
    try await assertFileDoesNotExist(at: "\(directoryName)/uploaded.ppt", client: client)

    try await client.deleteDirectory(path: directoryName)
    try await assertDirectoryDoesNotExist(at: directoryName, client: client)
  }

  func testRenameFile() async throws {
    let user = alice

    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let directoryName: String = #function
    try await client.createDirectory(path: directoryName)
    try await client.upload(
      localPath: root.appending(component: "shares/bob/test_files/file_example_ODS_5000.ods"),
      remotePath: "\(directoryName)/uploaded.ods"
    )

    try await assertFileExists(at: "\(directoryName)/uploaded.ods", client: client)

    let downloadData = try await client.download(path: "\(directoryName)/uploaded.ods")
    XCTAssertEqual(
      downloadData,
      try Data(contentsOf: root.appending(component: "shares/bob/test_files/file_example_ODS_5000.ods"))
    )

    try await client.rename(from: "\(directoryName)/uploaded.ods", to: "\(directoryName)/renamed.ods")
    try await assertFileDoesNotExist(at: "\(directoryName)/uploaded.ods", client: client)
    try await assertFileExists(at: "\(directoryName)/renamed.ods", client: client)

    let downloadData2 = try await client.download(path: "\(directoryName)/renamed.ods")
    XCTAssertEqual(
      downloadData2,
      try Data(contentsOf: root.appending(component: "shares/bob/test_files/file_example_ODS_5000.ods"))
    )

    try await client.deleteDirectory(path: directoryName)
    try await assertDirectoryDoesNotExist(at: directoryName, client: client)
  }

  func testMoveFile() async throws {
    let user = alice

    let client = SMBClient(host: "localhost", port: 4445)
    try await client.login(username: user.username, password: user.password)
    try await client.treeConnect(path: user.share)

    let root = Bundle.module.url(forResource: "Fixtures", withExtension: nil)!

    let directoryName: String = #function
    try await client.createDirectory(path: directoryName)
    try await client.upload(
      localPath: root.appending(component: "shares/bob/test_files/file_example_PNG_2500kB.jpg"),
      remotePath: "\(directoryName)/uploaded.jpg"
    )

    try await assertFileExists(at: "\(directoryName)/uploaded.jpg", client: client)

    let downloadData = try await client.download(path: "\(directoryName)/uploaded.jpg")
    XCTAssertEqual(
      downloadData,
      try Data(contentsOf: root.appending(component: "shares/bob/test_files/file_example_PNG_2500kB.jpg"))
    )

    try await client.createDirectory(path: "\(directoryName)/subdir")
    try await client.move(from: "\(directoryName)/uploaded.jpg", to: "\(directoryName)/subdir/moved.jpg")

    try await assertFileDoesNotExist(at: "\(directoryName)/uploaded.jpg", client: client)
    try await assertFileExists(at: "\(directoryName)/subdir/moved.jpg", client: client)

    let downloadData2 = try await client.download(path: "\(directoryName)/subdir/moved.jpg")
    XCTAssertEqual(
      downloadData2,
      try Data(contentsOf: root.appending(component: "shares/bob/test_files/file_example_PNG_2500kB.jpg"))
    )

    try await client.deleteDirectory(path: directoryName)
    try await assertDirectoryDoesNotExist(at: directoryName, client: client)
  }
}

func assertFileExists(
  at path: String,
  client: SMBClient,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  let exists = try await client.existFile(path: path)
  XCTAssertTrue(exists, file: file, line: line)
}

func assertFileDoesNotExist(
  at path: String,
  client: SMBClient,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  let exists = try await client.existFile(path: path)
  XCTAssertFalse(exists, file: file, line: line)
}

func assertDirectoryExists(
  at path: String,
  client: SMBClient,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  let exists = try await client.existDirectory(path: path)
  XCTAssertTrue(exists, file: file, line: line)
}

func assertDirectoryDoesNotExist(
  at path: String,
  client: SMBClient,
  file: StaticString = #filePath,
  line: UInt = #line
) async throws {
  let exists = try await client.existDirectory(path: path)
  XCTAssertFalse(exists, file: file, line: line)
}
