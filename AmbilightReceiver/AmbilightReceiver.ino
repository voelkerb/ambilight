#include "FastLED.h"

FASTLED_USING_NAMESPACE

#if defined(FASTLED_VERSION) && (FASTLED_VERSION < 3001000)
#warning "Requires FastLED 3.1 or later; check github for latest code."
#endif
// AVR-methods.
// Clear a bit on a given position (bit) in given register/byte (sfr).
#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
// Set a bit on a given position (bit) in given register/byte (sfr).
#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))

#define DATA_PIN    3
//#define CLK_PIN   4
#define LED_TYPE    WS2811
#define COLOR_ORDER GRB
#define NUM_LEDS    460
CRGB leds[NUM_LEDS];

#define MICRO_PIN A0                                                    // DC offset in mic signal. I subtract this value from the raw sample of a 'quiet room' test.
#define NSAMPLES 16
#define sensitivity 120                                                       // Define maximum cutoff of potentiometer for cutting off sounds.
int DC_OFFSET = 372;

bool soundEnabled = false;    
static int16_t samplearray[NSAMPLES];                                         // Array of samples.
static uint16_t samplesum = 0;                                                // Sum of the last 64 samples. This had better be positive.
static uint8_t samplecount = 0;                                                // Sum of the last 64 samples. This had better be positive.
int maxValue = 0;     

uint8_t BRIGHTNESS = 250;
#define FRAMES_PER_SECOND  120

uint8_t fadeDelay = 100;
// List of patterns to cycle through.  Each is defined as a separate function below.

uint8_t gCurrentPatternNumber = 0; // Index number of which pattern is current
uint8_t gHue = 0; // rotating "base color" used by many of the patterns

bool pattern = false;

CRGB fadeColor = CRGB(0,0,0);

#define ARRAY_SIZE(A) (sizeof(A) / sizeof((A)[0]))

void setup() {
  
  // Init the ADC and start convertion
  // set prescale to 16
  // Stop all current interrupts
  cli();
  sbi(ADCSRA,ADPS2) ;
  cbi(ADCSRA,ADPS1) ;
  cbi(ADCSRA,ADPS0) ;
  // Enable global interrupts
  sei();
  Serial.begin(4000000);
  analogReference(EXTERNAL);
  delay(100);
  // tell FastLED about the LED strip configuration
  FastLED.addLeds<LED_TYPE, DATA_PIN, COLOR_ORDER>(leds, NUM_LEDS).setCorrection(TypicalLEDStrip);
  //FastLED.addLeds<LED_TYPE,DATA_PIN,CLK_PIN,COLOR_ORDER>(leds, NUM_LEDS).setCorrection(TypicalLEDStrip);
  FastLED.setBrightness(20);
  for (int i = 0; i < 80; i++) {
    gradient();
    FastLED.show();
    FastLED.delay(1000 / FRAMES_PER_SECOND);
  }
  //fadeColor = CRGB(255,0,0);
  pattern = true;
  FastLED.show();
  // set master brightness control

  long value = 0;
  for (int i = 0; i < 1000; i++) {
    value += analogRead(MICRO_PIN);
  }
  DC_OFFSET = value / 1000;
  Serial.print("DC Offset: ");
  Serial.println(DC_OFFSET);

  Serial.println("Setup done");
}

typedef void (*SimplePatternList[])();
SimplePatternList gPatterns = {fadeout, fade, gradient, rainbow, rainbowWithGlitter, confetti, sinelon, juggle, bpm};

bool changed = true;
void loop() {
  /*
  if (soundEnabled) {
    int16_t sample = analogRead(MICRO_PIN) - DC_OFFSET;                                     // Sample the microphone. Range will result in -512 to 512.
    sample = abs(sample);                                                         // Get the absolute value and DO NOT combine abs() into the previous line or this will break. Badly!
    if (sample < sensitivity) sample = 0;                                               // Filter ambient noise, which is adjustable via the potentiometer.
    if (samplecount == NSAMPLES) {
      maxValue = 0;
      samplecount = 0;
    }
    samplecount += 1;
    if (sample > maxValue) maxValue= sample;
    uint16_t bright = map(maxValue, 0, 500, 0, BRIGHTNESS);
    if (bright > BRIGHTNESS) bright = BRIGHTNESS;
    //Serial.print("bright:\t");
    //Serial.println(bright);
    FastLED.setBrightness(bright);
    changed = true;
  }*/
  if (pattern) {
    // Call the current pattern function once, updating the 'leds' array
    gPatterns[gCurrentPatternNumber]();
    
    changed = true;
    if (gCurrentPatternNumber == 1) {
      FastLED.delay(fadeDelay); 
    } else if (gCurrentPatternNumber != 0) {
      // insert a delay to keep the framerate modest
      FastLED.delay(1000 / FRAMES_PER_SECOND);
    } 
    // do some periodic updates
    EVERY_N_MILLISECONDS( 20 ) {
      gHue++;  // slowly cycle the "base color" through the rainbow
    }
  }

  if (Serial.available()) {
    // TODO: Do prefix stuff
    char c = Serial.read();
    if (c == 'p') {
      pattern = true;
      delay(1);
      int patternNum = Serial.read();
      if (patternNum < ARRAY_SIZE(gPatterns)) {
        gCurrentPatternNumber = uint8_t(patternNum);
      }
      Serial.print("Set Pattern: ");
      Serial.println(gCurrentPatternNumber);
    } else if (c == 'o') {
      pattern = true;
      fadeToBlackBy( leds, NUM_LEDS, 20);
      Serial.println("Set off");
      gCurrentPatternNumber = 0;
      fadeColor = CRGB(0,0,0);
    } else if (c == 'b') {
      delay(10);
      BRIGHTNESS = Serial.read();
      FastLED.setBrightness(BRIGHTNESS);
      changed = true;
    } else if (c == 'c') {
      while (Serial.available() < 3) {}
      int red = Serial.read();
      int green = Serial.read();
      int blue = Serial.read();
      pattern = true;
      gCurrentPatternNumber = 0;
      fadeColor = CRGB(red,green,blue);
    } else if (c == 's') {
      pattern = false;
      uint8_t col[3] = {}; 
      for (int i = 0; i < NUM_LEDS; i++) {
        while (Serial.available() < 3) {}
        Serial.readBytes( (char*)(&leds[i]), 3);
      }
      changed = true;
    } else if (c == 'm') {
      soundEnabled = true;
    } else if (c == 'n') {
      soundEnabled = false;
    }
  }
  
  // send the 'leds' array out to the actual LED strip
  if (changed) {
    FastLED.show();
    changed = false;
  }
}

void fadeout() {
  fadeTowardColor( leds, NUM_LEDS, fadeColor, 10);
  bool allDone = true;
  for (int i = 0; i < NUM_LEDS; i++) {
    if (leds[i] != fadeColor) {
      allDone = false;
      break;
    }
  }
  if (allDone) {
    Serial.println("Fade finished");
    pattern = false;
    // This has only sth todo with the first fade to black
    FastLED.setBrightness(BRIGHTNESS);
  }
}


void gradient() {
  uint8_t starthue = beatsin8(20, 0, 255);
  uint8_t endhue = beatsin8(35, 0, 255);
  if (starthue < endhue) {
    fill_gradient(leds, NUM_LEDS, CHSV(starthue,255,255), CHSV(endhue,255,255), FORWARD_HUES);    // If we don't have this, the colour fill will flip around
  } else {
    fill_gradient(leds, NUM_LEDS, CHSV(starthue,255,255), CHSV(endhue,255,255), BACKWARD_HUES);
  }
} // blendme()

void rainbow() {
  // FastLED's built-in rainbow generator
  fill_rainbow( leds, NUM_LEDS, gHue, 2);
}

void rainbowWithGlitter() {
  // built-in FastLED rainbow, plus some random sparkly glitter
  rainbow();
  addGlitter(80);
}

void addGlitter( fract8 chanceOfGlitter) {
  if ( random8() < chanceOfGlitter) {
    leds[ random16(NUM_LEDS) ] += CRGB::White;
  }
}

void confetti() {
  // random colored speckles that blink in and fade smoothly
  fadeToBlackBy( leds, NUM_LEDS, 10);
  int pos = random16(NUM_LEDS);
  leds[pos] += CHSV( gHue + random8(64), 200, 255);
}

void sinelon() {
  //a colored dot sweeping back and forth, with fading trails
  fadeToBlackBy( leds, NUM_LEDS, 20);
  CRGBPalette16 palette = LavaColors_p;
  int pos = beatsin16( 13, 0, NUM_LEDS - 1 );
  //leds[pos] += CHSV( gHue, 255, 192);
  leds[pos] = ColorFromPalette(palette, gHue, 255, 192);
}

void bpm() {
  // colored stripes pulsing at a defined Beats-Per-Minute (BPM)
  uint8_t BeatsPerMinute = 62;
  CRGBPalette16 palette = PartyColors_p;
  uint8_t beat = beatsin8( BeatsPerMinute, 64, 255);
  for ( int i = 0; i < NUM_LEDS; i++) { //9948
    leds[i] = ColorFromPalette(palette, gHue + (i * 2), beat - gHue + (i * 10));
  }
}

void juggle() {
  // eight colored dots, weaving in and out of sync with each other
  fadeToBlackBy( leds, NUM_LEDS, 20);
  byte dothue = 0;
  for ( int i = 0; i < 8; i++) {
    leds[beatsin16( i + 7, 0, NUM_LEDS - 1 )] |= CHSV(dothue, 200, 255);
    dothue += 32;
  }
}

uint8_t fadeState = 1;
uint8_t fadeRed = BRIGHTNESS;
uint8_t fadeSpeed = 1;


void fade() {
  if (fadeState == 1) {
    fadeTowardColor( leds, NUM_LEDS, CRGB(BRIGHTNESS,0,0), fadeSpeed);
    if (leds[0] == CRGB(BRIGHTNESS,0,0)) fadeState++;
  } else if (fadeState == 2) {
    fadeTowardColor( leds, NUM_LEDS, CRGB(0,BRIGHTNESS,0), fadeSpeed);
    if (leds[0] == CRGB(0,BRIGHTNESS,0)) fadeState++;
  } else if (fadeState == 3) {
    fadeTowardColor( leds, NUM_LEDS, CRGB(0,0,BRIGHTNESS), fadeSpeed);
    if (leds[0] == CRGB(0,0,BRIGHTNESS)) fadeState = 1;
  }
}






// Helper function that blends one uint8_t toward another by a given amount
void nblendU8TowardU8( uint8_t& cur, const uint8_t target, uint8_t amount) {
  if( cur == target) {
    return;
  }
  if( cur < target ) {
    uint8_t delta = target - cur;
    delta = scale8_video( delta, amount);
    cur += delta;
  } else {
    uint8_t delta = cur - target;
    delta = scale8_video( delta, amount);
    cur -= delta;
  }
}

// Blend one CRGB color toward another CRGB color by a given amount.
// Blending is linear, and done in the RGB color space.
// This function modifies 'cur' in place.
CRGB fadeTowardColor( CRGB& cur, const CRGB& target, uint8_t amount) {
  nblendU8TowardU8( cur.red,   target.red,   amount);
  nblendU8TowardU8( cur.green, target.green, amount);
  nblendU8TowardU8( cur.blue,  target.blue,  amount);
  return cur;
}

// Fade an entire array of CRGBs toward a given background color by a given amount
// This function modifies the pixel array in place.
void fadeTowardColor( CRGB* L, uint16_t N, const CRGB& bgColor, uint8_t fadeAmount) {
  for( uint16_t i = 0; i < N; i++) {
    fadeTowardColor( L[i], bgColor, fadeAmount);
  }
}

