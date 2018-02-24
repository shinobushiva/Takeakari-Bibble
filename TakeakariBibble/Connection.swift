//
//  Connection.swift
//
//  Created by ninomae makoto on 2016/09/21.
//  Copyright © 2016年 ninomae makoto. All rights reserved.
//

import Foundation

extension OutputStream {
    func write(data: Data) -> Int {
        return data.withUnsafeBytes { write($0, maxLength: data.count) }
    }
}

/**
 各通信処理の挙動の挙動を継承先で定義する
 */
protocol ConnectionDelegate {
    
    /**
     * データの取得が完了した時の処理
     */
    func didReceivedResponseData(response: String)
    
}

///
/// ソケット通信クラス
///
class Connection : NSObject, StreamDelegate {
    
    /// シングルトン
    static let sharedManager = Connection()
    
    private override init() {
    }
    
    // 接続先
    var serverAddress: CFString = "127.0.0.1" as CFString
    let serverPort: UInt32 = 33334
    
    /// 受信用
    private var inputStream : InputStream!
    /// 送信用
    private var outputStream : OutputStream!
    
    /// 接続状態
    var isConnected = false
    
    /** 受信データのキュー */
    private var inputQueue = NSMutableData()
    
    /** 一度に受信するバッファーサイズ */
    let BUFFER_MAX = 2048
    
    /** 受信データの委譲先 */
    var delegate: ConnectionDelegate!  = nil
    /** 汎用エラー */
    static let ERR_MSG = "STR通信エラー\n再度やり直してくださいEOF"
    
    /** 接続 */
    func connect() {
        print("ソケット接続")
        var readStream : Unmanaged<CFReadStream>?
        var writeStream : Unmanaged<CFWriteStream>?
        
        // ソケット作成
        CFStreamCreatePairWithSocketToHost(
            kCFAllocatorDefault,
            serverAddress,
            serverPort,
            &readStream,
            &writeStream)
        
        if( inputStream != nil ) {
            // 接続中の場合は切断
            inputStream.delegate = nil
            inputStream.close()
            inputStream.remove(
                from: RunLoop.current,
                forMode: RunLoopMode.defaultRunLoopMode)
            
        }
        
        if( outputStream != nil ) {
            // 接続中の場合は切断
            outputStream.delegate = nil
            outputStream.close()
            outputStream.remove(
                from: RunLoop.current,
                forMode: RunLoopMode.defaultRunLoopMode)
        }
        
        inputStream = readStream!.takeRetainedValue() as InputStream
        outputStream = writeStream!.takeRetainedValue() as OutputStream
        
        // ストリームイベントの委譲先
        inputStream.delegate = self
        outputStream.delegate = self
        
        inputStream.schedule(
            in: RunLoop.current,
            forMode: RunLoopMode.defaultRunLoopMode)
        outputStream.schedule(
            in: RunLoop.current,
            forMode: RunLoopMode.defaultRunLoopMode)
        
        inputStream.open()
        outputStream.open()
        
    }
    
    /** 接続の切断処理を行う */
    func disConnect() {
        
        print("ソケット切断")
        inputStream.delegate = nil
        outputStream.delegate = nil
        
        inputStream.close()
        outputStream.close()
        
        inputStream.remove(
            from: RunLoop.current,
            forMode: RunLoopMode.defaultRunLoopMode)
        outputStream.remove(
            from: RunLoop.current,
            forMode: RunLoopMode.defaultRunLoopMode)
        
        isConnected = false
    }
    
    /** ストリームの状態が変化した時に呼ばれる */
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        
        if aStream === inputStream {
            // 入力ストリーム
            switch eventCode {
            case Stream.Event.errorOccurred:
                print("input: ErrorOccurred: \(aStream.streamError?.localizedDescription)")
            case Stream.Event.openCompleted:
                print("input: OpenCompleted")
            case Stream.Event.hasBytesAvailable:
                print("input: HasBytesAvailable")
                // 入力ストリーム読み込み可能
                
                getResponse()
                
            case Stream.Event.endEncountered:
                print("input: EndEncountered")
                // サーバから切断された？
                disConnect()
            default:
                break
            }
        }
        else if aStream === outputStream {
            // 出力ストリーム
            switch eventCode {
            case Stream.Event.errorOccurred:
                print("output: ErrorOccurred: \(aStream.streamError?.localizedDescription)")
            case Stream.Event.openCompleted:
                print("output: OpenCompleted")
            case Stream.Event.hasSpaceAvailable:
                print("output: HasSpaceAvailable")
                print("データ送信可能")
                
                // Here you can write() to `outputStream`
                isConnected = true
                
            case Stream.Event.endEncountered:
                print("output: EndEncountered")
                disConnect()
                
            default:
                break
            }
        }
    }
    
    
    /** requestを投げる
     */
    
    func sendRequest(msg: String) {
        
        // エンコード
        let request = msg.data(
            using: String.Encoding.utf8,
            allowLossyConversion: false)
        
        let requestBytes = UnsafePointer<UInt8>([UInt8](request!))
        let requestLength = request!.count
        
        let streamText = String(
            data: Data(bytes: requestBytes, count: requestLength),
            encoding: String.Encoding.utf8)
        
        print("message:\(msg)")
        print("sending:\(streamText!)")
        
        self.sendRequest(request: request)
    }
    /** requestを投げる
     */
    
    func sendRequest(request: Data?) {
        
        if !isConnected {
            connect()
        }
        
        var timeout = 5 * 100000 // wait 5 seconds before giving up
        //NSOperationQueue().addOperationWithBlock { [weak self] in
        while !self.outputStream.hasSpaceAvailable {
            usleep(1000) // wait until the socket is ready
            timeout -= 100
            if timeout < 0 {
                print("time out")
//                self.delegate.didReceivedResponseData(response: Connection.ERR_MSG)
                return
            } else if self.outputStream.streamError != nil {
                print("disconnect Stream")
//                self.delegate.didReceivedResponseData(response: Connection.ERR_MSG)
                return // disconnectStream will be called.
            }
        }
        
        print("write")
        let i = self.outputStream.write(data: request!)
        print(i)
        
    }
    
    
    /* responseを受け取る */
    private func getResponse() {
        
        var buffer = UnsafeMutablePointer<UInt8>(mutating: [UInt8](Data(capacity: BUFFER_MAX)))
        var length = self.inputStream!.read(buffer, maxLength: BUFFER_MAX)
        
        if length == -1 {
            print("length:-1")
            return
        }
        
        print(length)
        
//        // ストリームデータを文字列に変更
//        let streamText = String(
//            data: Data(bytes: buffer, count: length),
//            encoding: String.Encoding.utf8)
//
//        print("length:" + length.description)
//
//        // データが断片化する可能性があるのでキューにためておく
//        inputQueue.append(Data(bytes: buffer, count: length))
//
//        let work = inputQueue
//
//        buffer = UnsafeMutablePointer<UInt8>(work.bytes)
//        length = work.length
//
//        let allStream = NSString(
//            data: NSData(bytes: buffer, length: length),
//            encoding: NSShiftJISStringEncoding )
//
//        if (allStream != nil && allStream!.containsString("EOF") ) {
//            print("データ受信完了")
//
//            let data: String = allStream! as String
//            if( data.contains("STR") ) {
//
//                // データ受信完了後に委譲先に処理を依頼
//                if( delegate == nil ) {
//                    print("委譲先を設定してください")
//                }
//                delegate.didReceivedResponseData(response: data)
//                inputQueue = NSMutableData()
//            }
//            else {
//                // データ不正
//                print("不正なデータです。EOFはありますがSTRがありません")
//                delegate.didReceivedResponseData(response: Connection.ERR_MSG)
//                inputQueue = NSMutableData()
//            }
//        }
//
//
//        if( allStream != nil && !allStream!.containsString("STR") ){
//
//            if( allStream?.length == 0 ) {
//                print("切断された？")
//            }
//            else {
//                // データ不正
//                print("不正なデータです。STRがありません")
//                delegate.didReceivedResponseData(response: Connection.ERR_MSG)
//            }
//
//            inputQueue = NSMutableData()
//        }
    }
}
