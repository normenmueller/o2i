{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Typed O2I relations and their total runtime metadata projection.
module O2I.Relation
  ( Relation
  , SomeRelation(..)
  , FixedRelationCode(..)
  , AnchorRelationFamily(..)
  , RelationCode(..)
  , RelationSemantics(..)
  , MacroEvidenceKind(..)
  , RelationName(..)
  , RelationSpec(..)
  , relationSpec
  , relationCodeOf
  , relationSemanticsOf
  , relationNameOf
  , relationNameFor
  , relationIdentity
  , guidesMission
  , groundsVision
  , guidesVision
  , orientsStrategy
  , directsStrategy
  , contributesToStrategy
  , qualifiesNeed
  , surfacesNeed
  , addressesNeed
  , directsIntervention
  , changesSituation
  , setsTargetForMeasure
  , measuresSituation
  , framesMeasure
  , constitutedByAnchor
  , guidesEthosPrincipleToMissionDriver
  , guidesEthosPrincipleToVisionObjective
  , groundsMissionDriverToVisionObjective
  , orientsVisionObjectiveToStrategyObjective
  , groundsStrategyDriverToObjective
  , substantiatesStrategyKeyResultObjective
  , guidesStrategyPrincipleToAction
  , contributesStrategyActionToKeyResult
  , guidesStrategyPrincipleToPrinciple
  , contributesStrategyKeyResultToKeyResult
  , contributesStrategyActionToAction
  , translatesStrategyKeyResultToNeedObjective
  , groundsNeedDriverToObjective
  , anchorsNeedDriver
  , indicatesMeasureDomain
  , determinesMeasureDomain
  , containsStrategyKeyResult
  , containsMeasureKPI
  , guidesStrategyActionToInterventionAction
  , contributesInterventionActionToKeyResult
  , substantiatesInterventionKeyResultNeedObjective
  , contributesInterventionKeyResultToStrategyKeyResult
  , setsTargetForMeasureKPI
  , changesAnchor
  , measuresAnchor
  , allRelationCodes
  , reifyRelation
  , allRelations
  , lookupRelations
  ) where

import Data.Text (Text)
import O2I.Types

data FixedRelationCode
  = GuidesMissionCode
  | GroundsVisionCode
  | GuidesVisionCode
  | OrientsStrategyCode
  | DirectsStrategyCode
  | ContributesToStrategyCode
  | QualifiesNeedCode
  | SurfacesNeedCode
  | AddressesNeedCode
  | DirectsInterventionCode
  | ChangesSituationCode
  | SetsTargetForMeasureCode
  | MeasuresSituationCode
  | FramesMeasureCode
  | GuidesEthosPrincipleToMissionDriverCode
  | GuidesEthosPrincipleToVisionObjectiveCode
  | GroundsMissionDriverToVisionObjectiveCode
  | OrientsVisionObjectiveToStrategyObjectiveCode
  | GroundsStrategyDriverToObjectiveCode
  | SubstantiatesStrategyKeyResultObjectiveCode
  | GuidesStrategyPrincipleToActionCode
  | ContributesStrategyActionToKeyResultCode
  | GuidesStrategyPrincipleToPrincipleCode
  | ContributesStrategyKeyResultToKeyResultCode
  | ContributesStrategyActionToActionCode
  | TranslatesStrategyKeyResultToNeedObjectiveCode
  | GroundsNeedDriverToObjectiveCode
  | IndicatesMeasureDomainCode
  | DeterminesMeasureDomainCode
  | ContainsStrategyKeyResultCode
  | ContainsMeasureKPICode
  | GuidesStrategyActionToInterventionActionCode
  | ContributesInterventionActionToKeyResultCode
  | SubstantiatesInterventionKeyResultNeedObjectiveCode
  | ContributesInterventionKeyResultToStrategyKeyResultCode
  | SetsTargetForMeasureKPICode
  deriving (Bounded, Enum, Eq, Ord, Show)

data AnchorRelationFamily
  = ConstitutedByAnchorFamily
  | AnchorsNeedDriverFamily
  | ChangesAnchorFamily
  | MeasuresAnchorFamily
  deriving (Bounded, Enum, Eq, Ord, Show)

data RelationCode
  = FixedRelation FixedRelationCode
  | AnchorRelation AnchorRelationFamily SituationAnchor
  deriving (Eq, Ord, Show)

data MacroEvidenceKind
  = GuidesMissionEvidence
  | GroundsVisionEvidence
  | GuidesVisionEvidence
  | OrientsStrategyEvidence
  | DirectsStrategyEvidence
  | ContributesToStrategyEvidence
  | QualifiesNeedEvidence
  | SurfacesNeedEvidence
  | AddressesNeedEvidence
  | DirectsInterventionEvidence
  | ChangesSituationEvidence
  | SetsTargetForMeasureEvidence
  | MeasuresSituationEvidence
  | FramesMeasureEvidence
  deriving (Bounded, Enum, Eq, Ord, Show)

data RelationSemantics
  = MacroRelation MacroEvidenceKind
  | EvidenceRelation
  deriving (Eq, Ord, Show)

newtype RelationName = RelationName
  { relationNameText :: Text
  } deriving (Eq, Ord, Show)

data RelationSpec from to = RelationSpec
  { relationCode :: RelationCode
  , relationSemantics :: RelationSemantics
  , relationName :: RelationName
  , relationLabel :: Text
  , relationFrom :: SNodeKind from
  , relationTo :: SNodeKind to
  }

data Relation (from :: NodeKind) (to :: NodeKind) where
  Relation :: RelationSpec from to -> Relation from to

data SomeRelation where
  SomeRelation :: Relation from to -> SomeRelation

instance Eq SomeRelation where
  left == right = relationCodeOf left == relationCodeOf right

instance Show SomeRelation where
  show = show . relationNameOf

relationSpec :: Relation from to -> RelationSpec from to
relationSpec (Relation spec) = spec

relationCodeOf :: SomeRelation -> RelationCode
relationCodeOf (SomeRelation relation) = relationCode (relationSpec relation)

relationSemanticsOf :: SomeRelation -> RelationSemantics
relationSemanticsOf (SomeRelation relation) =
  relationSemantics (relationSpec relation)

relationNameOf :: SomeRelation -> RelationName
relationNameOf (SomeRelation relation) = relationName (relationSpec relation)

relationNameFor :: Relation from to -> RelationName
relationNameFor = relationName . relationSpec

relationIdentity :: SomeRelation -> (RelationName, NodeKindValue, NodeKindValue)
relationIdentity (SomeRelation relation) =
  let spec = relationSpec relation
   in ( relationName spec
      , nodeKindValue (relationFrom spec)
      , nodeKindValue (relationTo spec))

fixedContextRelation ::
     FixedRelationCode
  -> MacroEvidenceKind
  -> Text
  -> Text
  -> SContext from
  -> SContext to
  -> Relation ('ContextKind from) ('ContextKind to)
fixedContextRelation code semantics name label from to =
  Relation
    RelationSpec
      { relationCode = FixedRelation code
      , relationSemantics = MacroRelation semantics
      , relationName = RelationName name
      , relationLabel = label
      , relationFrom = SContextKind from
      , relationTo = SContextKind to
      }

fixedPrimitiveRelation ::
     FixedRelationCode
  -> Text
  -> Text
  -> SContext fromContext
  -> SPrimitive fromPrimitive
  -> SContext toContext
  -> SPrimitive toPrimitive
  -> Relation
       ('PrimitiveKind fromContext fromPrimitive)
       ('PrimitiveKind toContext toPrimitive)
fixedPrimitiveRelation code name label fromCtx fromPrim toCtx toPrim =
  fixedRelation
    code
    name
    label
    (SPrimitiveKind fromCtx fromPrim)
    (SPrimitiveKind toCtx toPrim)

fixedRelation ::
     FixedRelationCode
  -> Text
  -> Text
  -> SNodeKind from
  -> SNodeKind to
  -> Relation from to
fixedRelation code name label from to =
  Relation
    RelationSpec
      { relationCode = FixedRelation code
      , relationSemantics = EvidenceRelation
      , relationName = RelationName name
      , relationLabel = label
      , relationFrom = from
      , relationTo = to
      }

anchorRelation ::
     AnchorRelationFamily
  -> SSituationAnchor anchor
  -> Text
  -> Text
  -> RelationSemantics
  -> SNodeKind from
  -> SNodeKind to
  -> Relation from to
anchorRelation family anchor name label semantics from to =
  Relation
    RelationSpec
      { relationCode = AnchorRelation family (anchorValue anchor)
      , relationSemantics = semantics
      , relationName = RelationName name
      , relationLabel = label
      , relationFrom = from
      , relationTo = to
      }

-- * Typed relation specifications
-- ** Context macrorelations
guidesMission :: Relation ('ContextKind 'Ethos) ('ContextKind 'Mission)
guidesMission =
  fixedContextRelation
    GuidesMissionCode
    GuidesMissionEvidence
    "ethos-guides-mission"
    "guides"
    SEthos
    SMission

groundsVision :: Relation ('ContextKind 'Mission) ('ContextKind 'Vision)
groundsVision =
  fixedContextRelation
    GroundsVisionCode
    GroundsVisionEvidence
    "mission-grounds-vision"
    "grounds"
    SMission
    SVision

-- ** Remaining context macrorelations
guidesVision :: Relation ('ContextKind 'Ethos) ('ContextKind 'Vision)
guidesVision =
  fixedContextRelation
    GuidesVisionCode
    GuidesVisionEvidence
    "ethos-guides-vision"
    "guides"
    SEthos
    SVision

orientsStrategy :: Relation ('ContextKind 'Vision) ('ContextKind 'Strategy)
orientsStrategy =
  fixedContextRelation
    OrientsStrategyCode
    OrientsStrategyEvidence
    "vision-orients-strategy"
    "orients"
    SVision
    SStrategy

directsStrategy :: Relation ('ContextKind 'Strategy) ('ContextKind 'Strategy)
directsStrategy =
  fixedContextRelation
    DirectsStrategyCode
    DirectsStrategyEvidence
    "strategy-directs-strategy"
    "directs"
    SStrategy
    SStrategy

contributesToStrategy ::
     Relation ('ContextKind 'Strategy) ('ContextKind 'Strategy)
contributesToStrategy =
  fixedContextRelation
    ContributesToStrategyCode
    ContributesToStrategyEvidence
    "strategy-contributes-to-strategy"
    "contributes-to"
    SStrategy
    SStrategy

qualifiesNeed :: Relation ('ContextKind 'Strategy) ('ContextKind 'Need)
qualifiesNeed =
  fixedContextRelation
    QualifiesNeedCode
    QualifiesNeedEvidence
    "strategy-qualifies-need"
    "qualifies"
    SStrategy
    SNeed

surfacesNeed :: Relation ('ContextKind 'Situation) ('ContextKind 'Need)
surfacesNeed =
  fixedContextRelation
    SurfacesNeedCode
    SurfacesNeedEvidence
    "situation-surfaces-need"
    "surfaces"
    SSituation
    SNeed

addressesNeed :: Relation ('ContextKind 'Intervention) ('ContextKind 'Need)
addressesNeed =
  fixedContextRelation
    AddressesNeedCode
    AddressesNeedEvidence
    "intervention-addresses-need"
    "addresses"
    SIntervention
    SNeed

directsIntervention ::
     Relation ('ContextKind 'Strategy) ('ContextKind 'Intervention)
directsIntervention =
  fixedContextRelation
    DirectsInterventionCode
    DirectsInterventionEvidence
    "strategy-directs-intervention"
    "directs"
    SStrategy
    SIntervention

changesSituation ::
     Relation ('ContextKind 'Intervention) ('ContextKind 'Situation)
changesSituation =
  fixedContextRelation
    ChangesSituationCode
    ChangesSituationEvidence
    "intervention-changes-situation"
    "changes"
    SIntervention
    SSituation

setsTargetForMeasure ::
     Relation ('ContextKind 'Intervention) ('ContextKind 'Measure)
setsTargetForMeasure =
  fixedContextRelation
    SetsTargetForMeasureCode
    SetsTargetForMeasureEvidence
    "intervention-sets-target-for-measure"
    "sets-target-for"
    SIntervention
    SMeasure

measuresSituation :: Relation ('ContextKind 'Measure) ('ContextKind 'Situation)
measuresSituation =
  fixedContextRelation
    MeasuresSituationCode
    MeasuresSituationEvidence
    "measure-measures-situation"
    "measures"
    SMeasure
    SSituation

framesMeasure :: Relation ('ContextKind 'Strategy) ('ContextKind 'Measure)
framesMeasure =
  fixedContextRelation
    FramesMeasureCode
    FramesMeasureEvidence
    "strategy-frames-measure"
    "frames"
    SStrategy
    SMeasure

-- ** Situation anchor relation
constitutedByAnchor ::
     SSituationAnchor anchor
  -> Relation ('ContextKind 'Situation) ('AnchorKind anchor)
constitutedByAnchor anchor =
  anchorRelation
    ConstitutedByAnchorFamily
    anchor
    "situation-is-constituted-by-anchor"
    "is-constituted-by"
    EvidenceRelation
    (SContextKind SSituation)
    (SAnchorKind anchor)

-- ** Orientation and strategy evidence
guidesEthosPrincipleToMissionDriver ::
     Relation
       ('PrimitiveKind 'Ethos 'Principle)
       ('PrimitiveKind 'Mission 'Driver)
guidesEthosPrincipleToMissionDriver =
  fixedPrimitiveRelation
    GuidesEthosPrincipleToMissionDriverCode
    "ethos-principle-guides-mission-driver"
    "guides"
    SEthos
    SPrinciple
    SMission
    SDriver

guidesEthosPrincipleToVisionObjective ::
     Relation
       ('PrimitiveKind 'Ethos 'Principle)
       ('PrimitiveKind 'Vision 'Objective)
guidesEthosPrincipleToVisionObjective =
  fixedPrimitiveRelation
    GuidesEthosPrincipleToVisionObjectiveCode
    "ethos-principle-guides-vision-objective"
    "guides"
    SEthos
    SPrinciple
    SVision
    SObjective

groundsMissionDriverToVisionObjective ::
     Relation
       ('PrimitiveKind 'Mission 'Driver)
       ('PrimitiveKind 'Vision 'Objective)
groundsMissionDriverToVisionObjective =
  fixedPrimitiveRelation
    GroundsMissionDriverToVisionObjectiveCode
    "mission-driver-grounds-vision-objective"
    "grounds"
    SMission
    SDriver
    SVision
    SObjective

-- ** Remaining orientation and strategy evidence
orientsVisionObjectiveToStrategyObjective ::
     Relation
       ('PrimitiveKind 'Vision 'Objective)
       ('PrimitiveKind 'Strategy 'Objective)
orientsVisionObjectiveToStrategyObjective =
  fixedPrimitiveRelation
    OrientsVisionObjectiveToStrategyObjectiveCode
    "vision-objective-orients-strategy-objective"
    "orients"
    SVision
    SObjective
    SStrategy
    SObjective

groundsStrategyDriverToObjective ::
     Relation
       ('PrimitiveKind 'Strategy 'Driver)
       ('PrimitiveKind 'Strategy 'Objective)
groundsStrategyDriverToObjective =
  fixedPrimitiveRelation
    GroundsStrategyDriverToObjectiveCode
    "strategy-driver-grounds-strategy-objective"
    "grounds"
    SStrategy
    SDriver
    SStrategy
    SObjective

substantiatesStrategyKeyResultObjective ::
     Relation
       ('PrimitiveKind 'Strategy 'KeyResult)
       ('PrimitiveKind 'Strategy 'Objective)
substantiatesStrategyKeyResultObjective =
  fixedPrimitiveRelation
    SubstantiatesStrategyKeyResultObjectiveCode
    "strategy-key-result-substantiates-strategy-objective"
    "substantiates"
    SStrategy
    SKeyResult
    SStrategy
    SObjective

guidesStrategyPrincipleToAction ::
     Relation
       ('PrimitiveKind 'Strategy 'Principle)
       ('PrimitiveKind 'Strategy 'Action)
guidesStrategyPrincipleToAction =
  fixedPrimitiveRelation
    GuidesStrategyPrincipleToActionCode
    "strategy-principle-guides-strategy-action"
    "guides"
    SStrategy
    SPrinciple
    SStrategy
    SAction

contributesStrategyActionToKeyResult ::
     Relation
       ('PrimitiveKind 'Strategy 'Action)
       ('PrimitiveKind 'Strategy 'KeyResult)
contributesStrategyActionToKeyResult =
  fixedPrimitiveRelation
    ContributesStrategyActionToKeyResultCode
    "strategy-action-contributes-to-strategy-key-result"
    "contributes-to"
    SStrategy
    SAction
    SStrategy
    SKeyResult

guidesStrategyPrincipleToPrinciple ::
     Relation
       ('PrimitiveKind 'Strategy 'Principle)
       ('PrimitiveKind 'Strategy 'Principle)
guidesStrategyPrincipleToPrinciple =
  fixedPrimitiveRelation
    GuidesStrategyPrincipleToPrincipleCode
    "strategy-principle-guides-strategy-principle"
    "guides"
    SStrategy
    SPrinciple
    SStrategy
    SPrinciple

contributesStrategyKeyResultToKeyResult ::
     Relation
       ('PrimitiveKind 'Strategy 'KeyResult)
       ('PrimitiveKind 'Strategy 'KeyResult)
contributesStrategyKeyResultToKeyResult =
  fixedPrimitiveRelation
    ContributesStrategyKeyResultToKeyResultCode
    "strategy-key-result-contributes-to-strategy-key-result"
    "contributes-to"
    SStrategy
    SKeyResult
    SStrategy
    SKeyResult

contributesStrategyActionToAction ::
     Relation
       ('PrimitiveKind 'Strategy 'Action)
       ('PrimitiveKind 'Strategy 'Action)
contributesStrategyActionToAction =
  fixedPrimitiveRelation
    ContributesStrategyActionToActionCode
    "strategy-action-contributes-to-strategy-action"
    "contributes-to"
    SStrategy
    SAction
    SStrategy
    SAction

-- ** Need and measurement evidence
translatesStrategyKeyResultToNeedObjective ::
     Relation
       ('PrimitiveKind 'Strategy 'KeyResult)
       ('PrimitiveKind 'Need 'Objective)
translatesStrategyKeyResultToNeedObjective =
  fixedPrimitiveRelation
    TranslatesStrategyKeyResultToNeedObjectiveCode
    "strategy-key-result-translates-into-need-objective"
    "translates-into"
    SStrategy
    SKeyResult
    SNeed
    SObjective

groundsNeedDriverToObjective ::
     Relation ('PrimitiveKind 'Need 'Driver) ('PrimitiveKind 'Need 'Objective)
groundsNeedDriverToObjective =
  fixedPrimitiveRelation
    GroundsNeedDriverToObjectiveCode
    "need-driver-grounds-need-objective"
    "grounds"
    SNeed
    SDriver
    SNeed
    SObjective

-- ** Remaining need and measurement evidence
anchorsNeedDriver ::
     SSituationAnchor anchor
  -> Relation ('AnchorKind anchor) ('PrimitiveKind 'Need 'Driver)
anchorsNeedDriver anchor =
  anchorRelation
    AnchorsNeedDriverFamily
    anchor
    "situation-anchor-anchors-need-driver"
    "anchors"
    EvidenceRelation
    (SAnchorKind anchor)
    (SPrimitiveKind SNeed SDriver)

indicatesMeasureDomain ::
     Relation
       ('PrimitiveKind 'Strategy 'Driver)
       ('StructuringKind 'Measure 'Domain)
indicatesMeasureDomain =
  fixedRelation
    IndicatesMeasureDomainCode
    "strategy-driver-indicates-measure-domain"
    "indicates"
    (SPrimitiveKind SStrategy SDriver)
    (SStructuringKind SMeasure SDomain)

determinesMeasureDomain ::
     Relation
       ('PrimitiveKind 'Strategy 'KeyResult)
       ('StructuringKind 'Measure 'Domain)
determinesMeasureDomain =
  fixedRelation
    DeterminesMeasureDomainCode
    "strategy-key-result-determines-measure-domain"
    "determines"
    (SPrimitiveKind SStrategy SKeyResult)
    (SStructuringKind SMeasure SDomain)

containsStrategyKeyResult ::
     Relation
       ('StructuringKind 'Strategy 'Domain)
       ('PrimitiveKind 'Strategy 'KeyResult)
containsStrategyKeyResult =
  fixedRelation
    ContainsStrategyKeyResultCode
    "strategy-domain-contains-strategy-key-result"
    "contains"
    (SStructuringKind SStrategy SDomain)
    (SPrimitiveKind SStrategy SKeyResult)

containsMeasureKPI ::
     Relation ('StructuringKind 'Measure 'Domain) ('PrimitiveKind 'Measure 'KPI)
containsMeasureKPI =
  fixedRelation
    ContainsMeasureKPICode
    "measure-domain-contains-measure-kpi"
    "contains"
    (SStructuringKind SMeasure SDomain)
    (SPrimitiveKind SMeasure SKPI)

-- ** Intervention and effect evidence
guidesStrategyActionToInterventionAction ::
     Relation
       ('PrimitiveKind 'Strategy 'Action)
       ('PrimitiveKind 'Intervention 'Action)
guidesStrategyActionToInterventionAction =
  fixedPrimitiveRelation
    GuidesStrategyActionToInterventionActionCode
    "strategy-action-guides-intervention-action"
    "guides"
    SStrategy
    SAction
    SIntervention
    SAction

contributesInterventionActionToKeyResult ::
     Relation
       ('PrimitiveKind 'Intervention 'Action)
       ('PrimitiveKind 'Intervention 'KeyResult)
contributesInterventionActionToKeyResult =
  fixedPrimitiveRelation
    ContributesInterventionActionToKeyResultCode
    "intervention-action-contributes-to-intervention-key-result"
    "contributes-to"
    SIntervention
    SAction
    SIntervention
    SKeyResult

-- ** Remaining intervention and effect evidence
substantiatesInterventionKeyResultNeedObjective ::
     Relation
       ('PrimitiveKind 'Intervention 'KeyResult)
       ('PrimitiveKind 'Need 'Objective)
substantiatesInterventionKeyResultNeedObjective =
  fixedPrimitiveRelation
    SubstantiatesInterventionKeyResultNeedObjectiveCode
    "intervention-key-result-substantiates-need-objective"
    "substantiates"
    SIntervention
    SKeyResult
    SNeed
    SObjective

contributesInterventionKeyResultToStrategyKeyResult ::
     Relation
       ('PrimitiveKind 'Intervention 'KeyResult)
       ('PrimitiveKind 'Strategy 'KeyResult)
contributesInterventionKeyResultToStrategyKeyResult =
  fixedPrimitiveRelation
    ContributesInterventionKeyResultToStrategyKeyResultCode
    "intervention-key-result-contributes-to-strategy-key-result"
    "contributes-to"
    SIntervention
    SKeyResult
    SStrategy
    SKeyResult

setsTargetForMeasureKPI ::
     Relation
       ('PrimitiveKind 'Intervention 'KeyResult)
       ('PrimitiveKind 'Measure 'KPI)
setsTargetForMeasureKPI =
  fixedPrimitiveRelation
    SetsTargetForMeasureKPICode
    "intervention-key-result-sets-target-for-measure-kpi"
    "sets-target-for"
    SIntervention
    SKeyResult
    SMeasure
    SKPI

changesAnchor ::
     SSituationAnchor anchor
  -> Relation ('PrimitiveKind 'Intervention 'Action) ('AnchorKind anchor)
changesAnchor anchor =
  anchorRelation
    ChangesAnchorFamily
    anchor
    "intervention-action-changes-situation-anchor"
    "changes"
    EvidenceRelation
    (SPrimitiveKind SIntervention SAction)
    (SAnchorKind anchor)

measuresAnchor ::
     SSituationAnchor anchor
  -> Relation ('PrimitiveKind 'Measure 'KPI) ('AnchorKind anchor)
measuresAnchor anchor =
  anchorRelation
    MeasuresAnchorFamily
    anchor
    "measure-kpi-measures-situation-anchor"
    "measures"
    EvidenceRelation
    (SPrimitiveKind SMeasure SKPI)
    (SAnchorKind anchor)

-- * Total relation registry
allRelationCodes :: [RelationCode]
allRelationCodes =
  map FixedRelation [minBound .. maxBound]
    ++ [ AnchorRelation family anchor
       | family <- [minBound .. maxBound]
       , anchor <- [minBound .. maxBound]
       ]

reifyRelation :: RelationCode -> SomeRelation
reifyRelation (FixedRelation code) = reifyFixedRelation code
reifyRelation (AnchorRelation family anchorKind) =
  case someSAnchor anchorKind of
    SomeSAnchor anchor -> reifyAnchorRelation family anchor

reifyFixedRelation :: FixedRelationCode -> SomeRelation
reifyFixedRelation GuidesMissionCode = SomeRelation guidesMission
reifyFixedRelation GroundsVisionCode = SomeRelation groundsVision
reifyFixedRelation GuidesVisionCode = SomeRelation guidesVision
reifyFixedRelation OrientsStrategyCode = SomeRelation orientsStrategy
reifyFixedRelation DirectsStrategyCode = SomeRelation directsStrategy
reifyFixedRelation ContributesToStrategyCode =
  SomeRelation contributesToStrategy
reifyFixedRelation QualifiesNeedCode = SomeRelation qualifiesNeed
reifyFixedRelation SurfacesNeedCode = SomeRelation surfacesNeed
reifyFixedRelation AddressesNeedCode = SomeRelation addressesNeed
reifyFixedRelation DirectsInterventionCode = SomeRelation directsIntervention
reifyFixedRelation ChangesSituationCode = SomeRelation changesSituation
reifyFixedRelation SetsTargetForMeasureCode = SomeRelation setsTargetForMeasure
reifyFixedRelation MeasuresSituationCode = SomeRelation measuresSituation
reifyFixedRelation FramesMeasureCode = SomeRelation framesMeasure
reifyFixedRelation GuidesEthosPrincipleToMissionDriverCode =
  SomeRelation guidesEthosPrincipleToMissionDriver
reifyFixedRelation GuidesEthosPrincipleToVisionObjectiveCode =
  SomeRelation guidesEthosPrincipleToVisionObjective
reifyFixedRelation GroundsMissionDriverToVisionObjectiveCode =
  SomeRelation groundsMissionDriverToVisionObjective
reifyFixedRelation OrientsVisionObjectiveToStrategyObjectiveCode =
  SomeRelation orientsVisionObjectiveToStrategyObjective
reifyFixedRelation GroundsStrategyDriverToObjectiveCode =
  SomeRelation groundsStrategyDriverToObjective
reifyFixedRelation SubstantiatesStrategyKeyResultObjectiveCode =
  SomeRelation substantiatesStrategyKeyResultObjective
reifyFixedRelation GuidesStrategyPrincipleToActionCode =
  SomeRelation guidesStrategyPrincipleToAction
reifyFixedRelation ContributesStrategyActionToKeyResultCode =
  SomeRelation contributesStrategyActionToKeyResult
reifyFixedRelation GuidesStrategyPrincipleToPrincipleCode =
  SomeRelation guidesStrategyPrincipleToPrinciple
reifyFixedRelation ContributesStrategyKeyResultToKeyResultCode =
  SomeRelation contributesStrategyKeyResultToKeyResult
reifyFixedRelation ContributesStrategyActionToActionCode =
  SomeRelation contributesStrategyActionToAction
reifyFixedRelation TranslatesStrategyKeyResultToNeedObjectiveCode =
  SomeRelation translatesStrategyKeyResultToNeedObjective
reifyFixedRelation GroundsNeedDriverToObjectiveCode =
  SomeRelation groundsNeedDriverToObjective
reifyFixedRelation IndicatesMeasureDomainCode =
  SomeRelation indicatesMeasureDomain
reifyFixedRelation DeterminesMeasureDomainCode =
  SomeRelation determinesMeasureDomain
reifyFixedRelation ContainsStrategyKeyResultCode =
  SomeRelation containsStrategyKeyResult
reifyFixedRelation ContainsMeasureKPICode = SomeRelation containsMeasureKPI
reifyFixedRelation GuidesStrategyActionToInterventionActionCode =
  SomeRelation guidesStrategyActionToInterventionAction
reifyFixedRelation ContributesInterventionActionToKeyResultCode =
  SomeRelation contributesInterventionActionToKeyResult
reifyFixedRelation SubstantiatesInterventionKeyResultNeedObjectiveCode =
  SomeRelation substantiatesInterventionKeyResultNeedObjective
reifyFixedRelation ContributesInterventionKeyResultToStrategyKeyResultCode =
  SomeRelation contributesInterventionKeyResultToStrategyKeyResult
reifyFixedRelation SetsTargetForMeasureKPICode =
  SomeRelation setsTargetForMeasureKPI

reifyAnchorRelation ::
     AnchorRelationFamily -> SSituationAnchor anchor -> SomeRelation
reifyAnchorRelation ConstitutedByAnchorFamily anchor =
  SomeRelation (constitutedByAnchor anchor)
reifyAnchorRelation AnchorsNeedDriverFamily anchor =
  SomeRelation (anchorsNeedDriver anchor)
reifyAnchorRelation ChangesAnchorFamily anchor =
  SomeRelation (changesAnchor anchor)
reifyAnchorRelation MeasuresAnchorFamily anchor =
  SomeRelation (measuresAnchor anchor)

allRelations :: [SomeRelation]
allRelations = map reifyRelation allRelationCodes

lookupRelations :: RelationName -> [SomeRelation]
lookupRelations name = filter ((== name) . relationNameOf) allRelations
