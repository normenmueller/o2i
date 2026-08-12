{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine document for one exact Rule-explanation request.
module O2I.Operation.Discovery.Rule.Explanation.Machine
  ( type RuleExplanationDocument
  , ruleExplanationDocument
  , ruleExplanationSchema
  , ruleExplanationDocumentVariant
  , encodeRuleExplanationDocument
  ) where

import Data.ByteString (ByteString)
import O2I.Operation.Discovery.Machine.Internal
  ( discoveredRuleFragment
  , ruleAuthorityFragment
  )
import O2I.Operation.Discovery.Rule (RuleExplanation, foldRuleExplanation)
import O2I.Operation.Encoding.Internal
  ( MachineResult(..)
  , closedMachineResult
  , requiredMember
  , textFragment
  )
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated

-- | One immutable found or not-found Rule explanation document.
newtype RuleExplanationDocument =
  RuleExplanationDocument MachineResult

-- | Preserve authority and exact request in every explanation branch.
ruleExplanationDocument :: RuleExplanation -> RuleExplanationDocument
ruleExplanationDocument = foldRuleExplanation found notFound
  where
    found authority requested rule =
      RuleExplanationDocument
        (closedMachineResult
           Generated.ruleExplanationMachineSchema
           Generated.ruleExplanationFoundVariant
           [ requiredMember "authority" (ruleAuthorityFragment authority)
           , requiredMember "requestedRuleId" (textFragment requested)
           , requiredMember "rule" (discoveredRuleFragment rule)
           ])
    notFound authority requested =
      RuleExplanationDocument
        (closedMachineResult
           Generated.ruleExplanationMachineSchema
           Generated.ruleExplanationNotFoundVariant
           [ requiredMember "authority" (ruleAuthorityFragment authority)
           , requiredMember "requestedRuleId" (textFragment requested)
           ])

-- | Exact generated Schema authority for Rule explanation documents.
ruleExplanationSchema :: MachineSchema
ruleExplanationSchema = Generated.ruleExplanationMachineSchema

-- | Exact constructor discriminator selected by the lookup result.
ruleExplanationDocumentVariant :: RuleExplanationDocument -> SchemaVariant
ruleExplanationDocumentVariant (RuleExplanationDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeRuleExplanationDocument :: RuleExplanationDocument -> ByteString
encodeRuleExplanationDocument (RuleExplanationDocument result) =
  machineResultBytesValue result
