module HiddenSourceBinding where

import qualified O2I.Inspection.Input as Input

missingSourceDocumentLocator :: Input.SourceDocument -> ()
missingSourceDocumentLocator document = Input.sourceDocumentLocator document

missingDocumentPositionBinding :: Input.SourceDocument -> ()
missingDocumentPositionBinding document = Input.bindDocumentPosition document
