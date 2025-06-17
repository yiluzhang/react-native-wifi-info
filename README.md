# react-native-wifi-info

一个简单、跨平台的 React Native 原生模块，用于获取当前设备连接的 Wi-Fi SSID、BSSID 和本机 IP 地址，支持变更监听。

## 安装

```sh
yarn add react-native-wifi-info
```

## 权限设置

### iOS

##### 添加 Capability：Access WiFi Information
* 打开 Xcode 工程；
* 选择你的 TARGET > Signing & Capabilities；
* 点击左上角 + Capability；
* 搜索并添加 Access WiFi Information 权限。

##### Info.plist
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>App 需要定位权限以获取 Wi-Fi 信息</string>
```

### Android

##### AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## API

##### WifiInfo.getCurrentWifiInfo(): Promise<WifiInfoData | null>

获取当前 Wi-Fi 信息。
返回（无权限时返回 null）：
```ts
type WifiInfoData = {
  ssid: string;
  bssid: string;
  ip: string;
};
```

##### WifiInfo.addChangeListener(listener: (data: WifiInfoData) => void): { remove: () => void }

监听 Wi-Fi 信息变化（如网络切换）。
返回：
- `remove`: 移除监听器的函数。

```js
import WifiInfo from 'react-native-wifi-info';

// ...

const subscription = WifiInfo.addChangeListener((data) => {
  console.log('Wi-Fi info changed:', data);
});

// 移除监听器
subscription.remove();
```


## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
