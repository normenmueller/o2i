-- | Unchecked graph input expressed in the O2I semantic language.
--
-- Raw graphs retain runtime identifiers and values. Structural validation
-- elaborates them into the typed graph representation.
module O2I.Graph.Raw
  ( RawNode(..)
  , RawEdge(..)
  , CandidateGraphProposition(..)
  , RawClaimGraph(..)
  , RawGraph(..)
  ) where

import O2I.Language.Claim (Claim)
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
  | RawAnchorNode RawNodeId SituationAnchor
    -- ^ Identifier and anchor type.
  deriving (Eq, Show)

-- | Unchecked directed edge identified by endpoints and relation name.
data RawEdge = RawEdge
  { rawEdgeFrom :: RawNodeId -- ^ Declared source node identifier.
  , rawEdgeRelation :: RelationName -- ^ Declared relation name.
  , rawEdgeTo :: RawNodeId -- ^ Declared target node identifier.
  } deriving (Eq, Ord, Show)

-- | Structurally admissible candidate retained but not graph-elaborated.
data CandidateGraphProposition
  = CandidateNodeProposition RawNode
    -- ^ Proposed node declaration excluded from the typed graph.
  | CandidateEdgeProposition RawEdge
    -- ^ Proposed relation declaration excluded from the typed graph.
  deriving (Eq, Show)

-- | Unchecked atomic graph claims for explicitly incomplete modeling.
data RawClaimGraph = RawClaimGraph
  { rawNodeClaims :: [Claim RawNode] -- ^ Node claims in source order.
  , rawEdgeClaims :: [Claim RawEdge] -- ^ Relation claims in source order.
  } deriving (Eq, Show)

-- | Unchecked asserted graph input; structural guarantees are established later.
--
-- Use 'RawClaimGraph' when candidate propositions are present. Supplying a
-- 'RawGraph' explicitly asserts every contained proposition.
data RawGraph = RawGraph
  { rawNodes :: [RawNode] -- ^ Asserted nodes in source order.
  , rawEdges :: [RawEdge] -- ^ Asserted relations in source order.
  } deriving (Eq, Show)
