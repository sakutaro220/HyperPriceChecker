import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate, URLSessionWebSocketDelegate {
    var statusItem: NSStatusItem?
    var webSocketTask: URLSessionWebSocketTask!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // ステータスバーアイテムを作成
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSApp.setActivationPolicy(.accessory)
        if let button = statusItem?.button {
            button.action = #selector(statusItemClicked)
            button.target = self
            button.title = "HYPE: Loading..."
        }
        
        // WebSocketに接続
        connectWebSocket()
    }

    func connectWebSocket() {
        let url = URL(string: "wss://api.hyperliquid.xyz/ws")!
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask.resume()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket接続が確立しました")
        // 接続が確立した後に購読を開始
        sendSubscription()
        receiveMessages()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket接続が切断されました: \(closeCode)")
        // 必要に応じて再接続処理を行う
    }

    func sendSubscription() {
        let subscriptionMessage: [String: Any] = [
            "method": "subscribe",
            "subscription": [
                "type": "allMids"
            ]
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: subscriptionMessage, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask.send(message) { error in
                if let error = error {
                    print("WebSocket送信エラー: \(error)")
                } else {
                    print("サブスクリプションメッセージを送信しました")
                }
            }
        } else {
            print("サブスクリプションメッセージの作成に失敗しました")
        }
    }

    func receiveMessages() {
        webSocketTask.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket受信エラー: \(error)")
                // 必要に応じて再接続処理を行う
                self?.reconnectWebSocket()
            case .success(let message):
                switch message {
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessageText(text)
                    }
                case .string(let text):
                    self?.handleMessageText(text)
                @unknown default:
                    break
                }
                // 次のメッセージを待機
                self?.receiveMessages()
            }
        }
    }

    func handleMessageText(_ text: String) {
        do {
            if let data = text.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                // `"allMids"` チャンネルのデータを処理
                if let channel = json["channel"] as? String, channel == "allMids",
                   let dataDict = json["data"] as? [String: Any],
                   let mids = dataDict["mids"] as? [String: String],
                   let hypeValueString = mids["HYPE"],
                   let hypeValue = Double(hypeValueString) {
                    // メインスレッドでUIを更新
                    DispatchQueue.main.async {
                        self.statusItem?.button?.title = String(format: "HYPE: $%.4f", hypeValue)
                    }
                } else {
                    print("期待するデータ形式ではありません")
                }
            }
        } catch {
            print("JSON解析エラー: \(error)")
        }
    }

    @objc func reconnectWebSocket() {
        // 既存のWebSocketをキャンセル
        webSocketTask.cancel(with: .goingAway, reason: nil)
        // 新しい接続を開始
        connectWebSocket()
    }

    @objc func statusItemClicked(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "再接続", action: #selector(reconnectWebSocket), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "終了", action: #selector(terminate), keyEquivalent: "q"))
        
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc func terminate() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // WebSocketをクローズ
        webSocketTask.cancel(with: .goingAway, reason: nil)
    }
}
