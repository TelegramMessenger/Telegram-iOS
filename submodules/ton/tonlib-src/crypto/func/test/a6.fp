f(int a, int b, int c, int d, int e, int f) : (int, int) {
  var D  = a * d - b * c;
  var Dx : int = e * d - b * f;
  var Dy : int = a * f - e * c;
  return (Dx / D, Dy / D);
}

calc_phi() : int = {
  var n : int = 1;
  repeat (10) {
    n *= 10;
  }
  var p = var q = 1;
  do {
    (p, q) = (q, p + q);
  } until q > n;
  return muldivr(p, n, q);
}

calc_sqrt2() : int = {
  var n = 1;
  repeat (70) { n *= 10; }
  var p = var q = 1;
  do {
    var t = p + q;
    (p, q) = (q, t + q);
  } until q > n;
  return muldivr(p, n, q);
}

calc_phi() : int = {
  var n = 1;
  repeat (70) { n *= 10; }
  var p = var q = 1;
  do {
    (p, q) = (q, p + q);
  } until q > n;
  return muldivr(p, n, q);
}

operator _/%_ infix 20;

(x : int) /% (y : int) : (int, int) = {
  return (x / y, x % y);
}

{-
_/%_ (int x, int y) : (int, int) = {
  return (x / y, x % y);
}
-}

rot < A : type, B : type, C : type >
  (x : A, y : B, z : C) : (B, C, A) {
  return (y, z, x);
}

ataninv(base : int, q : int) : int { ;; computes base*atan(1/q)
  base /~= q;
  q *= - q;
  var sum : int = 0;
  var n = 1;
  do {
    sum += base /~ n;
    base /~= q;
    n += 2;
  } while base;
  return sum;
}

calc_pi() : int {
  var base = 64;
  repeat (70) { base *= 10; }
  return (ataninv(base << 2, 5) - ataninv(base, 239)) >>~ 4;
}
