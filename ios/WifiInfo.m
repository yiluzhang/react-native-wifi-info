#import "WifiInfo.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <CoreLocation/CoreLocation.h>

@implementation WifiInfo {
  NSTimer *_timer;
  NSInteger _observerCount;
  NSDictionary *_lastInfo;
  CLLocationManager *_locationManager;
  BOOL _hasRequestedPermission;
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents {
  return @[@"onWifiInfoChanged"];
}

+ (BOOL)requiresMainQueueSetup {
  return YES;
}

- (instancetype)init {
  if (self = [super init]) {
    _hasRequestedPermission = NO;
    _locationManager = [[CLLocationManager alloc] init];
  }
  return self;
}

RCT_EXPORT_METHOD(getCurrentWifiInfo:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  [self requestLocationPermissionIfNeeded];
  
  if (![self hasLocationPermission]) {
    resolve((id)kCFNull);
    return;
  }

  NSDictionary *info = [self fetchWifiInfo];
  resolve(info);
}

RCT_EXPORT_METHOD(startObserve) {
  _observerCount++;
  if (_timer) return;

  if (!_locationManager) {
    _locationManager = [[CLLocationManager alloc] init];
  }

  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    __strong typeof(weakSelf) strongSelf = weakSelf;
    if (!strongSelf) return;
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       target:weakSelf
                                                     selector:@selector(checkWifiInfo)
                                                     userInfo:nil
                                                      repeats:YES];
    strongSelf->_timer = timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
  });
}

RCT_EXPORT_METHOD(stopObserve) {
  if (_observerCount > 0) {
    _observerCount--;
    if (_observerCount == 0 && _timer) {
      [_timer invalidate];
      _timer = nil;
    }
  }
}

- (void)checkWifiInfo {
  if (![self hasLocationPermission]) {
    return;
  }

  NSDictionary *info = [self fetchWifiInfo];
  if (![info isEqualToDictionary:_lastInfo]) {
    _lastInfo = info;
    [self sendEventWithName:@"onWifiInfoChanged" body:info];
  }
}

- (void)requestLocationPermissionIfNeeded {
  if (_hasRequestedPermission) {
    return;
  }
  
  CLAuthorizationStatus status;
  if (@available(iOS 14.0, *)) {
    status = _locationManager.authorizationStatus;
  } else {
    status = [CLLocationManager authorizationStatus];
  }
  
  if (status == kCLAuthorizationStatusNotDetermined) {
    _hasRequestedPermission = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
      [self->_locationManager requestWhenInUseAuthorization];
    });
  }
}

- (BOOL)hasLocationPermission {
  if (!_locationManager) {
    _locationManager = [[CLLocationManager alloc] init];
  }

  CLAuthorizationStatus status;
  if (@available(iOS 14.0, *)) {
    status = _locationManager.authorizationStatus;
  } else {
    status = [CLLocationManager authorizationStatus];
  }

  return status == kCLAuthorizationStatusAuthorizedWhenInUse ||
         status == kCLAuthorizationStatusAuthorizedAlways;
}

- (NSDictionary *)fetchWifiInfo {
  // 先检查权限状态
  CLAuthorizationStatus status;
  if (@available(iOS 14.0, *)) {
    status = _locationManager.authorizationStatus;
  } else {
    status = [CLLocationManager authorizationStatus];
  }
  NSLog(@"[WifiInfo] Location permission status: %d (0=NotDetermined, 3=WhenInUse, 4=Always)", (int)status);
  
  // iOS 14+ 优先使用新 API
  if (@available(iOS 14.0, *)) {
    NSLog(@"[WifiInfo] iOS 14+ detected, trying NEHotspotNetwork API first...");
    __block NSDictionary *result = nil;
    __block BOOL completed = NO;
    
    [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable network) {
      if (network) {
        NSLog(@"[WifiInfo] ✅ NEHotspotNetwork success: SSID=%@, BSSID=%@", network.SSID, network.BSSID);
        NSString *ip = [self getIPAddress];
        result = @{
          @"ssid": network.SSID ?: @"",
          @"bssid": network.BSSID ?: @"",
          @"ip": ip ?: @""
        };
      } else {
        NSLog(@"[WifiInfo] ⚠️ NEHotspotNetwork returned nil, falling back to CNCopyCurrentNetworkInfo");
      }
      completed = YES;
    }];
    
    // 等待异步回调（最多1秒）
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:1.0];
    while (!completed && [timeout timeIntervalSinceNow] > 0) {
      [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    }
    
    if (result) {
      return result;
    }
  }
  
  // 回退到旧 API
  NSLog(@"[WifiInfo] Using legacy CNCopyCurrentNetworkInfo API...");
  NSArray *interfaces = (__bridge_transfer id)CNCopySupportedInterfaces();
  
  if (!interfaces || interfaces.count == 0) {
    NSLog(@"[WifiInfo] No supported interfaces found");
    return @{
      @"ssid": @"",
      @"bssid": @"",
      @"ip": @""
    };
  }
  
  NSLog(@"[WifiInfo] Found %lu interface(s): %@", (unsigned long)interfaces.count, interfaces);
  
  NSDictionary *networkInfo = nil;

  for (NSString *interfaceName in interfaces) {
    NSDictionary *info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName);
    NSLog(@"[WifiInfo] Interface '%@' returned: %@", interfaceName, info ?: @"(null)");
    
    if (info && info.count > 0) {
      networkInfo = [info copy];
      NSLog(@"[WifiInfo] ✅ Found network info on interface %@: SSID=%@, BSSID=%@", 
            interfaceName, networkInfo[@"SSID"], networkInfo[@"BSSID"]);
      break;
    }
  }
  
  if (!networkInfo || !networkInfo[@"BSSID"] || [networkInfo[@"BSSID"] isKindOfClass:[NSNull class]]) {
    NSLog(@"[WifiInfo] ❌ No valid network info found (not connected to WiFi or missing permissions)");
    NSLog(@"[WifiInfo] Troubleshooting: Check 1) Location permission granted? 2) Access WiFi Information capability enabled? 3) Connected to WiFi?");
    return @{
      @"ssid": @"",
      @"bssid": @"",
      @"ip": @""
    };
  }

  NSString *ssid = networkInfo[@"SSID"];
  NSString *bssid = networkInfo[@"BSSID"];
  NSString *ip = [self getIPAddress];

  return @{
    @"ssid": ssid ?: @"",
    @"bssid": bssid ?: @"",
    @"ip": ip ?: @""
  };
}

- (NSString *)getIPAddress {
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  NSString *address = @"";

  if (getifaddrs(&interfaces) == 0) {
    temp_addr = interfaces;
    while (temp_addr != NULL) {
      if (temp_addr->ifa_addr->sa_family == AF_INET) {
        if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
          address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
          break;
        }
      }
      temp_addr = temp_addr->ifa_next;
    }
  }

  if (interfaces != NULL) {
    freeifaddrs(interfaces);
  }

  return address.length > 0 ? address : @"";
}

- (void)dealloc {
  if (_timer) {
    [_timer invalidate];
    _timer = nil;
  }
}

@end
