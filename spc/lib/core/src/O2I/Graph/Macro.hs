{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}

-- | Typed macro-claim reification and conservative premise discovery.
--
-- This module interprets persisted facts through the canonical
-- 'MacroEvidenceRule' registry. Storage and deterministic lookup mechanics
-- remain isolated in the Cabal-private "O2I.Graph.Macro.Index" module.
module O2I.Graph.Macro
  ( MacroFactIndex
  , buildMacroFactIndex
  , MacroClaim
  , macroClaims
  , macroClaimsFor
  , macroClaimLookupWork
  , macroClaimExists
  , macroClaimConclusion
  , MacroEvidenceRule
  , macroEvidenceRules
  , macroEvidenceRuleConclusion
  , MacroDependency
  , macroDependencyEdge
  , macroScopeDependencies
  , MacroLookupWork
  , macroLookupNodeOccurrences
  , macroLookupEdgeBucketProbes
  , macroLookupEdgeOccurrences
  , macroLookupClaimOccurrences
  , macroScopeDependencyWork
  , macroPremiseEdgesBetween
  , macroSelectorCandidates
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import O2I.Graph.Macro.Index
import O2I.Graph.Raw
import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation hiding (MacroRelation)
import qualified O2I.Language.Relation as Relation

data MacroClaimKey =
  MacroClaimKey RawNodeId RelationCode RawNodeId
  deriving (Eq, Ord)

-- | Opaque occurrence-preserving index of persisted facts and typed claims.
--
-- Fact buckets retain source order and occurrence identity. Typed claims are
-- reified once from the same immutable fact index.
data MacroFactIndex node edge = MacroFactIndex
  { indexedFacts :: FactIndex node edge
  , indexedClaimsInOrder :: [(edge, MacroClaim node)]
  , indexedClaimsByKey :: Map MacroClaimKey [(edge, MacroClaim node)]
  }

-- | Index persisted format-neutral facts without validating or normalizing
-- them.
buildMacroFactIndex ::
     [(node, RawNode)] -> [(edge, RawEdge)] -> MacroFactIndex node edge
buildMacroFactIndex nodes edges =
  MacroFactIndex
    { indexedFacts = facts
    , indexedClaimsInOrder = claims
    , indexedClaimsByKey = claimsByKey
    }
  where
    facts = buildFactIndex nodes edges
    claims = concatMap (claimsForEdge facts) (orderedEdgeFacts facts)
    claimsByKey =
      Map.map
        reverse
        (Map.fromListWith
           (++)
           [ (claimKey claim, [(occurrence, claim)])
           | (occurrence, claim) <- claims
           ])

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
macroClaims = indexedClaimsInOrder

-- | Select occurrence-level claims for one exact macrorelation conclusion.
macroClaimsFor ::
     MacroFactIndex node edge
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> [(edge, MacroClaim node)]
macroClaimsFor index source conclusion target =
  lookupValues (claimLookup index source conclusion target)

-- | Test whether an exact typed macrorelation claim occurs in the index.
macroClaimExists :: MacroFactIndex node edge -> MacroClaim node -> Bool
macroClaimExists index claim =
  not
    (null
       (macroClaimsFor
          index
          (claimContextId ClaimSource claim)
          (macroClaimConclusion claim)
          (claimContextId ClaimTarget claim)))

claimLookup ::
     MacroFactIndex node edge
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> IndexedLookup (edge, MacroClaim node)
claimLookup index source conclusion target =
  claimBucketLookup
    (Map.findWithDefault
       []
       (MacroClaimKey source conclusion target)
       (indexedClaimsByKey index))

-- | Deterministic addressed work for one exact claim lookup.
--
-- This function is available only from the Cabal-private module boundary and
-- supports structural performance contracts without entering the public API.
macroClaimLookupWork ::
     MacroFactIndex node edge
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> MacroLookupWork
macroClaimLookupWork index source conclusion target =
  lookupWork (claimLookup index source conclusion target)

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

claimsForEdge ::
     FactIndex node edge
  -> OccurrenceFact edge RawEdge
  -> [(edge, MacroClaim node)]
claimsForEdge facts edgeFact =
  concatMap claimsForRelation (registeredMacroRelations (rawEdgeRelation edge))
  where
    edge = factValue edgeFact
    claimsForRelation (SomeMacroRelation relation) =
      [ ( factOccurrence edgeFact
        , RegisteredMacroClaim
            (MacroContextRef
               (factOccurrence fromFact)
               (rawEdgeFrom edge)
               (registeredMacroFrom relation))
            relation
            (MacroContextRef
               (factOccurrence toFact)
               (rawEdgeTo edge)
               (registeredMacroTo relation)))
      | fromFact <-
          contextFactsFor
            facts
            (rawEdgeFrom edge)
            (contextValue (registeredMacroFrom relation))
      , toFact <-
          contextFactsFor
            facts
            (rawEdgeTo edge)
            (contextValue (registeredMacroTo relation))
      ]

claimKey :: MacroClaim node -> MacroClaimKey
claimKey claim =
  MacroClaimKey
    (claimContextId ClaimSource claim)
    (macroClaimConclusion claim)
    (claimContextId ClaimTarget claim)

-- | Discover every persisted premise relation that could substantiate a claim.
--
-- Discovery is conservative and monotone: Strategy-role refinements are not
-- available before semantic validation, so every owned Primitive of the
-- required type is considered. Adding facts can only add dependencies. Exact
-- sufficiency is decided later against the same rule registry.
macroScopeDependencies ::
     MacroFactIndex node edge -> MacroClaim node -> [MacroDependency edge]
macroScopeDependencies index claim = fst (scopeDependencySearch index claim)

-- | Deterministic addressed work for conservative premise discovery.
--
-- This function remains behind the Cabal-private module boundary.
macroScopeDependencyWork ::
     MacroFactIndex node edge -> MacroClaim node -> MacroLookupWork
macroScopeDependencyWork index claim = snd (scopeDependencySearch index claim)

scopeDependencySearch ::
     MacroFactIndex node edge
  -> MacroClaim node
  -> ([MacroDependency edge], MacroLookupWork)
scopeDependencySearch index claim =
  (map (MacroDependency . factOccurrence) orderedMatches, totalWork)
  where
    premises =
      concatMap
        (NonEmpty.toList . alternativePremises)
        (NonEmpty.toList (ruleAlternatives (claimRule claim)))
    searches = map (matchingPremiseFacts index claim) premises
    totalWork = foldMap lookupWork searches
    orderedMatches =
      Map.elems
        (Map.fromList
           [ (factOrdinal fact, fact)
           | search <- searches
           , fact <- lookupValues search
           ])

matchingPremiseFacts ::
     MacroFactIndex node edge
  -> MacroClaim node
  -> MacroPremise
  -> IndexedLookup (OccurrenceFact edge RawEdge)
matchingPremiseFacts index claim premise =
  IndexedLookup
    (lookupValues edgeLookup)
    (lookupWork edgeLookup <> lookupWork sourceLookup <> lookupWork targetLookup)
  where
    sourceLookup = selectorLookup index claim (premiseSource premise)
    targetLookup = selectorLookup index claim (premiseTarget premise)
    edgeLookup =
      premiseEdgeFactsBetween
        (indexedFacts index)
        (premiseRelation premise)
        (lookupValues sourceLookup)
        (lookupValues targetLookup)

-- | Select premise occurrences between addressed source and target IDs.
--
-- Endpoint buckets avoid scanning same-relation facts belonging to unrelated
-- claims. Results retain persisted order and occurrence multiplicity.
macroPremiseEdgesBetween ::
     MacroFactIndex node edge
  -> MacroRelationPattern
  -> [RawNodeId]
  -> [RawNodeId]
  -> [(edge, RawEdge)]
macroPremiseEdgesBetween index pattern' sources targets =
  [ (factOccurrence fact, factValue fact)
  | fact <-
      lookupValues
        (premiseEdgeFactsBetween (indexedFacts index) pattern' sources targets)
  ]

-- | Select conservative node IDs addressed by one rule selector.
--
-- Results retain occurrence multiplicity. Exact Strategy-role refinement is
-- applied only after semantic validation.
macroSelectorCandidates ::
     MacroFactIndex node edge
  -> MacroClaim node
  -> MacroNodeSelector
  -> [RawNodeId]
macroSelectorCandidates index claim selector =
  lookupValues (selectorLookup index claim selector)

selectorLookup ::
     MacroFactIndex node edge
  -> MacroClaim node
  -> MacroNodeSelector
  -> IndexedLookup RawNodeId
selectorLookup index claim selector =
  case selector of
    ClaimContext side -> IndexedLookup [claimContextId side claim] mempty
    OwnedPrimitive side primitive _ ->
      ownedPrimitiveIdentifiers
        (indexedFacts index)
        (claimContextId side claim)
        primitive
    OwnedPerformanceDimension side _ ->
      ownedStructuringIdentifiers
        (indexedFacts index)
        (claimContextId side claim)
        PerformanceDimension
    ConstituentAnchor side ->
      constituentAnchorIdentifiers
        (indexedFacts index)
        (claimContextId side claim)

claimRule :: MacroClaim node -> MacroEvidenceRule
claimRule (RegisteredMacroClaim _ relation _) = registeredMacroRule relation

claimContextId :: ClaimSide -> MacroClaim node -> RawNodeId
claimContextId side (RegisteredMacroClaim source _ target) =
  case side of
    ClaimSource -> contextIdentifier source
    ClaimTarget -> contextIdentifier target
  where
    contextIdentifier (MacroContextRef _ identifier _) = identifier
