//
//  MProject.swift
//  ModelsInterfaces
//
//  Created by Moldes, Miguel on 19/09/2021.
//

import Foundation

// TO DO: replace arrays by sets
public struct MProject {
    public let id: Int
    public let name: String
    public var tasks: Set<MTask> = Set<MTask>()
    public var relationships: [Relationship] = [Relationship]()
    public let startDate: Date
    public var independentTasks: [UInt: [MTask]] = [UInt: [MTask]]()

    public init(id: Int,
                name: String,
                startDate: Date) {
        self.id = id
        self.name = name
        self.startDate = startDate
    }
}

public enum MEditingProjectError: Error, Equatable {
    case taskAlreadyExists, taskIdRepeated, unexistingTasks([MTask.Id]), daysBiggerThanZero
    case cycleReference, relationshipAlreadyExists, relationshipIdRepeated
    case taskAlreadyDependsOnInfluencerIndirectly
    case unexistingRelationship(Relationship.Id)
}

public struct MTask: Equatable, Hashable{

    public struct Id: Equatable, Hashable {
        public init(_ id: Int) {
            self.id = id
        }
        public let id: Int
    }
    public let id: Id
    public let name: String
    public let days: UInt
    public let color: Palette

    public init(id: Id,
                name: String,
                days: UInt,
                color: Palette) {
        self.id = id
        self.name = name
        self.days = days
        self.color = color
    }
}

public struct Relationship: Equatable {
    public struct Id: Equatable {
        public init(_ id: Int) {
            self.id = id
        }
        public let id: Int
    }
    public let id: Relationship.Id
    public let influencer: MTask
    public let dependent: MTask
    public let daysGap: Int

    public init(id: Id,
                influencer: MTask,
                dependent: MTask,
                daysGap: Int) {
        self.id = id
        self.influencer = influencer
        self.dependent = dependent
        self.daysGap = daysGap
    }
}
