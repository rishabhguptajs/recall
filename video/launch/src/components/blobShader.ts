// The Recall blob as a 2D signed-distance material.
// Shape, colour field, shade, rim and speculars are ported from scripts/make-icon.swift.
// uIcon = 1 reproduces the icon's still drawing; uIcon = 0 lets it move like a liquid.

export const MAX_BALLS = 16;
export const MAX_ARMS = 4;

export const VERT = `#version 300 es
in vec2 aPos;
void main() { gl_Position = vec4(aPos, 0.0, 1.0); }
`;

export const FRAG = `#version 300 es
precision highp float;
out vec4 outColor;

uniform vec2 uRes;        // logical size (CSS px)
uniform float uDpr;
uniform vec2 uCenter;     // logical px, y down
uniform float uR;         // icon radius (0.318 of tile)
uniform float uTime;      // seconds
uniform float uWobble;    // 0 still, 1 liquid
uniform float uIcon;      // 0 liquid shading, 1 icon shading
uniform float uSwirl;     // rotation of the colour lights (radians)
uniform float uGlow;      // 0..1 outer glow
uniform float uAlpha;
uniform float uK;         // smooth-min radius in px (viscosity)
uniform vec4 uBalls[${MAX_BALLS}]; // x, y (px, y down), radius, unused
uniform int uBallCount;
uniform vec4 uArms[${MAX_ARMS}]; // arms out of the body: tip x, y (px, y down), base radius, tip radius
uniform int uArmCount;
uniform float uDim;       // 0..1 darken (for distant / out-of-focus states)
uniform float uKick;      // ripple after an impact, decays to 0
uniform float uKickAng;   // impact direction (radians, y up)
uniform float uShade;     // strength of the lower-edge shade (lower on light backgrounds)
uniform vec4 uClip;       // walls the liquid cannot pass: x0, y0, x1, y1 (px, y down); x1 <= x0 = off

vec3 hex(float h) {
  return vec3(floor(h / 65536.0), mod(floor(h / 256.0), 256.0), mod(h, 256.0)) / 255.0;
}

float smin(float a, float b, float k) {
  float h = max(k - abs(a - b), 0.0) / k;
  return min(a, b) - h * h * k * 0.25;
}

// Tile size S follows from R = 0.318 S. Tile coords: u right, v up, blob centre at (0.5, 0.485).
float S() { return uR / 0.318; }
vec2 toTile(vec2 p) { // p in px, y down
  vec2 q = vec2(p.x - uCenter.x, uCenter.y - p.y) / S();
  return q + vec2(0.5, 0.485);
}

float bodyR(float th) {
  float t = uTime;
  float w = uWobble;
  // the icon's three harmonics, with drifting phases and a little extra motion while liquid
  float r = 1.0
    + 0.075 * (1.0 + 0.35 * w) * sin(3.0 * th + 0.5 + w * 0.55 * sin(t * 0.61))
    + 0.045 * (1.0 + 0.5 * w) * sin(2.0 * th + 2.1 + w * 0.8 * sin(t * 0.43 + 1.0))
    + 0.03 * cos(5.0 * th + 0.9 + w * 1.1 * t * 0.37)
    + w * (0.018 * sin(4.0 * th - t * 0.9) + 0.012 * sin(7.0 * th + t * 1.3));
  float a = th - uKickAng;
  r += uKick * (0.06 * cos(2.0 * a) + 0.035 * cos(3.0 * a - t * 7.0));
  return uR * r;
}

float sdSegment(vec2 p, vec2 a, vec2 b, float ra, float rb) {
  vec2 pa = p - a, ba = b - a;
  float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
  return length(pa - ba * h) - mix(ra, rb, h);
}

float field(vec2 p) { // p: px, y down. Negative inside.
  vec2 q = p - uCenter;
  q.y = -q.y;
  float th = atan(q.y, q.x);
  float d = length(q) - bodyR(th);
  for (int i = 0; i < ${MAX_BALLS}; i++) {
    if (i >= uBallCount) break;
    vec4 b = uBalls[i];
    if (b.z <= 0.01) continue;
    d = smin(d, length(p - b.xy) - b.z, uK);
  }
  for (int i = 0; i < ${MAX_ARMS}; i++) {
    if (i >= uArmCount) break;
    vec4 a = uArms[i];
    if (a.z <= 0.01) continue;
    d = smin(d, sdSegment(p, uCenter, a.xy, a.z, a.w), uK * 1.3);
  }
  if (uClip.z > uClip.x) {
    // distance to the inside of the wall box (negative inside); smooth max keeps the contact soft-edged
    vec2 c = 0.5 * (uClip.xy + uClip.zw), hb = 0.5 * (uClip.zw - uClip.xy);
    vec2 q2 = abs(p - c) - hb;
    float box = length(max(q2, 0.0)) + min(max(q2.x, q2.y), 0.0);
    float k = 10.0;
    float hh = max(k - abs(d - box), 0.0) / k;
    d = max(d, box) + hh * hh * k * 0.25;
  }
  return d;
}

float height(float d, float band) {
  float s = clamp(-d / band, 0.0, 1.0);
  return sqrt(max(1.0 - (1.0 - s) * (1.0 - s), 0.0));
}

vec3 lights(vec2 uv) {
  // rotate light positions around the blob centre
  vec2 c = vec2(0.5, 0.485);
  float s = sin(uSwirl), co = cos(uSwirl);
  vec3 col = hex(7031807.0); // #6B4BFF
  float sig = 0.115;
  vec3 L[5]; vec3 C[5];
  L[0] = vec3(0.316, 0.655, 0.316); C[0] = hex(16735185.0); // FF5BD1 pink
  L[1] = vec3(0.716, 0.716, 0.279); C[1] = hex(16753229.0); // FFA24D orange
  L[2] = vec3(0.728, 0.279, 0.316); C[2] = hex(3135999.0);  // 2FD9FF cyan
  L[3] = vec3(0.291, 0.243, 0.267); C[3] = hex(8146431.0);  // 7C4DFF violet
  L[4] = vec3(0.510, 0.510, 0.182); C[4] = hex(16743080.0); // FF7AA8 core
  for (int i = 0; i < 5; i++) {
    vec2 lp = L[i].xy - c;
    float fi = float(i);
    lp += (1.0 - uIcon) * 0.035 * vec2(sin(uTime * 0.5 + fi * 1.7), cos(uTime * 0.41 + fi * 2.3));
    lp = vec2(co * lp.x - s * lp.y, s * lp.x + co * lp.y) + c;
    float dd = length(uv - lp);
    float w = 1.0 - smoothstep(L[i].z - 1.15 * sig, L[i].z + 1.15 * sig, dd);
    col = mix(col, C[i], w);
  }
  return col;
}

void main() {
  vec2 p = vec2(gl_FragCoord.x, uRes.y * uDpr - gl_FragCoord.y) / uDpr; // logical px, y down
  float d = field(p);
  float band = 0.42 * uR;
  // Normal from the gradient of the dome height, sampled wide enough that thin necks round off
  // instead of creasing along their medial axis.
  float e = max(2.0, 0.035 * uR);
  float hx = height(field(p + vec2(e, 0.0)), band) - height(field(p - vec2(e, 0.0)), band);
  float hy = height(field(p + vec2(0.0, e)), band) - height(field(p - vec2(0.0, e)), band);
  vec2 slope = vec2(hx, -hy) / (2.0 * e) * band; // y up
  vec2 g1 = vec2(field(p + vec2(1.0, 0.0)) - field(p - vec2(1.0, 0.0)), field(p - vec2(0.0, 1.0)) - field(p + vec2(0.0, 1.0)));
  vec2 gUp = g1 / max(length(g1), 1e-4); // outward, y up

  float Sz = S();
  vec2 uv = toTile(p);

  // dome profile across an edge band
  float h = height(d, band);
  vec3 n = normalize(vec3(-slope * 0.9, 1.0));

  // arms and drops carry the colour of the nearest part of the body
  vec2 dv = uv - vec2(0.5, 0.485);
  vec2 uvc = vec2(0.5, 0.485) + dv * min(1.0, 0.34 / max(length(dv), 1e-4));
  // refraction: the colour field bends at the edges
  vec2 ruv = uvc - n.xy * 0.075 * (1.0 - uIcon * 0.6);
  vec3 col = lights(ruv);

  // depth: darker toward the lower edge (icon radial shade)
  float shadeT = length(uvc - vec2(0.449, 0.607)) / 0.4;
  col = mix(col, hex(1181742.0), 0.55 * uShade * smoothstep(0.55, 1.0, shadeT)); // #12082E

  // rim light along the top edge
  float rimW = 0.011 * Sz + 0.006 * Sz;
  float rim = exp(-(d * d) / (2.0 * rimW * rimW)) * 0.55;
  float rimFade = clamp((uv.y - 0.449) / (0.825 - 0.449), 0.0, 1.0);
  float rimLiquid = pow(clamp(dot(gUp, normalize(vec2(-0.35, 1.0))), 0.0, 1.0), 2.0);
  rim *= mix(rimLiquid, rimFade, uIcon);
  col = mix(col, vec3(1.0), rim * step(d, 1.5));

  // specular: painted ellipse (icon) blended with a moving Blinn highlight (liquid)
  vec2 sp = uv - vec2(0.358, 0.674);
  float a = 0.55;
  vec2 spr = vec2(cos(a) * sp.x + sin(a) * sp.y, -sin(a) * sp.x + cos(a) * sp.y) / vec2(0.115, 0.051);
  float ell = 0.9 * (1.0 - smoothstep(0.55, 1.45, length(spr)));
  float dot0 = 0.95 * (1.0 - smoothstep(0.0206 - 0.006, 0.0206 + 0.006, length(uv - vec2(0.265, 0.708))));
  vec3 Ld = normalize(vec3(-0.55, 0.62, 0.56));
  vec3 H = normalize(Ld + vec3(0.0, 0.0, 1.0));
  float bl = pow(max(dot(n, H), 0.0), 60.0) * 0.85 + pow(max(dot(n, H), 0.0), 900.0) * 0.9;
  float spec = mix(bl, max(ell, dot0), uIcon);
  col = mix(col, vec3(1.0), clamp(spec, 0.0, 1.0));

  col *= 1.0 - uDim * 0.55;

  float cov = clamp(0.5 - d * uDpr, 0.0, 1.0);

  // outer glow: the blob's colour, blurred, slightly below
  vec2 gp = p - vec2(0.0, 0.022 * Sz);
  float gd = field(gp);
  float gs = 0.085 * Sz;
  vec2 gdv = toTile(gp) - vec2(0.5, 0.485);
  vec3 gcol = lights(vec2(0.5, 0.485) + gdv * min(1.0, 0.34 / max(length(gdv), 1e-4)));
  // a blurred mask is ~erfc of the distance: 0.5 at the edge, soft both ways
  float x = gd / (gs * 1.4142);
  float erfcx = 1.0 - tanh(1.1283792 * x + 0.1009 * x * x * x);
  float glowA = uGlow * 0.85 * 0.5 * erfcx * (1.0 - uDim * 0.6);

  // composite blob over glow, premultiplied
  vec4 glow = vec4(gcol * glowA, glowA);
  vec4 body = vec4(col * cov, cov);
  vec4 o = body + glow * (1.0 - body.a);
  outColor = o * uAlpha;
}
`;
