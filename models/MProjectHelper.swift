//
//  MProjectHelper.swift
//  models
//
//  Created by Moldes, Miguel on 22/08/2021.
//

import Foundation
import UIKit
import ModelsInterfaces

// make everything Codable and save it locally

public protocol MProjectHelperProtocol {
    var project: MProject { get }
    func tasksSortedByDays() -> [UInt: [MTask]]
    func addTask(_ task: MTask, startDay: UInt) throws
    func removeTask(_ task: MTask, startDay: UInt) throws
    func addRelationship(_ relationship: Relationship) throws
    func removeRelationship(_ relationshipId: Relationship.Id, dependentStartDay: UInt?) throws
    func isIndependent(_ task: MTask) -> Bool
    func editTask(_ modifiedTask: MTask) throws
}

public class MProjectHelper: MProjectHelperProtocol {
    public private(set) var project: MProject
    public init(project: MProject) {
        self.project = project
    }

    public func tasksSortedByDays() -> [UInt: [MTask]] {
        var dic: [UInt: [MTask]] = [UInt: [MTask]]()
        dic[0] = [MTask]()
        project.tasks.forEach { task in
            let days = UInt(getDistanceFromItsInfluencerInDays(task: task))
            if dic.index(forKey: days) == nil {
                dic[days] = [MTask]()
            }
            dic[days]?.append(task)
        }
        return dic
    }

    public func addTask(_ task: MTask, startDay: UInt) throws {
        // Users won't create a task without knowing when it should start
        try canAddTask(task)
        project.tasks.insert(task)
        // At the beginning we add them as independent, until they become part of a relationship
        self.addTaskAsIndependent(task, startDay: startDay)
    }

    public func removeTask(_ task: MTask, startDay: UInt) throws {
        guard project.tasks.contains(task) else {
            throw MEditingProjectError.unexistingTasks([task.id])
        }
        project.tasks.remove(task)
        let taskId = task.id

        // if the task is influencer, we'll remove the relationship giving a startDay for the dependant to become independent
        // if the task is dependant it won't affect the influencer
        var dependantRelationships = [Relationship]()
        var influencerRelationships = [Relationship]()
        project.relationships.forEach {
            if $0.dependant.id == taskId {
                dependantRelationships.append($0)
                return
            }
            if $0.influencer.id == taskId {
                influencerRelationships.append($0)
            }
        }
        
        try dependantRelationships.forEach {
            try self.removeRelationship($0.id, dependentStartDay: nil)
        }
        try influencerRelationships.forEach {
            let dependentStartDay = Int(startDay + task.days) + $0.daysGap
            try self.removeRelationship($0.id,
                                        dependentStartDay: dependentStartDay >= 0 ? UInt(dependentStartDay) : 0)
        }

        self.removeIndependentTask(taskId)
    }

    public func addRelationship(_ relationship: Relationship) throws {
        try canAddRelationship(relationship)
        project.relationships.append(relationship)

        // The dependant cannot be independent anymore
        self.removeIndependentTask(relationship.dependant.id)
    }

    public func removeRelationship(_ relationshipId: Relationship.Id, dependentStartDay: UInt?) throws {
        guard let relationship = project.relationships.first(where: { $0.id == relationshipId }) else {
            throw MEditingProjectError.unexistingRelationship(relationshipId)
        }
        project.relationships.removeAll(where: { $0.id == relationshipId } )

        // we make the dependant independent if it doesn't depend on other tasks
        if let dependentStartDay = dependentStartDay, !self.dependsOnAnyTask(project, relationship.dependant) {
            self.addTaskAsIndependent(relationship.dependant, startDay: dependentStartDay)
        }
    }

    public func isIndependent(_ task: MTask) -> Bool {
        for (key, _) in project.independentTasks {
            if let list = project.independentTasks[key] {
                if list.contains( where: { $0.id == task.id }) {
                    return true
                }
            }
        }
        return false
    }

    // TO DO: think a better way to edit tasks.
    /*
     The way to edit a task is replacing it with a new one with the same id.
     It removes the old task from all the lists whre it appears and then
     we add the new task in those lists
     */
    public func editTask(_ modifiedTask: MTask) throws {
        // we should check first if we can add the task before removing it
        try canAddTask(modifiedTask, checkForId: false)
        guard let task = project.tasks.first(where: { $0.id == modifiedTask.id }) else {
            throw MEditingProjectError.unexistingTasks([modifiedTask.id])
        }
        let isIndependent = isIndependent(modifiedTask)
        let startDay = getStartDay(for: modifiedTask)
        removeIndependentTask(task.id)
        try removeTask(task, startDay: startDay)

        if isIndependent {
            addTaskAsIndependent(modifiedTask, startDay: startDay)
        }
        project.tasks.insert(modifiedTask)
    }

}

private extension MProjectHelper {

    private func removeIndependentTask(_ taskId: MTask.Id) {
        for (key, _) in project.independentTasks {
            if project.independentTasks[key] != nil {
                project.independentTasks[key]?.removeAll(where: { $0.id == taskId })
            }
        }
    }

    private func getDistanceFromItsInfluencerInDays(task: MTask) -> Int {
        guard let relationship = project.relationships.first(where: { $0.dependant.id == task.id })  else {
            return Int(getStartDay(for: task))
        }
        return getDistanceFromItsInfluencerInDays(task: relationship.influencer) + Int(relationship.influencer.days) + relationship.daysGap
    }

    private func getStartDay(for task: MTask) -> UInt {
        for (key, _) in project.independentTasks {
            if let list = project.independentTasks[key] {
                if list.contains(task) {
                    return key
                }
            }
        }
        return 0
    }

    private func canAddTask(_ task: MTask, checkForId: Bool = true) throws {
        if project.tasks.contains(task) { throw MEditingProjectError.taskAlreadyExists }
        // When we "edit" a task we replace it for a new one with the same id, so in that case we don't compare ids
        if checkForId {
            if project.tasks.first(where: { $0.id == task.id }) != nil { throw MEditingProjectError.taskIdRepeated }
        }
        if task.days <= 0 { throw MEditingProjectError.daysBiggerThanZero }
    }

    private func dependsOnAnyTask(_ project: MProject, _ task: MTask) -> Bool {
        for relationship in project.relationships {
            if relationship.dependant.id == task.id {
                return true
            }
        }
        return false
    }

    private func canAddRelationship(_ relationship: Relationship) throws {
        if project.relationships.contains(relationship) { throw MEditingProjectError.relationshipAlreadyExists }
        if project.relationships.first(where: { $0.id == relationship.id }) != nil { throw MEditingProjectError.relationshipIdRepeated }
        let t1 = relationship.influencer
        let t2 = relationship.dependant
        var unexistingTasks: [MTask.Id] = [MTask.Id]()
        if project.tasks.contains(t1) == false { unexistingTasks.append(t1.id) }
        if project.tasks.contains(t2) == false { unexistingTasks.append(t2.id) }
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
        let filtered = project.relationships.filter { $0.dependant.id == influencer.id }
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
        let filtered = project.relationships.filter { $0.dependant.id == dependant.id }
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

    private func addTaskAsIndependent(_ task: MTask, startDay: UInt) {
        if project.independentTasks.index(forKey: startDay) == nil {
            project.independentTasks[startDay] = [MTask]()
        }
        project.independentTasks[startDay]?.append(task)
    }
}
