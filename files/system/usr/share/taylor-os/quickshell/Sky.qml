// The live Horizon wallpaper, from her mockup "7 · Dock your way + mixer widget".
// The sun and moon follow real sun times for Washington, DC (her location in the mockup), worked out from
// the date, and the sky and hills blend through night, dawn, day and dusk, the same maths as the mockup.
// Drawn on the background layer, above hyprpaper (which stays as the still picture if this ever fails).
// The weather is real too: the mockup's clear / cloudy / rain / snow looks, picked from the current weather in DC
// (Open-Meteo, keyless, the same city-level spot TAYLOR's weather uses), asked every 15 minutes. If it can't be
// reached the sky stays as it was (clear at first). Clouds drift, rain and snow fall, as in the mockup.
// Repaints once a minute. TAYLOR_SKY_HOUR=13.5 and TAYLOR_SKY_WX=rain (for example) pin the hour and the weather,
// for the preview only.
// Canvas on purpose: it draws with the software renderer too, so the automatic preview can show it. Each layer is
// painted once and only moved, so the drifting and falling cost almost nothing.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win
    property QtObject theme
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#0F1010"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "taylor-sky"

    readonly property real pinnedHour: {
        const v = parseFloat(Quickshell.env("TAYLOR_SKY_HOUR") || "");
        return isNaN(v) ? -1 : v;
    }

    readonly property string pinnedWx: {
        const v = Quickshell.env("TAYLOR_SKY_WX") || "";
        return ["clear", "cloudy", "rain", "snow"].indexOf(v) >= 0 ? v : "";
    }
    property string liveWx: "clear"
    readonly property string wx: pinnedWx !== "" ? pinnedWx : liveWx
    onWxChanged: win.repaintAll()

    // sx / sy: the 1440 x 900 drawing fitted to the screen; sr keeps round things round.
    readonly property real sx: width / 1440
    readonly property real sy: height / 900
    readonly property real sr: Math.min(sx, sy)

    function repaintAll() { sky.requestPaint(); clouds.requestPaint(); hillsLayer.requestPaint(); }
    Connections { target: Prefs; function onSkyDeeperChanged() { win.repaintAll(); } }

    SystemClock { id: clock; precision: SystemClock.Minutes; onDateChanged: win.repaintAll() }

    // WMO weather codes to the mockup's four looks.
    function wxFromCode(c) {
        if (c >= 71 && c <= 77 || c === 85 || c === 86) return "snow";
        if (c >= 51 && c <= 67 || c >= 80 && c <= 82 || c >= 95) return "rain";
        if (c >= 2) return "cloudy";   // 2 partly cloudy, 3 overcast, 45/48 fog
        return "clear";
    }
    function fetchWeather() {
        const req = new XMLHttpRequest();
        req.onreadystatechange = function () {
            if (req.readyState !== XMLHttpRequest.DONE) return;
            try {
                const code = JSON.parse(req.responseText).current.weather_code;
                win.liveWx = win.wxFromCode(code);
                console.info("taylor-sky: weather code " + code + " -> " + win.liveWx);
            } catch (e) {
                console.info("taylor-sky: weather not read (status " + req.status + "); keeping " + win.liveWx);
            }
        };
        req.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=38.9&longitude=-77.04&current=weather_code");
        req.send();
    }
    Timer {
        interval: 15 * 60 * 1000
        repeat: true
        running: win.pinnedWx === ""
        triggeredOnStart: true
        onTriggered: win.fetchWeather()
    }

    // 110 stars and the three hills, copied from the mockup (1440 x 900 drawing).
    readonly property var stars: [[487, 143, 1.2, 0.75], [970, 77, 0.8, 0.75], [960, 275, 1, 0.36], [963, 497, 1.6, 0.6], [308, 247, 1, 0.73], [1071, 409, 0.8, 0.62], [131, 173, 0.8, 0.42], [63, 285, 1.6, 0.58], [793, 447, 1.6, 0.65], [1181, 465, 1, 0.73], [199, 46, 1, 0.52], [528, 456, 1.2, 0.48], [790, 369, 1.6, 0.57], [689, 39, 1.2, 0.8], [1374, 177, 1.2, 0.78], [1171, 116, 1, 0.6], [1174, 283, 1.2, 0.32], [987, 505, 0.8, 0.44], [136, 430, 1, 0.26], [874, 435, 0.8, 0.27], [1258, 56, 1.6, 0.65], [677, 295, 1, 0.8], [634, 17, 0.8, 0.31], [1096, 42, 1, 0.78], [597, 279, 1, 0.63], [695, 331, 1.2, 0.78], [773, 395, 1.6, 0.73], [790, 115, 1.2, 0.49], [486, 318, 1.6, 0.79], [1067, 320, 1.2, 0.26], [850, 332, 0.8, 0.46], [1206, 146, 0.8, 0.6], [680, 487, 1.2, 0.62], [722, 295, 1.6, 0.26], [124, 31, 1.2, 0.39], [934, 315, 1.2, 0.35], [379, 330, 1.2, 0.71], [540, 317, 1.6, 0.31], [55, 144, 1.2, 0.53], [1338, 285, 1, 0.43], [1388, 455, 0.8, 0.31], [659, 351, 1, 0.49], [346, 91, 1.2, 0.66], [446, 471, 1.2, 0.37], [247, 44, 1, 0.42], [1177, 197, 1.2, 0.44], [1314, 97, 1.2, 0.57], [862, 308, 1.2, 0.51], [1298, 436, 1.2, 0.48], [838, 46, 1.6, 0.34], [9, 498, 1.6, 0.56], [454, 43, 1.6, 0.71], [1357, 305, 1.2, 0.74], [139, 303, 0.8, 0.7], [92, 45, 1, 0.74], [880, 60, 0.8, 0.51], [247, 185, 1.2, 0.38], [40, 433, 0.8, 0.77], [1253, 126, 1.2, 0.32], [1107, 498, 0.8, 0.44], [404, 135, 0.8, 0.34], [560, 141, 0.8, 0.52], [1169, 419, 0.8, 0.67], [508, 285, 1.6, 0.28], [661, 11, 0.8, 0.68], [94, 137, 0.8, 0.29], [67, 98, 1.6, 0.42], [644, 83, 1.2, 0.46], [797, 321, 1.2, 0.4], [673, 448, 0.8, 0.32], [7, 399, 0.8, 0.56], [87, 392, 1.6, 0.58], [1108, 399, 0.8, 0.59], [883, 64, 1.2, 0.6], [1439, 332, 1.6, 0.77], [856, 481, 0.8, 0.38], [1097, 286, 0.8, 0.69], [459, 446, 1, 0.73], [666, 393, 1.2, 0.32], [1414, 136, 1.6, 0.62], [652, 115, 0.8, 0.51], [483, 408, 0.8, 0.54], [1155, 111, 1.6, 0.35], [48, 359, 0.8, 0.26], [235, 503, 1.2, 0.57], [181, 47, 1, 0.31], [204, 72, 1.2, 0.73], [369, 89, 1, 0.8], [1322, 265, 1.6, 0.59], [806, 268, 1.2, 0.58], [717, 438, 0.8, 0.46], [481, 432, 1, 0.48], [1164, 539, 1.6, 0.34], [821, 162, 1, 0.3], [990, 539, 1.6, 0.57], [381, 149, 1.2, 0.66], [300, 537, 1.2, 0.76], [1415, 312, 1.6, 0.58], [1197, 283, 1, 0.42], [549, 500, 1.6, 0.36], [1167, 379, 1, 0.43], [294, 438, 1.6, 0.64], [421, 489, 0.8, 0.51], [148, 419, 0.8, 0.51], [470, 250, 0.8, 0.78], [520, 257, 1, 0.68], [281, 201, 0.8, 0.74], [522, 183, 0.8, 0.42], [866, 103, 0.8, 0.31], [541, 308, 0.8, 0.45]]
    readonly property var hills: [
        "M0,900 L0,686.1 L10,687.8 L20,689.4 L30,690.9 L40,692.3 L50,693.5 L60,694.5 L70,695.5 L80,696.3 L90,697.0 L100,697.5 L110,697.9 L120,698.1 L130,698.3 L140,698.3 L150,698.2 L160,697.9 L170,697.5 L180,697.1 L190,696.5 L200,695.8 L210,695.1 L220,694.2 L230,693.3 L240,692.2 L250,691.2 L260,690.0 L270,688.8 L280,687.6 L290,686.3 L300,685.0 L310,683.7 L320,682.4 L330,681.0 L340,679.7 L350,678.3 L360,677.0 L370,675.7 L380,674.5 L390,673.2 L400,672.0 L410,670.9 L420,669.8 L430,668.7 L440,667.7 L450,666.8 L460,666.0 L470,665.2 L480,664.4 L490,663.8 L500,663.2 L510,662.7 L520,662.3 L530,661.9 L540,661.6 L550,661.4 L560,661.3 L570,661.2 L580,661.2 L590,661.2 L600,661.3 L610,661.4 L620,661.6 L630,661.8 L640,662.1 L650,662.4 L660,662.7 L670,663.0 L680,663.4 L690,663.7 L700,664.1 L710,664.4 L720,664.7 L730,665.0 L740,665.3 L750,665.5 L760,665.7 L770,665.9 L780,666.0 L790,666.0 L800,666.0 L810,665.9 L820,665.7 L830,665.5 L840,665.1 L850,664.7 L860,664.2 L870,663.6 L880,662.9 L890,662.1 L900,661.2 L910,660.2 L920,659.1 L930,658.0 L940,656.7 L950,655.3 L960,653.8 L970,652.3 L980,650.6 L990,648.9 L1000,647.1 L1010,645.2 L1020,643.3 L1030,641.3 L1040,639.2 L1050,637.1 L1060,634.9 L1070,632.7 L1080,630.5 L1090,628.2 L1100,626.0 L1110,623.7 L1120,621.4 L1130,619.2 L1140,616.9 L1150,614.7 L1160,612.6 L1170,610.4 L1180,608.4 L1190,606.4 L1200,604.5 L1210,602.6 L1220,600.9 L1230,599.2 L1240,597.6 L1250,596.2 L1260,594.9 L1270,593.6 L1280,592.6 L1290,591.6 L1300,590.8 L1310,590.1 L1320,589.6 L1330,589.2 L1340,589.0 L1350,589.0 L1360,589.0 L1370,589.3 L1380,589.7 L1390,590.2 L1400,590.9 L1410,591.8 L1420,592.8 L1430,594.0 L1440,595.3 L1440,900 Z",
        "M0,900 L0,754.7 L10,755.5 L20,756.2 L30,756.7 L40,757.2 L50,757.5 L60,757.7 L70,757.7 L80,757.5 L90,757.2 L100,756.7 L110,756.1 L120,755.2 L130,754.2 L140,753.0 L150,751.7 L160,750.1 L170,748.4 L180,746.6 L190,744.6 L200,742.4 L210,740.1 L220,737.7 L230,735.1 L240,732.4 L250,729.7 L260,726.9 L270,724.0 L280,721.0 L290,718.0 L300,715.0 L310,712.0 L320,709.0 L330,706.0 L340,703.1 L350,700.2 L360,697.4 L370,694.7 L380,692.1 L390,689.6 L400,687.3 L410,685.0 L420,683.0 L430,681.1 L440,679.3 L450,677.8 L460,676.4 L470,675.2 L480,674.2 L490,673.4 L500,672.8 L510,672.4 L520,672.2 L530,672.2 L540,672.4 L550,672.8 L560,673.3 L570,674.0 L580,674.9 L590,676.0 L600,677.1 L610,678.5 L620,679.9 L630,681.4 L640,683.1 L650,684.8 L660,686.6 L670,688.5 L680,690.4 L690,692.3 L700,694.2 L710,696.2 L720,698.1 L730,700.0 L740,701.9 L750,703.7 L760,705.5 L770,707.2 L780,708.8 L790,710.3 L800,711.8 L810,713.1 L820,714.3 L830,715.5 L840,716.5 L850,717.4 L860,718.2 L870,718.9 L880,719.4 L890,719.9 L900,720.3 L910,720.6 L920,720.8 L930,720.9 L940,720.9 L950,720.9 L960,720.8 L970,720.6 L980,720.5 L990,720.3 L1000,720.0 L1010,719.8 L1020,719.6 L1030,719.4 L1040,719.3 L1050,719.1 L1060,719.1 L1070,719.0 L1080,719.1 L1090,719.2 L1100,719.4 L1110,719.7 L1120,720.1 L1130,720.6 L1140,721.2 L1150,722.0 L1160,722.8 L1170,723.7 L1180,724.8 L1190,725.9 L1200,727.2 L1210,728.6 L1220,730.0 L1230,731.6 L1240,733.2 L1250,734.9 L1260,736.7 L1270,738.5 L1280,740.4 L1290,742.3 L1300,744.3 L1310,746.2 L1320,748.2 L1330,750.1 L1340,752.0 L1350,753.8 L1360,755.6 L1370,757.3 L1380,759.0 L1390,760.5 L1400,761.9 L1410,763.2 L1420,764.3 L1430,765.3 L1440,766.2 L1440,900 Z",
        "M0,900 L0,790.1 L10,788.3 L20,786.3 L30,784.3 L40,782.3 L50,780.2 L60,778.1 L70,776.1 L80,774.1 L90,772.1 L100,770.3 L110,768.5 L120,766.8 L130,765.3 L140,763.9 L150,762.7 L160,761.7 L170,760.9 L180,760.3 L190,759.9 L200,759.7 L210,759.8 L220,760.1 L230,760.7 L240,761.4 L250,762.4 L260,763.7 L270,765.1 L280,766.8 L290,768.7 L300,770.7 L310,772.9 L320,775.3 L330,777.8 L340,780.4 L350,783.1 L360,785.8 L370,788.6 L380,791.5 L390,794.3 L400,797.1 L410,799.9 L420,802.6 L430,805.2 L440,807.8 L450,810.2 L460,812.5 L470,814.6 L480,816.5 L490,818.3 L500,820.0 L510,821.4 L520,822.6 L530,823.7 L540,824.5 L550,825.2 L560,825.6 L570,825.9 L580,826.0 L590,826.0 L600,825.8 L610,825.5 L620,825.0 L630,824.5 L640,823.8 L650,823.1 L660,822.3 L670,821.5 L680,820.6 L690,819.8 L700,818.9 L710,818.1 L720,817.3 L730,816.6 L740,815.9 L750,815.3 L760,814.8 L770,814.4 L780,814.1 L790,813.9 L800,813.8 L810,813.8 L820,813.8 L830,814.0 L840,814.3 L850,814.7 L860,815.1 L870,815.6 L880,816.2 L890,816.7 L900,817.3 L910,818.0 L920,818.6 L930,819.1 L940,819.7 L950,820.1 L960,820.5 L970,820.8 L980,821.0 L990,821.1 L1000,821.0 L1010,820.8 L1020,820.5 L1030,819.9 L1040,819.2 L1050,818.4 L1060,817.3 L1070,816.1 L1080,814.7 L1090,813.1 L1100,811.3 L1110,809.4 L1120,807.4 L1130,805.2 L1140,802.8 L1150,800.4 L1160,797.9 L1170,795.3 L1180,792.6 L1190,789.9 L1200,787.2 L1210,784.5 L1220,781.8 L1230,779.2 L1240,776.7 L1250,774.2 L1260,771.9 L1270,769.7 L1280,767.7 L1290,765.8 L1300,764.1 L1310,762.6 L1320,761.3 L1330,760.3 L1340,759.5 L1350,758.9 L1360,758.5 L1370,758.4 L1380,758.6 L1390,759.0 L1400,759.6 L1410,760.4 L1420,761.4 L1430,762.7 L1440,764.1 L1440,900 Z"
    ]

    function mix(h1, h2, t) {
        const a = h1.replace('#', ''), b = h2.replace('#', '');
        const ch = (s, i) => parseInt(s.slice(i, i + 2), 16);
        const m = (i) => Math.round(ch(a, i) + (ch(b, i) - ch(a, i)) * t).toString(16).padStart(2, '0');
        return '#' + m(0) + m(2) + m(4);
    }

    function rgba(hex, a) {
        const h = hex.replace('#', '');
        return 'rgba(' + parseInt(h.slice(0, 2), 16) + ',' + parseInt(h.slice(2, 4), 16) + ',' + parseInt(h.slice(4, 6), 16) + ',' + a + ')';
    }

    // The mockup's scene maths, value for value, with its weather (which the mockup only showed in preview).
    function scene(nowD) {
        const bg = '#0F1010', accent = '#4FB386';
        const LAT = 38.9, LON = -77.04, rad = Math.PI / 180;
        const start0 = new Date(nowD.getFullYear(), 0, 0);
        const doy = Math.floor((nowD - start0) / 86400000);
        const Bv = rad * (360 / 365) * (doy - 81);
        const decl = 23.44 * Math.sin(Bv) * rad;
        const eot = 9.87 * Math.sin(2 * Bv) - 7.53 * Math.cos(Bv) - 1.5 * Math.sin(Bv);
        const cosH = (Math.sin(-0.833 * rad) - Math.sin(LAT * rad) * Math.sin(decl)) / (Math.cos(LAT * rad) * Math.cos(decl));
        const haH = Math.acos(Math.max(-1, Math.min(1, cosH))) / rad / 15;
        const tzH = -nowD.getTimezoneOffset() / 60;
        const noon = 12 - LON / 15 - eot / 60 + tzH;
        const rise = noon - haH, set = noon + haH;
        const hourNow = win.pinnedHour >= 0 ? win.pinnedHour : nowD.getHours() + nowD.getMinutes() / 60;
        const dayLen = set - rise;
        const tSun = (hourNow - rise) / dayLen;
        let tNight = (hourNow - set) / (24 - dayLen); if (tNight < 0) tNight += 24 / (24 - dayLen);
        const elev = (tSun >= 0 && tSun <= 1) ? Math.sin(Math.PI * tSun) : -Math.sin(Math.PI * Math.min(1, tNight));
        const morning = hourNow < noon;
        const P = {
            night: { top: bg, mid: mix(bg, '#1B2A33', 0.8), bottom: mix(bg, accent, 0.18), h: [mix(bg, accent, 0.16), mix(bg, accent, 0.09), mix(bg, accent, 0.04)] },
            dawn: { top: '#1B2235', mid: '#5A4A6E', bottom: '#E9A27C', h: ['#3B3550', '#2A2740', '#1C1B2C'] },
            dusk: { top: '#1E1830', mid: '#6E3A58', bottom: '#E07A4F', h: ['#3B2442', '#2A1A32', '#1A1222'] },
            day: { top: '#2F6E95', mid: '#5E9BBB', bottom: '#A9CFDB', h: ['#5B8A6E', '#3E6A51', '#2A4B39'] }
        };
        // her Settings switch "Deeper daytime sky" (her brief: about #1E3A4C to #2F5568 to #4A7480)
        if (Prefs.skyDeeper) { P.day.top = '#1E3A4C'; P.day.mid = '#2F5568'; P.day.bottom = '#4A7480'; }
        const blend = (A, B2, t) => ({ top: mix(A.top, B2.top, t), mid: mix(A.mid, B2.mid, t), bottom: mix(A.bottom, B2.bottom, t), h: [0, 1, 2].map((i) => mix(A.h[i], B2.h[i], t)) });
        const twi = morning ? P.dawn : P.dusk;
        let skyC;
        if (elev <= -0.22) skyC = P.night;
        else if (elev <= 0) skyC = blend(P.night, twi, (elev + 0.22) / 0.22);
        else if (elev <= 0.32) skyC = blend(twi, P.day, elev / 0.32);
        else skyC = P.day;
        const wx = win.wx;
        const cloudK = { clear: 0, cloudy: 0.72, rain: 0.86, snow: 0.6 }[wx];
        const greyC = mix('#1A1E22', '#8C969E', Math.max(0, elev));
        const sky = {
            top: mix(skyC.top, greyC, cloudK * 0.8), mid: mix(skyC.mid, greyC, cloudK), bottom: mix(skyC.bottom, greyC, cloudK),
            h: skyC.h.map((x) => mix(x, mix(x, '#2A2F33', 0.5), cloudK * 0.6))
        };
        const lowSun = Math.max(0, 1 - Math.max(0, elev) / 0.35);
        const sunVis = (tSun > -0.04 && tSun < 1.04) ? 1 : 0;
        const moonVis = (tNight > -0.03 && tNight < 1.03) ? 1 : 0;
        const avoid = (x, y) => {
            const cx = 930, cy = 390, R = 320;
            const dx = x - cx, dy = y - cy, dist = Math.sqrt(dx * dx + dy * dy) || 1;
            if (dist >= R) return { x: Math.round(x), y: Math.round(y) };
            return { x: Math.round(cx + dx / dist * R), y: Math.round(cy + dy / dist * R) };
        };
        const arcPos = (t, h) => avoid(140 + Math.max(-0.05, Math.min(1.05, t)) * 1160, 680 - Math.sin(Math.PI * Math.max(0, Math.min(1, t))) * h);
        return {
            sky: sky, elev: elev,
            sun: mix('#FFF6DC', '#FFB070', lowSun),
            sunGlow: 'rgba(255,' + Math.round(240 - 90 * lowSun) + ',' + Math.round(200 - 110 * lowSun) + ',' + (0.22 + 0.12 * lowSun).toFixed(2) + ')',
            sunR: Math.round(38 + 16 * lowSun), sunP: arcPos(tSun, 520), sunOp: sunVis * (1 - cloudK * 0.9),
            moonP: arcPos(tNight, 480), moonOp: moonVis * (1 - cloudK * 0.85),
            starOp: Math.max(0, Math.min(1, (-elev - 0.05) / 0.25)) * (1 - cloudK),
            cloud: mix(greyC, '#FFFFFF', elev > 0 ? 0.25 : 0.05)
        };
    }

    // The mockup's eleven cloud shapes: [cx, cy, rx, ry, opacity], drawn soft-edged (the mockup blurs them 18 px).
    readonly property var cloudShapes: [[826, 346, 279, 68, 0.70], [1102, 157, 207, 72, 0.69], [1157, 155, 184, 68, 0.62],
        [85, 335, 170, 78, 0.89], [827, 394, 317, 50, 0.75], [982, 92, 175, 42, 0.58], [395, 367, 167, 69, 0.63],
        [1110, 160, 292, 54, 0.76], [923, 62, 181, 69, 0.76], [733, 342, 181, 56, 0.63], [370, 322, 233, 41, 0.53]]

    // A pattern layer one tile bigger than the screen on each side, painted once and then slid by exactly one tile,
    // so the loop has no seam. draw(ctx) paints one tile at (0, 0).
    component Falling: Item {
        id: fall
        property real tileW: 100
        property real tileH: 100
        property real dx: 0          // how far it slides sideways per loop (the mockup's rain jumps back a little each loop, as here)
        property int ms: 1000
        property var draw: function (ctx) {}
        anchors.fill: parent
        clip: true
        Canvas {
            id: pat
            x: -fall.tileW; y: -fall.tileH
            width: fall.width + 2 * fall.tileW; height: fall.height + 2 * fall.tileH
            renderStrategy: Canvas.Cooperative
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                for (let ty = 0; ty < height; ty += fall.tileH)
                    for (let tx = 0; tx < width; tx += fall.tileW) {
                        ctx.save(); ctx.translate(tx, ty);
                        ctx.beginPath(); ctx.rect(0, 0, fall.tileW, fall.tileH); ctx.clip();
                        fall.draw(ctx);
                        ctx.restore();
                    }
            }
            NumberAnimation on y { from: -fall.tileH; to: 0; duration: fall.ms; loops: Animation.Infinite; running: fall.visible }
            NumberAnimation on x { from: -fall.tileW; to: -fall.tileW + fall.dx; duration: fall.ms; loops: Animation.Infinite; running: fall.visible && fall.dx !== 0 }
        }
    }

    Canvas {
        id: sky
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const sc = win.scene(clock.date);
            ctx.reset();
            // Fit the whole 1440 x 900 drawing to the screen, never cropping it: on a wider screen (16:9) the sky and
            // hills stretch sideways a little, and the sun, moon and stars stay round (cropping the top hid the
            // midday sun behind the dock in the first preview).
            const sx = win.sx, sy = win.sy, sr = win.sr;
            ctx.scale(sx, sy);

            const g = ctx.createLinearGradient(0, 0, 0, 900);
            g.addColorStop(0, sc.sky.top); g.addColorStop(0.55, sc.sky.mid); g.addColorStop(0.8, sc.sky.bottom); g.addColorStop(1, sc.sky.bottom);
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, 1440, 900);

            function disc(x, y, r, fill, alpha) {
                ctx.save();
                ctx.resetTransform();
                ctx.globalAlpha = alpha; ctx.fillStyle = fill;
                ctx.beginPath(); ctx.arc(x * sx, y * sy, r * sr, 0, 2 * Math.PI); ctx.fill();
                ctx.restore();
            }
            if (sc.starOp > 0)
                for (let i = 0; i < win.stars.length; i++) {
                    const st = win.stars[i];
                    disc(st[0], st[1], st[2], '#FFFFFF', st[3] * sc.starOp);
                }
            if (sc.moonOp > 0) {
                disc(sc.moonP.x, sc.moonP.y, 90, 'rgba(228,236,232,0.07)', sc.moonOp);
                disc(sc.moonP.x, sc.moonP.y, 24, '#E4ECE8', sc.moonOp);
            }
            if (sc.sunOp > 0) {
                disc(sc.sunP.x, sc.sunP.y, 130, sc.sunGlow, sc.sunOp);
                disc(sc.sunP.x, sc.sunP.y, sc.sunR, sc.sun, sc.sunOp);
            }
        }
    }

    // Clouds, between the sun and the hills, drifting slowly side to side (the mockup's 90 s drift).
    Canvas {
        id: clouds
        width: parent.width; height: parent.height
        visible: win.wx !== "clear"
        opacity: 0.85
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (win.wx === "clear") return;
            const col = win.scene(clock.date).cloud;
            for (let i = 0; i < win.cloudShapes.length; i++) {
                const c = win.cloudShapes[i];
                ctx.save();
                ctx.translate(c[0] * win.sx, c[1] * win.sy);
                ctx.scale(c[2] * win.sx, c[3] * win.sy);
                const g = ctx.createRadialGradient(0, 0, 0, 0, 0, 1.15);
                g.addColorStop(0, win.rgba(col, c[4]));
                g.addColorStop(0.7, win.rgba(col, c[4] * 0.85));
                g.addColorStop(1, win.rgba(col, 0));
                ctx.fillStyle = g;
                ctx.beginPath(); ctx.arc(0, 0, 1.15, 0, 2 * Math.PI); ctx.fill();
                ctx.restore();
            }
        }
        SequentialAnimation on x {
            running: clouds.visible
            loops: Animation.Infinite
            NumberAnimation { from: -60 * win.sx; to: 60 * win.sx; duration: 90000; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 60 * win.sx; to: -60 * win.sx; duration: 90000; easing.type: Easing.InOutQuad }
        }
    }

    Canvas {
        id: hillsLayer
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            const sc = win.scene(clock.date);
            ctx.reset();
            ctx.scale(win.sx, win.sy);
            for (let i = 0; i < 3; i++) {
                ctx.fillStyle = sc.sky.h[i];
                ctx.beginPath(); ctx.path = win.hills[i]; ctx.fill();
            }
        }
    }

    // Rain: the mockup's thin slanted streaks (105 degrees, one every 23 px, 180 x 260 tiles), falling every 0.7 s.
    Falling {
        visible: win.wx === "rain"
        tileW: 180 * win.sr; tileH: 260 * win.sr; dx: -70 * win.sr; ms: 700
        draw: function (ctx) {
            const s = win.sr, gx = Math.sin(105 * Math.PI / 180), gy = -Math.cos(105 * Math.PI / 180);
            ctx.strokeStyle = "rgba(205,220,230,0.16)";
            ctx.lineWidth = Math.max(1, s);
            for (let k = -40; k <= 40; k++) {
                const d = (k * 23 + 22.5) * s;         // distance along the slant to this streak
                const px = d * gx, py = d * gy;        // a point on the streak; the streak runs at right angles
                ctx.beginPath();
                ctx.moveTo(px - gy * 2000, py + gx * 2000);
                ctx.lineTo(px + gy * 2000, py - gx * 2000);
                ctx.stroke();
            }
        }
    }

    // Snow: the mockup's two layers of flakes, falling at its speeds (about 50 and 39 px a second), straight down so the loop has no seam.
    Falling {
        visible: win.wx === "snow"
        tileW: 140 * win.sr; tileH: 140 * win.sr; ms: 2800
        draw: function (ctx) {
            const s = win.sr;
            ctx.fillStyle = "rgba(255,255,255,0.75)";
            ctx.beginPath(); ctx.arc(70 * s, 70 * s, 2.1 * s, 0, 2 * Math.PI); ctx.fill();
        }
    }
    Falling {
        visible: win.wx === "snow"
        tileW: 90 * win.sr; tileH: 90 * win.sr; ms: 2330
        draw: function (ctx) {
            const s = win.sr;
            ctx.fillStyle = "rgba(255,255,255,0.5)";
            ctx.beginPath(); ctx.arc(40 * s, 60 * s, 1.5 * s, 0, 2 * Math.PI); ctx.fill();
        }
    }
}
