module OpaqueVocabularyConstructors where

import qualified O2I.ArchiMate.Profile as Profile

forgedRequired :: Profile.Requirement
forgedRequired = Profile.Required

forgedForbidden :: Profile.Requirement
forgedForbidden = Profile.Forbidden

forgedExactlyOne :: Profile.Cardinality
forgedExactlyOne = Profile.ExactlyOne

forgedExactlyOneEach :: Profile.Cardinality
forgedExactlyOneEach = Profile.ExactlyOneEach

forgedExactlyOneNonEmpty :: Profile.Cardinality
forgedExactlyOneNonEmpty = Profile.ExactlyOneNonEmpty

forgedAtLeastTwo :: Profile.Cardinality
forgedAtLeastTwo = Profile.AtLeastTwo
