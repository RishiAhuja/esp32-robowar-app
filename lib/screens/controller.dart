import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

class ControllerScreen extends StatefulWidget {
  final BluetoothDevice device;

  const ControllerScreen({Key? key, required this.device}) : super(key: key);

  @override
  _ControllerScreenState createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen> {
  bool isConnecting = true;
  bool isConnected = false;
  String errorMessage = '';

  // BLE specifics
  BluetoothCharacteristic?
      txCharacteristic; // Used to send commands from your app to the ESP32

  // These three string constants are crucial for Bluetooth Low Energy (BLE)
  // communication between your Flutter app and the ESP32 microcontroller.
  // Let me break down what they are and how they work at a technical level.

  final String UART_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  final String TX_CHAR_UUID =
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write characteristic
  final String RX_CHAR_UUID =
      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Notifications from ESP32

  // Controller states
  bool isForward = false;
  bool isBackward = false;
  bool isLeft = false;
  bool isRight = false;
  bool isDrumForward = false;
  bool isDrumBackward = false;
  bool isAuxForward = false;
  bool isAuxBackward = false;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  @override
  void dispose() {
    _disconnectFromDevice();
    super.dispose();
  }

  Future<void> _connectToDevice() async {
    try {
      // Connect to the device
      await widget.device.connect();

      // Discover services
      List<BluetoothService> services = await widget.device.discoverServices();

      // Find the UART service
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() == UART_SERVICE_UUID) {
          // Find the TX characteristic
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == TX_CHAR_UUID) {
              txCharacteristic = characteristic;
              break;
            }
          }

          // Look for the RX characteristic and set up notifications
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase() == RX_CHAR_UUID) {
              await characteristic.setNotifyValue(true);
              characteristic.onValueReceived.listen((value) {
                String message = utf8.decode(value);
                print('Received from ESP32: $message');
                // Process the message here
              });
              break;
            }
          }

          break;
        }
      }

      if (txCharacteristic == null) {
        throw Exception("UART service or characteristics not found");
      }

      setState(() {
        isConnecting = false;
        isConnected = true;
      });

      _showSnackBar('Connected to ${widget.device.name}');
    } catch (e) {
      print('Error connecting: $e');
      setState(() {
        isConnecting = false;
        errorMessage = 'Failed to connect: $e';
      });
    }
  }

  Future<void> _disconnectFromDevice() async {
    try {
      await widget.device.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _sendCommand(String command) async {
    if (txCharacteristic != null && isConnected) {
      try {
        List<int> bytes = utf8.encode("$command\n");
        await txCharacteristic!.write(bytes);
      } catch (e) {
        _showSnackBar('Error sending command: $e');
      }
    } else {
      _showSnackBar('Not connected or characteristic not available');
    }
  }

  void _handleMovementAction(String action, bool isPressed) {
    switch (action) {
      case 'forward':
        setState(() => isForward = isPressed);
        break;
      case 'backward':
        setState(() => isBackward = isPressed);
        break;
      case 'left':
        setState(() => isLeft = isPressed);
        break;
      case 'right':
        setState(() => isRight = isPressed);
        break;
    }

    String command = '';

    // Determine the command based on active buttons
    if (isForward && !isBackward) {
      if (isLeft && !isRight)
        command = 'FL'; // Forward-left
      else if (isRight && !isLeft)
        command = 'FR'; // Forward-right
      else
        command = 'F'; // Forward
    } else if (isBackward && !isForward) {
      if (isLeft && !isRight)
        command = 'BL'; // Backward-left
      else if (isRight && !isLeft)
        command = 'BR'; // Backward-right
      else
        command = 'B'; // Backward
    } else if (isLeft && !isRight) {
      command = 'L'; // Left
    } else if (isRight && !isLeft) {
      command = 'R'; // Right
    } else {
      command = 'S'; // Stop
    }

    _sendCommand(command);
  }

  void _handleDrumAction(String action, bool isPressed) {
    switch (action) {
      case 'drum_forward':
        setState(() => isDrumForward = isPressed);
        _sendCommand(isPressed ? 'DF' : 'DS');
        break;
      case 'drum_backward':
        setState(() => isDrumBackward = isPressed);
        _sendCommand(isPressed ? 'DB' : 'DS');
        break;
    }
  }

  void _handleAuxAction(String action, bool isPressed) {
    switch (action) {
      case 'aux_forward':
        setState(() => isAuxForward = isPressed);
        _sendCommand(isPressed ? 'AF' : 'AS');
        break;
      case 'aux_backward':
        setState(() => isAuxBackward = isPressed);
        _sendCommand(isPressed ? 'AB' : 'AS');
        break;
    }
  }

  Widget _buildActionButton(
      String label, IconData icon, String action, Function(bool) handler) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTapDown: (_) => handler(true),
          onTapUp: (_) => handler(false),
          onTapCancel: () => handler(false),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white),
                SizedBox(height: 5),
                Text(label, style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isConnecting) {
      return Scaffold(
        appBar: AppBar(title: Text('Connecting...')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!isConnected) {
      return Scaffold(
        appBar: AppBar(title: Text('Connection Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(errorMessage),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Go Back'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('ESP32 Robot Controller'),
        backgroundColor: Colors.black87,
        actions: [
          // Add disconnect button
          IconButton(
            icon: Icon(Icons.bluetooth_disabled),
            tooltip: 'Disconnect',
            onPressed: () async {
              await _disconnectFromDevice();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Movement controls
              Text(
                'Movement Controls',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              SizedBox(height: 10),
              // Forward button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTapDown: (_) =>
                            _handleMovementAction('forward', true),
                        onTapUp: (_) => _handleMovementAction('forward', false),
                        onTapCancel: () =>
                            _handleMovementAction('forward', false),
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: isForward ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward, color: Colors.white),
                              Text('Forward',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Left, Stop, Right buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTapDown: (_) => _handleMovementAction('left', true),
                        onTapUp: (_) => _handleMovementAction('left', false),
                        onTapCancel: () => _handleMovementAction('left', false),
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: isLeft ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back, color: Colors.white),
                              Text('Left',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTapDown: (_) {
                          _handleMovementAction('forward', false);
                          _handleMovementAction('backward', false);
                          _handleMovementAction('left', false);
                          _handleMovementAction('right', false);
                        },
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.stop, color: Colors.white),
                              Text('Stop',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTapDown: (_) => _handleMovementAction('right', true),
                        onTapUp: (_) => _handleMovementAction('right', false),
                        onTapCancel: () =>
                            _handleMovementAction('right', false),
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: isRight ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_forward, color: Colors.white),
                              Text('Right',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Backward button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onTapDown: (_) =>
                            _handleMovementAction('backward', true),
                        onTapUp: (_) =>
                            _handleMovementAction('backward', false),
                        onTapCancel: () =>
                            _handleMovementAction('backward', false),
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: isBackward ? Colors.green : Colors.blue,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward, color: Colors.white),
                              Text('Backward',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              // Drum controls
              Text(
                'Drum Controls',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  _buildActionButton(
                      'Drum Forward',
                      Icons.rotate_right,
                      'drum_forward',
                      (isPressed) =>
                          _handleDrumAction('drum_forward', isPressed)),
                  _buildActionButton(
                      'Drum Backward',
                      Icons.rotate_left,
                      'drum_backward',
                      (isPressed) =>
                          _handleDrumAction('drum_backward', isPressed)),
                ],
              ),

              SizedBox(height: 30),

              // Auxiliary controls
              Text(
                'Auxiliary Controls',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  _buildActionButton(
                      'Aux Forward',
                      Icons.add_circle,
                      'aux_forward',
                      (isPressed) =>
                          _handleAuxAction('aux_forward', isPressed)),
                  _buildActionButton(
                      'Aux Backward',
                      Icons.remove_circle,
                      'aux_backward',
                      (isPressed) =>
                          _handleAuxAction('aux_backward', isPressed)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
