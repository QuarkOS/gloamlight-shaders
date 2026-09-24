#ifndef ATMOSPHERE_GLSL
#define ATMOSPHERE_GLSL

// Single-scattering Rayleigh + Mie + ozone atmosphere, marched per pixel.
// Distances are in meters; the player sits on a planet of radius EARTH_R.

const float EARTH_R = 6360e3;
const float ATMOS_R = 6460e3;
const float H_RAYLEIGH = 8.0e3;
const float H_MIE = 1.2e3;
const vec3 BETA_RAYLEIGH = vec3(5.802e-6, 13.558e-6, 33.1e-6);
const float BETA_MIE = 8.0e-6;
const float MIE_EXTINCTION = 1.11;
const vec3 BETA_OZONE = vec3(0.650e-6, 1.881e-6, 0.085e-6);
const float MIE_G = 0.78;

const float SKY_RADIANCE = 22.0;   // light intensity fed to the scattering integral
const float SUN_ILLUMINANCE = 3.4; // direct sunlight on surfaces
const float MOON_ILLUMINANCE = 0.05;
const vec3 MOON_TINT = vec3(0.75, 0.88, 1.2);

vec2 raySphere(vec3 ro, vec3 rd, float radius) {
    float b = dot(ro, rd);
    float c = dot(ro, ro) - radius * radius;
    float d = b * b - c;
    if (d < 0.0) return vec2(-1.0);
    d = sqrt(d);
    return vec2(-b - d, -b + d);
}

vec3 atmosDensity(float h) {
    return vec3(exp(-h / H_RAYLEIGH), exp(-h / H_MIE), max(0.0, 1.0 - abs(h - 25e3) / 15e3));
}

vec3 atmosExtinction(vec3 opticalDepth) {
    float wet = rainStrength;
    return BETA_RAYLEIGH * opticalDepth.x
         + BETA_MIE * MIE_EXTINCTION * (1.0 + wet * 4.0) * opticalDepth.y
         + BETA_OZONE * opticalDepth.z;
}

float viewerAltitude() {
    return 150.0 + max(cameraPosition.y - 63.0, 0.0) * 2.0;
}

vec3 atmosOrigin() {
    return vec3(0.0, EARTH_R + viewerAltitude(), 0.0);
}

vec3 lightOpticalDepth(vec3 p, vec3 l, int steps) {
    if (raySphere(p, l, EARTH_R).x > 0.0) return vec3(1e9);
    float tMax = raySphere(p, l, ATMOS_R).y;
    float ds = tMax / float(steps);
    vec3 od = vec3(0.0);
    for (int i = 0; i < steps; i++) {
        vec3 pos = p + l * ((float(i) + 0.5) * ds);
        od += atmosDensity(length(pos) - EARTH_R);
    }
    return od * ds;
}

vec3 atmosTransmittance(vec3 dir) {
    return exp(-atmosExtinction(lightOpticalDepth(atmosOrigin(), dir, 8)));
}

float rayleighPhase(float mu) { return 3.0 / (16.0 * PI) * (1.0 + mu * mu); }

float miePhase(float mu) {
    // Cornette-Shanks
    float g = MIE_G;
    float g2 = g * g;
    return 3.0 / (8.0 * PI) * ((1.0 - g2) * (1.0 + mu * mu)) / ((2.0 + g2) * pow(1.0 + g2 - 2.0 * g * mu, 1.5));
}

// Sky radiance along rd lit by both sun and moon. viewT receives the view-ray transmittance.
vec3 atmosphere(vec3 rd, vec3 sunDir, vec3 moonDir, int steps, out vec3 viewT) {
    vec3 ro = atmosOrigin();
    float tEnd = raySphere(ro, rd, ATMOS_R).y;
    float tGround = raySphere(ro, rd, EARTH_R).x;
    if (tGround > 0.0) tEnd = tGround;

    float ds = tEnd / float(steps);
    vec3 odView = vec3(0.0);
    vec3 rSun = vec3(0.0), mSun = vec3(0.0), rMoon = vec3(0.0), mMoon = vec3(0.0);
    int lightSteps = steps > 8 ? 6 : 4;

    for (int i = 0; i < steps; i++) {
        vec3 p = ro + rd * ((float(i) + 0.5) * ds);
        vec3 d = atmosDensity(length(p) - EARTH_R) * ds;
        odView += d * 0.5;
        vec3 ts = exp(-atmosExtinction(odView + lightOpticalDepth(p, sunDir, lightSteps)));
        vec3 tm = exp(-atmosExtinction(odView + lightOpticalDepth(p, moonDir, lightSteps)));
        rSun += d.x * ts; mSun += d.y * ts;
        rMoon += d.x * tm; mMoon += d.y * tm;
        odView += d * 0.5;
    }
    viewT = exp(-atmosExtinction(odView));

    float muS = dot(rd, sunDir);
    float muM = dot(rd, moonDir);
    float mieScale = 1.0 + rainStrength * 3.0;
    vec3 sun = rSun * BETA_RAYLEIGH * rayleighPhase(muS) + mSun * BETA_MIE * mieScale * miePhase(muS);
    vec3 moon = rMoon * BETA_RAYLEIGH * rayleighPhase(muM) + mMoon * BETA_MIE * mieScale * miePhase(muM);

    vec3 col = sun * SKY_RADIANCE * SUN_BRIGHTNESS
             + moon * SKY_RADIANCE * MOON_ILLUMINANCE * MOON_BRIGHTNESS * MOON_TINT;
    col += vec3(0.0006, 0.0009, 0.0016) * MOON_BRIGHTNESS; // airglow floor so nights are never pitch black

    float rainGray = luminance(col);
    col = mix(col, vec3(rainGray) * vec3(0.86, 0.93, 1.06), rainStrength * 0.8) * (1.0 - rainStrength * 0.55);
    return col;
}

vec3 atmosphere(vec3 rd, vec3 sunDir, vec3 moonDir, int steps) {
    vec3 t;
    return atmosphere(rd, sunDir, moonDir, steps, t);
}

// Direct light color of the current shadow caster (sun by day, moon by night).
vec3 getDirectLightColor(vec3 sunDir, vec3 moonDir) {
    bool sunUp = sunDir.y > 0.0;
    vec3 dir = sunUp ? sunDir : moonDir;
    vec3 t = atmosTransmittance(normalize(vec3(dir.x, max(dir.y, 0.02), dir.z)));
    vec3 col = sunUp ? t * SUN_ILLUMINANCE * SUN_BRIGHTNESS
                     : mix(t, vec3(luminance(t)), 0.5) * MOON_ILLUMINANCE * MOON_BRIGHTNESS * MOON_TINT;
    col *= smoothstep(0.0, 0.06, dir.y);
    col *= 1.0 - rainStrength * 0.85;
    return col;
}

// Hemispherical sky irradiance approximated from a few sky samples.
vec3 getSkyAmbient(vec3 sunDir, vec3 moonDir) {
    vec3 h = normalize(vec3(sunDir.x, 0.0, sunDir.z) + vec3(1e-4, 0.0, 0.0));
    vec3 up = atmosphere(vec3(0.0, 1.0, 0.0), sunDir, moonDir, 6);
    vec3 toward = atmosphere(normalize(h + vec3(0.0, 0.6, 0.0)), sunDir, moonDir, 6);
    vec3 away = atmosphere(normalize(-h + vec3(0.0, 0.6, 0.0)), sunDir, moonDir, 6);
    vec3 amb = (up * 0.5 + toward * 0.25 + away * 0.25) * PI * 0.8;
    // Bounce light from the ground warms and desaturates the pure sky dome color.
    amb = mix(vec3(luminance(amb)) * vec3(1.05, 1.0, 0.92), amb, 0.7);
    return amb * AMBIENT_BRIGHTNESS;
}

float sunDisk(vec3 rd, vec3 sunDir) {
    float cosR = cos(radians(0.55 * SUN_SIZE));
    float mu = dot(rd, sunDir);
    float edge = smoothstep(cosR - 0.00004 * SUN_SIZE, cosR + 0.00002, mu);
    float r = saturate((1.0 - mu) / (1.0 - cosR));
    float limb = 1.0 - 0.6 * (1.0 - sqrt(max(1.0 - r, 0.0)));
    return edge * limb;
}

#endif
