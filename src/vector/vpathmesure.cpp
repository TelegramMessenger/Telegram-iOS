#include"vpathmesure.h"
#include"vbezier.h"

V_BEGIN_NAMESPACE

struct VPathMesureData
{
   VPathMesureData():ref(-1){}
   void        setPath(const VPath &path) { mPath = path; }
   VPath&       getPath() { return mPath; }
   VPath       mPath;
   RefCount    ref;
};

static const struct VPathMesureData shared_empty;

inline void VPathMesure::cleanUp(VPathMesureData *d)
{
    delete d;
}

void VPathMesure::detach()
{
    if (d->ref.isShared())
        *this = copy();
}

VPathMesure VPathMesure::copy() const
{
    VPathMesure other;

    other.d = new VPathMesureData;
    other.d->mPath = d->mPath;
    other.d->ref.setOwned();
    return other;
}

VPathMesure::~VPathMesure()
{
    if (!d->ref.deref())
        cleanUp(d);
}

VPathMesure::VPathMesure()
    : d(const_cast<VPathMesureData*>(&shared_empty))
{
}

VPathMesure::VPathMesure(const VPathMesure &other)
{
    d = other.d;
    d->ref.ref();
}

VPathMesure::VPathMesure(VPathMesure &&other): d(other.d)
{
    other.d = const_cast<VPathMesureData*>(&shared_empty);
}

VPathMesure &VPathMesure::operator=(const VPathMesure &other)
{
    other.d->ref.ref();
    if (!d->ref.deref())
        cleanUp(d);

    d = other.d;
    return *this;
}

inline VPathMesure &VPathMesure::operator=(VPathMesure &&other)
{
    if (!d->ref.deref())
        cleanUp(d);
    d = other.d;
    other.d = const_cast<VPathMesureData*>(&shared_empty);
    return *this;
}

void VPathMesure::setStart(float pos)
{
   detach();
   VPath &path = d->getPath();
   const std::vector<VPath::Element> &elm = path.elements();
   const std::vector<VPointF> &pts  = path.points();
   std::vector<float> len;

   std::vector<VPath::Element> elm_copy;

   int i = 0, idx = 0;
   float totlen = 0.0;
   float startlen = 0.0;
   bool cut = false;

   for (auto e : elm) {
        elm_copy.push_back(e);
        switch(e) {
           case VPath::Element::MoveTo:
              i++;
              break;
           case VPath::Element::LineTo:
                {
                   VPointF p0 = pts[i - 1];
                   VPointF p = pts[i++];

                   VBezier b = VBezier::fromPoints(p0, p0, p, p);
                   totlen += b.length();
                   len.push_back(b.length());
                   break;
                }
           case VPath::Element::CubicTo:
                {
                   VPointF p0 = pts[i - 1];
                   VPointF p = pts[i++];
                   VPointF p1 = pts[i++];
                   VPointF p2 = pts[i++];

                   VBezier b = VBezier::fromPoints(p0, p, p1, p2);
                   totlen += b.length();
                   len.push_back(b.length());

                   break;
                }
           case VPath::Element::Close:
              break;
        }
   }

   startlen = totlen * (pos / 100);
   i = 0;
   path.reset();

   for (auto e : elm_copy) {
        switch(e) {
           case VPath::Element::MoveTo:
                {
                   VPointF p = pts[i++];
                   path.moveTo(p.x(), p.y());
                   break;
                }
           case VPath::Element::LineTo:
                {
                   VPointF p0 = pts[i - 1];
                   VPointF p = pts[i++];

                   if (!cut)
                     {
                        if (len.at(idx) < startlen)
                          {
                             startlen -= len.at(idx);
                          }
                        else if (len.at(idx) == startlen)
                          {
                             path.moveTo(p.x(), p.y());
                             cut = true;
                          }
                        else
                          {
                             VBezier b, bleft;
                             float ratio = (startlen/len.at(idx));
                             b = VBezier::fromPoints(p0, p0, p, p);
                             b.parameterSplitLeft(ratio, &bleft);

                             path.moveTo(b.pt1().x(), b.pt1().y());
                             path.lineTo(b.pt4().x(), b.pt4().y());
                             cut = true;
                          }
                        idx++;
                     }
                   else
                     {
                        path.lineTo(p.x(), p.y());
                     }
                   break;
                }
           case VPath::Element::CubicTo:
                {
                   VPointF p0 = pts[i - 1];
                   VPointF p = pts[i++];
                   VPointF p1 = pts[i++];
                   VPointF p2 = pts[i++];

                   if (!cut)
                     {
                        if (len.at(idx) < startlen)
                          {
                             startlen -= len.at(idx);
                          }
                        else if (len.at(idx) == startlen)
                          {
                             path.moveTo(p2.x(), p2.y());
                             cut = true;
                          }
                        else
                          {
                             VBezier b, bleft;
                             float ratio = (startlen/len.at(idx));
                             b = VBezier::fromPoints(p0, p, p1, p2);
                             b.parameterSplitLeft(ratio, &bleft);

                             path.moveTo(b.pt1().x(), b.pt1().y());
                             path.cubicTo(b.pt2().x(), b.pt2().y(),
                                             b.pt3().x(), b.pt3().y(),
                                             b.pt4().x(), b.pt4().y());
                             cut = true;
                          }
                        idx++;
                     }
                   else
                     {
                        path.cubicTo(p.x(), p.y(), p1.x(), p1.y(), p2.x(), p2.y());
                     }
                   break;
                }
           case VPath::Element::Close:
              break;
        }
   }
}

void VPathMesure::setEnd(float pos)
{
   detach();
   VPath &path = d->getPath();
   const std::vector<VPath::Element> &elm = path.elements();
   const std::vector<VPointF> &pts  = path.points();
   std::vector<float> len;

   std::vector<VPath::Element> elm_copy;

   int i = 0, idx = 0;
   float totlen = 0.0;
   float endlen = 0.0;
   bool cut = false;

   for (auto e : elm) {
        elm_copy.push_back(e);
        switch(e) {
           case VPath::Element::MoveTo:
              i++;
              break;
           case VPath::Element::LineTo:
                {
                   VPointF p0 = pts[i - 1];
                   VPointF p = pts[i++];

                   VBezier b = VBezier::fromPoints(p0, p0, p, p);
                   totlen += b.length();
                   len.push_back(b.length());
                   break;
                }
           case VPath::Element::CubicTo:
                {
                   VPointF p0 = pts[i - 1];
                   VPointF p = pts[i++];
                   VPointF p1 = pts[i++];
                   VPointF p2 = pts[i++];

                   VBezier b = VBezier::fromPoints(p0, p, p1, p2);
                   totlen += b.length();
                   len.push_back(b.length());

                   break;
                }
           case VPath::Element::Close:
              break;
        }
   }

   endlen = totlen * (pos / 100);
   i = 0;
   path.reset();

   for (auto e : elm_copy) {
        switch(e) {
           case VPath::Element::MoveTo:
                {
                   VPointF p = pts[i++];
                   path.moveTo(p.x(), p.y());
                   break;
                }
           case VPath::Element::LineTo:
                {
                   VPointF p0 = pts[i - 1];
                   VPointF p = pts[i++];

                   if (!cut)
                     {
                        if (len.at(idx) < endlen)
                          {
                             path.lineTo(p.x(), p.y());
                             endlen -= len.at(idx);
                          }
                        else if (len.at(idx) == endlen)
                          {
                             path.lineTo(p.x(), p.y());
                             cut = true;
                          }
                        else
                          {
                             VBezier b, bleft;
                             float ratio = (endlen/len.at(idx));
                             b = VBezier::fromPoints(p0, p0, p, p);
                             b.parameterSplitLeft(ratio, &bleft);

                             path.lineTo(bleft.pt4().x(), bleft.pt4().y());
                             cut = true;
                          }
                        idx++;
                     }
                   break;
                }
           case VPath::Element::CubicTo:
                {
                   VPointF p0 = pts[i - 1];
                   VPointF p = pts[i++];
                   VPointF p1 = pts[i++];
                   VPointF p2 = pts[i++];

                   if (!cut)
                     {
                        if (len.at(idx) < endlen)
                          {
                             path.cubicTo(p.x(), p.y(), p1.x(), p1.y(), p2.x(), p2.y());
                             endlen -= len.at(idx);
                          }
                        else if (len.at(idx) == endlen)
                          {
                             path.cubicTo(p.x(), p.y(), p1.x(), p1.y(), p2.x(), p2.y());
                             cut = true;
                          }
                        else
                          {
                             VBezier b, bleft;
                             float ratio = (endlen/len.at(idx));
                             b = VBezier::fromPoints(p0, p, p1, p2);
                             b.parameterSplitLeft(ratio, &bleft);

                             path.cubicTo(bleft.pt2().x(), bleft.pt2().y(),
                                             bleft.pt3().x(), bleft.pt3().y(),
                                             bleft.pt4().x(), bleft.pt4().y());
                             cut = true;
                          }
                        idx++;
                     }
                   break;
                }
           case VPath::Element::Close:
              break;
        }
   }
}

void VPathMesure::setPath(const VPath &path)
{
   detach();
   d->setPath(path);
}

VPath VPathMesure::getPath()
{
   return d->getPath();
}

V_END_NAMESPACE
