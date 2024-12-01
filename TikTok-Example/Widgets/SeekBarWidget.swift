//
//  SeekBarWidget.swift
//  VideoPlayer
//
//  Created by shayanbo on 2023/6/19.
//

import Foundation
import AVKit
import SwiftUI
import Combine
import VideoPlayerContainer

struct SeekBarWidget : View {
    
    var body: some View {
        
        /// put WithService inside the GeometryReader
        GeometryReader { proxy in
            WithService(SeekBarWidgetService.self) { service in
            
                ZStack(alignment: .leading) {
                    Rectangle().fill(.gray)
                    
                    Rectangle().fill(.white)
                        .frame(maxHeight: .infinity)
                        .frame(width: service.progress * proxy.size.width)
                }
                .cornerRadius(2)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 5)
    }
}

fileprivate class SeekBarWidgetService : Service {
    
    @Published var progress = 0.0
    
    private var timeObserver: Any?
    
    required init(_ context: Context) {
        super.init(context)
        
        timeObserver = context.render.player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 1), queue: nil) { [weak self, weak context] time in
            guard let context, let self else { return }
            guard let item = context.render.player.currentItem else { return }
            guard item.duration.seconds.isNormal else { return }
            
            self.progress = time.seconds / item.duration.seconds
        }
    }
}
