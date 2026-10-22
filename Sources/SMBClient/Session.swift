import Foundation

public class Session {
  private var messageId = SequenceNumber<UInt64>()
  private var sessionId: UInt64 = 0
  private(set) var treeId: UInt32 = 0

  private var isAnonymous = false
  private var signingRequired = false
  private var signingKey: Data?

  // SMB3 state.
  private var dialect: Negotiate.Dialects = .smb210
  private let clientGuid = UUID()
  private var preauthHash = Data(count: 64)   // 3.1.1 running SHA-512 pre-auth integrity hash
  private var preauthSalt = Data()
  private var cipherId: UInt16 = 0            // negotiated cipher (0 = none)
  private var signingKeyDerived: Data?        // AES-CMAC signing key (3.x)
  private var encryptionKey: Data?            // client -> server (encrypt) key
  private var decryptionKey: Data?            // server -> client (decrypt) key
  private var encryptionEnabled = false       // GCM negotiated and keys ready
  private var shouldEncrypt = false           // actively wrap outbound traffic

  private var isSMB3: Bool {
    switch dialect {
    case .smb300, .smb302, .smb311: return true
    case .smb202, .smb210: return false
    }
  }

  public private(set) var maxTransactSize: UInt32 = 0
  public private(set) var maxReadSize: UInt32 = 0
  public private(set) var maxWriteSize: UInt32 = 0

  public var server: String { connection.host }
  public private(set) var connectedTree: String?

  /// True when the most recent login resulted in a guest or anonymous (null)
  /// session — i.e. the server set SMB2_SESSION_FLAG_IS_GUEST or IS_NULL. This
  /// is set even when the caller supplied a username/password, because some
  /// servers (e.g. Samba `map to guest = Bad User`) silently map an unknown
  /// user or wrong password onto the guest account and report success. Callers
  /// that require a *real* authenticated session can inspect this to detect that
  /// their credentials were effectively rejected.
  public private(set) var isGuestSession = false

  public var onDisconnected: (Error) -> Void {
    didSet {
      connection.onDisconnected = onDisconnected
    }
  }

  private let connection: Connection

  public convenience init(host: String) {
    self.init(Connection(host: host))
  }

  public convenience init(host: String, port: Int) {
    self.init(Connection(host: host, port: port))
  }

  private init(_ connection: Connection) {
    self.connection = connection
    onDisconnected = { _ in }
  }

  func newSession() -> Session {
    let session = Session(connection)

    session.messageId = messageId
    session.sessionId = sessionId
    session.treeId = 0

    session.signingRequired = signingRequired
    session.signingKey = signingKey

    session.dialect = dialect
    session.preauthHash = preauthHash
    session.preauthSalt = preauthSalt
    session.cipherId = cipherId
    session.signingKeyDerived = signingKeyDerived
    session.encryptionKey = encryptionKey
    session.decryptionKey = decryptionKey
    session.encryptionEnabled = encryptionEnabled
    session.shouldEncrypt = shouldEncrypt
    session.isAnonymous = isAnonymous
    session.isGuestSession = isGuestSession

    session.maxTransactSize = maxTransactSize
    session.maxReadSize = maxReadSize
    session.maxWriteSize = maxWriteSize

    return session
  }

  func treeAccessor(share: String) -> TreeAccessor {
    TreeAccessor(session: self, share: share)
  }

  public func connect() async throws {
    try await connection.connect()
  }

  public func disconnect() {
    connection.disconnect()
  }

  @discardableResult
  public func negotiate(
    securityMode: Negotiate.SecurityMode = [.signingEnabled],
    dialects: [Negotiate.Dialects] = [.smb202, .smb210, .smb300, .smb302, .smb311]
  ) async throws -> Negotiate.Response {
    let offers311 = dialects.contains(.smb311)
    let offers3x = dialects.contains { [.smb300, .smb302, .smb311].contains($0) }

    var contexts = [Data]()
    if offers311 {
      preauthSalt = Crypto.randomBytes(count: 32)
      contexts.append(NegotiateContext.preauthIntegrity(salt: preauthSalt))
      contexts.append(NegotiateContext.encryption(ciphers: [Cipher.aes128gcm, Cipher.aes256gcm]))
    }
    // Reset the running pre-auth integrity hash so NEGOTIATE is always chained
    // onto a fresh 64-byte zero seed. `negotiate()` is public and a Session (and
    // its Connection) can be reused, so without this a second negotiate would
    // fold new bytes onto the previous attempt's hash and corrupt 3.1.1 key
    // derivation. No-op on the first (only verified) negotiate, which already
    // starts from a zeroed hash.
    preauthHash = Data(count: 64)

    let request = Negotiate.Request(
      messageId: messageId.next(),
      securityMode: securityMode,
      capabilities: offers3x ? [.encryption] : [],
      clientGuid: clientGuid,
      dialects: dialects,
      negotiateContexts: contexts
    )

    // NEGOTIATE is never signed or encrypted; send the raw packet so the exact
    // bytes feed the 3.1.1 pre-auth integrity hash.
    let requestData = request.encoded()
    let responseData = try await connection.send(requestData)

    // Pre-auth integrity hash (used only when 3.1.1 is negotiated): seed(0) then
    // negotiate request, then negotiate response.
    updatePreauth(requestData)
    updatePreauth(responseData)

    let response = Negotiate.Response(data: responseData)

    signingRequired = response.securityMode.contains(.signingRequired) || (securityMode.contains(.signingRequired) && response.securityMode.contains(.signingEnabled))

    dialect = Negotiate.Dialects(rawValue: response.dialectRevision) ?? .smb210
    if dialect == .smb311 {
      cipherId = response.selectedCipher ?? 0
    } else {
      // 3.0/3.0.2 use AES-128-CCM, which this client does not implement; leave
      // cipherId 0 so encryption stays off (signing still works via CMAC).
      cipherId = 0
    }

    maxTransactSize = response.maxTransactSize
    maxReadSize = response.maxReadSize
    maxWriteSize = response.maxWriteSize

    return response
  }

  @discardableResult
  public func sessionSetup(
    username: String?,
    password: String?,
    domain: String? = nil,
    workstation: String? = nil,
    requireSigning: Bool = false
  ) async throws -> SessionSetup.Response {
    let negotiateMessage = NTLM.NegotiateMessage(
      domainName: domain,
      workstationName: workstation
    )
    let securityBuffer = negotiateMessage.encoded()

    let request1 = SessionSetup.Request(
      messageId: messageId.next(),
      sessionId: 0,
      securityMode: [requireSigning ? .signingRequired : .signingEnabled],
      capabilities: [],
      previousSessionId: 0,
      securityBuffer: securityBuffer
    )
    // SESSION_SETUP req/resp are never encrypted; use raw sends so exact bytes
    // feed the 3.1.1 pre-auth integrity hash.
    let request1Data = request1.encoded()
    let response1Data = try await connection.send(request1Data)
    let response1 = SessionSetup.Response(data: response1Data)

    guard NTStatus(response1.header.status) == .moreProcessingRequired else {
      sessionId = response1.header.sessionId
      return response1
    }

    updatePreauth(request1Data)
    updatePreauth(response1Data)

    let challengeMessage = NTLM.ChallengeMessage(data: response1.buffer)

    let sessionKey = Crypto.randomBytes(count: 16) // NTLM ExportedSessionKey (KDF Ki)
    let authenticateMessage = challengeMessage.authenticateMessage(
      username: username,
      password: password,
      domain: domain,
      workstation: workstation,
      negotiateMessage: securityBuffer,
      signingKey: sessionKey
    )

    isAnonymous = (username ?? "").isEmpty && (password ?? "").isEmpty
    self.signingKey = sessionKey

    // The final SESSION_SETUP request must NOT carry the SMB2 SIGNED flag or a
    // CMAC signature. The session is still mid-authentication at this point, so
    // the server has no session key to verify a signature against: Samba routes
    // a signed request into its dispatch-time verification path and rejects the
    // still-pending session with STATUS_INVALID_HANDLE. Windows' own clients
    // likewise send the final session setup unsigned. Integrity of everything
    // after this point is guaranteed by SMB3 signing (when not encrypting) or by
    // AES-GCM encryption (when the server requires it).
    let request2 = SessionSetup.Request(
      headerFlags: [],
      messageId: messageId.next(),
      sessionId: response1.header.sessionId,
      securityMode: [.signingEnabled],
      capabilities: [],
      previousSessionId: 0,
      securityBuffer: authenticateMessage.encoded()
    )
    let request2Data = request2.encoded()

    // The pre-auth hash includes the final request (with its zeroed signature
    // field); the session keys are then derived from that hash. The final
    // SUCCESS response is NOT folded into the pre-auth hash.
    updatePreauth(request2Data)

    if isSMB3 && !isAnonymous {
      deriveKeys(sessionKey: sessionKey)
    }

    let response2Data = try await connection.send(request2Data)
    let response2 = SessionSetup.Response(data: response2Data)

    sessionId = response2.header.sessionId

    // A guest or null (anonymous) session has no cryptographically valid session
    // key: the server never verified a password, so the signing/encryption keys
    // we derived from the random NTLM ExportedSessionKey do not match the
    // server's. Per MS-SMB2 3.2.5.3.1 the client MUST NOT sign or encrypt such a
    // session. Detect this from the server's SessionFlags response rather than an
    // empty username, because callers routinely log in with the literal user
    // name "guest" (non-empty) yet are still mapped to a guest session. Signing
    // or encrypting anyway makes the server drop the connection on the first
    // request after SESSION_SETUP (e.g. TREE_CONNECT).
    if response2.sessionFlags.contains(.guest) || response2.sessionFlags.contains(.nullSession) {
      isAnonymous = true
      isGuestSession = true
    }

    // Enable encryption when AES-GCM was negotiated (satisfies "encrypt = required"),
    // but never for a guest/null session whose derived keys are not valid.
    if isSMB3, !isAnonymous,
       cipherId == Cipher.aes128gcm || cipherId == Cipher.aes256gcm,
       encryptionKey != nil, decryptionKey != nil {
      encryptionEnabled = true
      shouldEncrypt = true
      installDecryptor()
    }

    return response2
  }

  @discardableResult
  public func logoff() async throws -> Logoff.Response {
    let request = Logoff.Request(
      messageId: messageId.next(),
      sessionId: sessionId
    )

    let response = try await send(request)

    sessionId = 0

    return response
  }

  public func enumShareAll() async throws -> [Share] {
    let treeAccessor = treeAccessor(share: "IPC$")
    let session = try await treeAccessor.session()

    let createResponse = try await session.create(
      desiredAccess: [.readData, .writeData, .appendData, .readAttributes],
      fileAttributes: [.normal],
      shareAccess: [.read, .write],
      createDisposition: .open,
      createOptions: [.nonDirectoryFile],
      name: "srvsvc"
    )

    try await session.bind(fileId: createResponse.fileId)
    let ioCtlResponse = try await session.netShareEnum(fileId: createResponse.fileId)

    let rpcResponse = DCERPC.Response(data: ioCtlResponse.buffer)
    let netShareEnumResponse = NetShareEnumResponse(data: rpcResponse.stub)

    let shares = netShareEnumResponse.shareInfo1.shareInfo

    try await session.close(fileId: createResponse.fileId)

    return shares.compactMap {
      var type = Share.ShareType(rawValue: $0.type & 0x0FFFFFFF)

      if $0.type & Share.ShareType.special.rawValue != 0 {
        type.insert(.special)
      }
      if $0.type & Share.ShareType.temporary.rawValue != 0 {
        type.insert(.temporary)
      }

      return Share(name: $0.name.value, comment: $0.comment.value, type: type)
    }
  }

  @discardableResult
  public func treeConnect(path: String) async throws -> TreeConnect.Response {
    let request = TreeConnect.Request(
      messageId: messageId.next(),
      sessionId: sessionId,
      path: #"\\\#(server)\\#(path)"#
    )

    let response = try await send(request)

    treeId = response.header.treeId
    connectedTree = path

    return response
  }

  @discardableResult
  public func treeDisconnect() async throws -> TreeDisconnect.Response {
    let request = TreeDisconnect.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId
    )

    let response = try await send(request)

    treeId = 0
    connectedTree = nil

    return response
  }

  public func create(
    desiredAccess: FilePipePrinterAccessMask,
    fileAttributes: FileAttributes,
    shareAccess: Create.ShareAccess,
    createDisposition: Create.CreateDisposition,
    createOptions: Create.CreateOptions,
    name: String
  ) async throws -> Create.Response {
    let request = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: desiredAccess,
      fileAttributes: fileAttributes,
      shareAccess: shareAccess,
      createDisposition: createDisposition,
      createOptions: createOptions,
      name: name
    )

    return try await send(request)
  }

  public func read(fileId: Data, offset: UInt64) async throws -> Read.Response {
    try await read(fileId: fileId, offset: offset, length: maxReadSize)
  }

  public func read(fileId: Data, offset: UInt64, length: UInt32) async throws -> Read.Response {
    let readSize = min(length, maxReadSize)
    let creditSize = creditSize(size: readSize)

    let request = Read.Request(
      creditCharge: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId,
      offset: offset,
      length: readSize
    )

    return try await send(request)
  }

  @discardableResult
  public func write(data: Data, fileId: Data, offset: UInt64) async throws -> Write.Response {
    try await write(data: data, fileId: fileId, offset: offset, length: maxWriteSize)
  }

  @discardableResult
  public func write(data: Data, fileId: Data, offset: UInt64, length: UInt32) async throws -> Write.Response {
    let writeSize = min(length, maxWriteSize)
    let creditSize = creditSize(size: writeSize)

    let request = Write.Request(
      creditCharge: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId,
      offset: offset,
      data: data
    )

    return try await send(request)
  }

  @discardableResult
  public func close(fileId: Data) async throws -> Close.Response {
    let request = Close.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId
    )

    return try await send(request)
  }

  public func queryDirectory(path: String, pattern: String) async throws -> [FileDirectoryInformation] {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readData, .readAttributes, .synchronize],
      fileAttributes: [.directory],
      shareAccess: [.read, .write, .delete],
      createDisposition: .open,
      createOptions: [.directoryFile],
      name: path
    )

    let outputBufferLength = min(1048576, maxTransactSize)
    let creditSize = creditSize(size: outputBufferLength)
    let fileInformationClass = QueryDirectory.FileInformationClass.fileDirectoryInformation

    let queryDirectoryRequest = QueryDirectory.Request(
      creditCharge: creditSize,
      headerFlags: [.relatedOperations],
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      fileInformationClass: fileInformationClass,
      fileId: temporaryUUID,
      fileName: pattern,
      outputBufferLength: outputBufferLength
    )

    let (createResponse, queryDirectoryResponse) = try await send(createRequest, queryDirectoryRequest)

    var files: [FileDirectoryInformation] = queryDirectoryResponse.files()

    if NTStatus(createResponse.header.status) != .noMoreFiles {
      repeat {
        let fileId = createResponse.fileId

        let queryDirectoryRequest = QueryDirectory.Request(
          creditCharge: creditSize,
          messageId: messageId.next(count: UInt64(creditSize)),
          treeId: treeId,
          sessionId: sessionId,
          fileInformationClass: fileInformationClass,
          flags: [],
          fileId: fileId,
          fileName: pattern,
          outputBufferLength: outputBufferLength
        )

        let queryDirectoryResponse = try await send(queryDirectoryRequest)
        files.append(contentsOf: queryDirectoryResponse.files())

        if NTStatus(queryDirectoryResponse.header.status) == .noMoreFiles {
          break
        }
      } while true
    }

    try await close(fileId: createResponse.fileId)

    return files
  }

  public func fileStat(path: String) async throws -> Create.Response {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readData, .readAttributes, .synchronize],
      fileAttributes: [],
      shareAccess: [.read, .write, .delete],
      createDisposition: .open,
      createOptions: [],
      name: path
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    let (response, _) = try await send(createRequest, closeRequest)
    return response
  }

  public func existFile(path: String) async throws -> Bool {
    do {
      _ = try await fileStat(path: path)
      return true
    } catch let error as ErrorResponse {
      if NTStatus(error.header.status) == .objectNameNotFound {
        return false
      }
      throw error
    }
  }

  public func existDirectory(path: String) async throws -> Bool {
    do {
      let stat = try await fileStat(path: path)
      return stat.fileAttributes.contains(.directory)
    } catch let error as ErrorResponse {
      if NTStatus(error.header.status) == .objectNameNotFound {
        return false
      }
      throw error
    }
  }

  public func queryInfo(path: String, infoType: InfoType = .file, fileInfoClass: FileInfoClass = .fileAllInformation) async throws -> QueryInfo.Response {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes],
      fileAttributes: [],
      shareAccess: [.read],
      createDisposition: .open,
      createOptions: [],
      name: path
    )
    let queryInfoRequest = QueryInfo.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      infoType: infoType,
      fileInfoClass: fileInfoClass,
      fileId: temporaryUUID
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    let (_, response, _) = try await send(createRequest, queryInfoRequest, closeRequest)
    return response
  }

  @discardableResult
  public func createDirectory(path: String) async throws -> Create.Response {
    let response = try await create(
      desiredAccess: [.readData, .readAttributes],
      fileAttributes: [],
      shareAccess: [.read, .write, .delete],
      createDisposition: .create,
      createOptions: [.directoryFile],
      name: path.precomposedStringWithCanonicalMapping
    )
    try await close(fileId: response.fileId)
    return response
  }

  public func deleteDirectory(path: String) async throws {
    let files = try await queryDirectory(path: path, pattern: "*")
    for file in files {
      guard file.fileName != "." && file.fileName != ".." else {
        continue
      }

      let subpath = Pathname.join(path, file.fileName)
      if file.fileAttributes.contains(.directory) {
        try await deleteDirectory(path: subpath)
      } else {
        try await deleteFile(path: subpath)
      }
    }

    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes, .delete, .synchronize],
      fileAttributes: [.directory],
      shareAccess: [],
      createDisposition: .open,
      createOptions: [.directoryFile],
      name: path
    )
    let setInfoRequest = SetInfo.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileDispositionInformation(deletePending: true)
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(createRequest, setInfoRequest, closeRequest)
  }

  public func deleteFile(path: String) async throws {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes, .delete, .synchronize],
      fileAttributes: [.normal],
      shareAccess: [],
      createDisposition: .open,
      createOptions: [],
      name: path
    )
    let setInfoRequest = SetInfo.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileDispositionInformation(deletePending: true)
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(createRequest, setInfoRequest, closeRequest)
  }

  public func move(from: String, to: String) async throws {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes, .delete, .synchronize],
      fileAttributes: [.normal],
      shareAccess: [],
      createDisposition: .open,
      createOptions: [],
      name: from
    )
    let setInfoRequest = SetInfo.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: FileRenameInformation(fileName: to.precomposedStringWithCanonicalMapping)
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    _ = try await send(createRequest, setInfoRequest, closeRequest)
  }

  @discardableResult
  public func setInfo(path: String, _ info: FileInformationClass) async throws -> SetInfo.Response {
    let createRequest = Create.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      desiredAccess: [.readAttributes, .writeAttributes, .synchronize],
      fileAttributes: [],
      shareAccess: [.read, .write, .delete],
      createDisposition: .open,
      createOptions: [],
      name: path
    )
    let setInfoRequest = SetInfo.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID,
      infoType: .file,
      fileInformation: info
    )
    let closeRequest = Close.Request(
      headerFlags: [.relatedOperations],
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: temporaryUUID
    )

    let (_, response, _) = try await send(createRequest, setInfoRequest, closeRequest)
    return response
  }

  @discardableResult
  public func flush(fileId: Data) async throws -> Flush.Response {
    let request = Flush.Request(
      messageId: messageId.next(),
      treeId: treeId,
      sessionId: sessionId,
      fileId: fileId
    )

    return try await send(request)
  }

  @discardableResult
  public func echo() async throws -> Echo.Response {
    let request = Echo.Request(
      messageId: messageId.next(),
      sessionId: sessionId
    )

    return try await send(request)
  }

  @discardableResult
  func bind(fileId: Data) async throws -> IOCtl.Response {
    let input = DCERPC.Bind(
      callID: 1,
      context: DCERPC.ContextList(
        items: [
          DCERPC.PresentationContext(
            contextID: 0,
            abstractSyntax: DCERPC.AbstractSyntax(),
            transferSyntaxes: [
              DCERPC.TransferSyntax()
            ]
          )
        ]
      )
    )

    let creditSize = creditSize(size: maxReadSize)
    let request = IOCtl.Request(
      creditCharge: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      ctlCode: .pipeTransceive,
      fileId: fileId,
      input: input.encoded(),
      output: Data()
    )

    return try await send(request)
  }

  func netShareEnum(fileId: Data) async throws -> IOCtl.Response {
    let netShareEnum = NetShareEnum(serverName: connection.host)

    let input = DCERPC.Request(
      callID: 0,
      opnum: .netrShareEnum,
      stub: netShareEnum.encoded()
    )

    let creditSize = creditSize(size: maxReadSize)
    let request = IOCtl.Request(
      creditCharge: creditSize,
      messageId: messageId.next(count: UInt64(creditSize)),
      treeId: treeId,
      sessionId: sessionId,
      ctlCode: .pipeTransceive,
      fileId: fileId,
      input: input.encoded(),
      output: Data()
    )

    return try await send(request)
  }

  private func send<Request: Message.Request>(_ message: Request) async throws -> Request.Response {
    let packet = message.encoded()
    let data = try await connection.send(maybeEncrypt(sign(packet)))
    let response = Request.Response(data: data)
    return response
  }

#if compiler(>=5.9)
  private func send<each Request: Message.Request>(_ messages: repeat each Request) async throws -> (repeat (each Request).Response) {
    var count = 0
    for _ in repeat each messages {
      count += 1
    }

    var packet = Data()
    var index = 0
    for message in repeat each messages {
      let data = message.encoded()
      let alignment = Data(count: 8 - data.count % 8)
      if index < count - 1 {
        let body = data + alignment
        var header = Header(data: body[..<64])
        let payload = data[64...]

        header.nextCommand = UInt32(body.count)

        packet += sign(header.encoded() + payload + alignment)
      } else {
        packet += sign(data + alignment)
      }

      index += 1
    }

    let responseData = try await connection.send(maybeEncrypt(packet))
    let reader = ByteReader(responseData)

    var responses = [Data]()

    var header: Header
    var offset = 0

    repeat {
      responses.append(Data(responseData[offset...]))

      header = reader.read()

      offset += Int(header.nextCommand)
      reader.seek(to: offset)
    } while header.nextCommand != 0

    var iterator = 0
    func respond<R: Message.Request>(requestType: R.Type) -> R.Response {
      let response = R.Response(data: responses[iterator])
      iterator += 1
      return response
    }

    return (repeat respond(requestType: (each Request).self))
  }
#else
  private func send<R1: Message.Request, R2: Message.Request>(_ m1: R1, _ m2: R2) async throws -> (R1.Response, R2.Response) {
    let data = try await send(m1.encoded(), m2.encoded())
    let r1 = R1.Response(data: data)
    let r2 = R2.Response(data: Data(data[r1.header.nextCommand...]))
    return (r1, r2)
  }

  private func send<R1: Message.Request, R2: Message.Request, R3: Message.Request>(_ m1: R1, _ m2: R2, _ m3: R3) async throws -> (R1.Response, R2.Response, R3.Response) {
    let data = try await send(m1.encoded(), m2.encoded(), m3.encoded())
    let r1 = R1.Response(data: data)
    let r2 = R2.Response(data: Data(data[r1.header.nextCommand...]))
    let r3 = R3.Response(data: Data(data[r2.header.nextCommand...]))
    return (r1, r2, r3)
  }

  private func send(_ packets: Data...) async throws -> Data {
    let packet = packets.enumerated().reduce(into: Data()) {
      let alignment = Data(count: 8 - $1.element.count % 8)
      if $1.offset < packets.count - 1 {
        let packet = $1.element + alignment
        var header = Header(data: packet[..<64])
        let payload = $1.element[64...]

        header.nextCommand = UInt32(packet.count)

        $0 += sign(header.encoded() + payload + alignment)
      } else {
        $0 += sign($1.element + alignment)
      }
    }
    return try await connection.send(maybeEncrypt(packet))
  }
#endif

  private func sign(_ packet: Data) -> Data {
    // Encrypted messages are authenticated by AES-GCM; do not also sign them.
    guard !shouldEncrypt else { return packet }
    guard signingRequired, !isAnonymous else { return packet }

    var header = Header(data: packet[..<64])
    let payload = packet[64...]

    header.flags = header.flags.union(.signed)
    header.signature = Data(count: 16)

    if isSMB3, let key = signingKeyDerived {
      let signature = Data(Crypto.aesCMAC(key: key, data: header.encoded() + payload).prefix(16))
      header.signature = signature
      return header.encoded() + payload
    } else if let signingKey {
      let signature = Crypto.hmacSHA256(key: signingKey, data: header.encoded() + payload)[..<16]
      header.signature = Data(signature)
      return header.encoded() + payload
    } else {
      return packet
    }
  }

  // MARK: - SMB3 helpers

  private func updatePreauth(_ message: Data) {
    preauthHash = Crypto.sha512(preauthHash + message)
  }

  /// Derive the SMB3 signing key (and cipher keys when AES-GCM is negotiated)
  /// via the SP800-108 SMB2 KDF. `ki` is the NTLM ExportedSessionKey.
  private func deriveKeys(sessionKey ki: Data) {
    // SMB3 KDF labels are null-terminated ASCII strings (MS-SMB2 3.1.4.2; matches
    // Samba's data_blob_string_const_null and Windows). sp800108CounterKDF adds
    // the SP800-108 0x00 separator itself, so the null-terminated label yields the
    // two 0x00 bytes the wire protocol expects between label and context.
    func label(_ s: String) -> Data { s.data(using: .ascii)! + Data([0x00]) }
    let keyBits: UInt32 = (cipherId == Cipher.aes256gcm) ? 256 : 128

    if dialect == .smb311 {
      // 3.1.1: context is the pre-auth integrity hash.
      signingKeyDerived = Crypto.sp800108CounterKDF(key: ki, label: label("SMBSigningKey"), context: preauthHash, lengthInBits: 128)
      if cipherId == Cipher.aes128gcm || cipherId == Cipher.aes256gcm {
        encryptionKey = Crypto.sp800108CounterKDF(key: ki, label: label("SMBC2SCipherKey"), context: preauthHash, lengthInBits: keyBits)
        decryptionKey = Crypto.sp800108CounterKDF(key: ki, label: label("SMBS2CCipherKey"), context: preauthHash, lengthInBits: keyBits)
      }
    } else {
      // 3.0 / 3.0.2: static labels/contexts. (Encryption on these dialects uses
      // AES-CCM which is not implemented, so only the signing key is derived.)
      signingKeyDerived = Crypto.sp800108CounterKDF(key: ki, label: label("SMB2AESCMAC"), context: "SmbSign".data(using: .ascii)! + Data([0x00]), lengthInBits: 128)
    }
  }

  private func installDecryptor() {
    let key = decryptionKey
    connection.setDecryptor { data in
      guard let key else { throw ConnectionError.unknown }
      return try Session.decryptTransform(data, key: key)
    }
  }

  private func maybeEncrypt(_ plaintext: Data) -> Data {
    guard shouldEncrypt, let key = encryptionKey else { return plaintext }
    return Session.encryptTransform(plaintext, key: key, sessionId: sessionId)
  }

  /// Wrap a plaintext SMB2 message (possibly compounded) in a TRANSFORM_HEADER
  /// using AES-GCM. A random 96-bit nonce is used per message, which guarantees
  /// nonce uniqueness across cloned sessions that share the same cipher key.
  static func encryptTransform(_ plaintext: Data, key: Data, sessionId: UInt64) -> Data {
    let nonce12 = Crypto.randomBytes(count: 12)
    let nonce16 = nonce12 + Data(count: 4)
    var header = TransformHeader(
      signature: Data(count: 16),
      nonce: nonce16,
      originalMessageSize: UInt32(plaintext.count),
      flags: 0x0001,
      sessionId: sessionId
    )
    let aad = header.associatedData
    // Seal cannot fail for valid 16/32-byte keys and 12-byte nonces.
    let sealed = try! Crypto.aesGCMSeal(key: key, nonce: nonce12, plaintext: plaintext, aad: aad)
    header.signature = sealed.tag
    let out = header.encoded() + sealed.ciphertext
    return out
  }

  static func decryptTransform(_ data: Data, key: Data) throws -> Data {
    guard data.count >= TransformHeader.size else { throw ConnectionError.unknown }
    let header = TransformHeader(data: Data(data.prefix(TransformHeader.size)))
    let ciphertext = Data(data[data.index(data.startIndex, offsetBy: TransformHeader.size)...])
    let nonce12 = Data(header.nonce.prefix(12))
    let aadStart = data.index(data.startIndex, offsetBy: 20)
    let aadEnd = data.index(data.startIndex, offsetBy: TransformHeader.size)
    let aad = Data(data[aadStart..<aadEnd])
    return try Crypto.aesGCMOpen(key: key, nonce: nonce12, ciphertext: ciphertext, tag: header.signature, aad: aad)
  }
}

private class SequenceNumber<I: UnsignedInteger & FixedWidthInteger> {
  var current: I = 0

  func next(count: I = 1) -> I {
    let next = current
    current &+= count
    return next
  }
}

private func creditSize(size: UInt32) -> UInt16 {
  UInt16(truncatingIfNeeded: (size - 1) / 65536 + 1)
}
