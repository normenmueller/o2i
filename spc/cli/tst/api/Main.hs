{-# LANGUAGE TemplateHaskell #-}

module Main where

import ApiContractTH (assertFacadeContract)
import O2I.Cli
import PublicComposition (selectedProfileRules)

main :: IO ()
main = selectedProfileRules `seq` $(assertFacadeContract)
