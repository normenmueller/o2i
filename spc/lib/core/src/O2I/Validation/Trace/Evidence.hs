{-# LANGUAGE GADTs #-}

-- | Exact macro-evidence interpretation for semantically valid models.
--
-- One immutable context pairs a semantic model with its occurrence-preserving
-- fact index. Trace and collective validation reuse that context for every
-- exact witness query.
module O2I.Validation.Trace.Evidence
  ( MacroEvidenceWitness
  , MacroEvidenceContext
  , buildMacroEvidenceContext
  , macroEvidenceClaims
  , macroEvidenceWitnesses
  , macroEvidenceWitnessesIn
  , macroEvidenceWitnessesFor
  , macroEvidenceWitnessesForIn
  , witnessPremises
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import O2I.Graph.Macro
import O2I.Graph.Raw
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation
import O2I.Validation.Semantics.Context

-- | Opaque exact substantiation of one macrorelation through persisted edges.
newtype MacroEvidenceWitness = MacroEvidenceWitness
  { validatedWitnessPremises :: NonEmpty.NonEmpty RawEdge
  } deriving (Eq, Show)

-- | One exact semantic model paired with its immutable macro-fact index.
--
-- Construct once at an operation boundary and reuse for every claim lookup.
data MacroEvidenceContext = MacroEvidenceContext
  { macroEvidenceSemanticModel :: ContextSemantics
  , macroEvidenceFacts :: MacroFactIndex RawNodeId RawEdge
  }

-- | Build the exact macro-evidence lookup context for one semantic model.
buildMacroEvidenceContext :: ContextSemantics -> MacroEvidenceContext
buildMacroEvidenceContext semantic =
  MacroEvidenceContext
    semantic
    (buildMacroFactIndex
       [(someNodeId node, rawNodeFromSome node) | node <- graphNodes graph]
       [(raw, raw) | edge <- graphEdges graph, let raw = rawEdgeFromSome edge])
  where
    graph = contextGraph semantic

-- | Enumerate the persisted typed macrorelation claims in source order.
macroEvidenceClaims :: MacroEvidenceContext -> [(RawEdge, MacroClaim RawNodeId)]
macroEvidenceClaims = macroClaims . macroEvidenceFacts

-- | Interpret the canonical macro rule exactly against one semantic model.
--
-- Strategy-role constraints are resolved only from validated formulations.
-- Repeated premise selectors bind the same graph node, so compound rules such
-- as @Strategy --frames--> Measure@ cannot combine unrelated dimensions.
macroEvidenceWitnesses ::
     ContextSemantics -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
macroEvidenceWitnesses semantic =
  macroEvidenceWitnessesIn (buildMacroEvidenceContext semantic)

-- | Interpret one canonical macro rule through an existing indexed context.
macroEvidenceWitnessesIn ::
     MacroEvidenceContext -> MacroClaim RawNodeId -> [MacroEvidenceWitness]
macroEvidenceWitnessesIn evidence claim
  | macroClaimExists (macroEvidenceFacts evidence) claim =
    concatMap witnessesForAlternative alternatives
  | otherwise = []
  where
    alternatives = NonEmpty.toList (ruleAlternatives (claimEvidenceRule claim))
    witnessesForAlternative (PremiseAlternative premises) =
      [ MacroEvidenceWitness (fmap matchedPremiseEdge matches)
      | matches <-
          sequenceA (fmap (exactPremiseMatches evidence claim) premises)
      , consistentBindings
          (concatMap matchedPremiseBindings (NonEmpty.toList matches))
      ]

-- | Select exact witnesses for one registered context macrorelation claim.
macroEvidenceWitnessesFor ::
     ContextSemantics
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> [MacroEvidenceWitness]
macroEvidenceWitnessesFor semantic source conclusion target =
  macroEvidenceWitnessesForIn
    (buildMacroEvidenceContext semantic)
    source
    conclusion
    target

-- | Select exact witnesses through an existing indexed evidence context.
macroEvidenceWitnessesForIn ::
     MacroEvidenceContext
  -> RawNodeId
  -> RelationCode
  -> RawNodeId
  -> [MacroEvidenceWitness]
macroEvidenceWitnessesForIn evidence source conclusion target =
  concat
    [ macroEvidenceWitnessesIn evidence claim
    | (_, claim) <-
        macroClaimsFor (macroEvidenceFacts evidence) source conclusion target
    ]

-- | Enumerate the non-empty persisted premise set of an exact witness.
witnessPremises :: MacroEvidenceWitness -> NonEmpty.NonEmpty RawEdge
witnessPremises = validatedWitnessPremises

data MatchedPremise = MatchedPremise
  { matchedPremiseEdge :: RawEdge
  , matchedPremiseBindings :: [(MacroNodeSelector, RawNodeId)]
  }

exactPremiseMatches ::
     MacroEvidenceContext
  -> MacroClaim RawNodeId
  -> MacroPremise
  -> [MatchedPremise]
exactPremiseMatches evidence claim premise =
  [ MatchedPremise
    edge
    [ (premiseSource premise, rawEdgeFrom edge)
    , (premiseTarget premise, rawEdgeTo edge)
    ]
  | (edge, _) <-
      macroPremiseEdgesBetween
        (macroEvidenceFacts evidence)
        (premiseRelation premise)
        sourceCandidates
        targetCandidates
  ]
  where
    sourceCandidates =
      exactSelectorCandidates evidence claim (premiseSource premise)
    targetCandidates =
      exactSelectorCandidates evidence claim (premiseTarget premise)

exactSelectorCandidates ::
     MacroEvidenceContext
  -> MacroClaim RawNodeId
  -> MacroNodeSelector
  -> [RawNodeId]
exactSelectorCandidates evidence claim selector =
  case selector of
    ClaimContext side -> [claimContextIdentifier side claim]
    OwnedPrimitive side _primitive requiredRole ->
      case requiredRole of
        Nothing -> primitiveCandidates
        Just role ->
          filter
            (`Set.member` strategyRoleReferences semantic owner role)
            primitiveCandidates
      where owner = claimContextIdentifier side claim
            primitiveCandidates =
              macroSelectorCandidates
                (macroEvidenceFacts evidence)
                claim
                selector
    OwnedPerformanceDimension side roleCode ->
      [ identifier
      | identifier <-
          macroSelectorCandidates (macroEvidenceFacts evidence) claim selector
      , roleMatches ownerContext roleCode
      ]
      where ownerContext = claimContextValue side claim
    ConstituentAnchor _side ->
      macroSelectorCandidates (macroEvidenceFacts evidence) claim selector
  where
    semantic = macroEvidenceSemanticModel evidence

roleMatches :: Context -> PerformanceDimensionRoleCode -> Bool
roleMatches context code =
  case lookupPerformanceDimensionRole context of
    Just role -> performanceDimensionRoleCodeOf role == code
    Nothing -> False

strategyRoleReferences ::
     ContextSemantics -> RawNodeId -> StrategyPrimitiveRole -> Set.Set RawNodeId
strategyRoleReferences semantic strategy role =
  case Map.lookup strategy (contextStrategyFormulations semantic) of
    Nothing -> Set.empty
    Just formulation ->
      let raw = strategyFormulationData formulation
       in Set.fromList
            (case role of
               DiagnosisRole -> [rawFormulationDiagnosis raw]
               IntentRole -> [rawFormulationIntent raw]
               GuidingPolicyRole -> [rawFormulationGuidingPolicy raw]
               CoherentActionRole -> NonEmpty.toList (rawFormulationActions raw)
               StrategicKeyResultRole ->
                 NonEmpty.toList (rawFormulationKeyResults raw))

claimEvidenceRule :: MacroClaim node -> MacroEvidenceRule
claimEvidenceRule (RegisteredMacroClaim _ relation _) =
  registeredMacroRule relation

claimContextIdentifier :: ClaimSide -> MacroClaim node -> RawNodeId
claimContextIdentifier side (RegisteredMacroClaim source _ target) =
  case side of
    ClaimSource -> identifier source
    ClaimTarget -> identifier target
  where
    identifier (MacroContextRef _ rawIdentifier _) = rawIdentifier

claimContextValue :: ClaimSide -> MacroClaim node -> Context
claimContextValue side (RegisteredMacroClaim source _ target) =
  case side of
    ClaimSource -> value source
    ClaimTarget -> value target
  where
    value (MacroContextRef _ _ context) = contextValue context

consistentBindings :: [(MacroNodeSelector, RawNodeId)] -> Bool
consistentBindings = go Map.empty
  where
    go _ [] = True
    go bindings ((selector, identifier):rest) =
      case Map.lookup selector bindings of
        Nothing -> go (Map.insert selector identifier bindings) rest
        Just existing -> existing == identifier && go bindings rest

rawNodeFromSome :: SomeNode -> RawNode
rawNodeFromSome (SomeNode node) =
  case node of
    ContextNode identifier context ->
      RawContextNode (unNodeId identifier) (contextValue context)
    PrimitiveNode identifier owner _ primitive _ ->
      RawPrimitiveNode
        (unNodeId identifier)
        (unNodeId owner)
        (primitiveValue primitive)
    PerformanceDimensionNode identifier owner _ ->
      RawStructuringNode
        (unNodeId identifier)
        (unNodeId owner)
        PerformanceDimension
    AnchorNode identifier anchor ->
      RawAnchorNode (unNodeId identifier) (anchorValue anchor)

rawEdgeFromSome :: SomeEdge -> RawEdge
rawEdgeFromSome edge =
  RawEdge
    { rawEdgeFrom = someEdgeFrom edge
    , rawEdgeRelation = someEdgeRelation edge
    , rawEdgeTo = someEdgeTo edge
    }
