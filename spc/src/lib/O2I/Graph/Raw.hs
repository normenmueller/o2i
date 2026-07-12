-- | Unchecked graph input expressed in the O2I semantic language.
--
-- Raw graphs retain runtime identifiers and values. Structural validation
-- elaborates them into the typed graph representation.
module O2I.Graph.Raw
  ( RawNode(..)
  , RawEdge(..)
  , RawGraph(..)
  ) where

import O2I.Language.Element
import O2I.Language.Relation (RelationName)

-- | Unchecked graph node accepted at the structural-validation boundary.
data RawNode
  = RawContextNode RawNodeId Context
    -- ^ Identifier and declared context type.
  | RawPrimitiveNode RawNodeId RawNodeId Primitive
    -- ^ Identifier, owning context identifier, and primitive type.
  | RawStructuringNode RawNodeId RawNodeId Structuring
    -- ^ Identifier, owning context identifier, and structuring type.
  | RawAnchorNode RawNodeId RawNodeId SituationAnchor
    -- ^ Identifier, owning Situation identifier, and anchor type.
  deriving (Eq, Show)

-- | Unchecked directed edge identified by endpoints and relation name.
data RawEdge = RawEdge
  { rawEdgeFrom :: RawNodeId -- ^ Declared source node identifier.
  , rawEdgeRelation :: RelationName -- ^ Declared relation name.
  , rawEdgeTo :: RawNodeId -- ^ Declared target node identifier.
  } deriving (Eq, Ord, Show)

-- | Unchecked graph input; structural guarantees are established later.
data RawGraph = RawGraph
  { rawNodes :: [RawNode] -- ^ Nodes in source order.
  , rawEdges :: [RawEdge] -- ^ Edges in source order.
  } deriving (Eq, Show)
