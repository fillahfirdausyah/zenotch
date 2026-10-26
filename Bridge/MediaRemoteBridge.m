// Loaded into /usr/bin/perl by NowPlayingService: since macOS 15.4 MediaRemote only answers Apple-signed processes.
// Protocol: one JSON object per line on stdout; commands (play, pause, toggle, next, previous, seek <sec>) on stdin.
#import <Foundation/Foundation.h>
#import <dlfcn.h>

typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetPIDFn)(dispatch_queue_t, void (^)(int));
typedef void (*MRGetIsPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRRegisterFn)(dispatch_queue_t);
typedef Boolean (*MRSendFn)(uint32_t, NSDictionary *);
typedef void (*MRSetElapsedFn)(double);

static MRGetInfoFn getInfo;
static MRGetPIDFn getPID;
static MRGetIsPlayingFn getIsPlaying;
static MRSendFn sendCommand;
static MRSetElapsedFn setElapsed;
static BOOL emitPending;
static NSData *lastArtwork;

static void writeLine(NSDictionary *object) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
    if (!data) return;
    fwrite(data.bytes, 1, data.length, stdout);
    fputc('\n', stdout);
    fflush(stdout);
}

static void copyValue(NSDictionary *info, NSString *key, NSMutableDictionary *out, NSString *outKey, Class cls) {
    id value = info[key];
    if ([value isKindOfClass:cls]) out[outKey] = value;
}

static void emitState(void) {
    dispatch_queue_t q = dispatch_get_main_queue();
    getInfo(q, ^(NSDictionary *info) {
        getPID(q, ^(int pid) {
            getIsPlaying(q, ^(Boolean playing) {
                NSMutableDictionary *out = [NSMutableDictionary dictionary];
                out[@"pid"] = @(pid);
                out[@"playing"] = playing ? @YES : @NO;
                if (info) {
                    copyValue(info, @"kMRMediaRemoteNowPlayingInfoTitle", out, @"title", NSString.class);
                    copyValue(info, @"kMRMediaRemoteNowPlayingInfoArtist", out, @"artist", NSString.class);
                    copyValue(info, @"kMRMediaRemoteNowPlayingInfoAlbum", out, @"album", NSString.class);
                    copyValue(info, @"kMRMediaRemoteNowPlayingInfoDuration", out, @"duration", NSNumber.class);
                    copyValue(info, @"kMRMediaRemoteNowPlayingInfoElapsedTime", out, @"elapsed", NSNumber.class);
                    copyValue(info, @"kMRMediaRemoteNowPlayingInfoPlaybackRate", out, @"rate", NSNumber.class);
                    NSDate *timestamp = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
                    if ([timestamp isKindOfClass:NSDate.class]) out[@"timestamp"] = @(timestamp.timeIntervalSince1970);
                    NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                    if (![artwork isKindOfClass:NSData.class] || artwork.length == 0) artwork = nil;
                    // Artwork is large, so only send it when it changes.
                    if (artwork && [artwork isEqualToData:lastArtwork]) {
                        out[@"artworkUnchanged"] = @YES;
                    } else if (artwork) {
                        out[@"artwork"] = [artwork base64EncodedStringWithOptions:0];
                    }
                    lastArtwork = artwork;
                } else {
                    lastArtwork = nil;
                }
                writeLine(out);
            });
        });
    });
}

// MediaRemote fires several notifications per track change; coalesce them into one emit.
static void scheduleEmit(void) {
    if (emitPending) return;
    emitPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 80 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        emitPending = NO;
        emitState();
    });
}

static void handleCommand(NSString *line) {
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@" "];
    NSString *name = parts.firstObject;
    if ([name isEqualToString:@"play"]) sendCommand(0, nil);
    else if ([name isEqualToString:@"pause"]) sendCommand(1, nil);
    else if ([name isEqualToString:@"toggle"]) sendCommand(2, nil);
    else if ([name isEqualToString:@"next"]) sendCommand(4, nil);
    else if ([name isEqualToString:@"previous"]) sendCommand(5, nil);
    else if ([name isEqualToString:@"seek"] && parts.count > 1) setElapsed(parts[1].doubleValue);
    else if ([name isEqualToString:@"refresh"]) {
        lastArtwork = nil;
        emitState();
    }
}

// Called through perl's DynaLoader as an XSUB, so it receives (interpreter, CV*) and ignores both.
void zen_media_bridge_run(void *interpreter, void *cv) {
    (void)interpreter;
    (void)cv;
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!handle) exit(2);
    getInfo = (MRGetInfoFn)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
    getPID = (MRGetPIDFn)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationPID");
    getIsPlaying = (MRGetIsPlayingFn)dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
    sendCommand = (MRSendFn)dlsym(handle, "MRMediaRemoteSendCommand");
    setElapsed = (MRSetElapsedFn)dlsym(handle, "MRMediaRemoteSetElapsedTime");
    MRRegisterFn registerForNotifications = (MRRegisterFn)dlsym(handle, "MRMediaRemoteRegisterForNowPlayingNotifications");
    if (!getInfo || !getPID || !getIsPlaying || !sendCommand || !setElapsed || !registerForNotifications) exit(3);

    registerForNotifications(dispatch_get_main_queue());
    NSArray *names = @[
        @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
        @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
    ];
    for (NSString *name in names) {
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
            (void)note;
            scheduleEmit();
        }];
    }

    __block NSMutableData *pending = [NSMutableData data];
    dispatch_source_t input = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, STDIN_FILENO, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(input, ^{
        char buffer[512];
        ssize_t count = read(STDIN_FILENO, buffer, sizeof buffer);
        // The app closed our stdin (quit or crash): exit instead of lingering as an orphan.
        if (count <= 0) exit(0);
        [pending appendBytes:buffer length:(NSUInteger)count];
        NSString *text = [[NSString alloc] initWithData:pending encoding:NSUTF8StringEncoding] ?: @"";
        NSRange lastNewline = [text rangeOfString:@"\n" options:NSBackwardsSearch];
        if (lastNewline.location == NSNotFound) return;
        NSString *complete = [text substringToIndex:lastNewline.location];
        pending = [[text substringFromIndex:lastNewline.location + 1] dataUsingEncoding:NSUTF8StringEncoding].mutableCopy;
        for (NSString *line in [complete componentsSeparatedByString:@"\n"]) {
            if (line.length > 0) handleCommand(line);
        }
    });
    dispatch_resume(input);

    emitState();
    CFRunLoopRun();
}
