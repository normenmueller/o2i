{-# LANGUAGE OverloadedStrings #-}

-- | Private representation of selected-Profile rule explanations.
module O2I.ArchiMate.Profile.Rule.Internal.Explanation
  ( ProfileRuleId(..)
  , ProfileRuleAuthority(..)
  , ProfileRuleStage(..)
  , NonEmptyRuleText
  , nonEmptyRuleText
  , nonEmptyRuleTextValue
  , ProfileRuleExplanation(..)
  , profileRuleIdText
  , selectedProfileRuleAuthority
  , profileRuleAuthorityText
  , foldProfileRuleAuthority
  , selectedProfileRuleStage
  , profileRuleStageText
  , foldProfileRuleStage
  , profileRuleId
  , profileRuleAuthority
  , profileRuleProfileReference
  , profileRuleProfileContractDigest
  , profileRuleStage
  , profileRuleExpectation
  , profileRuleMeaning
  , profileRuleAction
  , foldProfileRuleExplanation
  ) where

import Data.Text (Text)
import qualified Data.Text as Text

-- | Exact selected-Profile rule identity.
newtype ProfileRuleId =
  ProfileRuleId Text
  deriving (Eq, Ord, Show)

-- | Closed authority for every selected-Profile rule.
data ProfileRuleAuthority =
  ProfileAuthority
  deriving (Eq, Ord, Show)

-- | Closed processing stage for every selected-Profile rule.
data ProfileRuleStage =
  ProfileStage
  deriving (Eq, Ord, Show)

-- | Construction form that makes an empty explanation field unrepresentable.
data NonEmptyRuleText =
  NonEmptyRuleText !Char !Text
  deriving (Eq, Ord, Show)

-- | One complete explanation bound to the exact compiled Profile.
data ProfileRuleExplanation =
  ProfileRuleExplanation
    !ProfileRuleId
    !ProfileRuleAuthority
    !Text
    !Text
    !ProfileRuleStage
    !NonEmptyRuleText
    !NonEmptyRuleText
    !NonEmptyRuleText
  deriving (Eq, Ord, Show)

nonEmptyRuleText :: Char -> Text -> NonEmptyRuleText
nonEmptyRuleText = NonEmptyRuleText

nonEmptyRuleTextValue :: NonEmptyRuleText -> Text
nonEmptyRuleTextValue (NonEmptyRuleText first rest) = Text.cons first rest

-- | Project the exact rule identity text without normalization.
profileRuleIdText :: ProfileRuleId -> Text
profileRuleIdText (ProfileRuleId value) = value

-- | The sole authority admitted for selected-Profile rules.
selectedProfileRuleAuthority :: ProfileRuleAuthority
selectedProfileRuleAuthority = ProfileAuthority

-- | Render the closed rule authority for discovery output.
profileRuleAuthorityText :: ProfileRuleAuthority -> Text
profileRuleAuthorityText ProfileAuthority = "Profile"

-- | Consume the sole closed rule-authority case.
foldProfileRuleAuthority :: result -> ProfileRuleAuthority -> result
foldProfileRuleAuthority profile ProfileAuthority = profile

-- | The sole stage admitted for selected-Profile rules.
selectedProfileRuleStage :: ProfileRuleStage
selectedProfileRuleStage = ProfileStage

-- | Render the closed selected-Profile stage for discovery output.
profileRuleStageText :: ProfileRuleStage -> Text
profileRuleStageText ProfileStage = "profile"

-- | Consume the sole closed selected-Profile stage case.
foldProfileRuleStage :: result -> ProfileRuleStage -> result
foldProfileRuleStage profile ProfileStage = profile

-- | Exact selected-Profile rule identity carried by the explanation.
profileRuleId :: ProfileRuleExplanation -> ProfileRuleId
profileRuleId (ProfileRuleExplanation identifier _ _ _ _ _ _ _) = identifier

-- | Closed normative authority carried by the explanation.
profileRuleAuthority :: ProfileRuleExplanation -> ProfileRuleAuthority
profileRuleAuthority (ProfileRuleExplanation _ authority _ _ _ _ _ _) =
  authority

-- | Exact selected compiled Profile reference carried by the explanation.
profileRuleProfileReference :: ProfileRuleExplanation -> Text
profileRuleProfileReference (ProfileRuleExplanation _ _ reference _ _ _ _ _) =
  reference

-- | Exact selected compiled Profile contract digest carried by the explanation.
profileRuleProfileContractDigest :: ProfileRuleExplanation -> Text
profileRuleProfileContractDigest (ProfileRuleExplanation _ _ _ digest _ _ _ _) =
  digest

-- | Closed processing stage carried by the explanation.
profileRuleStage :: ProfileRuleExplanation -> ProfileRuleStage
profileRuleStage (ProfileRuleExplanation _ _ _ _ stage _ _ _) = stage

-- | Normative expectation projected from the compiled static rule owner.
profileRuleExpectation :: ProfileRuleExplanation -> Text
profileRuleExpectation (ProfileRuleExplanation _ _ _ _ _ expectation _ _) =
  nonEmptyRuleTextValue expectation

-- | Non-normative explanation of why the Profile rule matters.
profileRuleMeaning :: ProfileRuleExplanation -> Text
profileRuleMeaning (ProfileRuleExplanation _ _ _ _ _ _ meaning _) =
  nonEmptyRuleTextValue meaning

-- | Non-normative corrective action for the Profile rule.
profileRuleAction :: ProfileRuleExplanation -> Text
profileRuleAction (ProfileRuleExplanation _ _ _ _ _ _ _ action) =
  nonEmptyRuleTextValue action

-- | Consume every immutable explanation field in canonical field order.
foldProfileRuleExplanation ::
     (ProfileRuleId -> ProfileRuleAuthority -> Text -> Text -> ProfileRuleStage -> Text -> Text -> Text -> result)
  -> ProfileRuleExplanation
  -> result
foldProfileRuleExplanation consume explanation =
  consume
    (profileRuleId explanation)
    (profileRuleAuthority explanation)
    (profileRuleProfileReference explanation)
    (profileRuleProfileContractDigest explanation)
    (profileRuleStage explanation)
    (profileRuleExpectation explanation)
    (profileRuleMeaning explanation)
    (profileRuleAction explanation)
