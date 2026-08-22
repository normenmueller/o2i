{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

-- | Build-only, public-source conformance corpus for Core owners.
module O2I.Core.Conformance
  ( CoreConformanceFailure
  , foldCoreConformanceFailure
  , CoreConformanceResult
  , foldCoreConformanceResult
  , foldStructureCorpusEvidence
  , structureCorpusRuleIds
  , foldBindingCorpusEvidence
  , foldBindingCorpusOwnerEvidence
  , bindingCorpusRuleIds
  , foldSemanticsCorpusEvidence
  , foldSemanticsCorpusOwnerEvidence
  , semanticsCorpusRuleIds
  ) where

import qualified Data.ByteString.Char8 as ByteString
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified O2I.Core.Conformance.SemanticsSource as SemanticsSource
import O2I.Core.Contract
import O2I.Core.Graph.Observation (Commitment(Asserted))
import O2I.Core.Identity
import qualified O2I.Semantics as Semantics
import O2I.Semantics.Input
import O2I.Structure

-- | Closed fixture/owner-boundary failures, separate from model diagnostics.
data CoreConformanceFailure
  = UnknownContractValue !Text
  | InvalidOccurrenceSource !Text
  | InvalidModelIdentitySource !Text
  | InvalidIdentityIndexSource !(NonEmpty IdentityIndexDefect)
  | InvalidSelectedScopeSource !(NonEmpty SelectedViewScopeDefect)
  | InvalidStructureInputSource !(NonEmpty StructureInputDefect)
  | InvalidSupplementalSource !(NonEmpty SupplementalInputDefect)
  | InvalidBindingGraphSource

-- | Eliminate every closed conformance-fixture failure.
foldCoreConformanceFailure ::
     (Text -> result)
  -> (Text -> result)
  -> (Text -> result)
  -> (NonEmpty IdentityIndexDefect -> result)
  -> (NonEmpty SelectedViewScopeDefect -> result)
  -> (NonEmpty StructureInputDefect -> result)
  -> (NonEmpty SupplementalInputDefect -> result)
  -> result
  -> CoreConformanceFailure
  -> result
foldCoreConformanceFailure contract occurrence model index scope structure supplemental graph failure =
  case failure of
    UnknownContractValue value -> contract value
    InvalidOccurrenceSource value -> occurrence value
    InvalidModelIdentitySource value -> model value
    InvalidIdentityIndexSource defects -> index defects
    InvalidSelectedScopeSource defects -> scope defects
    InvalidStructureInputSource defects -> structure defects
    InvalidSupplementalSource defects -> supplemental defects
    InvalidBindingGraphSource -> graph

-- | Closed outcome of producing evidence from the public-source corpus.
data CoreConformanceResult result
  = CoreConformanceFailed !(NonEmpty CoreConformanceFailure)
  | CoreConformanceObserved ![result]

-- | Eliminate a conformance result without exposing its constructors.
foldCoreConformanceResult ::
     (NonEmpty CoreConformanceFailure -> result)
  -> ([value] -> result)
  -> CoreConformanceResult value
  -> result
foldCoreConformanceResult failed observed result =
  case result of
    CoreConformanceFailed failures -> failed failures
    CoreConformanceObserved values -> observed values

-- | Consume every real Structure evidence value produced by the corpus.
foldStructureCorpusEvidence ::
     (forall scope. SelectedViewScope scope -> StructureEvidence scope -> result)
  -> CoreConformanceResult result
foldStructureCorpusEvidence consume =
  case buildFixture of
    Left failure -> CoreConformanceFailed (failure :| [])
    Right fixture ->
      case traverse
             (uncurry (runStructureSource fixture consume))
             (structureSources fixture)
             >>= (\values ->
                    fmap
                      (concat values <>)
                      (runDuplicateIdentitySource fixture consume)) of
        Left failure -> CoreConformanceFailed (failure :| [])
        Right values -> CoreConformanceObserved values

-- | Structure rule identities observed through their public evidence fold.
structureCorpusRuleIds :: CoreConformanceResult CoreRuleId
structureCorpusRuleIds =
  foldStructureCorpusEvidence (\_ evidence -> structureEvidenceRule evidence)

-- | Consume every real supplemental-binding evidence value from the corpus.
foldBindingCorpusEvidence ::
     (forall scope. SupplementalBindingEvidence scope -> result)
  -> CoreConformanceResult result
foldBindingCorpusEvidence consume =
  foldBindingCorpusOwnerEvidence (\_ evidence -> consume evidence)

-- | Consume each Binding artifact together with its own scoped evidence.
foldBindingCorpusOwnerEvidence ::
     (forall scope. SupplementalBinding scope -> SupplementalBindingEvidence
                                                   scope -> result)
  -> CoreConformanceResult result
foldBindingCorpusOwnerEvidence consume =
  case buildBindingSources of
    Left failure -> CoreConformanceFailed (failure :| [])
    Right sources ->
      case traverse (runBindingSource consume) sources of
        Left failure -> CoreConformanceFailed (failure :| [])
        Right values -> CoreConformanceObserved (concat values)

-- | Binding rule identities observed through their public evidence fold.
bindingCorpusRuleIds :: CoreConformanceResult CoreRuleId
bindingCorpusRuleIds = foldBindingCorpusEvidence supplementalBindingEvidenceRule

-- | Consume every real semantic diagnostic evidence value from the corpus.
foldSemanticsCorpusEvidence ::
     (forall scope. Semantics.SemanticDiagnosticEvidence scope -> result)
  -> CoreConformanceResult result
foldSemanticsCorpusEvidence consume =
  foldSemanticsCorpusOwnerEvidence (\_ evidence -> consume evidence)

-- | Consume each Semantics assessment together with its own scoped evidence.
foldSemanticsCorpusOwnerEvidence ::
     (forall scope. Semantics.SemanticAssessment scope -> Semantics.SemanticDiagnosticEvidence
                                                            scope -> result)
  -> CoreConformanceResult result
foldSemanticsCorpusOwnerEvidence consume =
  case traverse (runSemanticsSource consume) SemanticsSource.semanticSources of
    Left failure -> CoreConformanceFailed (failure :| [])
    Right values -> CoreConformanceObserved (concat values)

-- | Semantics rule identities observed through their public evidence fold.
semanticsCorpusRuleIds :: CoreConformanceResult CoreRuleId
semanticsCorpusRuleIds =
  foldSemanticsCorpusEvidence Semantics.semanticDiagnosticRule

runSemanticsSource ::
     (forall scope. Semantics.SemanticAssessment scope -> Semantics.SemanticDiagnosticEvidence
                                                            scope -> result)
  -> SemanticsSource.SemanticSource
  -> Either CoreConformanceFailure [result]
runSemanticsSource consume source = do
  let occurrences = SemanticsSource.semanticSourceOccurrences source
  index <- requireIndex occurrences
  runWithStructureScope
    index
    (map modelOccurrenceIdentity occurrences)
    (\scope ->
       case assessStructure
              scope
              (SemanticsSource.semanticSourceProjection source) of
         Left defects -> Left (InvalidStructureInputSource defects)
         Right assessment ->
           foldStructureAssessment
             (const (Left InvalidBindingGraphSource))
             (\graph -> do
                decoded <-
                  traverse
                    (\(ordinal, payload) ->
                       case decodeSupplementalInput
                              (supplementalInputOrdinal ordinal)
                              payload of
                         Left defects ->
                           Left (InvalidSupplementalSource defects)
                         Right input -> Right input)
                    (SemanticsSource.semanticSourceInputs source)
                inputSet <-
                  case assessSupplementalInputSet decoded of
                    Left defects -> Left (InvalidSupplementalSource defects)
                    Right accepted -> Right accepted
                foldSupplementalBinding
                  (\bound evidence ->
                     if null evidence
                       then let semanticAssessment =
                                  Semantics.assessSemantics graph bound
                             in Right
                                  (Semantics.foldSemanticAssessment
                                     (map (consume semanticAssessment)
                                        . NonEmpty.toList)
                                     []
                                     (const [])
                                     semanticAssessment)
                       else Left InvalidBindingGraphSource)
                  (bindSupplementalInputs graph inputSet))
             assessment)

data BindingSource = BindingSource
  { bindingSourceIndex :: !ModelIdentityIndex
  , bindingSourceSelected :: ![OccurrenceIdentity]
  , bindingSourceProjection :: !StructureProjection
  , bindingSourceInput :: !SupplementalInputSet
  }

buildBindingSources :: Either CoreConformanceFailure [BindingSource]
buildBindingSources = do
  contextCategory <- requireContract "Context" lookupCoreCarrierCategory
  needType <- requireContract "Need" lookupCoreO2IType
  unknown <- bindingSource [] [] (structureProjection [] [] [] [] []) "unknown"
  ambiguousA <- requireOccurrence "ambiguous-a"
  ambiguousB <- requireOccurrence "ambiguous-b"
  ambiguousIdentity <- requireModelIdentity "ambiguous"
  ambiguous <-
    bindingSource
      [ modelOccurrence ambiguousA ambiguousIdentity
      , modelOccurrence ambiguousB ambiguousIdentity
      ]
      []
      (structureProjection [] [] [] [] [])
      "ambiguous"
  outsideOccurrence <- requireOccurrence "outside-occurrence"
  outsideIdentity <- requireModelIdentity "outside"
  outside <-
    bindingSource
      [modelOccurrence outsideOccurrence outsideIdentity]
      []
      (structureProjection [] [] [] [] [])
      "outside"
  wrongOccurrence <- requireOccurrence "wrong-occurrence"
  wrongIdentity <- requireModelIdentity "wrong"
  wrong <-
    bindingSource
      [modelOccurrence wrongOccurrence wrongIdentity]
      [wrongOccurrence]
      (structureProjection
         [carrierProjection wrongOccurrence contextCategory needType Asserted]
         []
         []
         []
         [])
      "wrong"
  Right [unknown, ambiguous, wrong, outside]

bindingSource ::
     [ModelOccurrence]
  -> [OccurrenceIdentity]
  -> StructureProjection
  -> Text
  -> Either CoreConformanceFailure BindingSource
bindingSource occurrences selected projection identityValue = do
  index <- requireIndex occurrences
  input <-
    case decodeSupplementalInput
           (supplementalInputOrdinal 0)
           (strategyPayload identityValue) of
      Left defects -> Left (InvalidSupplementalSource defects)
      Right decoded -> Right decoded
  inputSet <-
    case assessSupplementalInputSet [input] of
      Left defects -> Left (InvalidSupplementalSource defects)
      Right accepted -> Right accepted
  Right (BindingSource index selected projection inputSet)

runBindingSource ::
     (forall scope. SupplementalBinding scope -> SupplementalBindingEvidence
                                                   scope -> result)
  -> BindingSource
  -> Either CoreConformanceFailure [result]
runBindingSource consume source =
  runWithStructureScope
    (bindingSourceIndex source)
    (bindingSourceSelected source)
    (\scope ->
       case assessStructure scope (bindingSourceProjection source) of
         Left defects -> Left (InvalidStructureInputSource defects)
         Right assessment ->
           foldStructureAssessment
             (const (Left InvalidBindingGraphSource))
             (\graph ->
                let binding =
                      bindSupplementalInputs graph (bindingSourceInput source)
                 in Right
                      (foldSupplementalBinding
                         (\_ evidence -> map (consume binding) evidence)
                         binding))
             assessment)

strategyPayload :: Text -> ByteString.ByteString
strategyPayload identityValue =
  ByteString.pack
    ("{\"type\":\"StrategyFormulationInput\",\"strategy\":\""
       <> text
       <> "\",\"scope\":[\"scope\"],\"anchoring\":{\"period\":\"period\",\"responsibilityScope\":\"responsibility scope\",\"decisionLevel\":\"decision level\",\"responsibilities\":[\"responsibility\"],\"decisionPaths\":[\"decision path\"],\"implementationLogic\":\"implementation logic\"},\"derivedGuardrails\":[\"guardrail\"],\"diagnosis\":\""
       <> text
       <> "\",\"intent\":\""
       <> text
       <> "\",\"guidingPolicy\":\""
       <> text
       <> "\",\"positioning\":[\"positioning\"],\"tradeOffs\":[\"trade-off\"],\"actions\":[\""
       <> text
       <> "\"],\"keyResults\":[\""
       <> text
       <> "\"],\"fitRationale\":[\"fit rationale\"]}")
  where
    text = Text.unpack identityValue

runStructureSource ::
     Fixture
  -> (forall scope. SelectedViewScope scope -> StructureEvidence scope -> result)
  -> StructureProjection
  -> [OccurrenceIdentity]
  -> Either CoreConformanceFailure [result]
runStructureSource fixture consume projection selected =
  runWithStructureScope
    (fixtureIdentityIndex fixture)
    selected
    (\scope ->
       case assessStructure scope projection of
         Left defects -> Left (InvalidStructureInputSource defects)
         Right assessment ->
           Right
             (foldStructureAssessment
                (map (consume scope) . NonEmpty.toList)
                (const [])
                assessment))

runDuplicateIdentitySource ::
     Fixture
  -> (forall scope. SelectedViewScope scope -> StructureEvidence scope -> result)
  -> Either CoreConformanceFailure [result]
runDuplicateIdentitySource fixture consume =
  runWithStructureScope
    (fixtureDuplicateIdentityIndex fixture)
    (canonicalSelected fixture)
    (\scope ->
       case assessStructure scope (canonicalProjection fixture) of
         Left defects -> Left (InvalidStructureInputSource defects)
         Right assessment ->
           Right
             (foldStructureAssessment
                (map (consume scope) . NonEmpty.toList)
                (const [])
                assessment))

runWithStructureScope ::
     ModelIdentityIndex
  -> [OccurrenceIdentity]
  -> (forall scope. SelectedViewScope scope -> Either
                                                 CoreConformanceFailure
                                                 result)
  -> Either CoreConformanceFailure result
runWithStructureScope index selected consume =
  case withSelectedViewScope index selected consume of
    Left defects -> Left (InvalidSelectedScopeSource defects)
    Right result -> result

data Fixture = Fixture
  { fixtureContextCategory :: !CoreCarrierCategory
  , fixturePrimitiveCategory :: !CoreCarrierCategory
  , fixtureSituationAnchorCategory :: !CoreCarrierCategory
  , fixtureStrategyType :: !CoreO2IType
  , fixtureNeedType :: !CoreO2IType
  , fixtureActionType :: !CoreO2IType
  , fixtureBusinessCapabilityType :: !CoreO2IType
  , fixtureDirectsToken :: !CoreRelationToken
  , fixtureCollectiveFamily :: !CoreStructuredPropositionFamilyId
  , fixtureParticipantRole :: !CoreStructuredPropositionRoleId
  , fixtureTargetRole :: !CoreStructuredPropositionRoleId
  , fixtureCompletenessClosed :: !CoreParticipantCompleteness
  , fixtureCarrierA :: !OccurrenceIdentity
  , fixtureCarrierB :: !OccurrenceIdentity
  , fixtureTargetCarrier :: !OccurrenceIdentity
  , fixturePropositionOccurrence :: !OccurrenceIdentity
  , fixturePropositionAlias :: !OccurrenceIdentity
  , fixtureRelationOccurrence :: !OccurrenceIdentity
  , fixtureContextualizationOccurrence :: !OccurrenceIdentity
  , fixtureActionMember :: !OccurrenceIdentity
  , fixtureIncidenceParticipantA :: !OccurrenceIdentity
  , fixtureIncidenceParticipantB :: !OccurrenceIdentity
  , fixtureIncidenceTarget :: !OccurrenceIdentity
  , fixtureIdentityIndex :: !ModelIdentityIndex
  , fixtureDuplicateIdentityIndex :: !ModelIdentityIndex
  }

buildFixture :: Either CoreConformanceFailure Fixture
buildFixture = do
  contextCategory <- requireContract "Context" lookupCoreCarrierCategory
  primitiveCategory <- requireContract "Primitive" lookupCoreCarrierCategory
  situationAnchorCategory <-
    requireContract "SituationAnchor" lookupCoreCarrierCategory
  strategyType <- requireContract "Strategy" lookupCoreO2IType
  needType <- requireContract "Need" lookupCoreO2IType
  actionType <- requireContract "Action" lookupCoreO2IType
  businessCapabilityType <-
    requireContract "BusinessCapability" lookupCoreO2IType
  directsToken <- requireContract "directs" lookupCoreRelationToken
  collectiveFamily <-
    requireContract
      "collective-strategy-realization"
      lookupCoreStructuredPropositionFamilyId
  participantRole <-
    requireContract
      "collective-strategy-realization.role.participant"
      lookupCoreStructuredPropositionRoleId
  targetRole <-
    requireContract
      "collective-strategy-realization.role.target"
      lookupCoreStructuredPropositionRoleId
  completenessClosed <-
    requireContract "closed" lookupCoreParticipantCompletenessToken
  carrierA <- requireOccurrence "carrier-a"
  carrierB <- requireOccurrence "carrier-b"
  targetCarrier <- requireOccurrence "target"
  propositionOccurrence <- requireOccurrence "proposition"
  propositionAlias <- requireOccurrence "proposition-alias"
  relationOccurrence <- requireOccurrence "relation"
  contextualizationOccurrence <- requireOccurrence "contextualization"
  actionMember <- requireOccurrence "action-member"
  incidenceParticipantA <- requireOccurrence "incidence-a"
  incidenceParticipantB <- requireOccurrence "incidence-b"
  incidenceTarget <- requireOccurrence "incidence-target"
  let occurrences =
        [ carrierA
        , carrierB
        , targetCarrier
        , propositionOccurrence
        , propositionAlias
        , relationOccurrence
        , contextualizationOccurrence
        , actionMember
        , incidenceParticipantA
        , incidenceParticipantB
        , incidenceTarget
        ]
  modelOccurrences <- traverse distinctModelOccurrence occurrences
  identityIndex <- requireIndex modelOccurrences
  propositionIdentity <- requireModelIdentity "model-proposition"
  duplicateIdentityIndex <-
    requireIndex
      (modelOccurrence propositionAlias propositionIdentity
         : filter
             ((/= propositionAlias) . modelOccurrenceIdentity)
             modelOccurrences)
  Right
    Fixture
      { fixtureContextCategory = contextCategory
      , fixturePrimitiveCategory = primitiveCategory
      , fixtureSituationAnchorCategory = situationAnchorCategory
      , fixtureStrategyType = strategyType
      , fixtureNeedType = needType
      , fixtureActionType = actionType
      , fixtureBusinessCapabilityType = businessCapabilityType
      , fixtureDirectsToken = directsToken
      , fixtureCollectiveFamily = collectiveFamily
      , fixtureParticipantRole = participantRole
      , fixtureTargetRole = targetRole
      , fixtureCompletenessClosed = completenessClosed
      , fixtureCarrierA = carrierA
      , fixtureCarrierB = carrierB
      , fixtureTargetCarrier = targetCarrier
      , fixturePropositionOccurrence = propositionOccurrence
      , fixturePropositionAlias = propositionAlias
      , fixtureRelationOccurrence = relationOccurrence
      , fixtureContextualizationOccurrence = contextualizationOccurrence
      , fixtureActionMember = actionMember
      , fixtureIncidenceParticipantA = incidenceParticipantA
      , fixtureIncidenceParticipantB = incidenceParticipantB
      , fixtureIncidenceTarget = incidenceTarget
      , fixtureIdentityIndex = identityIndex
      , fixtureDuplicateIdentityIndex = duplicateIdentityIndex
      }
  where
    distinctModelOccurrence occurrence =
      modelOccurrence occurrence
        <$> requireModelIdentity ("model-" <> occurrenceIdentityText occurrence)

requireContract ::
     Text -> (Text -> Maybe value) -> Either CoreConformanceFailure value
requireContract value decoder =
  maybe (Left (UnknownContractValue value)) Right (decoder value)

requireOccurrence :: Text -> Either CoreConformanceFailure OccurrenceIdentity
requireOccurrence value =
  case occurrenceIdentity value of
    Left _ -> Left (InvalidOccurrenceSource value)
    Right occurrence -> Right occurrence

requireModelIdentity :: Text -> Either CoreConformanceFailure ModelIdentity
requireModelIdentity value =
  case modelIdentity value of
    Left _ -> Left (InvalidModelIdentitySource value)
    Right identity -> Right identity

requireIndex ::
     [ModelOccurrence] -> Either CoreConformanceFailure ModelIdentityIndex
requireIndex occurrences =
  case buildModelIdentityIndex occurrences of
    Left defects -> Left (InvalidIdentityIndexSource defects)
    Right index -> Right index

structureSources :: Fixture -> [(StructureProjection, [OccurrenceIdentity])]
structureSources fixture =
  [ (invalidDirectEndpoint fixture, [fixtureCarrierA fixture])
  , ( invalidContextualizationSource fixture
    , [ fixtureCarrierA fixture
      , fixtureCarrierB fixture
      , fixtureContextualizationOccurrence fixture
      ])
  , ( invalidContextualizationTarget fixture
    , [ fixtureCarrierA fixture
      , fixtureCarrierB fixture
      , fixtureContextualizationOccurrence fixture
      ])
  , (missingContextOwner fixture, [fixtureActionMember fixture])
  , ( incompatibleRelation fixture
    , [ fixtureCarrierA fixture
      , fixtureCarrierB fixture
      , fixtureRelationOccurrence fixture
      ])
  , (wrongParticipantType fixture, canonicalSelected fixture)
  , (oneParticipant fixture, oneParticipantSelected fixture)
  , (duplicateParticipant fixture, canonicalSelected fixture)
  , (wrongTargetType fixture, canonicalSelected fixture)
  , (noTarget fixture, noTargetSelected fixture)
  , (overlappingTarget fixture, overlappingTargetSelected fixture)
  ]

invalidDirectEndpoint, invalidContextualizationSource, invalidContextualizationTarget, missingContextOwner, incompatibleRelation, canonicalProjection, oneParticipant, duplicateParticipant, wrongParticipantType, noTarget, wrongTargetType, overlappingTarget ::
     Fixture -> StructureProjection
invalidDirectEndpoint fixture =
  structureProjection
    [ carrierProjection
        (fixtureCarrierA fixture)
        (fixtureContextCategory fixture)
        (fixtureActionType fixture)
        Asserted
    ]
    []
    []
    []
    []

invalidContextualizationSource fixture =
  structureProjection
    [ anchorCarrier fixture (fixtureCarrierA fixture)
    , carrierProjection
        (fixtureCarrierB fixture)
        (fixturePrimitiveCategory fixture)
        (fixtureActionType fixture)
        Asserted
    ]
    [ contextualizationProjection
        (fixtureContextualizationOccurrence fixture)
        (fixtureCarrierA fixture)
        (fixtureCarrierB fixture)
        Asserted
    ]
    []
    []
    []

invalidContextualizationTarget fixture =
  structureProjection
    [ strategyCarrier fixture (fixtureCarrierA fixture)
    , needCarrier fixture (fixtureCarrierB fixture)
    ]
    [ contextualizationProjection
        (fixtureContextualizationOccurrence fixture)
        (fixtureCarrierA fixture)
        (fixtureCarrierB fixture)
        Asserted
    ]
    []
    []
    []

missingContextOwner fixture =
  structureProjection
    [ carrierProjection
        (fixtureActionMember fixture)
        (fixturePrimitiveCategory fixture)
        (fixtureActionType fixture)
        Asserted
    ]
    []
    []
    []
    []

incompatibleRelation fixture =
  structureProjection
    [ strategyCarrier fixture (fixtureCarrierA fixture)
    , needCarrier fixture (fixtureCarrierB fixture)
    ]
    []
    [ relationProjection
        (fixtureRelationOccurrence fixture)
        (fixtureCarrierA fixture)
        (fixtureDirectsToken fixture)
        (fixtureCarrierB fixture)
        Asserted
    ]
    []
    []

canonicalProjection fixture =
  collectiveProjection
    fixture
    [ strategyCarrier fixture (fixtureCarrierA fixture)
    , strategyCarrier fixture (fixtureCarrierB fixture)
    , strategyCarrier fixture (fixtureTargetCarrier fixture)
    ]
    [ participantIncidence
        fixture
        (fixtureIncidenceParticipantA fixture)
        (fixtureCarrierA fixture)
    , participantIncidence
        fixture
        (fixtureIncidenceParticipantB fixture)
        (fixtureCarrierB fixture)
    ]
    [ targetIncidence
        fixture
        (fixtureIncidenceTarget fixture)
        (fixtureTargetCarrier fixture)
    ]

oneParticipant fixture =
  collectiveProjection
    fixture
    [ strategyCarrier fixture (fixtureCarrierA fixture)
    , strategyCarrier fixture (fixtureTargetCarrier fixture)
    ]
    [ participantIncidence
        fixture
        (fixtureIncidenceParticipantA fixture)
        (fixtureCarrierA fixture)
    ]
    [ targetIncidence
        fixture
        (fixtureIncidenceTarget fixture)
        (fixtureTargetCarrier fixture)
    ]

duplicateParticipant fixture =
  collectiveProjection
    fixture
    [ strategyCarrier fixture (fixtureCarrierA fixture)
    , strategyCarrier fixture (fixtureTargetCarrier fixture)
    ]
    [ participantIncidence
        fixture
        (fixtureIncidenceParticipantA fixture)
        (fixtureCarrierA fixture)
    , participantIncidence
        fixture
        (fixtureIncidenceParticipantB fixture)
        (fixtureCarrierA fixture)
    ]
    [ targetIncidence
        fixture
        (fixtureIncidenceTarget fixture)
        (fixtureTargetCarrier fixture)
    ]

wrongParticipantType fixture =
  collectiveProjection
    fixture
    [ needCarrier fixture (fixtureCarrierA fixture)
    , strategyCarrier fixture (fixtureCarrierB fixture)
    , strategyCarrier fixture (fixtureTargetCarrier fixture)
    ]
    [ participantIncidence
        fixture
        (fixtureIncidenceParticipantA fixture)
        (fixtureCarrierA fixture)
    , participantIncidence
        fixture
        (fixtureIncidenceParticipantB fixture)
        (fixtureCarrierB fixture)
    ]
    [ targetIncidence
        fixture
        (fixtureIncidenceTarget fixture)
        (fixtureTargetCarrier fixture)
    ]

noTarget fixture =
  collectiveProjection
    fixture
    [ strategyCarrier fixture (fixtureCarrierA fixture)
    , strategyCarrier fixture (fixtureCarrierB fixture)
    ]
    [ participantIncidence
        fixture
        (fixtureIncidenceParticipantA fixture)
        (fixtureCarrierA fixture)
    , participantIncidence
        fixture
        (fixtureIncidenceParticipantB fixture)
        (fixtureCarrierB fixture)
    ]
    []

wrongTargetType fixture =
  collectiveProjection
    fixture
    [ strategyCarrier fixture (fixtureCarrierA fixture)
    , strategyCarrier fixture (fixtureCarrierB fixture)
    , needCarrier fixture (fixtureTargetCarrier fixture)
    ]
    [ participantIncidence
        fixture
        (fixtureIncidenceParticipantA fixture)
        (fixtureCarrierA fixture)
    , participantIncidence
        fixture
        (fixtureIncidenceParticipantB fixture)
        (fixtureCarrierB fixture)
    ]
    [ targetIncidence
        fixture
        (fixtureIncidenceTarget fixture)
        (fixtureTargetCarrier fixture)
    ]

overlappingTarget fixture =
  collectiveProjection
    fixture
    [ strategyCarrier fixture (fixtureCarrierA fixture)
    , strategyCarrier fixture (fixtureCarrierB fixture)
    ]
    [ participantIncidence
        fixture
        (fixtureIncidenceParticipantA fixture)
        (fixtureCarrierA fixture)
    , participantIncidence
        fixture
        (fixtureIncidenceParticipantB fixture)
        (fixtureCarrierB fixture)
    ]
    [ targetIncidence
        fixture
        (fixtureIncidenceTarget fixture)
        (fixtureCarrierA fixture)
    ]

collectiveProjection ::
     Fixture
  -> [CarrierProjection]
  -> [StructuredIncidenceProjection]
  -> [StructuredIncidenceProjection]
  -> StructureProjection
collectiveProjection fixture carriers participants targets =
  structureProjection
    carriers
    []
    []
    [collectiveProposition fixture]
    (participants <> targets)

strategyCarrier, needCarrier, anchorCarrier ::
     Fixture -> OccurrenceIdentity -> CarrierProjection
strategyCarrier fixture identifier =
  carrierProjection
    identifier
    (fixtureContextCategory fixture)
    (fixtureStrategyType fixture)
    Asserted

needCarrier fixture identifier =
  carrierProjection
    identifier
    (fixtureContextCategory fixture)
    (fixtureNeedType fixture)
    Asserted

anchorCarrier fixture identifier =
  carrierProjection
    identifier
    (fixtureSituationAnchorCategory fixture)
    (fixtureBusinessCapabilityType fixture)
    Asserted

collectiveProposition :: Fixture -> StructuredPropositionProjection
collectiveProposition fixture =
  structuredPropositionProjection
    (fixturePropositionOccurrence fixture)
    (fixtureCollectiveFamily fixture)
    (fixtureCompletenessClosed fixture)
    Asserted

participantIncidence, targetIncidence ::
     Fixture
  -> OccurrenceIdentity
  -> OccurrenceIdentity
  -> StructuredIncidenceProjection
participantIncidence fixture identifier endpoint =
  structuredIncidenceProjection
    identifier
    (fixturePropositionOccurrence fixture)
    (fixtureParticipantRole fixture)
    endpoint

targetIncidence fixture identifier endpoint =
  structuredIncidenceProjection
    identifier
    (fixturePropositionOccurrence fixture)
    (fixtureTargetRole fixture)
    endpoint

canonicalSelected, oneParticipantSelected, noTargetSelected, overlappingTargetSelected ::
     Fixture -> [OccurrenceIdentity]
canonicalSelected fixture =
  [ fixtureCarrierA fixture
  , fixtureCarrierB fixture
  , fixtureTargetCarrier fixture
  , fixturePropositionOccurrence fixture
  , fixtureIncidenceParticipantA fixture
  , fixtureIncidenceParticipantB fixture
  , fixtureIncidenceTarget fixture
  ]

oneParticipantSelected fixture =
  [ fixtureCarrierA fixture
  , fixtureTargetCarrier fixture
  , fixturePropositionOccurrence fixture
  , fixtureIncidenceParticipantA fixture
  , fixtureIncidenceTarget fixture
  ]

noTargetSelected fixture =
  [ fixtureCarrierA fixture
  , fixtureCarrierB fixture
  , fixturePropositionOccurrence fixture
  , fixtureIncidenceParticipantA fixture
  , fixtureIncidenceParticipantB fixture
  ]

overlappingTargetSelected fixture =
  [ fixtureCarrierA fixture
  , fixtureCarrierB fixture
  , fixturePropositionOccurrence fixture
  , fixtureIncidenceParticipantA fixture
  , fixtureIncidenceParticipantB fixture
  , fixtureIncidenceTarget fixture
  ]
