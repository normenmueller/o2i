{-# LANGUAGE DataKinds #-}

module MacroVocabulary where

import O2I.Language.Element
import O2I.Language.Macro
import O2I.Language.Relation

readableSingleAlternative :: AlternativeShape 'Ethos 'Mission
readableSingleAlternative =
  Single
    (SourcePrimitiveSelector SEthos SPrinciple)
    guidesEthosPrincipleToMissionDriver
    (TargetPrimitiveSelector SMission SDriver)

readableJoinedAlternative :: AlternativeShape 'Strategy 'Measure
readableJoinedAlternative =
  JoinedChainWithTail
    (SourceStrategyRoleSelector StrategyDiagnosisRole)
    indicatesMeasurePerformanceDimension
    (TargetPerformanceDimensionSelector MeasureMeasurementDimension)
    (SourceStrategyRoleSelector StrategyKeyResultRole)
    determinesMeasurePerformanceDimension
    (containsPerformanceDimension MeasureMeasurementDimension)
    (TargetPrimitiveSelector SMeasure SKPI)

conservativeProjection :: PremiseAlternative
conservativeProjection = conservativeAlternative readableJoinedAlternative
