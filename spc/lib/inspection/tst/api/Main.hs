{-# LANGUAGE TemplateHaskell #-}

-- | External-client opacity contracts for Inspection artifacts.
module Main
  ( main
  ) where

import ApiContractTH
  ( assertAbstractTypes
  , assertExactArgumentConstructors
  , assertHiddenValues
  , assertOrdinaryFunctions
  )
import Control.Monad (forM_, unless)
import Data.List (isInfixOf)
import qualified O2I.Inspection.Adapter as Adapter
import qualified O2I.Inspection.Cardinality as Cardinality
import qualified O2I.Inspection.Diagnostic as Diagnostic
import qualified O2I.Inspection.Import as Import
import qualified O2I.Inspection.Input as Input
import qualified O2I.Inspection.Pipeline as Pipeline
import qualified O2I.Inspection.Profile as Profile
import qualified O2I.Inspection.Provenance as Provenance
import qualified O2I.Inspection.Report as Report
import qualified O2I.Inspection.Scope as Scope
import System.Exit (ExitCode(..))
import System.Process (readProcessWithExitCode)

$(assertAbstractTypes
    [ "Cardinality.AtLeastTwo"
    , "Adapter.AdapterDescriptor"
    , "Adapter.NativeVersion"
    , "Diagnostic.DiagnosticCode"
    , "Diagnostic.DiagnosticId"
    , "Diagnostic.DiagnosticSpec"
    , "Diagnostic.Diagnostic"
    , "Import.ImportedGraph"
    , "Input.SourceDocument"
    , "Pipeline.StructurallyClosedModel"
    , "Pipeline.SemanticsWitness"
    , "Pipeline.ReadinessWitness"
    , "Pipeline.EvidenceWitness"
    , "Profile.IndexedProfileFact"
    , "Profile.O2IProfileVersion"
    , "Profile.ProfileSnapshot"
    , "Profile.ResolvedProfileProjection"
    , "Profile.ProfileIndex"
    , "Provenance.SourceHash"
    , "Provenance.ExpandedQName"
    , "Provenance.PathStep"
    , "Provenance.SourceSpan"
    , "Provenance.Provenance"
    , "Report.StageReports"
    , "Report.InspectionReport"
    , "Scope.SemanticallyClosedScope"
    ])

$(assertHiddenValues
    [ "Diagnostic.diagnosticFromSpec"
    , "Diagnostic.diagnosticFromLocated"
    , "Diagnostic.diagnosticsFromLocated"
    , "Diagnostic.diagnosticWithSupplementalSources"
    , "Diagnostic.normalizeDiagnostics"
    , "Report.nativeAdapterBinding"
    ])

$(assertOrdinaryFunctions
    [ 'Adapter.adapterIdentifier
    , 'Adapter.adapterName
    , 'Adapter.adapterVersion
    , 'Adapter.nativeVersionText
    , 'Diagnostic.diagnosticCodeText
    , 'Diagnostic.diagnosticIdText
    , 'Diagnostic.specCode
    , 'Diagnostic.specSeverity
    , 'Diagnostic.specDisposition
    , 'Diagnostic.specMessage
    , 'Diagnostic.specSubjects
    , 'Diagnostic.specData
    , 'Diagnostic.diagnosticId
    , 'Diagnostic.diagnosticCode
    , 'Diagnostic.diagnosticStage
    , 'Diagnostic.diagnosticSeverity
    , 'Diagnostic.diagnosticDisposition
    , 'Diagnostic.diagnosticMessage
    , 'Diagnostic.diagnosticSubjects
    , 'Diagnostic.diagnosticLocations
    , 'Diagnostic.diagnosticSupplementalSources
    , 'Diagnostic.diagnosticData
    , 'Profile.profileVersionText
    , 'Provenance.qNameNamespace
    , 'Provenance.qNameLocalName
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
main = forM_ compileFailContracts runCompileFailContract

data CompileFailContract =
  CompileFailContract String FilePath [String]

runCompileFailContract :: CompileFailContract -> IO ()
runCompileFailContract (CompileFailContract label source names) = do
  (exitCode, standardOutput, standardError) <-
    readProcessWithExitCode
      "cabal"
      [ "exec"
      , "--"
      , "ghc"
      , "-v0"
      , "-fno-code"
      , "-fforce-recomp"
      , "-fmax-errors=100"
      , "-package"
      , "o2i-inspection"
      , source
      ]
      ""
  let output = standardOutput ++ standardError
  case exitCode of
    ExitSuccess -> fail (label ++ " unexpectedly compiled")
    ExitFailure _ ->
      forM_
        names
        (\name ->
           unless
             (name `isInfixOf` output)
             (fail (label ++ " did not reject " ++ name)))

compileFailContracts :: [CompileFailContract]
compileFailContracts =
  [ CompileFailContract
      "Inspection opaque constructors"
      "tst/api/compile-fail/OpaqueConstructors.hs"
      [ "Adapter.AdapterDescriptor"
      , "Adapter.NativeVersion"
      , "Diagnostic.DiagnosticCode"
      , "Diagnostic.DiagnosticId"
      , "Diagnostic.DiagnosticSpec"
      , "Diagnostic.Diagnostic"
      , "Profile.O2IProfileVersion"
      , "Provenance.ExpandedQName"
      ]
  , CompileFailContract
      "Inspection-owned diagnostic normalization"
      "tst/api/compile-fail/HiddenNormalization.hs"
      [ "Diagnostic.diagnosticFromSpec"
      , "Diagnostic.diagnosticFromLocated"
      , "Diagnostic.diagnosticsFromLocated"
      , "Diagnostic.diagnosticWithSupplementalSources"
      , "Diagnostic.normalizeDiagnostics"
      , "Report.nativeAdapterBinding"
      ]
  ]
