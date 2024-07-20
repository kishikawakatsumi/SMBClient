# SMBClient

Swift SMB client library and iOS/macOS file browser applications.

## Usage

`SMBClient` class hides the low-layer SMB protocol and provides a higher-layer interface suitable for common use cases. The following example demonstrates how to list files in a share drive on a remote SMB server.

```swift
import SMBClient

let client = SMBClient(host: "198.51.100.50")

try await client.login(username: "alice", password: "secret")
try await client.connectShare("Public")

let files = try await client.listDirectory("")
print(files.map { $0.fileName })

try await client.disconnectShare()
try await client.logoff()
```

If you want to use the low-layer SMB protocol directly, you can use the `Session` class. `Session` class provides a set of functions that correspond to SMB messages. You can get more fine-grained control over the SMB protocol.

```swift
import SMBClient

let session = Session(host: "198.51.100.50")

try await session.connect()
try await session.login(username: "alice", password: "secret")
try await session.treeConnect(path: "Public")

let files = try await session.queryDirectory(path: "", pattern: "*")
print(files.map { $0.fileName })

try await session.treeDisconnect()
try await session.logoff()
```

## Example Applications

<img width="1200" src="https://github.com/user-attachments/assets/5573ab34-645a-404e-b28f-182935b0badd" alt="macOS File Browser App">

## Installation

Add the following line to the dependencies in your `Package.swift` file:

```swift

dependencies: [
  .package(url: "https://github.com/kishikawakatsumi/SMBClient.git", .branch("main")),
]
```

## Supported Platforms

- macOS 10.15 or later
- iOS 13.0 or later

## Supported SMB Messages

- [x] NEGOTIATE
- [x] SESSION_SETUP
- [x] LOGOFF
- [x] TREE_CONNECT
- [x] TREE_DISCONNECT
- [x] CREATE
- [x] CLOSE
- [ ] FLUSH
- [x] READ
- [x] WRITE
- [ ] LOCK
- [ ] ECHO
- [ ] CANCEL
- [x] IOCTL
- [x] QUERY_DIRECTORY
- [ ] CHANGE_NOTIFY
- [x] QUERY_INFO
- [x] SET_INFO
