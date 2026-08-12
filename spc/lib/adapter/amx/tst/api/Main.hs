{-# LANGUAGE TemplateHaskell #-}

module Main
  ( main
  ) where

import ApiContractTH
import Data.List.NonEmpty (NonEmpty)
import O2I.Adapter.AMX
import O2I.Operation.Adapter (Adapter)

$(assertFacade
    [ "NativeDocument"
    , "NativeElement"
    , "NativeFailure"
    , "AdapterRuleDefinition"
    , "AMXIdentifierDefect"
    , "AMXDescriptorDefect"
    , "AMXRuleDefinitionDefect"
    , "AMXCompilationDefect"
    ])

$(assertNoInstances ''AMXAdapterDefect [''Eq, ''Show])

main :: IO ()
main = adapterType amxAdapter >> defectFoldType foldAMXAdapterDefect

adapterType :: Either (NonEmpty AMXAdapterDefect) Adapter -> IO ()
adapterType _ = pure ()

defectFoldType ::
     (result -> result -> result -> result -> AMXAdapterDefect -> result)
  -> IO ()
defectFoldType _ = pure ()
