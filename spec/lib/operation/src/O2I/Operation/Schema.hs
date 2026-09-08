{-# LANGUAGE ExplicitNamespaces #-}

-- | Immutable generated JSON Schema authorities for machine results.
--
-- Schemas are compiled package assets. They identify and verify result
-- contracts, but are never loaded as runtime input or treated as domain
-- authorities.
module O2I.Operation.Schema
  ( type SchemaIdentity
  , schemaIdentityText
  , type SchemaVersion
  , schemaVersionValue
  , type SchemaDigest
  , schemaDigestText
  , type SchemaVariant
  , schemaVariantText
  , type SchemaAuthority
  , schemaAuthorityIdentity
  , schemaAuthorityVersion
  , schemaAuthorityDigest
  , schemaAuthorityReference
  , foldSchemaAuthority
  , type MachineSchema
  , machineSchemaAuthority
  , machineSchemaVariants
  , foldMachineSchema
  ) where

import Data.List.NonEmpty (NonEmpty)
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.Operation.Schema.Internal

-- | Project the stable Schema identity.
schemaIdentityText :: SchemaIdentity -> Text
schemaIdentityText (SchemaIdentity value) = value

-- | Project the positive machine-contract version.
schemaVersionValue :: SchemaVersion -> Natural
schemaVersionValue (SchemaVersion value) = value

-- | Project the lowercase hexadecimal digest of exact generated Schema bytes.
schemaDigestText :: SchemaDigest -> Text
schemaDigestText (SchemaDigest value) = value

-- | Project one stable result-constructor discriminator.
schemaVariantText :: SchemaVariant -> Text
schemaVariantText (SchemaVariant value) = value

-- | Project the stable identity of one generated Schema authority.
schemaAuthorityIdentity :: SchemaAuthority -> SchemaIdentity
schemaAuthorityIdentity = schemaAuthorityIdentityValue

-- | Project the version of one generated Schema authority.
schemaAuthorityVersion :: SchemaAuthority -> SchemaVersion
schemaAuthorityVersion = schemaAuthorityVersionValue

-- | Project the digest of the exact generated Schema bytes.
schemaAuthorityDigest :: SchemaAuthority -> SchemaDigest
schemaAuthorityDigest = schemaAuthorityDigestValue

-- | Render the canonical document-level Schema reference.
schemaAuthorityReference :: SchemaAuthority -> Text
schemaAuthorityReference authority =
  schemaIdentityText (schemaAuthorityIdentity authority)
    <> Text.pack "/v"
    <> Text.pack (show (schemaVersionValue (schemaAuthorityVersion authority)))

-- | Consume every immutable Schema-authority field in canonical order.
foldSchemaAuthority ::
     (SchemaIdentity -> SchemaVersion -> SchemaDigest -> result)
  -> SchemaAuthority
  -> result
foldSchemaAuthority consume authority =
  consume
    (schemaAuthorityIdentityValue authority)
    (schemaAuthorityVersionValue authority)
    (schemaAuthorityDigestValue authority)

-- | Project the generated Schema authority of one result algebra.
machineSchemaAuthority :: MachineSchema -> SchemaAuthority
machineSchemaAuthority = machineSchemaAuthorityValue

-- | Project every admitted constructor discriminator in declaration order.
machineSchemaVariants :: MachineSchema -> NonEmpty SchemaVariant
machineSchemaVariants = machineSchemaVariantsValue

-- | Consume the complete immutable machine-Schema metadata.
foldMachineSchema ::
     (SchemaAuthority -> NonEmpty SchemaVariant -> result)
  -> MachineSchema
  -> result
foldMachineSchema consume schema =
  consume
    (machineSchemaAuthorityValue schema)
    (machineSchemaVariantsValue schema)
