{-# LANGUAGE TemplateHaskell #-}

-- | Package-internal compile-time embedding of generated Schema bytes.
module O2I.Operation.Schema.Embed
  ( embedSchemaBytes
  ) where

import qualified Data.ByteString as ByteString
import Language.Haskell.TH.Syntax
  ( Exp
  , Q
  , lift
  , loc_filename
  , location
  , qAddDependentFile
  , runIO
  )
import System.FilePath ((</>), normalise, takeDirectory)

-- | Embed one generated Schema relative to the calling generated module.
--
-- The dependency is tracked by GHC, and the resulting strict bytes live in
-- the compiled package rather than being read from a runtime registry.
embedSchemaBytes :: FilePath -> Q Exp
embedSchemaBytes relativePath = do
  callSite <- location
  let schemaPath =
        normalise (takeDirectory (loc_filename callSite) </> relativePath)
  qAddDependentFile schemaPath
  bytes <- runIO (ByteString.readFile schemaPath)
  [|ByteString.pack $(lift (ByteString.unpack bytes))|]
