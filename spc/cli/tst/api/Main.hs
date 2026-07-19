{-# LANGUAGE TemplateHaskell #-}

module Main where

import ApiContractTH (assertFacadeContract)
import O2I.Cli

main :: IO ()
main = $(assertFacadeContract)
