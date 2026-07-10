{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}

-- | Allowed O2I relation types.
module O2I.Relation
  ( Relation(..)
  , SomeRelation(..)
  , RelationKey(..)
  , NodeKindValue(..)
  , NodeKindPattern(..)
  , RelationDomain
  , relationKey
  , relationLabel
  , relationDomain
  , contextDomain
  , primitiveDomain
  , matchesDomain
  ) where

import O2I.Elements

-- * Type-level relations
-- ** Semantic relations
data Relation (from :: NodeKind) (to :: NodeKind)
  -- *** Context macrorelations
 where
  GuidesMission :: Relation (ContextKind Ethos) (ContextKind Mission)
  GroundsVision :: Relation (ContextKind Mission) (ContextKind Vision)
  GuidesVision :: Relation (ContextKind Ethos) (ContextKind Vision)
  OrientsStrategy :: Relation (ContextKind Vision) (ContextKind Strategy)
  DirectsStrategy :: Relation (ContextKind Strategy) (ContextKind Strategy)
  ContributesToStrategy
    :: Relation (ContextKind Strategy) (ContextKind Strategy)
  QualifiesNeed :: Relation (ContextKind Strategy) (ContextKind Need)
  SurfacesNeed :: Relation (ContextKind Situation) (ContextKind Need)
  AddressesNeed :: Relation (ContextKind Intervention) (ContextKind Need)
  DirectsIntervention
    :: Relation (ContextKind Strategy) (ContextKind Intervention)
  ChangesSituation
    :: Relation (ContextKind Intervention) (ContextKind Situation)
  SetsTargetForMeasure
    :: Relation (ContextKind Intervention) (ContextKind Measure)
  MeasuresSituation :: Relation (ContextKind Measure) (ContextKind Situation)
  FramesMeasure :: Relation (ContextKind Strategy) (ContextKind Measure)
  -- *** Situation anchor relations
  ConstitutedByAnchor :: Relation (ContextKind Situation) (AnchorKind anchor)
  -- *** Primitive evidence relations
  -- **** Orientation and strategy evidence
  GuidesEthosPrincipleToMissionDriver
    :: Relation (PrimitiveKind Ethos Principle) (PrimitiveKind Mission Driver)
  GuidesEthosPrincipleToVisionObjective
    :: Relation (PrimitiveKind Ethos Principle) (PrimitiveKind Vision Objective)
  GroundsMissionDriverToVisionObjective
    :: Relation (PrimitiveKind Mission Driver) (PrimitiveKind Vision Objective)
  OrientsVisionObjectiveToStrategyObjective
    :: Relation
         (PrimitiveKind Vision Objective)
         (PrimitiveKind Strategy Objective)
  GroundsStrategyDriverToObjective
    :: Relation
         (PrimitiveKind Strategy Driver)
         (PrimitiveKind Strategy Objective)
  SubstantiatesStrategyKeyResultObjective
    :: Relation
         (PrimitiveKind Strategy KeyResult)
         (PrimitiveKind Strategy Objective)
  GuidesStrategyPrincipleToAction
    :: Relation
         (PrimitiveKind Strategy Principle)
         (PrimitiveKind Strategy Action)
  ContributesStrategyActionToKeyResult
    :: Relation
         (PrimitiveKind Strategy Action)
         (PrimitiveKind Strategy KeyResult)
  GuidesStrategyPrincipleToPrinciple
    :: Relation
         (PrimitiveKind Strategy Principle)
         (PrimitiveKind Strategy Principle)
  ContributesStrategyKeyResultToKeyResult
    :: Relation
         (PrimitiveKind Strategy KeyResult)
         (PrimitiveKind Strategy KeyResult)
  ContributesStrategyActionToAction
    :: Relation (PrimitiveKind Strategy Action) (PrimitiveKind Strategy Action)
  -- **** Need and measurement evidence
  TranslatesStrategyKeyResultToNeedObjective
    :: Relation
         (PrimitiveKind Strategy KeyResult)
         (PrimitiveKind Need Objective)
  GroundsNeedDriverToObjective
    :: Relation (PrimitiveKind Need Driver) (PrimitiveKind Need Objective)
  AnchorsNeedDriver :: Relation (AnchorKind anchor) (PrimitiveKind Need Driver)
  IndicatesMeasureDomain
    :: Relation (PrimitiveKind Strategy Driver) (StructuringKind Measure Domain)
  DeterminesMeasureDomain
    :: Relation
         (PrimitiveKind Strategy KeyResult)
         (StructuringKind Measure Domain)
  ContainsStrategyKeyResult
    :: Relation
         (StructuringKind Strategy Domain)
         (PrimitiveKind Strategy KeyResult)
  ContainsMeasureKPI
    :: Relation (StructuringKind Measure Domain) (PrimitiveKind Measure KPI)
  -- **** Intervention and effect evidence
  GuidesStrategyActionToInterventionAction
    :: Relation
         (PrimitiveKind Strategy Action)
         (PrimitiveKind Intervention Action)
  ContributesInterventionActionToKeyResult
    :: Relation
         (PrimitiveKind Intervention Action)
         (PrimitiveKind Intervention KeyResult)
  SubstantiatesInterventionKeyResultNeedObjective
    :: Relation
         (PrimitiveKind Intervention KeyResult)
         (PrimitiveKind Need Objective)
  ContributesInterventionKeyResultToStrategyKeyResult
    :: Relation
         (PrimitiveKind Intervention KeyResult)
         (PrimitiveKind Strategy KeyResult)
  SetsTargetForMeasureKPI
    :: Relation
         (PrimitiveKind Intervention KeyResult)
         (PrimitiveKind Measure KPI)
  ChangesAnchor
    :: Relation (PrimitiveKind Intervention Action) (AnchorKind anchor)
  MeasuresAnchor :: Relation (PrimitiveKind Measure KPI) (AnchorKind anchor)

-- ** Dynamic relation representation
data SomeRelation where
  SomeRelation :: Relation from to -> SomeRelation

data RelationKey
  = RKGuidesMission
  | RKGroundsVision
  | RKGuidesVision
  | RKOrientsStrategy
  | RKDirectsStrategy
  | RKContributesToStrategy
  | RKQualifiesNeed
  | RKSurfacesNeed
  | RKAddressesNeed
  | RKDirectsIntervention
  | RKChangesSituation
  | RKSetsTargetForMeasure
  | RKMeasuresSituation
  | RKFramesMeasure
  | RKConstitutedByAnchor
  | RKGuidesEthosPrincipleToMissionDriver
  | RKGuidesEthosPrincipleToVisionObjective
  | RKGroundsMissionDriverToVisionObjective
  | RKOrientsVisionObjectiveToStrategyObjective
  | RKGroundsStrategyDriverToObjective
  | RKSubstantiatesStrategyKeyResultObjective
  | RKGuidesStrategyPrincipleToAction
  | RKContributesStrategyActionToKeyResult
  | RKGuidesStrategyPrincipleToPrinciple
  | RKContributesStrategyKeyResultToKeyResult
  | RKContributesStrategyActionToAction
  | RKTranslatesStrategyKeyResultToNeedObjective
  | RKGroundsNeedDriverToObjective
  | RKAnchorsNeedDriver
  | RKIndicatesMeasureDomain
  | RKDeterminesMeasureDomain
  | RKContainsStrategyKeyResult
  | RKContainsMeasureKPI
  | RKGuidesStrategyActionToInterventionAction
  | RKContributesInterventionActionToKeyResult
  | RKSubstantiatesInterventionKeyResultNeedObjective
  | RKContributesInterventionKeyResultToStrategyKeyResult
  | RKSetsTargetForMeasureKPI
  | RKChangesAnchor
  | RKMeasuresAnchor
  deriving (Eq, Show)

instance Eq SomeRelation where
  left == right = relationKey left == relationKey right

instance Show SomeRelation where
  show = relationLabel

data NodeKindValue
  = ContextNodeKind Context
  | PrimitiveNodeKind Context Primitive
  | StructuringNodeKind Context Structuring
  | AnchorNodeKind SituationAnchor
  deriving (Eq, Show)

data NodeKindPattern
  = Exact NodeKindValue
  | AnyAnchor
  deriving (Eq, Show)

type RelationDomain = (NodeKindPattern, NodeKindPattern)

matchesDomain :: RelationDomain -> (NodeKindValue, NodeKindValue) -> Bool
matchesDomain (fromPattern, toPattern) (fromKind, toKind) =
  matchesKind fromPattern fromKind && matchesKind toPattern toKind

matchesKind :: NodeKindPattern -> NodeKindValue -> Bool
matchesKind (Exact expected) actual = expected == actual
matchesKind AnyAnchor (AnchorNodeKind _) = True
matchesKind AnyAnchor _ = False

relationKey :: SomeRelation -> RelationKey
relationKey (SomeRelation GuidesMission) = RKGuidesMission
relationKey (SomeRelation GroundsVision) = RKGroundsVision
relationKey (SomeRelation GuidesVision) = RKGuidesVision
relationKey (SomeRelation OrientsStrategy) = RKOrientsStrategy
relationKey (SomeRelation DirectsStrategy) = RKDirectsStrategy
relationKey (SomeRelation ContributesToStrategy) = RKContributesToStrategy
relationKey (SomeRelation QualifiesNeed) = RKQualifiesNeed
relationKey (SomeRelation SurfacesNeed) = RKSurfacesNeed
relationKey (SomeRelation AddressesNeed) = RKAddressesNeed
relationKey (SomeRelation DirectsIntervention) = RKDirectsIntervention
relationKey (SomeRelation ChangesSituation) = RKChangesSituation
relationKey (SomeRelation SetsTargetForMeasure) = RKSetsTargetForMeasure
relationKey (SomeRelation MeasuresSituation) = RKMeasuresSituation
relationKey (SomeRelation FramesMeasure) = RKFramesMeasure
relationKey (SomeRelation ConstitutedByAnchor) = RKConstitutedByAnchor
relationKey (SomeRelation GuidesEthosPrincipleToMissionDriver) =
  RKGuidesEthosPrincipleToMissionDriver
relationKey (SomeRelation GuidesEthosPrincipleToVisionObjective) =
  RKGuidesEthosPrincipleToVisionObjective
relationKey (SomeRelation GroundsMissionDriverToVisionObjective) =
  RKGroundsMissionDriverToVisionObjective
relationKey (SomeRelation OrientsVisionObjectiveToStrategyObjective) =
  RKOrientsVisionObjectiveToStrategyObjective
relationKey (SomeRelation GroundsStrategyDriverToObjective) =
  RKGroundsStrategyDriverToObjective
relationKey (SomeRelation SubstantiatesStrategyKeyResultObjective) =
  RKSubstantiatesStrategyKeyResultObjective
relationKey (SomeRelation GuidesStrategyPrincipleToAction) =
  RKGuidesStrategyPrincipleToAction
relationKey (SomeRelation ContributesStrategyActionToKeyResult) =
  RKContributesStrategyActionToKeyResult
relationKey (SomeRelation GuidesStrategyPrincipleToPrinciple) =
  RKGuidesStrategyPrincipleToPrinciple
relationKey (SomeRelation ContributesStrategyKeyResultToKeyResult) =
  RKContributesStrategyKeyResultToKeyResult
relationKey (SomeRelation ContributesStrategyActionToAction) =
  RKContributesStrategyActionToAction
relationKey (SomeRelation TranslatesStrategyKeyResultToNeedObjective) =
  RKTranslatesStrategyKeyResultToNeedObjective
relationKey (SomeRelation GroundsNeedDriverToObjective) =
  RKGroundsNeedDriverToObjective
relationKey (SomeRelation AnchorsNeedDriver) = RKAnchorsNeedDriver
relationKey (SomeRelation IndicatesMeasureDomain) = RKIndicatesMeasureDomain
relationKey (SomeRelation DeterminesMeasureDomain) = RKDeterminesMeasureDomain
relationKey (SomeRelation ContainsStrategyKeyResult) =
  RKContainsStrategyKeyResult
relationKey (SomeRelation ContainsMeasureKPI) = RKContainsMeasureKPI
relationKey (SomeRelation GuidesStrategyActionToInterventionAction) =
  RKGuidesStrategyActionToInterventionAction
relationKey (SomeRelation ContributesInterventionActionToKeyResult) =
  RKContributesInterventionActionToKeyResult
relationKey (SomeRelation SubstantiatesInterventionKeyResultNeedObjective) =
  RKSubstantiatesInterventionKeyResultNeedObjective
relationKey (SomeRelation ContributesInterventionKeyResultToStrategyKeyResult) =
  RKContributesInterventionKeyResultToStrategyKeyResult
relationKey (SomeRelation SetsTargetForMeasureKPI) = RKSetsTargetForMeasureKPI
relationKey (SomeRelation ChangesAnchor) = RKChangesAnchor
relationKey (SomeRelation MeasuresAnchor) = RKMeasuresAnchor

relationLabel :: SomeRelation -> String
relationLabel (SomeRelation GuidesMission) = "guides"
relationLabel (SomeRelation GroundsVision) = "grounds"
relationLabel (SomeRelation GuidesVision) = "guides"
relationLabel (SomeRelation OrientsStrategy) = "orients"
relationLabel (SomeRelation DirectsStrategy) = "directs"
relationLabel (SomeRelation ContributesToStrategy) = "contributes-to"
relationLabel (SomeRelation QualifiesNeed) = "qualifies"
relationLabel (SomeRelation SurfacesNeed) = "surfaces"
relationLabel (SomeRelation AddressesNeed) = "addresses"
relationLabel (SomeRelation DirectsIntervention) = "directs"
relationLabel (SomeRelation ChangesSituation) = "changes"
relationLabel (SomeRelation SetsTargetForMeasure) = "sets-target-for"
relationLabel (SomeRelation MeasuresSituation) = "measures"
relationLabel (SomeRelation FramesMeasure) = "frames"
relationLabel (SomeRelation ConstitutedByAnchor) = "is-constituted-by"
relationLabel (SomeRelation GuidesEthosPrincipleToMissionDriver) = "guides"
relationLabel (SomeRelation GuidesEthosPrincipleToVisionObjective) = "guides"
relationLabel (SomeRelation GroundsMissionDriverToVisionObjective) = "grounds"
relationLabel (SomeRelation OrientsVisionObjectiveToStrategyObjective) =
  "orients"
relationLabel (SomeRelation GroundsStrategyDriverToObjective) = "grounds"
relationLabel (SomeRelation SubstantiatesStrategyKeyResultObjective) =
  "substantiates"
relationLabel (SomeRelation GuidesStrategyPrincipleToAction) = "guides"
relationLabel (SomeRelation ContributesStrategyActionToKeyResult) =
  "contributes-to"
relationLabel (SomeRelation GuidesStrategyPrincipleToPrinciple) = "guides"
relationLabel (SomeRelation ContributesStrategyKeyResultToKeyResult) =
  "contributes-to"
relationLabel (SomeRelation ContributesStrategyActionToAction) =
  "contributes-to"
relationLabel (SomeRelation TranslatesStrategyKeyResultToNeedObjective) =
  "translates-into"
relationLabel (SomeRelation GroundsNeedDriverToObjective) = "grounds"
relationLabel (SomeRelation AnchorsNeedDriver) = "anchors"
relationLabel (SomeRelation IndicatesMeasureDomain) = "indicates"
relationLabel (SomeRelation DeterminesMeasureDomain) = "determines"
relationLabel (SomeRelation ContainsStrategyKeyResult) = "contains"
relationLabel (SomeRelation ContainsMeasureKPI) = "contains"
relationLabel (SomeRelation GuidesStrategyActionToInterventionAction) = "guides"
relationLabel (SomeRelation ContributesInterventionActionToKeyResult) =
  "contributes-to"
relationLabel (SomeRelation SubstantiatesInterventionKeyResultNeedObjective) =
  "substantiates"
relationLabel (SomeRelation ContributesInterventionKeyResultToStrategyKeyResult) =
  "contributes-to"
relationLabel (SomeRelation SetsTargetForMeasureKPI) = "sets-target-for"
relationLabel (SomeRelation ChangesAnchor) = "changes"
relationLabel (SomeRelation MeasuresAnchor) = "measures"

relationDomain :: SomeRelation -> RelationDomain
relationDomain (SomeRelation GuidesMission) = contextDomain Ethos Mission
relationDomain (SomeRelation GroundsVision) = contextDomain Mission Vision
relationDomain (SomeRelation GuidesVision) = contextDomain Ethos Vision
relationDomain (SomeRelation OrientsStrategy) = contextDomain Vision Strategy
relationDomain (SomeRelation DirectsStrategy) = contextDomain Strategy Strategy
relationDomain (SomeRelation ContributesToStrategy) =
  contextDomain Strategy Strategy
relationDomain (SomeRelation QualifiesNeed) = contextDomain Strategy Need
relationDomain (SomeRelation SurfacesNeed) = contextDomain Situation Need
relationDomain (SomeRelation AddressesNeed) = contextDomain Intervention Need
relationDomain (SomeRelation DirectsIntervention) =
  contextDomain Strategy Intervention
relationDomain (SomeRelation ChangesSituation) =
  contextDomain Intervention Situation
relationDomain (SomeRelation SetsTargetForMeasure) =
  contextDomain Intervention Measure
relationDomain (SomeRelation MeasuresSituation) =
  contextDomain Measure Situation
relationDomain (SomeRelation FramesMeasure) = contextDomain Strategy Measure
relationDomain (SomeRelation ConstitutedByAnchor) =
  (Exact (ContextNodeKind Situation), AnyAnchor)
relationDomain (SomeRelation GuidesEthosPrincipleToMissionDriver) =
  primitiveDomain Ethos Principle Mission Driver
relationDomain (SomeRelation GuidesEthosPrincipleToVisionObjective) =
  primitiveDomain Ethos Principle Vision Objective
relationDomain (SomeRelation GroundsMissionDriverToVisionObjective) =
  primitiveDomain Mission Driver Vision Objective
relationDomain (SomeRelation OrientsVisionObjectiveToStrategyObjective) =
  primitiveDomain Vision Objective Strategy Objective
relationDomain (SomeRelation GroundsStrategyDriverToObjective) =
  primitiveDomain Strategy Driver Strategy Objective
relationDomain (SomeRelation SubstantiatesStrategyKeyResultObjective) =
  primitiveDomain Strategy KeyResult Strategy Objective
relationDomain (SomeRelation GuidesStrategyPrincipleToAction) =
  primitiveDomain Strategy Principle Strategy Action
relationDomain (SomeRelation ContributesStrategyActionToKeyResult) =
  primitiveDomain Strategy Action Strategy KeyResult
relationDomain (SomeRelation GuidesStrategyPrincipleToPrinciple) =
  primitiveDomain Strategy Principle Strategy Principle
relationDomain (SomeRelation ContributesStrategyKeyResultToKeyResult) =
  primitiveDomain Strategy KeyResult Strategy KeyResult
relationDomain (SomeRelation ContributesStrategyActionToAction) =
  primitiveDomain Strategy Action Strategy Action
relationDomain (SomeRelation TranslatesStrategyKeyResultToNeedObjective) =
  primitiveDomain Strategy KeyResult Need Objective
relationDomain (SomeRelation GroundsNeedDriverToObjective) =
  primitiveDomain Need Driver Need Objective
relationDomain (SomeRelation AnchorsNeedDriver) =
  (AnyAnchor, Exact (PrimitiveNodeKind Need Driver))
relationDomain (SomeRelation IndicatesMeasureDomain) =
  ( Exact (PrimitiveNodeKind Strategy Driver)
  , Exact (StructuringNodeKind Measure Domain))
relationDomain (SomeRelation DeterminesMeasureDomain) =
  ( Exact (PrimitiveNodeKind Strategy KeyResult)
  , Exact (StructuringNodeKind Measure Domain))
relationDomain (SomeRelation ContainsStrategyKeyResult) =
  ( Exact (StructuringNodeKind Strategy Domain)
  , Exact (PrimitiveNodeKind Strategy KeyResult))
relationDomain (SomeRelation ContainsMeasureKPI) =
  ( Exact (StructuringNodeKind Measure Domain)
  , Exact (PrimitiveNodeKind Measure KPI))
relationDomain (SomeRelation GuidesStrategyActionToInterventionAction) =
  primitiveDomain Strategy Action Intervention Action
relationDomain (SomeRelation ContributesInterventionActionToKeyResult) =
  primitiveDomain Intervention Action Intervention KeyResult
relationDomain (SomeRelation SubstantiatesInterventionKeyResultNeedObjective) =
  primitiveDomain Intervention KeyResult Need Objective
relationDomain (SomeRelation ContributesInterventionKeyResultToStrategyKeyResult) =
  primitiveDomain Intervention KeyResult Strategy KeyResult
relationDomain (SomeRelation SetsTargetForMeasureKPI) =
  primitiveDomain Intervention KeyResult Measure KPI
relationDomain (SomeRelation ChangesAnchor) =
  (Exact (PrimitiveNodeKind Intervention Action), AnyAnchor)
relationDomain (SomeRelation MeasuresAnchor) =
  (Exact (PrimitiveNodeKind Measure KPI), AnyAnchor)

contextDomain :: Context -> Context -> RelationDomain
contextDomain from to =
  (Exact (ContextNodeKind from), Exact (ContextNodeKind to))

primitiveDomain ::
     Context -> Primitive -> Context -> Primitive -> RelationDomain
primitiveDomain fromCtx fromPrim toCtx toPrim =
  ( Exact (PrimitiveNodeKind fromCtx fromPrim)
  , Exact (PrimitiveNodeKind toCtx toPrim))
