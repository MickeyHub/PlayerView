//
//  TimelineWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/19.
//

import Foundation
import AVKit
import Combine
import SwiftUI
import VideoPlayerContainer

struct TimelineWidget : View {
    
    var body: some View {
        
        WithService(TimelineWidgetService.self) { service in
            Text("\(service.current)/\(service.duration)")
                .foregroundColor(.white)
        }
    }
}

fileprivate class TimelineWidgetService : Service {
    
    @Published var current = "00:00"
    
    @Published var duration = "00:00"
    
    private var cancellables = [AnyCancellable]()
    
    private var timeObserver: Any?
    
    required init(_ context: Context) {
        super.init(context)
        
        timeObserver = context.render.player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: nil) { [weak self] time in
            guard let self else { return }
            
            let current = CMTimeGetSeconds(time)
            let duration = CMTimeGetSeconds(context.render.player.currentItem!.duration)
            
            self.current = self.toDisplay(Int(current))
            self.duration = duration.isNormal ? self.toDisplay(Int(duration)) : "00:00"
        }
        
        context.gesture.observe(.drag(.horizontal)) { [weak self] event in
            guard let self else { return }
            
            switch event.action {
            case .start:
                
                guard let item = context.render.player.currentItem else { return }
                guard item.duration.seconds.isNormal else { return }
                
                guard case let .drag(value) = event.value else { return }
                
                let percent = value.translation.width / context.viewSize.width
                let secs = item.duration.seconds * percent
                let current = item.currentTime().seconds
                context.plugin.present(.center) {
                    AnyView(
                        Text(self.toDisplay(Int(current + secs)))
                            .padding(8)
                            .background(Color.white.opacity(0.5))
                            .offset(CGSize(width: 0, height: 50))
                    )
                }
            case .end:
                context.plugin.dismiss()
                break
            }
        }.store(in: &cancellables)
    }
    
    private func toDisplay(_ seconds: Int) -> String {
        
        if seconds < 0 {
            return "00:00"
        }
        
        var mins = "", secs = ""
        
        let numberOfMin = (seconds % 3600) / 60
        if numberOfMin >= 10 {
            mins = "\(numberOfMin)"
        } else {
            mins = "0\(numberOfMin)"
        }
        
        let numberOfSec = (seconds % 3600) % 60
        if numberOfSec >= 10 {
            secs = "\(numberOfSec)"
        } else {
            secs = "0\(numberOfSec)"
        }
        
        return "\(mins):\(secs)"
    }
}

