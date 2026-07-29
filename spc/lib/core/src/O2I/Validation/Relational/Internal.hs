{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RoleAnnotations #-}
{-# LANGUAGE TypeOperators #-}

-- | Executor-internal kernel for typed relational evaluation.
--
-- A plan starts with one relation atom. Every subsequent variable is attached
-- to an already bound prefix, while constraints may only connect existing
-- variables. Each declared premise receives a fresh nominal token. The token,
-- endpoint kinds, and declaration order form one exact type-level shape shared
-- by the plan, its premise sequence, its matched occurrences, and its
-- projection. Rule-authoring modules use the safe
-- "O2I.Validation.Relational.Types" facade and never import this kernel.
module O2I.Validation.Relational.Internal
  ( Domain
  , emptyDomain
  , singletonDomain
  , domainFromList
  , domainInsert
  , domainToAscList
  , domainSize
  , domainMember
  , Bound
  , boundKey
  , boundKind
  , boundDomain
  , sameBound
  , SomeBound(..)
  , Premise
  , PremiseKey
  , premiseFrom
  , premiseRelation
  , premiseTo
  , SomePremise(..)
  , PremiseShape(..)
  , Premises(..)
  , premisesToList
  , ProjectedPremise
  , projectedPremiseOrdinal
  , projectedPremiseEdge
  , projectedPremiseRawFrom
  , projectedPremiseRelationCode
  , projectedPremiseRelationName
  , projectedPremiseRawTo
  , ProjectedOccurrence
  , projectedOccurrenceFrom
  , projectedOccurrenceTo
  , projectedOccurrenceOrdinal
  , projectedOccurrenceEdge
  , ProjectionMode(..)
  , Projection
  , projectPremise
  , appendProjectedPremise
  , projectOccurrence
  , appendOccurrence
  , MatchedPremise
  , MatchedPremises
  , emptyMatchedPremises
  , appendMatchedPremise
  , applyProjection
  , Plan
  , CompiledPlan
  , rootAtom
  , extendForward
  , extendBackward
  , constrainExisting
  , finish
  , withCompiledPlan
  , EdgeOccurrence
  , mkEdgeOccurrence
  , occurrenceOrdinal
  , occurrenceEdge
  ) where

import Data.Kind (Type)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.Set as Set
import Data.Set (Set)
import Data.Type.Equality ((:~:))
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Relation

-- | Sorted, duplicate-free domain of nodes of one statically fixed kind.
type role Domain nominal

newtype Domain (kind :: NodeKind) =
  Domain (Set (NodeId kind))

-- | Empty typed node domain.
emptyDomain :: Domain kind
emptyDomain = Domain Set.empty

-- | Singleton typed node domain.
singletonDomain :: NodeId kind -> Domain kind
singletonDomain = Domain . Set.singleton

-- | Build a sorted, duplicate-free typed domain.
domainFromList :: [NodeId kind] -> Domain kind
domainFromList = Domain . Set.fromList

-- | Insert one node without weakening the domain kind.
domainInsert :: NodeId kind -> Domain kind -> Domain kind
domainInsert value (Domain values) = Domain (Set.insert value values)

-- | Enumerate a domain in canonical identifier order.
domainToAscList :: Domain kind -> [NodeId kind]
domainToAscList (Domain values) = Set.toAscList values

-- | Return the number of distinct nodes in a domain.
domainSize :: Domain kind -> Int
domainSize (Domain values) = Set.size values

-- | Test membership in one typed domain.
domainMember :: NodeId kind -> Domain kind -> Bool
domainMember value (Domain values) = Set.member value values

-- | One internally allocated variable in a generative plan scope.
--
-- Domain-rule authors receive values only from the constructive callbacks.
-- They cannot allocate keys, inspect keys, or move a variable between plans.
type role Bound nominal nominal

data Bound (scope :: Type) (kind :: NodeKind) = Bound
  { boundOrdinal :: !Int
  , boundKind :: SNodeKind kind
  , boundDomain :: Domain kind
  }

-- | Read the evaluator-owned identity of one bound variable.
--
-- The identity is allocated internally and is never accepted as author input.
boundKey :: Bound scope kind -> Int
boundKey = boundOrdinal

-- | Existential bound retained by the private executor.
data SomeBound scope where
  SomeBound :: Bound scope kind -> SomeBound scope

-- | Prove that two handles in one scope denote the same typed variable.
sameBound :: Bound scope left -> Bound scope right -> Maybe (left :~: right)
sameBound left right
  | boundOrdinal left /= boundOrdinal right = Nothing
  | otherwise = eqSNodeKind (boundKind left) (boundKind right)

-- | Nominal key pairing one plan scope with one generative premise token.
--
-- The key occupies the existing private premise index so relation indices can
-- remain indifferent to evaluator identity while projections retain it.
data PremiseKey (scope :: Type) (token :: Type)

-- | One typed relation premise with a fresh identity in one plan scope.
type role Premise nominal nominal nominal

data Premise (key :: Type) from to where
  Premise
    :: !Int
    -> Bound scope from
    -> Relation from to
    -> Bound scope to
    -> Premise (PremiseKey scope token) from to

-- | Read the source variable of one typed premise.
premiseFrom :: Premise (PremiseKey scope token) from to -> Bound scope from
premiseFrom (Premise _ from _ _) = from

-- | Read the relation of one typed premise.
premiseRelation :: Premise key from to -> Relation from to
premiseRelation (Premise _ _ relation _) = relation

-- | Read the target variable of one typed premise.
premiseTo :: Premise (PremiseKey scope token) from to -> Bound scope to
premiseTo (Premise _ _ _ to) = to

-- | Existential premise retained by variable-domain evaluation.
data SomePremise scope where
  SomePremise :: Premise (PremiseKey scope token) from to -> SomePremise scope

-- | Exact declaration-order shape of one premise sequence.
data PremiseShape
  = EmptyPremises
  | SnocPremise PremiseShape Type NodeKind NodeKind

-- | Premises indexed by token, endpoints, and declaration order.
data Premises (scope :: Type) (shape :: PremiseShape) where
  PremiseNil :: Premises scope 'EmptyPremises
  PremiseSnoc
    :: Premises scope shape
    -> Premise (PremiseKey scope token) from to
    -> Premises scope ('SnocPremise shape token from to)

-- | Erase only sequence indices for variable-domain evaluation.
premisesToList :: Premises scope shape -> [SomePremise scope]
premisesToList premises = collect premises []
  where
    collect ::
         Premises localScope localShape
      -> [SomePremise localScope]
      -> [SomePremise localScope]
    collect PremiseNil accumulated = accumulated
    collect (PremiseSnoc prefix premise) accumulated =
      collect prefix (SomePremise premise : accumulated)

-- | One exact persisted edge occurrence in canonical index order.
data EdgeOccurrence from to = EdgeOccurrence
  { occurrenceOrdinal :: !Int
  , occurrenceEdge :: Edge from to
  }

-- | Construct one typed edge occurrence after canonical indexing.
mkEdgeOccurrence :: Int -> Edge from to -> EdgeOccurrence from to
mkEdgeOccurrence = EdgeOccurrence

-- | One evaluator-selected occurrence retaining premise identity and endpoints.
--
-- Its constructor is hidden. The private evaluator can create values only
-- through 'appendMatchedPremise', which simultaneously advances the exact
-- premise shape.
data MatchedPremise (scope :: Type) (token :: Type) (from :: NodeKind) (to :: NodeKind) where
  MatchedPremise
    :: Premise (PremiseKey scope token) from to
    -> EdgeOccurrence from to
    -> MatchedPremise scope token from to

-- | Exact occurrence row with the same shape as its declared premises.
data MatchedPremises (scope :: Type) (shape :: PremiseShape) where
  MatchedPremiseNil :: MatchedPremises scope 'EmptyPremises
  MatchedPremiseSnoc
    :: MatchedPremises scope shape
    -> MatchedPremise scope token from to
    -> MatchedPremises scope ('SnocPremise shape token from to)

-- | Start an evaluator-owned matched row.
emptyMatchedPremises :: MatchedPremises scope 'EmptyPremises
emptyMatchedPremises = MatchedPremiseNil

-- | Append one exact occurrence for its declaration token and endpoints.
--
-- This is the sole construction boundary used by the private evaluator.
appendMatchedPremise ::
     MatchedPremises scope shape
  -> Premise (PremiseKey scope token) from to
  -> EdgeOccurrence from to
  -> MatchedPremises scope ('SnocPremise shape token from to)
appendMatchedPremise matched premise occurrence =
  MatchedPremiseSnoc matched (MatchedPremise premise occurrence)

-- | Total, domain-neutral projection of one selected premise occurrence.
--
-- Domain projections can observe only the exact edge and canonical ordinal,
-- never evaluator bindings or a partial occurrence environment.
data ProjectedPremise where
  ProjectedPremise :: MatchedPremise scope token from to -> ProjectedPremise

-- | Read the canonical occurrence ordinal.
projectedPremiseOrdinal :: ProjectedPremise -> Int
projectedPremiseOrdinal (ProjectedPremise (MatchedPremise _ occurrence)) =
  occurrenceOrdinal occurrence

-- | Read the exact typed edge behind one projected premise.
projectedPremiseEdge :: ProjectedPremise -> SomeEdge
projectedPremiseEdge (ProjectedPremise (MatchedPremise _ occurrence)) =
  SomeEdge (occurrenceEdge occurrence)

-- | Read the raw source identifier.
projectedPremiseRawFrom :: ProjectedPremise -> RawNodeId
projectedPremiseRawFrom (ProjectedPremise (MatchedPremise _ occurrence)) =
  unNodeId (edgeFrom (occurrenceEdge occurrence))

-- | Read the stable relation code.
projectedPremiseRelationCode :: ProjectedPremise -> RelationCode
projectedPremiseRelationCode (ProjectedPremise (MatchedPremise _ occurrence)) =
  relationCode (relationSpec (edgeRelation (occurrenceEdge occurrence)))

-- | Read the stable relation name.
projectedPremiseRelationName :: ProjectedPremise -> RelationName
projectedPremiseRelationName (ProjectedPremise (MatchedPremise _ occurrence)) =
  relationNameFor (edgeRelation (occurrenceEdge occurrence))

-- | Read the raw target identifier.
projectedPremiseRawTo :: ProjectedPremise -> RawNodeId
projectedPremiseRawTo (ProjectedPremise (MatchedPremise _ occurrence)) =
  unNodeId (edgeTo (occurrenceEdge occurrence))

-- | Endpoint-typed view of one evaluator-selected persisted occurrence.
--
-- The constructor remains private to this executor kernel. Rule authors can
-- inspect only the statically typed endpoints, exact edge, and canonical
-- ordinal through total projections.
newtype ProjectedOccurrence from to =
  ProjectedOccurrence (EdgeOccurrence from to)

-- | Read the statically typed source identifier.
projectedOccurrenceFrom :: ProjectedOccurrence from to -> NodeId from
projectedOccurrenceFrom (ProjectedOccurrence occurrence) =
  edgeFrom (occurrenceEdge occurrence)

-- | Read the statically typed target identifier.
projectedOccurrenceTo :: ProjectedOccurrence from to -> NodeId to
projectedOccurrenceTo (ProjectedOccurrence occurrence) =
  edgeTo (occurrenceEdge occurrence)

-- | Read the canonical persisted-occurrence ordinal.
projectedOccurrenceOrdinal :: ProjectedOccurrence from to -> Int
projectedOccurrenceOrdinal (ProjectedOccurrence occurrence) =
  occurrenceOrdinal occurrence

-- | Read the exact endpoint-typed edge.
projectedOccurrenceEdge :: ProjectedOccurrence from to -> Edge from to
projectedOccurrenceEdge (ProjectedOccurrence occurrence) =
  occurrenceEdge occurrence

-- | Non-empty difference-list builder materialized once per result row.
data NonEmptyBuilder value =
  NonEmptyBuilder value ([value] -> [value])

singletonBuilder :: value -> NonEmptyBuilder value
singletonBuilder value = NonEmptyBuilder value id

snocBuilder :: NonEmptyBuilder value -> value -> NonEmptyBuilder value
snocBuilder (NonEmptyBuilder first rest) value =
  NonEmptyBuilder first (rest . (value :))

materializeBuilder :: NonEmptyBuilder value -> NonEmpty value
materializeBuilder (NonEmptyBuilder first rest) = first :| rest []

-- | Structural projection path over one exact non-empty premise shape.
data ProjectionPath (scope :: Type) (shape :: PremiseShape) where
  ProjectionFirst
    :: ProjectionPath scope ('SnocPremise 'EmptyPremises token from to)
  ProjectionNext
    :: ProjectionPath scope shape
    -> ProjectionPath scope ('SnocPremise shape token from to)

-- | Closed projection representations understood by the private executor.
data ProjectionMode
  = ErasedPremiseProjection
  | EndpointOccurrenceProjection

-- | Total typed row projection over one exact premise shape and mode.
--
-- The mode makes erased and endpoint-typed authoring paths disjoint. Both
-- consume matched premises structurally only when every token and endpoint
-- matches its declaration-order shape. Erased projection builds one non-empty
-- difference list in O(p). Endpoint projection applies one row-constructor
-- argument per premise in O(p), without positional decoding.
type role Projection nominal nominal nominal representational

data Projection (mode :: ProjectionMode) (scope :: Type) (shape :: PremiseShape) (row :: Type) where
  PremiseProjection
    :: ProjectionPath scope shape
    -> (NonEmptyBuilder ProjectedPremise -> row)
    -> Projection 'ErasedPremiseProjection scope shape row
  TypedOccurrenceProjection
    :: (MatchedPremises scope shape -> row)
    -> Projection 'EndpointOccurrenceProjection scope shape row

-- | Project the first declared premise.
projectPremise ::
     Premise (PremiseKey scope token) from to
  -> Projection
       'ErasedPremiseProjection
       scope
       ('SnocPremise 'EmptyPremises token from to)
       (NonEmpty ProjectedPremise)
projectPremise _ = PremiseProjection ProjectionFirst materializeBuilder

-- | Append the next declared premise to a complete occurrence projection.
--
-- Passing another premise, reordering handles, or mixing plan scopes changes
-- the projection shape and is rejected when the plan is finished.
appendProjectedPremise ::
     Projection 'ErasedPremiseProjection scope shape (NonEmpty ProjectedPremise)
  -> Premise (PremiseKey scope token) from to
  -> Projection
       'ErasedPremiseProjection
       scope
       ('SnocPremise shape token from to)
       (NonEmpty ProjectedPremise)
appendProjectedPremise (PremiseProjection path render) _ =
  PremiseProjection (ProjectionNext path) render

-- | Start an endpoint-typed row projection at the first declared premise.
--
-- The premise handle fixes the first shape token and endpoint kinds. The row
-- constructor receives only the corresponding typed occurrence.
projectOccurrence ::
     Premise (PremiseKey scope token) from to
  -> (ProjectedOccurrence from to -> row)
  -> Projection
       'EndpointOccurrenceProjection
       scope
       ('SnocPremise 'EmptyPremises token from to)
       row
projectOccurrence _ render =
  TypedOccurrenceProjection $ \(MatchedPremiseSnoc MatchedPremiseNil matched) ->
    case matched of
      MatchedPremise _ occurrence -> render (ProjectedOccurrence occurrence)

-- | Consume the next declared endpoint-typed occurrence.
--
-- The projection can advance only with the exact next premise from the same
-- plan scope. Reordering equal-endpoint premises still changes the generative
-- token sequence and is rejected by 'finish'.
appendOccurrence ::
     Projection
       'EndpointOccurrenceProjection
       scope
       shape
       (ProjectedOccurrence from to -> row)
  -> Premise (PremiseKey scope token) from to
  -> Projection
       'EndpointOccurrenceProjection
       scope
       ('SnocPremise shape token from to)
       row
appendOccurrence (TypedOccurrenceProjection render) _ =
  TypedOccurrenceProjection $ \(MatchedPremiseSnoc initial final) ->
    case final of
      MatchedPremise _ occurrence ->
        render initial (ProjectedOccurrence occurrence)

-- | Apply a total projection to an exactly matching occurrence row.
applyProjection ::
     Projection mode scope shape row -> MatchedPremises scope shape -> row
applyProjection (PremiseProjection path render) matched =
  render (projectMatchedPremises path matched)
applyProjection (TypedOccurrenceProjection render) matched = render matched

projectMatchedPremises ::
     ProjectionPath scope shape
  -> MatchedPremises scope shape
  -> NonEmptyBuilder ProjectedPremise
projectMatchedPremises ProjectionFirst (MatchedPremiseSnoc MatchedPremiseNil matched) =
  singletonBuilder (ProjectedPremise matched)
projectMatchedPremises (ProjectionNext prefix) (MatchedPremiseSnoc initial final) =
  snocBuilder (projectMatchedPremises prefix initial) (ProjectedPremise final)

-- | A connected continuation of one relational plan.
--
-- Constructors remain hidden. The exported smart constructors are the complete
-- plan-authoring surface.
type role Plan nominal nominal representational

data Plan (scope :: Type) (shape :: PremiseShape) row where
  ExtendForwardPlan
    :: Bound scope known
    -> Relation known fresh
    -> Domain fresh
    -> (forall token. Bound scope fresh -> Premise
                                             (PremiseKey scope token)
                                             known
                                             fresh -> Plan
                                                        scope
                                                        ('SnocPremise
                                                           shape
                                                           token
                                                           known
                                                           fresh)
                                                        row)
    -> Plan scope shape row
  ExtendBackwardPlan
    :: Domain fresh
    -> Relation fresh known
    -> Bound scope known
    -> (forall token. Bound scope fresh -> Premise
                                             (PremiseKey scope token)
                                             fresh
                                             known -> Plan
                                                        scope
                                                        ('SnocPremise
                                                           shape
                                                           token
                                                           fresh
                                                           known)
                                                        row)
    -> Plan scope shape row
  ConstrainExistingPlan
    :: Bound scope from
    -> Relation from to
    -> Bound scope to
    -> (forall token. Premise (PremiseKey scope token) from to -> Plan
                                                                    scope
                                                                    ('SnocPremise
                                                                       shape
                                                                       token
                                                                       from
                                                                       to)
                                                                    row)
    -> Plan scope shape row
  FinishedPlan :: Projection mode scope shape row -> Plan scope shape row

-- | Opaque, connected, projection-complete executable plan.
data CompiledPlan row where
  CompiledPlan
    :: NonEmpty (SomeBound scope)
    -> Premises scope shape
    -> Projection mode scope shape row
    -> CompiledPlan row

-- | Start a plan with one typed relation atom and fresh scope and token.
--
-- The smaller root domain is evaluated first. This preserves connectivity
-- while avoiding a needlessly wide first prefix.
rootAtom ::
     Domain from
  -> Relation from to
  -> Domain to
  -> (forall scope token. Bound scope from -> Bound scope to -> Premise
                                                                  (PremiseKey
                                                                     scope
                                                                     token)
                                                                  from
                                                                  to -> Plan
                                                                          scope
                                                                          ('SnocPremise
                                                                             'EmptyPremises
                                                                             token
                                                                             from
                                                                             to)
                                                                          row)
  -> CompiledPlan row
rootAtom fromDomain relation toDomain build =
  closePlan
    initialBounds
    (PremiseSnoc PremiseNil premise)
    2
    1
    (build from to premise)
  where
    from = Bound 0 (relationFrom spec) fromDomain
    to = Bound 1 (relationTo spec) toDomain
    premise = Premise 0 from relation to
    initialBounds
      | domainSize fromDomain <= domainSize toDomain =
        SomeBound from :| [SomeBound to]
      | otherwise = SomeBound to :| [SomeBound from]
    spec = relationSpec relation

-- | Extend a connected prefix from one existing variable to one fresh target.
extendForward ::
     Bound scope known
  -> Relation known fresh
  -> Domain fresh
  -> (forall token. Bound scope fresh -> Premise
                                           (PremiseKey scope token)
                                           known
                                           fresh -> Plan
                                                      scope
                                                      ('SnocPremise
                                                         shape
                                                         token
                                                         known
                                                         fresh)
                                                      row)
  -> Plan scope shape row
extendForward = ExtendForwardPlan

-- | Extend a connected prefix from one fresh source to one existing variable.
extendBackward ::
     Domain fresh
  -> Relation fresh known
  -> Bound scope known
  -> (forall token. Bound scope fresh -> Premise
                                           (PremiseKey scope token)
                                           fresh
                                           known -> Plan
                                                      scope
                                                      ('SnocPremise
                                                         shape
                                                         token
                                                         fresh
                                                         known)
                                                      row)
  -> Plan scope shape row
extendBackward = ExtendBackwardPlan

-- | Add a relation constraint between two already existing variables.
constrainExisting ::
     Bound scope from
  -> Relation from to
  -> Bound scope to
  -> (forall token. Premise (PremiseKey scope token) from to -> Plan
                                                                  scope
                                                                  ('SnocPremise
                                                                     shape
                                                                     token
                                                                     from
                                                                     to)
                                                                  row)
  -> Plan scope shape row
constrainExisting = ConstrainExistingPlan

-- | Complete one connected plan with an exactly shaped total row projection.
finish :: Projection mode scope shape row -> Plan scope shape row
finish = FinishedPlan

closePlan ::
     NonEmpty (SomeBound scope)
  -> Premises scope shape
  -> Int
  -> Int
  -> Plan scope shape row
  -> CompiledPlan row
closePlan bounds premises nextBound nextPremise plan =
  case plan of
    ExtendForwardPlan known relation domain continue ->
      let fresh = Bound nextBound (relationTo (relationSpec relation)) domain
          premise = Premise nextPremise known relation fresh
       in closePlan
            (bounds <> (SomeBound fresh :| []))
            (PremiseSnoc premises premise)
            (nextBound + 1)
            (nextPremise + 1)
            (continue fresh premise)
    ExtendBackwardPlan domain relation known continue ->
      let fresh = Bound nextBound (relationFrom (relationSpec relation)) domain
          premise = Premise nextPremise fresh relation known
       in closePlan
            (bounds <> (SomeBound fresh :| []))
            (PremiseSnoc premises premise)
            (nextBound + 1)
            (nextPremise + 1)
            (continue fresh premise)
    ConstrainExistingPlan from relation to continue ->
      let premise = Premise nextPremise from relation to
       in closePlan
            bounds
            (PremiseSnoc premises premise)
            nextBound
            (nextPremise + 1)
            (continue premise)
    FinishedPlan projection -> CompiledPlan bounds premises projection

-- | Consume an opaque plan without allowing scope or shape to escape.
withCompiledPlan ::
     CompiledPlan row
  -> (forall mode scope shape. NonEmpty (SomeBound scope) -> Premises
                                                               scope
                                                               shape -> Projection
                                                                          mode
                                                                          scope
                                                                          shape
                                                                          row -> result)
  -> result
withCompiledPlan (CompiledPlan bounds premises projection) consume =
  consume bounds premises projection
