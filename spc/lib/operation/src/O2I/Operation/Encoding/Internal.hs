{-# LANGUAGE OverloadedStrings #-}

-- | Internal canonical JSON primitives for capability-owned result encoders.
--
-- This is deliberately not a public JSON AST or serialization framework.
-- Capability modules assemble their fixed fields explicitly and expose only
-- completed opaque machine results.
module O2I.Operation.Encoding.Internal
  ( CanonicalFragment
  , CanonicalMember
  , MachineResult(..)
  , MachineEncodingDefect(..)
  , textFragment
  , naturalFragment
  , booleanFragment
  , nullFragment
  , arrayFragment
  , objectFragment
  , closedObjectFragment
  , requiredMember
  , optionalMember
  , machineResult
  , closedMachineResult
  , closedOperationMachineResult
  ) where

import qualified Data.ByteString as ByteString
import Data.ByteString (ByteString)
import qualified Data.ByteString.Builder as Builder
import Data.ByteString.Builder (Builder)
import qualified Data.ByteString.Lazy as LazyByteString
import Data.Char (ord)
import Data.List (group, sort)
import Data.List.NonEmpty (NonEmpty(..))
import qualified Data.List.NonEmpty as NonEmpty
import Data.Text (Text)
import qualified Data.Text as Text
import Numeric.Natural (Natural)
import O2I.Operation.Machine (ToolDescriptor, foldToolDescriptor)
import O2I.Operation.Machine.Internal
  ( OperationIdentity
  , operationIdentityValue
  )
import O2I.Operation.Schema
  ( MachineSchema
  , SchemaVariant
  , machineSchemaAuthority
  , machineSchemaVariants
  , schemaAuthorityReference
  , schemaVariantText
  )

-- | One already encoded canonical JSON value.
newtype CanonicalFragment = CanonicalFragment
  { canonicalFragmentBuilder :: Builder
  }

-- | One fixed-name member in capability-declared order.
data CanonicalMember = CanonicalMember
  { canonicalMemberName :: !Text
  , canonicalMemberFragment :: !CanonicalFragment
  }

-- | One complete immutable machine document.
data MachineResult = MachineResult
  { machineResultSchemaValue :: !MachineSchema
  , machineResultVariantValue :: !SchemaVariant
  , machineResultBytesValue :: !ByteString
  }

-- | Why fixed result fields cannot form a canonical machine document.
data MachineEncodingDefect
  = UndeclaredSchemaVariant !SchemaVariant
  | ReservedMachineMember !Text
  | DuplicateMachineMember !Text
  deriving (Eq, Show)

-- | Encode one unrestricted domain text as a canonical JSON string.
--
-- Only package-internal capability encoders may call this function. Public
-- result constructors remain opaque, so unrestricted text never crosses the
-- public machine-result boundary.
textFragment :: Text -> CanonicalFragment
textFragment value =
  CanonicalFragment
    (Builder.char7 '"'
       <> Text.foldl'
            (\encoded character -> encoded <> encodeCharacter character)
            mempty
            value
       <> Builder.char7 '"')

-- | Encode one non-negative integral scalar without exponent or leading zero.
naturalFragment :: Natural -> CanonicalFragment
naturalFragment = CanonicalFragment . Builder.string7 . show

-- | Encode one canonical JSON boolean.
booleanFragment :: Bool -> CanonicalFragment
booleanFragment value =
  CanonicalFragment
    (Builder.string7
       (if value
          then "true"
          else "false"))

-- | Encode the sole canonical null literal.
nullFragment :: CanonicalFragment
nullFragment = CanonicalFragment (Builder.string7 "null")

-- | Encode array entries in their capability-declared canonical order.
arrayFragment :: [CanonicalFragment] -> CanonicalFragment
arrayFragment entries =
  CanonicalFragment
    (Builder.char7 '['
       <> separated (fmap canonicalFragmentBuilder entries)
       <> Builder.char7 ']')

-- | Validate names and encode object members in their declared order.
objectFragment ::
     [CanonicalMember]
  -> Either (NonEmpty MachineEncodingDefect) CanonicalFragment
objectFragment members =
  case duplicateMemberDefects members of
    [] -> Right (CanonicalFragment (objectBuilder members))
    first:rest -> Left (first :| rest)

-- | Encode one capability-owned object whose fixed member names are closed by
-- its module and verified against the generated Schema contract.
closedObjectFragment :: [CanonicalMember] -> CanonicalFragment
closedObjectFragment = CanonicalFragment . objectBuilder

-- | Declare one required fixed-name member.
requiredMember :: Text -> CanonicalFragment -> CanonicalMember
requiredMember = CanonicalMember

-- | Omit an absent optional member and preserve every present value.
optionalMember :: Text -> Maybe CanonicalFragment -> [CanonicalMember]
optionalMember name = maybe [] (pure . CanonicalMember name)

-- | Close one capability result into deterministic UTF-8 JSON bytes.
--
-- The generated Schema reference and exact result discriminator are fixed
-- members. Operation-envelope metadata is reserved for the corresponding
-- closed encoder. Capability encoders own every subsequent member and its
-- omission policy. The result variant must belong to the same generated
-- Schema catalog.
machineResult ::
     MachineSchema
  -> SchemaVariant
  -> [CanonicalMember]
  -> Either (NonEmpty MachineEncodingDefect) MachineResult
machineResult schema variant members =
  case NonEmpty.nonEmpty defects of
    Just failures -> Left failures
    Nothing ->
      Right
        MachineResult
          { machineResultSchemaValue = schema
          , machineResultVariantValue = variant
          , machineResultBytesValue =
              strictBuilder
                (objectBuilder (schemaMember : kindMember : members))
          }
  where
    schemaMember =
      CanonicalMember
        "schema"
        (textFragment (schemaAuthorityReference (machineSchemaAuthority schema)))
    kindMember =
      CanonicalMember "kind" (textFragment (schemaVariantText variant))
    defects =
      variantDefects <> reservedDefects <> duplicateMemberDefects members
    variantDefects =
      [ UndeclaredSchemaVariant variant
      | variant `notElem` NonEmpty.toList (machineSchemaVariants schema)
      ]
    reservedDefects =
      [ ReservedMachineMember name
      | name <- ["schema", "operation", "tool", "kind"]
      , any ((== name) . canonicalMemberName) members
      ]

-- | Close one capability-owned document from generated Schema metadata and
-- fixed members. Variant membership and field closure are exhaustively tested
-- at the owning machine-document boundary rather than revalidated at runtime.
closedMachineResult ::
     MachineSchema -> SchemaVariant -> [CanonicalMember] -> MachineResult
closedMachineResult schema variant members =
  MachineResult
    { machineResultSchemaValue = schema
    , machineResultVariantValue = variant
    , machineResultBytesValue =
        strictBuilder (objectBuilder (schemaMember : kindMember : members))
    }
  where
    schemaMember =
      CanonicalMember
        "schema"
        (textFragment (schemaAuthorityReference (machineSchemaAuthority schema)))
    kindMember =
      CanonicalMember "kind" (textFragment (schemaVariantText variant))

-- | Close one authority-required Operation envelope in canonical member order.
--
-- Operation identity is package-internal and capability-fixed. The opaque tool
-- descriptor is supplied only by the executable composition boundary. This
-- shared primitive is the sole encoder of the four envelope members.
closedOperationMachineResult ::
     MachineSchema
  -> OperationIdentity
  -> ToolDescriptor
  -> SchemaVariant
  -> [CanonicalMember]
  -> MachineResult
closedOperationMachineResult schema operation tool variant members =
  MachineResult
    { machineResultSchemaValue = schema
    , machineResultVariantValue = variant
    , machineResultBytesValue =
        strictBuilder
          (objectBuilder
             (schemaMember : operationMember : toolMember : kindMember : members))
    }
  where
    schemaMember =
      CanonicalMember
        "schema"
        (textFragment (schemaAuthorityReference (machineSchemaAuthority schema)))
    operationMember =
      CanonicalMember
        "operation"
        (textFragment (operationIdentityValue operation))
    toolMember = CanonicalMember "tool" (toolDescriptorFragment tool)
    kindMember =
      CanonicalMember "kind" (textFragment (schemaVariantText variant))

toolDescriptorFragment :: ToolDescriptor -> CanonicalFragment
toolDescriptorFragment =
  foldToolDescriptor $ \identity version ->
    closedObjectFragment
      [ requiredMember "identity" (textFragment identity)
      , requiredMember "version" (textFragment version)
      ]

objectBuilder :: [CanonicalMember] -> Builder
objectBuilder members =
  Builder.char7 '{'
    <> separated (fmap memberBuilder members)
    <> Builder.char7 '}'

memberBuilder :: CanonicalMember -> Builder
memberBuilder member =
  canonicalFragmentBuilder (textFragment (canonicalMemberName member))
    <> Builder.char7 ':'
    <> canonicalFragmentBuilder (canonicalMemberFragment member)

duplicateMemberDefects :: [CanonicalMember] -> [MachineEncodingDefect]
duplicateMemberDefects members =
  [ DuplicateMachineMember duplicate
  | duplicate:_:_ <- group (sort (fmap canonicalMemberName members))
  ]

separated :: [Builder] -> Builder
separated [] = mempty
separated (first:rest) = first <> foldMap (Builder.char7 ',' <>) rest

strictBuilder :: Builder -> ByteString
strictBuilder =
  ByteString.concat . LazyByteString.toChunks . Builder.toLazyByteString

encodeCharacter :: Char -> Builder
encodeCharacter character =
  case character of
    '"' -> Builder.string7 "\\\""
    '\\' -> Builder.string7 "\\\\"
    '\b' -> Builder.string7 "\\b"
    '\t' -> Builder.string7 "\\t"
    '\n' -> Builder.string7 "\\n"
    '\f' -> Builder.string7 "\\f"
    '\r' -> Builder.string7 "\\r"
    _
      | ord character < 0x20 -> unicodeControl character
      | otherwise -> Builder.charUtf8 character

unicodeControl :: Char -> Builder
unicodeControl character =
  Builder.string7 "\\u00"
    <> Builder.char7 (hexDigit (ord character `div` 16))
    <> Builder.char7 (hexDigit (ord character `mod` 16))

hexDigit :: Int -> Char
hexDigit value
  | value < 10 = toEnum (fromEnum '0' + value)
  | otherwise = toEnum (fromEnum 'A' + value - 10)
