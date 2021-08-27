//
//  modelsTests.swift
//  modelsTests
//
//  Created by Moldes, Jose on 22/08/2021.
//

import XCTest

@testable import models
class modelsTests: XCTestCase {

    func testAddAndRemoveTasks() throws {
        var project = createSUT()
        let task1 = createTask(id: MTask.Id(1))
        let task2 = createTask(id: MTask.Id(2))
        let task3 = createTask(id: MTask.Id(3))
        try project.addTask(task1)
        try project.addTask(task2)
        try project.addTask(task3)
        XCTAssertEqual(project.tasks.count, 3)
        XCTAssertEqual(project.tasks, [task1, task2, task3])

        project.removeTask(id: task2.id)
        XCTAssertEqual(project.tasks.count, 2)
        XCTAssertEqual(project.tasks, [task1, task3])
    }

    func testAddintExistingTask_Error() throws {
        var project = createSUT()
        let task1 = createTask(id: MTask.Id(1),
                               name: "Plot cleaning")
        let taskWithSameId = createTask(id: MTask.Id(1))
        let taskWithDaysLessThanOne = createTask(id: MTask.Id(3),
                                                 days: 0)
        try project.addTask(task1)
        XCTAssertThrowsError(try project.addTask(taskWithSameId)) { error in
            XCTAssertEqual(error as? MEditingProjectError, MEditingProjectError.taskIdRepeated)
        }
        XCTAssertThrowsError(try project.addTask(task1)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .taskAlreadyExists)
        }
        XCTAssertThrowsError(try project.addTask(taskWithDaysLessThanOne)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .daysBiggerThanZero)
        }
    }

    func testAddAndRemoveRelationships() throws {
        var sut = createSUT()
        let influencer = createTask(id: MTask.Id(1), days: 5)
        let dependant = createTask(id: MTask.Id(2), days: 3)

        let relationship = Relationship(id: .init(1),
                                         influencer: influencer,
                                         dependant: dependant,
                                         daysGap: 0)
        try sut.addTask(influencer)
        try sut.addTask(dependant)
        try sut.addRelationship(relationship)
        XCTAssertEqual(sut.relationships, [relationship])
        sut.removeRelationship(relationship.id)
        XCTAssertEqual(sut.relationships, [])
    }

    func testAddingRelationships_Errors() throws {
        var sut = createSUT()
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
        try sut.addTask(influencer)
        try sut.addTask(dependant)

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
    }

    func testTasksPositions() throws {
        var sut = createSUT()
        let task1 = createTask(id: .init(1))
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        let task4 = createTask(id: .init(4))
        let task5 = createTask(id: .init(5))
        let task6 = createTask(id: .init(6))

        // no tasks added, no tasks to show
        XCTAssertEqual(sut.tasksByDays()[0], [])
        try sut.addTask(task1)
        try sut.addTask(task2)
        try sut.addTask(task3)
        try sut.addTask(task4)
        try sut.addTask(task5)
        try sut.addTask(task6)

        let relationship1 = Relationship(id: .init(1),
                                        influencer: task1,
                                        dependant: task2,
                                        daysGap: 2)
        let relationship2 = Relationship(id: .init(2),
                                        influencer: task2,
                                        dependant: task3,
                                        daysGap: -2)

        // no relationships added, all tasks start from day 1
        XCTAssertEqual(sut.tasksByDays()[0], [task1, task2, task3, task4, task5, task6])

        try sut.addRelationship(relationship1)
        try sut.addRelationship(relationship2)
        let list = sut.tasksByDays()
        XCTAssertEqual(list[0], [task1, task4, task5, task6])
        XCTAssertEqual(list[9], [task2])
        XCTAssertEqual(list[14], [task3])
    }

    func testCycleReference() throws {
        var sut = createSUT()
        let task1 = createTask(id: .init(1))
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        let task4 = createTask(id: .init(4))

        try sut.addTask(task1)
        try sut.addTask(task2)
        try sut.addTask(task3)
        try sut.addTask(task4)

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

    // MARK: Private
    private func createSUT(id: Int = 1,
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
