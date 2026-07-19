{-# LANGUAGE TemplateHaskell #-}

module Main
  ( main
  ) where

import ApiContractTH
import O2I.Adapter.AMX
import O2I.Inspection.Adapter (Adapter)

$(assertFacade
    [ "AMXDocument"
    , "AMXSelectedView"
    , "AMXProfileFact"
    , "AMXDecodeDefect"
    , "AMXViewDefect"
    , "AMXProfileDefect"
    ])

main :: IO ()
main = adapterType amxAdapter

adapterType :: Adapter -> IO ()
adapterType _ = pure ()
