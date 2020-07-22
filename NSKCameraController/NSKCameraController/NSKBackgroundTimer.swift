//
//  NSKBackgroundTimer.swift
//  NSKCameraController
//
//  Created by User on 16.04.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import Foundation

class NSKBackgroundTimer {
    private let queue = DispatchQueue(label: "com.digitalsparta.BackgroundTimer", qos: .background)
    private var timer: DispatchSourceTimer?
    private let lock = NSLock()
    
    func start(withPeriod period: UInt, event: @escaping (NSKBackgroundTimer) -> Void) {
        self.lock.lock()
        self._stop()
        
        let period = Double(period)
        let timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: 0), queue: self.queue)
        timer.schedule(deadline: .now() + period,
                       repeating: period)
        timer.setEventHandler { [weak self] () -> Void in
            guard let sSelf = self else { return }
            
            event(sSelf)
        }
        self.timer = timer
        timer.resume()
        self.lock.unlock()
    }
    
    func stop() {
        self.lock.lock()
        self._stop()
        self.lock.unlock()
    }
    func _stop() {
        self.timer?.cancel()
        self.timer = nil
    }
    
    var isCancelled: Bool {
        self.lock.lock()
        let isCancelled = self.timer?.isCancelled ?? true
        self.lock.unlock()
        
        return isCancelled
    }
    
    deinit {
        self.stop()
    }
}
