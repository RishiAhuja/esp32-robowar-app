// main.dart
import 'package:esp32_led_control/screens/controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 Robot Controller',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BluetoothDeviceListScreen(),
    );
  }
}

// Screen to discover and connect to ESP32
class BluetoothDeviceListScreen extends StatefulWidget {
  @override
  _BluetoothDeviceListScreenState createState() =>
      _BluetoothDeviceListScreenState();
}

class _BluetoothDeviceListScreenState extends State<BluetoothDeviceListScreen> {
  List<ScanResult> scanResults = [];
  bool isScanning = false;
  bool isPermissionGranted = false;
  bool isBluetoothEnabled = false;
  StreamSubscription? scanSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    // Request required permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    setState(() {
      isPermissionGranted = allGranted;
    });

    if (isPermissionGranted) {
      _checkBluetoothStatus();
    }
  }

  void _checkBluetoothStatus() async {
    try {
      isBluetoothEnabled =
          //This is a Stream that continuously monitors the state of the device's Bluetooth adapter
          await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on;
      setState(() {});

      if (isBluetoothEnabled) {
        _startScan();
      }
    } catch (e) {
      _showSnackBar('Error checking Bluetooth: ${e.toString()}');
    }
  }

  void _enableBluetooth() async {
    try {
      // On Android 12+ we can't enable Bluetooth programmatically
      // Instead, show an instruction to the user
      _showSnackBar('Please enable Bluetooth in your device settings');
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  void _startScan() async {
    setState(() {
      scanResults = [];
      isScanning = true;
    });

    try {
      // Cancel any existing subscription
      scanSubscription?.cancel();

      // Listen for scan results
      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        setState(() {
          scanResults = results;
        });
      }, onError: (e) {
        _showSnackBar('Error scanning: $e');
      });

      // Start scanning
      await FlutterBluePlus.startScan(timeout: Duration(seconds: 15));

      // When scan completes
      setState(() {
        isScanning = false;
      });
    } catch (e) {
      setState(() {
        isScanning = false;
      });
      _showSnackBar('Error scanning: ${e.toString()}');
    }
  }

  void _stopScan() {
    FlutterBluePlus.stopScan();
    setState(() {
      isScanning = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!isPermissionGranted) {
      return Scaffold(
        appBar: AppBar(title: Text('Permissions Required')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Bluetooth and Location permissions are required.'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _requestPermissions,
                child: Text('Request Permissions'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Connect to ESP32'),
        actions: [
          if (isBluetoothEnabled)
            IconButton(
              icon: Icon(isScanning ? Icons.stop : Icons.refresh),
              onPressed: isScanning ? _stopScan : _startScan,
            ),
        ],
      ),
      body: !isBluetoothEnabled
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Bluetooth is disabled'),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _enableBluetooth,
                    child: Text('Enable Bluetooth'),
                  ),
                ],
              ),
            )
          : isScanning
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('Scanning for devices...'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    final device = scanResults[index].device;
                    return ListTile(
                      title: Text(device.platformName.isNotEmpty
                          ? device.platformName
                          : 'Unknown Device'),
                      // remoteId is MAC address of the bluetooth device
                      subtitle: Text(device.remoteId.str),
                      trailing: Text(
                          'RSSI: ${scanResults[index].rssi}'), // (Received Signal Strength Indicator)
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ControllerScreen(device: device),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

// Controller screen for robot
