// Canvas 2D (V5d plan, Task 3): WPT's interfaces/html.idl canvas section and geometry.idl's 2D matrix, for profile 1
// (`canvas.*`). The generator takes no overloads and no sequence arguments and returns no unions, so an overloaded
// operation is one with `any` arguments resolved natively by HTML's rules, and README.md lists every change.

enum CanvasFillRule { "nonzero", "evenodd" };
enum ImageSmoothingQuality { "low", "medium", "high" };
enum CanvasLineCap { "butt", "round", "square" };
enum CanvasLineJoin { "round", "bevel", "miter" };
enum CanvasTextAlign { "start", "end", "left", "right", "center" };
enum CanvasTextBaseline { "top", "hanging", "middle", "alphabetic", "ideographic", "bottom" };
enum CanvasDirection { "ltr", "rtl", "inherit" };
enum CanvasFontKerning { "auto", "normal", "none" };
enum CanvasFontStretch { "ultra-condensed", "extra-condensed", "condensed", "semi-condensed", "normal", "semi-expanded", "expanded", "extra-expanded", "ultra-expanded" };
enum CanvasFontVariantCaps { "normal", "small-caps", "all-small-caps", "petite-caps", "all-petite-caps", "unicase", "titling-caps" };
enum CanvasTextRendering { "auto", "optimizeSpeed", "optimizeLegibility", "geometricPrecision" };

[Exposed=Window]
interface HTMLCanvasElement : HTMLElement {
  [CEReactions] attribute unsigned long width;
  [CEReactions] attribute unsigned long height;

  any getContext(DOMString contextId, optional any options);

  USVString toDataURL(optional DOMString type = "image/png", optional any quality);
  undefined toBlob(any _callback, optional DOMString type = "image/png", optional any quality);
  undefined transferControlToOffscreen();
};

[Exposed=Window]
interface CanvasRenderingContext2D {
  // back-reference to the canvas
  readonly attribute HTMLCanvasElement canvas;
};
CanvasRenderingContext2D includes CanvasSettings;
CanvasRenderingContext2D includes CanvasState;
CanvasRenderingContext2D includes CanvasTransform;
CanvasRenderingContext2D includes CanvasCompositing;
CanvasRenderingContext2D includes CanvasImageSmoothing;
CanvasRenderingContext2D includes CanvasFillStrokeStyles;
CanvasRenderingContext2D includes CanvasShadowStyles;
CanvasRenderingContext2D includes CanvasFilters;
CanvasRenderingContext2D includes CanvasRect;
CanvasRenderingContext2D includes CanvasDrawPath;
CanvasRenderingContext2D includes CanvasUserInterface;
CanvasRenderingContext2D includes CanvasText;
CanvasRenderingContext2D includes CanvasDrawImage;
CanvasRenderingContext2D includes CanvasImageData;
CanvasRenderingContext2D includes CanvasPathDrawingStyles;
CanvasRenderingContext2D includes CanvasTextDrawingStyles;
CanvasRenderingContext2D includes CanvasPath;

interface mixin CanvasSettings {
  // settings
  object getContextAttributes();
};

interface mixin CanvasState {
  // state
  undefined save(); // push state on state stack
  undefined restore(); // pop state stack and restore state
  undefined reset(); // reset the rendering context to its default state
  boolean isContextLost(); // return whether context is lost
};

interface mixin CanvasTransform {
  // transformations (default transform is the identity matrix)
  undefined scale(unrestricted double x, unrestricted double y);
  undefined rotate(unrestricted double angle);
  undefined translate(unrestricted double x, unrestricted double y);
  undefined transform(unrestricted double a, unrestricted double b, unrestricted double c, unrestricted double d, unrestricted double e, unrestricted double f);

  [NewObject] DOMMatrix getTransform();
  undefined setTransform(any... transform);
  undefined resetTransform();

};

interface mixin CanvasCompositing {
  // compositing
  attribute unrestricted double globalAlpha; // (default 1.0)
  attribute DOMString globalCompositeOperation; // (default "source-over")
};

interface mixin CanvasImageSmoothing {
  // image smoothing
  attribute boolean imageSmoothingEnabled; // (default true)
  attribute ImageSmoothingQuality imageSmoothingQuality; // (default low)

};

interface mixin CanvasFillStrokeStyles {
  // colors and styles (see also the CanvasPathDrawingStyles and CanvasTextDrawingStyles interfaces)
  attribute any strokeStyle; // (default black)
  attribute any fillStyle; // (default black)
  CanvasGradient createLinearGradient(double x0, double y0, double x1, double y1);
  CanvasGradient createRadialGradient(double x0, double y0, double r0, double x1, double y1, double r1);
  CanvasGradient createConicGradient(double startAngle, double x, double y);
  any createPattern(any image, [LegacyNullToEmptyString] DOMString repetition);

};

interface mixin CanvasShadowStyles {
  // shadows
  attribute unrestricted double shadowOffsetX; // (default 0)
  attribute unrestricted double shadowOffsetY; // (default 0)
  attribute unrestricted double shadowBlur; // (default 0)
  attribute DOMString shadowColor; // (default transparent black)
};

interface mixin CanvasFilters {
  // filters
  attribute DOMString filter; // (default "none")
};

interface mixin CanvasRect {
  // rects
  undefined clearRect(unrestricted double x, unrestricted double y, unrestricted double w, unrestricted double h);
  undefined fillRect(unrestricted double x, unrestricted double y, unrestricted double w, unrestricted double h);
  undefined strokeRect(unrestricted double x, unrestricted double y, unrestricted double w, unrestricted double h);
};

interface mixin CanvasDrawPath {
  // path API (see also CanvasPath)
  undefined beginPath();
  undefined fill(optional any pathOrFillRule, optional any fillRule);
  undefined stroke(optional any path);
  undefined clip(optional any pathOrFillRule, optional any fillRule);
  boolean isPointInPath(any pathOrX, any xOrY, any... rest);
  boolean isPointInStroke(any pathOrX, any xOrY, optional any y);
};

interface mixin CanvasUserInterface {
  undefined drawFocusIfNeeded(any pathOrElement, optional any element);
};

interface mixin CanvasText {
  // text (see also the CanvasPathDrawingStyles and CanvasTextDrawingStyles interfaces)
  undefined fillText(DOMString text, unrestricted double x, unrestricted double y, optional unrestricted double maxWidth);
  undefined strokeText(DOMString text, unrestricted double x, unrestricted double y, optional unrestricted double maxWidth);
  TextMetrics measureText(DOMString text);
};

interface mixin CanvasDrawImage {
  // drawing images
  undefined drawImage(any image, any dxOrSx, any dyOrSy, any... rest);
};

interface mixin CanvasImageData {
  // pixel manipulation
  ImageData createImageData(any swOrImageData, any... rest);
  ImageData getImageData([EnforceRange] long sx, [EnforceRange] long sy, [EnforceRange] long sw, [EnforceRange] long sh, optional any settings);
  undefined putImageData(any imageData, any dx, any dy, any... dirty);
};

interface mixin CanvasPathDrawingStyles {
  // line caps/joins
  attribute unrestricted double lineWidth; // (default 1)
  attribute CanvasLineCap lineCap; // (default "butt")
  attribute CanvasLineJoin lineJoin; // (default "miter")
  attribute unrestricted double miterLimit; // (default 10)

  // dashed lines
  undefined setLineDash(any segments); // default empty
  sequence<unrestricted double> getLineDash();
  attribute unrestricted double lineDashOffset;
};

interface mixin CanvasTextDrawingStyles {
  // text
  attribute DOMString lang; // (default: "inherit")
  attribute DOMString font; // (default 10px sans-serif)
  attribute CanvasTextAlign textAlign; // (default: "start")
  attribute CanvasTextBaseline textBaseline; // (default: "alphabetic")
  attribute CanvasDirection direction; // (default: "inherit")
  attribute DOMString letterSpacing; // (default: "0px")
  attribute CanvasFontKerning fontKerning; // (default: "auto")
  attribute CanvasFontStretch fontStretch; // (default: "normal")
  attribute CanvasFontVariantCaps fontVariantCaps; // (default: "normal")
  attribute CanvasTextRendering textRendering; // (default: "auto")
  attribute DOMString wordSpacing; // (default: "0px")
};

interface mixin CanvasPath {
  // shared path API methods
  undefined closePath();
  undefined moveTo(unrestricted double x, unrestricted double y);
  undefined lineTo(unrestricted double x, unrestricted double y);
  undefined quadraticCurveTo(unrestricted double cpx, unrestricted double cpy, unrestricted double x, unrestricted double y);
  undefined bezierCurveTo(unrestricted double cp1x, unrestricted double cp1y, unrestricted double cp2x, unrestricted double cp2y, unrestricted double x, unrestricted double y);
  undefined arcTo(unrestricted double x1, unrestricted double y1, unrestricted double x2, unrestricted double y2, unrestricted double radius);
  undefined rect(unrestricted double x, unrestricted double y, unrestricted double w, unrestricted double h);
  undefined roundRect(unrestricted double x, unrestricted double y, unrestricted double w, unrestricted double h, optional any radii);
  undefined arc(unrestricted double x, unrestricted double y, unrestricted double radius, unrestricted double startAngle, unrestricted double endAngle, optional boolean counterclockwise = false);
  undefined ellipse(unrestricted double x, unrestricted double y, unrestricted double radiusX, unrestricted double radiusY, unrestricted double rotation, unrestricted double startAngle, unrestricted double endAngle, optional boolean counterclockwise = false);
};

[Exposed=(Window,Worker)]
interface CanvasGradient {
  // opaque object
  undefined addColorStop(double offset, DOMString color);
};

[Exposed=(Window,Worker)]
interface CanvasPattern {
  // opaque object
  undefined setTransform(optional DOMMatrix2DInit transform = {});
};

[Exposed=(Window,Worker)]
interface TextMetrics {
  // x-direction
  readonly attribute double width; // advance width
  readonly attribute double actualBoundingBoxLeft;
  readonly attribute double actualBoundingBoxRight;

  // y-direction
  readonly attribute double fontBoundingBoxAscent;
  readonly attribute double fontBoundingBoxDescent;
  readonly attribute double actualBoundingBoxAscent;
  readonly attribute double actualBoundingBoxDescent;
  readonly attribute double emHeightAscent;
  readonly attribute double emHeightDescent;
  readonly attribute double hangingBaseline;
  readonly attribute double alphabeticBaseline;
  readonly attribute double ideographicBaseline;
};

[Exposed=(Window,Worker)]
interface Path2D {
  constructor(optional (Path2D or DOMString) path);

  undefined addPath(Path2D path, optional DOMMatrix2DInit transform = {});
};
Path2D includes CanvasPath;

[Exposed=(Window,Worker)]
interface ImageData {
  constructor(any swOrData, any shOrSw, optional any sh, optional any settings);

  readonly attribute unsigned long width;
  readonly attribute unsigned long height;
  readonly attribute any data;
  readonly attribute DOMString colorSpace;
};

// geometry-1: the 2D members of DOMMatrix, without DOMMatrixReadOnly (README.md).
dictionary DOMMatrix2DInit {
  unrestricted double a;
  unrestricted double b;
  unrestricted double c;
  unrestricted double d;
  unrestricted double e;
  unrestricted double f;
  unrestricted double m11;
  unrestricted double m12;
  unrestricted double m21;
  unrestricted double m22;
  unrestricted double m41;
  unrestricted double m42;
};

[Exposed=(Window,Worker)]
interface DOMMatrix {
  constructor(optional any init);

  attribute unrestricted double a;
  attribute unrestricted double b;
  attribute unrestricted double c;
  attribute unrestricted double d;
  attribute unrestricted double e;
  attribute unrestricted double f;

  attribute unrestricted double m11;
  attribute unrestricted double m12;
  attribute unrestricted double m13;
  attribute unrestricted double m14;
  attribute unrestricted double m21;
  attribute unrestricted double m22;
  attribute unrestricted double m23;
  attribute unrestricted double m24;
  attribute unrestricted double m31;
  attribute unrestricted double m32;
  attribute unrestricted double m33;
  attribute unrestricted double m34;
  attribute unrestricted double m41;
  attribute unrestricted double m42;
  attribute unrestricted double m43;
  attribute unrestricted double m44;

  readonly attribute boolean is2D;
  readonly attribute boolean isIdentity;
};
