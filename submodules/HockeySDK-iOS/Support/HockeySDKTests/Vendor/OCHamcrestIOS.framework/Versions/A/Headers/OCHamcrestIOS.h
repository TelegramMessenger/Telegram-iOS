//  OCHamcrest by Jon Reid, http://qualitycoding.org/about/
//  Copyright 2016 hamcrest.org. See LICENSE.txt

#import <OCHamcrestIOS/HCAllOf.h>
#import <OCHamcrestIOS/HCAnyOf.h>
#import <OCHamcrestIOS/HCArgumentCaptor.h>
#import <OCHamcrestIOS/HCAssertThat.h>
#import <OCHamcrestIOS/HCConformsToProtocol.h>
#import <OCHamcrestIOS/HCDescribedAs.h>
#import <OCHamcrestIOS/HCEvery.h>
#import <OCHamcrestIOS/HCHasCount.h>
#import <OCHamcrestIOS/HCHasDescription.h>
#import <OCHamcrestIOS/HCHasProperty.h>
#import <OCHamcrestIOS/HCIs.h>
#import <OCHamcrestIOS/HCIsAnything.h>
#import <OCHamcrestIOS/HCIsCloseTo.h>
#import <OCHamcrestIOS/HCIsCollectionContaining.h>
#import <OCHamcrestIOS/HCIsCollectionContainingInAnyOrder.h>
#import <OCHamcrestIOS/HCIsCollectionContainingInOrder.h>
#import <OCHamcrestIOS/HCIsCollectionContainingInRelativeOrder.h>
#import <OCHamcrestIOS/HCIsCollectionOnlyContaining.h>
#import <OCHamcrestIOS/HCIsDictionaryContaining.h>
#import <OCHamcrestIOS/HCIsDictionaryContainingEntries.h>
#import <OCHamcrestIOS/HCIsDictionaryContainingKey.h>
#import <OCHamcrestIOS/HCIsDictionaryContainingValue.h>
#import <OCHamcrestIOS/HCIsEmptyCollection.h>
#import <OCHamcrestIOS/HCIsEqual.h>
#import <OCHamcrestIOS/HCIsEqualIgnoringCase.h>
#import <OCHamcrestIOS/HCIsEqualCompressingWhiteSpace.h>
#import <OCHamcrestIOS/HCIsEqualToNumber.h>
#import <OCHamcrestIOS/HCIsIn.h>
#import <OCHamcrestIOS/HCIsInstanceOf.h>
#import <OCHamcrestIOS/HCIsNil.h>
#import <OCHamcrestIOS/HCIsNot.h>
#import <OCHamcrestIOS/HCIsSame.h>
#import <OCHamcrestIOS/HCIsTrueFalse.h>
#import <OCHamcrestIOS/HCIsTypeOf.h>
#import <OCHamcrestIOS/HCNumberAssert.h>
#import <OCHamcrestIOS/HCOrderingComparison.h>
#import <OCHamcrestIOS/HCStringContains.h>
#import <OCHamcrestIOS/HCStringContainsInOrder.h>
#import <OCHamcrestIOS/HCStringEndsWith.h>
#import <OCHamcrestIOS/HCStringStartsWith.h>
#import <OCHamcrestIOS/HCTestFailure.h>
#import <OCHamcrestIOS/HCTestFailureReporter.h>
#import <OCHamcrestIOS/HCTestFailureReporterChain.h>
#import <OCHamcrestIOS/HCThrowsException.h>

// Carthage workaround: Include transitive public headers
#import <OCHamcrestIOS/HCBaseDescription.h>
#import <OCHamcrestIOS/HCCollect.h>
#import <OCHamcrestIOS/HCRequireNonNilObject.h>
#import <OCHamcrestIOS/HCStringDescription.h>
#import <OCHamcrestIOS/HCWrapInMatcher.h>
