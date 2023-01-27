//
//  MainViewController+BLEManager.swift
//  MotionPluginAppSample
//
//  Created by Ueno Masamitsu on 2020/09/07.
//  Copyright © 2020 aptpod, Inc. All rights reserved.
//

import UIKit
import CoreBluetooth

extension MainViewController: BLECentralManagerValueDelegate {
    
    func setupBLEManager() {
        self.app.bleManager.valueDelegate = self
    }
    
    func manager(_ manager: BLECentralManager, peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // ToDo:ここでタイムスタンプ保持？もしくはデータから取得する可能性あり
        // 基本的にはMotion側でDate()で取れる端末時間を元にNTPサーバーと同期を行っているのでDate()を扱うことを推奨
        // 端末時間と送信元デバイスとの伝送遅延を考慮したタイムスタンプであると良い。
        let time = Date().timeIntervalSince1970
        
        if let error = error {
            print("didUpdateValueFor characteristic error: \(error.localizedDescription) - CBPeripheralDelegate")
            return
        }
        guard let data = characteristic.value else { return }
        //NSLog("Received \(data) bytes of data.")
        guard let message = String(data: data, encoding: .utf8) else {
            print("Failed to convert message.")
            return
        }
        //NSLog("didReceived Message: \(message)")
        self.frameRateCalc.step()
        let newMessage = "\(message)\n↓\nTime: \(self.dateFormatter.string(from: Date()))"
         
         guard let dic = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
             print("Failed to decode data.")
             return
         }
        
        DispatchQueue.main.async {
            self.messageLabel.text = "Fps: \(self.frameRateCalc.getFps())\n\n" + newMessage
        }
        
        DispatchQueue.global().async {
            // 受信したデータを参照します。
            if let vYaw = dic["yaw"] as? NSNumber,
                let vPitch = dic["pitch"] as? NSNumber,
                let vRoll = dic["roll"] as? NSNumber,
                let vX = dic["x"] as? NSNumber,
                let vY = dic["y"] as? NSNumber,
                let vZ = dic["z"] as? NSNumber {
                let yaw = vYaw.doubleValue
                let pitch = vPitch.doubleValue
                let roll = vRoll.doubleValue
                let x = vX.doubleValue
                let y = vY.doubleValue
                let z = vZ.doubleValue
                print("yaw: \(yaw), pitch: \(pitch), roll: \(roll), x: \(x), y: \(y), z: \(z)")
                // データをintdashのペイロードフォーマットへと変換します。
                // 参考: フォーマットの詳細は、iSCP 2.0プロトコル仕様書の
                // 「【拡張仕様】ペイロードフォーマット」を参照してください。
                // このサンプルでは `Float64` のフォーマットを使用します。
                // 参考: Float64のフォーマットは、iSCP 2.0プロトコル仕様書の
                // 「【拡張仕様】ペイロードフォーマット」→「Float64」に定義されています。
                let dataType = "float64"
                // データを識別するためのデータ名称を用意します。このサンプルではiSCPv1と互換性があるデータ名称にします。
                // 参考: 互換性のあるデータ名称については、「intdash API/SDK」サイトの
                // 「リアルタイムAPI」→「iSCP 1.0とiSCP 2.0の互換仕様」→
                // 「データポイントとそのメタ情報」を参照してください。
                let dataNameYaw = "v1/1/yaw"
                let dataNamePitch = "v1/1/pitch"
                let dataNameRoll = "v1/1/roll"
                let dataNameX = "v1/1/x"
                let dataNameY = "v1/1/y"
                let dataNameZ = "v1/1/z"
                
                // 送信するパケットを生成します。
                let strs = NSMutableString()
                strs.append("{")
                strs.append("\n  \"t\": \"\(time)\",")
                strs.append("\n  \"d\": [")
                strs.append("\n    {")
                strs.append("\n      \"n\": \"\(dataNameYaw)\",")
                strs.append("\n      \"t\": \"\(dataType)\",")
                strs.append("\n      \"p\": \"\(yaw.toData().base64EncodedString())\"")
                strs.append("\n    },")
                strs.append("\n    {")
                strs.append("\n      \"n\": \"\(dataNamePitch)\",")
                strs.append("\n      \"t\": \"\(dataType)\",")
                strs.append("\n      \"p\": \"\(pitch.toData().base64EncodedString())\"")
                strs.append("\n    },")
                strs.append("\n    {")
                strs.append("\n      \"n\": \"\(dataNameRoll)\",")
                strs.append("\n      \"t\": \"\(dataType)\",")
                strs.append("\n      \"p\": \"\(roll.toData().base64EncodedString())\"")
                strs.append("\n    },")
                strs.append("\n    {")
                strs.append("\n      \"n\": \"\(dataNameX)\",")
                strs.append("\n      \"t\": \"\(dataType)\",")
                strs.append("\n      \"p\": \"\(x.toData().base64EncodedString())\"")
                strs.append("\n    },")
                strs.append("\n    {")
                strs.append("\n      \"n\": \"\(dataNameY)\",")
                strs.append("\n      \"t\": \"\(dataType)\",")
                strs.append("\n      \"p\": \"\(y.toData().base64EncodedString())\"")
                strs.append("\n    },")
                strs.append("\n    {")
                strs.append("\n      \"n\": \"\(dataNameZ)\",")
                strs.append("\n      \"t\": \"\(dataType)\",")
                strs.append("\n      \"p\": \"\(z.toData().base64EncodedString())\"")
                strs.append("\n    }")
                strs.append("\n  ]")
                strs.append("\n}")
                let message = String(strs)
                //print("send data:\n\(message)")
                guard let messageData = message.data(using: .utf8) else { return }
                self.sendMessage(data: messageData)
            }
        }
        
    }
    
}

extension Double {
    func toData(_ isLittleEndian: Bool = false) -> Data {
        let value = isLittleEndian ? self.bitPattern.littleEndian : self.bitPattern.bigEndian
        return convertData(value)
    }
}

fileprivate func convertData<T>(_ value: T) -> Data {
    var value = value
    return Data(withUnsafePointer(to: &value) {
        $0.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<T>.size) {
            Array(UnsafeBufferPointer(start: $0, count: MemoryLayout<T>.size))
        }
    })
}
