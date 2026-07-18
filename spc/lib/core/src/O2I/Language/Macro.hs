{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

-- | Canonical evidence rules for O2I context macrorelations.
--
-- This module is the sole semantic registry for macrorelation premises. The
-- graph interpreter uses the rules conservatively for scope discovery, while
-- trace validation interprets the same rules exactly. Notation adapters do not
-- define or extend this registry.
module O2I.Language.Macro
  ( StrategyPrimitiveRole(..)
  , MacroContextRef(..)
  , MacroRelation(..)
  , MacroClaim(..)
  , ClaimSide(..)
  , MacroNodeSelector(..)
  , MacroRelationPattern(..)
  , MacroPremise(..)
  , PremiseAlternative(..)
  , MacroEvidenceRule(..)
  , macroEvidenceRules
  , macroEvidenceRuleConclusion
  , macroClaimConclusion
  , lookupMacroEvidenceRule
  ) where

import Data.List (find)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import O2I.Language.Element
import O2I.Language.Relation

-- | Primitive roles required by a complete Strategy formulation.
--
-- The conservative scope interpreter deliberately ignores these role
-- refinements and retains every persisted primitive of the required type. The
-- exact interpreter accepts only references selected by the validated Strategy
-- formulation.
data StrategyPrimitiveRole
  = DiagnosisRole -- ^ Driver expressing the decisive challenge.
  | IntentRole -- ^ Objective expressing the intended contribution.
  | GuidingPolicyRole -- ^ Principle expressing the chosen approach.
  | CoherentActionRole -- ^ Action expressing a strategic commitment.
  | StrategicKeyResultRole -- ^ Key Result expressing strategic evidence.
  deriving (Eq, Ord, Show)

-- | One occurrence of a Context whose type is retained at the type level.
data MacroContextRef node (context :: Context) =
  MacroContextRef node RawNodeId (SContext context)

-- | A registered context macrorelation with statically aligned endpoints.
data MacroRelation (from :: Context) (to :: Context) = MacroRelation
  { registeredMacroCode :: RelationCode
  , registeredMacroRule :: MacroEvidenceRule
  , registeredMacroFrom :: SContext from
  , registeredMacroTo :: SContext to
  }

-- | Kind-consistent occurrence-level claim of one registered macrorelation.
--
-- Values are reified only from raw context occurrences and a relation in the
-- canonical O2I registry. The constructor remains internal to the core.
data MacroClaim node where
  RegisteredMacroClaim
    :: MacroContextRef node from
    -> MacroRelation from to
    -> MacroContextRef node to
    -> MacroClaim node

-- | Select one endpoint Context of a macrorelation claim.
data ClaimSide
  = ClaimSource
  | ClaimTarget
  deriving (Eq, Ord, Show)

-- | A bound node position in one declarative premise pattern.
--
-- Repeated selectors denote the same node in an exact witness. A Strategy role
-- refines exact matching but never narrows conservative scope discovery.
data MacroNodeSelector
  = ClaimContext ClaimSide
  | OwnedPrimitive ClaimSide Primitive (Maybe StrategyPrimitiveRole)
  | OwnedPerformanceDimension ClaimSide PerformanceDimensionRoleCode
  | ConstituentAnchor ClaimSide
  deriving (Eq, Ord, Show)

-- | A registered relation required by one premise.
data MacroRelationPattern
  = ExactRelation RelationCode
  | AnchorRelationFamilyPattern AnchorRelationFamily
  deriving (Eq, Ord, Show)

-- | One directed relation pattern between two bound node positions.
data MacroPremise = MacroPremise
  { premiseSource :: MacroNodeSelector
  , premiseRelation :: MacroRelationPattern
  , premiseTarget :: MacroNodeSelector
  } deriving (Eq, Ord, Show)

-- | One complete alternative that can substantiate a macrorelation.
newtype PremiseAlternative = PremiseAlternative
  { alternativePremises :: NonEmpty MacroPremise
  } deriving (Eq, Ord, Show)

-- | Canonical finite evidence rule for one registered context macrorelation.
data MacroEvidenceRule = MacroEvidenceRule
  { ruleConclusion :: RelationCode
  , ruleAlternatives :: NonEmpty PremiseAlternative
  } deriving (Eq, Ord, Show)

-- | Project the registered macrorelation concluded by a rule.
macroEvidenceRuleConclusion :: MacroEvidenceRule -> RelationCode
macroEvidenceRuleConclusion = ruleConclusion

-- | Project the registered macrorelation represented by a typed claim.
macroClaimConclusion :: MacroClaim node -> RelationCode
macroClaimConclusion (RegisteredMacroClaim _ relation _) =
  registeredMacroCode relation

-- | Resolve the unique canonical rule for a relation code.
lookupMacroEvidenceRule :: RelationCode -> Maybe MacroEvidenceRule
lookupMacroEvidenceRule code =
  find
    ((== code) . macroEvidenceRuleConclusion)
    (NonEmpty.toList macroEvidenceRules)

-- | Complete registry containing exactly one rule per O2I macrorelation.
macroEvidenceRules :: NonEmpty MacroEvidenceRule
macroEvidenceRules =
  rule
    GuidesMissionCode
    (premise
       ethosPrinciple
       GuidesEthosPrincipleToMissionDriverCode
       missionDriver
       :| [])
    :| [ rule
           GroundsVisionCode
           (premise
              sourceMissionDriver
              GroundsMissionDriverToVisionObjectiveCode
              visionObjective
              :| [])
       , rule
           GuidesVisionCode
           (premise
              ethosPrinciple
              GuidesEthosPrincipleToVisionObjectiveCode
              visionObjective
              :| [])
       , rule
           OrientsStrategyCode
           (premise
              sourceVisionObjective
              OrientsVisionObjectiveToStrategyObjectiveCode
              strategyIntent
              :| [])
       , rule
           DirectsStrategyCode
           (premise
              sourceStrategyPolicy
              GuidesStrategyPrincipleToPrincipleCode
              targetStrategyPolicy
              :| [])
       , alternativesRule
           ContributesToStrategyCode
           ((premise
               sourceStrategyKeyResult
               ContributesStrategyKeyResultToKeyResultCode
               targetStrategyKeyResult
               :| [])
              :| [ premise
                     sourceStrategyAction
                     ContributesStrategyActionToActionCode
                     targetStrategyAction
                     :| []
                 ])
       , rule
           QualifiesNeedCode
           (premise
              sourceStrategyKeyResult
              TranslatesStrategyKeyResultToNeedObjectiveCode
              needObjective
              :| [])
       , rule
           SurfacesNeedCode
           (anchorPremise
              (ClaimContext ClaimSource)
              ConstitutedByAnchorFamily
              (ConstituentAnchor ClaimSource)
              :| [ anchorPremise
                     (ConstituentAnchor ClaimSource)
                     AnchorsNeedDriverFamily
                     needDriver
                 ])
       , rule
           AddressesNeedCode
           (premise
              interventionKeyResult
              SubstantiatesInterventionKeyResultNeedObjectiveCode
              needObjective
              :| [])
       , rule
           DirectsInterventionCode
           (premise
              sourceStrategyAction
              GuidesStrategyActionToInterventionActionCode
              targetInterventionAction
              :| [])
       , rule
           ChangesSituationCode
           (anchorPremise
              (ClaimContext ClaimTarget)
              ConstitutedByAnchorFamily
              (ConstituentAnchor ClaimTarget)
              :| [ anchorPremise
                     sourceInterventionAction
                     ChangesAnchorFamily
                     (ConstituentAnchor ClaimTarget)
                 ])
       , rule
           SetsTargetForMeasureCode
           (premise interventionKeyResult SetsTargetForMeasureKPICode measureKPI
              :| [])
       , rule
           MeasuresSituationCode
           (anchorPremise
              (ClaimContext ClaimTarget)
              ConstitutedByAnchorFamily
              (ConstituentAnchor ClaimTarget)
              :| [ anchorPremise
                     sourceMeasureKPI
                     MeasuresAnchorFamily
                     (ConstituentAnchor ClaimTarget)
                 ])
       , rule
           FramesMeasureCode
           (premise
              sourceStrategyDiagnosis
              IndicatesMeasurePerformanceDimensionCode
              measureDimension
              :| [ premise
                     sourceStrategyKeyResult
                     DeterminesMeasurePerformanceDimensionCode
                     measureDimension
                 , MacroPremise
                     measureDimension
                     (ExactRelation
                        (PerformanceDimensionMembership
                           MeasureMeasurementDimensionCode))
                     measureKPI
                 ])
       ]
  where
    ethosPrinciple = owned ClaimSource Principle Nothing
    missionDriver = owned ClaimTarget Driver Nothing
    sourceMissionDriver = owned ClaimSource Driver Nothing
    visionObjective = owned ClaimTarget Objective Nothing
    sourceVisionObjective = owned ClaimSource Objective Nothing
    strategyIntent = owned ClaimTarget Objective (Just IntentRole)
    sourceStrategyPolicy = owned ClaimSource Principle (Just GuidingPolicyRole)
    targetStrategyPolicy = owned ClaimTarget Principle (Just GuidingPolicyRole)
    sourceStrategyKeyResult =
      owned ClaimSource KeyResult (Just StrategicKeyResultRole)
    targetStrategyKeyResult =
      owned ClaimTarget KeyResult (Just StrategicKeyResultRole)
    sourceStrategyAction = owned ClaimSource Action (Just CoherentActionRole)
    targetStrategyAction = owned ClaimTarget Action (Just CoherentActionRole)
    sourceStrategyDiagnosis = owned ClaimSource Driver (Just DiagnosisRole)
    needDriver = owned ClaimTarget Driver Nothing
    needObjective = owned ClaimTarget Objective Nothing
    sourceInterventionAction = owned ClaimSource Action Nothing
    targetInterventionAction = owned ClaimTarget Action Nothing
    interventionKeyResult = owned ClaimSource KeyResult Nothing
    measureKPI = owned ClaimTarget KPI Nothing
    sourceMeasureKPI = owned ClaimSource KPI Nothing
    measureDimension =
      OwnedPerformanceDimension ClaimTarget MeasureMeasurementDimensionCode

rule :: FixedRelationCode -> NonEmpty MacroPremise -> MacroEvidenceRule
rule code premises = alternativesRule code (premises :| [])

alternativesRule ::
     FixedRelationCode -> NonEmpty (NonEmpty MacroPremise) -> MacroEvidenceRule
alternativesRule code premiseLists =
  MacroEvidenceRule (FixedRelation code) (fmap PremiseAlternative premiseLists)

premise ::
     MacroNodeSelector -> FixedRelationCode -> MacroNodeSelector -> MacroPremise
premise source code target =
  MacroPremise source (ExactRelation (FixedRelation code)) target

anchorPremise ::
     MacroNodeSelector
  -> AnchorRelationFamily
  -> MacroNodeSelector
  -> MacroPremise
anchorPremise source family target =
  MacroPremise source (AnchorRelationFamilyPattern family) target

owned ::
     ClaimSide -> Primitive -> Maybe StrategyPrimitiveRole -> MacroNodeSelector
owned = OwnedPrimitive
