# Canonical and Sitemap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one correct self-referencing canonical to every public HTML page, generate a matching sitemap and robots file, normalize internal index links, and align IIS redirects with the canonical URL scheme.

**Architecture:** A Ruby maintenance module discovers the explicit public source tree, derives canonical URLs from file paths, synchronizes HTML metadata and internal index links, and deterministically generates `sitemap.xml` and `robots.txt`. Existing IIS inventory and generator code gain canonical path and host/scheme rules while keeping `/s/` outside this website's canonicalization.

**Tech Stack:** Ruby 2.6 standard library (`pathname`, `rexml`, `minitest`, `yaml`), static HTML, IIS 10.0 URL Rewrite, XML sitemap.

**Spec:** `docs/superpowers/specs/2026-08-31-canonical-sitemap-design.md`

## Global Constraints

- Canonical origin is exactly `https://www.gracelife.com.tw`.
- `index.html`, `taichung/index.html`, and `zhushan/index.html` canonicalize to `/`, `/taichung/`, and `/zhushan/`.
- Every other public HTML page keeps its `.html` path.
- Public HTML scope is exactly 127 source pages: seven root pages plus all HTML under `cases/`, `knowledge/`, `services/`, `taichung/`, and `zhushan/`.
- Exclude `element.html`, `.vercel/`, `.worktrees/`, `docs/`, and `test/fixtures/` from public canonical and sitemap output.
- `element.html` gets one `noindex, nofollow` robots meta and no canonical.
- Do not modify knowledge article components, `know-*` classes, CSS, JavaScript, previews, or example code.
- `sitemap.xml` contains exactly the 127 canonical URLs and omits unreliable `lastmod` values.
- `/s/` is an independent appointment application and must not match newly added IIS host, scheme, or canonical path rules.
- Do not overwrite a server-only production `web.config`; deployment must merge the generated `<rewrite>` section when necessary.
- Preserve unrelated untracked image and video files.

## File Structure

- Create `scripts/sync_seo_metadata.rb`: public-page discovery, canonical derivation, idempotent HTML metadata/link synchronization, sitemap and robots rendering, and `--write`/`--check` CLI.
- Create `test/seo_metadata_test.rb`: tests real source HTML, generated XML/text, canonical path derivation, link normalization, and idempotence.
- Modify 127 public HTML files: add canonical and normalize index links.
- Modify `element.html`: add `noindex, nofollow` only.
- Create `sitemap.xml`: generated canonical URL list.
- Create `robots.txt`: generated sitemap declaration.
- Modify `config/iis_legacy_urls.yml`: add canonical path redirects and change two legacy destinations to directory canonicals.
- Modify `scripts/generate_iis_redirect_config.rb`: render host/scheme and canonical path rules before legacy rules.
- Modify `test/iis_redirect_test.rb`: verify rule order, canonical paths, canonical legacy destinations, and `/s/` exclusion.
- Regenerate `web.config`.

---

### Task 1: Define public pages and canonical URL derivation

**Files:**
- Create: `test/seo_metadata_test.rb`
- Create: `scripts/sync_seo_metadata.rb`

**Interfaces:**
- Produces: `SeoMetadata.public_html_paths(root) -> Array<String>` using project-relative slash-separated paths.
- Produces: `SeoMetadata.canonical_url(path) -> String`.
- Consumes: no earlier task output.

- [ ] **Step 1: Write failing discovery and canonical tests**

Create `test/seo_metadata_test.rb`:

```ruby
require 'minitest/autorun'
require_relative '../scripts/sync_seo_metadata'

class SeoMetadataTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def public_paths
    @public_paths ||= SeoMetadata.public_html_paths(ROOT)
  end

  def test_public_page_inventory_is_complete_and_excludes_internal_files
    assert_equal 127, public_paths.length
    assert_includes public_paths, 'index.html'
    assert_includes public_paths, 'knowledge/know_20150222.html'
    assert_includes public_paths, 'services/implant.html'
    refute_includes public_paths, 'element.html'
    refute public_paths.any? { |path| path.start_with?('.vercel/', 'docs/', 'test/') }
  end

  def test_canonical_url_follows_the_approved_path_scheme
    assert_equal 'https://www.gracelife.com.tw/', SeoMetadata.canonical_url('index.html')
    assert_equal 'https://www.gracelife.com.tw/taichung/', SeoMetadata.canonical_url('taichung/index.html')
    assert_equal 'https://www.gracelife.com.tw/zhushan/', SeoMetadata.canonical_url('zhushan/index.html')
    assert_equal 'https://www.gracelife.com.tw/services/implant.html',
                 SeoMetadata.canonical_url('services/implant.html')
    assert_equal 'https://www.gracelife.com.tw/cases/index.html',
                 SeoMetadata.canonical_url('cases/index.html')
  end

  def test_canonical_url_rejects_non_public_paths
    assert_raises(ArgumentError) { SeoMetadata.canonical_url('element.html') }
    assert_raises(ArgumentError) { SeoMetadata.canonical_url('docs/plan.html') }
    assert_raises(ArgumentError) { SeoMetadata.canonical_url('services/implant') }
  end
end
```

- [ ] **Step 2: Run the test and verify the missing module failure**

Run: `ruby test/seo_metadata_test.rb`

Expected: ERROR with `LoadError` for `scripts/sync_seo_metadata.rb`.

- [ ] **Step 3: Implement discovery and canonical derivation**

Create `scripts/sync_seo_metadata.rb` with these constants and methods:

```ruby
require 'pathname'

module SeoMetadata
  ORIGIN = 'https://www.gracelife.com.tw'.freeze
  ROOT_PAGES = %w[
    appointment.html
    idea.html
    index.html
    knowledge.html
    news.html
    offday.html
    videos.html
  ].freeze
  PUBLIC_DIRECTORIES = %w[cases knowledge services taichung zhushan].freeze

  module_function

  def public_html_paths(root)
    directory_pages = PUBLIC_DIRECTORIES.flat_map do |directory|
      Dir.glob(File.join(root, directory, '**', '*.html')).map do |absolute_path|
        Pathname.new(absolute_path).relative_path_from(Pathname.new(root)).to_s
      end
    end
    (ROOT_PAGES + directory_pages).sort
  end

  def canonical_url(path)
    segments = path.split('/')
    public_path = !segments.any? { |segment| segment == '.' || segment == '..' } &&
                  (ROOT_PAGES.include?(path) || PUBLIC_DIRECTORIES.any? do |directory|
                    path.match?(%r{\A#{Regexp.escape(directory)}/.+\.html\z})
                  end)
    raise ArgumentError, "not a public HTML path: #{path}" unless public_path

    canonical_path = case path
                     when 'index.html' then '/'
                     when 'taichung/index.html' then '/taichung/'
                     when 'zhushan/index.html' then '/zhushan/'
                     else "/#{path}"
    end
    "#{ORIGIN}#{canonical_path}"
  end
end
```

- [ ] **Step 4: Run the test and verify it passes**

Run: `ruby test/seo_metadata_test.rb`

Expected: 3 runs, all assertions pass.

- [ ] **Step 5: Commit the canonical URL model**

```bash
git add scripts/sync_seo_metadata.rb test/seo_metadata_test.rb
git commit -m "test: define public canonical URL model"
```

---

### Task 2: Synchronize HTML metadata, sitemap, and robots

**Files:**
- Modify: `scripts/sync_seo_metadata.rb`
- Modify: `test/seo_metadata_test.rb`
- Modify: all 127 public HTML files
- Modify: `element.html`
- Create: `sitemap.xml`
- Create: `robots.txt`

**Interfaces:**
- Produces: `SeoMetadata.sync_canonical(html, canonical_url) -> String`.
- Produces: `SeoMetadata.sync_element_robots(html) -> String`.
- Produces: `SeoMetadata.render_sitemap(urls) -> String`.
- Produces: `SeoMetadata.render_robots -> String`.
- Produces: `SeoMetadata.sync(root, write:) -> Array<String>` changed project-relative paths.
- Produces: CLI `ruby scripts/sync_seo_metadata.rb --write` and `--check`.

- [ ] **Step 1: Add failing tests for metadata and generated files**

Add `rexml` requires and the following tests to `test/seo_metadata_test.rb`:

```ruby
require 'rexml/document'
require 'rexml/xpath'

def canonical_hrefs(path)
  File.read(File.join(ROOT, path)).scan(
    /<link\b(?=[^>]*\brel=["']canonical["'])(?=[^>]*\bhref=["']([^"']+)["'])[^>]*>/i
  ).flatten
end

def test_every_public_page_has_one_self_referencing_canonical
  public_paths.each do |path|
    assert_equal [SeoMetadata.canonical_url(path)], canonical_hrefs(path), path
  end
end

def test_element_is_noindex_and_has_no_canonical
  html = File.read(File.join(ROOT, 'element.html'))
  assert_empty html.scan(/<link\b[^>]*\brel=["']canonical["'][^>]*>/i)
  assert_equal 1, html.scan(/<meta\b(?=[^>]*\bname=["']robots["'])(?=[^>]*\bcontent=["']noindex, nofollow["'])[^>]*>/i).length
end

def test_sitemap_exactly_matches_public_canonicals
  document = REXML::Document.new(File.read(File.join(ROOT, 'sitemap.xml')))
  namespaces = { 'sitemap' => 'http://www.sitemaps.org/schemas/sitemap/0.9' }
  urls = REXML::XPath.match(document, '//sitemap:loc', namespaces).map(&:text)
  expected = public_paths.map { |path| SeoMetadata.canonical_url(path) }.sort
  assert_equal expected, urls.sort
  assert_equal 127, urls.uniq.length
  assert_empty REXML::XPath.match(document, '//sitemap:lastmod', namespaces)
end

def test_robots_declares_the_canonical_sitemap
  assert_equal "User-agent: *\nAllow: /\n\nSitemap: https://www.gracelife.com.tw/sitemap.xml\n",
               File.read(File.join(ROOT, 'robots.txt'))
end
```

- [ ] **Step 2: Run tests and verify metadata/generated-file failures**

Run: `ruby test/seo_metadata_test.rb`

Expected: FAIL because canonical tags, `sitemap.xml`, and `robots.txt` do not exist.

- [ ] **Step 3: Implement idempotent metadata and generated-file rendering**

Extend `scripts/sync_seo_metadata.rb`:

```ruby
require 'cgi'

CANONICAL_TAG = /<link\b[^>]*\brel=["']canonical["'][^>]*>\s*/i
ROBOTS_TAG = /<meta\b[^>]*\bname=["']robots["'][^>]*>\s*/i

def sync_canonical(html, canonical_url)
  raise 'HTML is missing </head>' unless html.match?(%r{</head>}i)
  raise 'HTML has duplicate canonical tags' if html.scan(CANONICAL_TAG).length > 1

  tag = %(  <link rel="canonical" href="#{CGI.escapeHTML(canonical_url)}">\n)
  if html.match?(CANONICAL_TAG)
    html.sub(CANONICAL_TAG, tag)
  else
    html.sub(%r{</head>}i, "#{tag}</head>")
  end
end

def sync_element_robots(html)
  raise 'element.html is missing </head>' unless html.match?(%r{</head>}i)
  raise 'element.html has duplicate robots tags' if html.scan(ROBOTS_TAG).length > 1

  html = html.gsub(CANONICAL_TAG, '')
  tag = %(  <meta name="robots" content="noindex, nofollow">\n)
  if html.match?(ROBOTS_TAG)
    html.sub(ROBOTS_TAG, tag)
  else
    html.sub(%r{</head>}i, "#{tag}</head>")
  end
end

def render_sitemap(urls)
  entries = urls.sort.map { |url| "  <url><loc>#{CGI.escapeHTML(url)}</loc></url>" }
  <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{entries.join("\n")}
    </urlset>
  XML
end

def render_robots
  "User-agent: *\nAllow: /\n\nSitemap: #{ORIGIN}/sitemap.xml\n"
end

def sync(root, write:)
  desired = {}

  public_html_paths(root).each do |relative_path|
    absolute_path = File.join(root, relative_path)
    desired[relative_path] = sync_canonical(
      File.read(absolute_path),
      canonical_url(relative_path)
    )
  end

  desired['element.html'] = sync_element_robots(File.read(File.join(root, 'element.html')))
  urls = public_html_paths(root).map { |path| canonical_url(path) }
  desired['sitemap.xml'] = render_sitemap(urls)
  desired['robots.txt'] = render_robots

  changed = desired.each_with_object([]) do |(relative_path, content), paths|
    absolute_path = File.join(root, relative_path)
    current = File.exist?(absolute_path) ? File.read(absolute_path) : nil
    next if current == content

    File.write(absolute_path, content) if write
    paths << relative_path
  end

  changed.sort
end
```

Add CLI behavior after the module's closing `end`:

```ruby
if $PROGRAM_NAME == __FILE__
  root = File.expand_path('..', __dir__)
  mode = ARGV.fetch(0, '--check')
  abort 'usage: --write or --check' unless %w[--write --check].include?(mode)
  changed = SeoMetadata.sync(root, write: mode == '--write')
  if mode == '--check' && !changed.empty?
    warn "SEO files need synchronization: #{changed.join(', ')}"
    exit 1
  end
end
```

- [ ] **Step 4: Run the synchronizer and verify metadata tests pass**

Run: `ruby scripts/sync_seo_metadata.rb --write`

Run: `ruby test/seo_metadata_test.rb`

Expected: all discovery, canonical, element, sitemap, and robots tests pass.

- [ ] **Step 5: Verify idempotence and XML validity**

Run: `ruby scripts/sync_seo_metadata.rb --check`

Run: `xmllint --noout sitemap.xml`

Expected: both commands exit 0 with no output.

- [ ] **Step 6: Commit metadata and generated files**

```bash
git add scripts/sync_seo_metadata.rb test/seo_metadata_test.rb element.html sitemap.xml robots.txt \
  appointment.html idea.html index.html knowledge.html news.html offday.html videos.html \
  cases knowledge services taichung zhushan
git commit -m "feat: add canonical metadata and sitemap"
```

---

### Task 3: Normalize internal index links

**Files:**
- Modify: `scripts/sync_seo_metadata.rb`
- Modify: `test/seo_metadata_test.rb`
- Modify: public HTML files containing index-page links

**Interfaces:**
- Produces: `SeoMetadata.normalize_index_links(html, document_path) -> String`.
- Extends: `SeoMetadata.sync(root, write:)` to normalize links before canonical synchronization.

- [ ] **Step 1: Add failing link-resolution tests**

Add helpers and tests:

```ruby
require 'pathname'

INDEX_DOCUMENTS = %w[index.html taichung/index.html zhushan/index.html].freeze

def resolved_internal_href(document_path, href)
  path = href.split(/[?#]/, 2).first
  return path.delete_prefix('/') if path.start_with?('/')

  Pathname.new(File.dirname(document_path)).join(path).cleanpath.to_s
end

def test_public_pages_do_not_link_to_index_documents
  public_paths.each do |document_path|
    html = File.read(File.join(ROOT, document_path))
    hrefs = html.scan(/\bhref=["']([^"']+)["']/i).flatten
    duplicate_links = hrefs.select do |href|
      next false if href.match?(%r{\A(?:[a-z][a-z0-9+.-]*:|//|#)}i)
      INDEX_DOCUMENTS.include?(resolved_internal_href(document_path, href))
    end
    assert_empty duplicate_links, "#{document_path}: #{duplicate_links.join(', ')}"
  end
end

def test_index_link_normalization_preserves_query_and_fragment
  html = '<a href="../taichung/index.html?src=nav#team">Clinic</a>'
  expected = '<a href="../taichung/?src=nav#team">Clinic</a>'
  assert_equal expected, SeoMetadata.normalize_index_links(html, 'services/implant.html')
end

def test_index_link_normalization_keeps_root_relative_style
  html = '<a href="/zhushan/index.html#team">Clinic</a>'
  expected = '<a href="/zhushan/#team">Clinic</a>'
  assert_equal expected, SeoMetadata.normalize_index_links(html, 'services/implant.html')
end
```

- [ ] **Step 2: Run tests and verify existing index links fail**

Run: `ruby test/seo_metadata_test.rb`

Expected: FAIL listing public pages that still link to one of the three `index.html` documents.

- [ ] **Step 3: Implement HTML href normalization**

Add these constants and the exact normalization method inside `SeoMetadata`:

```ruby
INDEX_TARGET_DIRECTORIES = {
  'index.html' => '.',
  'taichung/index.html' => 'taichung',
  'zhushan/index.html' => 'zhushan'
}.freeze
HREF_ATTRIBUTE = /(\bhref=)(["'])([^"']+)\2/i
NON_LOCAL_HREF = %r{\A(?:[a-z][a-z0-9+.-]*:|//|#)}i

def normalize_index_links(html, document_path)
  document_directory = Pathname.new(File.dirname(document_path))

  html.gsub(HREF_ATTRIBUTE) do |attribute|
    prefix, quote, href = Regexp.last_match.captures
    next attribute if href.match?(NON_LOCAL_HREF)

    path, suffix = href.split(/(?=[?#])/, 2)
    root_relative = path.start_with?('/')
    resolved = if root_relative
                 path.delete_prefix('/')
               else
                 document_directory.join(path).cleanpath.to_s
               end
    target_directory = INDEX_TARGET_DIRECTORIES[resolved]
    next attribute unless target_directory

    normalized_path = if root_relative
                        target_directory == '.' ? '/' : "/#{target_directory}/"
                      else
                        relative = Pathname.new(target_directory)
                                           .relative_path_from(document_directory).to_s
                        relative == '.' ? './' : "#{relative}/"
                      end
    "#{prefix}#{quote}#{normalized_path}#{suffix}#{quote}"
  end
end
```

In `sync`, replace the public-page assignment with this sequence so link normalization runs before canonical synchronization:

```ruby
html = File.read(absolute_path)
html = normalize_index_links(html, relative_path)
desired[relative_path] = sync_canonical(html, canonical_url(relative_path))
```

- [ ] **Step 4: Synchronize and verify normalized links**

Run: `ruby scripts/sync_seo_metadata.rb --write`

Run: `ruby test/seo_metadata_test.rb`

Expected: all tests pass; no public page resolves a local href to an `index.html` duplicate.

- [ ] **Step 5: Verify idempotence**

Run: `ruby scripts/sync_seo_metadata.rb --check`

Expected: exit 0 with no output.

- [ ] **Step 6: Commit link normalization**

```bash
git add scripts/sync_seo_metadata.rb test/seo_metadata_test.rb \
  appointment.html idea.html index.html knowledge.html news.html offday.html videos.html \
  cases knowledge services taichung zhushan
git commit -m "fix: link directly to canonical index URLs"
```

---

### Task 4: Align IIS redirects with canonical URLs

**Files:**
- Modify: `config/iis_legacy_urls.yml`
- Modify: `scripts/generate_iis_redirect_config.rb`
- Modify: `test/iis_redirect_test.rb`
- Regenerate: `web.config`

**Interfaces:**
- Adds inventory key: `canonical_redirects -> Hash<String, String>` for four new path sources; `/index.html` remains in existing fixed redirects.
- Adds generator methods: `IisRedirectConfig.render_host_rule -> String` and `IisRedirectConfig.render_redirect_rules(name_prefix, redirects) -> Array<String>`.
- Preserves: `IisRedirectConfig.expanded_redirects(inventory) -> Hash<String, String>` with 100 audited legacy outcomes.

- [ ] **Step 1: Add failing canonical redirect and host-rule tests**

Extend `test/iis_redirect_test.rb` with separate rule selectors by name prefix and these assertions:

```ruby
def named_rules(prefix)
  all_rules.select { |rule| rule.attributes['name'].start_with?(prefix) }
end

def test_canonical_path_redirects_are_exact_and_permanent
  expected = {
    '/index.html' => '/',
    '/taichung' => '/taichung/',
    '/taichung/index.html' => '/taichung/',
    '/zhushan' => '/zhushan/',
    '/zhushan/index.html' => '/zhushan/'
  }
  rules = named_rules('Canonical path') + named_rules('Legacy 301')
  expected.each do |source, destination|
    matches = matching_rules(source, rules)
    assert_equal 1, matches.length, source
    action = REXML::XPath.first(matches.first, 'action')
    assert_equal destination, action.attributes['url'], source
    assert_equal 'Permanent', action.attributes['redirectType'], source
  end
end

def test_host_rule_forces_https_www_but_excludes_appointment_app
  rule = named_rules('Canonical host').fetch(0)
  pattern = REXML::XPath.first(rule, 'match').attributes['url']
  assert Regexp.new(pattern, Regexp::IGNORECASE).match?('services/implant.html')
  refute Regexp.new(pattern, Regexp::IGNORECASE).match?('s/app/calendar.aspx')
  action = REXML::XPath.first(rule, 'action')
  assert_equal 'https://www.gracelife.com.tw/{R:1}', action.attributes['url']
  assert_equal 'Permanent', action.attributes['redirectType']
  assert_equal 'true', action.attributes['appendQueryString']
end

def test_legacy_clinic_redirects_go_directly_to_directory_canonicals
  assert_equal '/taichung/', expanded_redirects.fetch('/about-tc.html')
  assert_equal '/zhushan/', expanded_redirects.fetch('/about-js.html')
end

def test_rule_order_is_host_then_path_then_legacy_then_gone
  names = all_rules.map { |rule| rule.attributes['name'] }
  assert_operator names.index { |name| name.start_with?('Canonical host') }, :<,
                  names.index { |name| name.start_with?('Canonical path') }
  assert_operator names.index { |name| name.start_with?('Canonical path') }, :<,
                  names.index { |name| name.start_with?('Legacy 301') }
  assert_operator names.index { |name| name.start_with?('Legacy 301') }, :<,
                  names.index { |name| name.start_with?('Legacy 410') }
end
```

Update existing selectors so the 100-rule legacy assertions examine only `Legacy 301` rules and do not count the host or canonical-path rules.

- [ ] **Step 2: Run tests and verify missing canonical rules fail**

Run: `ruby test/iis_redirect_test.rb`

Expected: FAIL because `canonical_redirects` and `Canonical host/path` rules do not exist and two legacy destinations still contain `index.html`.

- [ ] **Step 3: Update inventory and generator**

In `config/iis_legacy_urls.yml`:

```yaml
canonical_redirects:
  /taichung: /taichung/
  /taichung/index.html: /taichung/
  /zhushan: /zhushan/
  /zhushan/index.html: /zhushan/
```

Change:

```yaml
/about-tc.html: /taichung/
/about-js.html: /zhushan/
```

Render one host rule before all path rules:

```xml
<rule name="Canonical host and scheme" stopProcessing="true">
  <match url="^(?!s(?:/|$))(.*)$" ignoreCase="true" />
  <conditions logicalGrouping="MatchAny">
    <add input="{HTTPS}" pattern="^OFF$" ignoreCase="true" />
    <add input="{HTTP_HOST}" pattern="^www\.gracelife\.com\.tw$" negate="true" ignoreCase="true" />
  </conditions>
  <action type="Redirect" url="https://www.gracelife.com.tw/{R:1}" redirectType="Permanent" appendQueryString="true" />
</rule>
```

Render the four `canonical_redirects` as exact `Canonical path NNN` rules after the host rule, followed by the existing 100 `Legacy 301` and 34 `Legacy 410` rules. Continue escaping sources with `Regexp.escape` and HTML attribute values with `CGI.escapeHTML`.

- [ ] **Step 4: Regenerate and verify IIS tests**

Run: `ruby scripts/generate_iis_redirect_config.rb --write`

Run: `ruby test/iis_redirect_test.rb`

Expected: all IIS tests pass; 100 legacy redirects, four additional canonical path redirects, one host/scheme rule, 34 Gone rules, and no `/s/` match.

- [ ] **Step 5: Validate generated XML and freshness**

Run: `xmllint --noout web.config`

Run: `ruby scripts/generate_iis_redirect_config.rb | diff -u web.config -`

Expected: both commands exit 0 with no output.

- [ ] **Step 6: Commit canonical IIS routing**

```bash
git add config/iis_legacy_urls.yml scripts/generate_iis_redirect_config.rb test/iis_redirect_test.rb web.config
git commit -m "feat: align IIS redirects with canonical URLs"
```

---

### Task 5: Run full verification and prepare deployment handoff

**Files:**
- Verify all files changed by Tasks 1–4.
- Do not modify unrelated user image/video files.

**Interfaces:**
- Consumes: canonical HTML, sitemap, robots, link synchronization, and IIS artifacts.
- Produces: fresh verification evidence and an IIS/Search Console deployment checklist.

- [ ] **Step 1: Run every Ruby test**

```bash
for test_file in test/*_test.rb; do
  ruby "$test_file" || exit 1
done
```

Expected: every test file exits 0 with no failures or errors.

- [ ] **Step 2: Run both deterministic generators in check mode**

```bash
ruby scripts/sync_seo_metadata.rb --check
ruby scripts/generate_iis_redirect_config.rb | diff -u web.config -
```

Expected: both commands exit 0 with no output.

- [ ] **Step 3: Validate XML and Git formatting**

```bash
xmllint --noout sitemap.xml web.config
git diff --check
```

Expected: exit 0 with no output.

- [ ] **Step 4: Inspect scope and counts**

```bash
git status --short --branch
git diff --stat main...HEAD
```

Confirm the implementation changes only SEO metadata, canonical index hrefs, the two generated root files, SEO/IIS scripts and tests, IIS inventory, and generated `web.config`. Confirm unrelated image/video paths remain untracked and untouched.

- [ ] **Step 5: Include production-only checks in the handoff**

The final handoff must state:

- Confirm IIS URL Rewrite is installed and merge `<rewrite>` into any server-only `web.config`.
- Do not delete or upload over `/s/`.
- Verify 301 and one-hop `Location` for HTTP, non-www, `/index.html`, `/taichung`, `/taichung/index.html`, `/zhushan`, and `/zhushan/index.html`.
- Verify `/`, `/taichung/`, `/zhushan/`, `/sitemap.xml`, and `/robots.txt` return 200.
- Verify `/s/app/calendar.aspx` still works.
- Submit `https://www.gracelife.com.tw/sitemap.xml` in Google Search Console after deployment.
