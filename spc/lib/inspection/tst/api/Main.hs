{-# LANGUAGE TemplateHaskell #-}

-- | External-client opacity contracts for Inspection artifacts.
module Main
  ( main
  ) where

import ApiContractTH (assertAbstractTypes, assertExactArgumentConstructors)
import qualified O2I.Inspection.Cardinality as Cardinality
import qualified O2I.Inspection.Diagnostic as Diagnostic
import qualified O2I.Inspection.Import as Import
import qualified O2I.Inspection.Input as Input
import qualified O2I.Inspection.Pipeline as Pipeline
import qualified O2I.Inspection.Profile as Profile
import qualified O2I.Inspection.Provenance as Provenance
import qualified O2I.Inspection.Report as Report
import qualified O2I.Inspection.Scope as Scope

$(assertAbstractTypes
    [ "Cardinality.AtLeastTwo"
    , "Import.ImportedGraph"
    , "Input.SourceDocument"
    , "Pipeline.StructurallyClosedModel"
    , "Pipeline.SemanticsWitness"
    , "Pipeline.ReadinessWitness"
    , "Pipeline.EvidenceWitness"
    , "Profile.IndexedProfileFact"
    , "Profile.ProfileSnapshot"
    , "Profile.ResolvedProfileProjection"
    , "Profile.ProfileIndex"
    , "Provenance.SourceHash"
    , "Provenance.PathStep"
    , "Provenance.SourceSpan"
    , "Provenance.Provenance"
    , "Report.StageReports"
    , "Report.InspectionReport"
    , "Scope.SemanticallyClosedScope"
    ])

$(assertExactArgumentConstructors
    [ ( 'Diagnostic.structuralDefectSpec
      , [ "DuplicateNodeId"
        , "DuplicateEdge"
        , "UnknownOwner"
        , "InvalidPrimitiveInterpretation"
        , "InvalidStructuringContext"
        , "UnknownEdgeEndpoint"
        , "UnknownRelation"
        , "InvalidRelationEndpointKinds"
        , "PerformanceDimensionMembershipOwnerMismatch"
        ])
    , ( 'Diagnostic.semanticDefectSpec
      , [ "EthosWithoutPrinciple"
        , "MissionWithoutDriver"
        , "MissionWithoutEthosGuidance"
        , "VisionWithoutObjective"
        , "VisionWithoutMissionGrounding"
        , "VisionWithoutEthosGuidance"
        , "StrategyIntentWithoutVisionOrientation"
        , "SituationWithoutConstitutingAnchor"
        , "NeedWithoutDriver"
        , "NeedWithoutObjective"
        , "NeedWithoutSurfacingSituation"
        , "UnanchoredNeedDriver"
        , "UngroundedNeedObjective"
        , "InterventionWithoutAction"
        , "InterventionWithoutKeyResult"
        , "InterventionWithoutActionContribution"
        , "MeasureWithoutPerformanceDimension"
        , "MeasureWithoutKPI"
        , "MeasureWithoutKPIDimensionMembership"
        , "StrategyWithoutFormulation"
        , "DuplicateStrategyFormulation"
        , "UnknownFormulationStrategy"
        , "FormulationForNonStrategy"
        , "EmptyStrategyText"
        , "DuplicateStrategyPrimitiveReference"
        , "InvalidStrategyPrimitiveReference"
        , "StrategyActionWithoutKeyResult"
        , "MissingStrategyCoherence"
        ])
    , ( 'Diagnostic.traceabilityDefectSpec
      , [ "NoIntervention"
        , "InterventionWithoutNeed"
        , "MissingMacroEvidence"
        , "MissingEffectTrace"
        ])
    , ( 'Diagnostic.readinessDefectSpec
      , [ "UnknownKPIDefinition"
        , "DuplicateKPIDefinition"
        , "ConflictingKPIDefinition"
        , "MissingKPIDefinition"
        , "InvalidKPIValueDomain"
        , "EmptyKPIUnit"
        , "EmptyKPIMeasurementMethod"
        , "EmptyKPIInterpretation"
        , "UnknownPlannedInterventionStart"
        , "DuplicatePlannedInterventionStart"
        , "MissingPlannedInterventionStart"
        , "ReadinessCheckedAtOrAfterPlannedStart"
        , "UnknownEvidencePlanTrace"
        , "DuplicateEvidencePlan"
        , "MissingEvidencePlan"
        , "PlanEstablishedAfterCheck"
        , "BaselineObservedAfterCheck"
        , "InvalidTargetDueDate"
        , "BaselineKPIMismatch"
        , "BaselineAnchorMismatch"
        , "InvalidEffectCriterion"
        , "RelativeEffectCriterionWithZeroBaseline"
        , "InvalidTargetCriterion"
        , "BaselineLevelOutsideDomain"
        , "EffectCriterionOutsideDomain"
        , "TargetCriterionOutsideDomain"
        , "EmptyPlanSource"
        , "EmptyBaselineSource"
        ])
    , ( 'Diagnostic.evidenceDefectSpec
      , [ "UnknownActualInterventionStart"
        , "DuplicateActualInterventionStart"
        , "MissingActualInterventionStart"
        , "ActualInterventionStartAtOrBeforeReadiness"
        , "ActualInterventionStartAtOrAfterAssessment"
        , "UnknownFollowUpTrace"
        , "DuplicateFollowUpObservation"
        , "MissingFollowUpObservation"
        , "FollowUpKPIMismatch"
        , "FollowUpAnchorMismatch"
        , "FollowUpLevelOutsideDomain"
        , "FollowUpObservedAtOrBeforeActualStart"
        , "FollowUpObservedAfterAssessment"
        , "EmptyFollowUpSource"
        ])
    ])

main :: IO ()
main = pure ()
