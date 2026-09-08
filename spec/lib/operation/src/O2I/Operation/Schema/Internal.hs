{-# LANGUAGE OverloadedStrings #-}

-- | Internal construction of immutable machine-schema authorities.
module O2I.Operation.Schema.Internal
  ( SchemaIdentity(..)
  , SchemaVersion(..)
  , SchemaDigest(..)
  , SchemaVariant(..)
  , SchemaAuthority(..)
  , MachineSchema(..)
  , SchemaDefinitionDefect(..)
  , defineMachineSchema
  ) where

import qualified Crypto.Hash.SHA256 as SHA256
import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import Data.Char (isAsciiLower, isDigit)
import Data.List (group, sort)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Numeric (showHex)
import Numeric.Natural (Natural)

-- | Stable identity of one generated JSON Schema.
newtype SchemaIdentity = SchemaIdentity
  { schemaIdentityValue :: Text
  } deriving (Eq, Ord, Show)

-- | Positive version of one machine contract.
newtype SchemaVersion = SchemaVersion
  { schemaVersionValueInternal :: Natural
  } deriving (Eq, Ord, Show)

-- | Lowercase hexadecimal SHA-256 of the exact generated Schema bytes.
newtype SchemaDigest = SchemaDigest
  { schemaDigestValue :: Text
  } deriving (Eq, Ord, Show)

-- | Stable discriminator of one constructor in the owning result algebra.
newtype SchemaVariant = SchemaVariant
  { schemaVariantValue :: Text
  } deriving (Eq, Ord, Show)

-- | Immutable public identity, version, and digest of one generated Schema.
data SchemaAuthority = SchemaAuthority
  { schemaAuthorityIdentityValue :: !SchemaIdentity
  , schemaAuthorityVersionValue :: !SchemaVersion
  , schemaAuthorityDigestValue :: !SchemaDigest
  } deriving (Eq, Ord, Show)

-- | Closed metadata shared by one result ADT, its encoder, and its Schema.
data MachineSchema = MachineSchema
  { machineSchemaAuthorityValue :: !SchemaAuthority
  , machineSchemaVariantsValue :: !(NonEmpty SchemaVariant)
  } deriving (Eq, Show)

-- | Why generated Schema metadata cannot become a machine authority.
data SchemaDefinitionDefect
  = InvalidSchemaIdentity !Text
  | InvalidSchemaVersion !Natural
  | EmptySchemaDocument
  | InvalidSchemaVariant !Text
  | DuplicateSchemaVariant !Text
  deriving (Eq, Ord, Show)

-- | Validate generated metadata and bind it to exact generated Schema bytes.
--
-- This function is intentionally package-internal. Accepted generated modules
-- call it once for their checked-in authority; runtime input never does.
defineMachineSchema ::
     Text
  -> Natural
  -> NonEmpty Text
  -> ByteString
  -> Either (NonEmpty SchemaDefinitionDefect) MachineSchema
defineMachineSchema identity version variants schemaBytes =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      Right
        MachineSchema
          { machineSchemaAuthorityValue =
              SchemaAuthority
                { schemaAuthorityIdentityValue = SchemaIdentity identity
                , schemaAuthorityVersionValue = SchemaVersion version
                , schemaAuthorityDigestValue =
                    SchemaDigest (sha256Hex schemaBytes)
                }
          , machineSchemaVariantsValue = fmap SchemaVariant variants
          }
  where
    defects =
      identityDefects
        <> versionDefects
        <> documentDefects
        <> variantDefects
        <> duplicateVariantDefects
    identityDefects =
      [InvalidSchemaIdentity identity | not (validSchemaIdentity identity)]
    versionDefects = [InvalidSchemaVersion version | version == 0]
    documentDefects = [EmptySchemaDocument | ByteString.null schemaBytes]
    variantValues = NonEmpty.toList variants
    variantDefects =
      [ InvalidSchemaVariant variant
      | variant <- variantValues
      , not (validToken variant)
      ]
    duplicateVariantDefects =
      [ DuplicateSchemaVariant duplicate
      | duplicate:_:_ <- group (sort variantValues)
      ]

validSchemaIdentity :: Text -> Bool
validSchemaIdentity value =
  case Text.splitOn "." value of
    [] -> False
    segments -> all validToken segments

validToken :: Text -> Bool
validToken value =
  case Text.unpack value of
    [] -> False
    first:rest ->
      isAsciiLower first
        && validTail rest
        && maybe False asciiAlphaNumeric (lastCharacter value)
        && not ("--" `Text.isInfixOf` value)
  where
    validTail =
      all (\character -> asciiAlphaNumeric character || character == '-')

asciiAlphaNumeric :: Char -> Bool
asciiAlphaNumeric character = isAsciiLower character || isDigit character

lastCharacter :: Text -> Maybe Char
lastCharacter value = snd <$> Text.unsnoc value

sha256Hex :: ByteString -> Text
sha256Hex =
  TextEncoding.decodeUtf8
    . ByteString.pack
    . concatMap hexByte
    . ByteString.unpack
    . SHA256.hash
  where
    hexByte byte =
      case showHex byte "" of
        [digit] -> fmap (fromIntegral . fromEnum) ['0', digit]
        digits -> fmap (fromIntegral . fromEnum) digits
