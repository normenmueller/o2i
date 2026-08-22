module ClosureOpaqueConstructor where

import qualified O2I.ArchiMate.Profile.Closure as Closure

forgedClosure :: Closure.ProfileAssessmentUniverse profile document
forgedClosure = Closure.ProfileAssessmentUniverse undefined

forgedActivation :: Closure.ActivationProvenance profile document
forgedActivation = Closure.ActivationProvenance undefined

forgedProvenance :: Closure.ClosureProvenance profile document
forgedProvenance = Closure.ClosureProvenance undefined
