{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Main
  ( main
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import O2I.Core.Contract
import O2I.Core.Graph.Observation (Commitment(Asserted))
import O2I.Core.Identity
import O2I.Input.Internal.Binding (bindSupplementalInputs)
import O2I.Input.Internal.Text (canonicalizeFachlicheText)
import O2I.Input.Internal.Types
import O2I.Structure
import qualified O2I.Structure.Index as StructureIndex
import O2I.Structure.Internal (StructureAssessment(..))
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit ((@?=), testCase)

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "Core supplemental-input identity binding"
    [ testCase "binds every admitted identity site" acceptedIdentitySites
    , testCase "unknown identity has first precedence" unknownIdentity
    , testCase "ambiguity precedes selected-View membership" ambiguousIdentity
    , testCase "unique identity outside the View is rejected" outsideIdentity
    , testCase "selected identity of the wrong kind is rejected" wrongKind
    , testCase
        "all four real binding defects retain exact Core rules"
        bindingRules
    , testCase "nested sites retain exact pointer evidence" nestedPointer
    , testCase
        "independent identity defects accumulate by evidence key"
        independentDefects
    , testCase
        "retains one source-local diagnostic group including empty groups"
        sourceLocalDiagnosticGroups
    , testCase
        "unresolved sites retain independently usable binding state"
        siteLocalBinding
    ]

acceptedIdentitySites :: IO ()
acceptedIdentitySites =
  runBinding [] completeSet $ \result ->
    supplementalBindingDefects result @?= []

unknownIdentity :: IO ()
unknownIdentity =
  defectsFor
    []
    (strategySet
       strategyFormulation {formulationStrategy = identity "unknown-strategy"})
    @?= [ identityDefect
            SupplementalIdentityUnknownDefect
            strategyOrdinal
            "/strategy"
            "unknown-strategy"
        ]

ambiguousIdentity :: IO ()
ambiguousIdentity =
  defectsFor
    [modelOccurrence (occurrence "strategy-alias") (identity "strategy-1")]
    (strategySet strategyFormulation)
    @?= [ identityDefect
            SupplementalIdentityAmbiguousDefect
            strategyOrdinal
            "/strategy"
            "strategy-1"
        ]

outsideIdentity :: IO ()
outsideIdentity =
  defectsFor
    [modelOccurrence (occurrence "outside") (identity "strategy-outside")]
    (strategySet
       strategyFormulation {formulationStrategy = identity "strategy-outside"})
    @?= [ identityDefect
            SupplementalIdentityOutOfSelectedViewDefect
            strategyOrdinal
            "/strategy"
            "strategy-outside"
        ]

wrongKind :: IO ()
wrongKind =
  defectsFor
    []
    (strategySet strategyFormulation {formulationStrategy = identity "driver-1"})
    @?= [ identityDefect
            SupplementalIdentityWrongTypeDefect
            strategyOrdinal
            "/strategy"
            "driver-1"
        ]

bindingRules :: IO ()
bindingRules = do
  let actual = map supplementalInputDefectRule realBindingDefects
      expected =
        map
          exactCoreRule
          [ "core.supplemental.identity.unknown"
          , "core.supplemental.identity.ambiguous"
          , "core.supplemental.identity.wrong-type"
          , "core.supplemental.identity.out-of-selected-view"
          ]
  actual @?= expected
  if actual == drop 1 expected ++ take 1 expected
    then fail "a binding rule permutation preserved exact associations"
    else pure ()

realBindingDefects :: [SupplementalInputDefect]
realBindingDefects =
  [ onlyDefect
      (defectsFor
         []
         (strategySet
            strategyFormulation
              {formulationStrategy = identity "unknown-strategy"}))
  , onlyDefect
      (defectsFor
         [modelOccurrence (occurrence "strategy-alias") (identity "strategy-1")]
         (strategySet strategyFormulation))
  , onlyDefect
      (defectsFor
         []
         (strategySet
            strategyFormulation {formulationStrategy = identity "driver-1"}))
  , onlyDefect
      (defectsFor
         [modelOccurrence (occurrence "outside") (identity "strategy-outside")]
         (strategySet
            strategyFormulation
              {formulationStrategy = identity "strategy-outside"}))
  ]

onlyDefect :: [SupplementalInputDefect] -> SupplementalInputDefect
onlyDefect defects =
  case defects of
    [defect] -> defect
    _ -> error ("expected one binding defect, got " ++ show defects)

exactCoreRule :: Text -> CoreRuleId
exactCoreRule identifier =
  case filter ((== identifier) . coreRuleIdText) (NonEmpty.toList coreRuleIds) of
    [rule] -> rule
    rules ->
      error
        ("expected one Core rule " ++ show identifier ++ ", got " ++ show rules)

nestedPointer :: IO ()
nestedPointer =
  defectsFor [] (collectiveSet invalidCollective)
    @?= [ identityDefect
            SupplementalIdentityUnknownDefect
            collectiveOrdinal
            "/pairwiseCoherence/0/participantB"
            "unknown-participant"
        ]
  where
    invalidCollective =
      collectiveFit
        { collectivePairwiseCoherence =
            PairwiseCoherence
              (identity "strategy-a")
              (identity "unknown-participant")
              fachlicheText
              :| []
        }

independentDefects :: IO ()
independentDefects =
  defectsFor
    []
    (strategySet
       strategyFormulation
         { formulationStrategy = identity "unknown-strategy"
         , formulationDiagnosis = identity "objective-1"
         })
    @?= [ identityDefect
            SupplementalIdentityUnknownDefect
            strategyOrdinal
            "/strategy"
            "unknown-strategy"
        , identityDefect
            SupplementalIdentityWrongTypeDefect
            strategyOrdinal
            "/diagnosis"
            "objective-1"
        ]

sourceLocalDiagnosticGroups :: IO ()
sourceLocalDiagnosticGroups =
  runBinding [] inputs $ \binding ->
    supplementalBindingDiagnosticGroups binding
      @?= [ ("valid", [])
          , ( "invalid"
            , [ SupplementalBindingIdentityUnknown
                  (SupplementalIdentityUnknownEvidence
                     collectiveOrdinal
                     "/strategy"
                     (identity "unknown-strategy"))
              ])
          ]
  where
    inputs :: SupplementalInputSet Text
    inputs =
      SupplementalInputSet
        [ StrategyFormulationSupplement
            "valid"
            strategyOrdinal
            strategyFormulation
        , StrategyFormulationSupplement
            "invalid"
            collectiveOrdinal
            strategyFormulation
              {formulationStrategy = identity "unknown-strategy"}
        ]

siteLocalBinding :: IO ()
siteLocalBinding =
  runBinding [] inputs $ \binding -> do
    supplementalBindingDefects binding
      @?= [ ( ()
            , identityDefect
                SupplementalIdentityUnknownDefect
                strategyOrdinal
                "/diagnosis"
                "unknown-diagnosis")
          ]
    let bound = supplementalBindingInputs binding
    supplementalIdentitySiteResolved
      bound
      strategyOrdinal
      "/strategy"
      (identity "strategy-1")
      @?= True
    supplementalIdentitySiteResolved
      bound
      strategyOrdinal
      "/diagnosis"
      (identity "unknown-diagnosis")
      @?= False
  where
    inputs =
      strategySet
        strategyFormulation
          {formulationDiagnosis = identity "unknown-diagnosis"}

defectsFor ::
     [ModelOccurrence] -> SupplementalInputSet () -> [SupplementalInputDefect]
defectsFor extra inputs =
  runBinding extra inputs (map snd . supplementalBindingDefects)

runBinding ::
     [ModelOccurrence]
  -> SupplementalInputSet provenance
  -> (forall scope. SupplementalBinding scope provenance -> result)
  -> result
runBinding extra inputs inspect =
  case buildModelIdentityIndex (modelOccurrences ++ extra) of
    Left defects -> error ("invalid identity fixture: " ++ show defects)
    Right index ->
      case withSelectedViewScope index selectedOccurrences withinScope of
        Left defects ->
          error ("invalid selected-View fixture: " ++ show defects)
        Right result -> result
  where
    withinScope scope =
      case StructureIndex.assessStructure scope projection of
        Left defects -> error ("invalid Structure input: " ++ show defects)
        Right (StructureRejected defects) ->
          error ("invalid Structure fixture: " ++ show defects)
        Right (StructureAccepted graph) ->
          inspect (bindSupplementalInputs graph inputs)

identityDefect ::
     (SupplementalInputOrdinal -> Text -> ModelIdentity -> SupplementalInputDefect)
  -> SupplementalInputOrdinal
  -> Text
  -> Text
  -> SupplementalInputDefect
identityDefect constructor ordinal pointer identifier =
  constructor ordinal pointer (identity identifier)

completeSet :: SupplementalInputSet ()
completeSet =
  SupplementalInputSet
    [ StrategyFormulationSupplement () strategyOrdinal strategyFormulation
    , CollectiveFitSupplement () collectiveOrdinal collectiveFit
    ]

strategySet :: StrategyFormulationInput -> SupplementalInputSet ()
strategySet formulation =
  SupplementalInputSet
    [StrategyFormulationSupplement () strategyOrdinal formulation]

collectiveSet :: CollectiveFitInput -> SupplementalInputSet ()
collectiveSet collective =
  SupplementalInputSet [CollectiveFitSupplement () collectiveOrdinal collective]

strategyOrdinal, collectiveOrdinal :: SupplementalInputOrdinal
strategyOrdinal = SupplementalInputOrdinal 0

collectiveOrdinal = SupplementalInputOrdinal 1

strategyFormulation :: StrategyFormulationInput
strategyFormulation =
  StrategyFormulationInput
    { formulationStrategy = identity "strategy-1"
    , formulationScope = fachlicheText :| []
    , formulationAnchoring =
        StrategyAnchoring
          { strategyAnchoringPeriod = fachlicheText
          , strategyAnchoringResponsibilityScope = fachlicheText
          , strategyAnchoringDecisionLevel = fachlicheText
          , strategyAnchoringResponsibilities = fachlicheText :| []
          , strategyAnchoringDecisionPaths = fachlicheText :| []
          , strategyAnchoringImplementationLogic = fachlicheText
          }
    , formulationDerivedGuardrails = fachlicheText :| []
    , formulationDiagnosis = identity "driver-1"
    , formulationIntent = identity "objective-1"
    , formulationGuidingPolicy = identity "principle-1"
    , formulationPositioning = fachlicheText :| []
    , formulationTradeOffs = fachlicheText :| []
    , formulationActions = identity "action-1" :| []
    , formulationKeyResults = identity "key-result-1" :| []
    , formulationFitRationale = fachlicheText :| []
    }

collectiveFit :: CollectiveFitInput
collectiveFit =
  CollectiveFitInput
    { collectiveClaim = identity "claim-1"
    , collectiveParticipants = identity "strategy-a" :| [identity "strategy-b"]
    , collectiveTarget = identity "strategy-target"
    , collectiveTargetGuidingPolicy = identity "principle-target"
    , collectiveTargetTradeOffs = fachlicheText :| []
    , collectivePairwiseCoherence =
        PairwiseCoherence
          (identity "strategy-a")
          (identity "strategy-b")
          fachlicheText
          :| []
    , collectiveParticipantCompatibility =
        ParticipantCompatibility
          (identity "strategy-a")
          fachlicheText
          fachlicheText
          :| [ ParticipantCompatibility
                 (identity "strategy-b")
                 fachlicheText
                 fachlicheText
             ]
    , collectiveContributionInteraction = fachlicheText :| []
    }

fachlicheText :: FachlicheText
fachlicheText =
  FachlicheText (expectRight (canonicalizeFachlicheText "evidence"))

projection :: StructureProjection
projection =
  structureProjection
    carriers
    contextualizations
    []
    [ structuredPropositionProjection
        claimOccurrence
        collectiveFamily
        completenessClosed
        Asserted
    ]
    [ incidence participantAIncidence participantRole strategyAOccurrence
    , incidence participantBIncidence participantRole strategyBOccurrence
    , incidence targetIncidence targetRole strategyTargetOccurrence
    ]

carriers :: [CarrierProjection]
carriers =
  [ contextCarrier strategyOccurrence strategyType
  , primitiveCarrier driverOccurrence driverType
  , primitiveCarrier objectiveOccurrence objectiveType
  , primitiveCarrier principleOccurrence principleType
  , primitiveCarrier actionOccurrence actionType
  , primitiveCarrier keyResultOccurrence keyResultType
  , contextCarrier strategyAOccurrence strategyType
  , contextCarrier strategyBOccurrence strategyType
  , contextCarrier strategyTargetOccurrence strategyType
  , primitiveCarrier targetPrincipleOccurrence principleType
  ]

contextualizations :: [ContextualizationProjection]
contextualizations =
  [ ownership "owns-driver" strategyOccurrence driverOccurrence
  , ownership "owns-objective" strategyOccurrence objectiveOccurrence
  , ownership "owns-principle" strategyOccurrence principleOccurrence
  , ownership "owns-action" strategyOccurrence actionOccurrence
  , ownership "owns-key-result" strategyOccurrence keyResultOccurrence
  , ownership
      "owns-target-principle"
      strategyTargetOccurrence
      targetPrincipleOccurrence
  ]

contextCarrier :: OccurrenceIdentity -> CoreO2IType -> CarrierProjection
contextCarrier identifier o2iType =
  carrierProjection identifier contextCategory o2iType Asserted

primitiveCarrier :: OccurrenceIdentity -> CoreO2IType -> CarrierProjection
primitiveCarrier identifier o2iType =
  carrierProjection identifier primitiveCategory o2iType Asserted

ownership ::
     Text
  -> OccurrenceIdentity
  -> OccurrenceIdentity
  -> ContextualizationProjection
ownership identifier owner member =
  contextualizationProjection (occurrence identifier) owner member Asserted

incidence ::
     OccurrenceIdentity
  -> CoreStructuredPropositionRoleId
  -> OccurrenceIdentity
  -> StructuredIncidenceProjection
incidence identifier role endpoint =
  structuredIncidenceProjection identifier claimOccurrence role endpoint

contextCategory, primitiveCategory :: CoreCarrierCategory
contextCategory = exact "Context" lookupCoreCarrierCategory

primitiveCategory = exact "Primitive" lookupCoreCarrierCategory

strategyType, driverType, objectiveType, principleType, actionType, keyResultType ::
     CoreO2IType
strategyType = exact "Strategy" lookupCoreO2IType

driverType = exact "Driver" lookupCoreO2IType

objectiveType = exact "Objective" lookupCoreO2IType

principleType = exact "Principle" lookupCoreO2IType

actionType = exact "Action" lookupCoreO2IType

keyResultType = exact "KeyResult" lookupCoreO2IType

collectiveFamily :: CoreStructuredPropositionFamilyId
collectiveFamily =
  exact
    "collective-strategy-realization"
    lookupCoreStructuredPropositionFamilyId

participantRole, targetRole :: CoreStructuredPropositionRoleId
participantRole =
  exact
    "collective-strategy-realization.role.participant"
    lookupCoreStructuredPropositionRoleId

targetRole =
  exact
    "collective-strategy-realization.role.target"
    lookupCoreStructuredPropositionRoleId

completenessClosed :: CoreParticipantCompleteness
completenessClosed = exact "closed" lookupCoreParticipantCompletenessToken

modelOccurrences :: [ModelOccurrence]
modelOccurrences =
  [ model strategyOccurrence "strategy-1"
  , model driverOccurrence "driver-1"
  , model objectiveOccurrence "objective-1"
  , model principleOccurrence "principle-1"
  , model actionOccurrence "action-1"
  , model keyResultOccurrence "key-result-1"
  , model strategyAOccurrence "strategy-a"
  , model strategyBOccurrence "strategy-b"
  , model strategyTargetOccurrence "strategy-target"
  , model targetPrincipleOccurrence "principle-target"
  , model claimOccurrence "claim-1"
  ]
    ++ map segmentModel segmentOccurrences

selectedOccurrences :: [OccurrenceIdentity]
selectedOccurrences = map modelOccurrenceIdentity modelOccurrences

segmentModel :: OccurrenceIdentity -> ModelOccurrence
segmentModel identifier =
  model identifier ("model-" <> occurrenceIdentityText identifier)

model :: OccurrenceIdentity -> Text -> ModelOccurrence
model identifier modelIdentifier =
  modelOccurrence identifier (identity modelIdentifier)

segmentOccurrences :: [OccurrenceIdentity]
segmentOccurrences =
  [ ownershipOccurrence "owns-driver"
  , ownershipOccurrence "owns-objective"
  , ownershipOccurrence "owns-principle"
  , ownershipOccurrence "owns-action"
  , ownershipOccurrence "owns-key-result"
  , ownershipOccurrence "owns-target-principle"
  , participantAIncidence
  , participantBIncidence
  , targetIncidence
  ]

strategyOccurrence, driverOccurrence, objectiveOccurrence, principleOccurrence, actionOccurrence, keyResultOccurrence, strategyAOccurrence, strategyBOccurrence, strategyTargetOccurrence, targetPrincipleOccurrence, claimOccurrence, participantAIncidence, participantBIncidence, targetIncidence ::
     OccurrenceIdentity
strategyOccurrence = occurrence "strategy"

driverOccurrence = occurrence "driver"

objectiveOccurrence = occurrence "objective"

principleOccurrence = occurrence "principle"

actionOccurrence = occurrence "action"

keyResultOccurrence = occurrence "key-result"

strategyAOccurrence = occurrence "strategy-a"

strategyBOccurrence = occurrence "strategy-b"

strategyTargetOccurrence = occurrence "strategy-target"

targetPrincipleOccurrence = occurrence "principle-target"

claimOccurrence = occurrence "claim"

participantAIncidence = occurrence "claim-participant-a"

participantBIncidence = occurrence "claim-participant-b"

targetIncidence = occurrence "claim-target"

ownershipOccurrence :: Text -> OccurrenceIdentity
ownershipOccurrence = occurrence

occurrence :: Text -> OccurrenceIdentity
occurrence = expectRight . occurrenceIdentity

identity :: Text -> ModelIdentity
identity = expectRight . modelIdentity

exact :: Show key => key -> (key -> Maybe value) -> value
exact key decoder =
  fromMaybe (error ("invalid test fixture value: " ++ show key)) (decoder key)

expectRight :: Show problem => Either problem value -> value
expectRight value =
  case value of
    Left problem -> error ("invalid test fixture: " ++ show problem)
    Right result -> result
