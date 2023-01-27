# Motion V2 Plugin App Sample

このリポジトリにはintdash Motion V2（以下、Motion）用プラグインアプリのサンプルが収められています。
プラグインアプリは発生したデータをMotionに送信し、Motionはそのデータをintdashサーバーに送信します。

**注意: このサンプルはMotion V2用であるため、Motion V1では動作しません。**

このサンプルは以下の2つのプロジェクトにより構成されます。
詳細は各プロジェクトに含まれるREADMEファイルを参照してください。

## MotionV2PluginAppSample

intdash Motion用プラグインアプリの本体です。所定のフォーマットに沿ってメッセージを作成し、それをMotionに送信する処理が実装されています。

## BluetoothDeviceEmulator

Bluetoothデバイスをエミュレートするアプリです。MotionプラグインによってBluetoothデバイスをMotionに接続する構成をエミュレートするために使用します。
本アプリを使用することで、Bluetoothデバイス（仮想）→Motionプラグインアプリ→Motion→intdashサーバーというデータ送信を実行することができます。
