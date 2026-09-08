{-# LANGUAGE ExplicitNamespaces #-}

-- | Static adapter discovery over one immutable compiled collection.
--
-- Enumeration follows canonical adapter-identity order. Exact lookup is
-- discovery only and never selects adapter behavior.
module O2I.Operation.Discovery.Adapter
  ( type AdapterDiscovery
  , discoverAdapters
  , discoveredAdapters
  , lookupDiscoveredAdapter
  , foldAdapterDiscovery
  ) where

import Data.List.NonEmpty (NonEmpty)
import qualified Data.List.NonEmpty as NonEmpty
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import O2I.Operation.Adapter
  ( AdapterCollection
  , AdapterDescriptor
  , AdapterId
  , adapterCollectionDescriptors
  , adapterDescriptorId
  )

-- | Canonical adapter rows and their exact identity index.
data AdapterDiscovery =
  AdapterDiscovery
    !(NonEmpty AdapterDescriptor)
    !(Map AdapterId AdapterDescriptor)

-- | Materialize the complete static adapter inventory in @O(A log A)@.
discoverAdapters :: AdapterCollection -> AdapterDiscovery
discoverAdapters collection = AdapterDiscovery rows byIdentity
  where
    rows = adapterCollectionDescriptors collection
    byIdentity =
      Map.fromList
        [ (adapterDescriptorId descriptor, descriptor)
        | descriptor <- NonEmpty.toList rows
        ]

-- | Enumerate every compiled adapter in canonical identity order.
discoveredAdapters :: AdapterDiscovery -> NonEmpty AdapterDescriptor
discoveredAdapters (AdapterDiscovery rows _) = rows

-- | Look up one exact adapter identity in @O(log A)@ without normalization.
lookupDiscoveredAdapter ::
     AdapterId -> AdapterDiscovery -> Maybe AdapterDescriptor
lookupDiscoveredAdapter identifier (AdapterDiscovery _ byIdentity) =
  Map.lookup identifier byIdentity

-- | Consume the complete canonical adapter inventory.
foldAdapterDiscovery ::
     (NonEmpty AdapterDescriptor -> result) -> AdapterDiscovery -> result
foldAdapterDiscovery consume (AdapterDiscovery rows _) = consume rows
