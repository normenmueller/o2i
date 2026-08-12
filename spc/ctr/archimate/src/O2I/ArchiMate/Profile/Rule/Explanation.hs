-- | Opaque explanation data for exact selected-Profile rules.
--
-- Explanation values carry provenance and presentation only. Rule identifiers
-- and explanation text never select Profile evaluator behavior.
module O2I.ArchiMate.Profile.Rule.Explanation
  ( ProfileRuleId
  , profileRuleIdText
  , ProfileRuleAuthority
  , selectedProfileRuleAuthority
  , profileRuleAuthorityText
  , foldProfileRuleAuthority
  , ProfileRuleStage
  , selectedProfileRuleStage
  , profileRuleStageText
  , foldProfileRuleStage
  , ProfileRuleExplanation
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

import O2I.ArchiMate.Profile.Rule.Internal.Explanation
