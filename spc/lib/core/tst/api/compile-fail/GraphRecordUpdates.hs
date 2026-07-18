module GraphRecordUpdates where

import qualified O2I.Graph as Graph

rewriteSomeNode :: Graph.SomeNode -> Graph.SomeNode
rewriteSomeNode node = node {Graph.someNodeId = Graph.someNodeId node}

rewriteSomeEdge :: Graph.SomeEdge -> Graph.SomeEdge
rewriteSomeEdge edge = edge {Graph.someEdgeFrom = Graph.someEdgeFrom edge}

rewriteWellFormedGraph :: Graph.WellFormedGraph -> Graph.WellFormedGraph
rewriteWellFormedGraph graph = graph {Graph.graphNodes = Graph.graphNodes graph}
