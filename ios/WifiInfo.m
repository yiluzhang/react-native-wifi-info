#import "WifiInfo.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>
#import <CoreLocation/CoreLocation.h>

@implementation WifiInfo {
  NSTimer *_timer;
  NSInteger _observerCount;
  NSDictionary *_lastInfo;
  CLLocationManager *_locationManager;
}

RCT_EXPORT_MODULE();

- (NSArray<NSString *> *)supportedEvents {
  return @[@"onWifiInfoChanged"];
}

RCT_EXPORT_METHOD(getCurrentWifiInfo:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
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

- (BOOL)hasLocationPermission {
  if (!_locationManager) {
    _locationManager = [[CLLocationManager alloc] init];
  }

  CLAuthorizationStatus status = _locationManager.authorizationStatus;

  return status == kCLAuthorizationStatusAuthorizedWhenInUse ||
         status == kCLAuthorizationStatusAuthorizedAlways;
}

- (NSDictionary *)fetchWifiInfo {
  NSArray *interfaces = (__bridge_transfer id)CNCopySupportedInterfaces();
  NSDictionary *networkInfo = nil;

  for (NSString *interfaceName in interfaces) {
    networkInfo = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)interfaceName);
    if (networkInfo && networkInfo.count > 0) {
      networkInfo = [networkInfo copy];
      break;
    }
  }
  
  if (!networkInfo || !networkInfo[@"BSSID"] || [networkInfo[@"BSSID"] isKindOfClass:[NSNull class]]) {
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
