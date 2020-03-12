#import "Freedom.h"

#import <objc/runtime.h>
#import <objc/message.h>

#import <map>

#include <inttypes.h>

#define FORCE_INLINE __attribute__((always_inline))

static inline uint32_t rotl32 ( uint32_t x, int8_t r )
{
    return (x << r) | (x >> (32 - r));
}

#define ROTL32(x,y)     rotl32(x,y)

static FORCE_INLINE uint32_t getblock ( const uint32_t * p, int i )
{
    return p[i];
}

static FORCE_INLINE uint32_t fmix ( uint32_t h )
{
    h ^= h >> 16;
    h *= 0x85ebca6b;
    h ^= h >> 13;
    h *= 0xc2b2ae35;
    h ^= h >> 16;
    
    return h;
}

static void MurmurHash3_x86_32 ( const void * key, int len,
                                uint32_t seed, void * out )
{
    const uint8_t * data = (const uint8_t*)key;
    const int nblocks = len / 4;
    
    uint32_t h1 = seed;
    
    const uint32_t c1 = 0xcc9e2d51;
    const uint32_t c2 = 0x1b873593;
    
    //----------
    // body
    
    const uint32_t * blocks = (const uint32_t *)(data + nblocks*4);
    
    for(int i = -nblocks; i; i++)
    {
        uint32_t k1 = getblock(blocks,i);
        
        k1 *= c1;
        k1 = ROTL32(k1,15);
        k1 *= c2;
        
        h1 ^= k1;
        h1 = ROTL32(h1,13);
        h1 = h1*5+0xe6546b64;
    }
    
    //----------
    // tail
    
    const uint8_t * tail = (const uint8_t*)(data + nblocks*4);
    
    uint32_t k1 = 0;
    
    switch(len & 3)
    {
        case 3: k1 ^= tail[2] << 16;
        case 2: k1 ^= tail[1] << 8;
        case 1: k1 ^= tail[0];
            k1 *= c1; k1 = ROTL32(k1,15); k1 *= c2; h1 ^= k1;
    };
    
    //----------
    // finalization
    
    h1 ^= len;
    
    h1 = fmix(h1);
    
    *(uint32_t*)out = h1;
}

static int32_t murMurHashBytes32(void *bytes, int length)
{
    int32_t result = 0;
    MurmurHash3_x86_32(bytes, length, -137723950, &result);
    
    return result;
}

static const char *freedomDecoratedClass = "freedomDecoratedClass";

static int (*freedom_getClassList)(Class *, int) = NULL;
static const char * (*freedom_class_getName)(Class cls) = NULL;
static bool freedom_initialized = false;

FreedomIdentifier FreedomIdentifierEmpty = (FreedomIdentifier){ .string = NULL, .key = 0 };

char *copyFreedomIdentifierValue(FreedomIdentifier identifier)
{
    if (identifier.string == NULL)
        return NULL;
    
    int length = (int)strlen(identifier.string) / 2;
    char *buf = (char *)malloc(length + 1);
    buf[length] = 0;
    
    for (int i = 0; i < length; i++)
    {
        int b = 0;
        sscanf(identifier.string + i * 2, "%02x", &b);
        buf[i] = ((char)b) ^ (((uint8_t *)&identifier.key)[i % 4]);
    }
    
    return buf;
}

Class freedomClass(uint32_t name)
{
    static std::map<uint32_t, __unsafe_unretained Class> classMap;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        int classCount = freedom_getClassList(NULL, 0);
        if (classCount > 0)
        {
            __unsafe_unretained Class *classList = (Class *)malloc(classCount * sizeof(Class));
            objc_getClassList(classList, classCount);
            
            for (int i = 0; i < classCount; i++)
            {
                const char *className = freedom_class_getName(classList[i]);
                uint32_t hashName = (uint32_t)murMurHashBytes32((void *)className, (int)strlen(className));
                //NSLog(@"0x%" PRIx32 " -> %s", hashName, className);
                classMap[hashName] = classList[i];
            }
            
            free(classList);
        }
        freedom_initialized = true;
    });
    
    auto it = classMap.find(name);
    if (it != classMap.end())
        return it->second;
    
    return nil;
}

Class freedomMakeClass(Class superclass, Class subclass)
{
    if (superclass == Nil || subclass == Nil)
        return nil;
    
    int32_t randomId = 0;
    arc4random_buf(&randomId, 4);
    Class decoratedClass = objc_allocateClassPair(superclass, [[NSString alloc] initWithFormat:@"Decorated%" PRIx32 "", randomId].UTF8String, 0);
    
    unsigned int count = 0;
    Method *methodList = class_copyMethodList(subclass, &count);
    if (methodList != NULL)
    {
        for (unsigned int i = 0; i < count; i++)
        {
            class_addMethod(decoratedClass, method_getName(methodList[i]), method_getImplementation(methodList[i]), method_getTypeEncoding(methodList[i]));
        }
        
        free(methodList);
    }
    
    objc_registerClassPair(decoratedClass);
    
    return decoratedClass;
}

ptrdiff_t freedomIvarOffset(Class targetClass, uint32_t name)
{
    ptrdiff_t result = -1;
    
    unsigned int count = 0;
    Ivar *ivarList = class_copyIvarList(targetClass, &count);
    
    if (ivarList != NULL)
    {
        for (unsigned int i = 0; i < count; i++)
        {
            const char *ivarName = ivar_getName(ivarList[i]);
            uint32_t hashName = (uint32_t)murMurHashBytes32((void *)ivarName, (int)strlen(ivarName));
            //NSLog(@"%s -> 0x%x", ivarName, hashName);
            if (hashName == name)
            {
                result = ivar_getOffset(ivarList[i]);
            }
        }
        
        free(ivarList);
    }
    
    return result;
}

static bool consumeToken(const char *desc, int length, int &offset, const char *token)
{
    size_t tokenLength = strlen(token);
    if (offset + (int)tokenLength > length)
        return false;
    
    if (strncmp(desc + offset, token, tokenLength))
        return false;
    
    offset += tokenLength;
    return true;
}

static bool consumeNumber(const char *desc, int length, int &offset, int &number)
{
    if (offset + 1 > length)
        return false;
    
    int result = 0;
    
    for (int i = offset; i < length; i++)
    {
        if (desc[i] < '0' || desc[i] > '9')
        {
            if (i != offset)
            {
                number = result;
                offset = i;
                return true;
            }
            
            return false;
        }
        else
            result = result * 10 + (desc[i] - '0');
    }
    
    return false;
}

static bool consumeField(const char *desc, int length, int &offset, uint32_t &outName, int &outBitSize)
{
    if (!consumeToken(desc, length, offset, "\""))
        return false;
    
    for (int i = offset; i < length; i++)
    {
        if (desc[i] == '"')
        {
            outName = (uint32_t)murMurHashBytes32((void *)(desc + offset), i - offset);
            
            char buf[i - offset + 1];
            memcpy(buf, desc + offset, i - offset);
            buf[i - offset] = 0;
            
            int newOffset = i + 1;
            if (consumeToken(desc, length, newOffset, "b"))
            {
                int fieldLength = 0;
                if (consumeNumber(desc, length, newOffset, fieldLength))
                {
                    offset = newOffset;
                    outBitSize = fieldLength;
                    //NSLog(@"%s", buf);
                    return true;
                }
                else
                    return false;
            }
            else if (consumeToken(desc, length, newOffset, "I"))
            {
                offset = newOffset;
                outBitSize = sizeof(unsigned int) * 8;
                //NSLog(@"%s", buf);
                return true;
            }
            else
                return false;
            
            break;
        }
    }
    
    return false;
}

static int freedomBitfieldOffsetInBits(const char *desc, uint32_t name)
{
    size_t length = strlen(desc);
    int offset = 0;
    
    if (!consumeToken(desc, (int)length, offset, "{?="))
        return -1;
    
    int currentBitOffset = 0;
    while (true)
    {
        uint32_t fieldName = 0;
        int bitLength = 0;
        if (consumeField(desc, (int)length, offset, fieldName, bitLength))
        {
            if (fieldName == name)
                return currentBitOffset;
            
            currentBitOffset += bitLength;
        }
        else
            break;
    }
    
    return -1;
}

static void freedomDumpBitfieldsByDescription(void *address, const char *desc)
{
    size_t length = strlen(desc);
    int offset = 0;
    
    if (!consumeToken(desc, (int)length, offset, "{?="))
        return;
    
    int currentBitOffset = 0;
    while (true)
    {
        uint32_t fieldName = 0;
        int bitLength = 0;
        if (consumeField(desc, (int)length, offset, fieldName, bitLength))
        {
            if (bitLength == 1)
            {
                uint8_t *value = ((uint8_t *)address) + currentBitOffset / 8 + (currentBitOffset % 8 == 0 ? 0 : 1);
                NSLog(@" : %d", ((*value) & ((uint8_t)(1 << (8 - currentBitOffset % 8)))) != 0 ? 1 : 0);
            }
            
            currentBitOffset += bitLength;
        }
        else
            break;
    }
}

FreedomBitfield freedomIvarBitOffset(Class targetClass, uint32_t fieldName, uint32_t bitfieldName)
{
    FreedomBitfield result = {.offset = -1, .bit = -1 };
    
    unsigned int count = 0;
    Ivar *ivarList = class_copyIvarList(targetClass, &count);
    
    if (ivarList != NULL)
    {
        for (unsigned int i = 0; i < count; i++)
        {
            const char *ivarName = ivar_getName(ivarList[i]);
            uint32_t hashName = (uint32_t)murMurHashBytes32((void *)ivarName, (int)strlen(ivarName));
            //NSLog(@"%s -> 0x%x", ivarName, hashName);
            if (hashName == fieldName)
            {
                ptrdiff_t ivarOffset = ivar_getOffset(ivarList[i]);
                int bitOffset = freedomBitfieldOffsetInBits(ivar_getTypeEncoding(ivarList[i]), bitfieldName);
                if (bitOffset >= 0)
                {
                    result.offset = ivarOffset + bitOffset / 8 + (bitOffset % 8 == 0 ? 0 : 1);
                    result.bit = bitOffset % 8;
                }
            }
        }
        
        free(ivarList);
    }
    
    return result;
}

FreedomBitfield freedomIvarBitOffset2(Class targetClass, uint32_t fieldName, uint32_t bitfieldName)
{
    FreedomBitfield result = {.offset = -1, .bit = -1 };
    
    unsigned int count = 0;
    Ivar *ivarList = class_copyIvarList(targetClass, &count);
    
    if (ivarList != NULL)
    {
        for (unsigned int i = 0; i < count; i++)
        {
            const char *ivarName = ivar_getName(ivarList[i]);
            uint32_t hashName = (uint32_t)murMurHashBytes32((void *)ivarName, (int)strlen(ivarName));
            //NSLog(@"%s -> 0x%x", ivarName, hashName);
            if (hashName == fieldName)
            {
                ptrdiff_t ivarOffset = ivar_getOffset(ivarList[i]);
                int bitOffset = freedomBitfieldOffsetInBits(ivar_getTypeEncoding(ivarList[i]), bitfieldName);
                if (bitOffset >= 0)
                {
                    result.offset = ivarOffset + bitOffset / 8;
                    result.bit = bitOffset % 8;
                }
            }
        }
        
        free(ivarList);
    }
    
    return result;
}

void freedomSetBitfield(void *object, FreedomBitfield bitfield, int value)
{
    if (object == nil || bitfield.offset < 0 || bitfield.bit < 0)
        return;
    
    uint8_t *bytePtr = (((uint8_t *)object) + bitfield.offset);
    
    if (value != 0)
        *bytePtr = (*bytePtr) | ((uint8_t)(1 << (bitfield.bit)));
    else
        *bytePtr = (*bytePtr) & ((uint8_t)~(1 << (bitfield.bit)));
}

int freedomGetBitfield(void *object, FreedomBitfield bitfield)
{
    if (object == nil || bitfield.offset < 0 || bitfield.bit < 0)
        return 0;
    
    uint8_t *bytePtr = (((uint8_t *)object) + bitfield.offset);
    
    return ((*bytePtr) & ((uint8_t)(1 << (bitfield.bit)))) != 0;
}

void freedomDumpBitfields(Class targetClass, void *object, uint32_t fieldName)
{
    unsigned int count = 0;
    Ivar *ivarList = class_copyIvarList(targetClass, &count);
    
    if (ivarList != NULL)
    {
        for (unsigned int i = 0; i < count; i++)
        {
            const char *ivarName = ivar_getName(ivarList[i]);
            uint32_t hashName = (uint32_t)murMurHashBytes32((void *)ivarName, (int)strlen(ivarName));
            if (hashName == fieldName)
            {
                ptrdiff_t ivarOffset = ivar_getOffset(ivarList[i]);
                freedomDumpBitfieldsByDescription(((uint8_t *)object) + ivarOffset, ivar_getTypeEncoding(ivarList[i]));
            }
        }
        
        free(ivarList);
    }
}

IMP freedomNativeImpl(Class targetClass, SEL selector)
{
    return class_getMethodImplementation(class_getSuperclass(targetClass), selector);
}

Class adjustDecoratedClass(Class targetClass)
{
    __unsafe_unretained Class decoratedClass = Nil;
    __unsafe_unretained Class currentClass = targetClass;
    while (currentClass != Nil)
    {
        __unsafe_unretained Class currentDecoratedClass = objc_getAssociatedObject(currentClass, freedomDecoratedClass);
        if (currentDecoratedClass != Nil)
        {
            decoratedClass = currentDecoratedClass;
            
            if (currentClass != targetClass)
            {
                const char *currentClassName = class_getName(targetClass);
                Class adjustedDecoratedClass = objc_allocateClassPair(targetClass, [[NSString alloc] initWithFormat:@"%s_Super%" PRIx32 "", class_getName(decoratedClass), murMurHashBytes32((void *)currentClassName, (int)strlen(currentClassName))].UTF8String, 0);
                
                unsigned int methodCount = 0;
                Method *methodList = class_copyMethodList(decoratedClass, &methodCount);
                for (unsigned int i = 0; i < methodCount; i++)
                {
                    class_addMethod(adjustedDecoratedClass, method_getName(methodList[i]), method_getImplementation(methodList[i]), method_getTypeEncoding(methodList[i]));
                }
                free(methodList);
                
                objc_registerClassPair(adjustedDecoratedClass);
                
                decoratedClass = adjustedDecoratedClass;
                objc_setAssociatedObject(targetClass, freedomDecoratedClass, adjustedDecoratedClass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            
            break;
        }
        
        currentClass = class_getSuperclass(currentClass);
    }
    
    return decoratedClass;
}

id freedomAllocImpl(id self, SEL _cmd)
{
    static id (*nativeImp)(id, SEL) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        nativeImp = (id (*)(id, SEL))class_getMethodImplementation(object_getClass([NSObject class]), @selector(alloc));
    });
    
    id result = nativeImp(self, _cmd);
    
    Class decoratedClass = adjustDecoratedClass(self);
    if (decoratedClass != Nil)
        object_setClass(result, decoratedClass);
    
    return result;
}

static SEL freedomFindMethodName(uint32_t name, Class className, Method *methodList, unsigned int methodCount, const char **methodTypeEncoding)
{
    for (unsigned int j = 0; j < methodCount; j++)
    {
        SEL methodName = method_getName(methodList[j]);
        const char *selectorName = sel_getName(methodName);
        uint32_t methodHashName = (uint32_t)murMurHashBytes32((void *)selectorName, (int)strlen(selectorName));
        //NSLog(@"0x%" PRIx32 " -> %s", methodHashName, selectorName);
        if (methodHashName == name)
        {
            if (methodTypeEncoding != NULL)
                *methodTypeEncoding = method_getTypeEncoding(methodList[j]);
            return methodName;
        }
    }
    
    Class superClass = class_getSuperclass(className);
    if (superClass != NULL)
    {
        unsigned int superClassMethodCount = 0;
        Method *superClassMethodList = class_copyMethodList(superClass, &superClassMethodCount);
        SEL result = freedomFindMethodName(name, superClass, superClassMethodList, superClassMethodCount, methodTypeEncoding);
        free(superClassMethodList);
        
        return result;
    }
    
    return NULL;
}

void freedomClassAutoDecorate(uint32_t name, __unused FreedomDecoration *classDecorations, __unused int numClassDecorations, FreedomDecoration *instanceDecorations, int numInstanceDecorations)
{
    __unsafe_unretained Class className = freedomClass(name);
    freedomClassAutoDecorateExplicit(className, name, classDecorations, numClassDecorations, instanceDecorations, numInstanceDecorations);
}

void freedomClassAutoDecorateExplicit(Class className, uint32_t name, __unused FreedomDecoration *classDecorations, __unused int numClassDecorations, FreedomDecoration *instanceDecorations, int numInstanceDecorations)
{
    if (className != nil)
    {
        if (name == 0)
        {
            const char *string = [NSStringFromClass(className) UTF8String];
            name = (uint32_t)murMurHashBytes32((void *)string, (int)strlen(string));
        }
            
        Class decoratedClass = objc_allocateClassPair(className, [[NSString alloc] initWithFormat:@"Decorated%" PRIx32 "", name].UTF8String, 0);
        
        unsigned int methodCount = 0;
        Method *methodList = class_copyMethodList(className, &methodCount);
        
        for (int i = 0; i < numInstanceDecorations; i++)
        {
            if (instanceDecorations[i].name != 0)
            {
                const char *methodTypeEncoding = NULL;
                SEL methodName = freedomFindMethodName(instanceDecorations[i].name, className, methodList, methodCount, &methodTypeEncoding);
                if (methodName != NULL)
                    class_addMethod(decoratedClass, methodName, instanceDecorations[i].imp, methodTypeEncoding);
                else
                {
#ifdef DEBUG
                    NSLog(@"[Freedom coulnd'n find method named 0x%" PRIx32 "]", instanceDecorations[i].name);
#endif
                }
            }
            else if (instanceDecorations[i].newIdentifier.string != NULL && instanceDecorations[i].newEncoding.string != NULL)
            {
                char *identifier = copyFreedomIdentifierValue(instanceDecorations[i].newIdentifier);
                char *encoding = copyFreedomIdentifierValue(instanceDecorations[i].newEncoding);
                
                SEL selector = sel_getUid(identifier);
                if (!sel_isMapped(selector))
                    selector = sel_registerName(identifier);
                
                class_addMethod(decoratedClass, selector, instanceDecorations[i].imp, encoding);
                
                free(identifier);
                free(encoding);
            }
            else
            {
#ifdef DEBUG
                NSLog(@"[Freedom invalid decoration description]");
#endif
            }
        }
        
        free(methodList);
        
        objc_registerClassPair(decoratedClass);
        
        objc_setAssociatedObject(className, freedomDecoratedClass, decoratedClass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        Class metaClass = object_getClass(className);
        class_addMethod(metaClass, @selector(alloc), (IMP)&freedomAllocImpl, "@:@");
    }
    else
    {
#ifdef DEBUG
        NSLog(@"[Freedom coulnd'n find class named 0x%" PRIx32 "]", name);
        assert(false);
#endif
    }
}

IMP freedomImpl(id target, uint32_t name, SEL *selector)
{
    if (target == nil)
        return NULL;
    
    Class targetClass = object_getClass(target);
    return freedomImplInstancesOfClass(targetClass, name, selector);
}

IMP freedomImplInstancesOfClass(Class targetClass, uint32_t name, SEL *selector) {
    if (targetClass == NULL)
        return NULL;
    
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(targetClass, &methodCount);
    SEL methodName = freedomFindMethodName(name, targetClass, methodList, methodCount, NULL);
    free(methodList);
    
    if (methodName != NULL)
    {
        if (selector != NULL)
            *selector = methodName;
        IMP result = class_getMethodImplementation(targetClass, methodName);
        if (result == NULL)
        {
#ifdef DEBUG
            NSLog(@"[Freedom coulnd'n find method named 0x%" PRIx32 "]", name);
#endif
        }
        
        return result;
    }
    
    return NULL;
}

void freedomInit()
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        freedom_getClassList = &objc_getClassList;
        freedom_class_getName = &class_getName;
    });
}

bool freedomInitialized()
{
    return freedom_initialized;
}
