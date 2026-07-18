module GraphOpaqueConstructors where

import qualified O2I.Graph as Graph

forgedSomeNode :: Graph.SomeNode
forgedSomeNode = Graph.SomeNode undefined

forgedSomeEdge :: Graph.SomeEdge
forgedSomeEdge = Graph.SomeEdge undefined

forgedWellFormedGraph :: Graph.WellFormedGraph
forgedWellFormedGraph = Graph.WellFormedGraph undefined undefined
