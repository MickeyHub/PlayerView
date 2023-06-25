//
//  FeatureWidget.swift
//  PlayerView
//
//  Created by shayanbo on 2023/6/15.
//

import SwiftUI
import Combine

public class FeatureService : Service {
    
    enum Feature {
        case left( () -> any View)
        case right( () -> any View)
    }
    
    @ViewState fileprivate var feature: Feature?
    
    private var cancellables = [AnyCancellable]()
    
    public required init(_ context: Context) {
        super.init(context)
        
        let gestureService = context[GestureService.self]
        gestureService.observeTap { [weak self] in
            self?.dismiss()
        }.store(in: &cancellables)
    }
    
    public func left(_ viewGetter: @escaping () -> some View) {
        withAnimation {
            feature = .left(viewGetter)
        }
    }
    
    public func right(_ viewGetter: @escaping () -> some View) {
        withAnimation {
            feature = .right(viewGetter)
        }
    }
    
    public func dismiss() {
        withAnimation {
            feature = nil
        }
    }
}

struct FeatureWidget: View {
    
    var body: some View {
        
        WithService(FeatureService.self) { service in
            ZStack {
                
                VStack(alignment: .leading) {
                    Spacer()
                        .frame(maxWidth: .infinity, maxHeight: 0)
                    if case let .left(view) = service.feature {
                        AnyView(
                            view()
                                .frame(maxHeight: .infinity)
                                .transition(.move(edge: .leading))
                        ) // can add an eraseToAnyView in extension to replace here
                    }
                }
                
                VStack(alignment: .trailing) {
                    Spacer()
                        .frame(maxWidth: .infinity, maxHeight: 0)
                    if case let .right(view) = service.feature {
                        AnyView(
                            view()
                                .frame(maxHeight: .infinity)
                                .transition(.move(edge: .trailing))
                        )
                    }
                }
            }
        }
    }
}

