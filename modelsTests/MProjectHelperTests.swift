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

        let task1 = createTask(id: .init(1))
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        try sut.addTask(task1, startDay: 0)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)
        XCTAssertEqual(sut.project.tasks.count, 3)
        XCTAssertEqual(sut.project.tasks, [task1, task2, task3])

        try sut.removeTask(task2)
        XCTAssertEqual(sut.project.tasks.count, 2)
        XCTAssertEqual(sut.project.tasks, [task1, task3])
    }

    func testAddAndRemoveTasks_IndependentTasks() throws {
        let sut = createSUT()

        let task1 = createTask(id: .init(1))
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        try sut.addTask(task1, startDay: 0)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 5)

        XCTAssertEqual(sut.project.independentTasks[0]?.first, task1)
        XCTAssertEqual(sut.project.independentTasks[0]?.last, task2)
        XCTAssertEqual(sut.project.independentTasks[5]?.first, task3)

        try sut.removeTask(task1)
        XCTAssertEqual(sut.project.independentTasks[0]?.first, task2)

        try sut.removeTask(task2)
        XCTAssertNil(sut.project.independentTasks[0]?.first)

        try sut.removeTask(task3)
        XCTAssertNil(sut.project.independentTasks[5]?.first)
    }

    func testAddintExistingTask_Error() throws {
        let sut = createSUT()

        let task1 = createTask(id: .init(1),
                               name: "Plot cleaning")
        let taskWithSameId = createTask(id: .init(1))
        let taskWithDaysLessThanOne = createTask(id: .init(3),
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

        let task1 = createTask(id: .init(1),
                               name: "Plot cleaning")

        XCTAssertThrowsError(try sut.removeTask(task1)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .unexistingTasks([task1.id]))
        }
    }


    /*
     When removing a task, if there are dependents on it, it should remove the relationship and make them independent and set a new startDay if they don't have other relationships. The startDay should be the startDay of the task being removed, only if tasks are independent!
     if independent => remove task from the "tasks" list
                    => remove it from the "independent tasks" list.
                    => check if some task depends on it
                        => remove relationship
                        => This should be done in removingRelationship func. if this one doesn't depend on others, make it independent and set its startDay as the startDay of the removed task
                        => if this one does depend on others, "refresh" will define its startDay automatically.
     */

    func testRemoveInfluencerTask_ShouldRemoveRelationship_ShouldEditDependent() throws {
        let sut = createSUT()

        // Given only one relationship in the project, where the influencer is independent.
        let task1days: UInt = 8
        let task1StartDay: UInt = 2
        let task1 = createTask(id: .init(1), days: task1days)
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        try sut.addTask(task1, startDay: task1StartDay)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)

        let gap: Int = 2
        let relationship1 = MRelationship(id: .init(1),
                                         influencer: task1,
                                         dependent: task2,
                                         daysGap: gap)
        try sut.addRelationship(relationship1)
        XCTAssertNotNil(sut.project.relationships.first(where: { $0.id == relationship1.id }))
        XCTAssertTrue(sut.isIndependent(task1))
        XCTAssertFalse(sut.isIndependent(task2))
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task1days + task1StartDay + UInt(gap)]!, [task2])

        // When removing the influencer task
        try sut.removeTask(task1)

        // It should remove the relationship
        XCTAssertTrue(sut.project.relationships.isEmpty)
        // It should remove the influencer from the independent list anymore
        XCTAssertFalse(sut.isIndependent(task1))
        // It should make the dependent task "independent"
        XCTAssertTrue(sut.isIndependent(task2))

        // It should keep other independent tasks untouched
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[0]!, [task3])
        // It should make the dependent task to start when the influencer task was starting.
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task1days + task1StartDay + UInt(gap)]!, [task2])
    }

    // TO DO: If A -> B -> C and I remove B, what should happen? Should A -> C?
    func testRemoveInfluencerTask_ShouldRemoveRelationship_ShouldNotEditDependent() throws {
        let sut = createSUT()

        // Given many relationships in the project, if the dependent task depends on a second task
        let task1days: UInt = 8
        let task1StartDay: UInt = 2
        let task1 = createTask(id: .init(1), days: task1days)
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        try sut.addTask(task1, startDay: task1StartDay)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)

        let gap: Int = 2
        let relationship1 = MRelationship(id: .init(1),
                                         influencer: task1,
                                         dependent: task2,
                                         daysGap: gap)
        try sut.addRelationship(relationship1)
        XCTAssertNotNil(sut.project.relationships.first(where: { $0.id == relationship1.id }))
        XCTAssertTrue(sut.isIndependent(task1))
        XCTAssertFalse(sut.isIndependent(task2))
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task1days + task1StartDay + UInt(gap)]!, [task2])

        // When removing the influencer task
        try sut.removeTask(task1)

        // It should remove the relationship
        XCTAssertTrue(sut.project.relationships.isEmpty)
        // It should remove the influencer from the independent list anymore
        XCTAssertFalse(sut.isIndependent(task1))
        // It should make the dependent task "independent"
        XCTAssertTrue(sut.isIndependent(task2))

        // It should keep other independent tasks untouched
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[0]!, [task3])
        // It should make the dependent task to start when the influencer task was starting.
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task1days + task1StartDay + UInt(gap)]!, [task2])
    }

    func testRemoveDependentTask_ShouldRemoveRelationship() throws {
        let sut = createSUT()

        let task1days: UInt = 8
        let task1StartDay: UInt = 2
        let task1 = createTask(id: .init(1), days: task1days)
        let task2 = createTask(id: .init(2))
        let task3 = createTask(id: .init(3))
        try sut.addTask(task1, startDay: task1StartDay)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)

        let gap: Int = 2
        let relationship1 = MRelationship(id: .init(1),
                                         influencer: task1,
                                         dependent: task2,
                                         daysGap: gap)
        try sut.addRelationship(relationship1)
        XCTAssertNotNil(sut.project.relationships.first(where: { $0.id == relationship1.id }))
        XCTAssertTrue(sut.isIndependent(task1))
        XCTAssertFalse(sut.isIndependent(task2))

        try sut.removeTask(task2)//, startDay: task1StartDay + task2.days)
        XCTAssertTrue(sut.project.relationships.isEmpty)

        XCTAssertListsAreEqual(sut.tasksSortedByDays()[0]!, [task3])
        XCTAssertNil(sut.tasksSortedByDays()[task1days + task1StartDay + UInt(gap)])
    }

    func test_RemoveRelationship_Should_MakeDependentIndependent() throws {
        let sut = createSUT()

        let influencerStartDay: UInt = 1
        let dependentStartDay: UInt = 1
        let gap: Int = 2
        let influencer = createTask(id: .init(1), days: 5)
        let dependent = createTask(id: .init(2), days: 3)

        let relationship = MRelationship(id: .init(1),
                                         influencer: influencer,
                                         dependent: dependent,
                                         daysGap: gap)
        try sut.addTask(influencer, startDay: influencerStartDay)
        try sut.addTask(dependent, startDay: dependentStartDay)
        try sut.addRelationship(relationship)
        XCTAssertEqual(sut.project.relationships, [relationship])
        let startDay = Int(influencerStartDay + influencer.days) + gap
        try sut.removeRelationship(relationship, dependentStartDay: UInt(startDay))
        XCTAssertEqual(sut.project.relationships, [])
        XCTAssertEqual(sut.project.independentTasks[1], [influencer])
        // it should make the dependent task independent as it doesn't depend on any task now
        XCTAssertEqual(sut.project.independentTasks[8], [dependent])
    }

    func test_RemoveRelationship_Should_keepdependentasdependent() throws {
        // GIVEN one task depends on other two
        let sut = createSUT()

        let influencerDays: UInt = 5
        let influencerStartDay: UInt = 1
        let dependentStartDay: UInt = 1
        let gap: Int = 2
        let influencer = createTask(id: .init(1), days: influencerDays)
        let dependent = createTask(id: .init(2), days: 3)
        let secondInfluencer = createTask(id: .init(3), days: influencerDays)
        let relationship1 = MRelationship(id: .init(1),
                                         influencer: influencer,
                                         dependent: dependent,
                                         daysGap: gap)
        let relationship2 = MRelationship(id: .init(3),
                                         influencer: secondInfluencer,
                                         dependent: dependent,
                                         daysGap: gap)
        try sut.addTask(influencer, startDay: influencerStartDay)
        try sut.addTask(dependent, startDay: dependentStartDay)
        try sut.addTask(secondInfluencer, startDay: influencerStartDay)
        try sut.addRelationship(relationship1)
        try sut.addRelationship(relationship2)
        XCTAssertEqual(sut.project.relationships, [relationship1, relationship2])
        let startDay = Int(influencerStartDay + influencer.days) + gap

        XCTAssertListsAreEqual(sut.tasksSortedByDays()[1]!, [influencer, secondInfluencer])
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[influencerDays + influencerStartDay + UInt(gap)]!, [dependent])

        // WHEN removing one relationship
        try sut.removeRelationship(relationship1, dependentStartDay: UInt(startDay))
        XCTAssertEqual(sut.project.relationships, [relationship2])
        XCTAssertEqual(sut.project.independentTasks[1], [influencer, secondInfluencer])
        // IT should NOT make the dependent task independent as it STILL depends on secondInfluencer
        XCTAssertNil(sut.project.independentTasks[8])

        // It should keep other independent tasks untouched
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[1]!, [influencer, secondInfluencer])
        // It should make the dependent task to start when the influencer task was starting.
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[influencerDays + influencerStartDay + UInt(gap)]!, [dependent])
    }

    func test_RemoveTask_Should_keepDependentAsDependent() throws {
        // GIVEN one task depends on other two
        let sut = createSUT()

        let influencerDays: UInt = 5
        let influencerStartDay: UInt = 1
        let secondInfluencerStartDay: UInt = 3
        let secondInfluencerDays: UInt = 5
        let dependentStartDay: UInt = 1
        let gap: Int = 2
        let influencer = createTask(id: .init(1), days: influencerDays)
        let dependent = createTask(id: .init(2), days: 3)
        let secondInfluencer = createTask(id: .init(3), days: secondInfluencerDays)
        let relationship1 = MRelationship(id: .init(1),
                                         influencer: influencer,
                                         dependent: dependent,
                                         daysGap: gap)
        let relationship2 = MRelationship(id: .init(3),
                                         influencer: secondInfluencer,
                                         dependent: dependent,
                                         daysGap: gap)
        try sut.addTask(influencer, startDay: influencerStartDay)
        try sut.addTask(dependent, startDay: dependentStartDay)
        try sut.addTask(secondInfluencer, startDay: secondInfluencerStartDay)
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[1]!, [influencer])
        try sut.addRelationship(relationship1)
        try sut.addRelationship(relationship2)
        XCTAssertEqual(sut.project.relationships, [relationship1, relationship2])

        XCTAssertListsAreEqual(sut.tasksSortedByDays()[1]!, [influencer])
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[3]!, [secondInfluencer])
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[influencerDays + max(influencerStartDay, secondInfluencerStartDay) + UInt(gap)]!, [dependent])

        // WHEN removing one relationship
        try sut.removeTask(influencer)
        XCTAssertEqual(sut.project.relationships, [relationship2])
        XCTAssertEqual(sut.project.independentTasks[1], [])
        XCTAssertEqual(sut.project.independentTasks[3], [secondInfluencer])
        // IT should NOT make the dependent task independent as it STILL depends on secondInfluencer
        XCTAssertNil(sut.project.independentTasks[8])

        // It should keep other independent tasks untouched
        let firstDayList = try XCTUnwrap(sut.tasksSortedByDays()[3])
        XCTAssertListsAreEqual(firstDayList, [secondInfluencer])
        // It should define when the dependent task starts depending on its new only influencer.
        let dependentDayList = try XCTUnwrap(sut.tasksSortedByDays()[secondInfluencerDays + secondInfluencerStartDay + UInt(gap)])
        XCTAssertListsAreEqual(dependentDayList, [dependent])
    }


// TO DO: what happens if, having 2 influencers one of those moves in time that is needs to move in time the dependent? How is the relationships going to end?
    func testAddingRelationships_Errors() throws {
        let sut = createSUT()

        let influencer = createTask(id: .init(1), days: 5)
        let dependent = createTask(id: .init(2), days: 3)

        let relationship = MRelationship(id: .init(1),
                                         influencer: influencer,
                                         dependent: dependent,
                                         daysGap: 0)
        XCTAssertThrowsError(try sut.addRelationship(relationship)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .unexistingTasks([influencer.id, dependent.id]))
        }

        // adding tasks
        try sut.addTask(influencer, startDay: 0)
        try sut.addTask(dependent, startDay: 0)

        try sut.addRelationship(relationship)

        // trying to add the same relationship
        XCTAssertThrowsError(try sut.addRelationship(relationship)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .relationshipAlreadyExists)
        }

        // given a relationship with the same id
        let task3 = createTask(id: .init(3))
        let task4 = createTask(id: .init(4))
        let relationship2 = MRelationship(id: .init(1),
                                         influencer: task3,
                                         dependent: task4,
                                         daysGap: 0)
        XCTAssertThrowsError(try sut.addRelationship(relationship2)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .relationshipIdRepeated)
        }
        let nonExistingRelationship = MRelationship(id: .init(2), influencer: createTask(id: .init(9)), dependent: createTask(id: .init(10)), daysGap: 0)
        XCTAssertThrowsError(try sut.removeRelationship(nonExistingRelationship, dependentStartDay: 1)) { error in
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
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[0]!, [])
        try sut.addTask(task1, startDay: 0)
        try sut.addTask(task2, startDay: 0)
        try sut.addTask(task3, startDay: 0)
        try sut.addTask(task4, startDay: 0)
        try sut.addTask(task5, startDay: 0)
        try sut.addTask(task6, startDay: 0)

        let relationship1 = MRelationship(id: .init(1),
                                        influencer: task1,
                                        dependent: task2,
                                        daysGap: 2)
        let relationship2 = MRelationship(id: .init(2),
                                        influencer: task2,
                                        dependent: task3,
                                        daysGap: -2)

        // no relationships added, all tasks start from day 1
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[0]!, [task1, task2, task3, task4, task5, task6])

        try sut.addRelationship(relationship1)
        try sut.addRelationship(relationship2)
        let list = sut.tasksSortedByDays()
        XCTAssertListsAreEqual(list[0]!, [task1, task4, task5, task6])
        XCTAssertListsAreEqual(list[9]!, [task2])
        XCTAssertListsAreEqual(list[14]!, [task3])
    }

    func testTasksPositions2() throws {
        let sut = createSUT()

        let task1 = createTask(id: .init(1), days: 7)
        let task2 = createTask(id: .init(2), days: 7)
        let task3 = createTask(id: .init(3), days: 7)

        // no tasks added, no tasks to show
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[0]!, [])
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
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task1InitialDay]!, [task1, task3])
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task2InitialDay]!, [task2])
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task3InitialDay]!, [task1, task3])

        let relationship1 = MRelationship(id: .init(1),
                                        influencer: task1,
                                        dependent: task2,
                                        daysGap: Int(task2InitialDay - task1InitialDay - task1.days))

        try sut.addRelationship(relationship1)

        let list = sut.tasksSortedByDays()
        XCTAssertListsAreEqual(list[0]!, [task1, task3])
        XCTAssertListsAreEqual(list[10]!, [task2])

        XCTAssertEqual(sut.project.independentTasks[0]?.first, task1)
        XCTAssertEqual(sut.project.independentTasks[0]?.last, task3)


        let relationship2 = MRelationship(id: .init(2),
                                        influencer: task2,
                                        dependent: task3,
                                        daysGap: Int(task3InitialDay) - Int(task2InitialDay))

        try sut.addRelationship(relationship2)
        XCTAssertListsAreEqual(list[0]!, [task1, task3])
        XCTAssertListsAreEqual(list[10]!, [task2])

        XCTAssertEqual(sut.project.independentTasks[0]?.first, task1)
        XCTAssertTrue(sut.isIndependent(task1))
        XCTAssertFalse(sut.isIndependent(task2))
        XCTAssertFalse(sut.isIndependent(task3))

        try sut.removeRelationship(relationship2, dependentStartDay: 0)
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

        let relationship1 = MRelationship(id: .init(1),
                                        influencer: task1,
                                        dependent: task2,
                                        daysGap: 2)
        let relationship2 = MRelationship(id: .init(2),
                                        influencer: task2,
                                        dependent: task3,
                                        daysGap: -2)
        let relationship3 = MRelationship(id: .init(3),
                                        influencer: task3,
                                        dependent: task1,
                                        daysGap: 0)

        try sut.addRelationship(relationship1)
        try sut.addRelationship(relationship2)

        // task2 depends on task1, task3 depends on task2, task1 can't depend on task3
        XCTAssertThrowsError(try sut.addRelationship(relationship3)) { error in
            XCTAssertEqual(error as? MEditingProjectError, .cycleReference)
        }

        let relationship4 = MRelationship(id: .init(4),
                                        influencer: task1,
                                        dependent: task3,
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
        let originalColor = MPalette.blue
        let newName = "New name"
        let newDays: UInt = 100
        let newColor = MPalette.orange
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

        let relationship = MRelationship(id: .init(1), influencer: task1, dependent: task2, daysGap: 2)

        try sut.addRelationship(relationship)

        let replacingTask = createTask(id: .init(1),
                                       name: newName,
                                       days: newDays,
                                       color: newColor)

        XCTAssertListsAreEqual(sut.tasksSortedByDays()[0]!, [task1])
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task1StartingDay + originalDays + 2]!, [task2])

        try sut.editTask(replacingTask)

        XCTAssertListsAreEqual(sut.tasksSortedByDays()[0]!, [replacingTask])
        XCTAssertListsAreEqual(sut.tasksSortedByDays()[task1StartingDay + originalDays + 2]!, [task2])
    }

    func test_EditTask_Errors() throws {
        // GIVEN there is no task with X id
        let sut = createSUT()
        let replacingTask = createTask(id: .init(1))

        // WHEN trying to replace it
        XCTAssertThrowsError(try sut.editTask(replacingTask)) { error in
            // IT should fail with the .unexistingTask error
            XCTAssertEqual(error as? MEditingProjectError, .unexistingTasks([replacingTask.id]))
        }
    }

    // MARK: Private
    private func createSUT() -> MProjectHelperProtocol {
        return MProjectHelper(project: createProject())
    }

    private func createProject(id: Identifier<MProject> = .init(1),
                               name: String = "Morros de Alihuen",
                               startDate: Date = Date()) -> MProject {
        let project = MProject(id: id,
                               name: name,
                               startDate: startDate)
        return project
    }

    private func createTask(id: Identifier<MTask>,
                            name: String = "Task name",
                            days: UInt = 7,
                            color: MPalette = .red) -> MTask {
        return MTask(id: id,
                     name: name,
                     days: days,
                     color: color)
    }
}

extension MTask: Comparable {
    public static func < (lhs: MTask, rhs: MTask) -> Bool {
        lhs.id.value < rhs.id.value
    }
}

// TO DO: Move these extensions to another target
extension Array where Element: Comparable {
    func containsSameElements(as other: [Element]) -> Bool {
        return self.count == other.count && self.sorted() == other.sorted()
    }
}

extension XCTest {
    func XCTAssertListsAreEqual<T>(_ expression1: @autoclosure () throws -> [T], _ expression2: @autoclosure () throws -> [T], _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) where T : Comparable {
        try XCTAssertTrue(expression1().containsSameElements(as: expression2()))
    }
}
