/*
 * metalutil.mm
 *
 * Metal utility functions implementation
 * Objective-C++ implementation file
 */

#import "metalutil.h"

id<MTLLibrary> compileMetalLibrary(NSString* source,
                                    id<MTLDevice> device,
                                    NSError** error) {
    if (!source || !device) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalUtil"
                                        code:-1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid source or device"}];
        }
        return nil;
    }

    MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
    // Use fast math mode for better performance (relaxed IEEE 754 compliance)
    if (@available(macOS 15.0, *)) {
        options.mathMode = MTLMathModeFast;
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        options.fastMathEnabled = YES;
        #pragma clang diagnostic pop
    }

    id<MTLLibrary> library = [device newLibraryWithSource:source
                                                  options:options
                                                    error:error];

    if (!library && error && *error) {
        LOG_F(ERROR, "Metal shader compilation failed: %s",
              [[*error localizedDescription] UTF8String]);
    }

    return library;
}

id<MTLLibrary> loadMetalLibrary(NSString* path,
                                id<MTLDevice> device,
                                NSError** error) {
    if (!path || !device) {
        if (error) {
            *error = [NSError errorWithDomain:@"MetalUtil"
                                        code:-1
                                    userInfo:@{NSLocalizedDescriptionKey: @"Invalid path or device"}];
        }
        return nil;
    }

    // Check if file exists
    NSFileManager* fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        LOG_F(ERROR, "Metal library not found at path: %s", [path UTF8String]);
        if (error) {
            *error = [NSError errorWithDomain:@"MetalUtil"
                                        code:-2
                                    userInfo:@{NSLocalizedDescriptionKey: @"File not found"}];
        }
        return nil;
    }

    NSURL* url = [NSURL fileURLWithPath:path];
    id<MTLLibrary> library = [device newLibraryWithURL:url error:error];

    if (!library && error && *error) {
        LOG_F(ERROR, "Failed to load Metal library from %s: %s",
              [path UTF8String],
              [[*error localizedDescription] UTF8String]);
    }

    return library;
}
