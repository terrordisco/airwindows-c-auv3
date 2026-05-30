//
//  BridgingHeader.h
//  AirwindowsAUExtension target
//
//  Exposes the AirwindowsDSP framework's ObjC headers to Swift in this
//  extension target. Importing the framework umbrella header is enough
//  — Swift then sees AirwindowsAudioUnit, AirwindowsEngine,
//  AirwindowsEffectInfo, etc. as if they were native Swift types.
//
//  The framework itself wraps C++ (Chris Johnson's airwin2rack DSP).
//  Swift never touches the C++ directly — every C++ call goes through
//  ObjC++ inside the framework. The three-language stack is:
//
//      Swift (UI, view models, host shell)
//        │
//        ▼
//      Objective-C (AirwindowsAudioUnit.h / AirwindowsBridge.h)
//        │
//        ▼
//      Objective-C++ (.mm files in AirwindowsDSP/Bridge)
//        │
//        ▼
//      C++ (AirwinRegistry + 350 effect classes in AirwindowsDSP/Airwin)
//

#import <AirwindowsDSP/AirwindowsDSP.h>
