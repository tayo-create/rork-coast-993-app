// Minimal station-side console for announcing contest keywords.
export const adminPage = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Coast 99.3 · Station Console</title>
<style>
  :root { --bg:#050A1A; --surface:#0E1730; --raised:#14214A; --border:#1E3A8A; --orange:#FF7A1A; --blue:#1F6BFF; --muted:#9AA7C7; }
  * { box-sizing: border-box; }
  body { margin:0; min-height:100vh; font:16px/1.45 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color:#fff;
    background: radial-gradient(ellipse at 50% 0%, rgba(31,107,255,.25), transparent 60%), radial-gradient(ellipse at 100% 100%, rgba(255,122,26,.12), transparent 50%), var(--bg); }
  main { max-width:560px; margin:0 auto; padding:40px 20px 60px; }
  h1 { font-size:32px; letter-spacing:.5px; margin:0 0 4px; text-transform:uppercase; }
  h1 span { color:var(--orange); }
  p.sub { color:var(--muted); margin:0 0 28px; }
  .card { background:linear-gradient(var(--raised), var(--surface)); border:1px solid rgba(31,107,255,.45); border-radius:22px; padding:22px; margin-bottom:18px; }
  label { display:block; font-size:13px; font-weight:700; letter-spacing:1.2px; text-transform:uppercase; color:var(--orange); margin:14px 0 6px; }
  input, textarea, select { width:100%; background:#0A1226; color:#fff; border:1px solid var(--border); border-radius:12px; padding:12px 14px; font:inherit; }
  input.keyword { font-size:28px; font-weight:800; letter-spacing:2px; text-transform:uppercase; }
  textarea { min-height:70px; resize:vertical; }
  button { width:100%; margin-top:20px; border:0; border-radius:999px; padding:16px; font-size:18px; font-weight:800; letter-spacing:1px; text-transform:uppercase; color:#fff; cursor:pointer;
    background:linear-gradient(#FF9A3D,#FF7A1A,#F25C05); box-shadow:0 8px 24px rgba(255,122,26,.4); }
  button:disabled { opacity:.5; cursor:wait; }
  .stats { display:flex; gap:12px; }
  .stat { flex:1; background:#0A1226; border:1px solid var(--border); border-radius:14px; padding:12px; text-align:center; }
  .stat b { display:block; font-size:26px; }
  .stat small { color:var(--muted); }
  .msg { margin-top:14px; padding:12px 14px; border-radius:12px; display:none; }
  .msg.ok { display:block; background:rgba(31,107,255,.15); border:1px solid var(--blue); }
  .msg.err { display:block; background:rgba(232,50,43,.15); border:1px solid #E8322B; }
  ul { list-style:none; padding:0; margin:0; }
  li { display:flex; justify-content:space-between; padding:10px 0; border-bottom:1px solid rgba(30,58,138,.5); }
  li:last-child { border-bottom:0; }
  li span { color:var(--muted); font-size:14px; }
  .warn { color:#FFB35C; font-size:14px; margin-top:10px; display:none; }
  table { width:100%; border-collapse:collapse; font-size:14px; }
  th { text-align:left; color:var(--muted); font-weight:600; font-size:12px; letter-spacing:.8px; text-transform:uppercase; padding:6px 4px; }
  td { padding:10px 4px; border-top:1px solid rgba(30,58,138,.5); vertical-align:top; }
  td.num { text-align:right; font-variant-numeric:tabular-nums; }
  td small { color:var(--muted); display:block; }
</style>
</head>
<body>
<main>
  <h1>Coast <span>99.3</span></h1>
  <p class="sub">Keyword Alerts &amp; past Music Test results.</p>

  <div class="card">
    <label for="key">Admin key</label>
    <input id="key" type="password" placeholder="COAST_ADMIN_KEY" autocomplete="current-password" />
    <div class="stats" style="margin-top:16px">
      <div class="stat"><b id="sDevices">–</b><small>devices</small></div>
      <div class="stat"><b id="sAlerts">–</b><small>alerts on</small></div>
      <div class="stat"><b id="sTakers">–</b><small>test takers</small></div>
    </div>
    <div class="warn" id="apnsWarn">Apple push credentials are not configured yet — keywords will be saved and shown in the app, but no push will be sent.</div>
  </div>

  <form class="card" id="form">
    <label for="keyword">Keyword</label>
    <input id="keyword" class="keyword" required maxlength="40" placeholder="SAVANNAH" />
    <label for="contest">Contest</label>
    <select id="contest">
      <option value="coast-cash-keyword|Coast Cash Keyword">Coast Cash Keyword</option>
      <option value="new-years-eve-vegas-flyaway|NYE Vegas Flyaway">NYE Vegas Flyaway</option>
    </select>
    <label for="message">Message (optional)</label>
    <textarea id="message" maxlength="180" placeholder="The keyword is SAVANNAH. Enter it now for your shot at $1,000!"></textarea>
    <button id="send" type="submit">Send Keyword Alert</button>
    <div class="msg" id="result"></div>
  </form>

  <div class="card">
    <label style="margin-top:0">Recent keywords</label>
    <ul id="recent"><li><span>Enter your admin key to load.</span></li></ul>
  </div>

  <div class="card">
    <label style="margin-top:0">Music Test results (archived, closed to new answers)</label>
    <table>
      <thead><tr><th>Song</th><th style="text-align:right">Score</th><th style="text-align:right">Like</th><th style="text-align:right">More</th></tr></thead>
      <tbody id="music"><tr><td colspan="4"><small>Enter your admin key to load.</small></td></tr></tbody>
    </table>
  </div>
</main>
<script>
  const $ = (id) => document.getElementById(id);
  $("key").value = localStorage.getItem("coastAdminKey") || "";
  const headers = () => ({ "Content-Type": "application/json", "X-Admin-Key": $("key").value.trim() });
  const esc = (s) => String(s ?? "").replace(/[&<>"]/g, (c) => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;" })[c]);

  async function loadStats() {
    if (!$("key").value.trim()) return;
    localStorage.setItem("coastAdminKey", $("key").value.trim());
    const res = await fetch("admin/stats", { headers: headers() });
    const data = await res.json();
    if (!res.ok) { $("recent").innerHTML = "<li><span>" + esc(data.error) + "</span></li>"; return; }
    $("sDevices").textContent = data.devices.total;
    $("sAlerts").textContent = data.devices.alerts;
    $("sTakers").textContent = data.devices.testTakers;
    $("apnsWarn").style.display = data.apnsConfigured ? "none" : "block";
    $("recent").innerHTML = data.keywords.length ? data.keywords.map((k) =>
      "<li><b>" + esc(k.keyword) + "</b><span>" + new Date(k.createdAt).toLocaleString() + " · " + k.delivered + " sent</span></li>").join("")
      : "<li><span>No keywords yet.</span></li>";
    loadMusicTest();
  }

  async function loadMusicTest() {
    const res = await fetch("admin/music-test", { headers: headers() });
    const data = await res.json();
    if (!res.ok) return;
    $("music").innerHTML = data.songs.length ? data.songs.map((s) =>
      "<tr><td><b>" + esc(s.title) + "</b><small>" + esc(s.artist) + " · " + s.votes + " votes · " + s.familiarPct + "% know it</small></td>" +
      "<td class='num'>" + s.score.toFixed(1) + "</td><td class='num'>" + s.positivePct + "%</td><td class='num'>" + s.playMorePct + "%</td></tr>").join("")
      : "<tr><td colspan='4'><small>No Music Test answers yet.</small></td></tr>";
  }

  $("key").addEventListener("change", loadStats);
  $("form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const [contestSlug, contestTitle] = $("contest").value.split("|");
    $("send").disabled = true;
    const box = $("result");
    box.className = "msg";
    try {
      const res = await fetch("admin/announce", { method: "POST", headers: headers(), body: JSON.stringify({
        keyword: $("keyword").value, contestSlug, contestTitle, message: $("message").value }) });
      const data = await res.json();
      if (!res.ok || !data.ok) throw new Error(data.error || "Failed to send");
      box.className = "msg ok";
      box.textContent = data.apnsConfigured
        ? "Sent " + data.keyword + " to " + data.delivered + " device(s)" + (data.failed ? " · " + data.failed + " failed" : "") + "."
        : "Saved " + data.keyword + ". Push is not configured yet, so it only shows in the app.";
      $("keyword").value = ""; $("message").value = "";
      loadStats();
    } catch (err) {
      box.className = "msg err";
      box.textContent = err.message;
    } finally {
      $("send").disabled = false;
    }
  });
  loadStats();
</script>
</body>
</html>`;
