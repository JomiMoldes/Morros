//
//  MProjectHelperTests.swift
//  MProjectHelperTests
//
//  Created by Moldes, Miguel on 22/08/2021.
//

import XCTest
import ModelsInterfaces

@testable import models
class MProjectHelperTests: XCTestCase {

    func testAddAndRemoveTasks() throws {
        let sut = createSUT()
        var project = createProject()
        let task1 = createTask(id: MTask.Id(1))
        let task2 = createTask(id: MTask.Id(2))
        let task3 = createTask(id: MTask.Id(3))
        try sut.addTask(&project, task1, startDay: 0)
        try sut.addTask(&project, task2, startDay: 0)
        try sut.addTask(&project, task3, startDay: 0)
        XCTAssertEqual(project.tasks.count, 3)
        XCTAssertEqual(project.tasks, [task1, task2, task3])

        try sut.removeTask(&project, taskId: task2.id, startDay: 0)
        XCTAssertEqual(project.tasks.count, 2)
        XCTAssertEqual(project.tasks, [task1, task3])
    }

    func testAddAndRemoveTasks_IndependentTasks() throws {
        let sut = createSUT()
        var project = createProject()
        let task1 = createTask(id: MTask.Id(1))
        let task2 = createTask(id: MTask.Id(2))
        let task3 = createTask(id: MTask.Id(3))
        try sut.addTask(&project, task1, startDay: 0)
        try sut.addTask(&project, task2, startDay: 0)
        try sut.addTask(&project, task3, startDay: 5)

        XCTAssertEqual(project.independentTasks[0]?.first, task1)
        XCTAssertEqual(project.independentTasks[0]?.last, task2)
        XCTAssertEqual(project.independentTasks[5]?.first, task3)

        try sut.removeTask(&project, taskId: task1.id, startDay: 0)
        XCTAssertEqual(project.independentTasks[0]?.first, task2)

        try sut.removeTask(&project, taskId: task2.id, startDay: 0)
        XCTAssertNil(project.independentTasks[0]?.first)

        try sut.removeTask(&project, taskId: task3.id, startDay: 0)
        XCTAssertNil(project.independentTasks[5]?.first)
    }

    func testAddintExistingTask_Error() throws {
        let sut = createSUT()
        var project = createProject()
        let task1 = createTask(id: MTask.Id(1),
                               name: "Plot cleaning")
        let taskWithSameId = createTask(id: MTask.Id(1))
        let taskWithDaysLessThanOne = createTask(id: MTask.Id(3),
                                                 days: 0)
        try sut.addTask(&project, task1, startDay: 0)
        XCTAssertThrowsError(try sut.addTask(&project, taskWithSameId, startDay: 0)) { error in
            XCTAssertEqual(error as? MEditingProjectError, MEditingProjectError.taskIdRepeated)
        }
        XCTAssertThrowsError(try sut.addTask(&project, task1, startDay: 0)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .taskAlreadyExists)
        }
        XCTAssertThrowsError(try sut.addTask(&project, taskWithDaysLessThanOne, startDay: 0)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .daysBiggerThanZero)
        }
    }

    func testRemoveTask_Errors() throws {
        let sut = createSUT()
        var project = createProject()
        let task1 = createTask(id: MTask.Id(1),
                               name: "Plot cleaning")

        XCTAssertThrowsError(try sut.removeTask(&project, taskId: task1.id, startDay: 0)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .unexistingTasks([task1.id]))
        }
    }

    func testRemoveTask_ShouldRemoveRelationship() throws {
        let sut = createSUT()
        var project = createProject()
        let task1days: UInt = 8
        let task1StartDay: UInt = 2
        let task1 = createTask(id: MTask.Id(1), days: task1days)
        let task2 = createTask(id: MTask.Id(2))
        let task3 = createTask(id: MTask.Id(3))
        try sut.addTask(&project, task1, startDay: task1StartDay)
        try sut.addTask(&project, task2, startDay: 0)
        try sut.addTask(&project, task3, startDay: 0)

        let gap: Int = 2
        let relationship1 = Relationship(id: .init(1),
                                         influencer: task1,
                                         dependant: task2,
                                         daysGap: gap)
        try sut.addRelationship(&project, relationship1)
        XCTAssertNotNil(project.relationships.first(where: { $0.id == relationship1.id }))
        XCTAssertTrue(sut.isIndependent(project, task1))
        XCTAssertFalse(sut.isIndependent(project, task2))

        try sut.removeTask(&project, taskId: task1.id, startDay: task1StartDay)
        XCTAssertNil(project.relationships.first(where: { $0.id == relationship1.id }))
        XCTAssertFalse(sut.isIndependent(project, task1))
        XCTAssertTrue(sut.isIndependent(project, task2))

        XCTAssertEqual(sut.tasksSortedByDays(project)[0], [task3])
        XCTAssertEqual(sut.tasksSortedByDays(project)[task1days + task1StartDay + UInt(gap)], [task2])
    }

    func testAddAndRemoveRelationships() throws {
        let sut = createSUT()
        var project = createProject()
        let influencerStartDay: UInt = 1
        let dependantStartDay: UInt = 1
        let gap: Int = 2
        let influencer = createTask(id: MTask.Id(1), days: 5)
        let dependant = createTask(id: MTask.Id(2), days: 3)

        let relationship = Relationship(id: .init(1),
                                         influencer: influencer,
                                         dependant: dependant,
                                         daysGap: gap)
        try sut.addTask(&project, influencer, startDay: influencerStartDay)
        try sut.addTask(&project, dependant, startDay: dependantStartDay)
        try sut.addRelationship(&project, relationship)
        XCTAssertEqual(project.relationships, [relationship])
        let startDay = Int(influencerStartDay + influencer.days) + gap
        try sut.removeRelationship(&project, relationship.id, dependentStartDay: startDay >= 0 ? UInt(startDay) : 0)
        XCTAssertEqual(project.relationships, [])
        XCTAssertEqual(project.independentTasks[1], [influencer])
        XCTAssertEqual(project.independentTasks[8], [dependant])
    }

    func testAddingRelationships_Errors() throws {
        let sut = createSUT()
        var project = createProject()
        let influencer = createTask(id: MTask.Id(1), days: 5)
        let dependant = createTask(id: MTask.Id(2), days: 3)

        let relationship = Relationship(id: .init(1),
                                         influencer: influencer,
                                         dependant: dependant,
                                         daysGap: 0)
        XCTAssertThrowsError(try sut.addRelationship(&project, relationship)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .unexistingTasks([influencer.id, dependant.id]))
        }

        // adding tasks
        try sut.addTask(&project, influencer, startDay: 0)
        try sut.addTask(&project, dependant, startDay: 0)

        try sut.addRelationship(&project, relationship)

        // trying to add the same relationship
        XCTAssertThrowsError(try sut.addRelationship(&project, relationship)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .relationshipAlreadyExists)
        }

        // given a relationship with the same id
        let task3 = createTask(id: .init(3))
        let task4 = createTask(id: .init(4))
        let relationship2 = Relationship(id: .init(1),
                                         influencer: task3,
                                         dependant: task4,
                                         daysGap: 0)
        XCTAssertThrowsError(try sut.addRelationship(&project, relationship2)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .relationshipIdRepeated)
        }
        let nonExistingRelationship = Relationship(id: .init(2), influencer: createTask(id: .init(9)), dependant: createTask(id: .init(10)), daysGap: 0)
        XCTAssertThrowsError(try sut.removeRelationship(&project, nonExistingRelationship.id, dependentStartDay: 1)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .unexistingRelationship(nonExistingRelationship.id))
        }
    }

    func testTasksPositions() throws {
        let sut = createSUT()
        var project = createProject()
        let task1 = createTask(id: .init(1), days: 7)
        let task2 = createTask(id: .init(2), days: 7)
        let task3 = createTask(id: .init(3), days: 7)
        let task4 = createTask(id: .init(4), days: 7)
        let task5 = createTask(id: .init(5), days: 7)
        let task6 = createTask(id: .init(6), days: 7)

        // no tasks added, no tasks to show
        XCTAssertEqual(sut.tasksSortedByDays(project)[0], [])
        try sut.addTask(&project, task1, startDay: 0)
        try sut.addTask(&project, task2, startDay: 0)
        try sut.addTask(&project, task3, startDay: 0)
        try sut.addTask(&project, task4, startDay: 0)
        try sut.addTask(&project, task5, startDay: 0)
        try sut.addTask(&project, task6, startDay: 0)

        let relationship1 = Relationship(id: .init(1),
                                        influencer: task1,
                                        dependant: task2,
                                        daysGap: 2)
        let relationship2 = Relationship(id: .init(2),
                                        influencer: task2,
                                        dependant: task3,
                                        daysGap: -2)

        // no relationships added, all tasks start from day 1
        XCTAssertEqual(sut.tasksSortedByDays(project)[0], [task1, task2, task3, task4, task5, task6])

        try sut.addRelationship(&project, relationship1)
        try sut.addRelationship(&project, relationship2)
        let list = sut.tasksSortedByDays(project)
        XCTAssertEqual(list[0], [task1, task4, task5, task6])
        XCTAssertEqual(list[9], [task2])
        XCTAssertEqual(list[14], [task3])
    }

    func testTasksPositions2() throws {
        let sut = createSUT()
        var project = createProject()
        let task1 = createTask(id: .init(1), days: 7)
        let task2 = createTask(id: .init(2), days: 7)
        let task3 = createTask(id: .init(3), days: 7)

        // no tasks added, no tasks to show
        XCTAssertEqual(sut.tasksSortedByDays(project)[0], [])
        let task1InitialDay: UInt = 0
        let task2InitialDay: UInt = 10
        let task3InitialDay: UInt = 0
        try sut.addTask(&project, task1, startDay: task1InitialDay)
        try sut.addTask(&project, task2, startDay: task2InitialDay)
        try sut.addTask(&project, task3, startDay: task3InitialDay)
        XCTAssertTrue(sut.isIndependent(project, task1))
        XCTAssertTrue(sut.isIndependent(project, task2))
        XCTAssertTrue(sut.isIndependent(project, task3))

        // no relationships added, all tasks start from day 1
        XCTAssertEqual(sut.tasksSortedByDays(project)[task1InitialDay], [task1, task3])
        XCTAssertEqual(sut.tasksSortedByDays(project)[task2InitialDay], [task2])
        XCTAssertEqual(sut.tasksSortedByDays(project)[task3InitialDay], [task1, task3])

        let relationship1 = Relationship(id: .init(1),
                                        influencer: task1,
                                        dependant: task2,
                                        daysGap: Int(task2InitialDay - task1InitialDay - task1.days))

        try sut.addRelationship(&project, relationship1)

        let list = sut.tasksSortedByDays(project)
        XCTAssertEqual(list[0], [task1, task3])
        XCTAssertEqual(list[10], [task2])

        XCTAssertEqual(project.independentTasks[0]?.first, task1)
        XCTAssertEqual(project.independentTasks[0]?.last, task3)


        let relationship2 = Relationship(id: .init(2),
                                        influencer: task2,
                                        dependant: task3,
                                        daysGap: Int(task3InitialDay) - Int(task2InitialDay))

        try sut.addRelationship(&project, relationship2)
        XCTAssertEqual(list[0], [task1, task3])
        XCTAssertEqual(list[10], [task2])

        XCTAssertEqual(project.independentTasks[0]?.first, task1)
        XCTAssertTrue(sut.isIndependent(project, task1))
        XCTAssertFalse(sut.isIndependent(project, task2))
        XCTAssertFalse(sut.isIndependent(project, task3))

        try sut.removeRelationship(&project, relationship2.id, dependentStartDay: 0)
        XCTAssertTrue(sut.isIndependent(project, task1))
        XCTAssertFalse(sut.isIndependent(project, task2))
        XCTAssertTrue(sut.isIndependent(project, task3))
    }

    func testCycleReference() throws {
        let sut = createSUT()
        var project = createProject()
        let task1 = createTask(id: .init(1))
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        let task4 = createTask(id: .init(4))

        try sut.addTask(&project, task1, startDay: 0)
        try sut.addTask(&project, task2, startDay: 0)
        try sut.addTask(&project, task3, startDay: 0)
        try sut.addTask(&project, task4, startDay: 0)

        let relationship1 = Relationship(id: .init(1),
                                        influencer: task1,
                                        dependant: task2,
                                        daysGap: 2)
        let relationship2 = Relationship(id: .init(2),
                                        influencer: task2,
                                        dependant: task3,
                                        daysGap: -2)
        let relationship3 = Relationship(id: .init(3),
                                        influencer: task3,
                                        dependant: task1,
                                        daysGap: 0)

        try sut.addRelationship(&project, relationship1)
        try sut.addRelationship(&project, relationship2)

        // task2 depends on task1, task3 depends on task2, task1 can't depend on task3
        XCTAssertThrowsError(try sut.addRelationship(&project, relationship3)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .cycleReference)
        }

        let relationship4 = Relationship(id: .init(3),
                                        influencer: task1,
                                        dependant: task3,
                                        daysGap: 0)

        // task3 already depends on task1 through task2, so no need to add this relationship
        XCTAssertThrowsError(try sut.addRelationship(&project, relationship4)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .taskAlreadyDependsOnInfluencerIndirectly)
        }
    }

    // MARK: Private
    private func createSUT() -> MProjectHelperProtocol {
        return MProjectHelper()
    }

    private func createProject(id: Int = 1,
                               name: String = "Morros de Alihuen",
                               startDate: Date = Date()) -> MProject {
        let project = MProject(id: id,
                               name: name,
                               startDate: startDate)
        return project
    }

    private func createTask(id: MTask.Id,
                            name: String = "Task name",
                            days: UInt = 7,
                            color: Palette = .red) -> MTask {
        return MTask(id: id,
                     name: name,
                     days: days,
                     color: color)
    }
}
