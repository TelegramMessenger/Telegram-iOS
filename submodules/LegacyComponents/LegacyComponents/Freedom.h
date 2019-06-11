#ifndef Freedom_h
#define Freedom_h

#import <Foundation/Foundation.h>
#import <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif
    
typedef struct {
    const char *string;
    uint32_t key;
} FreedomIdentifier;
    
char *copyFreedomIdentifierValue(FreedomIdentifier identifier);
    
extern FreedomIdentifier FreedomIdentifierEmpty;
    
typedef struct {
    uint32_t name;
    IMP imp;
    FreedomIdentifier newIdentifier;
    FreedomIdentifier newEncoding;
} FreedomDecoration;
    
typedef struct {
    ptrdiff_t offset;
    int bit;
} FreedomBitfield;
    
void freedomInit();
bool freedomInitialized();
    
Class freedomClass(uint32_t name);
Class freedomMakeClass(Class superclass, Class subclass);
ptrdiff_t freedomIvarOffset(Class targetClass, uint32_t name);
FreedomBitfield freedomIvarBitOffset(Class targetClass, uint32_t fieldName, uint32_t bitfieldName);
FreedomBitfield freedomIvarBitOffset2(Class targetClass, uint32_t fieldName, uint32_t bitfieldName);
void freedomSetBitfield(void *object, FreedomBitfield bitfield, int value);
int freedomGetBitfield(void *object, FreedomBitfield bitfield);
void freedomDumpBitfields(Class targetClass, void *object, uint32_t fieldName);
    
IMP freedomNativeImpl(Class targetClass, SEL selector);
void freedomClassAutoDecorate(uint32_t name, FreedomDecoration *classDecorations, int numClassDecorations, FreedomDecoration *instanceDecorations, int numInstanceDecorations);
void freedomClassAutoDecorateExplicit(Class c, uint32_t name, FreedomDecoration *classDecorations, int numClassDecorations, FreedomDecoration *instanceDecorations, int numInstanceDecorations);
IMP freedomImpl(id target, uint32_t name, SEL *selector);
IMP freedomImplInstancesOfClass(Class targetClass, uint32_t name, SEL *selector);

#ifdef __cplusplus
}
#endif

#endif
