import { LyricPlayer, BackgroundRender, MeshGradientRenderer } from "@applemusic-like-lyrics/core";
import { parseTTML } from "@applemusic-like-lyrics/lyric";
import "@applemusic-like-lyrics/core/style.css";

const playerHost = document.querySelector("#lyric-player");
if (!playerHost) throw new Error("missing #lyric-player");

function report(tag, data) {
    try {
        const text = "[JS] " + tag + ": " + String(data);
        if (window.chrome && window.chrome.webview) {
            window.chrome.webview.postMessage(text);
        } else {
            console.log(text);
        }
    } catch (e) { /* noop */ }
}

// ── 背景：优先 WebGL MeshGradient，失败降级为 CSS 模糊专辑图 ──
let background = null;   // WebGL 背景实例
let bgCover = null;      // CSS fallback 专辑图图层
let bgShade = null;      // CSS fallback 遮罩层
let bgMode = "none";

try {
    background = BackgroundRender.new(MeshGradientRenderer);
    playerHost.appendChild(background.getElement());
    // 应用渲染设置（官方推荐值；flowSpeed 默认 1 过快，0.2 更接近 Apple Music 观感）
    background.setFPS(60);
    background.setRenderScale(1);
    background.setFlowSpeed(0.2);
    // 初始静止，待 setPlaying(true) 时恢复动态，避免常驻期间空转
    background.setStaticMode(true);
    bgMode = "webgl";
    report("BG", "webgl mesh ok");
} catch (e) {
    bgMode = "css";
    report("BG_FALLBACK", (e && e.message) ? e.message : String(e));

    bgCover = document.createElement("div");
    bgCover.style.cssText = [
        "position:absolute", "inset:-80px", "z-index:0",
        "background-size:cover", "background-position:center",
        "filter:blur(70px) saturate(1.5) brightness(0.65)",
        "opacity:0", "transition:opacity 0.8s ease",
        "transform:scale(1)", "animation:bg-flow 24s ease-in-out infinite alternate",
        "animation-play-state:running",
    ].join(";");
    bgShade = document.createElement("div");
    bgShade.style.cssText = [
        "position:absolute", "inset:0", "z-index:0",
        "background:linear-gradient(180deg, rgba(0,0,0,0.30) 0%, rgba(0,0,0,0.55) 100%)",
    ].join(";");
    const styleEl = document.createElement("style");
    styleEl.textContent = "@keyframes bg-flow { from { transform: scale(1) translate(0,0); } to { transform: scale(1.1) translate(1.5%, -1.5%); } }";
    document.head.appendChild(styleEl);
    playerHost.appendChild(bgCover);
    playerHost.appendChild(bgShade);
    report("BG_FALLBACK_DOM", "css bg attached");
}

// ── 歌词组件 ──
let player = null;
try {
    player = new LyricPlayer();
    playerHost.appendChild(player.getElement());
    report("LYRIC", "ok");
} catch (e) {
    report("LYRIC_ERROR", (e && e.message) ? e.message : String(e));
}

let isPlaying = false;
let currentTime = 0;
let lastFrameTime = -1;

function onFrame(frameTime) {
    const delta = lastFrameTime === -1 ? 0 : frameTime - lastFrameTime;
    lastFrameTime = frameTime;
    if (isPlaying && player) {
        currentTime += delta;
        player.setCurrentTime(Math.round(currentTime));
    }
    if (player) player.update(delta);
    requestAnimationFrame(onFrame);
}
requestAnimationFrame(onFrame);

// ── 左侧清晰大封面 ──
const coverArtEl = document.querySelector("#cover-art");
if (!coverArtEl) throw new Error("missing #cover-art");
coverArtEl.addEventListener("error", () => { coverArtEl.style.visibility = "hidden"; });

// ── 暂无歌词提示 ──
const noLyricEl = document.querySelector("#no-lyric");
if (!noLyricEl) throw new Error("missing #no-lyric");

function showNoLyric(show) {
    noLyricEl.style.display = show ? "flex" : "none";
}

// ── WebGL 状态监听 ──
if (background) {
    const bgCanvas = background.getElement();
    bgCanvas.addEventListener("webglcontextlost", (e) => {
        e.preventDefault();
        report("WEBGL_LOST", "context lost");
    });
    bgCanvas.addEventListener("webglcontextrestored", () => report("WEBGL_RESTORED", ""));
}

// ── Flutter WebView 调用 API ──
window.setLyric = (ttmlString) => {
    if (!player) { report("LYRIC_SKIP", "player missing"); showNoLyric(true); return; }
    if (!ttmlString || ttmlString.trim().length === 0) {
        player.setLyricLines([], Math.round(currentTime));
        showNoLyric(true);
        if (background) background.setHasLyric(false);
        report("LYRIC_SET", "0 lines (empty)");
        return;
    }
    try {
        const parsed = parseTTML(ttmlString);
        player.setLyricLines(parsed.lines, Math.round(currentTime));
        showNoLyric(parsed.lines.length === 0);
        if (background) background.setHasLyric(parsed.lines.length > 0);
        report("LYRIC_SET", parsed.lines.length + " lines");
    } catch (e) {
        player.setLyricLines([], Math.round(currentTime));
        showNoLyric(true);
        if (background) background.setHasLyric(false);
        report("LYRIC_PARSE_ERR", (e && e.message) ? e.message : String(e));
    }
};

window.setCurrentTime = (timeMs) => {
    currentTime = timeMs;
    if (player) player.setCurrentTime(Math.round(timeMs), true);
};

window.setPlaying = (playing) => {
    isPlaying = playing;
    if (player) { playing ? player.resume() : player.pause(); }
    if (background) {
        if (playing) {
            background.setStaticMode(false);
            background.resume();
        } else {
            // 不彻底 pause: 用 static mode 保持渲染循环,
            // 封面/动画在渲染完当前帧后静止, 避免 canvas 冻结在初始黑帧
            background.setStaticMode(true);
            background.resume();
        }
    }
    if (bgCover) {
        bgCover.style.animationPlayState = playing ? "running" : "paused";
    }
    lastFrameTime = performance.now();
};

window.setCover = async (url) => {
    try {
        if (background) {
            await background.setAlbum(url);
            report("COVER_OK", "webgl album set");
        }
        if (bgCover) {
            const safeUrl = url.replace(/'/g, "\\'").replace(/\\/g, "\\\\");
            bgCover.style.backgroundImage = "url('" + safeUrl + "')";
            bgCover.style.opacity = "1";
            report("COVER_OK", "css bg set");
        }
        if (url) {
            coverArtEl.src = url;
            coverArtEl.style.visibility = "visible";
        } else {
            coverArtEl.style.visibility = "hidden";
        }
    } catch (e) {
        report("COVER_ERR", (e && e.message) ? e.message : String(e));
    }
};

window.setVolume = (vol) => {
    try {
        if (background) background.setLowFreqVolume(vol);
    } catch (e) { /* noop */ }
};

// ── 诊断：每步独立 try/catch，避免一次异常吞掉全部信息 ──
window.__diag = () => {
    const cs = document.querySelectorAll("canvas");
    report("DIAG canvas_count", cs.length);
    for (let i = 0; i < cs.length; i++) {
        try {
            const c = cs[i];
            report("DIAG canvas#" + i + " size", c.width + "x" + c.height + " css=" + (c.clientWidth || 0) + "x" + (c.clientHeight || 0));
            const gl = c.getContext("webgl") || c.getContext("webgl2");
            if (gl) {
                report("DIAG canvas#" + i + " webgl", String(gl.getParameter(gl.RENDERER)) + " lost=" + gl.isContextLost());
            } else {
                report("DIAG canvas#" + i + " webgl", "UNAVAILABLE");
            }
        } catch (e) {
            report("DIAG canvas#" + i + " ERR", (e && e.message) ? e.message : String(e));
        }
    }
    report("DIAG lyric_dom", document.querySelectorAll(".amll-lyric-player").length);
    report("DIAG bgMode", bgMode);
    report("DIAG lyricLines", player ? player.getLyricLines().length : "n/a");
    report("DIAG playing", isPlaying);
    report("DIAG time", Math.round(currentTime));
};

report("INIT", "done bgMode=" + bgMode + " lyric=" + (player ? "ok" : "fail"));
