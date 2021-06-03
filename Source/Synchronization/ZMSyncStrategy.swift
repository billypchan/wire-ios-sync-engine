//
//  ZMSyncStrategy.swift
//  WireSyncEngine-ios
//
//  Created by Bill, Yiu Por Chan on 03.06.21.
//  Copyright © 2021 Zeta Project Gmbh. All rights reserved.
//

import Foundation

extension ZMSyncStrategy {
//    @objc
    func callingRequestStrategy() -> CallingRequestStrategy? {
        return strategyDirectory?.requestStrategies.first(where: { requestStrategy in
            requestStrategy is CallingRequestStrategy
        }) as? CallingRequestStrategy
    }
}
