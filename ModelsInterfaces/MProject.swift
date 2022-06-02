//
//  MProject.swift
//  ModelsInterfaces
//
//  Created by Moldes, Miguel on 19/09/2021.
//

import Foundation

// TO DO: replace arrays by sets
public struct MProject {
    public let id: Identifier<Self>
    public let name: String
    public var tasks: Set<MTask> = Set<MTask>()
    public var relationships: Set<MRelationship> = Set<MRelationship>()
    public let startDate: Date
    public var independentTasks: [UInt: [MTask]] = [UInt: [MTask]]()

    public init(id: Identifier<Self>,
                name: String,
                startDate: Date) {
        self.id = id
        self.name = name
        self.startDate = startDate
    }
}

public enum MEditingProjectError: Error, Equatable {
    case taskAlreadyExists, taskIdRepeated, unexistingTasks([Identifier<MTask>]), daysBiggerThanZero
    case cycleReference, relationshipAlreadyExists, relationshipIdRepeated
    case taskAlreadyDependsOnInfluencerIndirectly
    case unexistingRelationship(Identifier<MRelationship>)
}
