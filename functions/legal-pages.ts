// Public legal + support pages for the Coast 99.3 iOS app (linked from App Store Connect and in-app).

const UPDATED = "October 1, 2026";

function shell(title: string, body: string): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${title} · Coast 99.3 App</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; background: #050A1A; color: #E6EBF7; font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 720px; margin: 0 auto; padding: 40px 20px 64px; }
  h1 { font-size: 34px; line-height: 1.15; margin: 0 0 6px; letter-spacing: -0.5px; }
  h1 span { color: #FF7A1A; }
  h2 { font-size: 19px; margin: 32px 0 8px; color: #fff; }
  p, li { color: #B7C1DB; }
  ul { padding-left: 20px; }
  a { color: #FF9A4D; }
  .sub { color: #7F8BAA; margin: 0 0 28px; font-size: 14px; }
  .card { background: #0E1730; border: 1px solid #1C2A55; border-radius: 16px; padding: 18px 20px; margin: 18px 0; }
  .btn { display: inline-block; background: #FF7A1A; color: #050A1A; font-weight: 700; text-decoration: none; padding: 12px 20px; border-radius: 999px; margin-top: 6px; }
  footer { margin-top: 40px; font-size: 13px; color: #7F8BAA; }
  footer a { color: #7F8BAA; }
</style>
</head>
<body>
<main>
${body}
<footer><a href="privacy">Privacy Policy</a> · <a href="support">Support</a> · <a href="https://coast993.com">coast993.com</a></footer>
</main>
</body>
</html>`;
}

export const privacyPage = shell(
  "Privacy Policy",
  `<h1>Coast <span>99.3</span> App Privacy Policy</h1>
<p class="sub">Last updated ${UPDATED}</p>

<p>This policy explains what the Coast 99.3 iPhone app ("the app") does with your information. The short version: the app has no accounts, never asks for your name, email or phone number, shows no ads, and does not track you.</p>

<h2>Information the app does not collect</h2>
<ul>
  <li>No name, email address, phone number or other contact details.</li>
  <li>No location data.</li>
  <li>No contacts, photos, microphone or camera access.</li>
  <li>No advertising identifiers, analytics SDKs or third-party tracking.</li>
</ul>

<h2>Keyword alert notifications</h2>
<p>If you allow notifications, Apple gives the app a push notification token for your device. The app sends that token, your on/off preference for keyword alerts, and whether it is a test or App Store build to our server so we can send you contest keyword alerts. The token is not linked to your identity and is used only to deliver these notifications.</p>
<p>You can stop alerts at any time with the Keyword alerts switch in the app's Station tab, or in iOS Settings &gt; Notifications &gt; Coast 99.3. Tokens that Apple reports as no longer valid (for example after you delete the app) are deleted from our server automatically.</p>

<h2>Listening and song information</h2>
<ul>
  <li>The live stream and the now-playing / recently-played song list are delivered by our streaming provider (AzuraCast hosting at asurahosting.com). Like any internet audio stream, the provider receives your IP address and basic connection details while you listen.</li>
  <li>To show album artwork, the app looks up the artist and song title on Apple's public iTunes Search service. Only the song details are sent, never anything about you.</li>
</ul>

<h2>Data stored on your phone</h2>
<p>The app stores a few settings on your device, such as your keyword alert preference. They stay on your phone and are removed when you delete the app.</p>

<h2>Links to other sites</h2>
<p>The app can open coast993.com and the station's Instagram page. Those sites have their own privacy practices.</p>

<h2>Earlier versions</h2>
<p>A test version of the app included an optional Music Test. Answers were anonymous song ratings stored with a random ID and no personal information. The feature has been removed and no new answers are collected.</p>

<h2>Children</h2>
<p>The app is not directed to children under 13 and does not knowingly collect personal information from them.</p>

<h2>Your choices and contact</h2>
<p>Because the app does not collect personal information, there is no account to delete. To ask a privacy question or request removal of your device's notification token, contact the station through <a href="https://coast993.com/contact">coast993.com/contact</a>.</p>

<h2>Changes</h2>
<p>If this policy changes, the updated version will be posted on this page with a new date.</p>`,
);

export const supportPage = shell(
  "Support",
  `<h1>Coast <span>99.3</span> App Support</h1>
<p class="sub">Savannah's Hip Hop, R&amp;B and Throwbacks</p>

<div class="card">
  <p style="margin-top:0"><b style="color:#fff">Need help or have feedback?</b><br/>Reach the station team directly. We usually reply within a few business days.</p>
  <a class="btn" href="https://coast993.com/contact">Contact Coast 99.3</a>
</div>

<h2>The stream won't play</h2>
<ul>
  <li>Check that you're connected to Wi-Fi or cellular data.</li>
  <li>Tap pause, then play again. The app reconnects automatically after a dropped connection.</li>
  <li>Make sure your phone isn't muted and the volume is up. Audio keeps playing in the background and on the Lock Screen.</li>
</ul>

<h2>I'm not getting keyword alerts</h2>
<ul>
  <li>Open the Station tab and make sure Keyword alerts is turned on.</li>
  <li>In iOS Settings &gt; Notifications &gt; Coast 99.3, make sure Allow Notifications is on.</li>
  <li>Focus modes can silence notifications. Check your Focus settings.</li>
</ul>

<h2>Song info or artwork looks wrong</h2>
<p>Now-playing details come straight from the studio. Artwork is matched automatically, so the occasional mismatch can happen. Let us know through the contact page.</p>

<h2>Privacy</h2>
<p>The app has no accounts and collects no personal information. Read the full <a href="privacy">privacy policy</a>.</p>

<p>Follow the station on <a href="https://www.instagram.com/coast993sav">Instagram @coast993sav</a>.</p>`,
);
