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

        let task1 = createTask(id: MTask.Id(1))
        let task2 = createTask(id: MTask.Id(2))
        let task3 = createTask(id: MTask.Id(3))
        try sut.addTask(task1, startDay: 0)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)
        XCTAssertEqual(sut.project.tasks.count, 3)
        XCTAssertEqual(sut.project.tasks, [task1, task2, task3])

        try sut.removeTask(taskId: task2.id, startDay: 0)
        XCTAssertEqual(sut.project.tasks.count, 2)
        XCTAssertEqual(sut.project.tasks, [task1, task3])
    }

    func testAddAndRemoveTasks_IndependentTasks() throws {
        let sut = createSUT()

        let task1 = createTask(id: MTask.Id(1))
        let task2 = createTask(id: MTask.Id(2))
        let task3 = createTask(id: MTask.Id(3))
        try sut.addTask(task1, startDay: 0)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 5)

        XCTAssertEqual(sut.project.independentTasks[0]?.first, task1)
        XCTAssertEqual(sut.project.independentTasks[0]?.last, task2)
        XCTAssertEqual(sut.project.independentTasks[5]?.first, task3)

        try sut.removeTask(taskId: task1.id, startDay: 0)
        XCTAssertEqual(sut.project.independentTasks[0]?.first, task2)

        try sut.removeTask(taskId: task2.id, startDay: 0)
        XCTAssertNil(sut.project.independentTasks[0]?.first)

        try sut.removeTask(taskId: task3.id, startDay: 0)
        XCTAssertNil(sut.project.independentTasks[5]?.first)
    }

    func testAddintExistingTask_Error() throws {
        let sut = createSUT()

        let task1 = createTask(id: MTask.Id(1),
                               name: "Plot cleaning")
        let taskWithSameId = createTask(id: MTask.Id(1))
        let taskWithDaysLessThanOne = createTask(id: MTask.Id(3),
                                                 days: 0)
        try sut.addTask(task1, startDay: 0)
        XCTAssertThrowsError(try sut.addTask(taskWithSameId, startDay: 0)) { error in
            XCTAssertEqual(error as? MEditingProjectError, MEditingProjectError.taskIdRepeated)
        }
        XCTAssertThrowsError(try sut.addTask(task1, startDay: 0)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .taskAlreadyExists)
        }
        XCTAssertThrowsError(try sut.addTask(taskWithDaysLessThanOne, startDay: 0)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .daysBiggerThanZero)
        }
    }

    func testRemoveTask_Errors() throws {
        let sut = createSUT()

        let task1 = createTask(id: MTask.Id(1),
                               name: "Plot cleaning")

        XCTAssertThrowsError(try sut.removeTask(taskId: task1.id, startDay: 0)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .unexistingTasks([task1.id]))
        }
    }

    func testRemoveTask_ShouldRemoveRelationship() throws {
        let sut = createSUT()

        let task1days: UInt = 8
        let task1StartDay: UInt = 2
        let task1 = createTask(id: MTask.Id(1), days: task1days)
        let task2 = createTask(id: MTask.Id(2))
        let task3 = createTask(id: MTask.Id(3))
        try sut.addTask(task1, startDay: task1StartDay)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)

        let gap: Int = 2
        let relationship1 = Relationship(id: .init(1),
                                         influencer: task1,
                                         dependant: task2,
                                         daysGap: gap)
        try sut.addRelationship(relationship1)
        XCTAssertNotNil(sut.project.relationships.first(where: { $0.id == relationship1.id }))
        XCTAssertTrue(sut.isIndependent(task1))
        XCTAssertFalse(sut.isIndependent(task2))

        try sut.removeTask(taskId: task1.id, startDay: task1StartDay)
        XCTAssertNil(sut.project.relationships.first(where: { $0.id == relationship1.id }))
        XCTAssertFalse(sut.isIndependent(task1))
        XCTAssertTrue(sut.isIndependent(task2))

        XCTAssertEqual(sut.tasksSortedByDays()[0], [task3])
        XCTAssertEqual(sut.tasksSortedByDays()[task1days + task1StartDay + UInt(gap)], [task2])
    }

    func testAddAndRemoveRelationships() throws {
        let sut = createSUT()

        let influencerStartDay: UInt = 1
        let dependantStartDay: UInt = 1
        let gap: Int = 2
        let influencer = createTask(id: MTask.Id(1), days: 5)
        let dependant = createTask(id: MTask.Id(2), days: 3)

        let relationship = Relationship(id: .init(1),
                                         influencer: influencer,
                                         dependant: dependant,
                                         daysGap: gap)
        try sut.addTask(influencer, startDay: influencerStartDay)
        try sut.addTask(dependant, startDay: dependantStartDay)
        try sut.addRelationship(relationship)
        XCTAssertEqual(sut.project.relationships, [relationship])
        let startDay = Int(influencerStartDay + influencer.days) + gap
        try sut.removeRelationship(relationship.id, dependentStartDay: startDay >= 0 ? UInt(startDay) : 0)
        XCTAssertEqual(sut.project.relationships, [])
        XCTAssertEqual(sut.project.independentTasks[1], [influencer])
        XCTAssertEqual(sut.project.independentTasks[8], [dependant])
    }

    func testAddingRelationships_Errors() throws {
        let sut = createSUT()

        let influencer = createTask(id: MTask.Id(1), days: 5)
        let dependant = createTask(id: MTask.Id(2), days: 3)

        let relationship = Relationship(id: .init(1),
                                         influencer: influencer,
                                         dependant: dependant,
                                         daysGap: 0)
        XCTAssertThrowsError(try sut.addRelationship(relationship)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .unexistingTasks([influencer.id, dependant.id]))
        }

        // adding tasks
        try sut.addTask(influencer, startDay: 0)
        try sut.addTask(dependant, startDay: 0)

        try sut.addRelationship(relationship)

        // trying to add the same relationship
        XCTAssertThrowsError(try sut.addRelationship(relationship)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .relationshipAlreadyExists)
        }

        // given a relationship with the same id
        let task3 = createTask(id: .init(3))
        let task4 = createTask(id: .init(4))
        let relationship2 = Relationship(id: .init(1),
                                         influencer: task3,
                                         dependant: task4,
                                         daysGap: 0)
        XCTAssertThrowsError(try sut.addRelationship(relationship2)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .relationshipIdRepeated)
        }
        let nonExistingRelationship = Relationship(id: .init(2), influencer: createTask(id: .init(9)), dependant: createTask(id: .init(10)), daysGap: 0)
        XCTAssertThrowsError(try sut.removeRelationship(nonExistingRelationship.id, dependentStartDay: 1)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .unexistingRelationship(nonExistingRelationship.id))
        }
    }

    func testTasksPositions() throws {
        let sut = createSUT()

        let task1 = createTask(id: .init(1), days: 7)
        let task2 = createTask(id: .init(2), days: 7)
        let task3 = createTask(id: .init(3), days: 7)
        let task4 = createTask(id: .init(4), days: 7)
        let task5 = createTask(id: .init(5), days: 7)
        let task6 = createTask(id: .init(6), days: 7)

        // no tasks added, no tasks to show
        XCTAssertEqual(sut.tasksSortedByDays()[0], [])
        try sut.addTask(task1, startDay: 0)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)
        try sut.addTask(task4, startDay: 0)
        try sut.addTask(task5, startDay: 0)
        try sut.addTask(task6, startDay: 0)

        let relationship1 = Relationship(id: .init(1),
                                        influencer: task1,
                                        dependant: task2,
                                        daysGap: 2)
        let relationship2 = Relationship(id: .init(2),
                                        influencer: task2,
                                        dependant: task3,
                                        daysGap: -2)

        // no relationships added, all tasks start from day 1
        XCTAssertEqual(sut.tasksSortedByDays()[0], [task1, task2, task3, task4, task5, task6])

        try sut.addRelationship(relationship1)
        try sut.addRelationship(relationship2)
        let list = sut.tasksSortedByDays()
        XCTAssertEqual(list[0], [task1, task4, task5, task6])
        XCTAssertEqual(list[9], [task2])
        XCTAssertEqual(list[14], [task3])
    }

    func testTasksPositions2() throws {
        let sut = createSUT()

        let task1 = createTask(id: .init(1), days: 7)
        let task2 = createTask(id: .init(2), days: 7)
        let task3 = createTask(id: .init(3), days: 7)

        // no tasks added, no tasks to show
        XCTAssertEqual(sut.tasksSortedByDays()[0], [])
        let task1InitialDay: UInt = 0
        let task2InitialDay: UInt = 10
        let task3InitialDay: UInt = 0
        try sut.addTask(task1, startDay: task1InitialDay)
        try sut.addTask(task2, startDay: task2InitialDay)
        try sut.addTask(task3, startDay: task3InitialDay)
        XCTAssertTrue(sut.isIndependent(task1))
        XCTAssertTrue(sut.isIndependent(task2))
        XCTAssertTrue(sut.isIndependent(task3))

        // no relationships added, all tasks start from day 1
        XCTAssertEqual(sut.tasksSortedByDays()[task1InitialDay], [task1, task3])
        XCTAssertEqual(sut.tasksSortedByDays()[task2InitialDay], [task2])
        XCTAssertEqual(sut.tasksSortedByDays()[task3InitialDay], [task1, task3])

        let relationship1 = Relationship(id: .init(1),
                                        influencer: task1,
                                        dependant: task2,
                                        daysGap: Int(task2InitialDay - task1InitialDay - task1.days))

        try sut.addRelationship(relationship1)

        let list = sut.tasksSortedByDays()
        XCTAssertEqual(list[0], [task1, task3])
        XCTAssertEqual(list[10], [task2])

        XCTAssertEqual(sut.project.independentTasks[0]?.first, task1)
        XCTAssertEqual(sut.project.independentTasks[0]?.last, task3)


        let relationship2 = Relationship(id: .init(2),
                                        influencer: task2,
                                        dependant: task3,
                                        daysGap: Int(task3InitialDay) - Int(task2InitialDay))

        try sut.addRelationship(relationship2)
        XCTAssertEqual(list[0], [task1, task3])
        XCTAssertEqual(list[10], [task2])

        XCTAssertEqual(sut.project.independentTasks[0]?.first, task1)
        XCTAssertTrue(sut.isIndependent(task1))
        XCTAssertFalse(sut.isIndependent(task2))
        XCTAssertFalse(sut.isIndependent(task3))

        try sut.removeRelationship(relationship2.id, dependentStartDay: 0)
        XCTAssertTrue(sut.isIndependent(task1))
        XCTAssertFalse(sut.isIndependent(task2))
        XCTAssertTrue(sut.isIndependent(task3))
    }

    func testCycleReference() throws {
        let sut = createSUT()

        let task1 = createTask(id: .init(1))
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        let task4 = createTask(id: .init(4))

        try sut.addTask(task1, startDay: 0)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)
        try sut.addTask(task4, startDay: 0)

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

        try sut.addRelationship(relationship1)
        try sut.addRelationship(relationship2)

        // task2 depends on task1, task3 depends on task2, task1 can't depend on task3
        XCTAssertThrowsError(try sut.addRelationship(relationship3)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .cycleReference)
        }

        let relationship4 = Relationship(id: .init(3),
                                        influencer: task1,
                                        dependant: task3,
                                        daysGap: 0)

        // task3 already depends on task1 through task2, so no need to add this relationship
        XCTAssertThrowsError(try sut.addRelationship(relationship4)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .taskAlreadyDependsOnInfluencerIndirectly)
        }
    }

    func testModifyTask() throws {
        let sut = createSUT()

        let originalName = "Original name"
        let originalDays: UInt = 10
        let originalColor = Palette.blue
        let newName = "New name"
        let newDays: UInt = 100
        let newColor = Palette.orange
        let task1StartingDay: UInt = 0
        let task1 = createTask(id: .init(1),
                               name: originalName,
                               days: originalDays,
                               color: originalColor)

        let task2 = createTask(id: .init(2),
                               name: "Task 2 Name",
                               days: 5)

        try sut.addTask(task1, startDay: task1StartingDay)
        try sut.addTask(task2, startDay: 0)

        let relationship = Relationship(id: .init(1), influencer: task1, dependant: task2, daysGap: 2)

        try sut.addRelationship(relationship)

        let replacingTask = createTask(id: .init(1),
                                       name: newName,
                                       days: newDays,
                                       color: newColor)

        XCTAssertEqual(sut.tasksSortedByDays()[0], [task1])
        XCTAssertEqual(sut.tasksSortedByDays()[task1StartingDay + originalDays + 2], [task2])

        try sut.editTask(replacingTask)

        XCTAssertEqual(sut.tasksSortedByDays()[0], [replacingTask])
        XCTAssertEqual(sut.tasksSortedByDays()[task1StartingDay + originalDays + 2], [task2])
    }

    // MARK: Private
    private func createSUT() -> MProjectHelperProtocol {
        return MProjectHelper(project: createProject())
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
