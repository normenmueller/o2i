{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- | Format-neutral occurrence facts and conservative macro-premise discovery.
--
-- The index retains unchecked persisted O2I facts. It performs no structural
-- validation and does not manufacture model content. Its sole purpose is to
-- apply the core-owned 'MacroEvidenceRule' registry monotonically so that an
-- inspection scope includes every persisted relation that could participate in
-- an exact evidence witness.
module O2I.Graph.Macro
  ( MacroFactIndex
  , buildMacroFactIndex
  , MacroClaim
  , macroClaims
  , macroClaimConclusion
  , MacroEvidenceRule
  , macroEvidenceRules
  , macroEvidenceRuleConclusion
  , MacroDependency
  , macroDependencyEdge
  , macroScopeDependencies
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation hiding (MacroRelation)
import qualified O2I.Language.Relation as Relation

-- | Opaque occurrence-preserving index of persisted nodes and relationships.
--
-- The caller-supplied identity parameters identify concrete occurrences, not
-- semantic node IDs. Input order and repeated occurrences are retained. Model
-- validity remains the responsibility of structural validation.
data MacroFactIndex node edge = MacroFactIndex
  { indexedMacroNodes :: [(node, RawNode)]
  , indexedMacroEdges :: [(edge, RawEdge)]
  }

-- | Index persisted, format-neutral facts without validating or normalizing
-- them.
buildMacroFactIndex ::
     [(node, RawNode)] -> [(edge, RawEdge)] -> MacroFactIndex node edge
buildMacroFactIndex = MacroFactIndex

-- | One occurrence-level premise dependency discovered by the conservative
-- interpreter.
data MacroDependency edge =
  MacroDependency edge

-- | Recover the concrete persisted premise-relation occurrence.
macroDependencyEdge :: MacroDependency edge -> edge
macroDependencyEdge (MacroDependency edge) = edge

-- | Reify every persisted registered context macrorelation as a typed claim.
--
-- Duplicate raw Context IDs intentionally produce every occurrence-level
-- claim. Structural validation, not scope discovery, diagnoses that defect.
macroClaims :: MacroFactIndex node edge -> [(edge, MacroClaim node)]
macroClaims index = concatMap claimsForEdge (indexedMacroEdges index)
  where
    claimsForEdge (edgeOccurrence, edge) =
      concatMap
        (claimsForRelation (indexedMacroNodes index) edgeOccurrence edge)
        (registeredMacroRelations (rawEdgeRelation edge))

data SomeMacroRelation where
  SomeMacroRelation :: MacroRelation from to -> SomeMacroRelation

registeredMacroRelations :: RelationName -> [SomeMacroRelation]
registeredMacroRelations name =
  concatMap reifyMacroRelation (lookupRelations name)

reifyMacroRelation :: SomeRelation -> [SomeMacroRelation]
reifyMacroRelation (SomeRelation relation) =
  case ( relationFrom spec
       , relationTo spec
       , relationSemantics spec
       , lookupMacroEvidenceRule (relationCode spec)) of
    (SContextKind from, SContextKind to, Relation.MacroRelation _, Just rule) ->
      [ SomeMacroRelation
          MacroRelation
            { registeredMacroCode = relationCode spec
            , registeredMacroRule = rule
            , registeredMacroFrom = from
            , registeredMacroTo = to
            }
      ]
    _ -> []
  where
    spec = relationSpec relation

claimsForRelation ::
     [(node, RawNode)]
  -> edge
  -> RawEdge
  -> SomeMacroRelation
  -> [(edge, MacroClaim node)]
claimsForRelation nodes edgeOccurrence edge (SomeMacroRelation relation) =
  [ ( edgeOccurrence
    , RegisteredMacroClaim
        (MacroContextRef fromOccurrence fromIdentifier fromContext)
        relation
        (MacroContextRef toOccurrence toIdentifier toContext))
  | (fromOccurrence, RawContextNode fromIdentifier fromValue) <- nodes
  , fromIdentifier == rawEdgeFrom edge
  , fromValue == contextValue fromContext
  , (toOccurrence, RawContextNode toIdentifier toValue) <- nodes
  , toIdentifier == rawEdgeTo edge
  , toValue == contextValue toContext
  ]
  where
    fromContext = registeredMacroFrom relation
    toContext = registeredMacroTo relation

-- | Discover every persisted premise relation that could substantiate a claim.
--
-- Discovery is conservative and monotone: Strategy-role refinements are not
-- available before semantic validation, so every owned Primitive of the
-- required type is considered. Adding facts can only add dependencies. Exact
-- sufficiency is decided later against the same rule registry.
macroScopeDependencies ::
     MacroFactIndex node edge -> MacroClaim node -> [MacroDependency edge]
macroScopeDependencies index claim =
  [ MacroDependency edgeOccurrence
  | (edgeOccurrence, edge) <- indexedMacroEdges index
  , any (matchesPremise index claim edge) premises
  ]
  where
    premises =
      concatMap
        (NonEmpty.toList . alternativePremises)
        (NonEmpty.toList (ruleAlternatives (claimRule claim)))

claimRule :: MacroClaim node -> MacroEvidenceRule
claimRule (RegisteredMacroClaim _ relation _) = registeredMacroRule relation

matchesPremise ::
     MacroFactIndex node edge
  -> MacroClaim node
  -> RawEdge
  -> MacroPremise
  -> Bool
matchesPremise index claim edge premise =
  relationPatternMatches (premiseRelation premise) edge
    && rawEdgeFrom edge
         `elem` selectorCandidates index claim (premiseSource premise)
    && rawEdgeTo edge
         `elem` selectorCandidates index claim (premiseTarget premise)

selectorCandidates ::
     MacroFactIndex node edge
  -> MacroClaim node
  -> MacroNodeSelector
  -> [RawNodeId]
selectorCandidates index claim selector =
  case selector of
    ClaimContext side -> [claimContextId side claim]
    OwnedPrimitive side primitive _ ->
      [ identifier
      | (_, RawPrimitiveNode identifier owner actual) <- indexedMacroNodes index
      , owner == claimContextId side claim
      , actual == primitive
      ]
    OwnedPerformanceDimension side _ ->
      [ identifier
      | (_, RawStructuringNode identifier owner PerformanceDimension) <-
          indexedMacroNodes index
      , owner == claimContextId side claim
      ]
    ConstituentAnchor side ->
      [ identifier
      | (_, RawAnchorNode identifier _) <- indexedMacroNodes index
      , (_, edge) <- indexedMacroEdges index
      , rawEdgeFrom edge == claimContextId side claim
      , rawEdgeTo edge == identifier
      , relationPatternMatches
          (AnchorRelationFamilyPattern ConstitutedByAnchorFamily)
          edge
      ]

claimContextId :: ClaimSide -> MacroClaim node -> RawNodeId
claimContextId side (RegisteredMacroClaim source _ target) =
  case side of
    ClaimSource -> contextIdentifier source
    ClaimTarget -> contextIdentifier target
  where
    contextIdentifier (MacroContextRef _ identifier _) = identifier

relationPatternMatches :: MacroRelationPattern -> RawEdge -> Bool
relationPatternMatches pattern' edge =
  rawEdgeRelation edge `elem` relationPatternNames pattern'

relationPatternNames :: MacroRelationPattern -> [RelationName]
relationPatternNames pattern' =
  case pattern' of
    ExactRelation code -> [relationNameOf (reifyRelation code)]
    AnchorRelationFamilyPattern family ->
      stableNames
        [ relationNameOf (reifyRelation (AnchorRelation family anchor))
        | anchor <- [minBound .. maxBound]
        ]

stableNames :: Eq value => [value] -> [value]
stableNames = foldr add []
  where
    add value values
      | value `elem` values = values
      | otherwise = value : values
