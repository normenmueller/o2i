module MachineDocumentTypeSeparation where

import qualified Data.ByteString
import O2I.Operation.Discovery.Adapter.Machine
import O2I.Operation.Discovery.Profile.Machine
import O2I.Operation.Discovery.Rule.Explanation.Machine
import O2I.Operation.Discovery.Rule.Inventory.Machine
import O2I.Operation.Discovery.View.Machine

adapterAsProfile :: AdapterInventoryDocument -> Data.ByteString.ByteString
adapterAsProfile = encodeProfileInventoryDocument

profileAsRule :: ProfileInventoryDocument -> Data.ByteString.ByteString
profileAsRule = encodeRuleInventoryDocument

ruleAsExplanation :: RuleInventoryDocument -> Data.ByteString.ByteString
ruleAsExplanation = encodeRuleExplanationDocument

explanationAsView :: RuleExplanationDocument -> Data.ByteString.ByteString
explanationAsView = encodeViewDiscoveryDocument

viewAsAdapter :: ViewDiscoveryDocument -> Data.ByteString.ByteString
viewAsAdapter = encodeAdapterInventoryDocument
