Morros is a an app that allows users to manage tasks and visualize them in a Gantt chart.

MTask -> a task unit. Most important property is the amount of days that it takes to do it.
MRelationshipt -> defines the relation between two MTasks. One will be the "influencer" and the other de "dependent". There is also a "daysGap" which defines the time needed to wait to start the dependent task when the influencer one is done.

MProjectHelper -> is the class responsible of ordering the task in the timeline.
    The idea is that each task doesn't need to know its relationships and it shouldn't react itself to a change of its "influencers". In case of a change, MProjectHelper will take care of showing the results in the chart.
    There are two important processes here:
        1. The refresh. In the initialization and after any change, this class will "order" all the tasks, defining their startDays depending on their relationships.
        2. The snapshot. After the "refresh" process, a "snapshot" process will run and will save the startDay for all the tasks, in order to make it easier to find the startDay of a task without needing to loop through all the tasks and relationships. TBD
        

TO DO:

- Think about isolating functionallities. Can I make them like layers?
- MProject: replace arrays by sets
- Codable: // TO DO: make everything Codable and save it locally
- Array extension: // TO DO: Move these extensions to another target
- Relationships: // TO DO: what happens if, having 2 influencers one of those moves in time that is needs to move in time the dependent? How is the relationships going to end?
- Editing tasks: // TO DO: think a better way to edit tasks.
- Separate responsibilities. MProjectHelper does too much.
    - CRUD operations
    - Tasks sorting.
- Think if the CRUD operations should not happen directly extending MProject. MProject could be changed from anywhere, how can I avoid that problem? 
    
