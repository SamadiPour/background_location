import 'dart:async';
import 'dart:developer';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/services.dart';

import 'background_callback.dart';
import 'location.dart';

typedef LocationCallback = void Function(List<Location> value);
typedef OptLocationCallback = void Function(Location? value);

enum LocationPriority {
  /// The best level of accuracy available.
  PRIORITY_HIGH_ACCURACY,
  // Accurate to within one hundred meters.
  PRIORITY_BALANCED_POWER_ACCURACY,
  // Accurate to within ten meters of the desired target.
  PRIORITY_LOW_POWER,
  // The level of accuracy used when an app isn’t authorized for full accuracy location data.
  PRIORITY_NO_POWER,
}

/// BackgroundLocation plugin to get background
/// lcoation updates in iOS and Android
class BackgroundLocation {
  // The channel to be used for communication.
  // This channel is also referenced inside both iOS and Abdroid classes
  static final MethodChannel _channel =
      MethodChannel('com.almoullim.background_location/methods')
        ..setMethodCallHandler((MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'location':
              var locationData =
                  Map<String, dynamic>.from(methodCall.arguments);
              locationCallbackStream?.add(Location.fromJson(locationData));
              break;
            case 'notificationAction':
              var callback = notificationActionCallback;
              var response = Map.from(methodCall.arguments);
              var location = response[ARG_LOCATION];
              if (callback != null) {
                callback(Location.fromJson(location));
              }
              break;
          }
        });

  static StreamController<Location>? locationCallbackStream;
  static OptLocationCallback? notificationActionCallback;

  /// Stop receiving location updates
  static Future stopLocationService() async {
    return await _channel.invokeMethod('stop_location_service');
  }

  /// Check if the location update service is running
  static Future<bool> isServiceRunning() async {
    var result = await _channel.invokeMethod('is_service_running');
    return result == true;
  }

  /// Start receiving location updated
  static Future startLocationService({
    bool startOnBoot = false,
    int interval = 1000,
    int fastestInterval = 500,
    double distanceFilter = 0.0,
    bool forceAndroidLocationManager = false,
    LocationPriority priority = LocationPriority.PRIORITY_HIGH_ACCURACY,
    LocationCallback? backgroundCallback,
  }) async {
    var callbackHandle = 0;
    var locationCallback = 0;
    if (backgroundCallback != null) {
      callbackHandle =
          PluginUtilities.getCallbackHandle(callbackHandler)!.toRawHandle();
      try {
        locationCallback =
            PluginUtilities.getCallbackHandle(backgroundCallback)!
                .toRawHandle();
      } catch (ex, stack) {
        log('Error getting callback handle', error: ex, stackTrace: stack);
      }
    }

    return await _channel
        .invokeMethod('start_location_service', <String, dynamic>{
      'callbackHandle': callbackHandle,
      'locationCallback': locationCallback,
      'startOnBoot': startOnBoot,
      'interval': interval,
      'fastest_interval': fastestInterval,
      'priority': priority.index,
      'distance_filter': distanceFilter,
      'force_location_manager': forceAndroidLocationManager,
    });
  }

  static Future setAndroidNotification({
    String? channelID,
    String? title,
    String? message,
    String? icon,
    String? actionText,
    OptLocationCallback? actionCallback,
  }) async {
    if (Platform.isAndroid) {
      var callback = 0;
      notificationActionCallback = actionCallback;
      if (actionCallback != null) {
        try {
          callback = PluginUtilities.getCallbackHandle(actionCallback)
                  ?.toRawHandle() ??
              0;
        } catch (ex, stack) {
          log('Error getting callback handle', error: ex, stackTrace: stack);
        }
      }
      return await _channel
          .invokeMethod('set_android_notification', <String, dynamic>{
        'channelID': channelID,
        'title': title,
        'message': message,
        'icon': icon,
        'actionText': actionText,
        'actionCallback': callback,
      });
    } else {
      //return Promise.resolve();
    }
  }

  static Future setAndroidConfiguration(int interval) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod('set_configuration', <String, dynamic>{
        'interval': interval.toString(),
      });
    } else {
      //return Promise.resolve();
    }
  }

  /// Get the current location once.
  Future<Location> getCurrentLocation() async {
    var completer = Completer<Location>();

    await getLocationUpdates(completer.complete);

    return completer.future;
  }

  /// Register a function to receive location updates as long as the location
  /// service has started
  static StreamController<Location>? getLocationUpdates(
      Function(Location) location) {
    if (locationCallbackStream?.isClosed == false) {
      locationCallbackStream?.close();
    }

    locationCallbackStream = StreamController();
    locationCallbackStream?.stream.listen(location);
    return locationCallbackStream;
  }
}
