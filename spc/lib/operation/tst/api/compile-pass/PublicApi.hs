module PublicApi where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import O2I.Operation.Acquisition
import O2I.Operation.Adapter
import O2I.Operation.Adapter.Authoring
import O2I.Operation.Diagnostic
import O2I.Operation.Discovery.Adapter
import O2I.Operation.Discovery.Adapter.Machine
import O2I.Operation.Discovery.Profile
import O2I.Operation.Discovery.Profile.Machine
import O2I.Operation.Discovery.Rule
import O2I.Operation.Discovery.Rule.Explanation.Machine
import O2I.Operation.Discovery.Rule.Inventory.Machine
import O2I.Operation.Discovery.View
import O2I.Operation.Discovery.View.Machine (ViewDiscoveryDocument)
import qualified O2I.Operation.Discovery.View.Machine as ViewMachine
import O2I.Operation.Failure
import O2I.Operation.Machine
import O2I.Operation.Preparation
import O2I.Operation.Profile
import O2I.Operation.Provenance
import O2I.Operation.Request
import O2I.Operation.Rule.Catalog
import O2I.Operation.Schema
import O2I.Operation.View

catalogSize :: Int
catalogSize = operationRuleCatalogSize operationRuleCatalog

adapterIds :: AdapterCollection -> NonEmpty AdapterId
adapterIds = fmap adapterDescriptorId . adapterCollectionDescriptors

adapterContractIds :: AdapterCollection -> NonEmpty AdapterId
adapterContractIds =
  fmap (adapterDescriptorId . adapterContractDescriptor)
    . adapterCollectionContracts

adapterDocument :: AdapterDiscovery -> AdapterInventoryDocument
adapterDocument = adapterInventoryDocument

profileDocument :: ProfileDiscoveryCompilation -> ProfileInventoryDocument
profileDocument = profileInventoryDocument

ruleDocument :: RuleDiscoveryCompilation -> RuleInventoryDocument
ruleDocument = ruleInventoryDocument

explanationDocument :: RuleExplanation -> RuleExplanationDocument
explanationDocument = ruleExplanationDocument

viewDocument :: ToolDescriptor -> ViewDiscovery -> ViewDiscoveryDocument
viewDocument = ViewMachine.viewDiscoveryDocument

compositionTool ::
     Text -> Text -> Either (NonEmpty ToolDescriptorDefect) ToolDescriptor
compositionTool = mkToolDescriptor

consumeTool :: ToolDescriptor -> (Text, Text)
consumeTool = foldToolDescriptor (,)
