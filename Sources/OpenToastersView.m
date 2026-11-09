//  OpenToastersView.m — "OpenToasters"
//
//  A from-scratch rebuild of the AfterDark "Flying Toasters" screensaver.
//  Same sprite assets, but:
//    * Zero per-frame allocations (fixed-size C struct pools, no ObjC churn).
//    * Sprite bitmaps decoded exactly once per animation session and
//      released when the saver stops — no slow growth over time.
//    * Unified right-to-left flight stream with a per-toaster angle
//      spread, depth/parallax layers, wind drift, per-toaster
//      speed/size/wobble/spin variation, weighted character classes,
//      and optional "special maneuvers" (tumbles & wind).
//
//  Assets: 350 PNG frames, 32 character types (characterN_MN.png).

#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#import <QuartzCore/QuartzCore.h>
#include <stdlib.h>

#define MAX_TOASTERS        96
#define TARGET_TOASTER_PTS  96.0   // sprite target size in points at z=1, size setting=1
#define BASE_SPEED_PTS      70.0   // base horizontal speed in points/sec at z=1, speed=1

// Low-opacity background sky: tiny stars (some twinkling) and a few
// large, faint, slowly drifting celestial bodies (soft glow disks).
typedef struct {
    CGPoint  pos;
    CGFloat  radius;
    CGFloat  alpha;       // base opacity (low)
    CGFloat  tAmp;        // twinkle amplitude (0 = static)
    CGFloat  tFreq;       // Hz
    CGFloat  tPhase;
    float    r, g, b;
} Star;

typedef struct {
    CGPoint  pos;
    CGFloat  vel;         // pts/sec, leftward
    CGFloat  radius;
    CGFloat  alpha;       // low
    float    r, g, b;
    CGGradientRef grad;   // center -> transparent, prebuilt once
} Body;

#pragma mark - Character / Toaster definitions

typedef struct {
    int      id;         // character id 1..32
    int      frameCount;
    CGImageRef *frames;  // retained CGImageRefs, decoded up-front
    CGFloat  maxDim;     // max pixel dimension across frames (for scale math)
} CharacterDef;

typedef struct {
    BOOL     active;
    CGPoint  pos;        // view coords (points, origin bottom-left)
    CGPoint  vel;        // pts/sec
    CGFloat  z;          // depth: 0.35 (far) .. 1.0 (near)
    CGFloat  scale;      // image-px -> pts
    CGFloat  angle;      // radians
    CGFloat  spin;       // rad/sec (0 = none)
    CGFloat  bobAmp;     // pts
    CGFloat  bobFreq;    // Hz
    CGFloat  bobPhase;   // rad
    CGFloat  frameRate;  // fps for the character animation
    double   frameAcc;   // fractional frame accumulator
    int      charIdx;    // index into CharacterDef
    int      frame;      // current frame
    CGFloat  flip;       // 1 = as-is (facing left), -1 = mirrored (facing right)
} Toaster;

#pragma mark - View

@interface OpenToastersView : ScreenSaverView {
    CharacterDef *_chars;
    int           _charCount;
    Toaster      *_pool;
    int          *_drawOrder;      // toaster indices sorted far->near
    int           _activeCount;

    double        _lastTime;
    double        _drawTime;
    int           _framesSeen;
    BOOL          _started;
    BOOL          _selfDriven;
    NSTimer      *_fallbackTimer;

    Star         *_stars;
    int           _starCount;
    Body         *_bodies;
    int           _bodyCount;

    // settings
    int           _settingCount;
    CGFloat       _settingSpeed;
    CGFloat       _settingSize;
    CGFloat       _settingBounce;   // bob amplitude multiplier (1.0 = default)
    CGFloat       _settingFlap;     // wingbeat / turn rate multiplier
    CGFloat       _settingWind;     // wind drift multiplier
    BOOL          _specials;
    BOOL          _enabled[33];    // enabled[charId]
    CGFloat       _lastSpeed;
    CGFloat       _lastSize;
    CGFloat       _lastBounce;
    CGFloat       _lastFlap;
}

- (void)applyConfigChanges;
- (void)printStats;
@end

#pragma mark - Helpers (static, no allocation)

static CGFloat uni(void) {
    // arc4random_double() is gone from the modern SDK; 24 bits is plenty here.
    return (CGFloat)(arc4random() >> 8) / 16777216.0;
}
static CGFloat uniRange(CGFloat lo, CGFloat hi) { return lo + (hi - lo) * uni(); }
static int rangeInt(int lo, int hi) { return lo + (int)arc4random_uniform((uint32_t)(hi - lo + 1)); }

typedef struct { int id, fr; CGImageRef img; } Entry;

#pragma mark - Forward declarations

@interface OpenToastersConfigView : NSView {
    ScreenSaverView *_saver;
    NSSlider *_countSlider;
    NSSlider *_speedSlider;
    NSSlider *_sizeSlider;
    NSSlider *_bounceSlider;
    NSSlider *_flapSlider;
    NSSlider *_windSlider;
    NSTextField *_countLabel;
    NSTextField *_speedLabel;
    NSTextField *_sizeLabel;
    NSTextField *_bounceLabel;
    NSTextField *_flapLabel;
    NSTextField *_windLabel;
    NSButton   *_specialsButton;
    NSMutableArray<NSButton *> *_charButtons;
}
- (instancetype)initWithSaver:(ScreenSaverView *)saver;
@end

static CGImageRef loadCGImageDecoded(NSString *path) {
    // Force immediate decode so the bitmap lives in memory once, for the
    // lifetime of the session (no re-decode on draw, no growth per frame).
    NSData *fileData = [NSData dataWithContentsOfFile:path];
    if (!fileData) return NULL;
    CGImageSourceRef src = CGImageSourceCreateWithData((CFDataRef)fileData, NULL);
    CGImageRef img = NULL;
    if (src) {
        NSDictionary *opts = @{ (id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                                (id)kCGImageSourceShouldCacheImmediately:     @YES };
        img = CGImageSourceCreateImageAtIndex(src, 0, (__bridge CFDictionaryRef)opts);
        CFRelease(src);
    }
    return img;
}

static void freeCharacter(CharacterDef *c) {
    if (c->frames) {
        for (int i = 0; i < c->frameCount; i++) CGImageRelease(c->frames[i]);
        free(c->frames);
        c->frames = NULL;
    }
}

#pragma mark - OpenToastersView

@implementation OpenToastersView

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        _pool = calloc(MAX_TOASTERS, sizeof(Toaster));
        _drawOrder = malloc(MAX_TOASTERS * sizeof(int));
        _lastSpeed  = 1.0;
        _lastSize   = 1.0;
        _lastBounce = 1.0;
        _lastFlap   = 1.0;
        [self loadSettings];
        [self loadAssets];
        [self resetScene:YES];
    }
    return self;
}

- (void)dealloc {
    [self releaseAssets];
    [self freeSky];
    if (_pool)      free(_pool);
    if (_drawOrder) free(_drawOrder);
    if (_chars) {
        for (int i = 0; i < _charCount; i++) freeCharacter(&_chars[i]);
        free(_chars);
    }
}

#pragma mark Settings

- (NSUserDefaults *)defaults {
    NSString *suite = [[NSBundle bundleForClass:self.class] bundleIdentifier];
    return [[NSUserDefaults alloc] initWithSuiteName:suite];
}

- (void)loadSettings {
    NSUserDefaults *d = [self defaults];
    _settingCount = MAX(1, MIN(48, [d integerForKey:@"numberOfToasters"] ?: 16));
    _settingSpeed = [d doubleForKey:@"speed"]   > 0 ? (CGFloat)[d doubleForKey:@"speed"]   : 1.0;
    _settingSize   = [d doubleForKey:@"size"]    > 0 ? (CGFloat)[d doubleForKey:@"size"]    : 1.0;
    // bounce/flap/wind may legitimately be 0.0 (the sliders allow it), so a
    // missing key (doubleForKey returns 0.0) must be told apart from 0.0.
    NSNumber *bv = [d objectForKey:@"bounce"]; _settingBounce = bv ? (CGFloat)bv.doubleValue : 1.0;
    NSNumber *fv = [d objectForKey:@"flap"];   _settingFlap   = fv ? (CGFloat)fv.doubleValue : 1.0;
    NSNumber *wv = [d objectForKey:@"wind"];   _settingWind   = wv ? (CGFloat)wv.doubleValue : 1.0;
    if (![d objectForKey:@"specials"]) _specials = YES; else _specials = [d boolForKey:@"specials"];

    NSArray *enabled = [d arrayForKey:@"enabledCharacters"];
    for (int i = 1; i <= 32; i++) _enabled[i] = YES;
    if (enabled) {
        for (int i = 1; i <= 32; i++) _enabled[i] = NO;
        for (NSNumber *n in enabled) if (n.integerValue >= 1 && n.integerValue <= 32) _enabled[n.integerValue] = YES;
    }
    if ([enabled count] == 0) return; // all off -> nothing to fly
}

#pragma mark Assets

- (void)loadAssets {
    if (_chars) return;
    NSBundle *b = [NSBundle bundleForClass:self.class];
    NSString *resDir = b.resourcePath;
    if (!resDir) return;

    NSArray<NSString *> *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:resDir error:NULL];
    if (files.count == 0) return;

    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^character(\\d+)_(\\d+)\\.png$"
                                                                       options:0 error:NULL];
    Entry *entries = NULL;
    size_t nEntries = 0, cap = 0;
    for (NSString *f in files) {
        NSTextCheckingResult *m = [re firstMatchInString:f options:0 range:NSMakeRange(0, f.length)];
        if (!m) continue;
        int id = [f substringWithRange:[m rangeAtIndex:1]].integerValue;
        int fr = [f substringWithRange:[m rangeAtIndex:2]].integerValue;
        CGImageRef img = loadCGImageDecoded([NSString stringWithFormat:@"%@/%@", resDir, f]);
        if (!img) continue;
        if (nEntries == cap) { cap = cap ? cap * 2 : 256; entries = realloc(entries, cap * sizeof(Entry)); }
        entries[nEntries++] = (Entry){ id, fr, img };
    }
    // sort by (id, fr)
    for (size_t i = 0; i < nEntries; i++)
        for (size_t j = i + 1; j < nEntries; j++) {
            Entry a = entries[i], b2 = entries[j];
            if (a.id > b2.id || (a.id == b2.id && a.fr > b2.fr)) {
                entries[i] = b2; entries[j] = a;
            }
        }

    // group into CharacterDefs
    size_t nChars = 0;
    for (size_t i = 0; i < nEntries; i++)
        if (i == 0 || entries[i].id != entries[i-1].id) nChars++;

    _chars = calloc(nChars, sizeof(CharacterDef));
    _charCount = (int)nChars;
    size_t i = 0;
    for (int c = 0; c < _charCount; c++) {
        int id = entries[i].id;
        size_t end = i;
        while (end < nEntries && entries[end].id == id) end++;
        _chars[c].id = id;
        _chars[c].frameCount = (int)(end - i);
        _chars[c].frames = malloc(_chars[c].frameCount * sizeof(CGImageRef));
        for (size_t k = i; k < end; k++) {
            _chars[c].frames[k - i] = entries[k].img; // transfer ownership
            CGFloat w = CGImageGetWidth(entries[k].img), h = CGImageGetHeight(entries[k].img);
            if (MAX(w, h) > _chars[c].maxDim) _chars[c].maxDim = MAX(w, h);
        }
        i = end;
    }
    free(entries);
}

- (void)releaseAssets {
    if (_chars) {
        for (int i = 0; i < _charCount; i++) freeCharacter(&_chars[i]);
        free(_chars);
        _chars = NULL;
        _charCount = 0;
    }
}

- (int)countEnabledByClass:(int)cls { // 0=normal,1=long,2=single
    int n = 0;
    for (int i = 0; i < _charCount; i++) {
        if (!_enabled[_chars[i].id]) continue;
        int f = _chars[i].frameCount;
        int kind = f == 1 ? 2 : (f >= 20 ? 1 : 0);
        if (kind == cls) n++;
    }
    return n;
}

- (int)randomCharOfKind:(int)kind { // returns charIdx or -1
    // two passes: count then select
    int n = 0, pick = -1;
    for (int i = 0; i < _charCount; i++) {
        if (!_enabled[_chars[i].id]) continue;
        int f = _chars[i].frameCount;
        int k = f == 1 ? 2 : (f >= 20 ? 1 : 0);
        if (k != kind) continue;
        if (arc4random_uniform((uint32_t)(n + 1)) == 0) pick = i;
        n++;
    }
    return pick;
}

#pragma mark Scene lifecycle

- (void)effectiveCount:(int *)out {
    // Linear area density: same toasters per square inch on any display,
    // so big/4K screens get proportionally more (12 at 1080p -> ~48 at 4K).
    CGFloat area = self.bounds.size.width * self.bounds.size.height;
    CGFloat k = area / (1920.0 * 1080.0);
    int n = (int)lround(_settingCount * k);
    *out = MAX(1, MIN(MAX_TOASTERS, n));
}

- (void)rollToaster:(Toaster *)t firstSpawn:(BOOL)first {
    NSRect b = self.bounds;
    double W = b.size.width, H = b.size.height;

    // -- character (weighted by class)
    double r = uni();
    double singleW = _specials ? 0.16 : 0.08;
    double longW    = 0.28;
    int kind = 0;
    if (r < singleW)       kind = 2;
    else if (r < singleW + longW) kind = 1;
    else                    kind = 0;
    int ci = [self randomCharOfKind:kind];
    if (ci < 0) { for (int k = 0; k < 3; k++) ci = [self randomCharOfKind:k]; }
    if (ci < 0) ci = rangeInt(0, _charCount - 1); // last resort
    CharacterDef *cd = &_chars[ci];

    // -- depth (parallax): far toasters are smaller AND slower
    CGFloat z = uniRange(0.35, 1.0);

    // -- direction: one unified stream, right -> left, with a spread of
    //    flight angles (±~20°) so the flock crosses the sky together but
    //    no two toasters share exactly the same line.
    double ang = M_PI + uniRange(-0.35, 0.35);

    // -- speed: base * settings * depth * jitter
    CGFloat speed = BASE_SPEED_PTS * _settingSpeed * z * uniRange(0.6, 1.4);
    CGPoint vel = CGPointMake(cos(ang) * speed, sin(ang) * speed);

    // -- scale: target pts * size setting * depth * jitter
    CGFloat scale = (TARGET_TOASTER_PTS * _settingSize / cd->maxDim) * z * uniRange(0.75, 1.3);

    // -- facing: every toaster flies leftward and the sprites face left,
    //    so nothing needs mirroring.
    CGFloat flip = 1.0;

    // -- spin: long-animation characters spin (their frames ARE the spin),
    //    a few others get a gentle tumble when specials are on
    CGFloat spin = 0.0;
    if (cd->frameCount >= 20) {
        spin = uniRange(0.8, 2.4) * (uni() < 0.5 ? 1.0 : -1.0);
    } else if (_specials && uni() < 0.05) {
        spin = uniRange(0.6, 1.4) * (uni() < 0.5 ? 1.0 : -1.0);
    }

    t->active    = YES;
    t->charIdx   = ci;
    t->z         = z;
    t->vel       = vel;
    t->scale     = scale;
    // Non-spinning toasters point their nose along their path (the sprite
    // natively faces left = M_PI); spinners get a random starting rotation.
    t->angle     = spin ? uni() * 2.0 * M_PI
                        : (ang - M_PI) + uniRange(-0.08, 0.08);
    t->spin      = spin;
    // Bounce height: the base range is the "soft" default (half of the
    // original 9-28); the Bounce option multiplies it (2.0 = original).
    t->bobAmp    = uniRange(4.5, 14.0) * _settingBounce;
    t->bobFreq   = uniRange(0.35, 1.3);
    t->bobPhase  = uni() * 2.0 * M_PI;
    // Softer wingbeats: the 12-frame flight loops run at ~0.5-0.75 beats/s
    // (was 0.75-1.3) so flapping reads as gentle against the bob; spinner
    // types (long loops) turn slowly at ~1/6..1/4 turn per second.
    // The Flap option scales the rate (0 = glide with no flapping).
    t->frameRate = (cd->frameCount == 1) ? 1.0
                   : (cd->frameCount >= 20) ? uniRange(8.0, 14.0) * _settingFlap
                                            : uniRange(6.0, 9.0) * _settingFlap;
    t->frameAcc  = 0;
    t->frame     = 0;
    t->flip      = flip;

    if (first) {
        // initial fill: scatter across the whole screen
        t->pos = CGPointMake(uni() * W, uni() * H);
    } else {
        // respawn: enter just off the edge we're flying away from
        CGFloat m = 180.0 * scale + 80.0;
        if (fabs(vel.x) >= fabs(vel.y)) {
            if (vel.x > 0) t->pos = CGPointMake(-m, uni() * H);
            else           t->pos = CGPointMake(W + m, uni() * H);
        } else {
            if (vel.y > 0) t->pos = CGPointMake(uni() * W, -m);
            else           t->pos = CGPointMake(uni() * W, H + m);
        }
    }
}

- (void)resetScene:(BOOL)first {
    if (!_chars || _charCount == 0) { _activeCount = 0; return; }
    int n = 0;
    [self effectiveCount:&n];
    _activeCount = n;
    for (int i = 0; i < MAX_TOASTERS; i++) {
        _pool[i].active = (i < _activeCount);
        if (_pool[i].active) [self rollToaster:&_pool[i] firstSpawn:first];
    }
}

#pragma mark Sky (stars + celestial bodies)

- (void)generateSky {
    [self freeSky];
    NSRect b = self.bounds;
    CGFloat W = b.size.width, H = b.size.height;
    if (W < 2 || H < 2) return;
    CGFloat area = W * H;

    // -- stars: density ~1 per 9000 pt^2 (≈230 at 1080p)
    int ns = (int)(area / 9000.0);
    ns = MAX(60, MIN(1400, ns));
    _stars = malloc(ns * sizeof(Star));
    _starCount = ns;
    for (int i = 0; i < ns; i++) {
        Star *s = &_stars[i];
        s->pos = CGPointMake(uni() * W, uni() * H);
        s->radius = (uni() < 0.05) ? uniRange(1.6, 2.4) : uniRange(0.5, 1.3);
        s->alpha  = uniRange(0.10, 0.45);
        // slight warm/cool variation, mostly white
        float c = (float)uni();
        if (c < 0.2)      { s->r = 1.0f; s->g = 0.93f; s->b = 0.82f; }
        else if (c < 0.4) { s->r = 0.82f; s->g = 0.88f; s->b = 1.0f; }
        else              { s->r = 0.95f; s->g = 0.96f; s->b = 1.0f; }
        if (uni() < 0.35) { s->tAmp = uniRange(0.05, 0.18); s->tFreq = uniRange(0.2, 0.8); }
        else              { s->tAmp = 0.0; s->tFreq = 0.0; }
        s->tPhase = uni() * 2.0 * M_PI;
    }

    // -- celestial bodies: a few large faint disks drifting slowly right->left
    int nb = (int)(area / 700000.0);
    nb = MAX(2, MIN(6, nb));
    _bodies = malloc(nb * sizeof(Body));
    _bodyCount = nb;
    static const float palettes[4][3] = {
        { 0.62f, 0.72f, 0.95f },  // ice blue
        { 0.95f, 0.86f, 0.68f },  // gold
        { 0.72f, 0.78f, 0.90f },  // lavender
        { 0.88f, 0.80f, 0.70f },  // tan
    };
    for (int i = 0; i < nb; i++) {
        Body *bd = &_bodies[i];
        bd->pos    = CGPointMake(uni() * W, uniRange(0.08, 0.92) * H);
        bd->vel    = uniRange(2.0, 7.0);
        bd->radius = uniRange(14.0, 44.0);
        bd->alpha  = uniRange(0.05, 0.13);
        const float *p = palettes[rangeInt(0, 3)];
        bd->r = p[0]; bd->g = p[1]; bd->b = p[2];
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGFloat aMax = MIN(0.3, (CGFloat)(bd->alpha * 2.2));
        CGFloat colors[8] = { bd->r, bd->g, bd->b, aMax,
                              bd->r, bd->g, bd->b, 0.0 };
        CGFloat locs[2] = { 0.0, 1.0 };
        bd->grad = CGGradientCreateWithColorComponents(cs, colors, locs, 2);
        CGColorSpaceRelease(cs);
    }
}

- (void)freeSky {
    if (_stars) { free(_stars); _stars = NULL; _starCount = 0; }
    if (_bodies) {
        for (int i = 0; i < _bodyCount; i++)
            if (_bodies[i].grad) CGGradientRelease(_bodies[i].grad);
        free(_bodies); _bodies = NULL; _bodyCount = 0;
    }
}

#pragma mark Animation

- (void)startAnimation {
    [super startAnimation];
    _started = YES;
    _framesSeen = 0;
    _lastTime = CACurrentMediaTime();
    [self generateSky];
    [self resetScene:YES];
    // Robustness: the ScreenSaverView engine normally drives animateOneFrame
    // itself; if it hasn't after 2.5s, drive ourselves at 60 Hz. (The timer
    // retains self until it fires, so this is safe if the view goes away.)
    [NSTimer scheduledTimerWithTimeInterval:2.5
                                     target:self
                                   selector:@selector(ensureDriven)
                                   userInfo:NULL
                                    repeats:NO];
}

- (void)stopAnimation {
    [super stopAnimation];
    _started = NO;
    _selfDriven = NO;
    if (_fallbackTimer) { [_fallbackTimer invalidate]; _fallbackTimer = NULL; }
    [self releaseAssets];   // give the ~10 MB of decoded bitmaps back
    [self freeSky];
}

- (void)ensureDriven {
    if (!_started || _selfDriven || _framesSeen >= 5) return;
    _selfDriven = YES;
    _fallbackTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0
                                                      target:self
                                                    selector:@selector(engineTick)
                                                    userInfo:NULL
                                                     repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_fallbackTimer forMode:NSEventTrackingRunLoopMode];
}

- (void)engineTick { [self animateOneFrame]; }

- (void)animateOneFrame {
    // Defensive: drain any autoreleased objects even if the engine's
    // display-link callback doesn't run one of its own.
    @autoreleasepool {
        [self tickOneFrame];
    }
}

- (void)tickOneFrame {
    if (!_chars || _charCount == 0) return;
    _framesSeen++;

    double now = CACurrentMediaTime();
    double dt = now - _lastTime;
    _lastTime = now;
    if (dt <= 0 || dt > 0.25) dt = 1.0 / 60.0;
    _drawTime = now;

    NSRect b = self.bounds;

    // celestial bodies drift slowly right->left, wrapping around
    for (int i = 0; i < _bodyCount; i++) {
        Body *bd = &_bodies[i];
        bd->pos.x -= bd->vel * dt;
        if (bd->pos.x < -bd->radius) {
            bd->pos.x = b.size.width + bd->radius;
            bd->pos.y = uniRange(0.08, 0.92) * b.size.height;
        }
    }

    for (int i = 0; i < _activeCount; i++) {
        Toaster *t = &_pool[i];
        if (!t->active) continue;

        // gentle global wind (slowly varying) for organic drift; the
        // horizontal component stays small enough that even the slowest,
        // farthest toasters keep drifting leftward
        CGFloat wx = (sin(now * 0.13) * 6.0 + sin(now * 0.07 + 1.7) * 4.0) * _settingSpeed * _settingWind;
        CGFloat wy = sin(now * 0.11 + 0.9) * 6.0 * _settingWind;

        t->pos.x += (t->vel.x + wx) * dt;
        t->pos.y += (t->vel.y + wy) * dt;
        t->angle += t->spin * dt;

        t->frameAcc += t->frameRate * dt;
        int fc = _chars[t->charIdx].frameCount;
        t->frame = (int)(t->frameAcc) % fc;

        // off-screen -> respawn
        CGFloat m = 180.0 * t->scale + 80.0;
        if (t->pos.x < -m || t->pos.x > b.size.width + m ||
            t->pos.y < -m || t->pos.y > b.size.height + m) {
            [self rollToaster:t firstSpawn:NO];
        }
    }

    // sort draw order far->near (insertion sort, in place, no allocation)
    for (int i = 0; i < _activeCount; i++) _drawOrder[i] = i;
    for (int i = 1; i < _activeCount; i++) {
        int key = _drawOrder[i];
        CGFloat kz = _pool[key].z;
        int j = i - 1;
        while (j >= 0 && _pool[_drawOrder[j]].z > kz) {
            _drawOrder[j + 1] = _drawOrder[j];
            j--;
        }
        _drawOrder[j + 1] = key;
    }

    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    if (!ctx) return;

    // background
    CGContextSaveGState(ctx);
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
    CGContextFillRect(ctx, dirtyRect);
    CGContextRestoreGState(ctx);

    // -- background sky: stars (some twinkling), then faint bodies
    for (int i = 0; i < _starCount; i++) {
        Star *s = &_stars[i];
        CGFloat a = s->alpha + s->tAmp * sin(_drawTime * s->tFreq * 2.0 * M_PI + s->tPhase);
        if (a < 0.02) a = 0.02;
        if (a > 0.75) a = 0.75;
        CGContextSetRGBFillColor(ctx, s->r, s->g, s->b, a);
        CGContextFillEllipseInRect(ctx, CGRectMake(s->pos.x - s->radius,
                                                   s->pos.y - s->radius,
                                                   s->radius * 2.0,
                                                   s->radius * 2.0));
    }
    for (int i = 0; i < _bodyCount; i++) {
        Body *bd = &_bodies[i];
        if (!bd->grad) continue;
        CGFloat x = bd->pos.x, y = bd->pos.y, r = bd->radius;
        CGContextSaveGState(ctx);
        CGContextClipToRect(ctx, CGRectMake(x - r, y - r, r * 2.0, r * 2.0));
        CGContextDrawRadialGradient(ctx, bd->grad,
                                    CGPointMake(x, y), 0.0,
                                    CGPointMake(x, y), r,
                                    kCGGradientDrawsBeforeStartLocation);
        CGContextRestoreGState(ctx);
    }

    if (!_chars || _charCount == 0) return;

    // crisp pixel art
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);

    for (int k = 0; k < _activeCount; k++) {
        int i = _drawOrder[k];
        Toaster *t = &_pool[i];
        if (!t->active) continue;

        CharacterDef *cd = &_chars[t->charIdx];
        CGImageRef img = cd->frames[t->frame % cd->frameCount];

        CGFloat bob = sin(_drawTime * t->bobFreq * 2.0 * M_PI + t->bobPhase) * t->bobAmp;

        CGContextSaveGState(ctx);
        CGContextTranslateCTM(ctx, t->pos.x, t->pos.y + bob);
        CGContextRotateCTM(ctx, t->angle);
        CGContextScaleCTM(ctx, t->scale * t->flip, t->scale);
        CGFloat iw = CGImageGetWidth(img);
        CGFloat ih = CGImageGetHeight(img);
        CGContextDrawImage(ctx, CGRectMake(-iw / 2.0, -ih / 2.0, iw, ih), img);
        CGContextRestoreGState(ctx);
    }
}

#pragma mark Config sheet

+ (NSView *)viewForBounds:(NSRect)bounds inScreenSaver:(ScreenSaverView *)screenSaver {
    return [[OpenToastersConfigView alloc] initWithSaver:screenSaver];
}

- (void)applyConfigChanges {
    [self loadSettings];
    // speed/size: rescale the running scene proportionally (no visual jump)
    if (_lastSpeed > 0) {
        CGFloat s = _settingSpeed / _lastSpeed;
        for (int i = 0; i < _activeCount; i++)
            if (_pool[i].active) { _pool[i].vel.x *= s; _pool[i].vel.y *= s; }
    }
    if (_lastSize > 0) {
        CGFloat s = _settingSize / _lastSize;
        for (int i = 0; i < _activeCount; i++)
            if (_pool[i].active) _pool[i].scale *= s;
    }
    _lastSpeed  = _settingSpeed;
    _lastSize   = _settingSize;
    _lastBounce = _settingBounce;
    _lastFlap   = _settingFlap;
    // count / characters / specials: rebuild the scene
    [self resetScene:NO];
}

- (void)printStats {
    printf("characters: %d, pool: %d active\n", _charCount, _activeCount);
    long totalFrames = 0;
    for (int i = 0; i < _charCount; i++) totalFrames += _chars[i].frameCount;
    printf("total frames: %ld\n", totalFrames);
}

@end

#pragma mark - Config view (programmatic, no nib)

@implementation OpenToastersConfigView

- (instancetype)initWithSaver:(ScreenSaverView *)saver {
    NSRect r = NSMakeRect(0, 0, 560, 550);
    self = [self initWithFrame:r];
    if (self) {
        _saver = saver;
        _charButtons = [NSMutableArray array];

        NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:
                             [[NSBundle bundleForClass:[saver class]] bundleIdentifier]];

        NSNumber *countVal  = @(MAX(1, MIN(48, [d integerForKey:@"numberOfToasters"] ? [d integerForKey:@"numberOfToasters"] : 16)));
        NSNumber *speedVal  = [d doubleForKey:@"speed"]  > 0 ? @([d doubleForKey:@"speed"])  : @1.0;
        NSNumber *sizeVal   = [d doubleForKey:@"size"]   > 0 ? @([d doubleForKey:@"size"])   : @1.0;
        NSNumber *bounceVal = [d objectForKey:@"bounce"] ? @([d doubleForKey:@"bounce"]) : @1.0;
        NSNumber *flapVal   = [d objectForKey:@"flap"]   ? @([d doubleForKey:@"flap"])   : @1.0;
        NSNumber *windVal   = [d objectForKey:@"wind"]   ? @([d doubleForKey:@"wind"])   : @1.0;

        NSSlider *countS, *speedS, *sizeS, *bounceS, *flapS, *windS;
        NSTextField *countL, *speedL, *sizeL, *bounceL, *flapL, *windL;

        // --- rows 0..5: label + slider + value
        [self addSlider:&countS  label:@"Toasters" min:1    max:48  value:countVal  intVal:YES valueLabel:&countL  row:0];
        [self addSlider:&speedS  label:@"Speed"    min:0.25 max:3.0 value:speedVal  intVal:NO  valueLabel:&speedL  row:1];
        [self addSlider:&sizeS   label:@"Size"     min:0.5  max:2.0 value:sizeVal   intVal:NO  valueLabel:&sizeL   row:2];
        [self addSlider:&bounceS label:@"Bounce"   min:0    max:2.0 value:bounceVal intVal:NO  valueLabel:&bounceL row:3];
        [self addSlider:&flapS   label:@"Flap"     min:0    max:2.0 value:flapVal   intVal:NO  valueLabel:&flapL   row:4];
        [self addSlider:&windS   label:@"Wind"     min:0    max:2.0 value:windVal   intVal:NO  valueLabel:&windL   row:5];
        _countSlider  = countS;  _countLabel  = countL;
        _speedSlider  = speedS;  _speedLabel  = speedL;
        _sizeSlider   = sizeS;   _sizeLabel   = sizeL;
        _bounceSlider = bounceS; _bounceLabel = bounceL;
        _flapSlider   = flapS;   _flapLabel   = flapL;
        _windSlider   = windS;   _windLabel   = windL;

        // --- row 6: specials checkbox
        _specialsButton = [NSButton checkboxWithTitle:@"Special maneuvers (tumbles & wind)"
                                                target:self action:@selector(configChanged:)];
        _specialsButton.state = [d objectForKey:@"specials"]
            ? ([d boolForKey:@"specials"] ? NSControlStateValueOn : NSControlStateValueOff)
            : NSControlStateValueOn;
        _specialsButton.frame = NSMakeRect(16, 0, 420, 20);
        [self placeRow:_specialsButton row:6];

        // --- row 7: characters caption
        NSTextField *cap = [NSTextField labelWithString:@"Characters:"];
        cap.frame = NSMakeRect(16, 0, 120, 18);
        [self placeRow:cap row:7];

        // --- character grid (8 x 4) under the caption
        NSBundle *b = [NSBundle bundleForClass:[saver class]];
        NSArray<NSNumber *> *enabled = [d arrayForKey:@"enabledCharacters"];

        for (int i = 0; i < 32; i++) {
            int id = i + 1;
            NSImage *img = [[NSImage alloc] initWithContentsOfFile:
                            [NSString stringWithFormat:@"%@/character%d_00.png", b.resourcePath, id]];
            NSButton *btn = [NSButton buttonWithTitle:@"" target:self action:@selector(charToggled:)];
            [btn setButtonType:NSButtonTypePushOnPushOff];
            [btn setImagePosition:NSImageOnly];
            [btn setImage:img];
            BOOL on = YES;
            if (enabled && enabled.count > 0) on = [enabled containsObject:@(id)];
            btn.state = on ? NSControlStateValueOn : NSControlStateValueOff;
            btn.tag = id;
            btn.frame = NSMakeRect(0, 0, 44, 44);
            [self placeGridItem:btn col:(i % 8) gridRow:(i / 8)];
            [_charButtons addObject:btn];
        }
    }
    return self;
}

- (void)addSlider:(NSSlider **)out label:(NSString *)lbl min:(CGFloat)mn max:(CGFloat)mx
            value:(NSNumber *)v intVal:(BOOL)isInt valueLabel:(NSTextField **)vl row:(int)row {
    NSTextField *l = [NSTextField labelWithString:lbl];
    l.frame = NSMakeRect(16, 0, 80, 18);
    [self placeRow:l row:row];

    NSSlider *s = [NSSlider sliderWithValue:v.doubleValue minValue:mn maxValue:mx
                                      target:self action:@selector(configChanged:)];
    s.frame = NSMakeRect(100, 0, 320, 20);
    [self placeRow:s row:row];

    NSTextField *t = [NSTextField labelWithString:isInt
        ? [NSString stringWithFormat:@"%d", (int)v.doubleValue]
        : [NSString stringWithFormat:@"%.2f", v.doubleValue]];
    t.alignment = NSTextAlignmentRight;
    t.frame = NSMakeRect(428, 0, 56, 18);
    [self placeRow:t row:row];

    *out = s;
    if (vl) *vl = t;
}

// Rows 0..7 sit at the top, 26 pt apart.
- (void)placeRow:(NSView *)v row:(int)row {
    NSRect r = v.frame;
    r.origin.y = self.bounds.size.height - 26 - row * 26 - r.size.height;
    v.frame = r;
    [self addSubview:v];
}

// Grid rows 0..3 sit below the caption; 56 pt cells, offset past rows 0..6.
- (void)placeGridItem:(NSView *)v col:(int)col gridRow:(int)gridRow {
    NSRect r = v.frame;
    r.origin.x = 16 + col * 64;
    r.origin.y = self.bounds.size.height - 26 - 7 * 26 - 14 - (gridRow + 1) * 56 - r.size.height;
    v.frame = r;
    [self addSubview:v];
}

- (void)configChanged:(NSControl *)sender {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:
                         [[NSBundle bundleForClass:[_saver class]] bundleIdentifier]];
    [d setInteger:(int)_countSlider.doubleValue forKey:@"numberOfToasters"];
    [d setDouble:_speedSlider.doubleValue forKey:@"speed"];
    [d setDouble:_sizeSlider.doubleValue forKey:@"size"];
    [d setDouble:_bounceSlider.doubleValue forKey:@"bounce"];
    [d setDouble:_flapSlider.doubleValue forKey:@"flap"];
    [d setDouble:_windSlider.doubleValue forKey:@"wind"];
    [d setBool:_specialsButton.state == NSControlStateValueOn forKey:@"specials"];

    _countLabel.stringValue  = [NSString stringWithFormat:@"%d", (int)_countSlider.doubleValue];
    _speedLabel.stringValue  = [NSString stringWithFormat:@"%.2f", _speedSlider.doubleValue];
    _sizeLabel.stringValue   = [NSString stringWithFormat:@"%.2f", _sizeSlider.doubleValue];
    _bounceLabel.stringValue = [NSString stringWithFormat:@"%.2f", _bounceSlider.doubleValue];
    _flapLabel.stringValue   = [NSString stringWithFormat:@"%.2f", _flapSlider.doubleValue];
    _windLabel.stringValue   = [NSString stringWithFormat:@"%.2f", _windSlider.doubleValue];

    [((OpenToastersView *)_saver) applyConfigChanges];
}

- (void)charToggled:(NSButton *)btn {
    NSMutableArray<NSNumber *> *arr = [NSMutableArray array];
    for (NSButton *b in _charButtons)
        if (b.state == NSControlStateValueOn) [arr addObject:@(b.tag)];
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:
                         [[NSBundle bundleForClass:[_saver class]] bundleIdentifier]];
    [d setObject:arr forKey:@"enabledCharacters"];
    [((OpenToastersView *)_saver) applyConfigChanges];
}

@end
