{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

-- | Canonical closed vocabulary of O2I context macrorelations.
--
-- The endpoint-indexed 'MacroRelation' GADT is the sole registry authority.
-- Total functions derive relation metadata, evidence alternatives, typed
-- claims, conservative discovery rules, and executable relational plans.
module O2I.Language.Macro
  ( StrategyPrimitiveRole(..)
  , TypedStrategyRole(..)
  , typedStrategyRoleCode
  , MacroContextRef(..)
  , MacroRelation(..)
  , SomeMacroRelation(..)
  , MacroClaim(..)
  , ClaimSide(..)
  , MacroNodeSelector(..)
  , MacroRelationPattern(..)
  , MacroPremise(..)
  , PremiseAlternative(..)
  , TypedMacroSelector(..)
  , TypedMacroPremise(..)
  , AlternativeShape(..)
  , typedAlternativePremises
  , conservativeAlternative
  , instantiateAlternative
  , TypedMacroEvidenceRule(..)
  , MacroEvidenceRule(..)
  , macroEvidenceRules
  , allMacroRelations
  , macroRelationsForName
  , macroEvidenceRuleConclusion
  , macroClaimConclusion
  , lookupMacroRelation
  , lookupMacroEvidenceRule
  , registeredMacroCode
  , registeredMacroRule
  , registeredMacroFrom
  , registeredMacroTo
  , ruleAlternatives
  , eraseTypedSelector
  , typedSelectorKind
  ) where

import Data.List (find)
import Data.List.NonEmpty (NonEmpty((:|)))
import qualified Data.List.NonEmpty as NonEmpty
import O2I.Language.Element
import O2I.Language.Macro.Alternative
import O2I.Language.Relation hiding (MacroRelation)

-- | One occurrence of a Context whose type is retained at the type level.
data MacroContextRef node (context :: Context) =
  MacroContextRef node RawNodeId (SContext context)

-- | Closed endpoint-indexed context macrorelation vocabulary.
data MacroRelation (from :: Context) (to :: Context) where
  GuidesMissionMacro :: MacroRelation 'Ethos 'Mission
  GroundsVisionMacro :: MacroRelation 'Mission 'Vision
  GuidesVisionMacro :: MacroRelation 'Ethos 'Vision
  OrientsStrategyMacro :: MacroRelation 'Vision 'Strategy
  DirectsStrategyMacro :: MacroRelation 'Strategy 'Strategy
  ContributesToStrategyMacro :: MacroRelation 'Strategy 'Strategy
  QualifiesNeedMacro :: MacroRelation 'Strategy 'Need
  SurfacesNeedMacro :: MacroRelation 'Situation 'Need
  AddressesNeedMacro :: MacroRelation 'Intervention 'Need
  DirectsInterventionMacro :: MacroRelation 'Strategy 'Intervention
  ChangesSituationMacro :: MacroRelation 'Intervention 'Situation
  SetsTargetForMeasureMacro :: MacroRelation 'Intervention 'Measure
  MeasuresSituationMacro :: MacroRelation 'Measure 'Situation
  FramesMeasureMacro :: MacroRelation 'Strategy 'Measure

-- | Existential package used only to enumerate the closed vocabulary.
data SomeMacroRelation where
  SomeMacroRelation :: MacroRelation from to -> SomeMacroRelation

-- | Kind-consistent occurrence-level claim of one registered macrorelation.
data MacroClaim node where
  RegisteredMacroClaim
    :: MacroContextRef node from
    -> MacroRelation from to
    -> MacroContextRef node to
    -> MacroClaim node

-- | Canonical endpoint-typed rule projected from one closed relation.
data TypedMacroEvidenceRule (from :: Context) (to :: Context) = TypedMacroEvidenceRule
  { typedRuleConclusion :: Relation ('ContextKind from) ('ContextKind to)
  , typedRuleAlternatives :: NonEmpty (AlternativeShape from to)
  }

-- | Opaque existential public projection of one endpoint-typed rule.
data MacroEvidenceRule where
  MacroEvidenceRule :: MacroRelation from to -> MacroEvidenceRule

instance Eq MacroEvidenceRule where
  left == right =
    macroEvidenceRuleConclusion left == macroEvidenceRuleConclusion right
      && ruleAlternatives left == ruleAlternatives right

instance Ord MacroEvidenceRule where
  compare left right =
    compare
      (macroEvidenceRuleConclusion left, ruleAlternatives left)
      (macroEvidenceRuleConclusion right, ruleAlternatives right)

instance Show MacroEvidenceRule where
  show rule =
    "MacroEvidenceRule "
      ++ show (macroEvidenceRuleConclusion rule)
      ++ " "
      ++ show (ruleAlternatives rule)

-- | Enumerate every constructor of the closed vocabulary exactly once.
allMacroRelations :: NonEmpty SomeMacroRelation
allMacroRelations =
  SomeMacroRelation GuidesMissionMacro
    :| [ SomeMacroRelation GroundsVisionMacro
       , SomeMacroRelation GuidesVisionMacro
       , SomeMacroRelation OrientsStrategyMacro
       , SomeMacroRelation DirectsStrategyMacro
       , SomeMacroRelation ContributesToStrategyMacro
       , SomeMacroRelation QualifiesNeedMacro
       , SomeMacroRelation SurfacesNeedMacro
       , SomeMacroRelation AddressesNeedMacro
       , SomeMacroRelation DirectsInterventionMacro
       , SomeMacroRelation ChangesSituationMacro
       , SomeMacroRelation SetsTargetForMeasureMacro
       , SomeMacroRelation MeasuresSituationMacro
       , SomeMacroRelation FramesMeasureMacro
       ]

-- | Complete public rule projection in stable relation order.
macroEvidenceRules :: NonEmpty MacroEvidenceRule
macroEvidenceRules = fmap project allMacroRelations
  where
    project (SomeMacroRelation relation) = MacroEvidenceRule relation

-- | Select registered relations sharing one persisted relation name.
macroRelationsForName :: RelationName -> [SomeMacroRelation]
macroRelationsForName name =
  [ candidate
  | candidate@(SomeMacroRelation relation) <- NonEmpty.toList allMacroRelations
  , relationNameFor (macroRelationConclusion relation) == name
  ]

-- | Resolve one stable relation code to its typed closed constructor.
lookupMacroRelation :: RelationCode -> Maybe SomeMacroRelation
lookupMacroRelation code = find matches (NonEmpty.toList allMacroRelations)
  where
    matches (SomeMacroRelation relation) = registeredMacroCode relation == code

-- | Resolve the unique public rule projection for a relation code.
lookupMacroEvidenceRule :: RelationCode -> Maybe MacroEvidenceRule
lookupMacroEvidenceRule code = do
  SomeMacroRelation relation <- lookupMacroRelation code
  pure (MacroEvidenceRule relation)

-- | Project the stable code of one typed macrorelation.
registeredMacroCode :: MacroRelation from to -> RelationCode
registeredMacroCode = relationCode . relationSpec . macroRelationConclusion

-- | Project the complete typed rule from the closed vocabulary.
registeredMacroRule :: MacroRelation from to -> TypedMacroEvidenceRule from to
registeredMacroRule relation =
  TypedMacroEvidenceRule
    { typedRuleConclusion = macroRelationConclusion relation
    , typedRuleAlternatives = macroRelationAlternatives relation
    }

-- | Project the source Context witness.
registeredMacroFrom :: MacroRelation from to -> SContext from
registeredMacroFrom relation =
  case relationFrom (relationSpec (macroRelationConclusion relation)) of
    SContextKind context -> context

-- | Project the target Context witness.
registeredMacroTo :: MacroRelation from to -> SContext to
registeredMacroTo relation =
  case relationTo (relationSpec (macroRelationConclusion relation)) of
    SContextKind context -> context

-- | Project the registered macrorelation represented by a public rule.
macroEvidenceRuleConclusion :: MacroEvidenceRule -> RelationCode
macroEvidenceRuleConclusion (MacroEvidenceRule relation) =
  registeredMacroCode relation

-- | Project the registered macrorelation represented by a typed claim.
macroClaimConclusion :: MacroClaim node -> RelationCode
macroClaimConclusion (RegisteredMacroClaim _ relation _) =
  registeredMacroCode relation

-- | Derive conservative raw premises from the same closed alternatives.
ruleAlternatives :: MacroEvidenceRule -> NonEmpty PremiseAlternative
ruleAlternatives (MacroEvidenceRule relation) =
  fmap conservativeAlternative (macroRelationAlternatives relation)

macroRelationConclusion ::
     MacroRelation from to -> Relation ('ContextKind from) ('ContextKind to)
macroRelationConclusion relation =
  case relation of
    GuidesMissionMacro -> guidesMission
    GroundsVisionMacro -> groundsVision
    GuidesVisionMacro -> guidesVision
    OrientsStrategyMacro -> orientsStrategy
    DirectsStrategyMacro -> directsStrategy
    ContributesToStrategyMacro -> contributesToStrategy
    QualifiesNeedMacro -> qualifiesNeed
    SurfacesNeedMacro -> surfacesNeed
    AddressesNeedMacro -> addressesNeed
    DirectsInterventionMacro -> directsIntervention
    ChangesSituationMacro -> changesSituation
    SetsTargetForMeasureMacro -> setsTargetForMeasure
    MeasuresSituationMacro -> measuresSituation
    FramesMeasureMacro -> framesMeasure

macroRelationAlternatives ::
     MacroRelation from to -> NonEmpty (AlternativeShape from to)
macroRelationAlternatives relation =
  case relation of
    GuidesMissionMacro ->
      one
        (Single
           (sourcePrimitive SEthos SPrinciple)
           guidesEthosPrincipleToMissionDriver
           (targetPrimitive SMission SDriver))
    GroundsVisionMacro ->
      one
        (Single
           (sourcePrimitive SMission SDriver)
           groundsMissionDriverToVisionObjective
           (targetPrimitive SVision SObjective))
    GuidesVisionMacro ->
      one
        (Single
           (sourcePrimitive SEthos SPrinciple)
           guidesEthosPrincipleToVisionObjective
           (targetPrimitive SVision SObjective))
    OrientsStrategyMacro ->
      one
        (Single
           (sourcePrimitive SVision SObjective)
           orientsVisionObjectiveToStrategyObjective
           (targetStrategy StrategyIntentRole))
    DirectsStrategyMacro ->
      one
        (Single
           (sourceStrategy StrategyGuidingPolicyRole)
           guidesStrategyPrincipleToPrinciple
           (targetStrategy StrategyGuidingPolicyRole))
    ContributesToStrategyMacro ->
      Single
        (sourceStrategy StrategyKeyResultRole)
        contributesStrategyKeyResultToKeyResult
        (targetStrategy StrategyKeyResultRole)
        :| [ Single
               (sourceStrategy StrategyCoherentActionRole)
               contributesStrategyActionToAction
               (targetStrategy StrategyCoherentActionRole)
           ]
    QualifiesNeedMacro ->
      one
        (Single
           (sourceStrategy StrategyKeyResultRole)
           translatesStrategyKeyResultToNeedObjective
           (targetPrimitive SNeed SObjective))
    SurfacesNeedMacro -> fmap surfaceAlternative allTypedAnchors
    AddressesNeedMacro ->
      one
        (Single
           (sourcePrimitive SIntervention SKeyResult)
           substantiatesInterventionKeyResultNeedObjective
           (targetPrimitive SNeed SObjective))
    DirectsInterventionMacro ->
      one
        (Single
           (sourceStrategy StrategyCoherentActionRole)
           guidesStrategyActionToInterventionAction
           (targetPrimitive SIntervention SAction))
    ChangesSituationMacro -> fmap changeAlternative allTypedAnchors
    SetsTargetForMeasureMacro ->
      one
        (Single
           (sourcePrimitive SIntervention SKeyResult)
           setsTargetForMeasureKPI
           (targetPrimitive SMeasure SKPI))
    MeasuresSituationMacro -> fmap measureAlternative allTypedAnchors
    FramesMeasureMacro -> one frameMeasureAlternative
  where
    one alternative = alternative :| []

sourcePrimitive ::
     SContext from
  -> SPrimitive primitive
  -> TypedMacroSelector from to ('PrimitiveKind from primitive)
sourcePrimitive = SourcePrimitiveSelector

targetPrimitive ::
     SContext to
  -> SPrimitive primitive
  -> TypedMacroSelector from to ('PrimitiveKind to primitive)
targetPrimitive = TargetPrimitiveSelector

sourceStrategy ::
     TypedStrategyRole primitive
  -> TypedMacroSelector 'Strategy to ('PrimitiveKind 'Strategy primitive)
sourceStrategy = SourceStrategyRoleSelector

targetStrategy ::
     TypedStrategyRole primitive
  -> TypedMacroSelector from 'Strategy ('PrimitiveKind 'Strategy primitive)
targetStrategy = TargetStrategyRoleSelector

targetDimension ::
     PerformanceDimensionRole to member
  -> TypedMacroSelector from to ('StructuringKind to 'PerformanceDimension)
targetDimension = TargetPerformanceDimensionSelector

allTypedAnchors :: NonEmpty SomeSAnchor
allTypedAnchors =
  SomeSAnchor SBusinessCapability
    :| [ SomeSAnchor SBusinessProcess
       , SomeSAnchor SBusinessObject
       , SomeSAnchor SValueStream
       ]

surfaceAlternative :: SomeSAnchor -> AlternativeShape 'Situation 'Need
surfaceAlternative (SomeSAnchor anchor) =
  ForwardChain
    (SourceContextSelector SSituation)
    (constitutedByAnchor anchor)
    (SourceSituationAnchorSelector anchor)
    (anchorsNeedDriver anchor)
    (targetPrimitive SNeed SDriver)

changeAlternative :: SomeSAnchor -> AlternativeShape 'Intervention 'Situation
changeAlternative (SomeSAnchor anchor) =
  TargetJoin
    (TargetContextSelector SSituation)
    (constitutedByAnchor anchor)
    (TargetSituationAnchorSelector anchor)
    (sourcePrimitive SIntervention SAction)
    (changesAnchor anchor)

measureAlternative :: SomeSAnchor -> AlternativeShape 'Measure 'Situation
measureAlternative (SomeSAnchor anchor) =
  TargetJoin
    (TargetContextSelector SSituation)
    (constitutedByAnchor anchor)
    (TargetSituationAnchorSelector anchor)
    (sourcePrimitive SMeasure SKPI)
    (measuresAnchor anchor)

frameMeasureAlternative :: AlternativeShape 'Strategy 'Measure
frameMeasureAlternative =
  JoinedChainWithTail
    (sourceStrategy StrategyDiagnosisRole)
    indicatesMeasurePerformanceDimension
    (targetDimension MeasureMeasurementDimension)
    (sourceStrategy StrategyKeyResultRole)
    determinesMeasurePerformanceDimension
    (containsPerformanceDimension MeasureMeasurementDimension)
    (targetPrimitive SMeasure SKPI)
