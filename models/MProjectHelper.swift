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
    func tasksByDays(_ project: MProject) -> [UInt: [MTask]]
    func addTask(_ project: inout MProject, _ task: MTask) throws
    func removeTask(_ project: inout MProject, taskId: MTask.Id)
    func addRelationship(_ project: inout MProject, _ relationship: Relationship) throws
    func removeRelationship(_ project: inout MProject, _ relationshipId: Relationship.Id)
}
public class MProjectHelper: MProjectHelperProtocol {
    public func tasksByDays(_ project: MProject) -> [UInt: [MTask]] {
        var dic: [UInt: [MTask]] = [UInt: [MTask]]()
        dic[0] = [MTask]()
        project.tasks.forEach { task in
            let days = UInt(getDays(project, task: task))
            if dic.index(forKey: days) == nil {
                dic[days] = [MTask]()
            }
            dic[days]?.append(task)
        }
        return dic
    }

    public func addTask(_ project: inout MProject, _ task: MTask) throws {
        try canAddTask(project, task)
        project.tasks.append(task)
    }

    public func removeTask(_ project: inout MProject, taskId: MTask.Id) {
        project.tasks.removeAll(where: { $0.id == taskId })
        // remove relationships
    }

    public func addRelationship(_ project: inout MProject, _ relationship: Relationship) throws {
        try canAddRelationship(project, relationship)
        project.relationships.append(relationship)
    }

    public func removeRelationship(_ project: inout MProject, _ relationshipId: Relationship.Id) {
        project.relationships.removeAll(where: { $0.id == relationshipId } )
        // recreate connections
    }

}

private extension MProjectHelper {

    private func getDays(_ project: MProject, task: MTask) -> Int {
        guard let relationship = project.relationships.first(where: { $0.dependant.id == task.id })  else {
            return 0
        }
        return getDays(project, task: relationship.influencer) + Int(relationship.influencer.days) + relationship.daysGap
    }

    private func canAddTask(_ project: MProject, _ task: MTask) throws {
        if project.tasks.contains(task) { throw MEditingProjectError.taskAlreadyExists }
        if project.tasks.first(where: { $0.id == task.id }) != nil { throw MEditingProjectError.taskIdRepeated }
        if task.days <= 0 { throw MEditingProjectError.daysBiggerThanZero }
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
