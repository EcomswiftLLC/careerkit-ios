"""Builds the static CareerKit site into website/careerkit/.

  set CAREERKIT_SUPPORT_EMAIL=<the public support address>      (Windows cmd)
  $env:CAREERKIT_SUPPORT_EMAIL = "<the public support address>"  (PowerShell)
  python website/build_site.py

The support address is read from the environment so that it is set by a person and never hard coded in
this script. It is shown on the pages as selectable text (no mailto link, which is unreliable in many
mail setups and invites scraping). The same address is already printed in docs/legal/*.md.

Optional: CAREERKIT_SITE_OUT=<folder> writes the pages somewhere else (used for review builds).

Writes index.html, privacy/index.html, terms/index.html, support/index.html, sitemap.xml, robots.txt.
The privacy and terms pages are generated from docs/legal/*.md, so edit the Markdown and re-run this script.
The draft notice block in those files (between the DRAFT-NOTICE markers) is stripped from the web pages.
Assets (CSS, images) live in website/careerkit/assets (see website/make_site_assets.py).
Pure standard library.
"""
import html
import json
import os
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC_SITE = ROOT / "website" / "careerkit"
OUT = Path(os.environ.get("CAREERKIT_SITE_OUT") or SRC_SITE)
LEGAL = ROOT / "docs" / "legal"

BASE = "https://ecomswiftllc.github.io/careerkit/"
SUPPORT_EMAIL = os.environ.get("CAREERKIT_SUPPORT_EMAIL", "").strip()
UPDATED = "2026-11-16"
SITE_NAME = "Resume & CV Maker: CareerKit"

if not SUPPORT_EMAIL:
    sys.exit("Set CAREERKIT_SUPPORT_EMAIL to the public support address before building (see the top of this file).")


# ----------------------------------------------------------------------------- schematics
def _ln(x, y, w):
    return f'<rect class="ln" x="{x}" y="{y}" width="{w}" height="2.6" rx="1.3"/>'


def _hd(x, y, w=32):
    return f'<rect class="hd" x="{x}" y="{y}" width="{w}" height="3.4" rx="1.7"/>'


def _sections(x, y, w, n, gap=38, widths=(1, .9, .78)):
    out = []
    for i in range(n):
        yy = y + i * gap
        out.append(_hd(x, yy, min(34, w * .5)))
        for j, f in enumerate(widths):
            out.append(_ln(x, yy + 9 + j * 6, round(w * f, 1)))
    return "".join(out)


def schematic(kind, label):
    page = '<rect class="pg" x="1" y="1" width="148" height="198" rx="4"/>'
    if kind == "single":
        body = (page + '<rect class="nm" x="14" y="16" width="70" height="8" rx="2"/>' + _ln(14, 29, 44)
                + '<rect class="ac" x="14" y="40" width="122" height="1.6"/>' + _sections(14, 50, 122, 4))
    elif kind == "banner":
        band = '<path class="band" d="M5 1 H145 a4 4 0 0 1 4 4 V48 H1 V5 a4 4 0 0 1 4 -4 Z"/>'
        body = (page + band + '<rect class="ln-on" x="14" y="16" width="72" height="8" rx="2" opacity=".95"/>'
                + '<rect class="ln-on" x="14" y="30" width="46" height="3" rx="1.5"/>' + _sections(14, 62, 122, 3, gap=44))
    elif kind == "left":
        sb = '<path class="sb" d="M5 1 H54 V199 H5 a4 4 0 0 1 -4 -4 V5 a4 4 0 0 1 4 -4 Z"/>'
        side = ('<rect class="nm" x="10" y="16" width="34" height="7" rx="2"/>' + _ln(10, 29, 26)
                + _hd(10, 52, 24) + _ln(10, 61, 34) + _ln(10, 67, 28) + _ln(10, 73, 32)
                + _hd(10, 96, 24) + _ln(10, 105, 30) + _ln(10, 111, 34) + _ln(10, 117, 24))
        body = page + sb + side + _sections(66, 18, 70, 4, gap=45, widths=(1, .92, .8))
    elif kind == "right":
        sb = '<path class="sb" d="M96 1 H145 a4 4 0 0 1 4 4 V195 a4 4 0 0 1 -4 4 H96 Z"/>'
        side = ('<rect class="nm" x="104" y="16" width="34" height="7" rx="2"/>' + _ln(104, 29, 26)
                + _hd(104, 52, 24) + _ln(104, 61, 34) + _ln(104, 67, 28) + _ln(104, 73, 32)
                + _hd(104, 96, 24) + _ln(104, 105, 30) + _ln(104, 111, 34))
        body = page + sb + side + _sections(14, 18, 70, 4, gap=45, widths=(1, .92, .8))
    elif kind == "twocol":
        rail = '<rect class="sb" x="106" y="52" width="38" height="140" rx="2"/>'
        railc = _hd(112, 60, 22) + _ln(112, 69, 26) + _ln(112, 75, 22) + _hd(112, 96, 22) + _ln(112, 105, 26) + _ln(112, 111, 20)
        body = (page + '<rect class="nm" x="14" y="16" width="76" height="8" rx="2"/>' + _ln(14, 29, 44)
                + '<rect class="ac" x="14" y="40" width="130" height="1.6"/>' + rail + railc
                + _sections(14, 54, 84, 4, gap=34))
    else:
        raise ValueError(kind)
    return f'<svg viewBox="0 0 150 200" aria-hidden="true" focusable="false">{body}</svg>'


# ----------------------------------------------------------------------------- shell
def head(title, description, path, extra_head="", root=""):
    canonical = BASE + path
    t = html.escape(title)
    d = html.escape(description)
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{t}</title>
<meta name="description" content="{d}">
<link rel="canonical" href="{canonical}">
<meta name="theme-color" content="#FAF7F0" media="(prefers-color-scheme: light)">
<meta name="theme-color" content="#141614" media="(prefers-color-scheme: dark)">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="{root}assets/favicon.svg" type="image/svg+xml">
<link rel="icon" href="{root}assets/favicon-32.png" type="image/png" sizes="32x32">
<link rel="apple-touch-icon" href="{root}assets/apple-touch-icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="{html.escape(SITE_NAME)}">
<meta property="og:title" content="{t}">
<meta property="og:description" content="{d}">
<meta property="og:url" content="{canonical}">
<meta property="og:image" content="{BASE}assets/og-image.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:image:alt" content="The CareerKit app icon next to the name Resume & CV Maker: CareerKit">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="{t}">
<meta name="twitter:description" content="{d}">
<meta name="twitter:image" content="{BASE}assets/og-image.png">
<link rel="stylesheet" href="{root}assets/site.css">
{extra_head}</head>
<body>
<a class="skip" href="#main">Skip to content</a>
"""


def header(root, current=""):
    def a(href, text, key):
        cur = ' aria-current="page"' if key == current else ""
        return f'<a href="{href}"{cur}>{text}</a>'
    home = root or "./"
    return f"""<header class="site-header">
  <div class="wrap">
    <a class="brand" href="{home}"><img src="{root}assets/favicon.svg" alt="" width="30" height="30">CareerKit</a>
    <nav class="nav" aria-label="Main">
      {a(home + '#features', 'Features', 'f')}
      {a(home + '#templates', 'Templates', 't')}
      {a(home + '#free', 'Free with ads', 'a')}
      {a(home + '#faq', 'FAQ', 'q')}
      {a(root + 'support/', 'Support', 'support')}
    </nav>
  </div>
</header>
"""


def footer(root):
    home = root or "./"
    return f"""<footer class="site-footer">
  <div class="wrap">
    <div>
      <h2>Resume & CV Maker: CareerKit</h2>
      <p>A free resume and cover letter maker for iPhone and iPad. Coming soon to the App Store.</p>
    </div>
    <nav aria-label="Footer">
      <h2>Pages</h2>
      <ul>
        <li><a href="{home}">Home</a></li>
        <li><a href="{root}support/">Support</a></li>
        <li><a href="{root}privacy/">Privacy policy</a></li>
        <li><a href="{root}terms/">Terms of use</a></li>
      </ul>
    </nav>
    <div>
      <h2>Ecom Swift LLC</h2>
      <p>30 N Gould St #37906<br>Sheridan, WY 82801<br>United States</p>
      <p class="email">{html.escape(SUPPORT_EMAIL)}</p>
    </div>
    <p class="legalline">&copy; 2026 Ecom Swift LLC. Resume & CV Maker: CareerKit and its templates are not affiliated with Apple, Google or any employer. Apple and iPhone are trademarks of Apple Inc.</p>
  </div>
</footer>
</body>
</html>
"""


# ----------------------------------------------------------------------------- home
EMAIL_TEXT = f'<span class="email">{html.escape(SUPPORT_EMAIL)}</span>'

FAQ = [
    ("Is CareerKit really free?",
     "<p>Yes. There is no subscription, no in-app purchase and no paid version. Ads pay for the app: a banner on browse screens, and one rewarded video that you choose to watch when you export a finished document.</p>"),
    ("Why do I watch a video to export?",
     "<p>Exporting is the one step where the app asks for something in return. One completed video covers one export of that document, and if you do not finish exporting, the unlock stays for up to 24 hours. If no video can be shown, for example when you are offline or no ad is available, the app lets you export without one. Writing, editing, previewing, cover letters and the ATS check never need a video.</p>"),
    ("Do I need an account?",
     "<p>No. There is no sign-in and no sign-up.</p>"),
    ("Where are my documents stored?",
     "<p>On your device, in the app's own storage. We do not upload them and we cannot see them. A file you export (PDF, Word, Rich Text, plain text or web page) goes where you send it, such as the Files app or the share sheet. If you import an existing resume, the file is read on your device and is not uploaded.</p>"),
    ("Will an applicant tracking system accept my resume?",
     "<p>Nobody can promise that. Employers use many different systems and each one reads a resume in its own way. The ATS check in CareerKit flags common formatting problems and explains each finding, so use it as a checklist and not as a verdict.</p>"),
    ("Does it work offline?",
     "<p>Yes. Writing, editing, previewing and exporting work without a connection. Offline, no video can load, so the export sheet lets you export without one. Banner ads only appear when you are online.</p>"),
    ("What happens if I do not allow tracking?",
     "<p>The app works the same. The ads you see will be less personalised. You can change the choice any time in iOS Settings under Privacy and Security, then Tracking.</p>"),
    ("Which devices does it run on?",
     "<p>iPhone and iPad with iOS or iPadOS 17 or later.</p>"),
    ("How do I delete my data?",
     "<p>Open the Profile tab and choose Delete all local data. The app offers to save a backup file first. Deleting the app also removes its data. Files you already exported stay wherever you saved them.</p>"),
    ("When can I download it?",
     "<p>CareerKit is not released yet. This page will link to the App Store listing once the app is live.</p>"),
    ("Who makes CareerKit?",
     "<p>Ecom Swift LLC, a company registered in Wyoming, United States. You can reach us on the <a href=\"support/\">support page</a>.</p>"),
]


def jsonld_app():
    data = {
        "@context": "https://schema.org",
        "@type": "SoftwareApplication",
        "name": SITE_NAME,
        "alternateName": "CareerKit",
        "url": BASE,
        "applicationCategory": "BusinessApplication",
        "operatingSystem": "iOS 17.0 or later, iPadOS 17.0 or later",
        "description": "A free resume and cover letter maker for iPhone and iPad with 30 resume templates, 10 matching cover letter templates, an ATS check with general guidance, a job ad keyword check, resume import and export to PDF, Word, Rich Text, plain text and web page. Supported by ads. Documents stay on the device.",
        "image": BASE + "assets/icon-512.png",
        "offers": {"@type": "Offer", "price": "0", "priceCurrency": "USD"},
        "publisher": {"@type": "Organization", "name": "Ecom Swift LLC", "url": "https://www.ecomswiftllc.com/",
                      "address": {"@type": "PostalAddress", "streetAddress": "30 N Gould St #37906",
                                  "addressLocality": "Sheridan", "addressRegion": "WY", "postalCode": "82801",
                                  "addressCountry": "US"}},
        "featureList": [
            "30 resume templates",
            "Blank resume option",
            "10 cover letter templates",
            "ATS check with general guidance",
            "Several resumes in one place",
            "Export to PDF, Word, Rich Text, plain text and web page", "Import an existing resume from a PDF or pasted text", "Job ad keyword check",
            "Works without an account",
        ],
    }
    return '<script type="application/ld+json">\n' + json.dumps(data, indent=2) + "\n</script>\n"


def jsonld_faq():
    plain = lambda s: html.unescape(re.sub(r"<[^>]+>", "", s))
    data = {"@context": "https://schema.org", "@type": "FAQPage",
            "mainEntity": [{"@type": "Question", "name": q,
                            "acceptedAnswer": {"@type": "Answer", "text": plain(a)}} for q, a in FAQ]}
    return '<script type="application/ld+json">\n' + json.dumps(data, indent=2) + "\n</script>\n"


def build_index():
    title = "Resume & CV Maker: CareerKit | Free resume maker for iPhone and iPad"
    desc = "Free resume and cover letter maker for iPhone and iPad. 30 templates, general ATS guidance, job ad keyword check and export to PDF or Word. Your documents stay on your device. Coming soon."
    faq_html = "\n".join(
        f'        <details><summary>{html.escape(q)}</summary><div class="answer">{a}</div></details>' for q, a in FAQ)
    structures = [
        ("single", "Single column", "19 templates. One full-width column, the plainest structure and the easiest for software to read."),
        ("left", "Left sidebar", "4 templates. A narrow tinted column on the left for contact details and skills."),
        ("right", "Right sidebar", "3 templates. The same idea mirrored, with the main column reading first."),
        ("twocol", "Header, then two columns", "4 templates. A full-width header over a main column and a narrow right rail."),
    ]
    struct_html = "\n".join(
        f'          <li>{schematic(k, name + " page layout")}<p class="cap"><strong>{name}</strong>{note}</p></li>'
        for k, name, note in structures)

    body = head(title, desc, "", jsonld_app() + jsonld_faq(), root="") + header("", "") + f"""
<main id="main">
  <section class="hero" aria-labelledby="h1">
    <div class="wrap">
      <div>
        <img class="appicon" src="assets/icon-512.png" width="512" height="512" alt="CareerKit app icon: a folded page corner and a rising stroke forming the letter K, on forest green">
        <h1 id="h1">A resume and cover letter, finished on your phone.</h1>
        <p class="lede">CareerKit gives you 30 resume templates, 10 matching cover letter templates and export to PDF, Word and more. It is free, there is no account, and your documents stay on your device.</p>
        <p class="status">Coming soon to the App Store</p>
        <p class="small hero-note">The app has not been released yet, so there is no download link. Questions before launch are welcome on the <a href="support/">support page</a>.</p>
      </div>
      <figure class="layouts">
        <div class="row">
          <div>{schematic("single", "Single column page layout")}<p class="cap"><strong>Single column</strong>Plain and easy to scan</p></div>
          <div>{schematic("left", "Left sidebar page layout")}<p class="cap"><strong>Left sidebar</strong>Contact and skills set apart</p></div>
          <div>{schematic("banner", "Banner header page layout")}<p class="cap"><strong>Banner header</strong>A bold band for the name</p></div>
        </div>
        <figcaption>Three of the page structures in the app, drawn as simple diagrams. They are not screenshots.</figcaption>
      </figure>
    </div>
  </section>

  <section class="section" id="features" aria-labelledby="h-features">
    <div class="wrap">
      <h2 id="h-features">What you can do in CareerKit</h2>
      <div class="section-body">
        <dl class="defs">
          <div><dt>Start from 30 resume templates</dt><dd>Six groups: Professional, Modern, Creative, Academic, Entry Level and Technical. Each template is a complete design with its own layout, fonts and heading style.</dd></div>
          <div><dt>Or start from a blank page</dt><dd>Choose your own structure. Begin with a blank resume and add only the sections you need.</dd></div>
          <div><dt>Change every detail</dt><dd>Add, hide and reorder sections. Change the accent colour, fonts, text size, line spacing and margins. Add a photo when the kind of application you are making expects one.</dd></div>
          <div><dt>In your language</dt><dd>CareerKit is available in English, Spanish, French, German and Simplified Chinese. A resume can also be written in a different language from the app, and its headings and dates follow that language in every export.</dd></div>
          <div><dt>Cover letters that match</dt><dd>Ten cover letter templates share the design of a matching resume, so the two documents look like a set.</dd></div>
          <div><dt>Check the layout</dt><dd>The ATS check reads your resume and points out common formatting problems. It is general guidance and not a score from any employer system.</dd></div>
          <div><dt>Keep several resumes</dt><dd>Keep one version for each kind of job. Duplicate, rename or archive them from My Resumes, and compare two versions side by side. Pick A4 or US Letter.</dd></div>
          <div><dt>Export your way</dt><dd>Choose PDF, Word (.docx), Rich Text, plain text or a web page. Share it, save it to Files or print the PDF. The text in the PDF is selectable, and email, phone and web addresses are links.</dd></div>
        </dl>
      </div>
    </div>
  </section>

  <section class="section templates-wide" id="templates" aria-labelledby="h-templates">
    <div class="wrap">
      <h2 id="h-templates">30 templates on four page structures</h2>
      <div class="section-body">
        <p>Templates differ in more than colour. Each one sets its own header, heading style, date layout, bullet style and fonts. Underneath, every template uses one of four page structures.</p>
        <ul class="structures">
{struct_html}
        </ul>
        <dl class="facts">
          <dt>Groups</dt><dd>Professional (6), Modern (6), Creative (5), Technical (5), Academic (4) and Entry Level (4).</dd>
          <dt>Career stage</dt><dd>Student, Entry level, Mid career, Senior and Executive.</dd>
          <dt>Fields</dt><dd>General, Business and Finance, Technology, Design and Marketing, Academia and Research, Education, Healthcare.</dd>
          <dt>Fonts</dt><dd>Sixteen fonts that already ship with iOS, so nothing is downloaded: SF Pro, New York, Helvetica Neue, Avenir Next, Georgia, Palatino, Baskerville, Hoefler Text, Charter, Iowan Old Style, Gill Sans, Optima, Cochin, Didot, Futura and Menlo.</dd>
          <dt>Plain by design</dt><dd>Some templates leave out sidebars, photos and decoration on purpose, because simple layouts are usually easier for software to read.</dd>
        </dl>
      </div>
    </div>
  </section>

  <section class="section" id="ats" aria-labelledby="h-ats">
    <div class="wrap">
      <h2 id="h-ats">An ATS check that shows what it looked at</h2>
      <div class="section-body">
        <p>Many employers use an applicant tracking system, or ATS, to store and search applications. Systems differ a lot, and nobody outside them can promise how a resume will be read. CareerKit checks the things that commonly cause trouble and explains each finding.</p>
        <ul class="checks">
          <li>Standard section headings</li>
          <li>Email and phone details that look valid</li>
          <li>Dates on every job</li>
          <li>A summary at the top</li>
          <li>Whether the text can be read back out of the PDF</li>
          <li>Sidebars and multi-column layouts</li>
          <li>A photo on the page</li>
          <li>Unusual symbols</li>
          <li>Length</li>
        </ul>
        <p class="disclaimer">Treat the result as a checklist. It does not score your resume, it cannot predict any employer's system, and a clean result is not a promise of anything.</p>
      </div>
    </div>
  </section>

  <section class="section" id="free" aria-labelledby="h-free">
    <div class="wrap">
      <h2 id="h-free">Free, and paid for by ads</h2>
      <div class="section-body">
        <p>CareerKit has no subscription, no in-app purchase and no paid tier. Ads from Google AdMob pay for it, and they appear in two places only.</p>
        <div class="split">
          <div>
            <h3>Where you will see ads</h3>
            <ul>
              <li>A banner on browse screens: Home, My Resumes, Templates, Cover Letters and Profile.</li>
              <li>One short rewarded video that you choose to watch before you export a finished document. One video covers one export of that document.</li>
            </ul>
          </div>
          <div>
            <h3>Where you will not</h3>
            <ul>
              <li>In the editor or the preview.</li>
              <li>While you create, edit or preview a document, write a cover letter or run the ATS check.</li>
              <li>As a full-screen ad that pops up, or when you open the app.</li>
            </ul>
          </div>
        </div>
        <p>Where the law asks for it, the app shows a consent form before personalised ads, and iOS may ask whether the app may track you. You can say no to the iOS tracking prompt and still use everything. If you decline a consent form that applies in your region, ads may not load, and the export sheet lets you export without a video. You can change that choice later in the Profile tab. The <a href="privacy/">privacy policy</a> explains what the ad network collects.</p>
      </div>
    </div>
  </section>

  <section class="section" id="private" aria-labelledby="h-private">
    <div class="wrap">
      <h2 id="h-private">Your documents stay on your device</h2>
      <div class="section-body">
        <p>CareerKit has no account and no server that stores your resumes. What you write is saved on your device and is not uploaded. The only outside service is the ad network. There is no AI service behind the app, so your work is never sent to one.</p>
        <p>You can delete everything from the Profile tab whenever you like. The app can save a backup file first.</p>
      </div>
    </div>
  </section>

  <section class="section faq" id="faq" aria-labelledby="h-faq">
    <div class="wrap">
      <h2 id="h-faq">Questions</h2>
      <div class="section-body">
{faq_html}
      </div>
    </div>
  </section>
</main>
""" + footer("")
    (OUT / "index.html").write_text(body, encoding="utf-8")


# ----------------------------------------------------------------------------- support
def build_support():
    title = "Support | Resume & CV Maker: CareerKit"
    desc = "Get help with CareerKit: contact details, what to include in a message, and answers to common questions about exports, ads and your data."
    items = [
        ("The export sheet says no video is available",
         "<p>Tap Export without video to finish that export. Ad availability changes by country and by time of day, and no video can load while you are offline or when your ad privacy choice does not allow ads. You can also tap Try the video again.</p>"),
        ("I closed the video early and nothing was exported",
         "<p>A video unlocks the export only when it has played to the end. Tap Watch again on the export sheet to start another one.</p>"),
        ("I saw an ad that seems wrong",
         "<p>Open the Profile tab and tap Report an ad, or write to us at the address above. Tell us roughly when and where in the app you saw it and what it showed. A screenshot helps. We block ad categories and advertisers through Google AdMob where we can.</p>"),
        ("I want to change my ad or tracking choice",
         "<p>Open the Profile tab and look for the Ad privacy choices row, which appears where the law requires it. You can also change tracking in iOS Settings under Privacy and Security, then Tracking, and reset your advertising identifier there.</p>"),
        ("I deleted the app and my resumes are gone",
         "<p>Documents are stored only on your device, so deleting the app deletes them, and we cannot recover them. Keep an exported copy of anything important. A full backup of your device may still contain the app's data if you made one before deleting it.</p>"),
        ("How do I delete all of my data?",
         "<p>Open the Profile tab and choose Delete all local data. We hold no personal data about your use of the app, so there is nothing to delete on our side.</p>"),
        ("Something looks wrong in a template or an exported file",
         "<p>Tell us the template name, the page size you chose (A4 or US Letter), what you expected and what you got. A screenshot of the problem helps. Please do not send a full resume with real personal details unless we ask for it.</p>"),
        ("I have an idea for a template or a feature",
         "<p>Send it. We read every message, though we cannot promise to build every idea.</p>"),
    ]
    faq_html = "\n".join(f'          <details><summary>{html.escape(q)}</summary><div class="answer">{a}</div></details>' for q, a in items)
    body = head(title, desc, "support/", root="../") + header("../", "support") + f"""
<main id="main">
  <div class="page">
    <div class="wrap">
      <div class="doc">
        <h1>Support</h1>
        <p class="lede">Write to us and a person will read it.</p>
        <p class="contact-line">{EMAIL_TEXT}</p>
        <p class="small">Select the address to copy it into your mail app.</p>
        <p>We reply by email. A message gets answered faster when it includes:</p>
        <ul>
          <li>your iPhone or iPad model and iOS version</li>
          <li>what you were doing and what happened</li>
          <li>the template name, if it is about a template</li>
          <li>a screenshot, if it helps</li>
        </ul>
        <p>CareerKit is not released yet, so support right now covers questions about the app before launch.</p>
        <h2>Common questions</h2>
        <div class="faq">
{faq_html}
        </div>
        <h2>Company</h2>
        <p>Ecom Swift LLC<br>30 N Gould St #37906<br>Sheridan, WY 82801<br>United States</p>
        <p>Read the <a href="../privacy/">privacy policy</a> and the <a href="../terms/">terms of use</a>.</p>
      </div>
    </div>
  </div>
</main>
""" + footer("../")
    (OUT / "support").mkdir(exist_ok=True)
    (OUT / "support" / "index.html").write_text(body, encoding="utf-8")


# ----------------------------------------------------------------------------- legal (markdown -> html)
URL_RE = re.compile(r"(https?://[^\s<)]+)")
MAIL_RE = re.compile(r"([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})")


def inline(text):
    t = html.escape(text, quote=False)
    t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)

    def url(m):
        u = m.group(1)
        trail = ""
        while u and u[-1] in ".,;":
            trail = u[-1] + trail
            u = u[:-1]
        return f'<a href="{u}" rel="noopener">{u}</a>{trail}'

    t = URL_RE.sub(url, t)
    # email addresses stay as selectable text (no mailto link)
    parts = re.split(r"(<a .*?</a>)", t)
    parts = [p if p.startswith("<a ") else MAIL_RE.sub(r'<span class="email">\1</span>', p) for p in parts]
    return "".join(parts)


def md_to_html(md):
    md = re.sub(r"<!-- DRAFT-NOTICE-START -->.*?<!-- DRAFT-NOTICE-END -->", "", md, flags=re.S)
    out, para, items = [], [], []
    title = ""
    meta_open = False
    seen_h2 = False

    def flush_para():
        nonlocal para
        if para:
            out.append("<p>" + "<br>".join(inline(p) for p in para) + "</p>")
            para = []

    def flush_list():
        nonlocal items
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items = []

    for raw in md.splitlines():
        line = raw.rstrip()
        if line.startswith("# "):
            flush_para(); flush_list()
            title = line[2:].strip()
            out.append(f"<h1>{html.escape(title)}</h1>")
        elif line.startswith("## "):
            flush_para(); flush_list()
            if meta_open:
                out.append("</div>"); meta_open = False
            seen_h2 = True
            out.append(f"<h2>{inline(line[3:].strip())}</h2>")
        elif line.startswith("- "):
            flush_para()
            items.append(line[2:].strip())
        elif not line.strip():
            flush_para(); flush_list()
        elif line.startswith("**") and title and not seen_h2:
            if not meta_open:
                out.append('<div class="meta">'); meta_open = True
            out.append("<p>" + inline(line) + "</p>")
        else:
            flush_list()
            if meta_open:
                out.append("</div>"); meta_open = False
            para.append(line.strip())
    flush_para(); flush_list()
    if meta_open:
        out.append("</div>")
    return title, "\n".join(out)


def build_legal(src, folder, current_title, desc):
    md = (LEGAL / src).read_text(encoding="utf-8")
    title, content = md_to_html(md)
    page_title = f"{current_title} | {SITE_NAME}"
    body = head(page_title, desc, folder + "/", root="../") + header("../", "") + f"""
<main id="main">
  <div class="page">
    <div class="wrap">
      <article class="doc">
{content}
      </article>
    </div>
  </div>
</main>
""" + footer("../")
    (OUT / folder).mkdir(exist_ok=True)
    (OUT / folder / "index.html").write_text(body, encoding="utf-8")


def build_misc():
    urls = ["", "support/", "privacy/", "terms/"]
    xml = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for u in urls:
        xml.append(f"  <url><loc>{BASE}{u}</loc><lastmod>{UPDATED}</lastmod></url>")
    xml.append("</urlset>")
    (OUT / "sitemap.xml").write_text("\n".join(xml) + "\n", encoding="utf-8")
    (OUT / "robots.txt").write_text(
        "# Hosted on GitHub Pages as a project site under /careerkit/.\n"
        "User-agent: *\nAllow: /\n\n"
        f"Sitemap: {BASE}sitemap.xml\n", encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if OUT != SRC_SITE:  # review build elsewhere: bring the assets along
        shutil.copytree(SRC_SITE / "assets", OUT / "assets", dirs_exist_ok=True)
    build_index()
    build_support()
    build_legal("privacy-policy.md", "privacy", "Privacy Policy",
                "How Resume & CV Maker: CareerKit handles information: documents stay on your device, there is no account, and ads come from Google AdMob with your consent where required.")
    build_legal("terms-of-use.md", "terms", "Terms of Use",
                "The terms for using Resume & CV Maker: CareerKit, a free resume and cover letter app supported by ads.")
    build_misc()
    print("site built in", OUT)


if __name__ == "__main__":
    main()
