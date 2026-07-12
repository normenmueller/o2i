-- | Focused facade for concrete O2I graph instances.
--
-- Raw graph values form unchecked validation input. A 'WellFormedGraph' is
-- opaque and can only be obtained through structural validation. The exposed
-- typed operations are read-only observations and graph queries.
module O2I.Graph
  ( module O2I.Graph.Raw
  , SomeNode
  , SomeEdge
  , WellFormedGraph
  , modelNodes
  , modelEdges
  , someNodeId
  , someNodeKind
  , someNodeOwner
  , someEdgeFrom
  , someEdgeRelation
  , someEdgeTo
  , lookupNode
  , contextNodesOf
  , primitiveNodesIn
  , structuringNodesIn
  , anchorNodesIn
  , hasEdge
  , outgoingContextTargets
  ) where

import O2I.Graph.Raw
import O2I.Graph.Typed
  ( SomeEdge
  , SomeNode
  , WellFormedGraph
  , anchorNodesIn
  , contextNodesOf
  , hasEdge
  , lookupNode
  , modelEdges
  , modelNodes
  , outgoingContextTargets
  , primitiveNodesIn
  , someEdgeFrom
  , someEdgeRelation
  , someEdgeTo
  , someNodeId
  , someNodeKind
  , someNodeOwner
  , structuringNodesIn
  )
