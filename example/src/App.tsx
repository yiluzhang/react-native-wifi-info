import React, { useEffect, useState } from 'react';
import { PermissionsAndroid, Platform, StatusBar, StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import WifiInfo, { type WifiInfoData } from 'react-native-wifi-info';
import dayjs from 'dayjs';

function App(): React.JSX.Element {
  const [info, setInfo] = useState<WifiInfoData | null>(null);

  useEffect(() => {
    const sub = WifiInfo.addChangeListener(setInfo);

    return () => {
      sub.remove();
    };
  }, []);

  const requestPermissions = async () => {
    if (Platform.OS !== 'android') {
      return true;
    }

    const granted = await PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.ACCESS_FINE_LOCATION);
    return granted === 'granted';
  }

  const get = async () => {
    const access = await requestPermissions();

    if (access) {
      const res = await WifiInfo.getCurrentWifiInfo();
      setInfo(res);
    }
  }

  return (
    <View style={styles.container}>
      <StatusBar barStyle="dark-content" backgroundColor="#fff" />
      <View style={styles.tipContainer}>
        <Text style={{ fontSize: 26, paddingBottom: 12, color: '#000', textAlign: 'center' }}>{dayjs().format('HH:mm:ss')}</Text>
        <Text style={styles.txt}>SSID: <Text style={{ color: '#666' }}>{info?.ssid}</Text></Text>
        <Text style={styles.txt}>BSSID: <Text style={{ color: '#666' }}>{info?.bssid}</Text></Text>
        <Text style={styles.txt}>IP: <Text style={{ color: '#666' }}>{info?.ip}</Text></Text>
      </View>
      <TouchableOpacity onPress={get} style={styles.btn}>
        <Text style={styles.txt}>刷新 Wi-Fi 信息</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  tipContainer: {
    height: 300,
    width: '100%',
    paddingHorizontal: 32,
  },
  center: {
    textAlign: 'center',
  },
  btn: {
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 18,
    width: 180,
    height: 50,
    backgroundColor: '#f0f0f0',
    borderRadius: 8,
  },
  txt: {
    fontSize: 20,
    lineHeight: 32,
    color: '#000',
  },
});

export default App;
