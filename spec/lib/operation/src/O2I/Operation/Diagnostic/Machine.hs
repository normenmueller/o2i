{-# LANGUAGE ExplicitNamespaces #-}

-- | Canonical machine encoding and generated authority for owner diagnostics.
module O2I.Operation.Diagnostic.Machine
  ( diagnosticSchemaAuthority
  , encodePreparedDiagnosticDocument
  ) where

import Data.ByteString (ByteString)
import O2I.Operation.Diagnostic (PreparedDiagnosticDocument)
import O2I.Operation.Encoding.Internal (canonicalFragmentBytes)
import O2I.Operation.Machine.Fragment.Internal
  ( preparedDiagnosticDocumentFragment
  )
import O2I.Operation.Schema (SchemaAuthority)
import qualified O2I.Operation.Schema.Generated as Generated

-- | Exact generated JSON Schema authority for prepared diagnostic documents.
diagnosticSchemaAuthority :: SchemaAuthority
diagnosticSchemaAuthority = Generated.diagnosticSchemaAuthority

-- | Deterministic canonical UTF-8 JSON bytes for one closed document.
encodePreparedDiagnosticDocument :: PreparedDiagnosticDocument -> ByteString
encodePreparedDiagnosticDocument =
  canonicalFragmentBytes . preparedDiagnosticDocumentFragment
