//////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Websocket.swift
//
//  Created by Dalton Cherry on 7/16/14.
//
//////////////////////////////////////////////////////////////////////////////////////////////////

import Foundation
import CoreFoundation
import Security

public protocol WebSocketDelegate: class {
    func websocketDidConnect(_ socket: WebSocket)
    func websocketDidDisconnect(_ socket: WebSocket, error: NSError?)
    func websocketDidReceiveMessage(_ socket: WebSocket, text: String)
    func websocketDidReceiveData(_ socket: WebSocket, data: Data)
}

public protocol WebSocketPongDelegate: class {
    func websocketDidReceivePong(_ socket: WebSocket)
}

open class WebSocket : NSObject, StreamDelegate {
    
    enum OpCode : UInt8 {
        case continueFrame = 0x0
        case textFrame = 0x1
        case binaryFrame = 0x2
        //3-7 are reserved.
        case connectionClose = 0x8
        case ping = 0x9
        case pong = 0xA
        //B-F reserved.
    }
    
    enum CloseCode : UInt16 {
        case normal                 = 1000
        case goingAway              = 1001
        case protocolError          = 1002
        case protocolUnhandledType  = 1003
        // 1004 reserved.
        case noStatusReceived       = 1005
        //1006 reserved.
        case encoding               = 1007
        case policyViolated         = 1008
        case messageTooBig          = 1009
    }

    enum InternalErrorCode : UInt16 {
        // 0-999 WebSocket status codes not used
        case outputStreamWriteError  = 1
    }

    //Where the callback is executed. It defaults to the main UI thread queue.
    open var queue            = DispatchQueue.main

    var optionalProtocols       : Array<String>?
    //Constant Values.
    let headerWSUpgradeName     = "Upgrade"
    let headerWSUpgradeValue    = "websocket"
    let headerWSHostName        = "Host"
    let headerWSConnectionName  = "Connection"
    let headerWSConnectionValue = "Upgrade"
    let headerWSProtocolName    = "Sec-WebSocket-Protocol"
    let headerWSVersionName     = "Sec-WebSocket-Version"
    let headerWSVersionValue    = "13"
    let headerWSKeyName         = "Sec-WebSocket-Key"
    let headerOriginName        = "Origin"
    let headerWSAcceptName      = "Sec-WebSocket-Accept"
    let BUFFER_MAX              = 4096
    let FinMask: UInt8          = 0x80
    let OpCodeMask: UInt8       = 0x0F
    let RSVMask: UInt8          = 0x70
    let MaskMask: UInt8         = 0x80
    let PayloadLenMask: UInt8   = 0x7F
    let MaxFrameSize: Int       = 32
    
    class WSResponse {
        var isFin = false
        var code: OpCode = .continueFrame
        var bytesLeft = 0
        var frameCount = 0
        var buffer: NSMutableData?
    }
    
    open weak var delegate: WebSocketDelegate?
    open weak var pongDelegate: WebSocketPongDelegate?
    open var onConnect: ((Void) -> Void)?
    open var onDisconnect: ((NSError?) -> Void)?
    open var onText: ((String) -> Void)?
    open var onData: ((Data) -> Void)?
    open var onPong: ((Void) -> Void)?
    open var headers = Dictionary<String,String>()
    open var voipEnabled = false
    open var selfSignedSSL = false
    open var security: SSLSecurity?
    open var enabledSSLCipherSuites: [SSLCipherSuite]?
    open var isConnected :Bool {
        return connected
    }
    fileprivate var url: URL
    fileprivate var inputStream: InputStream?
    fileprivate var outputStream: OutputStream?
    fileprivate var isRunLoop = false
    fileprivate var connected = false
    fileprivate var isCreated = false
    fileprivate var writeQueue = OperationQueue()
    fileprivate var readStack = Array<WSResponse>()
    fileprivate var inputQueue = Array<Data>()
    fileprivate var fragBuffer: Data?
    fileprivate var certValidated = false
    fileprivate var didDisconnect = false
    
    //init the websocket with a url
    public init(url: URL) {
        self.url = url
        writeQueue.maxConcurrentOperationCount = 1
    }
    //used for setting protocols.
    public convenience init(url: URL, protocols: Array<String>) {
        self.init(url: url)
        optionalProtocols = protocols
    }
    
    ///Connect to the websocket server on a background thread
    open func connect() {
        if isCreated {
            return
        }
        queue.async(execute: { [weak self] in
            self?.didDisconnect = false
        })
        DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: { [weak self] in
            self?.isCreated = true
            self?.createHTTPRequest()
            self?.isCreated = false
        })
    }
    
    ///disconnect from the websocket server
    open func disconnect() {
        writeError(CloseCode.normal.rawValue)
    }
    
    ///write a string to the websocket. This sends it as a text frame.
    open func writeString(_ str: String) {
        dequeueWrite(str.data(using: String.Encoding.utf8)!, code: .textFrame)
    }
    
    ///write binary data to the websocket. This sends it as a binary frame.
    open func writeData(_ data: Data) {
        dequeueWrite(data, code: .binaryFrame)
    }
    
    //write a   ping   to the websocket. This sends it as a  control frame.
    //yodel a   sound  to the planet.    This sends it as an astroid. http://youtu.be/Eu5ZJELRiJ8?t=42s
    open func writePing(_ data: Data) {
        dequeueWrite(data, code: .ping)
    }
    //private methods below!
    
    //private method that starts the connection
    fileprivate func createHTTPRequest() {
        
        let urlRequest = CFHTTPMessageCreateRequest(kCFAllocatorDefault, "GET" as CFString,
            url as CFURL, kCFHTTPVersion1_1).takeRetainedValue()
        
        var port = (url as NSURL).port
        if port == nil {
            if url.scheme == "wss" || url.scheme == "https" {
                port = 443
            } else {
                port = 80
            }
        }
        addHeader(urlRequest, key: headerWSUpgradeName, val: headerWSUpgradeValue)
        addHeader(urlRequest, key: headerWSConnectionName, val: headerWSConnectionValue)
        if let protocols = optionalProtocols {
            addHeader(urlRequest, key: headerWSProtocolName, val: protocols.joined(separator: ","))
        }
        addHeader(urlRequest, key: headerWSVersionName, val: headerWSVersionValue)
        addHeader(urlRequest, key: headerWSKeyName, val: generateWebSocketKey())
        addHeader(urlRequest, key: headerOriginName, val: url.absoluteString)
        addHeader(urlRequest, key: headerWSHostName, val: "\(url.host!):\(port!)")
        for (key,value) in headers {
            addHeader(urlRequest, key: key, val: value)
        }
        if let cfHTTPMessage = CFHTTPMessageCopySerializedMessage(urlRequest) {
            let serializedRequest = cfHTTPMessage.takeRetainedValue()
            initStreamsWithData(serializedRequest as Data, Int(port!))
        }
    }
    //Add a header to the CFHTTPMessage by using the NSString bridges to CFString
    fileprivate func addHeader(_ urlRequest: CFHTTPMessage,key: String, val: String) {
        let nsKey: NSString = key as NSString
        let nsVal: NSString = val as NSString
        CFHTTPMessageSetHeaderFieldValue(urlRequest,
            nsKey,
            nsVal)
    }
    //generate a websocket key as needed in rfc
    fileprivate func generateWebSocketKey() -> String {
        var key = ""
        let seed = 16
        for (i in 0 ..< seed) {
            let uni = UnicodeScalar(UInt32(97 + arc4random_uniform(25)))
            key += "\(Character(uni!))"
        }
        let data = key.data(using: String.Encoding.utf8)
        let baseKey = data?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        return baseKey!
    }
    //Start the stream connection and write the data to the output stream
    fileprivate func initStreamsWithData(_ data: Data, _ port: Int) {
        //higher level API we will cut over to at some point
        //NSStream.getStreamsToHostWithName(url.host, port: url.port.integerValue, inputStream: &inputStream, outputStream: &outputStream)
        
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        let h: NSString = url.host! as NSString
        CFStreamCreatePairWithSocketToHost(nil, h, UInt32(port), &readStream, &writeStream)
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        guard let inStream = inputStream, let outStream = outputStream else { return }
        inStream.delegate = self
        outStream.delegate = self
        if url.scheme == "wss" || url.scheme == "https" {
            inStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: Stream.PropertyKey.socketSecurityLevelKey)
            outStream.setProperty(StreamSocketSecurityLevel.negotiatedSSL, forKey: Stream.PropertyKey.socketSecurityLevelKey)
        } else {
            certValidated = true //not a https session, so no need to check SSL pinning
        }
        if voipEnabled {
            inStream.setProperty(StreamNetworkServiceTypeValue.voIP, forKey: Stream.PropertyKey.networkServiceType)
            outStream.setProperty(StreamNetworkServiceTypeValue.voIP, forKey: Stream.PropertyKey.networkServiceType)
        }
        if selfSignedSSL {
            let settings: Dictionary<NSObject, NSObject> = [kCFStreamSSLValidatesCertificateChain: NSNumber(value: false as Bool), kCFStreamSSLPeerName: kCFNull]
            inStream.setProperty(settings, forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLSettings as String as String))
            outStream.setProperty(settings, forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLSettings as String as String))
        }
        if let cipherSuites = self.enabledSSLCipherSuites {
            if let sslContextIn = CFReadStreamCopyProperty(inputStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLContext)) as! SSLContext?,
                   let sslContextOut = CFWriteStreamCopyProperty(outputStream, CFStreamPropertyKey(rawValue: kCFStreamPropertySSLContext)) as! SSLContext? {
                let resIn = SSLSetEnabledCiphers(sslContextIn, cipherSuites, cipherSuites.count)
                let resOut = SSLSetEnabledCiphers(sslContextOut, cipherSuites, cipherSuites.count)
                if (resIn != errSecSuccess) {
                    let error = self.errorWithDetail("Error setting ingoing cypher suites", code: UInt16(resIn))
                    disconnectStream(error)
                    return
                }
                if (resOut != errSecSuccess) {
                    let error = self.errorWithDetail("Error setting outgoing cypher suites", code: UInt16(resOut))
                    disconnectStream(error)
                    return
                }
            }
        }
        isRunLoop = true
        inStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        outStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
        inStream.open()
        outStream.open()
        let bytes = (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)
        outStream.write(bytes, maxLength: data.count)
        while(isRunLoop) {
            RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture as Date)
        }
    }
    //delegate for the stream methods. Processes incoming bytes
    open func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        
        if let sec = security, !certValidated && (eventCode == .hasBytesAvailable || eventCode == .hasSpaceAvailable) {
            let possibleTrust: AnyObject? = aStream.property(forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLPeerTrust as String as String)) as AnyObject?
            if let trust: AnyObject = possibleTrust {
                let domain: AnyObject? = aStream.property(forKey: Stream.PropertyKey(rawValue: kCFStreamSSLPeerName as String as String)) as AnyObject?
                if sec.isValid(trust as! SecTrust, domain: domain as! String?) {
                    certValidated = true
                } else {
                    let error = errorWithDetail("Invalid SSL certificate", code: 1)
                    disconnectStream(error)
                    return
                }
            }
        }
        if eventCode == .hasBytesAvailable {
            if(aStream == inputStream) {
                processInputStream()
            }
        } else if eventCode == .errorOccurred {
            disconnectStream(aStream.streamError as NSError?)
        } else if eventCode == .endEncountered {
            disconnectStream(nil)
        }
    }
    //disconnect the stream object
    fileprivate func disconnectStream(_ error: NSError?) {
        writeQueue.waitUntilAllOperationsAreFinished()
        if let stream = inputStream {
            stream.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            stream.close()
        }
        if let stream = outputStream {
            stream.remove(from: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            stream.close()
        }        
        outputStream = nil
        isRunLoop = false
        certValidated = false
        doDisconnect(error)
        connected = false
    }
    
    ///handles the incoming bytes and sending them to the proper processing method
    fileprivate func processInputStream() {
        let buf = NSMutableData(capacity: BUFFER_MAX)
        let buffer = UnsafeMutablePointer<UInt8>(mutating: buf!.bytes.bindMemory(to: UInt8.self, capacity: buf!.count))
        let length = inputStream!.read(buffer, maxLength: BUFFER_MAX)
        if length > 0 {
            if !connected {
                connected = processHTTP(buffer, bufferLen: length)
                if !connected {
                    let response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false).takeRetainedValue()
                    CFHTTPMessageAppendBytes(response, buffer, length)
                    let code = CFHTTPMessageGetResponseStatusCode(response)
                    doDisconnect(errorWithDetail("Invalid HTTP upgrade", code: UInt16(code)))
                }
            } else {
                var process = false
                if inputQueue.count == 0 {
                    process = true
                }
                inputQueue.append(Data(bytes: UnsafePointer<UInt8>(buffer), count: length))
                if process {
                    dequeueInput()
                }
            }
        }
    }
    ///dequeue the incoming input so it is processed in order
    fileprivate func dequeueInput() {
        if inputQueue.count > 0 {
            let data = inputQueue[0]
            var work = data
            if fragBuffer != nil {
                var combine = NSData(data: fragBuffer!) as Data
                combine.append(data)
                work = combine
                fragBuffer = nil
            }
            let buffer = (work as NSData).bytes.bindMemory(to: UInt8.self, capacity: work.count)
            processRawMessage(buffer, bufferLen: work.count)
            inputQueue = inputQueue.filter{$0 != data}
            dequeueInput()
        }
    }
    ///Finds the HTTP Packet in the TCP stream, by looking for the CRLF.
    fileprivate func processHTTP(_ buffer: UnsafePointer<UInt8>, bufferLen: Int) -> Bool {
        let CRLFBytes = [UInt8(ascii: "\r"), UInt8(ascii: "\n"), UInt8(ascii: "\r"), UInt8(ascii: "\n")]
        var k = 0
        var totalSize = 0
        for i in 0 ..< bufferLen {
            if buffer[i] == CRLFBytes[k] {
                k += 1
                if k == 3 {
                    totalSize = i + 1
                    break
                }
            } else {
                k = 0
            }
        }
        if totalSize > 0 {
            if validateResponse(buffer, bufferLen: totalSize) {
                queue.async(execute: { [weak self] in
                    guard let s = self else { return }
                    if let connectBlock = s.onConnect {
                        connectBlock()
                    }
                    s.delegate?.websocketDidConnect(s)
                })
                totalSize += 1 //skip the last \n
                let restSize = bufferLen - totalSize
                if restSize > 0 {
                    processRawMessage((buffer+totalSize),bufferLen: restSize)
                }
                return true
            }
        }
        return false
    }
    
    ///validates the HTTP is a 101 as per the RFC spec
    fileprivate func validateResponse(_ buffer: UnsafePointer<UInt8>, bufferLen: Int) -> Bool {
        let response = CFHTTPMessageCreateEmpty(kCFAllocatorDefault, false).takeRetainedValue()
        CFHTTPMessageAppendBytes(response, buffer, bufferLen)
        if CFHTTPMessageGetResponseStatusCode(response) != 101 {
            return false
        }
        if let cfHeaders = CFHTTPMessageCopyAllHeaderFields(response) {
            let headers = cfHeaders.takeRetainedValue() as NSDictionary
            let acceptKey = headers[headerWSAcceptName] as! NSString
            if acceptKey.length > 0 {
                return true
            }
        }
        return false
    }
    
    ///process the websocket data
    fileprivate func processRawMessage(_ buffer: UnsafePointer<UInt8>, bufferLen: Int) {
        let response = readStack.last
        if response != nil && bufferLen < 2  {
            fragBuffer = Data(bytes: UnsafePointer<UInt8>(buffer), count: bufferLen)
            return
        }
        if response != nil && response!.bytesLeft > 0 {
            let resp = response!
            var len = resp.bytesLeft
            var extra = bufferLen - resp.bytesLeft
            if resp.bytesLeft > bufferLen {
                len = bufferLen
                extra = 0
            }
            resp.bytesLeft -= len
            resp.buffer?.append(Data(bytes: UnsafePointer<UInt8>(buffer), count: len))
            processResponse(resp)
            let offset = bufferLen - extra
            if extra > 0 {
                processExtra((buffer+offset), bufferLen: extra)
            }
            return
        } else {
            let isFin = (FinMask & buffer[0])
            let receivedOpcode = (OpCodeMask & buffer[0])
            let isMasked = (MaskMask & buffer[1])
            let payloadLen = (PayloadLenMask & buffer[1])
            var offset = 2
            if((isMasked > 0 || (RSVMask & buffer[0]) > 0) && receivedOpcode != OpCode.pong.rawValue) {
                let errCode = CloseCode.protocolError.rawValue
                doDisconnect(errorWithDetail("masked and rsv data is not currently supported", code: errCode))
                writeError(errCode)
                return
            }
            let isControlFrame = (receivedOpcode == OpCode.connectionClose.rawValue || receivedOpcode == OpCode.ping.rawValue)
            if !isControlFrame && (receivedOpcode != OpCode.binaryFrame.rawValue && receivedOpcode != OpCode.continueFrame.rawValue &&
                receivedOpcode != OpCode.textFrame.rawValue && receivedOpcode != OpCode.pong.rawValue) {
                    let errCode = CloseCode.protocolError.rawValue
                    doDisconnect(errorWithDetail("unknown opcode: \(receivedOpcode)", code: errCode))
                    writeError(errCode)
                    return
            }
            if isControlFrame && isFin == 0 {
                let errCode = CloseCode.protocolError.rawValue
                doDisconnect(errorWithDetail("control frames can't be fragmented", code: errCode))
                writeError(errCode)
                return
            }
            if receivedOpcode == OpCode.connectionClose.rawValue {
                var code = CloseCode.normal.rawValue
                if payloadLen == 1 {
                    code = CloseCode.protocolError.rawValue
                } else if payloadLen > 1 {
                    let codeBuffer = UnsafePointer<UInt16>((buffer+offset))
                    code = codeBuffer[0].bigEndian
                    if code < 1000 || (code > 1003 && code < 1007) || (code > 1011 && code < 3000) {
                        code = CloseCode.protocolError.rawValue
                    }
                    offset += 2
                }
                if payloadLen > 2 {
                    let len = Int(payloadLen-2)
                    if len > 0 {
                        let bytes = UnsafePointer<UInt8>((buffer+offset))
                        let str: NSString? = NSString(data: Data(bytes: UnsafePointer<UInt8>(bytes), count: len), encoding: String.Encoding.utf8.rawValue)
                        if str == nil {
                            code = CloseCode.protocolError.rawValue
                        }
                    }
                }
                doDisconnect(errorWithDetail("connection closed by server", code: code))
                writeError(code)
                return
            }
            if isControlFrame && payloadLen > 125 {
                writeError(CloseCode.protocolError.rawValue)
                return
            }
            var dataLength = UInt64(payloadLen)
            if dataLength == 127 {
                let bytes = UnsafePointer<UInt64>((buffer+offset))
                dataLength = bytes[0].bigEndian
                offset += MemoryLayout<UInt64>.size
            } else if dataLength == 126 {
                let bytes = UnsafePointer<UInt16>((buffer+offset))
                dataLength = UInt64(bytes[0].bigEndian)
                offset += MemoryLayout<UInt16>.size
            }
            if bufferLen < offset || UInt64(bufferLen - offset) < dataLength {
                fragBuffer = Data(bytes: UnsafePointer<UInt8>(buffer), count: bufferLen)
                return
            }
            var len = dataLength
            if dataLength > UInt64(bufferLen) {
                len = UInt64(bufferLen-offset)
            }
            var data: Data!
            if len < 0 {
                len = 0
                data = Data()
            } else {
                data = Data(bytes: UnsafePointer<UInt8>(UnsafePointer<UInt8>((buffer+offset))), count: Int(len))
            }
            if receivedOpcode == OpCode.pong.rawValue {
                queue.async(execute: { [weak self] in
                    guard let s = self else { return }
                    if let pongBlock = s.onPong {
                        pongBlock()
                    }
                    s.pongDelegate?.websocketDidReceivePong(s)
                })
                
                let step = Int(offset+numericCast(len))
                let extra = bufferLen-step
                if extra > 0 {
                    processRawMessage((buffer+step), bufferLen: extra)
                }
                return
            }
            var response = readStack.last
            if isControlFrame {
                response = nil //don't append pings
            }
            if isFin == 0 && receivedOpcode == OpCode.continueFrame.rawValue && response == nil {
                let errCode = CloseCode.protocolError.rawValue
                doDisconnect(errorWithDetail("continue frame before a binary or text frame", code: errCode))
                writeError(errCode)
                return
            }
            var isNew = false
            if(response == nil) {
                if receivedOpcode == OpCode.continueFrame.rawValue  {
                    let errCode = CloseCode.protocolError.rawValue
                    doDisconnect(errorWithDetail("first frame can't be a continue frame",
                        code: errCode))
                    writeError(errCode)
                    return
                }
                isNew = true
                response = WSResponse()
                response!.code = OpCode(rawValue: receivedOpcode)!
                response!.bytesLeft = Int(dataLength)
                response!.buffer = NSData(data: data) as Data as Data
            } else {
                if receivedOpcode == OpCode.continueFrame.rawValue  {
                    response!.bytesLeft = Int(dataLength)
                } else {
                    let errCode = CloseCode.protocolError.rawValue
                    doDisconnect(errorWithDetail("second and beyond of fragment message must be a continue frame",
                        code: errCode))
                    writeError(errCode)
                    return
                }
                response!.buffer!.append(data)
            }
            if response != nil {
                response!.bytesLeft -= Int(len)
                response!.frameCount += 1
                response!.isFin = isFin > 0 ? true : false
                if(isNew) {
                    readStack.append(response!)
                }
                processResponse(response!)
            }
            
            let step = Int(offset+numericCast(len))
            let extra = bufferLen-step
            if(extra > 0) {
                processExtra((buffer+step), bufferLen: extra)
            }
        }
        
    }
    
    ///process the extra of a buffer
    fileprivate func processExtra(_ buffer: UnsafePointer<UInt8>, bufferLen: Int) {
        if bufferLen < 2 {
            fragBuffer = Data(bytes: UnsafePointer<UInt8>(buffer), count: bufferLen)
        } else {
            processRawMessage(buffer, bufferLen: bufferLen)
        }
    }
    
    ///process the finished response of a buffer
    fileprivate func processResponse(_ response: WSResponse) -> Bool {
        if response.isFin && response.bytesLeft <= 0 {
            if response.code == .ping {
                let data = response.buffer! //local copy so it is perverse for writing
                dequeueWrite(data as Data, code: OpCode.pong)
            } else if response.code == .textFrame {
                let str: NSString? = NSString(data: response.buffer! as Data, encoding: String.Encoding.utf8.rawValue)
                if str == nil {
                    writeError(CloseCode.encoding.rawValue)
                    return false
                }

                queue.async(execute: { [weak self] in
                    guard let s = self else { return }
                    if let textBlock = s.onText {
                        textBlock(str! as String)
                    }
                    s.delegate?.websocketDidReceiveMessage(s, text: str! as String)
                })
            } else if response.code == .binaryFrame {
                let data = response.buffer! //local copy so it is perverse for writing
                queue.async(execute: { [weak self] in
                    guard let s = self else { return }
                    if let dataBlock = s.onData {
                        dataBlock(data as Data)
                    }
                    s.delegate?.websocketDidReceiveData(s, data: data as Data)
                })
            }
            readStack.removeLast()
            return true
        }
        return false
    }
    
    ///Create an error
    fileprivate func errorWithDetail(_ detail: String, code: UInt16) -> NSError {
        var details = Dictionary<String,String>()
        details[NSLocalizedDescriptionKey] =  detail
        return NSError(domain: "Websocket", code: Int(code), userInfo: details)
    }
    
    ///write a an error to the socket
    fileprivate func writeError(_ code: UInt16) {
        let buf = NSMutableData(capacity: MemoryLayout<UInt16>.size)
        let buffer = UnsafeMutablePointer<UInt16>(mutating: buf!.bytes.bindMemory(to: UInt16.self, capacity: buf!.count))
        buffer[0] = code.bigEndian
        dequeueWrite(Data(bytes: UnsafePointer<UInt8>(buffer), count: sizeof(UInt16)), code: .connectionClose)
    }
    ///used to write things to the stream
    fileprivate func dequeueWrite(_ data: Data, code: OpCode) {
        if !isConnected {
            return
        }
        writeQueue.addOperation { [weak self] in
            //stream isn't ready, let's wait
            guard let s = self else { return }
            var offset = 2
            let bytes = UnsafeMutablePointer<UInt8>(mutating: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count))
            let dataLength = data.count
            let frame = NSMutableData(capacity: dataLength + s.MaxFrameSize)
            let buffer = UnsafeMutablePointer<UInt8>(frame!.mutableBytes)
            buffer[0] = s.FinMask | code.rawValue
            if dataLength < 126 {
                buffer[1] = CUnsignedChar(dataLength)
            } else if dataLength <= Int(UInt16.max) {
                buffer[1] = 126
                let sizeBuffer = UnsafeMutablePointer<UInt16>((buffer+offset))
                sizeBuffer[0] = UInt16(dataLength).bigEndian
                offset += MemoryLayout<UInt16>.size
            } else {
                buffer[1] = 127
                let sizeBuffer = UnsafeMutablePointer<UInt64>((buffer+offset))
                sizeBuffer[0] = UInt64(dataLength).bigEndian
                offset += MemoryLayout<UInt64>.size
            }
            buffer[1] |= s.MaskMask
            let maskKey = UnsafeMutablePointer<UInt8>(buffer + offset)
            SecRandomCopyBytes(kSecRandomDefault, Int(MemoryLayout<UInt32>.size), maskKey)
            offset += MemoryLayout<UInt32>.size
            
            for (i in 0 ..< dataLength) {
                buffer[offset] = bytes[i] ^ maskKey[i % MemoryLayout<UInt32>.size]
                offset += 1
            }
            var total = 0
            while true {
                if !s.isConnected {
                    break
                }
                guard let outStream = s.outputStream else { break }
                let writeBuffer = UnsafePointer<UInt8>(frame!.bytes+total)
                let len = outStream.write(writeBuffer, maxLength: offset-total)
                if len < 0 {
                    var error: NSError?
                    if let streamError = outStream.streamError {
                        error = streamError as NSError?
                    } else {
                        let errCode = InternalErrorCode.outputStreamWriteError.rawValue
                        error = s.errorWithDetail("output stream error during write", code: errCode)
                    }
                    s.doDisconnect(error)
                    break
                } else {
                    total += len
                }
                if total >= offset {
                    break
                }
            }
            
        }
    }
    
    ///used to preform the disconnect delegate
    fileprivate func doDisconnect(_ error: NSError?) {
        if !didDisconnect {
            queue.async(execute: { [weak self] in
                guard let s = self else { return }
                s.didDisconnect = true
                if let disconnect = s.onDisconnect {
                    disconnect(error)
                }
                s.delegate?.websocketDidDisconnect(s, error: error)
            })
        }
    }
    
}
