#include"vpathmesure.h"
#include"vbezier.h"
#include"vdasher.h"

V_BEGIN_NAMESPACE

void VPathMesure::setOffset(float sp, float ep)
{
   startOffset = sp;
   endOffset = ep;
}

VPath VPathMesure::trim(const VPath &path)
{
   if (vCompare(startOffset, 0.0f) && (vCompare(endOffset, 1.0f))) return path;

   float len = path.length();
   float len1 = len;
   float sg = len * startOffset;
   float eg = len * (1.0f - endOffset);
   len = len - (sg + eg);

   float array[5] = { 0.0f, sg, len, 1000, 0.0f };
   VDasher dasher(array, 5);

   return dasher.dashed(path);
}

V_END_NAMESPACE
