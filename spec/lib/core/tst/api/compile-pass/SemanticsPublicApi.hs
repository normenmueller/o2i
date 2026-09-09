{-# LANGUAGE OverloadedStrings #-}

module SemanticsPublicApi where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Identity (modelIdentityText, occurrenceIdentityText)
import O2I.Semantics
import O2I.Semantics.Input (BoundSupplementalInputs)
import O2I.Structure (WellFormedGraph)

assess ::
     WellFormedGraph scope
  -> BoundSupplementalInputs scope
  -> SemanticAssessment scope
assess = assessSemantics

matchesProducingGraph ::
     WellFormedGraph scope -> SemanticAssessment scope -> Bool
matchesProducingGraph = semanticAssessmentMatchesGraph

summarize ::
     SemanticAssessment scope
  -> (SemanticDisposition, Int, Int, Maybe Int, Int, Int)
summarize assessment =
  ( semanticDisposition assessment
  , foldSemanticAssessment NonEmpty.length 0 (const 0) assessment
  , length (semanticCandidateOccurrences assessment)
  , length . semanticallyValidSituatedNeeds
      <$> semanticallyValidModel assessment
  , length (semanticallyValidStrategies assessment)
  , length (semanticallyValidCollectiveRealizations assessment))

diagnosticValues :: SemanticDiagnosticEvidence scope -> [Text]
diagnosticValues = foldSemanticDiagnosticEvidence eliminator
  where
    eliminator =
      SemanticDiagnosticEliminator
        { eliminateCollectiveAssertedCollectiveCoverage =
            \claim values -> "coverage" : model claim : occurrences values
        , eliminateCollectiveAssertedCompleteness =
            \claim occurrence -> ["completeness", model claim, item occurrence]
        , eliminateCollectiveAssertedMacroSupport =
            \claim participant claimOccurrence participantOccurrence targetOccurrence ->
              [ "macro-support"
              , model claim
              , model participant
              , item claimOccurrence
              , item participantOccurrence
              , item targetOccurrence
              ]
        , eliminateCollectiveAssertedParticipantPrimitiveSupport =
            \claim participant claimOccurrence participantOccurrence targetOccurrence ->
              [ "primitive-support"
              , model claim
              , model participant
              , item claimOccurrence
              , item participantOccurrence
              , item targetOccurrence
              ]
        , eliminateCollectiveFitPairwiseCoherence = fit "pairwise"
        , eliminateCollectiveFitParticipantBinding = fit "participant-binding"
        , eliminateCollectiveFitParticipantCompatibility =
            fit "participant-compatibility"
        , eliminateCollectiveFitTargetBinding = fit "target-binding"
        , eliminateCollectiveFitTargetGuidingPolicy = fit "target-policy"
        , eliminateCollectiveFitTargetTradeOffs = fit "target-trade-offs"
        , eliminateContextualizationAssertedDependency =
            \dependent endpoint context dependentOccurrence endpointOccurrence contextOccurrence ->
              [ "contextualization"
              , item dependent
              , item endpoint
              , item context
              , item dependentOccurrence
              , item endpointOccurrence
              , item contextOccurrence
              ]
        , eliminateSituatedNeedDriverAnchoring = member "driver-anchoring"
        , eliminateSituatedNeedDriverCardinality = one "driver-cardinality"
        , eliminateSituatedNeedObjectiveCardinality =
            one "objective-cardinality"
        , eliminateSituatedNeedObjectiveGrounding = member "objective-grounding"
        , eliminateSituatedNeedSurfacingSituationAnchoring =
            member "situation-anchoring"
        , eliminateSituatedNeedSurfacingSituationCardinality =
            one "situation-cardinality"
        , eliminateStrategyFormulationActionContributions =
            member "action-contributions"
        , eliminateStrategyFormulationActions =
            \strategy values -> "actions" : model strategy : occurrences values
        , eliminateStrategyFormulationDiagnosis = many "diagnosis"
        , eliminateStrategyFormulationDiagnosisGrounding =
            pair "diagnosis-grounding"
        , eliminateStrategyFormulationGuidingPolicy = many "guiding-policy"
        , eliminateStrategyFormulationGuidingPolicyActions =
            memberPair "guiding-policy-actions"
        , eliminateStrategyFormulationIntent = many "intent"
        , eliminateStrategyFormulationKeyResultSubstantiation =
            memberPair "key-result-substantiation"
        , eliminateStrategyFormulationKeyResults =
            \strategy values ->
              "key-results" : model strategy : occurrences values
        , eliminateStrategyFormulationVisionOrientation =
            one "vision-orientation"
        }
    model = modelIdentityText
    item = occurrenceIdentityText
    occurrences = map item . NonEmpty.toList
    fit tag claim occurrence = [tag, model claim, item occurrence]
    member tag owner owned occurrence =
      [tag, model owner, model owned, item occurrence]
    one tag identity = [tag, model identity]
    many tag identity values = tag : model identity : map item values
    pair tag identity first second =
      [tag, model identity, item first, item second]
    memberPair tag owner owned first second =
      [tag, model owner, model owned, item first, item second]

collectiveComponents ::
     CollectiveStrategyRealizationAssessment scope
  -> Maybe
       ( ComponentDisposition
       , ComponentDisposition
       , ComponentDisposition
       , [ComponentDisposition]
       , [ComponentDisposition])
collectiveComponents assessment = do
  components <- collectiveStrategyRealizationComponents assessment
  pure
    ( collectiveCompletenessDisposition components
    , collectiveFitDisposition components
    , collectiveCoverageDisposition components
    , map macroSupportDisposition (collectiveMacroSupportAssessments components)
    , map
        primitiveSupportDisposition
        (collectivePrimitiveSupportAssessments components))
