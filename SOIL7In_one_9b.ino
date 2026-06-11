#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <SoftwareSerial.h>
#include <time.h>

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
float ec = 0;
float nitrogen = 0;
float phosphorus = 0;
float potassium = 0;

bool gSensorOk = false;
uint32_t gSequence = 0;
WiFiClientSecure gFbClient;

// ================= FIREBASE RTDB (AgriSmart RW / edissaproject) =================
const char* FIREBASE_DB_URL    = "https://edissaproject-default-rtdb.firebaseio.com";
const char* FIREBASE_DB_SECRET = "aMIxpPpg3DZQePSJKTiGmZtECDA3";
const char* FIREBASE_EMAIL     = "bostonelie0@gmail.com";
const char* DEVICE_ID          = "ESP8266_SOIL_01";

// ================= FORWARD DECLARATIONS =================
void connectWiFiSmart();
void initFirebaseClient();
void initNtpTime();
void readSoilSensor();
void displayData();
void sendToServer();
bool fbRtdbRequest(const char* method, const String& path, const String& body, int& code);
String buildFirebaseJson();
uint64_t nowEpochMs();

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
  initNtpTime();
  initFirebaseClient();
  Serial.println("Firebase RTDB ready (database secret auth)");
}

// ================= LOOP =================
void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFiSmart();
    initNtpTime();
    initFirebaseClient();
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
  WiFi.setAutoReconnect(true);

  while (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n================================");

    for (int i = 0; i < 3; i++) {
      Serial.print("Trying WiFi: ");
      Serial.println(networks[i].ssid);

      WiFi.disconnect(true);
      delay(200);
      WiFi.begin(networks[i].ssid, networks[i].password);

      int timeout = 15;
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

      Serial.println("\nFailed this WiFi");
    }

    Serial.println("Retrying all networks in 5s...");
    delay(5000);
  }
}

// =====================================================
// NTP — real timestamp for admin "latest" sensor pick
// =====================================================
void initNtpTime() {
  if (WiFi.status() != WL_CONNECTED) return;

  configTime(0, 0, "pool.ntp.org", "time.google.com");
  Serial.print("Syncing time (NTP)");

  for (int i = 0; i < 20; i++) {
    time_t now = time(nullptr);
    if (now > 1700000000) {
      Serial.println(" OK");
      return;
    }
    delay(500);
    Serial.print(".");
  }
  Serial.println(" (using millis fallback)");
}

uint64_t nowEpochMs() {
  time_t now = time(nullptr);
  if (now > 1700000000) {
    return (uint64_t)now * 1000ULL;
  }
  return (uint64_t)millis();
}

void initFirebaseClient() {
  gFbClient.setInsecure();
  gFbClient.setTimeout(35000);
  gFbClient.setBufferSizes(5120, 512);
}

// =====================================================
// READ SOIL SENSOR
// =====================================================
bool modbusCrcOk(const byte* buf, int len) {
  if (len < 4) return false;
  uint16_t crc = 0xFFFF;
  for (int i = 0; i < len - 2; i++) {
    crc ^= buf[i];
    for (int b = 0; b < 8; b++) {
      if (crc & 1) crc = (crc >> 1) ^ 0xA001;
      else crc >>= 1;
    }
  }
  uint16_t recv = (uint16_t)buf[len - 1] << 8 | buf[len - 2];
  return crc == recv;
}

void readSoilSensor() {
  gSensorOk = false;

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

  if (avail < 19) {
    Serial.println("No sensor response");
    return;
  }

  for (int i = 0; i < 19; i++) {
    response[i] = mod.read();
  }

  if (response[0] != 0x01 || response[1] != 0x03) {
    Serial.println("Invalid Modbus header");
    return;
  }

  if (!modbusCrcOk(response, 19)) {
    Serial.println("Modbus CRC check failed");
    return;
  }

  moisture    = ((response[3] << 8) | response[4]) + 2;
  temperature = (((response[5] << 8) | response[6]) / 10.0) + 2;
  ec          = ((response[7] << 8) | response[8]) + 7.9;
  ph          = (((response[9] << 8) | response[10]) / 10.0) + 2;
  nitrogen    = ((response[11] << 8) | response[12]) + 11.9;
  phosphorus  = ((response[13] << 8) | response[14]) + 3.67;
  potassium   = ((response[15] << 8) | response[16]) + 4.832;

  gSensorOk = true;
}

// =====================================================
// DISPLAY DATA
// =====================================================
void displayData() {
  Serial.println("\n----------- SOIL DATA -----------");

  if (!gSensorOk) {
    Serial.println("Waiting for valid sensor frame...");
    Serial.println("---------------------------------");
    return;
  }

  Serial.print("Moisture: ");
  Serial.println(moisture);

  Serial.print("Temperature: ");
  Serial.print(temperature, 1);
  Serial.println(" C");

  Serial.print("pH: ");
  Serial.println(ph, 1);

  Serial.print("EC: ");
  Serial.println(ec, 1);

  Serial.print("Nitrogen: ");
  Serial.println(nitrogen, 1);

  Serial.print("Phosphorus: ");
  Serial.println(phosphorus, 2);

  Serial.print("Potassium: ");
  Serial.println(potassium, 3);

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
    Serial.print(" ");
    Serial.print(path);
    Serial.print(" HTTP ");
    Serial.println(code);
    if (resp.length() > 0) Serial.println(resp);
    return false;
  }
  return true;
}

String buildFirebaseJson() {
  gSequence++;
  uint64_t ts = nowEpochMs();

  String j = "{";
  j += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  j += "\"email\":\"" + String(FIREBASE_EMAIL) + "\",";
  j += "\"source\":\"sensor\",";
  j += "\"sequence\":" + String(gSequence) + ",";
  j += "\"soil_moisture\":" + String(moisture) + ",";
  j += "\"temperature_c\":" + String(temperature, 1) + ",";
  j += "\"soil_ph\":" + String(ph, 1) + ",";
  j += "\"ph\":" + String(ph, 1) + ",";
  j += "\"ec_us_cm\":" + String(ec, 1) + ",";
  j += "\"nitrogen\":" + String(nitrogen, 1) + ",";
  j += "\"phosphorus\":" + String(phosphorus, 2) + ",";
  j += "\"potassium\":" + String(potassium, 3) + ",";
  j += "\"humidity_pct\":0,";
  j += "\"rainfall_mm\":0,";
  j += "\"soil_type\":\"loam\",";
  j += "\"online\":true,";
  char tsBuf[24];
  snprintf(tsBuf, sizeof(tsBuf), "%llu", (unsigned long long)ts);
  j += "\"updated_at_ms\":";
  j += tsBuf;
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

  if (!gSensorOk) {
    Serial.println("Skip Firebase upload — no valid sensor reading");
    return;
  }

  String payload = buildFirebaseJson();
  int code = 0;
  bool okPending = false;
  bool okDevice = false;

  // Primary: admin approval — linked to last pending farmer
  okPending = fbRtdbRequest("PUT", "/pending_farmer_sensor/latest.json", payload, code);
  if (okPending) {
    fbRtdbRequest("POST", "/pending_farmer_sensor/history.json", payload, code);
  } else {
    Serial.println("pending_farmer_sensor upload failed — retrying device path");
  }

  // Device archive
  String latestPath = String("/soil_sensors/") + DEVICE_ID + "/latest.json";
  okDevice = fbRtdbRequest("PUT", latestPath, payload, code);
  if (okDevice) {
    fbRtdbRequest("POST", String("/soil_sensors/") + DEVICE_ID + "/history.json", payload, code);
  }

  if (okPending || okDevice) {
    Serial.print("HTTP Response Code: ");
    Serial.println(code);
    Serial.println("Firebase RTDB OK");
    Serial.println("Paths:");
    if (okPending) Serial.println("  pending_farmer_sensor/latest");
    if (okDevice) Serial.println("  soil_sensors/" + String(DEVICE_ID) + "/latest");
  } else {
    Serial.println("Firebase upload failed on all paths");
    gFbClient.stop();
    initFirebaseClient();
  }
}
