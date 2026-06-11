#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <SoftwareSerial.h>

// ================= WIFI STRUCTURE =================
struct WiFiNetwork {
  const char* ssid;
  const char* password;
};

WiFiNetwork networks[3] = {
  {"Papa.", "mamawacugusa1"},
  {"Theo-pc", "12345678"},
  {"IT Elias", "00998877660"}
};

// ================= RS485 PINS =================
#define RX_PIN D4
#define TX_PIN D5
#define DE_RE  D3

SoftwareSerial mod(RX_PIN, TX_PIN);

// ================= MODBUS REQUEST =================
byte request[] = {0x01, 0x03, 0x00, 0x00, 0x00, 0x07, 0x04, 0x08};
byte response[19];

// ================= SENSOR VALUES =================
int moisture = 0;
float temperature = 0;
float ph = 0;
int ec = 0;
int nitrogen = 0;
int phosphorus = 0;
int potassium = 0;

// ================= FIREBASE RTDB (AgriSmart RW / edissaproject) =================
// Latest readings go to pending_farmer_sensor/latest — backend links to last pending farmer.
const char* FIREBASE_DB_URL    = "https://edissaproject-default-rtdb.firebaseio.com";
const char* FIREBASE_DB_SECRET = "aMIxpPpg3DZQePSJKTiGmZtECDA3";
const char* DEVICE_ID          = "ESP8266_SOIL_01";

uint32_t gSequence = 0;
WiFiClientSecure gFbClient;

void initFirebaseClient() {
  gFbClient.setInsecure();
  gFbClient.setTimeout(35000);
  gFbClient.setBufferSizes(5120, 512);
}

// ================= SETUP =================
void setup() {
  Serial.begin(115200);

  pinMode(DE_RE, OUTPUT);
  digitalWrite(DE_RE, LOW);

  mod.begin(4800);

  Serial.println("\n================================");
  Serial.println(" 7 IN 1 SOIL SENSOR SYSTEM ");
  Serial.println("================================");

  connectWiFiSmart();
  initFirebaseClient();
  Serial.println("Firebase RTDB ready (database secret auth)");
}

// ================= LOOP =================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFiSmart();
  }

  readSoilSensor();
  displayData();
  sendToServer();

  delay(5000);
}

// =====================================================
// SMART WIFI CONNECTION
// =====================================================
void connectWiFiSmart() {
  WiFi.mode(WIFI_STA);

  while (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n================================");

    for (int i = 0; i < 3; i++) {
      Serial.print("Trying WiFi: ");
      Serial.println(networks[i].ssid);

      WiFi.begin(networks[i].ssid, networks[i].password);

      int timeout = 10;
      while (WiFi.status() != WL_CONNECTED && timeout > 0) {
        delay(1000);
        Serial.print(".");
        timeout--;
      }

      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("\nConnected!");
        Serial.print("SSID: ");
        Serial.println(WiFi.SSID());
        Serial.print("IP: ");
        Serial.println(WiFi.localIP());
        return;
      }

      Serial.println("\nFailed this WiFi\n");
    }
  }
}

// =====================================================
// READ SOIL SENSOR
// =====================================================
void readSoilSensor() {
  while (mod.available()) {
    mod.read();
  }

  digitalWrite(DE_RE, HIGH);
  delay(10);

  mod.write(request, sizeof(request));
  mod.flush();

  digitalWrite(DE_RE, LOW);

  delay(1500);

  int avail = mod.available();
  if (avail < 19) {
    delay(500);
    avail = mod.available();
  }

  if (avail >= 19) {
    for (int i = 0; i < 19; i++) {
      response[i] = mod.read();
    }

    moisture    = ((response[3] << 8) | response[4]) + 2;
    temperature = (((response[5] << 8) | response[6]) / 10.0) + 2;
    ec          = ((response[7] << 8) | response[8]) + 7.9;
    ph          = (((response[9] << 8) | response[10]) / 10.0) + 2;
    nitrogen    = ((response[11] << 8) | response[12]) + 11.9;
    phosphorus  = ((response[13] << 8) | response[14]) + 3.67;
    potassium   = ((response[15] << 8) | response[16]) + 4.832;
  } else {
    Serial.println("No sensor response");
  }
}

// =====================================================
// DISPLAY DATA
// =====================================================
void displayData() {
  Serial.println("\n----------- SOIL DATA -----------");

  Serial.print("Moisture: ");
  Serial.println(moisture);

  Serial.print("Temperature: ");
  Serial.print(temperature);
  Serial.println(" C");

  Serial.print("pH: ");
  Serial.println(ph);

  Serial.print("EC: ");
  Serial.println(ec);

  Serial.print("Nitrogen: ");
  Serial.println(nitrogen);

  Serial.print("Phosphorus: ");
  Serial.println(phosphorus);

  Serial.print("Potassium: ");
  Serial.println(potassium);

  Serial.println("---------------------------------");
}

// =====================================================
// FIREBASE RTDB — write with database secret (?auth=SECRET)
// =====================================================
bool fbRtdbRequest(const char* method, const String& path, const String& body, int& code) {
  String url = String(FIREBASE_DB_URL) + path + "?auth=" + FIREBASE_DB_SECRET;

  HTTPClient http;
  if (!http.begin(gFbClient, url)) {
    code = -1;
    return false;
  }
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(35000);
  http.setReuse(false);

  if (strcmp(method, "PUT") == 0) {
    code = http.PUT(body);
  } else if (strcmp(method, "POST") == 0) {
    code = http.POST(body);
  } else {
    http.end();
    code = -2;
    return false;
  }

  String resp = http.getString();
  http.end();

  if (code < 200 || code >= 300) {
    Serial.print("[Firebase] ");
    Serial.print(method);
    Serial.print(" HTTP ");
    Serial.println(code);
    if (resp.length() > 0) Serial.println(resp);
    return false;
  }
  return true;
}

String buildSensorJson() {
  gSequence++;
  String j = "{";
  j += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  j += "\"source\":\"sensor\",";
  j += "\"sequence\":" + String(gSequence) + ",";
  j += "\"soil_moisture\":" + String(moisture) + ",";
  j += "\"temperature_c\":" + String(temperature, 1) + ",";
  j += "\"soil_ph\":" + String(ph, 1) + ",";
  j += "\"ph\":" + String(ph, 1) + ",";
  j += "\"ec_us_cm\":" + String(ec) + ",";
  j += "\"nitrogen\":" + String(nitrogen) + ",";
  j += "\"phosphorus\":" + String(phosphorus) + ",";
  j += "\"potassium\":" + String(potassium) + ",";
  j += "\"humidity_pct\":0,";
  j += "\"rainfall_mm\":0,";
  j += "\"soil_type\":\"loam\",";
  j += "\"online\":true,";
  j += "\"updated_at_ms\":" + String(millis());
  j += "}";
  return j;
}

// =====================================================
// SEND DATA TO SERVER (HTTPS)
// =====================================================
void sendToServer() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi not connected");
    return;
  }

  String payload = buildSensorJson();
  int code = 0;

  // Primary: latest reading for the last pending farmer (admin approval)
  if (!fbRtdbRequest("PUT", "/pending_farmer_sensor/latest.json", payload, code)) {
    Serial.println("Firebase pending_farmer_sensor upload failed");
    return;
  }
  fbRtdbRequest("POST", "/pending_farmer_sensor/history.json", payload, code);

  // Device archive
  String devicePath = String("/soil_sensors/") + DEVICE_ID + "/latest.json";
  fbRtdbRequest("PUT", devicePath, payload, code);
  fbRtdbRequest("POST", String("/soil_sensors/") + DEVICE_ID + "/history.json", payload, code);

  Serial.print("HTTP Response Code: ");
  Serial.println(code);
  Serial.println("Firebase RTDB OK");
  Serial.println("Path: pending_farmer_sensor/latest (last pending farmer)");
}
