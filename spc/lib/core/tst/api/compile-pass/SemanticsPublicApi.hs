module SemanticsPublicApi where

import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import O2I.Core.Identity (OccurrenceIdentity)
import O2I.Semantics
import O2I.Semantics.Input (BoundSupplementalInputs)
import O2I.Structure (WellFormedGraph)

assess ::
     WellFormedGraph scope
  -> BoundSupplementalInputs scope
  -> SemanticAssessment scope
assess = assessSemantics

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

diagnosticOccurrences ::
     SemanticDiagnosticEvidence scope -> [(Text, [OccurrenceIdentity])]
diagnosticOccurrences =
  map projectGroup . NonEmpty.toList . semanticDiagnosticOccurrenceGroups
  where
    projectGroup group =
      ( semanticOccurrenceRoleId (semanticOccurrenceGroupRole group)
      , semanticOccurrenceGroupOccurrences group)

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
