{-# LANGUAGE OverloadedStrings #-}

-- | Discovery-owned canonical projections.
module O2I.Operation.Discovery.Machine.Internal
  ( profileDiscoveryRowFragment
  , profileDiscoveryDefectFragment
  , ruleAuthorityFragment
  , discoveredRuleFragment
  , ruleDiscoveryDefectFragment
  , viewDiscoveryAuthorityFragment
  ) where

import qualified Data.List.NonEmpty as NonEmpty
import O2I.Operation.Adapter (adapterIdText)
import O2I.Operation.Discovery.Profile
  ( ProfileDiscoveryDefect
  , ProfileDiscoveryRow
  , foldProfileDiscoveryDefect
  , foldProfileDiscoveryRow
  )
import O2I.Operation.Discovery.Rule
  ( DiscoveredRule
  , RuleAuthority
  , RuleContractBinding
  , RuleDiscoveryDefect
  , foldDiscoveredRule
  , foldRuleAuthority
  , foldRuleContractBinding
  , foldRuleDiscoveryDefect
  , ruleAuthorityText
  )
import O2I.Operation.Discovery.View
  ( ViewDiscoveryAuthority
  , foldViewDiscoveryAuthority
  )
import O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , arrayFragment
  , closedObjectFragment
  , nullFragment
  , requiredMember
  , textFragment
  )

profileDiscoveryRowFragment :: ProfileDiscoveryRow -> CanonicalFragment
profileDiscoveryRowFragment =
  foldProfileDiscoveryRow $ \identity token version notation adapters digest ->
    closedObjectFragment
      [ requiredMember "identity" (textFragment identity)
      , requiredMember "token" (textFragment token)
      , requiredMember "reference" (textFragment (identity <> "@" <> token))
      , requiredMember "version" (textFragment version)
      , requiredMember "notation" (textFragment notation)
      , requiredMember
          "adapterIds"
          (arrayFragment (fmap textFragment (NonEmpty.toList adapters)))
      , requiredMember "contractDigest" (textFragment digest)
      ]

profileDiscoveryDefectFragment :: ProfileDiscoveryDefect -> CanonicalFragment
profileDiscoveryDefectFragment =
  foldProfileDiscoveryDefect
    (\reference ->
       closedObjectFragment
         [ requiredMember "code" (textFragment "missing-adapter-id")
         , requiredMember "profileReference" (textFragment reference)
         ])
    (\reference identifier ->
       closedObjectFragment
         [ requiredMember "code" (textFragment "duplicate-adapter-id")
         , requiredMember "profileReference" (textFragment reference)
         , requiredMember "adapterId" (textFragment identifier)
         ])

ruleAuthorityFragment :: RuleAuthority -> CanonicalFragment
ruleAuthorityFragment authority =
  foldRuleAuthority
    (authorityFragment "operation" Nothing)
    (authorityFragment "core" Nothing)
    (\reference -> authorityFragment "profile" (Just reference))
    (\identifier ->
       authorityFragment "adapter" (Just (adapterIdText identifier)))
    authority
  where
    authorityFragment kind subject binding =
      closedObjectFragment
        [ requiredMember "kind" (textFragment kind)
        , requiredMember "label" (textFragment (ruleAuthorityText authority))
        , requiredMember "subject" (maybe nullFragment textFragment subject)
        , requiredMember "contract" (ruleContractBindingFragment binding)
        ]

discoveredRuleFragment :: DiscoveredRule -> CanonicalFragment
discoveredRuleFragment =
  foldDiscoveredRule $ \_ identity stage expectation meaning action ->
    closedObjectFragment
      [ requiredMember "id" (textFragment identity)
      , requiredMember "stage" (textFragment stage)
      , requiredMember "expectation" (textFragment expectation)
      , requiredMember "meaning" (textFragment meaning)
      , requiredMember "action" (textFragment action)
      ]

ruleDiscoveryDefectFragment :: RuleDiscoveryDefect -> CanonicalFragment
ruleDiscoveryDefectFragment =
  foldRuleDiscoveryDefect
    (\expectedReference actualReference expectedDigest actualDigest ->
       closedObjectFragment
         [ requiredMember "code" (textFragment "profile-catalog-mismatch")
         , requiredMember "expectedReference" (textFragment expectedReference)
         , requiredMember "actualReference" (textFragment actualReference)
         , requiredMember "expectedDigest" (textFragment expectedDigest)
         , requiredMember "actualDigest" (textFragment actualDigest)
         ])
    (\authority identity ->
       closedObjectFragment
         [ requiredMember "code" (textFragment "duplicate-rule-id")
         , requiredMember "authority" (textFragment authority)
         , requiredMember "ruleId" (textFragment identity)
         ])

viewDiscoveryAuthorityFragment :: ViewDiscoveryAuthority -> CanonicalFragment
viewDiscoveryAuthorityFragment =
  foldViewDiscoveryAuthority
    (closedObjectFragment [requiredMember "kind" (textFragment "operation")])
    (\identifier ->
       closedObjectFragment
         [ requiredMember "kind" (textFragment "adapter")
         , requiredMember "adapterId" (textFragment (adapterIdText identifier))
         ])

ruleContractBindingFragment :: RuleContractBinding -> CanonicalFragment
ruleContractBindingFragment =
  foldRuleContractBinding $ \identity version digest ->
    closedObjectFragment
      [ requiredMember "identity" (textFragment identity)
      , requiredMember "version" (textFragment version)
      , requiredMember "digest" (maybe nullFragment textFragment digest)
      ]
