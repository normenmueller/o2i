{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}

-- | One-time preparation of exact macro-evidence execution.
--
-- Closed endpoint-typed language rules are instantiated once for every
-- persisted macro claim. Model-wide fact, relation, owner, role, and anchor
-- indices are built once and retained by the resulting opaque context.
module O2I.Validation.MacroEvidence.Prepare
  ( PreparedMacroEvidence
  , CompiledMacroAlternative
  , compiledMacroPlan
  , prepareMacroEvidence
  , preparedContextSemantics
  , preparedMacroFacts
  , preparedRelationalIndex
  , preparedOwnedPrimitiveDomain
  , preparedStrategyRoleDomain
  , preparedPerformanceDimensionDomain
  , preparedSituationAnchorDomain
  , preparedMacroClaims
  , preparedClaimAlternatives
  , preparedMacroWork
  ) where

import qualified Data.Dependent.Map as DMap
import Data.Dependent.Map (DMap)
import Data.GADT.Compare
import Data.List (foldl')
import qualified Data.List.NonEmpty as NonEmpty
import Data.List.NonEmpty (NonEmpty)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Type.Equality ((:~:)(Refl))
import O2I.Graph.Macro
import O2I.Graph.Raw
import O2I.Graph.Typed
import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation
import O2I.Validation.MacroEvidence.Types
import O2I.Validation.Relational.Index
import O2I.Validation.Relational.Types
import O2I.Validation.Semantics.Context

-- | Private address of one model-wide domain with its node kind preserved.
data DomainAddress (kind :: NodeKind) where
  OwnedAddress
    :: RawNodeId
    -> SContext context
    -> SPrimitive primitive
    -> DomainAddress ('PrimitiveKind context primitive)
  StrategyRoleAddress
    :: RawNodeId
    -> TypedStrategyRole primitive
    -> DomainAddress ('PrimitiveKind 'Strategy primitive)
  PerformanceDimensionAddress
    :: RawNodeId
    -> PerformanceDimensionRole context member
    -> DomainAddress ('StructuringKind context 'PerformanceDimension)
  AnchorAddress
    :: RawNodeId
    -> SSituationAnchor anchor
    -> DomainAddress ('AnchorKind anchor)

instance GEq DomainAddress where
  geq left right =
    case compareDomainAddress left right of
      GEQ -> Just Refl
      GLT -> Nothing
      GGT -> Nothing

instance GCompare DomainAddress where
  gcompare = compareDomainAddress

-- | Model-wide addressed node domains prepared by one bounded scan.
newtype MacroDomainIndex =
  MacroDomainIndex (DMap DomainAddress Domain)

data FactPreparation = FactPreparation
  { preparedNodeFacts :: [(RawNodeId, RawNode)]
  , preparedEdgeFacts :: [(RawEdge, RawEdge)]
  , factNodesRead :: !Int
  , factEdgesRead :: !Int
  }

data DomainPreparation = DomainPreparation
  { preparedDomains :: !MacroDomainIndex
  , domainNodesRead :: !Int
  , domainEdgesRead :: !Int
  , domainStrategyFormulationsRead :: !Int
  , domainPreparationOperations :: !PreparationOperations
  }

data RegistryPreparation = RegistryPreparation
  { preparedRegistry :: !CompiledMacroRegistry
  , registryPreparationOperations :: !PreparationOperations
  }

data DomainInsertionResult kind =
  DomainInsertionResult !(Domain kind) !MacroDomainIndex !PreparationOperations

-- | One connected executable alternative in registry order.
data CompiledMacroAlternative = CompiledMacroAlternative
  { storedCompiledMacroPlan :: !(CompiledPlan (NonEmpty ProjectedPremise))
  }

data AlternativePreparationResult =
  AlternativePreparationResult !CompiledMacroAlternative !PreparationOperations

data PreparationOperations = PreparationOperations
  { operationDomainLookups :: !Int
  , operationDomainInsertions :: !Int
  , operationClaimsRead :: !Int
  , operationRegistryInsertions :: !Int
  , operationPlansInstantiated :: !Int
  }

instance Semigroup PreparationOperations where
  left <> right =
    PreparationOperations
      { operationDomainLookups =
          operationDomainLookups left + operationDomainLookups right
      , operationDomainInsertions =
          operationDomainInsertions left + operationDomainInsertions right
      , operationClaimsRead =
          operationClaimsRead left + operationClaimsRead right
      , operationRegistryInsertions =
          operationRegistryInsertions left + operationRegistryInsertions right
      , operationPlansInstantiated =
          operationPlansInstantiated left + operationPlansInstantiated right
      }

instance Monoid PreparationOperations where
  mempty = PreparationOperations 0 0 0 0 0

domainLookupOperation :: PreparationOperations
domainLookupOperation = PreparationOperations 1 0 0 0 0

domainInsertionOperation :: PreparationOperations
domainInsertionOperation = PreparationOperations 0 1 0 0 0

claimReadOperation :: PreparationOperations
claimReadOperation = PreparationOperations 0 0 1 0 0

registryInsertionOperation :: PreparationOperations
registryInsertionOperation = PreparationOperations 0 0 0 1 0

planInstantiationOperation :: PreparationOperations
planInstantiationOperation = PreparationOperations 0 0 0 0 1

data ClaimKey =
  ClaimKey RawNodeId RelationCode RawNodeId
  deriving (Eq, Ord)

-- | Complete model-specific registry of persisted macro claims.
newtype CompiledMacroRegistry =
  CompiledMacroRegistry (Map ClaimKey (NonEmpty CompiledMacroAlternative))

-- | Immutable exact macro-evidence execution context for one semantic model.
data PreparedMacroEvidence = PreparedMacroEvidence
  { storedContextSemantics :: ContextSemantics
  , storedMacroFacts :: MacroFactIndex RawNodeId RawEdge
  , storedRelationalIndex :: RelationalIndex
  , _storedMacroDomains :: MacroDomainIndex
  , storedMacroRegistry :: CompiledMacroRegistry
  , storedPreparationWork :: MacroPreparationWork
  }

-- | Prepare every model-wide macro-evidence structure exactly once.
prepareMacroEvidence :: ContextSemantics -> PreparedMacroEvidence
prepareMacroEvidence semantic =
  PreparedMacroEvidence
    { storedContextSemantics = semantic
    , storedMacroFacts = facts
    , storedRelationalIndex = relations
    , _storedMacroDomains = domains
    , storedMacroRegistry = registry
    , storedPreparationWork =
        MacroPreparationWork
          { preparationFactNodesRead = factNodesRead factPreparation
          , preparationFactEdgesRead = factEdgesRead factPreparation
          , preparationRelationalIndexWork = indexBuildWork relations
          , preparationDomainNodesRead = domainNodesRead domainPreparation
          , preparationDomainEdgesRead = domainEdgesRead domainPreparation
          , preparationStrategyFormulationsRead =
              domainStrategyFormulationsRead domainPreparation
          , preparationDomainLookups =
              operationDomainLookups preparationOperations
          , preparationDomainInsertions =
              operationDomainInsertions preparationOperations
          , preparationClaimsRead = operationClaimsRead preparationOperations
          , preparationRegistryInsertions =
              operationRegistryInsertions preparationOperations
          , preparationPlansInstantiated =
              operationPlansInstantiated preparationOperations
          }
    }
  where
    graph = contextGraph semantic
    nodes = graphNodes graph
    edges = graphEdges graph
    factPreparation = prepareFacts nodes edges
    facts =
      buildMacroFactIndex
        (preparedNodeFacts factPreparation)
        (preparedEdgeFacts factPreparation)
    relations = buildRelationalIndex graph
    domainPreparation = buildMacroDomainIndex semantic nodes edges
    domains = preparedDomains domainPreparation
    claims = map snd (macroClaims facts)
    registryPreparation = compileRegistry domains claims
    registry = preparedRegistry registryPreparation
    preparationOperations =
      domainPreparationOperations domainPreparation
        <> registryPreparationOperations registryPreparation

-- | Recover the exact Context semantics used during preparation.
preparedContextSemantics :: PreparedMacroEvidence -> ContextSemantics
preparedContextSemantics = storedContextSemantics

-- | Recover the conservative raw occurrence index prepared for the model.
preparedMacroFacts :: PreparedMacroEvidence -> MacroFactIndex RawNodeId RawEdge
preparedMacroFacts = storedMacroFacts

-- | Recover the exact typed relation index prepared for the model.
preparedRelationalIndex :: PreparedMacroEvidence -> RelationalIndex
preparedRelationalIndex = storedRelationalIndex

-- | Resolve one exact owner-, Context-, and Primitive-indexed domain.
preparedOwnedPrimitiveDomain ::
     PreparedMacroEvidence
  -> NodeId ('ContextKind context)
  -> SContext context
  -> SPrimitive primitive
  -> Domain ('PrimitiveKind context primitive)
preparedOwnedPrimitiveDomain prepared owner context primitive =
  lookupPreparedDomain
    prepared
    (OwnedAddress (unNodeId owner) context primitive)

-- | Resolve one exact Strategy formulation-role domain.
preparedStrategyRoleDomain ::
     PreparedMacroEvidence
  -> NodeId ('ContextKind 'Strategy)
  -> TypedStrategyRole primitive
  -> Domain ('PrimitiveKind 'Strategy primitive)
preparedStrategyRoleDomain prepared strategy role =
  lookupPreparedDomain prepared (StrategyRoleAddress (unNodeId strategy) role)

-- | Resolve one exact PerformanceDimension role domain.
preparedPerformanceDimensionDomain ::
     PreparedMacroEvidence
  -> NodeId ('ContextKind context)
  -> PerformanceDimensionRole context member
  -> Domain ('StructuringKind context 'PerformanceDimension)
preparedPerformanceDimensionDomain prepared owner role =
  lookupPreparedDomain
    prepared
    (PerformanceDimensionAddress (unNodeId owner) role)

-- | Resolve one exact Situation constituent-anchor domain.
preparedSituationAnchorDomain ::
     PreparedMacroEvidence
  -> NodeId ('ContextKind 'Situation)
  -> SSituationAnchor anchor
  -> Domain ('AnchorKind anchor)
preparedSituationAnchorDomain prepared situation anchor =
  lookupPreparedDomain prepared (AnchorAddress (unNodeId situation) anchor)

-- | Enumerate persisted typed macro claims in canonical graph order.
preparedMacroClaims ::
     PreparedMacroEvidence -> [(RawEdge, MacroClaim RawNodeId)]
preparedMacroClaims = macroClaims . storedMacroFacts

-- | Resolve the precompiled alternatives of one exact persisted claim.
preparedClaimAlternatives ::
     PreparedMacroEvidence
  -> MacroClaim RawNodeId
  -> Maybe (NonEmpty CompiledMacroAlternative)
preparedClaimAlternatives prepared claim = Map.lookup (claimKey claim) entries
  where
    CompiledMacroRegistry entries = storedMacroRegistry prepared

-- | Read exact work performed by the one-time preparation.
preparedMacroWork :: PreparedMacroEvidence -> MacroPreparationWork
preparedMacroWork = storedPreparationWork

-- | Recover the private executable plan of one prepared alternative.
compiledMacroPlan ::
     CompiledMacroAlternative -> CompiledPlan (NonEmpty ProjectedPremise)
compiledMacroPlan = storedCompiledMacroPlan

compileRegistry ::
     MacroDomainIndex -> [MacroClaim RawNodeId] -> RegistryPreparation
compileRegistry domains = foldl' compileRegistryClaim emptyRegistryPreparation
  where
    compileRegistryClaim preparation claim =
      let (alternatives, claimOperations) = compileClaim domains claim
          CompiledMacroRegistry entries = preparedRegistry preparation
       in preparation
            { preparedRegistry =
                CompiledMacroRegistry
                  (Map.insert (claimKey claim) alternatives entries)
            , registryPreparationOperations =
                registryPreparationOperations preparation
                  <> claimReadOperation
                  <> claimOperations
                  <> registryInsertionOperation
            }

compileClaim ::
     MacroDomainIndex
  -> MacroClaim RawNodeId
  -> (NonEmpty CompiledMacroAlternative, PreparationOperations)
compileClaim domains (RegisteredMacroClaim source relation target) =
  compileAlternatives (typedRuleAlternatives (registeredMacroRule relation))
  where
    compileAlternative alternative =
      case prepareCompiledAlternative
             (instantiateAlternative
                alternative
                (selectorDomain domains source target)) of
        AlternativePreparationResult compiled operations ->
          (compiled, operations)
    compileAlternatives (first NonEmpty.:| rest) =
      let (firstCompiled, firstOperations) = compileAlternative first
          (compiledRest, restOperations) =
            foldl'
              (\(compiled, operations) alternative ->
                 let (candidate, candidateOperations) =
                       compileAlternative alternative
                  in (candidate : compiled, operations <> candidateOperations))
              ([], mempty)
              rest
       in ( firstCompiled NonEmpty.:| reverse compiledRest
          , firstOperations <> restOperations)

emptyRegistryPreparation :: RegistryPreparation
emptyRegistryPreparation =
  RegistryPreparation
    { preparedRegistry = CompiledMacroRegistry Map.empty
    , registryPreparationOperations = mempty
    }

prepareCompiledAlternative ::
     (CompiledPlan (NonEmpty ProjectedPremise), PreparationOperations)
  -> AlternativePreparationResult
prepareCompiledAlternative (plan, resolverOperations) =
  AlternativePreparationResult
    (CompiledMacroAlternative {storedCompiledMacroPlan = plan})
    (resolverOperations <> planInstantiationOperation)

selectorDomain ::
     MacroDomainIndex
  -> MacroContextRef node from
  -> MacroContextRef node to
  -> TypedMacroSelector from to kind
  -> (Domain kind, PreparationOperations)
selectorDomain domains source target selector =
  case selector of
    SourceContextSelector _ ->
      (singletonDomain (mkNodeId (macroContextIdentifier source)), mempty)
    TargetContextSelector _ ->
      (singletonDomain (mkNodeId (macroContextIdentifier target)), mempty)
    SourcePrimitiveSelector context primitive ->
      addressedDomain
        domains
        (OwnedAddress (macroContextIdentifier source) context primitive)
    TargetPrimitiveSelector context primitive ->
      addressedDomain
        domains
        (OwnedAddress (macroContextIdentifier target) context primitive)
    SourceStrategyRoleSelector role ->
      addressedDomain
        domains
        (StrategyRoleAddress (macroContextIdentifier source) role)
    TargetStrategyRoleSelector role ->
      addressedDomain
        domains
        (StrategyRoleAddress (macroContextIdentifier target) role)
    SourcePerformanceDimensionSelector role ->
      addressedDomain
        domains
        (PerformanceDimensionAddress (macroContextIdentifier source) role)
    TargetPerformanceDimensionSelector role ->
      addressedDomain
        domains
        (PerformanceDimensionAddress (macroContextIdentifier target) role)
    SourceSituationAnchorSelector anchor ->
      addressedDomain
        domains
        (AnchorAddress (macroContextIdentifier source) anchor)
    TargetSituationAnchorSelector anchor ->
      addressedDomain
        domains
        (AnchorAddress (macroContextIdentifier target) anchor)

addressedDomain ::
     MacroDomainIndex
  -> DomainAddress kind
  -> (Domain kind, PreparationOperations)
addressedDomain (MacroDomainIndex domains) address =
  (domain, domainLookupOperation)
  where
    domain =
      case DMap.lookup address domains of
        Nothing -> emptyDomain
        Just existing -> existing

lookupPreparedDomain ::
     PreparedMacroEvidence -> DomainAddress kind -> Domain kind
lookupPreparedDomain prepared address =
  case DMap.lookup address domains of
    Nothing -> emptyDomain
    Just existing -> existing
  where
    MacroDomainIndex domains = _storedMacroDomains prepared

prepareFacts :: [SomeNode] -> [SomeEdge] -> FactPreparation
prepareFacts nodes edges =
  FactPreparation
    { preparedNodeFacts = reverse reversedNodeFacts
    , preparedEdgeFacts = reverse reversedEdgeFacts
    , factNodesRead = nodeReads
    , factEdgesRead = edgeReads
    }
  where
    (reversedNodeFacts, nodeReads) =
      foldl'
        (\(facts, readCount) node ->
           ((someNodeId node, rawNodeFromSome node) : facts, readCount + 1))
        ([], 0)
        nodes
    (reversedEdgeFacts, edgeReads) =
      foldl'
        (\(facts, readCount) edge ->
           let raw = rawEdgeFromSome edge
            in ((raw, raw) : facts, readCount + 1))
        ([], 0)
        edges

buildMacroDomainIndex ::
     ContextSemantics -> [SomeNode] -> [SomeEdge] -> DomainPreparation
buildMacroDomainIndex semantic nodes edges = formulationPreparation
  where
    ownedPreparation =
      foldl'
        (\preparation node ->
           let inserted = insertOwnedNode node preparation
            in inserted {domainNodesRead = domainNodesRead inserted + 1})
        emptyDomainPreparation
        nodes
    anchorPreparation =
      foldl'
        (\preparation edge ->
           let inserted = insertConstitutingAnchor edge preparation
            in inserted {domainEdgesRead = domainEdgesRead inserted + 1})
        ownedPreparation
        edges
    formulations = Map.toList (contextStrategyFormulations semantic)
    formulationPreparation =
      foldl'
        (\preparation formulation ->
           let inserted = insertStrategyFormulation formulation preparation
            in inserted
                 { domainStrategyFormulationsRead =
                     domainStrategyFormulationsRead inserted + 1
                 })
        anchorPreparation
        formulations

emptyDomainPreparation :: DomainPreparation
emptyDomainPreparation =
  DomainPreparation
    { preparedDomains = MacroDomainIndex DMap.empty
    , domainNodesRead = 0
    , domainEdgesRead = 0
    , domainStrategyFormulationsRead = 0
    , domainPreparationOperations = mempty
    }

insertOwnedNode :: SomeNode -> DomainPreparation -> DomainPreparation
insertOwnedNode (SomeNode node) preparation =
  case node of
    PrimitiveNode identifier owner context primitive _ ->
      insertAddress
        (OwnedAddress (unNodeId owner) context primitive)
        identifier
        preparation
    PerformanceDimensionNode identifier owner role ->
      insertAddress
        (PerformanceDimensionAddress (unNodeId owner) role)
        identifier
        preparation
    ContextNode _ _ -> preparation
    AnchorNode _ _ -> preparation

insertConstitutingAnchor :: SomeEdge -> DomainPreparation -> DomainPreparation
insertConstitutingAnchor (SomeEdge edge) preparation =
  case (relationCode specification, relationTo specification) of
    (AnchorRelation ConstitutedByAnchorFamily _, SAnchorKind anchor) ->
      insertAddress
        (AnchorAddress (unNodeId (edgeFrom edge)) anchor)
        (edgeTo edge)
        preparation
    _ -> preparation
  where
    specification = relationSpec (edgeRelation edge)

insertStrategyFormulation ::
     (RawNodeId, StrategyFormulation) -> DomainPreparation -> DomainPreparation
insertStrategyFormulation (strategy, formulation) preparation =
  foldl'
    (\current keyResult ->
       insertAddress
         (StrategyRoleAddress strategy StrategyKeyResultRole)
         (mkNodeId keyResult)
         current)
    actionPreparation
    (NonEmpty.toList (rawFormulationKeyResults raw))
  where
    raw = strategyFormulationData formulation
    diagnosisPreparation =
      insertAddress
        (StrategyRoleAddress strategy StrategyDiagnosisRole)
        (mkNodeId (rawFormulationDiagnosis raw))
        preparation
    intentPreparation =
      insertAddress
        (StrategyRoleAddress strategy StrategyIntentRole)
        (mkNodeId (rawFormulationIntent raw))
        diagnosisPreparation
    policyPreparation =
      insertAddress
        (StrategyRoleAddress strategy StrategyGuidingPolicyRole)
        (mkNodeId (rawFormulationGuidingPolicy raw))
        intentPreparation
    actionPreparation =
      foldl'
        (\current action ->
           insertAddress
             (StrategyRoleAddress strategy StrategyCoherentActionRole)
             (mkNodeId action)
             current)
        policyPreparation
        (NonEmpty.toList (rawFormulationActions raw))

insertAddress ::
     DomainAddress kind -> NodeId kind -> DomainPreparation -> DomainPreparation
insertAddress address identifier preparation =
  case prepareDomainInsertion address identifier (preparedDomains preparation) of
    DomainInsertionResult _ updatedDomains operations ->
      preparation
        { preparedDomains = updatedDomains
        , domainPreparationOperations =
            domainPreparationOperations preparation <> operations
        }

prepareDomainInsertion ::
     DomainAddress kind
  -> NodeId kind
  -> MacroDomainIndex
  -> DomainInsertionResult kind
prepareDomainInsertion address identifier (MacroDomainIndex domains) =
  DomainInsertionResult
    updatedDomain
    (MacroDomainIndex (DMap.insert address updatedDomain domains))
    (domainLookupOperation <> domainInsertionOperation)
  where
    existing =
      case DMap.lookup address domains of
        Nothing -> emptyDomain
        Just domain -> domain
    updatedDomain = domainInsert identifier existing

compareDomainAddress ::
     DomainAddress left -> DomainAddress right -> GOrdering left right
compareDomainAddress left right =
  case (left, right) of
    (OwnedAddress leftOwner leftContext leftPrimitive, OwnedAddress rightOwner rightContext rightPrimitive) ->
      case compare leftOwner rightOwner of
        LT -> GLT
        GT -> GGT
        EQ ->
          comparePrimitiveKind
            leftContext
            leftPrimitive
            rightContext
            rightPrimitive
    (OwnedAddress _ _ _, _) -> GLT
    (_, OwnedAddress _ _ _) -> GGT
    (StrategyRoleAddress leftOwner leftRole, StrategyRoleAddress rightOwner rightRole) ->
      case compare leftOwner rightOwner of
        LT -> GLT
        GT -> GGT
        EQ -> compareTypedStrategyRole leftRole rightRole
    (StrategyRoleAddress _ _, _) -> GLT
    (_, StrategyRoleAddress _ _) -> GGT
    (PerformanceDimensionAddress leftOwner leftRole, PerformanceDimensionAddress rightOwner rightRole) ->
      case compare leftOwner rightOwner of
        LT -> GLT
        GT -> GGT
        EQ -> comparePerformanceDimensionRole leftRole rightRole
    (PerformanceDimensionAddress _ _, _) -> GLT
    (_, PerformanceDimensionAddress _ _) -> GGT
    (AnchorAddress leftOwner leftAnchor, AnchorAddress rightOwner rightAnchor) ->
      case compare leftOwner rightOwner of
        LT -> GLT
        GT -> GGT
        EQ -> compareSAnchor leftAnchor rightAnchor

compareSContext :: SContext left -> SContext right -> GOrdering left right
compareSContext SEthos SEthos = GEQ
compareSContext SEthos _ = GLT
compareSContext _ SEthos = GGT
compareSContext SMission SMission = GEQ
compareSContext SMission _ = GLT
compareSContext _ SMission = GGT
compareSContext SVision SVision = GEQ
compareSContext SVision _ = GLT
compareSContext _ SVision = GGT
compareSContext SStrategy SStrategy = GEQ
compareSContext SStrategy _ = GLT
compareSContext _ SStrategy = GGT
compareSContext SSituation SSituation = GEQ
compareSContext SSituation _ = GLT
compareSContext _ SSituation = GGT
compareSContext SNeed SNeed = GEQ
compareSContext SNeed _ = GLT
compareSContext _ SNeed = GGT
compareSContext SIntervention SIntervention = GEQ
compareSContext SIntervention _ = GLT
compareSContext _ SIntervention = GGT
compareSContext SMeasure SMeasure = GEQ

compareSPrimitive :: SPrimitive left -> SPrimitive right -> GOrdering left right
compareSPrimitive SPrinciple SPrinciple = GEQ
compareSPrimitive SPrinciple _ = GLT
compareSPrimitive _ SPrinciple = GGT
compareSPrimitive SDriver SDriver = GEQ
compareSPrimitive SDriver _ = GLT
compareSPrimitive _ SDriver = GGT
compareSPrimitive SObjective SObjective = GEQ
compareSPrimitive SObjective _ = GLT
compareSPrimitive _ SObjective = GGT
compareSPrimitive SKeyResult SKeyResult = GEQ
compareSPrimitive SKeyResult _ = GLT
compareSPrimitive _ SKeyResult = GGT
compareSPrimitive SKPI SKPI = GEQ
compareSPrimitive SKPI _ = GLT
compareSPrimitive _ SKPI = GGT
compareSPrimitive SAction SAction = GEQ

comparePrimitiveKind ::
     SContext leftContext
  -> SPrimitive leftPrimitive
  -> SContext rightContext
  -> SPrimitive rightPrimitive
  -> GOrdering
       ('PrimitiveKind leftContext leftPrimitive)
       ('PrimitiveKind rightContext rightPrimitive)
comparePrimitiveKind leftContext leftPrimitive rightContext rightPrimitive =
  case compareSContext leftContext rightContext of
    GLT -> GLT
    GGT -> GGT
    GEQ ->
      case compareSPrimitive leftPrimitive rightPrimitive of
        GLT -> GLT
        GGT -> GGT
        GEQ -> GEQ

compareTypedStrategyRole ::
     TypedStrategyRole left
  -> TypedStrategyRole right
  -> GOrdering ('PrimitiveKind 'Strategy left) ('PrimitiveKind 'Strategy right)
compareTypedStrategyRole StrategyDiagnosisRole StrategyDiagnosisRole = GEQ
compareTypedStrategyRole StrategyDiagnosisRole _ = GLT
compareTypedStrategyRole _ StrategyDiagnosisRole = GGT
compareTypedStrategyRole StrategyIntentRole StrategyIntentRole = GEQ
compareTypedStrategyRole StrategyIntentRole _ = GLT
compareTypedStrategyRole _ StrategyIntentRole = GGT
compareTypedStrategyRole StrategyGuidingPolicyRole StrategyGuidingPolicyRole =
  GEQ
compareTypedStrategyRole StrategyGuidingPolicyRole _ = GLT
compareTypedStrategyRole _ StrategyGuidingPolicyRole = GGT
compareTypedStrategyRole StrategyCoherentActionRole StrategyCoherentActionRole =
  GEQ
compareTypedStrategyRole StrategyCoherentActionRole _ = GLT
compareTypedStrategyRole _ StrategyCoherentActionRole = GGT
compareTypedStrategyRole StrategyKeyResultRole StrategyKeyResultRole = GEQ

comparePerformanceDimensionRole ::
     PerformanceDimensionRole leftContext leftMember
  -> PerformanceDimensionRole rightContext rightMember
  -> GOrdering
       ('StructuringKind leftContext 'PerformanceDimension)
       ('StructuringKind rightContext 'PerformanceDimension)
comparePerformanceDimensionRole StrategySuccessDimension StrategySuccessDimension =
  GEQ
comparePerformanceDimensionRole StrategySuccessDimension _ = GLT
comparePerformanceDimensionRole _ StrategySuccessDimension = GGT
comparePerformanceDimensionRole MeasureMeasurementDimension MeasureMeasurementDimension =
  GEQ

compareSAnchor ::
     SSituationAnchor left
  -> SSituationAnchor right
  -> GOrdering ('AnchorKind left) ('AnchorKind right)
compareSAnchor SBusinessCapability SBusinessCapability = GEQ
compareSAnchor SBusinessCapability _ = GLT
compareSAnchor _ SBusinessCapability = GGT
compareSAnchor SBusinessProcess SBusinessProcess = GEQ
compareSAnchor SBusinessProcess _ = GLT
compareSAnchor _ SBusinessProcess = GGT
compareSAnchor SBusinessObject SBusinessObject = GEQ
compareSAnchor SBusinessObject _ = GLT
compareSAnchor _ SBusinessObject = GGT
compareSAnchor SValueStream SValueStream = GEQ

claimKey :: MacroClaim node -> ClaimKey
claimKey (RegisteredMacroClaim source relation target) =
  ClaimKey
    (macroContextIdentifier source)
    (registeredMacroCode relation)
    (macroContextIdentifier target)

macroContextIdentifier :: MacroContextRef node context -> RawNodeId
macroContextIdentifier (MacroContextRef _ identifier _) = identifier

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
