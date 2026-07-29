{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- | Compact typed fixtures for private constructive evaluator contracts.
module O2I.Validation.Relational.Test.Fixture
  ( qualificationPlan
  , qualificationOccurrencePlan
  , trianglePlan
  , TypedTriangleRow(..)
  , triangleOccurrencePlan
  , rowSignature
  , graphFrom
  , contextNode
  , relationEdge
  , nodeIdFor
  , rawId
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Types

data TypedTriangleRow = TypedTriangleRow
  { typedTriangleStrategy :: NodeId ('ContextKind 'Strategy)
  , typedTriangleIntervention :: NodeId ('ContextKind 'Intervention)
  , typedTriangleNeed :: NodeId ('ContextKind 'Need)
  , typedTriangleOccurrences :: [(RawNodeId, RelationCode, RawNodeId, Int)]
  } deriving (Eq, Show)

type OccurrenceSignature = (RawNodeId, RelationCode, RawNodeId, Int)

qualificationPlan :: RelationalIndex -> CompiledPlan (NonEmpty ProjectedPremise)
qualificationPlan index =
  rootAtom
    (nodeDomainFor (SContextKind SStrategy) index)
    qualifiesNeed
    (nodeDomainFor (SContextKind SNeed) index)
    (\_ _ premise -> finish (projectPremise premise))

qualificationOccurrencePlan ::
     RelationalIndex -> CompiledPlan OccurrenceSignature
qualificationOccurrencePlan index =
  rootAtom
    (nodeDomainFor (SContextKind SStrategy) index)
    qualifiesNeed
    (nodeDomainFor (SContextKind SNeed) index)
    (\_ _ premise ->
       finish (projectOccurrence premise (occurrenceSignature . occurrenceView)))

trianglePlan :: RelationalIndex -> CompiledPlan (NonEmpty ProjectedPremise)
trianglePlan index =
  rootAtom
    (nodeDomainFor (SContextKind SStrategy) index)
    directsIntervention
    (nodeDomainFor (SContextKind SIntervention) index)
    (\strategy intervention directsPremise ->
       extendForward
         intervention
         addressesNeed
         (nodeDomainFor (SContextKind SNeed) index)
         (\need addressesPremise ->
            constrainExisting
              strategy
              qualifiesNeed
              need
              (\qualifiesPremise ->
                 finish
                   (appendProjectedPremise
                      (appendProjectedPremise
                         (projectPremise directsPremise)
                         addressesPremise)
                      qualifiesPremise))))

triangleOccurrencePlan :: RelationalIndex -> CompiledPlan TypedTriangleRow
triangleOccurrencePlan index =
  rootAtom
    (nodeDomainFor (SContextKind SStrategy) index)
    directsIntervention
    (nodeDomainFor (SContextKind SIntervention) index)
    (\strategy intervention directsPremise ->
       extendForward
         intervention
         addressesNeed
         (nodeDomainFor (SContextKind SNeed) index)
         (\need addressesPremise ->
            constrainExisting
              strategy
              qualifiesNeed
              need
              (\qualifiesPremise ->
                 finish
                   (appendOccurrence
                      (appendOccurrence
                         (projectOccurrence
                            directsPremise
                            (\directs addresses qualifies ->
                               TypedTriangleRow
                                 { typedTriangleStrategy =
                                     projectedOccurrenceFrom directs
                                 , typedTriangleIntervention =
                                     projectedOccurrenceTo directs
                                 , typedTriangleNeed =
                                     projectedOccurrenceTo addresses
                                 , typedTriangleOccurrences =
                                     map
                                       occurrenceSignature
                                       [ occurrenceView directs
                                       , occurrenceView addresses
                                       , occurrenceView qualifies
                                       ]
                                 }))
                         addressesPremise)
                      qualifiesPremise))))

data OccurrenceView where
  OccurrenceView :: ProjectedOccurrence from to -> OccurrenceView

occurrenceView :: ProjectedOccurrence from to -> OccurrenceView
occurrenceView = OccurrenceView

occurrenceSignature :: OccurrenceView -> OccurrenceSignature
occurrenceSignature (OccurrenceView occurrence) =
  ( unNodeId (projectedOccurrenceFrom occurrence)
  , relationCode
      (relationSpec (edgeRelation (projectedOccurrenceEdge occurrence)))
  , unNodeId (projectedOccurrenceTo occurrence)
  , projectedOccurrenceOrdinal occurrence)

rowSignature :: NonEmpty ProjectedPremise -> [OccurrenceSignature]
rowSignature =
  map
    (\premise ->
       ( projectedPremiseRawFrom premise
       , projectedPremiseRelationCode premise
       , projectedPremiseRawTo premise
       , projectedPremiseOrdinal premise))
    . NonEmpty.toList

graphFrom :: [SomeNode] -> [SomeEdge] -> WellFormedGraph
graphFrom nodes =
  mkWellFormedGraph (Map.fromList [(someNodeId node, node) | node <- nodes])

contextNode :: Text -> SContext context -> SomeNode
contextNode name context = SomeNode (ContextNode (nodeIdFor name) context)

relationEdge :: Text -> Relation from to -> Text -> SomeEdge
relationEdge from relation to =
  SomeEdge
    Edge
      { edgeFrom = nodeIdFor from
      , edgeRelation = relation
      , edgeTo = nodeIdFor to
      }

nodeIdFor :: Text -> NodeId kind
nodeIdFor = mkNodeId . rawId

rawId :: Text -> RawNodeId
rawId = RawNodeId
