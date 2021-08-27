//
//  MProject.swift
//  models
//
//  Created by Moldes, Miguel on 22/08/2021.
//

import Foundation
import UIKit

public struct MProject {
    public let id: Int
    public let name: String
    public private(set) var tasks: [MTask] = [MTask]()
    public private(set) var relationships: [Relationship] = [Relationship]()
    public let startDate: Date

    public init(id: Int,
                name: String,
                startDate: Date) {
        self.id = id
        self.name = name
        self.startDate = startDate
    }

    public mutating func addTask(_ task: MTask) throws {
        try canAddTask(task)
        tasks.append(task)
    }

    public mutating func removeTask(id: MTask.Id) {
        tasks.removeAll(where: { $0.id == id })
        // remove relationships
    }

    public mutating func addRelationship(_ relationship: Relationship) throws {
        try canAddRelationship(relationship)
        relationships.append(relationship)
    }

    public mutating func removeRelationship(_ id: Relationship.Id) {
        relationships.removeAll(where: { $0.id == id} )
        // recreate connections
    }

}

public enum MEditingProjectError: Error, Equatable {
    case taskAlreadyExists, taskIdRepeated, unexistingTasks([MTask.Id]), daysBiggerThanZero
    case cycleReference, relationshipAlreadyExists, relationshipIdRepeated
    case taskAlreadyDependsOnInfluencerIndirectly
}

public struct MTask: Equatable {
    public struct Id: Equatable {
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
    public let dependant: MTask
    public let daysGap: Int

    public init(id: Id,
                influencer: MTask,
                dependant: MTask,
                daysGap: Int) {
        self.id = id
        self.influencer = influencer
        self.dependant = dependant
        self.daysGap = daysGap
    }
}

public enum Palette {
    case red, yellow, blue, orange, grey, green
}

public extension MProject {
    func tasksByDays() -> [UInt: [MTask]] {
        var dic: [UInt: [MTask]] = [UInt: [MTask]]()
        dic[0] = [MTask]()
        self.tasks.forEach { task in
            let days = UInt(getDays(task: task))
            if dic.index(forKey: days) == nil {
                dic[days] = [MTask]()
            }
            dic[days]?.append(task)
        }
        return dic
    }
}

private extension MProject {

    private func getDays(task: MTask) -> Int {
        guard let relationship = relationships.first(where: { $0.dependant.id == task.id })  else {
            return 0
        }
        return getDays(task: relationship.influencer) + Int(relationship.influencer.days) + relationship.daysGap
    }

    private func canAddTask(_ task: MTask) throws {
        if tasks.contains(task) { throw MEditingProjectError.taskAlreadyExists }
        if tasks.first(where: { $0.id == task.id }) != nil { throw MEditingProjectError.taskIdRepeated }
        if task.days <= 0 { throw MEditingProjectError.daysBiggerThanZero }
    }

    private func canAddRelationship(_ relationship: Relationship) throws {
        if relationships.contains(relationship) { throw MEditingProjectError.relationshipAlreadyExists }
        if relationships.first(where: { $0.id == relationship.id }) != nil { throw MEditingProjectError.relationshipIdRepeated }
        let t1 = relationship.influencer
        let t2 = relationship.dependant
        var unexistingTasks: [MTask.Id] = [MTask.Id]()
        if tasks.contains(t1) == false { unexistingTasks.append(t1.id) }
        if tasks.contains(t2) == false { unexistingTasks.append(t2.id) }
        if unexistingTasks.isEmpty == false {
            throw MEditingProjectError.unexistingTasks(unexistingTasks)
        }
        // there shouldn't be a cycle reference
        if influencerDependsOnDependant(influencer: t1, dependant: t2) {
            throw MEditingProjectError.cycleReference
        }
        // it already depends indirectly
        if dependsIndirectly(influencer: t1, dependant: t2) {
            throw MEditingProjectError.taskAlreadyDependsOnInfluencerIndirectly
        }
    }

    private func influencerDependsOnDependant(influencer: MTask, dependant: MTask) -> Bool {
        let filtered = self.relationships.filter { $0.dependant.id == influencer.id }
        guard filtered.count > 0 else { return false }
        for relationship in filtered {
            if relationship.influencer.id == dependant.id {
                return true
            }
            if influencerDependsOnDependant(influencer: relationship.influencer, dependant: dependant) {
                return true
            }
        }
        return false
    }

    private func dependsIndirectly(influencer: MTask, dependant: MTask) -> Bool {
        let filtered = self.relationships.filter { $0.dependant.id == dependant.id }
        guard filtered.count > 0 else { return false }
        for relationship in filtered {
            if relationship.influencer.id == influencer.id {
                return true
            }
            if dependsIndirectly(influencer: influencer, dependant: relationship.influencer) {
                return true
            }
        }
        return false
    }
}
