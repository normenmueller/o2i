{-# LANGUAGE ExplicitNamespaces #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Closed machine document for one authority-local Rule inventory.
module O2I.Operation.Discovery.Rule.Inventory.Machine
  ( type RuleInventoryDocument
  , ruleInventoryDocument
  , ruleInventorySchema
  , ruleInventoryDocumentVariant
  , encodeRuleInventoryDocument
  ) where

import Data.ByteString (ByteString)
import qualified Data.List.NonEmpty as NonEmpty
import O2I.Operation.Discovery.Machine.Internal
  ( discoveredRuleFragment
  , ruleAuthorityFragment
  , ruleDiscoveryDefectFragment
  )
import O2I.Operation.Discovery.Rule
  ( RuleDiscoveryCompilation
  , foldRuleDiscovery
  , foldRuleDiscoveryCompilation
  )
import O2I.Operation.Encoding.Internal
  ( MachineResult(..)
  , arrayFragment
  , closedMachineResult
  , requiredMember
  )
import O2I.Operation.Schema (MachineSchema, SchemaVariant)
import qualified O2I.Operation.Schema.Generated as Generated

-- | One immutable Rule inventory or static-definition-failure document.
newtype RuleInventoryDocument =
  RuleInventoryDocument MachineResult

-- | Project every Rule compilation branch into its exact machine variant.
ruleInventoryDocument :: RuleDiscoveryCompilation -> RuleInventoryDocument
ruleInventoryDocument = foldRuleDiscoveryCompilation invalid compiled
  where
    invalid defects =
      RuleInventoryDocument
        (closedMachineResult
           Generated.ruleInventoryMachineSchema
           Generated.ruleDefinitionInvalidVariant
           [ requiredMember
               "diagnostics"
               (arrayFragment
                  (fmap ruleDiscoveryDefectFragment (NonEmpty.toList defects)))
           ])
    compiled discovery =
      foldRuleDiscovery
        (\authority rows ->
           RuleInventoryDocument
             (closedMachineResult
                Generated.ruleInventoryMachineSchema
                Generated.ruleInventoryVariant
                [ requiredMember "authority" (ruleAuthorityFragment authority)
                , requiredMember
                    "rules"
                    (arrayFragment
                       (fmap discoveredRuleFragment (NonEmpty.toList rows)))
                ]))
        discovery

-- | Exact generated Schema authority for Rule inventory documents.
ruleInventorySchema :: MachineSchema
ruleInventorySchema = Generated.ruleInventoryMachineSchema

-- | Exact constructor discriminator selected by Rule compilation.
ruleInventoryDocumentVariant :: RuleInventoryDocument -> SchemaVariant
ruleInventoryDocumentVariant (RuleInventoryDocument result) =
  machineResultVariantValue result

-- | Deterministic canonical UTF-8 JSON bytes.
encodeRuleInventoryDocument :: RuleInventoryDocument -> ByteString
encodeRuleInventoryDocument (RuleInventoryDocument result) =
  machineResultBytesValue result
