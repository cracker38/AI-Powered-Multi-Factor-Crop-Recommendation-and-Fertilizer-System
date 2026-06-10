/*
 * SOIL7In_one_9b.ino — ESP8266 → Firebase Realtime Database (AgriSmart RW)
 *
 * Board: NodeMCU / Wemos D1 mini ONLY (install esp8266 core in Arduino IDE).
 * View data: Firebase Console → Realtime Database → soil_sensors/<DEVICE_ID>/latest
 */

#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <time.h>

// ─── CONFIG ─────────────────────────────────────────────────────────────────

const char* WIFI_SSID     = "IT Elias";
const char* WIFI_PASSWORD = "00998877660";

const char* FIREBASE_API_KEY = "AIzaSyAhqYyWDFv1jeG5NDRDURo9IZV44JQFx9s";
// Primary URL — if writes fail with 404, uncomment FALLBACK_DB_URL below
const char* FIREBASE_DB_URL  = "https://edissaproject-default-rtdb.firebaseio.com";
// const char* FIREBASE_DB_URL = "https://edissaproject-default-rtdb.europe-west1.firebasedatabase.app";

const char* FIREBASE_EMAIL    = "uwayiedissa@gmail.com";
const char* FIREBASE_PASSWORD = "Edissa@123";

const char* DEVICE_ID = "ESP8266_SOIL_01";

const unsigned long SEND_INTERVAL_MS = 5000;
const uint8_t MAX_HTTP_RETRIES       = 3;

#define USE_DEMO_SENSORS true
#define SOIL_RX_PIN 4
#define SOIL_TX_PIN 5

// ─── BUFFERS (avoid String heap fragmentation on ESP8266) ───────────────────

static const size_t TOKEN_MAX   = 2400;
static const size_t JSON_MAX    = 768;
static const size_t RESPONSE_MAX = 512;

char gIdToken[TOKEN_MAX];
char gRefreshToken[TOKEN_MAX];
unsigned long gTokenExpiryMs = 0;

char gJsonBody[JSON_MAX];
char gHttpResponse[RESPONSE_MAX];

WiFiClientSecure gSecure;
bool gSecureReady = false;

// ─── STATE MACHINE ──────────────────────────────────────────────────────────

enum AppState : uint8_t {
  ST_WIFI,
  ST_TIME,
  ST_AUTH,
  ST_PROBE_DB,
  ST_SEED,
  ST_IDLE,
  ST_SEND,
  ST_BACKOFF,
};

AppState gState = ST_WIFI;
unsigned long gStateAtMs    = 0;
unsigned long gLastSendMs   = 0;
unsigned long gBackoffMs    = 2000;
uint32_t      gSequence     = 0;
uint8_t       gDemoPreset   = 0;
uint16_t      gNoise        = 1234;
bool          gDemoSeeded   = false;

// ─── SENSOR PAYLOAD ─────────────────────────────────────────────────────────

struct SoilPacket {
  float temperature_c;
  float humidity_pct;
  float soil_moisture;
  float nitrogen;
  float phosphorus;
  float potassium;
  float ph;
  float ec_us_cm;
  float rainfall_mm;
  const char* soil_type;
  const char* season;
  const char* district;
  const char* label;
};

struct DemoFarm {
  SoilPacket base;
};

const DemoFarm DEMO_FARMS[] = {
  {{24.2f, 72.f, 58.f, 90.f, 42.f, 43.f, 6.5f, 850.f, 680.f, "loam",     "season_b", "kigali",    "Kigali maize"}},
  {{18.5f, 78.f, 62.f, 110.f, 55.f, 180.f, 5.8f, 1200.f, 920.f, "volcanic", "season_a", "musanze",   "Musanze potato"}},
  {{28.0f, 55.f, 38.f, 65.f, 28.f, 52.f, 6.2f, 620.f, 420.f, "sandy",    "season_c", "nyagatare", "Nyagatare cassava"}},
};
const uint8_t DEMO_FARM_COUNT = sizeof(DEMO_FARMS) / sizeof(DEMO_FARMS[0]);

// ─── UTILITIES ──────────────────────────────────────────────────────────────

uint16_t prngNext() {
  gNoise = (uint16_t)(gNoise * 2053u + 13849u);
  return gNoise;
}

float prngDrift(float span) {
  return ((int16_t)prngNext() % 200 - 100) / 100.0f * span;
}

const char* rwandaSeason() {
  time_t now = time(nullptr);
  if (now < 1700000000) return "season_b";
  struct tm* t = localtime(&now);
  int m = t->tm_mon + 1;
  if (m >= 9 || m <= 1) return "season_a";
  if (m >= 2 && m <= 6) return "season_b";
  return "season_c";
}

void isoNow(char* out, size_t outLen) {
  time_t now = time(nullptr);
  if (now < 1700000000) {
    snprintf(out, outLen, "%lu", millis());
    return;
  }
  struct tm* t = gmtime(&now);
  strftime(out, outLen, "%Y-%m-%dT%H:%M:%SZ", t);
}

void ensureSecureClient() {
  if (gSecureReady) return;
  gSecure.setInsecure();
  gSecure.setTimeout(20000);
  gSecureReady = true;
}

bool httpRequest(const char* method, const char* url, const char* contentType,
                 const char* body, int* statusOut) {
  ensureSecureClient();

  HTTPClient http;
  if (!http.begin(gSecure, url)) {
    if (statusOut) *statusOut = -1;
    return false;
  }

  if (contentType && contentType[0]) {
    http.addHeader("Content-Type", contentType);
  }
  http.setTimeout(20000);

  int code;
  if (strcmp(method, "POST") == 0) {
    code = http.POST((uint8_t*)body, body ? strlen(body) : 0);
  } else if (strcmp(method, "PUT") == 0) {
    code = http.PUT((uint8_t*)body, body ? strlen(body) : 0);
  } else if (strcmp(method, "GET") == 0) {
    code = http.GET();
  } else {
    http.end();
    if (statusOut) *statusOut = -2;
    return false;
  }

  String resp = http.getString();
  resp.toCharArray(gHttpResponse, RESPONSE_MAX);
  http.end();

  if (statusOut) *statusOut = code;
  return code >= 200 && code < 300;
}

bool jsonPick(const char* json, const char* key, char* out, size_t outLen) {
  char pattern[48];
  snprintf(pattern, sizeof(pattern), "\"%s\":\"", key);
  const char* start = strstr(json, pattern);
  if (!start) return false;
  start += strlen(pattern);
  const char* end = strchr(start, '"');
  if (!end || (size_t)(end - start) >= outLen) return false;
  memcpy(out, start, end - start);
  out[end - start] = '\0';
  return true;
}

long jsonPickInt(const char* json, const char* key) {
  char pattern[32];
  snprintf(pattern, sizeof(pattern), "\"%s\":", key);
  const char* start = strstr(json, pattern);
  if (!start) return 0;
  return atol(start + strlen(pattern));
}

void clearAuth() {
  gIdToken[0] = '\0';
  gRefreshToken[0] = '\0';
  gTokenExpiryMs = 0;
}

// ─── WIFI + TIME ────────────────────────────────────────────────────────────

bool connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return true;

  WiFi.mode(WIFI_STA);
  WiFi.persistent(false);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  Serial.print("[WiFi] connecting");
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 25000) {
    delay(400);
    Serial.print(".");
    yield();
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] OK %s RSSI=%d\n", WiFi.localIP().toString().c_str(), WiFi.RSSI());
    return true;
  }

  Serial.println("[WiFi] FAILED");
  return false;
}

bool syncClock() {
  configTime(2 * 3600, 0, "pool.ntp.org", "time.google.com");
  for (int i = 0; i < 15; i++) {
    if (time(nullptr) > 1700000000) {
      Serial.println("[NTP] OK");
      return true;
    }
    delay(400);
    yield();
  }
  Serial.println("[NTP] using millis timestamps");
  return false;
}

// ─── FIREBASE AUTH ──────────────────────────────────────────────────────────

bool firebaseSignIn() {
  char url[192];
  snprintf(url, sizeof(url),
           "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=%s",
           FIREBASE_API_KEY);

  char body[256];
  snprintf(body, sizeof(body),
           "{\"email\":\"%s\",\"password\":\"%s\",\"returnSecureToken\":true}",
           FIREBASE_EMAIL, FIREBASE_PASSWORD);

  int code = 0;
  if (!httpRequest("POST", url, "application/json", body, &code)) {
    Serial.printf("[Auth] signIn failed HTTP %d\n%s\n", code, gHttpResponse);
    return false;
  }

  if (!jsonPick(gHttpResponse, "idToken", gIdToken, TOKEN_MAX)) return false;
  jsonPick(gHttpResponse, "refreshToken", gRefreshToken, TOKEN_MAX);

  long expires = jsonPickInt(gHttpResponse, "expiresIn");
  if (expires < 120) expires = 3600;
  gTokenExpiryMs = millis() + (unsigned long)(expires - 90) * 1000UL;

  Serial.println("[Auth] signed in");
  return true;
}

bool firebaseRefresh() {
  if (gRefreshToken[0] == '\0') return false;

  char url[192];
  snprintf(url, sizeof(url),
           "https://securetoken.googleapis.com/v1/token?key=%s",
           FIREBASE_API_KEY);

  char body[TOKEN_MAX + 64];
  snprintf(body, sizeof(body), "grant_type=refresh_token&refresh_token=%s", gRefreshToken);

  int code = 0;
  if (!httpRequest("POST", url, "application/x-www-form-urlencoded", body, &code)) {
    Serial.printf("[Auth] refresh failed HTTP %d\n", code);
    return false;
  }

  char newToken[TOKEN_MAX];
  if (!jsonPick(gHttpResponse, "id_token", newToken, TOKEN_MAX)) return false;
  strncpy(gIdToken, newToken, TOKEN_MAX - 1);

  char newRefresh[TOKEN_MAX];
  if (jsonPick(gHttpResponse, "refresh_token", newRefresh, TOKEN_MAX)) {
    strncpy(gRefreshToken, newRefresh, TOKEN_MAX - 1);
  }

  long expires = jsonPickInt(gHttpResponse, "expires_in");
  if (expires < 120) expires = 3600;
  gTokenExpiryMs = millis() + (unsigned long)(expires - 90) * 1000UL;

  Serial.println("[Auth] token refreshed");
  return true;
}

bool ensureAuth() {
  if (gIdToken[0] != '\0' && millis() < gTokenExpiryMs) return true;
  if (gRefreshToken[0] != '\0' && firebaseRefresh()) return true;
  return firebaseSignIn();
}

// ─── RTDB PATHS ─────────────────────────────────────────────────────────────

void rtdbUrl(char* out, size_t outLen, const char* path) {
  snprintf(out, outLen, "%s%s.json?auth=%s", FIREBASE_DB_URL, path, gIdToken);
}

bool probeDatabase() {
  char url[TOKEN_MAX + 160];
  snprintf(url, sizeof(url), "%s/.json?auth=%s&shallow=true", FIREBASE_DB_URL, gIdToken);

  int code = 0;
  bool ok = httpRequest("GET", url, nullptr, nullptr, &code);
  Serial.printf("[RTDB] probe HTTP %d\n", code);

  if (code == 404) {
    Serial.println("[RTDB] Database not found — create Realtime Database in Firebase Console");
  } else if (code == 401) {
    Serial.println("[RTDB] Auth rejected — check RTDB rules and sensor user");
    clearAuth();
  }
  return ok;
}

// ─── DEMO / SENSOR READ ─────────────────────────────────────────────────────

#if !USE_DEMO_SENSORS
#include <SoftwareSerial.h>
SoftwareSerial soilSerial(SOIL_RX_PIN, SOIL_TX_PIN);
#endif

bool sampleDemo(SoilPacket& p) {
  const SoilPacket& b = DEMO_FARMS[gDemoPreset % DEMO_FARM_COUNT].base;
  p = b;
  p.temperature_c += prngDrift(1.8f);
  p.humidity_pct  += prngDrift(2.5f);
  p.soil_moisture += prngDrift(3.0f);
  p.nitrogen      += prngDrift(2.0f);
  p.phosphorus    += prngDrift(1.5f);
  p.potassium     += prngDrift(2.0f);
  p.ph            += prngDrift(0.12f);
  p.ec_us_cm      += prngDrift(40.f);
  p.rainfall_mm   += prngDrift(18.f);
  p.season = rwandaSeason();
  return true;
}

bool sampleSensor(SoilPacket& p) {
#if USE_DEMO_SENSORS
  return sampleDemo(p);
#else
  (void)p;
  return false;  // implement Modbus read in readRealSensor()
#endif
}

int buildJson(const SoilPacket& p, uint32_t seq, const char* ts) {
  return snprintf(
      gJsonBody, JSON_MAX,
      "{"
      "\"device_id\":\"%s\","
      "\"source\":\"%s\","
      "\"sequence\":%lu,"
      "\"label\":\"%s\","
      "\"district\":\"%s\","
      "\"soil_type\":\"%s\","
      "\"season\":\"%s\","
      "\"temperature_c\":%.1f,"
      "\"humidity_pct\":%.1f,"
      "\"soil_moisture\":%.1f,"
      "\"nitrogen\":%.1f,"
      "\"phosphorus\":%.1f,"
      "\"potassium\":%.1f,"
      "\"ph\":%.2f,"
      "\"ec_us_cm\":%.0f,"
      "\"rainfall_mm\":%.0f,"
      "\"online\":true,"
      "\"updated_at\":\"%s\","
      "\"updated_at_ms\":%lu"
      "}",
      DEVICE_ID,
      USE_DEMO_SENSORS ? "demo" : "sensor",
      (unsigned long)seq,
      p.label ? p.label : "field",
      p.district ? p.district : "kigali",
      p.soil_type ? p.soil_type : "loam",
      p.season ? p.season : rwandaSeason(),
      p.temperature_c, p.humidity_pct, p.soil_moisture,
      p.nitrogen, p.phosphorus, p.potassium,
      p.ph, p.ec_us_cm, p.rainfall_mm,
      ts, millis());
}

bool rtdbPut(const char* path, const char* body) {
  char url[TOKEN_MAX + 192];
  rtdbUrl(url, sizeof(url), path);

  for (uint8_t i = 0; i < MAX_HTTP_RETRIES; i++) {
    if (!ensureAuth()) return false;

    int code = 0;
    if (httpRequest("PUT", url, "application/json", body, &code)) return true;

    Serial.printf("[RTDB] PUT %s HTTP %d (try %u)\n", path, code, i + 1);
    if (code == 401) clearAuth();
    delay(300 * (i + 1));
    yield();
  }
  return false;
}

bool rtdbPush(const char* path, const char* body) {
  char url[TOKEN_MAX + 192];
  rtdbUrl(url, sizeof(url), path);

  for (uint8_t i = 0; i < MAX_HTTP_RETRIES; i++) {
    if (!ensureAuth()) return false;

    int code = 0;
    if (httpRequest("POST", url, "application/json", body, &code)) return true;

    Serial.printf("[RTDB] POST %s HTTP %d (try %u)\n", path, code, i + 1);
    if (code == 401) clearAuth();
    delay(300 * (i + 1));
    yield();
  }
  return false;
}

bool publishReading(const SoilPacket& p) {
  char ts[32];
  isoNow(ts, sizeof(ts));
  gSequence++;

  int jsonLen = buildJson(p, gSequence, ts);
  if (jsonLen <= 0 || jsonLen >= (int)JSON_MAX) {
    Serial.println("[RTDB] JSON buffer overflow");
    return false;
  }

  char latestPath[96];
  snprintf(latestPath, sizeof(latestPath), "/soil_sensors/%s/latest", DEVICE_ID);
  if (!rtdbPut(latestPath, gJsonBody)) return false;

  char histPath[96];
  snprintf(histPath, sizeof(histPath), "/soil_sensors/%s/history", DEVICE_ID);
  if (!rtdbPush(histPath, gJsonBody)) return false;

  char statusPath[96];
  snprintf(statusPath, sizeof(statusPath), "/soil_sensors/%s/meta", DEVICE_ID);
  char meta[160];
  snprintf(meta, sizeof(meta),
           "{\"device_id\":\"%s\",\"last_sequence\":%lu,\"last_upload\":\"%s\",\"mode\":\"%s\"}",
           DEVICE_ID, (unsigned long)gSequence, ts, USE_DEMO_SENSORS ? "demo" : "live");
  rtdbPut(statusPath, meta);

  Serial.printf("[RTDB] OK seq=%lu %s\n", (unsigned long)gSequence, p.label ? p.label : "");
  return true;
}

bool seedDemoData() {
  Serial.println("[Demo] seeding presets...");
  bool ok = true;

  for (uint8_t i = 0; i < DEMO_FARM_COUNT; i++) {
    gDemoPreset = i;
    SoilPacket p;
    sampleDemo(p);
    char path[112];
    snprintf(path, sizeof(path), "/soil_sensors/%s/history/demo_%u", DEVICE_ID, i + 1);
    char ts[32];
    isoNow(ts, sizeof(ts));
    buildJson(p, i + 1, ts);
    if (!rtdbPut(path, gJsonBody)) ok = false;
    delay(150);
    yield();
  }

  const char* banner =
      "{\"source\":\"demo\",\"message\":\"AgriSmart RW — 3 Rwanda demo farms loaded\"}";
  rtdbPut("/demo/latest", banner);
  return ok;
}

// ─── STATE HANDLERS ─────────────────────────────────────────────────────────

void enterState(AppState next) {
  gState = next;
  gStateAtMs = millis();
}

void handleBackoff() {
  if (millis() - gStateAtMs >= gBackoffMs) {
    gBackoffMs = min(gBackoffMs * 2, 60000UL);
    enterState(ST_SEND);
  }
}

void runStateMachine() {
  switch (gState) {
    case ST_WIFI:
      if (connectWiFi()) enterState(ST_TIME);
      else delay(2000);
      break;

    case ST_TIME:
      syncClock();
      enterState(ST_AUTH);
      break;

    case ST_AUTH:
      if (ensureAuth()) enterState(ST_PROBE_DB);
      else {
        Serial.println("[Auth] retry in 5s");
        delay(5000);
      }
      break;

    case ST_PROBE_DB:
      if (probeDatabase()) enterState(ST_SEED);
      else {
        Serial.println("[RTDB] probe failed — still trying uploads");
        enterState(ST_SEED);
      }
      break;

    case ST_SEED:
#if USE_DEMO_SENSORS
      if (!gDemoSeeded) {
        gDemoSeeded = seedDemoData();
        gLastSendMs = millis();
        enterState(ST_SEND);
        break;
      }
#endif
      enterState(ST_IDLE);
      break;

    case ST_IDLE:
      if (millis() - gLastSendMs >= SEND_INTERVAL_MS) {
        gDemoPreset = (uint8_t)((millis() / 15000UL) % DEMO_FARM_COUNT);
        enterState(ST_SEND);
      }
      break;

    case ST_SEND:
      if (WiFi.status() != WL_CONNECTED) {
        enterState(ST_WIFI);
        break;
      }
      {
        SoilPacket packet;
        if (!sampleSensor(packet)) {
          Serial.println("[Sensor] read failed");
          enterState(ST_BACKOFF);
          break;
        }
        if (publishReading(packet)) {
          gBackoffMs = 2000;
          gLastSendMs = millis();
          enterState(ST_IDLE);
        } else {
          enterState(ST_BACKOFF);
        }
      }
      break;

    case ST_BACKOFF:
      handleBackoff();
      break;
  }
}

// ─── ARDUINO ────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println();
  Serial.println("=== AgriSmart RW | SOIL 7-in-1 → Firebase RTDB ===");
  Serial.printf("Device: %s\n", DEVICE_ID);
  Serial.printf("Mode:   %s\n", USE_DEMO_SENSORS ? "DEMO" : "LIVE SENSOR");

#if !USE_DEMO_SENSORS
  soilSerial.begin(9600);
#endif
}

void loop() {
  runStateMachine();
  yield();
}
