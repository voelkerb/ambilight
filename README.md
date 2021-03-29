# Ambilight

A simple Ambilight appliaction for macOS.

  <img src="/docu/figures/Screenshot.jpg">

The application samples the edges of your screen and sends the LED pixel information over usb serial.

Color, and border can be adjusted. It automatically detects 16:9 movies and will therefore omit black bars (4:3 movies are not supported).

You can also control the Ambilight as an RGB light bulb over http requests, allowing you to add it to your SmartHome system e.g. using homebridge. 


# Light Controller
You can use any controller connected over USB serial. LED data is simply send with a preceding ```0x73``` and three ```0xff``` at the end, to keep track of frames. 

As an example, one can use an Arduino Uno and the following sketch.

```
#include "FastLED.h"
FASTLED_USING_NAMESPACE

#define DATA_PIN    3
#define LED_TYPE    WS2813
#define COLOR_ORDER GRB
#define NUM_LEDS    460
CRGB leds[NUM_LEDS];


void setup() {
  // Fast serial speed
  Serial.begin(4000000);
  // tell FastLED about the LED strip configuration
  FastLED.addLeds<LED_TYPE, DATA_PIN, COLOR_ORDER>(leds, NUM_LEDS).setCorrection(TypicalLEDStrip);
  // Standard brightness 
  FastLED.setBrightness(20);
  // Rainbow swirl at beginning
  for (int i = 0; i < 80; i++) {
    gradient();
    FastLED.show();
    FastLED.delay(10);
  }
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 's') {
      for (int i = 0; i < NUM_LEDS; i++) {
        while (Serial.available() < 3) {}
        Serial.readBytes( (char*)(&leds[i]), 3);
      }
      while (Serial.available() < 3) {}; // Read 3x 0xff
      for (int i = 0; i < 3; i++) { Serial.read(); }
      FastLED.show();
    } 
  }
}
```

If you want to have support for the remaining features such as e.g. confetti pattern and direct brightness control, see Arduino sketch [AmbilightReceiver](/AmbilightReceiver/AmbilightReceiver.ino).


# ToDo

* store all settings s.t. they are not reset upon app restart. 
* make number of horizontal and vertical LEDs a setting.
* maybe add support for skipping leds (if e.g. there are no at the bottom).
* WiFi LED support for e.g. ESP8266 ambilight.

