import { NativeEventEmitter, NativeModules } from 'react-native';

const { WifiInfo } = NativeModules;

export interface WifiInfoData {
  ssid: string | null;
  bssid: string | null;
  ip: string | null;
}

type WifiInfoType = {
  // 获取当前 Wi-Fi 信息，无权限时返回 null
  getCurrentWifiInfo(): Promise<WifiInfoData | null>;
  // 监听 Wi-Fi 变化
  addChangeListener(listener: (event: WifiInfoData) => void): { remove: () => void };
};

const emitter = new NativeEventEmitter(WifiInfo);

/**
 * 监听 Wi-Fi 变化
 * @param callback 回调函数
 * @returns 取消监听函数
 */
function addChangeListener(callback: (info: WifiInfoData) => void) {
  const subscription = emitter.addListener('onWifiInfoChanged', callback);
  WifiInfo.startObserve();
  return {
    remove: () => {
      WifiInfo.stopObserve();
      subscription.remove();
    },
  };
}

const WifiInfoModule: WifiInfoType = {
  getCurrentWifiInfo: WifiInfo.getCurrentWifiInfo,
  addChangeListener,
};

export default WifiInfoModule;
