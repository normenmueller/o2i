{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed cumulative Validate requests.
--
-- Notation, Profile, and Structure requests have no supplemental-input
-- position. A Semantics request alone retains ordered physical sources; the
-- runtime acquires those sources only after Notation and Profile acceptance.
module O2I.Operation.Validate.Request
  ( type ValidationLevel
  , notationValidationLevel
  , profileValidationLevel
  , structureValidationLevel
  , semanticsValidationLevel
  , validationLevelText
  , foldValidationLevel
  , type ValidateRequest
  , notationValidateRequest
  , profileValidateRequest
  , structureValidateRequest
  , semanticsValidateRequest
  , validateRequestLevel
  , validateModelInput
  , validateViewSelector
  , validateAdapterId
  , validateSupplementalInputs
  , foldValidateRequest
  ) where

import Data.Text (Text)
import O2I.Operation.Acquisition (InputSource)
import O2I.Operation.Adapter (AdapterId)
import O2I.Operation.Validate.Request.Internal
import O2I.Operation.View (ViewSelector)

-- | Stop after the selected-universe Notation assessment.
notationValidationLevel :: ValidationLevel
notationValidationLevel = NotationValidationLevel

-- | Stop after the compiled Profile assessment.
profileValidationLevel :: ValidationLevel
profileValidationLevel = ProfileValidationLevel

-- | Stop after notation-independent Core Structure assessment.
structureValidationLevel :: ValidationLevel
structureValidationLevel = StructureValidationLevel

-- | Stop after supplemental Binding and Core Semantics assessment.
semanticsValidationLevel :: ValidationLevel
semanticsValidationLevel = SemanticsValidationLevel

-- | Stable machine token for one requested level.
validationLevelText :: ValidationLevel -> Text
validationLevelText level =
  case level of
    NotationValidationLevel -> "notation"
    ProfileValidationLevel -> "profile"
    StructureValidationLevel -> "structure"
    SemanticsValidationLevel -> "semantics"

-- | Consume the complete closed level vocabulary.
foldValidationLevel ::
     result -> result -> result -> result -> ValidationLevel -> result
foldValidationLevel notation profile structure semantics level =
  case level of
    NotationValidationLevel -> notation
    ProfileValidationLevel -> profile
    StructureValidationLevel -> structure
    SemanticsValidationLevel -> semantics

-- | Validate only the selected Notation universe.
notationValidateRequest ::
     InputSource -> ViewSelector -> Maybe AdapterId -> ValidateRequest
notationValidateRequest = NotationValidateRequest

-- | Validate Notation and the selected compiled Profile projection.
profileValidateRequest ::
     InputSource -> ViewSelector -> Maybe AdapterId -> ValidateRequest
profileValidateRequest = ProfileValidateRequest

-- | Validate through notation-independent Core Structure.
structureValidateRequest ::
     InputSource -> ViewSelector -> Maybe AdapterId -> ValidateRequest
structureValidateRequest = StructureValidateRequest

-- | Validate through Core Semantics using ordered supplemental sources.
semanticsValidateRequest ::
     InputSource
  -> ViewSelector
  -> Maybe AdapterId
  -> [InputSource]
  -> ValidateRequest
semanticsValidateRequest = SemanticsValidateRequest

-- | Last requested cumulative stage.
validateRequestLevel :: ValidateRequest -> ValidationLevel
validateRequestLevel request =
  case request of
    NotationValidateRequest {} -> NotationValidationLevel
    ProfileValidateRequest {} -> ProfileValidationLevel
    StructureValidateRequest {} -> StructureValidationLevel
    SemanticsValidateRequest {} -> SemanticsValidationLevel

-- | Exact physical model source retained by the request.
validateModelInput :: ValidateRequest -> InputSource
validateModelInput request =
  foldValidateRequest
    (\model _ _ -> model)
    (\model _ _ -> model)
    (\model _ _ -> model)
    (\model _ _ _ -> model)
    request

-- | Exact mandatory View selector retained without normalization.
validateViewSelector :: ValidateRequest -> ViewSelector
validateViewSelector request =
  foldValidateRequest
    (\_ selector _ -> selector)
    (\_ selector _ -> selector)
    (\_ selector _ -> selector)
    (\_ selector _ _ -> selector)
    request

-- | Optional exact compiled Adapter identifier.
validateAdapterId :: ValidateRequest -> Maybe AdapterId
validateAdapterId request =
  foldValidateRequest
    (\_ _ adapter -> adapter)
    (\_ _ adapter -> adapter)
    (\_ _ adapter -> adapter)
    (\_ _ adapter _ -> adapter)
    request

-- | Ordered Semantics-only supplements; earlier levels project an empty list.
validateSupplementalInputs :: ValidateRequest -> [InputSource]
validateSupplementalInputs request =
  foldValidateRequest
    (\_ _ _ -> [])
    (\_ _ _ -> [])
    (\_ _ _ -> [])
    (\_ _ _ supplements -> supplements)
    request

-- | Consume every request shape without exposing constructors.
foldValidateRequest ::
     (InputSource -> ViewSelector -> Maybe AdapterId -> result)
  -> (InputSource -> ViewSelector -> Maybe AdapterId -> result)
  -> (InputSource -> ViewSelector -> Maybe AdapterId -> result)
  -> (InputSource -> ViewSelector -> Maybe AdapterId -> [InputSource] -> result)
  -> ValidateRequest
  -> result
foldValidateRequest notation profile structure semantics request =
  case request of
    NotationValidateRequest model selector adapter ->
      notation model selector adapter
    ProfileValidateRequest model selector adapter ->
      profile model selector adapter
    StructureValidateRequest model selector adapter ->
      structure model selector adapter
    SemanticsValidateRequest model selector adapter supplements ->
      semantics model selector adapter supplements
