{-# LANGUAGE DataKinds #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE StandaloneDeriving #-}

-- | Context-sensitive interpretations of O2I Primitives.
--
-- Interpretation is part of the O2I semantic language: it determines which
-- Primitive may carry which meaning in a Context before any graph is built.
module O2I.Language.Interpretation
  ( Interpretation(..)
  , InterpretationCode(..)
  , InterpretationSpec(..)
  , SomeInterpretation(..)
  , interpretationSpec
  , interpretationCodeOf
  , interpretationIdentity
  , allInterpretations
  , lookupInterpretation
  ) where

import O2I.Language.Element

-- ** Interpretations
-- | Proof that a Primitive carries an admissible meaning in a Context.
--
-- A constructor is a static witness; unsupported context/primitive pairs have
-- no constructor and therefore cannot be represented as typed interpretations.
data Interpretation (context :: Context) (primitive :: Primitive) where
  PrincipleInEthos :: Interpretation 'Ethos 'Principle
    -- ^ Cultural or normative principle.
  DriverInMission :: Interpretation 'Mission 'Driver
    -- ^ Enduring purpose driver.
  ObjectiveInVision :: Interpretation 'Vision 'Objective
    -- ^ Desired future state.
  DriverInStrategy :: Interpretation 'Strategy 'Driver
    -- ^ Diagnosed strategic challenge.
  ObjectiveInStrategy :: Interpretation 'Strategy 'Objective
    -- ^ Strategic intent.
  PrincipleInStrategy :: Interpretation 'Strategy 'Principle
    -- ^ Guiding policy or strategic decision logic.
  KeyResultInStrategy :: Interpretation 'Strategy 'KeyResult
    -- ^ Quantified strategic success evidence.
  ActionInStrategy :: Interpretation 'Strategy 'Action
    -- ^ Coherent strategic action commitment.
  DriverInNeed :: Interpretation 'Need 'Driver
    -- ^ Situated reason for required change.
  ObjectiveInNeed :: Interpretation 'Need 'Objective
    -- ^ Required qualitative change.
  ActionInIntervention :: Interpretation 'Intervention 'Action
    -- ^ Operational action applied to the Situation.
  KeyResultInIntervention :: Interpretation 'Intervention 'KeyResult
    -- ^ Quantified operational result.
  KPIInMeasure :: Interpretation 'Measure 'KPI
    -- ^ Stable observed quantity.

deriving instance Show (Interpretation context primitive)

-- ** Interpretation registry
-- | Runtime metadata and static witness for one admissible interpretation.
data InterpretationSpec context primitive = InterpretationSpec
  { interpretationCode :: InterpretationCode -- ^ Stable registry code.
  , interpretationContext :: SContext context -- ^ Context witness.
  , interpretationPrimitive :: SPrimitive primitive -- ^ Primitive witness.
  , interpretationWitness :: Interpretation context primitive -- ^ Proof.
  }

-- | Existential interpretation specification for heterogeneous registries.
data SomeInterpretation where
  SomeInterpretation
    :: InterpretationSpec context primitive -> SomeInterpretation
    -- ^ Hide type indices while retaining metadata and proof.

instance Show SomeInterpretation where
  show (SomeInterpretation spec) = show (interpretationCode spec)

-- | Stable runtime identity of every admissible interpretation.
data InterpretationCode
  = PrincipleInEthosCode -- ^ Code for 'PrincipleInEthos'.
  | DriverInMissionCode -- ^ Code for 'DriverInMission'.
  | ObjectiveInVisionCode -- ^ Code for 'ObjectiveInVision'.
  | DriverInStrategyCode -- ^ Code for 'DriverInStrategy'.
  | ObjectiveInStrategyCode -- ^ Code for 'ObjectiveInStrategy'.
  | PrincipleInStrategyCode -- ^ Code for 'PrincipleInStrategy'.
  | KeyResultInStrategyCode -- ^ Code for 'KeyResultInStrategy'.
  | ActionInStrategyCode -- ^ Code for 'ActionInStrategy'.
  | DriverInNeedCode -- ^ Code for 'DriverInNeed'.
  | ObjectiveInNeedCode -- ^ Code for 'ObjectiveInNeed'.
  | ActionInInterventionCode -- ^ Code for 'ActionInIntervention'.
  | KeyResultInInterventionCode -- ^ Code for 'KeyResultInIntervention'.
  | KPIInMeasureCode -- ^ Code for 'KPIInMeasure'.
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | Obtain registry metadata from a statically known interpretation witness.
interpretationSpec ::
     Interpretation context primitive -> InterpretationSpec context primitive
interpretationSpec PrincipleInEthos =
  InterpretationSpec PrincipleInEthosCode SEthos SPrinciple PrincipleInEthos
interpretationSpec DriverInMission =
  InterpretationSpec DriverInMissionCode SMission SDriver DriverInMission
interpretationSpec ObjectiveInVision =
  InterpretationSpec ObjectiveInVisionCode SVision SObjective ObjectiveInVision
interpretationSpec DriverInStrategy =
  InterpretationSpec DriverInStrategyCode SStrategy SDriver DriverInStrategy
interpretationSpec ObjectiveInStrategy =
  InterpretationSpec
    ObjectiveInStrategyCode
    SStrategy
    SObjective
    ObjectiveInStrategy
interpretationSpec PrincipleInStrategy =
  InterpretationSpec
    PrincipleInStrategyCode
    SStrategy
    SPrinciple
    PrincipleInStrategy
interpretationSpec KeyResultInStrategy =
  InterpretationSpec
    KeyResultInStrategyCode
    SStrategy
    SKeyResult
    KeyResultInStrategy
interpretationSpec ActionInStrategy =
  InterpretationSpec ActionInStrategyCode SStrategy SAction ActionInStrategy
interpretationSpec DriverInNeed =
  InterpretationSpec DriverInNeedCode SNeed SDriver DriverInNeed
interpretationSpec ObjectiveInNeed =
  InterpretationSpec ObjectiveInNeedCode SNeed SObjective ObjectiveInNeed
interpretationSpec ActionInIntervention =
  InterpretationSpec
    ActionInInterventionCode
    SIntervention
    SAction
    ActionInIntervention
interpretationSpec KeyResultInIntervention =
  InterpretationSpec
    KeyResultInInterventionCode
    SIntervention
    SKeyResult
    KeyResultInIntervention
interpretationSpec KPIInMeasure =
  InterpretationSpec KPIInMeasureCode SMeasure SKPI KPIInMeasure

-- | Complete finite registry of admissible interpretations.
allInterpretations :: [SomeInterpretation]
allInterpretations = map interpretationFromCode [minBound .. maxBound]

interpretationFromCode :: InterpretationCode -> SomeInterpretation
interpretationFromCode PrincipleInEthosCode =
  SomeInterpretation (interpretationSpec PrincipleInEthos)
interpretationFromCode DriverInMissionCode =
  SomeInterpretation (interpretationSpec DriverInMission)
interpretationFromCode ObjectiveInVisionCode =
  SomeInterpretation (interpretationSpec ObjectiveInVision)
interpretationFromCode DriverInStrategyCode =
  SomeInterpretation (interpretationSpec DriverInStrategy)
interpretationFromCode ObjectiveInStrategyCode =
  SomeInterpretation (interpretationSpec ObjectiveInStrategy)
interpretationFromCode PrincipleInStrategyCode =
  SomeInterpretation (interpretationSpec PrincipleInStrategy)
interpretationFromCode KeyResultInStrategyCode =
  SomeInterpretation (interpretationSpec KeyResultInStrategy)
interpretationFromCode ActionInStrategyCode =
  SomeInterpretation (interpretationSpec ActionInStrategy)
interpretationFromCode DriverInNeedCode =
  SomeInterpretation (interpretationSpec DriverInNeed)
interpretationFromCode ObjectiveInNeedCode =
  SomeInterpretation (interpretationSpec ObjectiveInNeed)
interpretationFromCode ActionInInterventionCode =
  SomeInterpretation (interpretationSpec ActionInIntervention)
interpretationFromCode KeyResultInInterventionCode =
  SomeInterpretation (interpretationSpec KeyResultInIntervention)
interpretationFromCode KPIInMeasureCode =
  SomeInterpretation (interpretationSpec KPIInMeasure)

-- | Look up the interpretation admitted for a runtime context/primitive pair.
--
-- 'Nothing' means that the pair is semantically inadmissible.
lookupInterpretation :: Context -> Primitive -> Maybe SomeInterpretation
lookupInterpretation context primitive = go allInterpretations
  where
    go [] = Nothing
    go (candidate@(SomeInterpretation spec):rest)
      | contextValue (interpretationContext spec) == context
          && primitiveValue (interpretationPrimitive spec) == primitive =
        Just candidate
      | otherwise = go rest

-- | Return the stable code of an existential interpretation.
interpretationCodeOf :: SomeInterpretation -> InterpretationCode
interpretationCodeOf (SomeInterpretation spec) = interpretationCode spec

-- | Project an interpretation to its runtime context/primitive identity.
interpretationIdentity :: SomeInterpretation -> (Context, Primitive)
interpretationIdentity (SomeInterpretation spec) =
  ( contextValue (interpretationContext spec)
  , primitiveValue (interpretationPrimitive spec))
