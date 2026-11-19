.import "intro_points.js" as Pts
// Her opening animation (TaylorOS_boot_animation.html, 2026-11-18), moved over line for line: the sparks pour in from
// the corner, swirl into a turning ball, the dial draws itself round it, the ball pulls back and the sparks spell
// "TaylorOS", two of them run off to play in the corner and hop home, and a ripple goes out. The numbers are hers.
// What is new here, and only here: the ending. Her page loops forever; the desktop has to come up. So at FALL the
// sparks let go and fall as rain (the sky's own slant), the dark lifts, and the desktop's live sky is underneath.
// Not a library on purpose: each screen gets its own copy of these sparks.

var W = 0, H = 0, S = 1, R = 100, P = [], t = 0, T = 0;
var cols = ['#4FB386', '#7FD0A8', '#3A9A70', '#A8E3C6', '#2E7F5C'], ACC = '#4FB386';
var FALL = 15.4;          // the sparks start to let go (after the first ripple has gone out)
var LIFT0 = 15.7, LIFT = 1.2;   // the dark lifts over this long
var END = 17.4;           // gone
var skipAt = -1;          // a key or a click: lift quickly from here
var RAIN_X = -0.26, RAIN_Y = 0.966;   // the sky's rain slant (Sky.qml: 70 across for 260 down)

function cl(v) { return Math.max(0, Math.min(1, v)); }
function sm(v) { v = cl(v); return v * v * (3 - 2 * v); }

function setSize(w, h) {
    W = w || 680; H = h || 380;
    S = Math.max(0.5, Math.min(W / 680, H / 380));
    R = Math.min(H * 0.27, W * 0.2);
}

function targets() {
    var F = Math.min(H * 0.3, W * 0.165), st = F * Pts.STEP, c = Pts.cells(), pts = [];
    for (var i = 0; i < c.length; i++) pts.push([W / 2 + c[i][0] * st, H / 2 + c[i][1] * st]);
    return pts;
}

function spawn() {
    P = []; t = 0; T = 1000 * Math.random(); skipAt = -1;
    var pts = targets(), n = pts.length, ring = 260, total = n + ring;
    for (var i = 0; i < total; i++) {
        var sx = W + (6 + Math.random() * 10) * S, sy = H + (6 + Math.random() * 10) * S;
        var th = 0.7854 + (Math.random() - 0.5) * 1.6, ct = Math.cos(th), st = Math.sin(th);
        var ray = Math.min(ct > 0.02 ? W / ct : 1e6, st > 0.02 ? H / st : 1e6);
        var k = 1.9 + Math.random() * 0.9, s = k * ray * (0.15 + 0.8 * Math.sqrt(Math.random()));
        var isT = i < n;
        P.push({ d: Math.pow(Math.random(), 1.2) * 1.7, x: sx, y: sy, vx: -ct * s, vy: -st * s, k: k, age: 0, z: 0, g: 0, m: 0, role: 0,
            t: isT, tx: isT ? pts[i][0] : 0, ty: isT ? pts[i][1] : 0,
            phi: Math.acos(1 - 2 * Math.random()), th: Math.random() * 6.2832,
            ang: Math.random() * 6.2832, rr: (Math.random() - 0.5) * 26 * S, sp: 0.16 + Math.random() * 0.14,
            r: (isT ? 1.25 + Math.random() * 0.5 : 0.9 + Math.random() * 1.6) * S, col: cols[i % cols.length], ph: Math.random() * 6.28,
            fall: FALL + Math.random() * 0.7, fell: false });
    }
    if (n > 2) {
        var li = 0, i2;
        for (i2 = 1; i2 < n; i2++) { if (P[i2].tx > P[li].tx || (P[i2].tx === P[li].tx && P[i2].ty > P[li].ty)) li = i2; }
        var fi = -1, bd = 1e12;
        for (i2 = 0; i2 < n; i2++) { if (i2 === li) continue; var ddx = P[i2].tx - P[li].tx, ddy = P[i2].ty - P[li].ty, dd = ddx * ddx + ddy * ddy; if (dd < bd) { bd = dd; fi = i2; } }
        P[li].role = 1; P[li].d = Math.min(P[li].d, 0.8); P[li].r = 1.6 * S;
        P[fi].role = 2; P[fi].d = Math.min(P[fi].d, 0.8); P[fi].r = 1.6 * S;
    }
}

function back(t) { return sm((t - 5.0) / 1.1); }

function story(p, t) {
    var ax = W * 0.14, ay = H * 0.8, hx = p.tx, hy = p.ty, u, px, py, HOP = 20 * S;
    if (p.role === 1) {
        if (t < 8.0) { u = sm((t - 6.0) / 2.0); px = W / 2 + (ax - W / 2) * u; py = H / 2 + (ay - H / 2) * u + Math.sin(u * 9.4) * 14 * S * (1 - u); }
        else if (t < 10.7) { px = ax + 16 * S * Math.sin((t - 8.0) * 2.4); py = ay + 3 * S * Math.sin((t - 8.0) * 5); }
        else if (t < 11.4) { px = ax; py = ay - (t < 11.15 ? Math.abs(Math.sin((t - 10.7) / 0.45 * 3.1416)) * HOP : 0); }
        else { u = sm((t - 11.4) / 1.9); px = ax + (hx - ax) * u; py = ay + (hy - ay) * u + Math.sin(u * 12.5) * 7 * S * Math.sin(u * 3.1416); }
    } else {
        var bx = ax + 22 * S, by = ay - 4 * S;
        if (t < 9.3) { px = hx; py = hy; }
        else if (t < 10.7) { u = sm((t - 9.3) / 1.4); px = hx + (bx - hx) * u; py = hy + (by - hy) * u + Math.sin(u * 12.5) * 9 * S * Math.sin(u * 3.1416); }
        else if (t < 11.35) { px = bx; py = by - ((t > 10.88 && t < 11.3) ? Math.abs(Math.sin((t - 10.88) / 0.42 * 3.1416)) * HOP * 0.58 : 0); }
        else { u = sm((t - 11.35) / 1.8); px = bx + (hx - bx) * u; py = by + (hy - by) * u + Math.sin(u * 12.5) * 7 * S * Math.sin(u * 3.1416); }
    }
    return [px, py];
}

function step(p, dt, T, t) {
    p.age += dt;
    if (t >= p.fall) {
        // the ending: let go and fall with the rain
        if (!p.fell) { p.fell = true; p.vx *= 0.3; p.vy *= 0.3; }
        p.vx += RAIN_X * 900 * S * dt; p.vy += RAIN_Y * 900 * S * dt;
        p.x += p.vx * dt; p.y += p.vy * dt;
        return;
    }
    var cx = W / 2, cy = H / 2, a1 = p.th + T * 0.7, sp = Math.sin(p.phi), Rs = R * (1 - 0.5 * back(t));
    var sx = cx + Rs * sp * Math.cos(a1), sy = cy + Rs * Math.cos(p.phi), z = sp * Math.sin(a1);
    var fx = p.tx, fy = p.ty;
    if (!p.t) { var a = p.ang + T * p.sp; fx = cx + Math.cos(a) * (W * 0.4 + p.rr); fy = cy + Math.sin(a) * (H * 0.37 + p.rr * 0.6); }
    var m = sm((t - 6.0) / 1.1), tx = sx + (fx - sx) * m, ty = sy + (fy - sy) * m, ks = 16 + (p.t ? 4 : -7) * m, dmp = 6.5;
    if (p.role && t >= 6.0) {
        var q = story(p, t), hop = sm((t - 10.4) / 0.3) * (1 - sm((t - 11.4) / 0.4));
        ks = 22 + 150 * hop; dmp = 6.5 + 12 * hop;
        if (p.role === 1) { tx = q[0]; ty = q[1]; m = 1; }
        else { tx = sx + (q[0] - sx) * m; ty = sy + (q[1] - sy) * m; }
    }
    p.z = z * (1 - m);
    var g = cl((p.age - 1.0) / 1.3);
    var dx = p.x - cx, dy = p.y - cy, sg = W * 0.2, gz = Math.exp(-(dx * dx + dy * dy) / (2 * sg * sg));
    var w = 1.2 * gz * (1 - g) * dt, cs = Math.cos(w), sn = Math.sin(w), vx = p.vx * cs - p.vy * sn, vy = p.vx * sn + p.vy * cs;
    vx += (tx - p.x) * ks * g * dt; vy += (ty - p.y) * ks * g * dt;
    var f = Math.exp(-(p.k * (1 - g) + dmp * g) * dt);
    p.vx = vx * f; p.vy = vy * f;
    p.x += p.vx * dt; p.y += p.vy * dt;
    p.g = g; p.m = m;
}

// One frame forward. dt is capped as in her page, so a slow frame never makes the sparks jump.
function advance(dt) {
    dt = Math.min(0.033, Math.max(0, dt));
    t += dt; T += dt;
    for (var i = 0; i < P.length; i++) { if (t >= P[i].d) step(P[i], dt, T, t); }
}

// Jump straight to time `at` (seconds), for the still frames the tests take.
function settleTo(at) {
    while (t < at) advance(Math.min(1 / 60, at - t + 1e-6));
}

function elapsed() { return t; }
function skipped() { return skipAt >= 0; }

function skip() { if (skipAt < 0) skipAt = t; }

// How much of the dark is left (1 = all of it).
function cover() {
    var c = 1 - sm((t - LIFT0) / LIFT);
    if (skipAt >= 0) c = Math.min(c, 1 - cl((t - skipAt) / 0.35));
    return c;
}

function finished() { return t >= END || (skipAt >= 0 && t >= skipAt + 0.4); }

function dial(x, t, T, al0) {
    var a = sm((t - 2.3) / 1.5), out = back(t);
    if (a <= 0 || out >= 1) return;
    var cx = W / 2, cy = H / 2, sc = 1 - 0.5 * out, al = Math.pow(1 - out, 1.6) * al0, Rd = (R + 22 * S) * sc, q = sc * S, s0 = -1.5708, s1 = s0 + a * 6.2832;
    x.lineCap = 'round';
    x.strokeStyle = ACC;
    x.globalAlpha = 0.12 * al; x.lineWidth = 9 * q; x.beginPath(); x.arc(cx, cy, Rd, s0, s1, false); x.stroke();
    x.globalAlpha = 0.95 * al; x.lineWidth = Math.max(0.5, 1.5 * q); x.beginPath(); x.arc(cx, cy, Rd, s0, s1, false); x.stroke();
    x.strokeStyle = '#EDEFEE'; x.lineWidth = Math.max(0.5, q);
    var nt = Math.floor(72 * a);
    for (var i = 0; i < nt; i++) {
        var an = s0 + i / 72 * 6.2832, big = i % 6 === 0, r0 = Rd + 9 * q, r1 = Rd + (big ? 17 : 13) * q;
        x.globalAlpha = (big ? 0.55 : 0.28) * al;
        x.beginPath(); x.moveTo(cx + Math.cos(an) * r0, cy + Math.sin(an) * r0); x.lineTo(cx + Math.cos(an) * r1, cy + Math.sin(an) * r1); x.stroke();
    }
    x.strokeStyle = ACC; x.lineWidth = Math.max(0.6, 2.5 * q);
    var b = sm((t - 3.2) / 0.9);
    for (var j = 0; j < 3; j++) {
        var st = T * 0.35 + j * 2.0944;
        x.globalAlpha = 0.85 * al * b;
        x.beginPath(); x.arc(cx, cy, Rd + 26 * q, st, st + 0.3 + 0.7 * b, false); x.stroke();
    }
    x.globalAlpha = 1;
}

function draw(x) {
    var cov = cover();
    x.reset();
    x.clearRect(0, 0, W, H);
    if (cov > 0) {
        x.globalAlpha = cov; x.fillStyle = '#0B0D0C'; x.fillRect(0, 0, W, H);
        x.lineWidth = Math.max(1, S * 0.8);
        for (var j = 0; j < 9; j++) {
            x.globalAlpha = cov;
            x.strokeStyle = 'rgba(165,172,168,' + (0.035 + j * 0.006) + ')';
            x.beginPath();
            var base = H * (0.1 + j * 0.105), amp = (5 + j * 1.1) * S, sp = 0.3 + j * 0.04, stp = Math.max(8, W / 120);
            for (var u = 0; u <= W + stp; u += stp) {
                var un = u / S, yy = base + Math.sin(un * 0.009 + T * sp + j * 1.7) * amp + Math.sin(un * 0.023 - T * sp * 0.7 + j * 0.9) * amp * 0.45;
                if (u === 0) x.moveTo(u, yy); else x.lineTo(u, yy);
            }
            x.stroke();
        }
        x.globalAlpha = 1;
        dial(x, t, T, cov);
    }
    var reach = Math.sqrt(W * W + H * H) / 2 + 80 * S, band = 46 * S;
    var wave = t > 14.0 ? ((t - 14.0) * 150 * S) % (reach + 200 * S) : -99999;
    var inStory = t > 6.0 && t < 13.7, grow = sm((t - 6.2) / 0.8) * (1 - sm((t - 13.1) / 0.6));
    var skipFade = skipAt >= 0 ? 1 - cl((t - skipAt) / 0.35) : 1;
    x.lineCap = 'round';
    for (var i = 0; i < P.length; i++) {
        var p = P[i];
        if (t < p.d) continue;
        if (p.y > H + 60 * S) continue;   // fallen off the bottom
        var sp2 = Math.sqrt(p.vx * p.vx + p.vy * p.vy), px = p.x, py = p.y, g = p.g, m = p.m;
        var al = p.t ? 0.9 : 0.5 + 0.25 * Math.sin(p.age * 1.3 + p.ph) + 0.3 * (1 - m) * g;
        var depth = (1 - m) * g, rad = p.r * (1 + 0.4 * p.z * depth) * (1 - 0.25 * back(t) * (1 - m));
        al = cl(al) * (1 - depth * 0.75 * (0.5 - 0.5 * p.z)) * skipFade;
        var hero = p.role && inStory;
        if (p.role) rad = rad * (1 + 0.45 * grow);
        if (p.fell) {
            // a falling spark is a raindrop: a pale streak along its fall, the green dot fading at its head
            var k = cl((t - p.fall) / 0.5);
            x.strokeStyle = 'rgba(205,220,230,1)'; x.globalAlpha = 0.5 * k * skipFade; x.lineWidth = Math.max(1, S * 0.7);
            x.beginPath(); x.moveTo(px - p.vx * 0.05, py - p.vy * 0.05); x.lineTo(px, py); x.stroke();
            x.globalAlpha = al * (1 - 0.7 * k); x.fillStyle = p.col;
            x.beginPath(); x.arc(px, py, Math.max(0.4, rad), 0, 6.2832, false); x.fill();
            continue;
        }
        if (sp2 > 60 * S && !hero) {
            x.strokeStyle = p.col; x.globalAlpha = 0.3 * skipFade; x.lineWidth = p.r * 1.3;
            x.beginPath(); x.moveTo(px - p.vx * 0.03, py - p.vy * 0.03); x.lineTo(px, py); x.stroke();
        }
        var dx = px - W / 2, dy = py - H / 2, r = Math.sqrt(dx * dx + dy * dy) + 0.01, q = wave - r;
        if (q > 0 && q < band) {
            var b = Math.sin(q / band * 3.1416);
            px += dx / r * b * 3.5 * S; py += dy / r * b * 3.5 * S; al = Math.min(1, al + b * 0.4); rad = rad * (1 + b * 0.5);
        }
        if (p.t && !hero && m > 0.99 && sp2 < 20 * S) { px += Math.sin(T * 1.7 + p.ph) * 0.5 * S; py += Math.cos(T * 1.3 + p.ph) * 0.5 * S; }
        x.globalAlpha = al; x.fillStyle = p.col;
        x.beginPath(); x.arc(px, py, Math.max(0.4, rad), 0, 6.2832, false); x.fill();
        x.globalAlpha = 1;
    }
    x.globalAlpha = 1;
}
