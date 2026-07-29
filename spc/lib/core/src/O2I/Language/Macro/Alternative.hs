{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE StandaloneDeriving #-}

-- | Closed constructive vocabulary for macro-evidence alternatives.
--
-- Each selector and relation occurs exactly once in an 'AlternativeShape'.
-- Total interpreters derive both conservative premise discovery and the
-- executable endpoint-typed relational plan from that one definition.
module O2I.Language.Macro.Alternative
  ( StrategyPrimitiveRole(..)
  , TypedStrategyRole(..)
  , typedStrategyRoleCode
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
  , eraseTypedSelector
  , typedSelectorKind
  ) where

import Data.List.NonEmpty (NonEmpty((:|)))
import O2I.Language.Element
import O2I.Language.Relation
import O2I.Validation.Relational.Types

-- | Primitive roles required by a complete Strategy formulation.
data StrategyPrimitiveRole
  = DiagnosisRole
  | IntentRole
  | GuidingPolicyRole
  | CoherentActionRole
  | StrategicKeyResultRole
  deriving (Eq, Ord, Show)

-- | Primitive-indexed Strategy formulation role.
data TypedStrategyRole (primitive :: Primitive) where
  StrategyDiagnosisRole :: TypedStrategyRole 'Driver
  StrategyIntentRole :: TypedStrategyRole 'Objective
  StrategyGuidingPolicyRole :: TypedStrategyRole 'Principle
  StrategyCoherentActionRole :: TypedStrategyRole 'Action
  StrategyKeyResultRole :: TypedStrategyRole 'KeyResult

deriving instance Show (TypedStrategyRole primitive)

-- | Erase only the primitive index for stable diagnostics and raw discovery.
typedStrategyRoleCode :: TypedStrategyRole primitive -> StrategyPrimitiveRole
typedStrategyRoleCode role =
  case role of
    StrategyDiagnosisRole -> DiagnosisRole
    StrategyIntentRole -> IntentRole
    StrategyGuidingPolicyRole -> GuidingPolicyRole
    StrategyCoherentActionRole -> CoherentActionRole
    StrategyKeyResultRole -> StrategicKeyResultRole

-- | Select one endpoint Context of a macrorelation claim.
data ClaimSide
  = ClaimSource
  | ClaimTarget
  deriving (Eq, Ord, Show)

-- | A bound node position in one conservative premise pattern.
data MacroNodeSelector
  = ClaimContext ClaimSide
  | OwnedPrimitive ClaimSide Primitive
  | StrategyRolePrimitive ClaimSide StrategyPrimitiveRole
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

-- | One typed node position within a macrorelation evidence rule.
data TypedMacroSelector (from :: Context) (to :: Context) (kind :: NodeKind) where
  SourceContextSelector
    :: SContext from -> TypedMacroSelector from to ('ContextKind from)
  TargetContextSelector
    :: SContext to -> TypedMacroSelector from to ('ContextKind to)
  SourcePrimitiveSelector
    :: SContext from
    -> SPrimitive primitive
    -> TypedMacroSelector from to ('PrimitiveKind from primitive)
  TargetPrimitiveSelector
    :: SContext to
    -> SPrimitive primitive
    -> TypedMacroSelector from to ('PrimitiveKind to primitive)
  SourceStrategyRoleSelector
    :: TypedStrategyRole primitive
    -> TypedMacroSelector 'Strategy to ('PrimitiveKind 'Strategy primitive)
  TargetStrategyRoleSelector
    :: TypedStrategyRole primitive
    -> TypedMacroSelector from 'Strategy ('PrimitiveKind 'Strategy primitive)
  SourcePerformanceDimensionSelector
    :: PerformanceDimensionRole from member
    -> TypedMacroSelector from to ('StructuringKind from 'PerformanceDimension)
  TargetPerformanceDimensionSelector
    :: PerformanceDimensionRole to member
    -> TypedMacroSelector from to ('StructuringKind to 'PerformanceDimension)
  SourceSituationAnchorSelector
    :: SSituationAnchor anchor
    -> TypedMacroSelector 'Situation to ('AnchorKind anchor)
  TargetSituationAnchorSelector
    :: SSituationAnchor anchor
    -> TypedMacroSelector from 'Situation ('AnchorKind anchor)

deriving instance Show (TypedMacroSelector from to kind)

-- | One endpoint-typed relation premise.
data TypedMacroPremise (from :: Context) (to :: Context) where
  TypedMacroPremise
    :: TypedMacroSelector from to source
    -> Relation source target
    -> TypedMacroSelector from to target
    -> TypedMacroPremise from to

-- | Complete closed vocabulary of constructively connected alternatives.
--
-- The four forms are the exact connected patterns required by the O2I
-- macrorelation vocabulary. They are semantic shapes, not a general query DSL.
data AlternativeShape (from :: Context) (to :: Context) where
  Single
    :: TypedMacroSelector from to source
    -> Relation source target
    -> TypedMacroSelector from to target
    -> AlternativeShape from to
  ForwardChain
    :: TypedMacroSelector from to source
    -> Relation source middle
    -> TypedMacroSelector from to middle
    -> Relation middle target
    -> TypedMacroSelector from to target
    -> AlternativeShape from to
  TargetJoin
    :: TypedMacroSelector from to firstSource
    -> Relation firstSource target
    -> TypedMacroSelector from to target
    -> TypedMacroSelector from to secondSource
    -> Relation secondSource target
    -> AlternativeShape from to
  JoinedChainWithTail
    :: TypedMacroSelector from to firstSource
    -> Relation firstSource joint
    -> TypedMacroSelector from to joint
    -> TypedMacroSelector from to secondSource
    -> Relation secondSource joint
    -> Relation joint tail
    -> TypedMacroSelector from to tail
    -> AlternativeShape from to

-- | Derive conservative premises in canonical witness order.
typedAlternativePremises ::
     AlternativeShape from to -> NonEmpty (TypedMacroPremise from to)
typedAlternativePremises shape =
  case shape of
    Single source relation target ->
      TypedMacroPremise source relation target :| []
    ForwardChain source first middle second target ->
      TypedMacroPremise source first middle
        :| [TypedMacroPremise middle second target]
    TargetJoin firstSource first target secondSource second ->
      TypedMacroPremise firstSource first target
        :| [TypedMacroPremise secondSource second target]
    JoinedChainWithTail firstSource first joint secondSource second tailRelation target ->
      TypedMacroPremise firstSource first joint
        :| [ TypedMacroPremise secondSource second joint
           , TypedMacroPremise joint tailRelation target
           ]

-- | Derive the conservative raw discovery alternative.
conservativeAlternative :: AlternativeShape from to -> PremiseAlternative
conservativeAlternative =
  PremiseAlternative . fmap eraseTypedPremise . typedAlternativePremises

-- | Derive one total connected relational plan from addressed typed domains.
instantiateAlternative ::
     Monoid work
  => AlternativeShape from to
  -> (forall kind. TypedMacroSelector from to kind -> (Domain kind, work))
  -> (CompiledPlan (NonEmpty ProjectedPremise), work)
instantiateAlternative shape resolve =
  case shape of
    Single source relation target ->
      let (sourceDomain, sourceWork) = resolvePreparedDomain resolve source
          (targetDomain, targetWork) = resolvePreparedDomain resolve target
       in ( rootAtom
              sourceDomain
              relation
              targetDomain
              (\_ _ premise -> finish (projectPremise premise))
          , sourceWork <> targetWork)
    ForwardChain source first middle second target ->
      let (sourceDomain, sourceWork) = resolvePreparedDomain resolve source
          (middleDomain, middleWork) = resolvePreparedDomain resolve middle
          (targetDomain, targetWork) = resolvePreparedDomain resolve target
       in ( rootAtom
              sourceDomain
              first
              middleDomain
              (\_ middleBound firstPremise ->
                 extendForward
                   middleBound
                   second
                   targetDomain
                   (\_ secondPremise ->
                      finish
                        (appendProjectedPremise
                           (projectPremise firstPremise)
                           secondPremise)))
          , sourceWork <> middleWork <> targetWork)
    TargetJoin firstSource first target secondSource second ->
      let (firstSourceDomain, firstSourceWork) =
            resolvePreparedDomain resolve firstSource
          (targetDomain, targetWork) = resolvePreparedDomain resolve target
          (secondSourceDomain, secondSourceWork) =
            resolvePreparedDomain resolve secondSource
       in ( rootAtom
              firstSourceDomain
              first
              targetDomain
              (\_ targetBound firstPremise ->
                 extendBackward
                   secondSourceDomain
                   second
                   targetBound
                   (\_ secondPremise ->
                      finish
                        (appendProjectedPremise
                           (projectPremise firstPremise)
                           secondPremise)))
          , firstSourceWork <> targetWork <> secondSourceWork)
    JoinedChainWithTail firstSource first joint secondSource second tailRelation target ->
      let (firstSourceDomain, firstSourceWork) =
            resolvePreparedDomain resolve firstSource
          (jointDomain, jointWork) = resolvePreparedDomain resolve joint
          (secondSourceDomain, secondSourceWork) =
            resolvePreparedDomain resolve secondSource
          (targetDomain, targetWork) = resolvePreparedDomain resolve target
       in ( rootAtom
              firstSourceDomain
              first
              jointDomain
              (\_ jointBound firstPremise ->
                 extendBackward
                   secondSourceDomain
                   second
                   jointBound
                   (\_ secondPremise ->
                      extendForward
                        jointBound
                        tailRelation
                        targetDomain
                        (\_ tailPremise ->
                           finish
                             (appendProjectedPremise
                                (appendProjectedPremise
                                   (projectPremise firstPremise)
                                   secondPremise)
                                tailPremise))))
          , firstSourceWork <> jointWork <> secondSourceWork <> targetWork)

resolvePreparedDomain ::
     (forall selected. TypedMacroSelector from to selected -> ( Domain selected
                                                              , work))
  -> TypedMacroSelector from to kind
  -> (Domain kind, work)
resolvePreparedDomain resolve selector =
  case resolve selector of
    resolved@(domain, _) -> domain `seq` resolved

eraseTypedPremise :: TypedMacroPremise from to -> MacroPremise
eraseTypedPremise (TypedMacroPremise source relation target) =
  MacroPremise
    { premiseSource = eraseTypedSelector source
    , premiseRelation = ExactRelation (relationCode (relationSpec relation))
    , premiseTarget = eraseTypedSelector target
    }

-- | Erase endpoint indices for conservative pre-semantic discovery.
eraseTypedSelector :: TypedMacroSelector from to kind -> MacroNodeSelector
eraseTypedSelector selector =
  case selector of
    SourceContextSelector _ -> ClaimContext ClaimSource
    TargetContextSelector _ -> ClaimContext ClaimTarget
    SourcePrimitiveSelector _ primitive ->
      OwnedPrimitive ClaimSource (primitiveValue primitive)
    TargetPrimitiveSelector _ primitive ->
      OwnedPrimitive ClaimTarget (primitiveValue primitive)
    SourceStrategyRoleSelector role ->
      StrategyRolePrimitive ClaimSource (typedStrategyRoleCode role)
    TargetStrategyRoleSelector role ->
      StrategyRolePrimitive ClaimTarget (typedStrategyRoleCode role)
    SourcePerformanceDimensionSelector role ->
      OwnedPerformanceDimension ClaimSource (performanceDimensionRoleCode role)
    TargetPerformanceDimensionSelector role ->
      OwnedPerformanceDimension ClaimTarget (performanceDimensionRoleCode role)
    SourceSituationAnchorSelector _ -> ConstituentAnchor ClaimSource
    TargetSituationAnchorSelector _ -> ConstituentAnchor ClaimTarget

-- | Recover the complete node-kind witness of one typed selector.
typedSelectorKind :: TypedMacroSelector from to kind -> SNodeKind kind
typedSelectorKind selector =
  case selector of
    SourceContextSelector context -> SContextKind context
    TargetContextSelector context -> SContextKind context
    SourcePrimitiveSelector context primitive ->
      SPrimitiveKind context primitive
    TargetPrimitiveSelector context primitive ->
      SPrimitiveKind context primitive
    SourceStrategyRoleSelector role ->
      SPrimitiveKind SStrategy (strategyRolePrimitive role)
    TargetStrategyRoleSelector role ->
      SPrimitiveKind SStrategy (strategyRolePrimitive role)
    SourcePerformanceDimensionSelector role -> SPerformanceDimensionKind role
    TargetPerformanceDimensionSelector role -> SPerformanceDimensionKind role
    SourceSituationAnchorSelector anchor -> SAnchorKind anchor
    TargetSituationAnchorSelector anchor -> SAnchorKind anchor

strategyRolePrimitive :: TypedStrategyRole primitive -> SPrimitive primitive
strategyRolePrimitive role =
  case role of
    StrategyDiagnosisRole -> SDriver
    StrategyIntentRole -> SObjective
    StrategyGuidingPolicyRole -> SPrinciple
    StrategyCoherentActionRole -> SAction
    StrategyKeyResultRole -> SKeyResult
