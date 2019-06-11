#import "SecretChatKeyVisualization.h"

#import <objc/runtime.h>

#define UIColorRGB(rgb) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:1.0f])

static int32_t get_bits(uint8_t const *bytes, unsigned int bitOffset, unsigned int numBits)
{
    uint8_t const *data = bytes;
    numBits = (unsigned int)pow(2, numBits) - 1; //this will only work up to 32 bits, of course
    data += bitOffset / 8;
    bitOffset %= 8;
    return (*((int*)data) >> bitOffset) & numBits;
}

UIImage *SecretChatKeyVisualization(NSData *data, NSData *additionalData, CGSize size) {
    uint8_t bits[128];
    memset(bits, 0, 128);
    
    uint8_t additionalBits[256 * 8];
    memset(additionalBits, 0, 256 * 8);
    
    [data getBytes:bits length:MIN((NSUInteger)128, data.length)];
    [additionalData getBytes:additionalBits length:MIN((NSUInteger)256, additionalData.length)];
    
    static CGColorRef colors[6];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        static const int textColors[] =
        {
            0xffffff,
            0xd5e6f3,
            0x2d5775,
            0x2f99c9
        };
        
        for (int i = 0; i < 4; i++)
        {
            colors[i] = CGColorRetain(UIColorRGB(textColors[i]).CGColor);
        }
    });
    
    UIGraphicsBeginImageContextWithOptions(size, true, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, colors[0]);
    CGContextFillRect(context, CGRectMake(0.0f, 0.0f, size.width, size.height));
    
    if (additionalData == nil) {
        int bitPointer = 0;
        
        CGFloat rectSize = size.width / 8.0f;
        
        for (int iy = 0; iy < 8; iy++)
        {
            for (int ix = 0; ix < 8; ix++)
            {
                int32_t byteValue = get_bits(bits, bitPointer, 2);
                bitPointer += 2;
                int colorIndex = ABS(byteValue) % 4;
                
                CGContextSetFillColorWithColor(context, colors[colorIndex]);
                
                CGRect rect = CGRectMake(ix * rectSize, iy * rectSize, rectSize, rectSize);
                if (size.width > 200) {
                    rect.origin.x = ceil(rect.origin.x);
                    rect.origin.y = ceil(rect.origin.y);
                    rect.size.width = ceil(rect.size.width);
                    rect.size.height = ceil(rect.size.height);
                }
                CGContextFillRect(context, rect);
            }
        }
    } else {
        int bitPointer = 0;
        
        CGFloat rectSize = size.width / 12.0f;
        
        for (int iy = 0; iy < 12; iy++)
        {
            for (int ix = 0; ix < 12; ix++)
            {
                int32_t byteValue = 0;
                if (bitPointer < 128) {
                    byteValue = get_bits(bits, bitPointer, 2);
                } else {
                    byteValue = get_bits(additionalBits, bitPointer - 128, 2);
                }
                bitPointer += 2;
                int colorIndex = ABS(byteValue) % 4;
                
                CGContextSetFillColorWithColor(context, colors[colorIndex]);
                
                CGRect rect = CGRectMake(ix * rectSize, iy * rectSize, rectSize, rectSize);
                if (size.width > 200) {
                    rect.origin.x = ceil(rect.origin.x);
                    rect.origin.y = ceil(rect.origin.y);
                    rect.size.width = ceil(rect.size.width);
                    rect.size.height = ceil(rect.size.height);
                }
                CGContextFillRect(context, rect);
            }
        }
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

static int32_t positionExtractor(uint8_t *bytes, int32_t i, int32_t count) {
    int offset = i * 8;
    int64_t num = (((int64_t)bytes[offset] & 0x7F) << 56) | (((int64_t)bytes[offset+1] & 0xFF) << 48) | (((int64_t)bytes[offset+2] & 0xFF) << 40) | (((int64_t)bytes[offset+3] & 0xFF) << 32) | (((int64_t)bytes[offset+4] & 0xFF) << 24) | (((int64_t)bytes[offset+5] & 0xFF) << 16) | (((int64_t)bytes[offset+6] & 0xFF) << 8) | (((int64_t)bytes[offset+7] & 0xFF));
    return num % count;
}

NSString *stringForEmojiHashOfData(NSData *data, NSInteger count) {
    if (data.length != 32)
        return @"";
    
    NSArray *emojis = @[ @"😉", @"😍", @"😛", @"😭", @"😱", @"😡", @"😎", @"😴", @"😵", @"😈", @"😬", @"😇", @"😏", @"👮", @"👷", @"💂", @"👶", @"👨", @"👩", @"👴", @"👵", @"😻", @"😽", @"🙀", @"👺", @"🙈", @"🙉", @"🙊", @"💀", @"👽", @"💩", @"🔥", @"💥", @"💤", @"👂", @"👀", @"👃", @"👅", @"👄", @"👍", @"👎", @"👌", @"👊", @"✌️", @"✋️", @"👐", @"👆", @"👇", @"👉", @"👈", @"🙏", @"👏", @"💪", @"🚶", @"🏃", @"💃", @"👫", @"👪", @"👬", @"👭", @"💅", @"🎩", @"👑", @"👒", @"👟", @"👞", @"👠", @"👕", @"👗", @"👖", @"👙", @"👜", @"👓", @"🎀", @"💄", @"💛", @"💙", @"💜", @"💚", @"💍", @"💎", @"🐶", @"🐺", @"🐱", @"🐭", @"🐹", @"🐰", @"🐸", @"🐯", @"🐨", @"🐻", @"🐷", @"🐮", @"🐗", @"🐴", @"🐑", @"🐘", @"🐼", @"🐧", @"🐥", @"🐔", @"🐍", @"🐢", @"🐛", @"🐝", @"🐜", @"🐞", @"🐌", @"🐙", @"🐚", @"🐟", @"🐬", @"🐋", @"🐐", @"🐊", @"🐫", @"🍀", @"🌹", @"🌻", @"🍁", @"🌾", @"🍄", @"🌵", @"🌴", @"🌳", @"🌞", @"🌚", @"🌙", @"🌎", @"🌋", @"⚡️", @"☔️", @"❄️", @"⛄️", @"🌀", @"🌈", @"🌊", @"🎓", @"🎆", @"🎃", @"👻", @"🎅", @"🎄", @"🎁", @"🎈", @"🔮", @"🎥", @"📷", @"💿", @"💻", @"☎️", @"📡", @"📺", @"📻", @"🔉", @"🔔", @"⏳", @"⏰", @"⌚️", @"🔒", @"🔑", @"🔎", @"💡", @"🔦", @"🔌", @"🔋", @"🚿", @"🚽", @"🔧", @"🔨", @"🚪", @"🚬", @"💣", @"🔫", @"🔪", @"💊", @"💉", @"💰", @"💵", @"💳", @"✉️", @"📫", @"📦", @"📅", @"📁", @"✂️", @"📌", @"📎", @"✒️", @"✏️", @"📐", @"📚", @"🔬", @"🔭", @"🎨", @"🎬", @"🎤", @"🎧", @"🎵", @"🎹", @"🎻", @"🎺", @"🎸", @"👾", @"🎮", @"🃏", @"🎲", @"🎯", @"🏈", @"🏀", @"⚽️", @"⚾️", @"🎾", @"🎱", @"🏉", @"🎳", @"🏁", @"🏇", @"🏆", @"🏊", @"🏄", @"☕️", @"🍼", @"🍺", @"🍷", @"🍴", @"🍕", @"🍔", @"🍟", @"🍗", @"🍱", @"🍚", @"🍜", @"🍡", @"🍳", @"🍞", @"🍩", @"🍦", @"🎂", @"🍰", @"🍪", @"🍫", @"🍭", @"🍯", @"🍎", @"🍏", @"🍊", @"🍋", @"🍒", @"🍇", @"🍉", @"🍓", @"🍑", @"🍌", @"🍐", @"🍍", @"🍆", @"🍅", @"🌽", @"🏡", @"🏥", @"🏦", @"⛪️", @"🏰", @"⛺️", @"🏭", @"🗻", @"🗽", @"🎠", @"🎡", @"⛲️", @"🎢", @"🚢", @"🚤", @"⚓️", @"🚀", @"✈️", @"🚁", @"🚂", @"🚋", @"🚎", @"🚌", @"🚙", @"🚗", @"🚕", @"🚛", @"🚨", @"🚔", @"🚒", @"🚑", @"🚲", @"🚠", @"🚜", @"🚦", @"⚠️", @"🚧", @"⛽️", @"🎰", @"🗿", @"🎪", @"🎭", @"🇯🇵", @"🇰🇷", @"🇩🇪", @"🇨🇳", @"🇺🇸", @"🇫🇷", @"🇪🇸", @"🇮🇹", @"🇷🇺", @"🇬🇧", @"1️⃣", @"2️⃣", @"3️⃣", @"4️⃣", @"5️⃣", @"6️⃣", @"7️⃣", @"8️⃣", @"9️⃣", @"0️⃣", @"🔟", @"❗️", @"❓", @"♥️", @"♦️", @"💯", @"🔗", @"🔱", @"🔴", @"🔵", @"🔶", @"🔷" ];
    
    uint8_t bytes[32];
    [data getBytes:bytes length:32];
    
    NSString *result = @"";
    for (int32_t i = 0; i < count; i++)
    {
        int32_t position = positionExtractor(bytes, i, (int32_t)emojis.count);
        NSString *emoji = emojis[position];
        result = [result stringByAppendingString:emoji];
    }
    
    return result;
}
