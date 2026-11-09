//  preview.m — offscreen test harness for the OpenToasters saver.
//
//  Loads the .saver bundle the same way the ScreenSaver engine does
//  (NSBundle principalClass), runs startAnimation + N frames of
//  animateOneFrame in real time, snapshots a few frames to PNG, and
//  reports memory footprint (phys_footprint) before/after.
//
//  Usage:
//    preview <path-to-.saver> [seconds] [fps] [width] [height] [every]
//    preview --config <path-to-.saver> <out.png>
//
//  [every] = snapshot every Nth frame (default: fps/2, i.e. one per 0.5 s
//  at 30 fps; pass 1 to snapshot every frame for motion/bob analysis).
//  --config renders the saver's Options sheet (the view the picker's
//  "Options..." button shows) to a PNG for layout verification.

#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#import <mach/mach.h>
#include <libproc.h>
#include <sys/resource.h>
#include <unistd.h>

// The ScreenSaver framework headers don't declare this; the engine calls it
// via the ObjC runtime. Declare it for ARC-safe direct calls.
@interface ScreenSaverView (OpenToastersConfigProbe)
+ (NSView *)viewForBounds:(NSRect)bounds inScreenSaver:(ScreenSaverView *)screenSaver;
@end

static long long physFootprintMB(void) {
    struct rusage_info_v2 info;
    if (proc_pid_rusage(getpid(), RUSAGE_INFO_V2, (rusage_info_t)&info) == 0) {
        return (long long)(info.ri_phys_footprint / (1024.0 * 1024.0));
    }
    return -1;
}

static void renderViewToPNG(NSView *v, NSString *path) {
    NSRect b = v.bounds;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithBitmapDataPlanes:NULL pixelsWide:(int)b.size.width pixelsHigh:(int)b.size.height
                       bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
                       isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
                       bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:gc];
    [v display];   // draws the view + all subviews
    [NSGraphicsContext restoreGraphicsState];
    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [png writeToFile:path atomically:YES];
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc >= 2 && strcmp(argv[1], "--config") == 0) {
            if (argc < 4) {
                fprintf(stderr, "usage: preview --config <bundle.saver> <out.png>\n");
                return 2;
            }
            [NSApplication sharedApplication];
            NSBundle *b = [NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[2]]];
            if (![b load]) { fprintf(stderr, "bundle failed to load\n"); return 1; }
            Class cls = [b principalClass];
            if (!cls) { fprintf(stderr, "no principal class\n"); return 1; }
            ScreenSaverView *view = [[cls alloc] initWithFrame:NSMakeRect(0, 0, 640, 480) isPreview:NO];
            NSView *cfg = [cls viewForBounds:NSMakeRect(0, 0, 560, 550) inScreenSaver:view];
            if (!cfg) { fprintf(stderr, "no config view\n"); return 1; }
            printf("config view: %s, bounds %gx%g, %lu subviews\n",
                   [NSStringFromClass([cfg class]) UTF8String],
                   cfg.bounds.size.width, cfg.bounds.size.height,
                   (unsigned long)cfg.subviews.count);
            for (NSView *s in cfg.subviews) {
                if ([s isKindOfClass:[NSSlider class]] || [s isKindOfClass:[NSButton class]] ||
                    [s isKindOfClass:[NSTextField class]]) {
                    NSString *txt = [s isKindOfClass:[NSTextField class]]
                        ? [(NSTextField *)s stringValue]
                        : ([s isKindOfClass:[NSButton class]] ? [(NSButton *)s title] : @"slider");
                    printf("  %-14s @ (%.0f, %.0f) %gx%g  \"%s\"\n",
                           NSStringFromClass([s class]).UTF8String,
                           s.frame.origin.x, s.frame.origin.y, s.frame.size.width, s.frame.size.height,
                           txt.UTF8String);
                }
            }
            renderViewToPNG(cfg, [NSString stringWithUTF8String:argv[3]]);
            printf("config rendered: %s\n", argv[3]);
            return 0;
        }

        if (argc < 2) {
            fprintf(stderr, "usage: preview <bundle.saver> [seconds] [fps] [width] [height] [every]\n");
            return 2;
        }
        NSString *bundlePath = [NSString stringWithUTF8String:argv[1]];
        int seconds = argc > 2 ? atoi(argv[2]) : 8;
        int fps     = argc > 3 ? atoi(argv[3]) : 30;
        int w = argc > 4 ? atoi(argv[4]) : 1280;
        int h = argc > 5 ? atoi(argv[5]) : 800;
        int every = argc > 6 ? atoi(argv[6]) : fps / 2;
        if (every < 1) every = 1;
        NSString *outDir = @"opentoaster_frames";
        [[NSFileManager defaultManager] createDirectoryAtPath:outDir
                                  withIntermediateDirectories:YES attributes:nil error:NULL];

        [NSApplication sharedApplication]; // some AppKit paths expect NSApp

        NSBundle *b = [NSBundle bundleWithPath:bundlePath];
        if (![b load]) { fprintf(stderr, "bundle failed to load\n"); return 1; }
        Class cls = [b principalClass];
        if (!cls) { fprintf(stderr, "no principal class\n"); return 1; }

        long long mbStart = physFootprintMB();
        printf("bundle: %s\n", [[b bundleIdentifier] UTF8String]);
        printf("principal class: %s\n", [NSStringFromClass(cls) UTF8String]);

        ScreenSaverView *view = [[cls alloc] initWithFrame:NSMakeRect(0, 0, w, h) isPreview:NO];
        [view startAnimation];

        if ([view respondsToSelector:@selector(printStats)]) [view performSelector:@selector(printStats)];
        printf("phys_footprint after load: %lld MB\n", physFootprintMB());

        // run the animation in real time
        long total = seconds * fps;
        for (long f = 0; f < total; f++) {
            @autoreleasepool {
                [view animateOneFrame];
                if ((f + 1) % every == 0) {
                    // snapshot to PNG
                    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                        initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h
                                       bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES
                                       isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
                                       bytesPerRow:0 bitsPerPixel:0];
                    NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
                    [NSGraphicsContext saveGraphicsState];
                    [NSGraphicsContext setCurrentContext:gc];
                    [view drawRect:NSMakeRect(0, 0, w, h)];
                    [NSGraphicsContext restoreGraphicsState];
                    NSString *out = [NSString stringWithFormat:@"%@/frame_%04ld.png", outDir, f / every];
                    NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                    [png writeToFile:out atomically:YES];
                    if ((f + 1) % (every * 15) == 0)
                        printf("snapshot: %s\n", [out UTF8String]);
                }
            }
            usleep((useconds_t)(1000000.0 / fps));
        }

        printf("phys_footprint after %ds: %lld MB\n", seconds, physFootprintMB());
        printf("delta: %lld MB\n", physFootprintMB() - mbStart);

        [view stopAnimation];
        printf("phys_footprint after stopAnimation: %lld MB\n", physFootprintMB());
    }
    return 0;
}
