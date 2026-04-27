#include "esp_camera.h"
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>

// Keep using your local board pin mapping.
#include "board_config.h"

const char *ssid = "Khuloud";
const char *password = "Khlood_14";

const char *cameraId = "camera_001";
const char *lotId = "lot_001";

const char *firebaseCameraUrl =
    "https://smartpasrk-default-rtdb.firebaseio.com/cameras/camera_001.json";

const unsigned long heartbeatIntervalMs = 15000;
unsigned long lastHeartbeatMs = 0;

void startCameraServer();
void setupLedFlash();
void sendHeartbeat();

void setup() {
  Serial.begin(115200);
  Serial.setDebugOutput(true);
  Serial.println();

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer = LEDC_TIMER_0;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.frame_size = FRAMESIZE_UXGA;
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 12;
  config.fb_count = 1;

  if (config.pixel_format == PIXFORMAT_JPEG) {
    if (psramFound()) {
      config.jpeg_quality = 10;
      config.fb_count = 2;
      config.grab_mode = CAMERA_GRAB_LATEST;
    } else {
      config.frame_size = FRAMESIZE_SVGA;
      config.fb_location = CAMERA_FB_IN_DRAM;
    }
  } else {
    config.frame_size = FRAMESIZE_240X240;
#if CONFIG_IDF_TARGET_ESP32S3
    config.fb_count = 2;
#endif
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("Camera init failed with error 0x%x\n", err);
    return;
  }

  sensor_t *s = esp_camera_sensor_get();
  if (s->id.PID == OV3660_PID) {
    s->set_vflip(s, 1);
    s->set_brightness(s, 1);
    s->set_saturation(s, -2);
  }
  if (config.pixel_format == PIXFORMAT_JPEG) {
    s->set_framesize(s, FRAMESIZE_QVGA);
  }

#if defined(CAMERA_MODEL_M5STACK_WIDE) || defined(CAMERA_MODEL_M5STACK_ESP32CAM)
  s->set_vflip(s, 1);
  s->set_hmirror(s, 1);
#endif

#if defined(CAMERA_MODEL_ESP32S3_EYE)
  s->set_vflip(s, 1);
#endif

#if defined(LED_GPIO_NUM)
  setupLedFlash();
#endif

  WiFi.begin(ssid, password);
  WiFi.setSleep(false);

  Serial.print("WiFi connecting");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.println("WiFi connected");

  startCameraServer();

  const String baseUrl = "http://" + WiFi.localIP().toString();
  Serial.printf("Camera Ready for lot %s with id %s\n", lotId, cameraId);
  Serial.printf("Base URL    : %s\n", baseUrl.c_str());
  Serial.printf("Stream URL  : %s/stream\n", baseUrl.c_str());
  Serial.printf("Snapshot URL: %s/capture\n", baseUrl.c_str());

  sendHeartbeat();
}

void loop() {
  if (millis() - lastHeartbeatMs >= heartbeatIntervalMs) {
    sendHeartbeat();
  }
  delay(50);
}

void sendHeartbeat() {
  lastHeartbeatMs = millis();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Heartbeat skipped: WiFi disconnected");
    return;
  }
  if (firebaseCameraUrl == nullptr || strlen(firebaseCameraUrl) == 0) {
    return;
  }

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  if (!http.begin(client, firebaseCameraUrl)) {
    Serial.println("Heartbeat skipped: failed to open endpoint");
    return;
  }

  http.addHeader("Content-Type", "application/json");
  const String baseUrl = "http://" + WiFi.localIP().toString();
  const String payload =
      "{"
      "\"id\":\"" + String(cameraId) + "\","
      "\"lot_id\":\"" + String(lotId) + "\","
      "\"base_url\":\"" + baseUrl + "\","
      "\"rtsp_url\":\"" + baseUrl + "\","
      "\"snapshot_url\":\"" + baseUrl + "/capture\","
      "\"stream_url\":\"" + baseUrl + "/stream\","
      "\"device_ip\":\"" + WiFi.localIP().toString() + "\","
      "\"status\":\"online\","
      "\"fps\":15,"
      "\"update_threshold_sec\":3,"
      "\"uptime_ms\":" + String(millis()) +
      "}";

  const int statusCode = http.PATCH(payload);
  Serial.printf("Heartbeat status: %d\n", statusCode);
  http.end();
}
