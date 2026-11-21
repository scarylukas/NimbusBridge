// Independent public-API probe. No restricted entitlement injection or OS changes.
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/hidsystem/IOHIDUserDevice.h>
#include <IOKit/hid/IOHIDManager.h>
#include <stdio.h>
#include <unistd.h>

int main(void) {
    const UInt8 bytes[] = {
        0x05,0x01,0x09,0x05,0xA1,0x01,
        0x05,0x09,0x19,0x01,0x29,0x08,
        0x15,0x00,0x25,0x01,0x75,0x01,0x95,0x08,0x81,0x02,0xC0
    };
    CFDataRef descriptor = CFDataCreate(NULL, bytes, sizeof(bytes));
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef serial = CFUUIDCreateString(NULL, uuid);
    const void *keys[] = {CFSTR(kIOHIDReportDescriptorKey), CFSTR(kIOHIDProductKey), CFSTR(kIOHIDSerialNumberKey)};
    const void *values[] = {descriptor, CFSTR("NimbusBridge IOHID Development Probe"), serial};
    CFDictionaryRef properties = CFDictionaryCreate(NULL, keys, values, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOHIDUserDeviceRef device = IOHIDUserDeviceCreateWithProperties(NULL, properties, 0);
    int result = 1;
    if (!device) {
        puts("FAIL: IOHIDUserDeviceCreateWithProperties returned NULL. No device created.");
    } else {
        IOHIDManagerRef manager = IOHIDManagerCreate(NULL, 0);
        const void *matchKey = CFSTR(kIOHIDSerialNumberKey), *matchValue = serial;
        CFDictionaryRef match = CFDictionaryCreate(NULL, &matchKey, &matchValue, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        IOHIDManagerSetDeviceMatching(manager, match);
        bool enumerated = false;
        for (int i = 0; i < 20; i++) {
            CFSetRef devices = IOHIDManagerCopyDevices(manager);
            enumerated = devices && CFSetGetCount(devices) > 0;
            if (devices) CFRelease(devices);
            if (enumerated) break;
            usleep(100000);
        }
        printf("Independent IOHIDManager enumeration: %s\n", enumerated ? "yes" : "no");
        puts("No reports generated; game compatibility unverified. Releasing temporary device.");
        result = enumerated ? 0 : 2;
        CFRelease(match);
        CFRelease(manager);
        CFRelease(device);
    }
    CFRelease(properties);
    CFRelease(serial);
    CFRelease(uuid);
    CFRelease(descriptor);
    return result;
}
