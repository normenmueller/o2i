-- | Unchecked input representation for concrete O2I models.
module O2I.Model.Raw
  ( RawNode(..)
  , RawEdge(..)
  , RawModel(..)
  ) where

import O2I.Relation (RelationName)
import O2I.Types

data RawNode
  = RawContextNode RawNodeId Context
  | RawPrimitiveNode RawNodeId RawNodeId Primitive
  | RawStructuringNode RawNodeId RawNodeId Structuring
  | RawAnchorNode RawNodeId RawNodeId SituationAnchor
  deriving (Eq, Show)

data RawEdge = RawEdge
  { rawEdgeFrom :: RawNodeId
  , rawEdgeRelation :: RelationName
  , rawEdgeTo :: RawNodeId
  } deriving (Eq, Ord, Show)

data RawModel = RawModel
  { rawNodes :: [RawNode]
  , rawEdges :: [RawEdge]
  } deriving (Eq, Show)
