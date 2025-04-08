// ESP32 BLE Controller for Robot Car
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Motor control pins (as per your wiring diagram)
// Motor Driver #1 (Wheels)
const int LEFT_MOTOR_FWD = 25;   // IN1
const int LEFT_MOTOR_REV = 26;   // IN2
const int RIGHT_MOTOR_FWD = 27;  // IN3
const int RIGHT_MOTOR_REV = 14;  // IN4

// Motor Driver #2 (Drum and Auxiliary)
const int DRUM_MOTORS_FWD = 12;  // IN1
const int DRUM_MOTORS_REV = 13;  // IN2
const int AUX_MOTORS_FWD = 32;   // IN3
const int AUX_MOTORS_REV = 33;   // IN4

// BLE UUIDs - Using Nordic UART Service (NUS) UUIDs
#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

BLEServer *pServer = NULL;
BLECharacteristic *pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;
String receivedCommand = "";



// Forward declarations of functions
void stopAllMotors();
void stopMovement();
void moveForward();
void moveBackward();
void turnLeft();
void turnRight();
void moveForwardLeft();
void moveForwardRight();
void moveBackwardLeft();
void moveBackwardRight();
void drumForward();
void drumBackward();
void stopDrum();
void auxForward();
void auxBackward();
void stopAux();
void processCommand(String command);
void sendMessage(const char* message);



class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device connected");
    };
    
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device disconnected");
      // Stop all motors when disconnected
      stopAllMotors();
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string rxValue = pCharacteristic->getValue().c_str();
      if (rxValue.length() > 0) {
        Serial.println("*********");
        Serial.print("Received Value: ");
        
        String command = "";
        for (int i = 0; i < rxValue.length(); i++) {
          Serial.print(rxValue[i]);
          command += rxValue[i];
        }
        Serial.println();
        Serial.println("*********");
        
        // Process the command
        processCommand(command);
      }
    }
};



void setup() {
   // Give time for power stabilization
  // delay(3000);
  
  // IMMEDIATELY control GPIO12
  pinMode(12, OUTPUT);
  digitalWrite(12, LOW);
  delay(100);
  
  // CRITICAL: Disable GPIO12 pull-up that might be enabled during boot
  // pinMode(12, INPUT);
  // pinMode(12, OUTPUT);
  // digitalWrite(12, LOW);
  
  // Configure remaining pins
  pinMode(LEFT_MOTOR_FWD, OUTPUT);
  pinMode(LEFT_MOTOR_REV, OUTPUT);
  pinMode(RIGHT_MOTOR_FWD, OUTPUT);
  pinMode(RIGHT_MOTOR_REV, OUTPUT);
  pinMode(DRUM_MOTORS_FWD, OUTPUT);
  pinMode(DRUM_MOTORS_REV, OUTPUT);
  pinMode(AUX_MOTORS_FWD, OUTPUT);
  pinMode(AUX_MOTORS_REV, OUTPUT);
  
  // EXPLICITLY set all pins LOW immediately 
  digitalWrite(LEFT_MOTOR_FWD, LOW);
  digitalWrite(LEFT_MOTOR_REV, LOW);
  digitalWrite(RIGHT_MOTOR_FWD, LOW);
  digitalWrite(RIGHT_MOTOR_REV, LOW);
  digitalWrite(DRUM_MOTORS_FWD, LOW);
  digitalWrite(DRUM_MOTORS_REV, LOW);
  digitalWrite(AUX_MOTORS_FWD, LOW);
  digitalWrite(AUX_MOTORS_REV, LOW);
  
  // Initialize all motors to stop
  stopAllMotors();
  
  // Initialize Serial for debugging
  Serial.begin(115200);
  // Create the BLE Device
  BLEDevice::init("ESP32_RobotCar");
  
  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Create a BLE Characteristic for receiving data (RX)
  BLECharacteristic *pRxCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID_RX,
                      BLECharacteristic::PROPERTY_WRITE);
  pRxCharacteristic->setCallbacks(new MyCallbacks());
  
  // Create a BLE Characteristic for sending data (TX)
  pTxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID_TX,
                        BLECharacteristic::PROPERTY_NOTIFY);
  pTxCharacteristic->addDescriptor(new BLE2902());
  
  // Start the service
  pService->start();
  
  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("BLE ready, waiting for connections...");
}

void loop() {
  // Disconnect / reconnect management
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Give the Bluetooth stack a chance to get things ready
    pServer->startAdvertising(); // Restart advertising
    Serial.println("Started advertising");
    oldDeviceConnected = deviceConnected;
  }
  
  // Connecting
  if (deviceConnected && !oldDeviceConnected) {
    // Do stuff when connecting
    oldDeviceConnected = deviceConnected;
  }
}

void sendMessage(const char * message) {
  if (deviceConnected) {
    pTxCharacteristic->setValue(message);
    pTxCharacteristic->notify();
  }
}

void processCommand(String command) {
  // Remove any newline characters
  command.replace("\n", "");
  command.replace("\r", "");
  
  Serial.print("Processing command: ");
  Serial.println(command);
  
  // Movement commands
  if (command == "F") {
    moveForward();
  } else if (command == "B") {
    moveBackward();
  } else if (command == "L") {
    turnLeft();
  } else if (command == "R") {
    turnRight();
  } else if (command == "FL") {
    moveForwardLeft();
  } else if (command == "FR") {
    moveForwardRight();
  } else if (command == "BL") {
    moveBackwardLeft();
  } else if (command == "BR") {
    moveBackwardRight();
  } else if (command == "S") {
    stopMovement();
  }
  
  // Drum commands
  else if (command == "DF") {
    drumForward();
  } else if (command == "DB") {
    drumBackward();
  } else if (command == "DS") {
    stopDrum();
  }
  
  // Auxiliary motor commands
  else if (command == "AF") {
    auxForward();
  } else if (command == "AB") {
    auxBackward();
  } else if (command == "AS") {
    stopAux();
  }
}

// Stop all motors
void stopAllMotors() {
  stopMovement();
  stopDrum();
  stopAux();
}

// Movement control functions
void stopMovement() {
  digitalWrite(LEFT_MOTOR_FWD, LOW);
  digitalWrite(LEFT_MOTOR_REV, LOW);
  digitalWrite(RIGHT_MOTOR_FWD, LOW);
  digitalWrite(RIGHT_MOTOR_REV, LOW);
  Serial.println("Stop Movement");
  sendMessage("Stop Movement");
}

void moveForward() {
  digitalWrite(LEFT_MOTOR_FWD, HIGH);
  digitalWrite(LEFT_MOTOR_REV, LOW);
  digitalWrite(RIGHT_MOTOR_FWD, HIGH);
  digitalWrite(RIGHT_MOTOR_REV, LOW);
  Serial.println("Forward");
  sendMessage("Forward");
}

void moveBackward() {
  digitalWrite(LEFT_MOTOR_FWD, LOW);
  digitalWrite(LEFT_MOTOR_REV, HIGH);
  digitalWrite(RIGHT_MOTOR_FWD, LOW);
  digitalWrite(RIGHT_MOTOR_REV, HIGH);
  Serial.println("Backward");
  sendMessage("Backward");
}

void turnLeft() {
  digitalWrite(LEFT_MOTOR_FWD, LOW);
  digitalWrite(LEFT_MOTOR_REV, HIGH);
  digitalWrite(RIGHT_MOTOR_FWD, HIGH);
  digitalWrite(RIGHT_MOTOR_REV, LOW);
  Serial.println("Left");
  sendMessage("Left");
}

void turnRight() {
  digitalWrite(LEFT_MOTOR_FWD, HIGH);
  digitalWrite(LEFT_MOTOR_REV, LOW);
  digitalWrite(RIGHT_MOTOR_FWD, LOW);
  digitalWrite(RIGHT_MOTOR_REV, HIGH);
  Serial.println("Right");
  sendMessage("Right");
}

void moveForwardLeft() {
  digitalWrite(LEFT_MOTOR_FWD, LOW);
  digitalWrite(LEFT_MOTOR_REV, LOW);
  digitalWrite(RIGHT_MOTOR_FWD, HIGH);
  digitalWrite(RIGHT_MOTOR_REV, LOW);
  Serial.println("Forward Left");
  sendMessage("Forward Left");
}

void moveForwardRight() {
  digitalWrite(LEFT_MOTOR_FWD, HIGH);
  digitalWrite(LEFT_MOTOR_REV, LOW);
  digitalWrite(RIGHT_MOTOR_FWD, LOW);
  digitalWrite(RIGHT_MOTOR_REV, LOW);
  Serial.println("Forward Right");
  sendMessage("Forward Right");
}

void moveBackwardLeft() {
  digitalWrite(LEFT_MOTOR_FWD, LOW);
  digitalWrite(LEFT_MOTOR_REV, LOW);
  digitalWrite(RIGHT_MOTOR_FWD, LOW);
  digitalWrite(RIGHT_MOTOR_REV, HIGH);
  Serial.println("Backward Left");
  sendMessage("Backward Left");
}

void moveBackwardRight() {
  digitalWrite(LEFT_MOTOR_FWD, LOW);
  digitalWrite(LEFT_MOTOR_REV, HIGH);
  digitalWrite(RIGHT_MOTOR_FWD, LOW);
  digitalWrite(RIGHT_MOTOR_REV, LOW);
  Serial.println("Backward Right");
  sendMessage("Backward Right");
}

// Drum control functions
void drumForward() {
  digitalWrite(DRUM_MOTORS_FWD, HIGH);
  digitalWrite(DRUM_MOTORS_REV, LOW);
  Serial.println("Drum Forward");
  sendMessage("Drum Forward");
}

void drumBackward() {
  digitalWrite(DRUM_MOTORS_FWD, LOW);
  digitalWrite(DRUM_MOTORS_REV, HIGH);
  Serial.println("Drum Backward");
  sendMessage("Drum Backward");
}

void stopDrum() {
  digitalWrite(DRUM_MOTORS_FWD, LOW);
  digitalWrite(DRUM_MOTORS_REV, LOW);
  Serial.println("Drum Stop");
  sendMessage("Drum Stop");
}

// Auxiliary motor control functions
void auxForward() {
  digitalWrite(AUX_MOTORS_FWD, HIGH);
  digitalWrite(AUX_MOTORS_REV, LOW);
  Serial.println("Auxiliary Forward");
  sendMessage("Auxiliary Forward");
}

void auxBackward() {
  digitalWrite(AUX_MOTORS_FWD, LOW);
  digitalWrite(AUX_MOTORS_REV, HIGH);
  Serial.println("Auxiliary Backward");
  sendMessage("Auxiliary Backward");
}

void stopAux() {
  digitalWrite(AUX_MOTORS_FWD, LOW);
  digitalWrite(AUX_MOTORS_REV, LOW);
  Serial.println("Auxiliary Stop");
  sendMessage("Auxiliary Stop");
}