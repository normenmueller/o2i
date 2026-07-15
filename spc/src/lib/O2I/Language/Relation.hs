{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Typed relations of the O2I semantic language.
--
-- Relation witnesses define admissible connections independently of concrete
-- graph instances and provide a total runtime projection for validation.
module O2I.Language.Relation
  ( Relation
  , SomeRelation(..)
  , FixedRelationCode(..)
  , AnchorRelationFamily(..)
  , RelationCode(..)
  , RelationSemantics(..)
  , MacroEvidenceKind(..)
  , RelationName(..)
  , RelationSpec
  , relationCode
  , relationSemantics
  , relationName
  , relationLabel
  , relationFrom
  , relationTo
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
  , indicatesMeasurePerformanceDimension
  , determinesMeasurePerformanceDimension
  , containsPerformanceDimension
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
import O2I.Language.Element

-- | Stable codes for relations whose endpoints are not anchor-parameterized.
data FixedRelationCode
  = GuidesMissionCode -- ^ Code for 'guidesMission'.
  | GroundsVisionCode -- ^ Code for 'groundsVision'.
  | GuidesVisionCode -- ^ Code for 'guidesVision'.
  | OrientsStrategyCode -- ^ Code for 'orientsStrategy'.
  | DirectsStrategyCode -- ^ Code for 'directsStrategy'.
  | ContributesToStrategyCode -- ^ Code for 'contributesToStrategy'.
  | QualifiesNeedCode -- ^ Code for 'qualifiesNeed'.
  | SurfacesNeedCode -- ^ Code for 'surfacesNeed'.
  | AddressesNeedCode -- ^ Code for 'addressesNeed'.
  | DirectsInterventionCode -- ^ Code for 'directsIntervention'.
  | ChangesSituationCode -- ^ Code for 'changesSituation'.
  | SetsTargetForMeasureCode -- ^ Code for 'setsTargetForMeasure'.
  | MeasuresSituationCode -- ^ Code for 'measuresSituation'.
  | FramesMeasureCode -- ^ Code for 'framesMeasure'.
  | GuidesEthosPrincipleToMissionDriverCode
    -- ^ Code for 'guidesEthosPrincipleToMissionDriver'.
  | GuidesEthosPrincipleToVisionObjectiveCode
    -- ^ Code for 'guidesEthosPrincipleToVisionObjective'.
  | GroundsMissionDriverToVisionObjectiveCode
    -- ^ Code for 'groundsMissionDriverToVisionObjective'.
  | OrientsVisionObjectiveToStrategyObjectiveCode
    -- ^ Code for 'orientsVisionObjectiveToStrategyObjective'.
  | GroundsStrategyDriverToObjectiveCode
    -- ^ Code for 'groundsStrategyDriverToObjective'.
  | SubstantiatesStrategyKeyResultObjectiveCode
    -- ^ Code for 'substantiatesStrategyKeyResultObjective'.
  | GuidesStrategyPrincipleToActionCode
    -- ^ Code for 'guidesStrategyPrincipleToAction'.
  | ContributesStrategyActionToKeyResultCode
    -- ^ Code for 'contributesStrategyActionToKeyResult'.
  | GuidesStrategyPrincipleToPrincipleCode
    -- ^ Code for 'guidesStrategyPrincipleToPrinciple'.
  | ContributesStrategyKeyResultToKeyResultCode
    -- ^ Code for 'contributesStrategyKeyResultToKeyResult'.
  | ContributesStrategyActionToActionCode
    -- ^ Code for 'contributesStrategyActionToAction'.
  | TranslatesStrategyKeyResultToNeedObjectiveCode
    -- ^ Code for 'translatesStrategyKeyResultToNeedObjective'.
  | GroundsNeedDriverToObjectiveCode
    -- ^ Code for 'groundsNeedDriverToObjective'.
  | IndicatesMeasurePerformanceDimensionCode -- ^ Code for 'indicatesMeasurePerformanceDimension'.
  | DeterminesMeasurePerformanceDimensionCode -- ^ Code for 'determinesMeasurePerformanceDimension'.
  | GuidesStrategyActionToInterventionActionCode
    -- ^ Code for 'guidesStrategyActionToInterventionAction'.
  | ContributesInterventionActionToKeyResultCode
    -- ^ Code for 'contributesInterventionActionToKeyResult'.
  | SubstantiatesInterventionKeyResultNeedObjectiveCode
    -- ^ Code for 'substantiatesInterventionKeyResultNeedObjective'.
  | ContributesInterventionKeyResultToStrategyKeyResultCode
    -- ^ Code for 'contributesInterventionKeyResultToStrategyKeyResult'.
  | SetsTargetForMeasureKPICode -- ^ Code for 'setsTargetForMeasureKPI'.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Relation families instantiated separately for each Situation-anchor form.
data AnchorRelationFamily
  = ConstitutedByAnchorFamily -- ^ Situation constitution family.
  | AnchorsNeedDriverFamily -- ^ Need-driver anchoring family.
  | ChangesAnchorFamily -- ^ Intervention change family.
  | MeasuresAnchorFamily -- ^ KPI observation family.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Complete runtime identity of a relation specification.
data RelationCode
  = FixedRelation FixedRelationCode -- ^ A relation with fixed endpoint kinds.
  | PerformanceDimensionMembership PerformanceDimensionRoleCode -- ^ Membership of a closed PerformanceDimension role.
  | AnchorRelation AnchorRelationFamily SituationAnchor -- ^ Anchor instance.
  deriving (Eq, Ord, Show)

-- | Primitive-level evidence obligation attached to a context macrorelation.
data MacroEvidenceKind
  = GuidesMissionEvidence -- ^ Evidence for 'guidesMission'.
  | GroundsVisionEvidence -- ^ Evidence for 'groundsVision'.
  | GuidesVisionEvidence -- ^ Evidence for 'guidesVision'.
  | OrientsStrategyEvidence -- ^ Evidence for 'orientsStrategy'.
  | DirectsStrategyEvidence -- ^ Evidence for 'directsStrategy'.
  | ContributesToStrategyEvidence -- ^ Evidence for 'contributesToStrategy'.
  | QualifiesNeedEvidence -- ^ Evidence for 'qualifiesNeed'.
  | SurfacesNeedEvidence -- ^ Evidence for 'surfacesNeed'.
  | AddressesNeedEvidence -- ^ Evidence for 'addressesNeed'.
  | DirectsInterventionEvidence -- ^ Evidence for 'directsIntervention'.
  | ChangesSituationEvidence -- ^ Evidence for 'changesSituation'.
  | SetsTargetForMeasureEvidence -- ^ Evidence for 'setsTargetForMeasure'.
  | MeasuresSituationEvidence -- ^ Evidence for 'measuresSituation'.
  | FramesMeasureEvidence -- ^ Evidence for 'framesMeasure'.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Semantic role of a relation in the O2I effect graph.
data RelationSemantics
  = MacroRelation MacroEvidenceKind -- ^ Claim requiring primitive evidence.
  | EvidenceRelation -- ^ Relation that can contribute such evidence.
  deriving (Eq, Ord, Show)

-- | Stable serialized name used by raw graph edges.
newtype RelationName = RelationName
  { relationNameText :: Text -- ^ Machine-readable relation identifier.
  } deriving (Eq, Ord, Show)

-- | Authoritative metadata and endpoint witnesses for a typed relation.
data RelationSpec from to =
  RelationSpec
    RelationCode
    RelationSemantics
    RelationName
    Text
    (SNodeKind from)
    (SNodeKind to)

-- | Project the stable finite-registry identity.
relationCode :: RelationSpec from to -> RelationCode
relationCode (RelationSpec code _ _ _ _ _) = code

-- | Project the macro or evidence role.
relationSemantics :: RelationSpec from to -> RelationSemantics
relationSemantics (RelationSpec _ semantics _ _ _ _) = semantics

-- | Project the name accepted in raw graph input.
relationName :: RelationSpec from to -> RelationName
relationName (RelationSpec _ _ name _ _ _) = name

-- | Project the concise human-readable relation label.
relationLabel :: RelationSpec from to -> Text
relationLabel (RelationSpec _ _ _ label _ _) = label

-- | Project the statically witnessed source kind.
relationFrom :: RelationSpec from to -> SNodeKind from
relationFrom (RelationSpec _ _ _ _ from _) = from

-- | Project the statically witnessed target kind.
relationTo :: RelationSpec from to -> SNodeKind to
relationTo (RelationSpec _ _ _ _ _ to) = to

-- | Typed proof that one node kind may relate to another.
data Relation (from :: NodeKind) (to :: NodeKind) where
  Relation :: RelationSpec from to -> Relation from to
    -- ^ Construct a typed witness from authoritative relation metadata.

-- | Existential typed relation for heterogeneous runtime registries.
--
-- Public clients obtain values through 'allRelations', 'lookupRelations', or
-- 'reifyRelation' and inspect them through the total projections below.
data SomeRelation where
  SomeRelation :: Relation from to -> SomeRelation
    -- ^ Hide endpoint indices while retaining their typed witnesses.

instance Eq SomeRelation where
  left == right = relationCodeOf left == relationCodeOf right

instance Show SomeRelation where
  show = show . relationNameOf

-- | Reveal the metadata carried by a typed relation witness.
relationSpec :: Relation from to -> RelationSpec from to
relationSpec (Relation spec) = spec

-- | Return the stable code of an existential relation.
relationCodeOf :: SomeRelation -> RelationCode
relationCodeOf (SomeRelation relation) = relationCode (relationSpec relation)

-- | Return the semantic role of an existential relation.
relationSemanticsOf :: SomeRelation -> RelationSemantics
relationSemanticsOf (SomeRelation relation) =
  relationSemantics (relationSpec relation)

-- | Return the serialized name of an existential relation.
relationNameOf :: SomeRelation -> RelationName
relationNameOf (SomeRelation relation) = relationName (relationSpec relation)

-- | Return the serialized name of a statically typed relation.
relationNameFor :: Relation from to -> RelationName
relationNameFor = relationName . relationSpec

-- | Project name and endpoint kinds for runtime validation and introspection.
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
    (RelationSpec
       (FixedRelation code)
       (MacroRelation semantics)
       (RelationName name)
       label
       (SContextKind from)
       (SContextKind to))

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
    (RelationSpec
       (FixedRelation code)
       EvidenceRelation
       (RelationName name)
       label
       from
       to)

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
    (RelationSpec
       (AnchorRelation family (anchorValue anchor))
       semantics
       (RelationName name)
       label
       from
       to)

-- * Typed relation specifications
-- ** Context macrorelations
-- | State that Ethos normatively guides Mission.
guidesMission :: Relation ('ContextKind 'Ethos) ('ContextKind 'Mission)
guidesMission =
  fixedContextRelation
    GuidesMissionCode
    GuidesMissionEvidence
    "ethos-guides-mission"
    "guides"
    SEthos
    SMission

-- | State that Mission provides the reason for Vision.
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
-- | State that Ethos normatively guides Vision.
guidesVision :: Relation ('ContextKind 'Ethos) ('ContextKind 'Vision)
guidesVision =
  fixedContextRelation
    GuidesVisionCode
    GuidesVisionEvidence
    "ethos-guides-vision"
    "guides"
    SEthos
    SVision

-- | State that Vision gives direction to Strategy.
orientsStrategy :: Relation ('ContextKind 'Vision) ('ContextKind 'Strategy)
orientsStrategy =
  fixedContextRelation
    OrientsStrategyCode
    OrientsStrategyEvidence
    "vision-orients-strategy"
    "orients"
    SVision
    SStrategy

-- | State that one Strategy directs another Strategy.
directsStrategy :: Relation ('ContextKind 'Strategy) ('ContextKind 'Strategy)
directsStrategy =
  fixedContextRelation
    DirectsStrategyCode
    DirectsStrategyEvidence
    "strategy-directs-strategy"
    "directs"
    SStrategy
    SStrategy

-- | State that one Strategy contributes to another Strategy.
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

-- | Qualify a situated Need as strategically relevant.
qualifiesNeed :: Relation ('ContextKind 'Strategy) ('ContextKind 'Need)
qualifiesNeed =
  fixedContextRelation
    QualifiesNeedCode
    QualifiesNeedEvidence
    "strategy-qualifies-need"
    "qualifies"
    SStrategy
    SNeed

-- | State that a Need becomes visible in a Situation.
surfacesNeed :: Relation ('ContextKind 'Situation) ('ContextKind 'Need)
surfacesNeed =
  fixedContextRelation
    SurfacesNeedCode
    SurfacesNeedEvidence
    "situation-surfaces-need"
    "surfaces"
    SSituation
    SNeed

-- | State that an Intervention addresses a Need.
addressesNeed :: Relation ('ContextKind 'Intervention) ('ContextKind 'Need)
addressesNeed =
  fixedContextRelation
    AddressesNeedCode
    AddressesNeedEvidence
    "intervention-addresses-need"
    "addresses"
    SIntervention
    SNeed

-- | State that Strategy directs an Intervention.
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

-- | State that an Intervention changes a Situation.
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

-- | State that an Intervention establishes targets for a Measure context.
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

-- | State that a Measure context observes a Situation.
measuresSituation :: Relation ('ContextKind 'Measure) ('ContextKind 'Situation)
measuresSituation =
  fixedContextRelation
    MeasuresSituationCode
    MeasuresSituationEvidence
    "measure-measures-situation"
    "measures"
    SMeasure
    SSituation

-- | State that Strategy frames the admissible Measure context.
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
-- | Relate a Situation to a constituent anchor of the witnessed form.
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
-- | Let an Ethos Principle guide a Mission Driver.
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

-- | Let an Ethos Principle guide a Vision Objective.
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

-- | Ground a Vision Objective in a Mission Driver.
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
-- | Orient a Strategy Objective through a Vision Objective.
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

-- | Ground a Strategy Objective in its diagnosed Driver.
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

-- | Make a Strategy Key Result substantiate its strategic Objective.
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

-- | Make a Strategy Principle guide a coherent strategic Action.
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

-- | Make a strategic Action contribute to a strategic Key Result.
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

-- | Make a Principle in a directing Strategy guide another Principle.
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

-- | Make one Strategy Key Result contribute to another Strategy Key Result.
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

-- | Make one strategic Action contribute to another strategic Action.
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
-- | Translate a Strategy Key Result into a Need Objective.
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

-- | Ground a Need Objective in its situated Driver.
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
-- | Attach a Need Driver to a Situation anchor of the witnessed form.
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

-- | Let a Strategy Driver indicate the Measure measurement dimension.
indicatesMeasurePerformanceDimension ::
     Relation
       ('PrimitiveKind 'Strategy 'Driver)
       ('StructuringKind 'Measure 'PerformanceDimension)
indicatesMeasurePerformanceDimension =
  fixedRelation
    IndicatesMeasurePerformanceDimensionCode
    "strategy-driver-indicates-measure-performance-dimension"
    "indicates"
    (SPrimitiveKind SStrategy SDriver)
    (SPerformanceDimensionKind MeasureMeasurementDimension)

-- | Let a Strategy Key Result determine the Measure measurement dimension.
determinesMeasurePerformanceDimension ::
     Relation
       ('PrimitiveKind 'Strategy 'KeyResult)
       ('StructuringKind 'Measure 'PerformanceDimension)
determinesMeasurePerformanceDimension =
  fixedRelation
    DeterminesMeasurePerformanceDimensionCode
    "strategy-key-result-determines-measure-performance-dimension"
    "determines"
    (SPrimitiveKind SStrategy SKeyResult)
    (SPerformanceDimensionKind MeasureMeasurementDimension)

-- | Relate a performance dimension to the member kind admitted by its role.
containsPerformanceDimension ::
     PerformanceDimensionRole context member
  -> Relation
       ('StructuringKind context 'PerformanceDimension)
       ('PrimitiveKind context member)
containsPerformanceDimension role =
  Relation
    (RelationSpec
       (PerformanceDimensionMembership (performanceDimensionRoleCode role))
       EvidenceRelation
       (RelationName (performanceDimensionMembershipRelationName role))
       "contains"
       (SPerformanceDimensionKind role)
       (SPrimitiveKind
          (performanceDimensionRoleContext role)
          (performanceDimensionRoleMember role)))

-- ** Intervention and effect evidence
-- | Guide an Intervention Action through a coherent strategic Action.
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

-- | Make an Intervention Action contribute to its Key Result.
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
-- | Make an Intervention Key Result substantiate a Need Objective.
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

-- | Link an Intervention Key Result back to its Strategy Key Result.
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

-- | Let an Intervention Key Result set the target for a KPI.
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

-- | State which Situation anchor an Intervention Action changes.
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

-- | State which Situation anchor a KPI observes.
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
-- | Complete finite list of stable relation codes.
allRelationCodes :: [RelationCode]
allRelationCodes =
  map FixedRelation [minBound .. maxBound]
    ++ map
         (PerformanceDimensionMembership . performanceDimensionRoleCodeOf)
         allPerformanceDimensionRoles
    ++ [ AnchorRelation family anchor
       | family <- [minBound .. maxBound]
       , anchor <- [minBound .. maxBound]
       ]

-- | Reify a stable runtime relation code as an existential typed witness.
reifyRelation :: RelationCode -> SomeRelation
reifyRelation (FixedRelation code) = reifyFixedRelation code
reifyRelation (PerformanceDimensionMembership code) =
  case reifyPerformanceDimensionRole code of
    SomePerformanceDimensionRole role ->
      SomeRelation (containsPerformanceDimension role)
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
reifyFixedRelation IndicatesMeasurePerformanceDimensionCode =
  SomeRelation indicatesMeasurePerformanceDimension
reifyFixedRelation DeterminesMeasurePerformanceDimensionCode =
  SomeRelation determinesMeasurePerformanceDimension
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

-- | Complete registry of all typed O2I relations.
allRelations :: [SomeRelation]
allRelations = map reifyRelation allRelationCodes

-- | Resolve all relations serialized under a runtime name.
--
-- Structural elaboration selects the candidate whose typed endpoints match the
-- concrete edge. Registry identity uniqueness prevents duplicate witnesses.
lookupRelations :: RelationName -> [SomeRelation]
lookupRelations name = filter ((== name) . relationNameOf) allRelations
