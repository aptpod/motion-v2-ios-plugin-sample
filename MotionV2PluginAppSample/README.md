# Motion V2 Plugin App Sample
このアプリは、intdash Motion V2（以下、Motion）のプラグインアプリのサンプルです。
プラグインアプリは、発生したデータをMotionに送信し、Motionはそのデータをintdashサーバーに送信します。
プラグインアプリとMotionの間の通信にはUDP (User Datagram Protocol)が利用されます。

※iOS、macOS標準で送受信可能なUDPの最大パケットサイズは9216バイトです。

Motionがフォアグラウンドで動作するため、プラグインアプリはバックグラウンドで動作させる必要があります。
そのためプラグインアプリでは、BluetoothやGPS関連の、バックグランドで許された動作しか実行できません。また、カメラは利用できません。

※このサンプルアプリケーションはiPhone、iPadの **実機のみ** で動作します。

## ■ 新しくMotion用プラグインアプリを作る際のポイント

新しくMotion用のプラグインを作る場合は、以下にご注意ください。

### 1. Info.plistの設定

Info.plistでいくつかの項目を追加する必要があります。

```
// Motionをプラグインアプリから起動するためにスキームを追加
// Motionのスキーム名はaptpod.motionです。

|Key                         |Type       |Value         |
|----------------------------|-----------|--------------|
|LSApplicationQueriesSchemes |Array      |              |
|item 0                      |String     |aptpod.motion |

// Bluetoothを利用する場合は理由を記述

|Key                                              |Type   |Value             |
|-------------------------------------------------|-------|------------------|
|Privacy - Bluetooth Always Usage Description     |String |デバイスとの接続に利用します。 |
|Privacy - Bluetooth Peripheral Usage Description |String |デバイスとの接続に利用します。 |

// Bluetoothをバックグラウンドで利用する設定(セントラルデバイスとして)

|Key                       |Type   |Value                                 |
|--------------------------|-------|--------------------------------------|
|Required background modes |Array  |                                      |
|item 0                    |String | App communicates using CoreBluetooth |
```

### 2. プラグインからMotionに送信するメッセージのフォーマット

プラグインアプリからMotionへは、以下のようなメッセージを送信することができます。

メッセージパケットを生成する方法については、[Motionに送信するパケットの生成](#generate-packet)を参照してください。

* データポイントを表すメッセージ

    ```
    "{
      \"t\": \"\(time)\",
      \"d": [
         {
           \"n\": \"\(name)\",
           \"t\": \"\(type)\"
           \"p": \"\(payload.base64EncodedString())\"
        }, ... 同じタイムスタンプで複数のデータ名称、ペイロードを入れることができる
      ],
    }"
    ```

* プラグインアプリ名を表すメッセージ

    ```
    "{
      \"name\": \"アプリ名\"
    }"
    ```

* 送信終了を表すメッセージ

    ```
    "{
      \"end\": \"\(true)\"
    }"
    ```


### <a id="generate-packet"></a> 3. Motionに送信するパケットの生成

Motionに送信するメッセージのパケットは、以下のように生成します。

#### 3.1 データをintdashのペイロードフォーマットに変換する

この例では、2つの値（x、y）を1つのパケットに入れて送信します。

```swift
let x: Double = 123.456
let y: Double = 789.012
// データをintdashのペイロードフォーマットへと変換します。
// 参考: フォーマットの詳細は、iSCP 2.0プロトコル仕様書の
// 「【拡張仕様】ペイロードフォーマット」を参照してください。
// このサンプルでは `Float64` のフォーマットを使用します。
// 参考: Float64のフォーマットは、iSCP 2.0プロトコル仕様書の
// 「【拡張仕様】ペイロードフォーマット」→「Float64」に定義されています。
let dataType = "float64"
let dataX = x.toData().base64EncodedString()
let dataY = y.toData().base64EncodedString()
// データを識別するためのデータ名称を用意します。このサンプルではiSCPv1と互換性があるデータ名称にします。
// 参考: 互換性のあるデータ名称については、「intdash API/SDK」サイトの
// 「リアルタイムAPI」→「iSCP 1.0とiSCP 2.0の互換仕様」→
// 「データポイントとそのメタ情報」を参照してください。
let dataNameX = "v1/1/x"
let dataNameY = "v1/1/y"

...

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
```

#### 3.2 Motionへ送信するパケットを生成する

```swift                
let strs = NSMutableString()
strs.append("{")
strs.append("\n  \"t\": \"\(time)\",")
strs.append("\n  \"d\": [")
strs.append("\n    {")
strs.append("\n      \"n\": \"\(dataNameX)\",")
strs.append("\n      \"t\": \"\(dataType)\",")
strs.append("\n      \"p\": \"\(dataX)\"")
strs.append("\n    },")
strs.append("\n    {")
strs.append("\n      \"n\": \"\(dataNmeY)\",")
strs.append("\n      \"t\": \"\(dataType)\",")
strs.append("\n      \"p\": \"\(dataY)\"")
strs.append("\n    },")
strs.append("\n  ]")
strs.append("\n}")
let message = String(strs)
//print("send data:\n\(message)")
guard let messageData = message.data(using: .utf8) else { return }
```

### 4. 送信先のMotionのポート番号

プラグインアプリからMotionにデータを送信する際には、Motionが待ち受けているUDPのポート番号を指定する必要があります。
Motionは、デフォルト設定では `12345` ポートで待ち受けています。
サンプルアプリでは、送信先Motionのポート番号は `./Classes/Config.swift/PORT_NUMBER_DEFAULT` で定義しています。

```swift
guard let port = NWEndpoint.Port(rawValue: NWEndpoint.Port.RawValue(12345)) else {
  return
}
self.connection = NWConnection(host: "localhost", port: port, using: .udp)
self.connection?.stateUpdateHandler = { (newState) in
  ...
}
self.connection?.start(queue: .global())
```


