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
     SemanticAssessment scope -> (SemanticDisposition, Int, Int, Maybe Int)
summarize assessment =
  ( semanticDisposition assessment
  , length (semanticDefects assessment)
  , length (semanticCandidateOccurrences assessment)
  , length . semanticallyValidStrategies <$> acceptedSemanticModel assessment)

diagnosticOccurrences :: SemanticDefect -> [(Text, [OccurrenceIdentity])]
diagnosticOccurrences =
  map projectGroup . NonEmpty.toList . semanticDefectOccurrenceGroups
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
