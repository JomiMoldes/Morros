//
//  MTask.swift
//  ModelsInterfaces
//
//  Created by Moldes, Miguel on 01/05/2022.
//

import Foundation

public struct MTask: Equatable, Hashable{

    public let id: Identifier<Self>
    public let name: String
    public let days: UInt
    public let color: MPalette

    public init(id: Identifier<Self>,
                name: String,
                days: UInt,
                color: MPalette) {
        self.id = id
        self.name = name
        self.days = days
        self.color = color
    }
}

public struct Identifier<Holder>: Equatable, Hashable {
    public let value: Int

    public init(_ value: Int) {
        self.value = value
    }
}
