//
//  Relationship.swift
//  ModelsInterfaces
//
//  Created by Moldes, Miguel on 01/05/2022.
//

import Foundation

public struct MRelationship: Equatable {

    public let id: Identifier<Self>
    public let influencer: MTask
    public let dependent: MTask
    public let daysGap: Int

    public init(id: Identifier<Self>,
                influencer: MTask,
                dependent: MTask,
                daysGap: Int) {
        self.id = id
        self.influencer = influencer
        self.dependent = dependent
        self.daysGap = daysGap
    }
}
