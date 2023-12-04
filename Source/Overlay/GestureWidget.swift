//
//  GestureWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/26.
//

import SwiftUI
import Combine

/// Service used by GestureWidget.
///
/// The GestureService comes with multiple gestures: tap, double-tap, drag, long-press, rotate, pinch and hover.
/// Other service can easily use the observe method to bind action to the gesture.
/// For some of gestures, users can observe them by specifying the location. Such as Tap gesture is divided into left and right.
///
public class GestureService : Service {
    
    /// Flag to determine if the built-in gesture is enabled or disabled
    @ViewState public private(set) var enabled = true
    
    /// Enable or disable the whole built-in gesture support
    /// - Parameter onOrOff: flag to determine if the built-in gesture is enabled or disabled
    ///
    public func configure(_ onOrOff: Bool) {
        self.enabled = onOrOff
    }
    
    //MARK: Observe
    
    public enum Gesture: Equatable {

        public enum Location: Equatable {
            case all, left, right
            
            public static func == (a: Location, b: Location) -> Bool {
                switch (a, b) {
                case (.all, _), (_, .all): return true
                case (.left, .right), (.right, .left): return false
                default: return true
                }
            }
        }

        public enum Direction: Equatable {
            case horizontal, vertical(Location)
        }

        case tap(Location)
        case doubleTap(Location)
        case drag(Direction)
        case longPress
        case rotate
        case pinch
        case hover
    }
    
    private let observable = PassthroughSubject<GestureEvent, Never>()
    
    /// Gesture Info received by users when event occurs.
    public struct GestureEvent {
        
        public enum Action {
            case start, end
        }
        
        public enum Value {
            case tap(CGPoint)
            case doubleTap(CGPoint)
            case drag(DragGesture.Value)
            case longPress
            case rotate(RotationGesture.Value)
            case pinch(MagnificationGesture.Value)
            case hover
        }
        
        public let gesture: Gesture
        public let action: Action
        public let value: Value
    }
    
    /// Observe the specific gesture and bind action on it.
    /// - Parameters:
    ///     - gesture: Gesture to observed.
    ///     - handler: The action to perform when the specific gesture occurs.
    ///
    public func observe(_ gesture: Gesture, handler: @escaping (GestureEvent)->Void) -> AnyCancellable {
        observable.filter { event in
            event.gesture == gesture
        }.sink { event in
            handler(event)
        }
    }
    
    //MARK: Simultaneous Gesture
    
    /// Drag Gesture.
    /// Gesture applying over the whole VideoPlayerContainer should be assigned to this to make sure you can receive events.
    @ViewState public var simultaneousDragGesture: _EndedGesture<_ChangedGesture<DragGesture>>?
    
    /// Tap Gesture.
    /// Gesture applying over the whole VideoPlayerContainer should be assigned to this to make sure you can receive events.
    @ViewState public var simultaneousTapGesture: _EndedGesture<SpatialTapGesture>?

    /// DoubleTap Gesture.
    /// Gesture applying over the whole VideoPlayerContainer should be assigned to this to make sure you can receive events.
    @ViewState public var simultaneousDoubleTapGesture: _EndedGesture<SpatialTapGesture>?
    
    /// LongPress Gesture.
    /// Gesture applying over the whole VideoPlayerContainer should be assigned to this to make sure you can receive events.
    @ViewState public var simultaneousLongPressGesture: _EndedGesture<LongPressGesture>?
    
    /// Pinch Gesture.
    /// Gesture applying over the whole VideoPlayerContainer should be assigned to this to make sure you can receive events.
    @ViewState public var simultaneousPinchGesture: _EndedGesture<_ChangedGesture<MagnificationGesture>>?
    
    /// Rotation Gesture.
    /// Gesture applying over the whole VideoPlayerContainer should be assigned to this to make sure you can receive events.
    @ViewState public var simultaneousRotationGesture: _EndedGesture<_ChangedGesture<RotationGesture>>?
    
    //MARK: Gestures
    
    /// Tap Gesture.
    /// Widgets inside the VideoPlayerContainer can use it as the simulataneous gesture to pass through the gesture to the built-in Tap gesture.
    public private(set) lazy var tapGesture: some SwiftUI.Gesture = {
        SpatialTapGesture(count: 1)
            .onEnded { [weak self] value in
                guard let self, let context else { return }
                let leftSide = value.location.x < context.viewSize.width * 0.5
                let event = GestureEvent(gesture: .tap( leftSide ? .left : .right ), action: .end, value: .tap(value.location))
                self.observable.send(event)
            }
    }()

    /// Double-Tap Gesture.
    /// Widgets inside the VideoPlayerContainer can use it as the simulataneous gesture to pass through the gesture to the built-in Double-Tap gesture.
    public private(set) lazy var doubleTapGesture: some SwiftUI.Gesture = {
        SpatialTapGesture(count: 2)
            .onEnded { [weak self] value in
                guard let self, let context else { return }
                let leftSide = value.location.x < context.viewSize.width * 0.5
                let event = GestureEvent(gesture: .doubleTap( leftSide ? .left : .right ), action: .end, value: .doubleTap(value.location))
                self.observable.send(event)
            }
    }()
    
    /// LongPress Gesture.
    /// Widgets inside the VideoPlayerContainer can use it as the simulataneous gesture to pass through the gesture to the built-in Long-Press gesture.
    public private(set) lazy var longPressGesture: some SwiftUI.Gesture = {
        LongPressGesture()
            .onEnded { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .longPress, action: .end, value: .longPress)
                self.observable.send(event)
            }
    }()
    
    /// Drag Gesture.
    /// Widgets inside the VideoPlayerContainer can use it as the simulataneous gesture to pass through the gesture to the built-in Drag gesture.
    public private(set) lazy var dragGesture: some SwiftUI.Gesture = {
        
        let handleDrag: (DragGesture.Value, GestureEvent.Action)->Void = { [weak self] value, action in
            guard let self, let context else { return }
            
            let direction: Gesture.Direction = {
                
                if let last = self.lastDragGesture, case let .drag(direction) = last.gesture {
                    return direction
                }
                
                let horizontal = abs(value.translation.width) > abs(value.translation.height)
                if horizontal {
                    return .horizontal
                }
                let leftSide = value.startLocation.x < context.viewSize.width * 0.5
                if leftSide {
                    return .vertical(.left)
                } else {
                    return .vertical(.right)
                }
            }()
            
            let event = GestureEvent(gesture: .drag(direction), action: action, value: .drag(value))
            
            switch action {
            case .start:
                if self.lastDragGesture == nil {
                    self.lastDragGesture = event
                }
            case .end:
                self.lastDragGesture = nil
            }
            self.observable.send(event)
        }
        
        return
            DragGesture()
                .onChanged{ value in
                    handleDrag(value, .start)
                }
                .onEnded{ value in
                    handleDrag(value, .end)
                }
        
    }()
    
    /// Pinch Gesture.
    /// Widgets inside the VideoPlayerContainer can use it as the simulataneous gesture to pass through the gesture to the built-in Pinch gesture.
    public private(set) lazy var pinchGesture: some SwiftUI.Gesture = {
        MagnificationGesture()
            .onChanged { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .pinch, action: .start, value: .pinch(value))
                self.observable.send(event)
            }
            .onEnded { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .pinch, action: .end, value: .pinch(value))
                self.observable.send(event)
            }
    }()

    /// Rotation Gesture.
    /// Widgets inside the VideoPlayerContainer can use it as the simulataneous gesture to pass through the gesture to the built-in Rotation gesture.
    public private(set) lazy var rotationGesture: some SwiftUI.Gesture = {
        RotationGesture()
            .onChanged { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .rotate, action: .start, value: .rotate(value))
                self.observable.send(event)
            }
            .onEnded { [weak self] value in
                guard let self else { return }
                let event = GestureEvent(gesture: .rotate, action: .end, value: .rotate(value))
                self.observable.send(event)
            }
    }()
    
    private var lastDragGesture: GestureEvent?
    
    func handleHover(action: GestureEvent.Action) {
        let event = GestureEvent(gesture: .hover, action: action, value: .hover)
        observable.send(event)
    }
}

struct GestureWidget: View {
    var body: some View {
        WithService(GestureService.self) { service in
            if service.enabled {
                Color.clear.contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            service.doubleTapGesture,
                            service.simultaneousDoubleTapGesture ?? SpatialTapGesture(count:2).onEnded { _ in }
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.tapGesture,
                            service.simultaneousTapGesture ?? SpatialTapGesture(count:1).onEnded { _ in }
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.longPressGesture,
                            service.simultaneousLongPressGesture ?? LongPressGesture().onEnded{_ in }
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.dragGesture,
                            service.simultaneousDragGesture ?? DragGesture().onChanged{_ in}.onEnded{_ in}
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.pinchGesture,
                            service.simultaneousPinchGesture ?? MagnificationGesture().onChanged{_ in}.onEnded{_ in}
                        )
                    )
                    .gesture(
                        SimultaneousGesture(
                            service.rotationGesture,
                            service.simultaneousRotationGesture ?? RotationGesture().onChanged{_ in}.onEnded{_ in}
                        )
                    )
            }
        }
    }
}

public extension Context {
    
    /// Simple alternative for `context[GestureService.self]`
    var gesture: GestureService {
        self[GestureService.self]
    }
}
