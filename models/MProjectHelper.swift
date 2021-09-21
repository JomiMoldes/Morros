//
//  MProject.swift
//  models
//
//  Created by Moldes, Miguel on 22/08/2021.
//

import Foundation
import UIKit
import ModelsInterfaces

// definir cómo guardar las tareas que no tengan dependencias
// when removing tasks, -> remove relationships
// when removing relationships -> recreate connections
// edit tasks? maybe recreate them? how to keep relationships?
// make everything Codable and save it locally

public protocol MProjectHelperProtocol {
    func tasksSortedByDays(_ project: MProject) -> [UInt: [MTask]]
    func addTask(_ project: inout MProject, _ task: MTask, startDay: UInt) throws
    func removeTask(_ project: inout MProject, taskId: MTask.Id, startDay: UInt) throws
    func addRelationship(_ project: inout MProject, _ relationship: Relationship) throws
    func removeRelationship(_ project: inout MProject, _ relationshipId: Relationship.Id, dependentStartDay: UInt?) throws
    func isIndependent(_ project: MProject, _ task: MTask) -> Bool
}

public class MProjectHelper: MProjectHelperProtocol {
    public func tasksSortedByDays(_ project: MProject) -> [UInt: [MTask]] {
        var dic: [UInt: [MTask]] = [UInt: [MTask]]()
        dic[0] = [MTask]()
        project.tasks.forEach { task in
            let days = UInt(getDistanceFromItsInfluencerInDays(project, task: task))
            if dic.index(forKey: days) == nil {
                dic[days] = [MTask]()
            }
            dic[days]?.append(task)
        }
        return dic
    }

    public func addTask(_ project: inout MProject, _ task: MTask, startDay: UInt) throws {
        // Users won't create a task without knowing when it should start
        try canAddTask(project, task)
        project.tasks.append(task)
        // At the beginning we add them as independent, until they become part of a relationship
        self.addTaskAsIndependent(&project, task, startDay: startDay)
    }

    private func addTaskAsIndependent(_ project: inout MProject, _ task: MTask, startDay: UInt) {
        if project.independentTasks.index(forKey: startDay) == nil {
            project.independentTasks[startDay] = [MTask]()
        }
        project.independentTasks[startDay]?.append(task)
    }

    public func removeTask(_ project: inout MProject, taskId: MTask.Id, startDay: UInt) throws {
        guard let task = project.tasks.first(where: { $0.id == taskId }) else {
            throw MEditingProjectError.unexistingTasks([taskId])
        }
        project.tasks.removeAll(where: { $0.id == taskId })

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
            try self.removeRelationship(&project, $0.id, dependentStartDay: nil)
        }
        try influencerRelationships.forEach {
            let dependentStartDay = Int(startDay + task.days) + $0.daysGap
            try self.removeRelationship(&project,
                                        $0.id,
                                        dependentStartDay: dependentStartDay >= 0 ? UInt(dependentStartDay) : 0)
        }

        self.removeIndependentTask(&project, taskId)
    }

    public func addRelationship(_ project: inout MProject, _ relationship: Relationship) throws {
        try canAddRelationship(project, relationship)
        project.relationships.append(relationship)

        // The dependant cannot be independent anymore
        self.removeIndependentTask(&project, relationship.dependant.id)
    }

    public func removeRelationship(_ project: inout MProject, _ relationshipId: Relationship.Id, dependentStartDay: UInt?) throws {
        guard let relationship = project.relationships.first(where: { $0.id == relationshipId }) else {
            throw MEditingProjectError.unexistingRelationship(relationshipId)
        }
        project.relationships.removeAll(where: { $0.id == relationshipId } )

        // we make the dependant independent if it doesn't depend on other tasks
        if let dependentStartDay = dependentStartDay, !self.dependsOnAnyTask(project, relationship.dependant) {
            self.addTaskAsIndependent(&project, relationship.dependant, startDay: dependentStartDay)
        }
    }

    public func isIndependent(_ project: MProject, _ task: MTask) -> Bool {
        for (key, _) in project.independentTasks {
            if let list = project.independentTasks[key] {
                if list.contains( where: { $0.id == task.id }) {
                    return true
                }
            }
        }
        return false
    }

}

private extension MProjectHelper {

    private func removeIndependentTask(_ project: inout MProject, _ taskId: MTask.Id) {
        for (key, _) in project.independentTasks {
            if project.independentTasks[key] != nil {
                project.independentTasks[key]?.removeAll(where: { $0.id == taskId })
            }
        }
    }

    private func getDistanceFromItsInfluencerInDays(_ project: MProject, task: MTask) -> Int {
        guard let relationship = project.relationships.first(where: { $0.dependant.id == task.id })  else {
            return Int(getStartDay(project, for: task))
        }
        return getDistanceFromItsInfluencerInDays(project, task: relationship.influencer) + Int(relationship.influencer.days) + relationship.daysGap
    }

    private func getStartDay(_ project: MProject, for task: MTask) -> UInt {
        for (key, _) in project.independentTasks {
            if let list = project.independentTasks[key] {
                if list.contains(task) {
                    return key
                }
            }
        }
        return 0
    }

    private func canAddTask(_ project: MProject, _ task: MTask) throws {
        if project.tasks.contains(task) { throw MEditingProjectError.taskAlreadyExists }
        if project.tasks.first(where: { $0.id == task.id }) != nil { throw MEditingProjectError.taskIdRepeated }
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

    private func canAddRelationship(_ project: MProject, _ relationship: Relationship) throws {
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
        if influencerDependsOnDependant(project, influencer: t1, dependant: t2) {
            throw MEditingProjectError.cycleReference
        }
        // it already depends indirectly
        if dependsIndirectly(project, influencer: t1, dependant: t2) {
            throw MEditingProjectError.taskAlreadyDependsOnInfluencerIndirectly
        }
    }

    private func influencerDependsOnDependant(_ project: MProject, influencer: MTask, dependant: MTask) -> Bool {
        let filtered = project.relationships.filter { $0.dependant.id == influencer.id }
        guard filtered.count > 0 else { return false }
        for relationship in filtered {
            if relationship.influencer.id == dependant.id {
                return true
            }
            if influencerDependsOnDependant(project, influencer: relationship.influencer, dependant: dependant) {
                return true
            }
        }
        return false
    }

    private func dependsIndirectly(_ project: MProject, influencer: MTask, dependant: MTask) -> Bool {
        let filtered = project.relationships.filter { $0.dependant.id == dependant.id }
        guard filtered.count > 0 else { return false }
        for relationship in filtered {
            if relationship.influencer.id == influencer.id {
                return true
            }
            if dependsIndirectly(project, influencer: influencer, dependant: relationship.influencer) {
                return true
            }
        }
        return false
    }
}