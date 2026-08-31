# IIS URL Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate and verify an IIS `web.config` that maps the current gracelife.com.tw URLs to the replacement site with 100 exact HTTP 301 redirects, 34 exact HTTP 410 responses, and two unchanged HTTP 200 paths.

**Architecture:** Keep the audited URL inventory in a small YAML data file, render deterministic IIS URL Rewrite XML with a Ruby maintenance script, and commit the generated `web.config`. A Ruby test suite independently parses both the inventory and generated XML, verifies destination files, rejects redirect chains and duplicate matches, and enforces the 100/34/2 coverage contract.

**Tech Stack:** Ruby 2.6 standard library (`yaml`, `cgi`, `rexml`, `minitest`), IIS 10.0 URL Rewrite, XML `web.config`.

**Spec:** `docs/superpowers/specs/2026-08-31-iis-url-migration-design.md`

## Global Constraints

- The production host is the existing Microsoft IIS 10.0 server for `https://www.gracelife.com.tw/`; Vercel is not part of production routing.
- Use server-side HTTP 301 only when the old page has an equivalent or consolidated replacement.
- Return HTTP 410 for removed news and magazine pages that have no equivalent replacement.
- Never blanket-redirect removed or unknown URLs to the home page.
- Each redirect must go directly to its final destination and preserve the original query string.
- Do not restore `vercel.json`.
- Do not change reusable knowledge HTML structures, `know-*` classes, knowledge CSS, or knowledge JavaScript; `element.html` therefore does not require synchronization.
- Do not claim IIS-level behavior until the generated file has been tested on a server with the IIS URL Rewrite module installed.
- If production already has a server-only `web.config`, merge the generated `<rewrite>` section into that file after backing it up; never overwrite unrelated IIS or ASP.NET settings blindly.

## File Structure

- Create `config/iis_legacy_urls.yml`: audited source of truth for fixed redirects, same-date knowledge redirects, renamed knowledge redirects, gone URLs, and unchanged URLs.
- Create `scripts/generate_iis_redirect_config.rb`: deterministic renderer from the inventory to IIS XML; `--write` writes root `web.config`, otherwise it prints XML to stdout.
- Create `web.config`: generated deployment artifact consumed by IIS URL Rewrite.
- Create `test/iis_redirect_test.rb`: independent inventory, XML, destination, chain, and coverage checks.

---

### Task 1: Add the audited legacy URL inventory

**Files:**
- Create: `config/iis_legacy_urls.yml`
- Create: `test/iis_redirect_test.rb`

**Interfaces:**
- Produces: YAML keys `fixed_redirects`, `same_date_knowledge`, `renamed_knowledge`, `gone`, and `unchanged`.
- Produces: `IisRedirectTest#inventory`, returning the parsed YAML hash.
- Consumes: no earlier task output.

- [ ] **Step 1: Write the failing inventory test**

Create `test/iis_redirect_test.rb` with the following initial content:

```ruby
require 'minitest/autorun'
require 'yaml'

class IisRedirectTest < Minitest::Test
  INVENTORY_PATH = File.expand_path('../config/iis_legacy_urls.yml', __dir__)

  def inventory
    @inventory ||= YAML.safe_load(File.read(INVENTORY_PATH))
  end

  def expanded_redirects
    same_date = inventory.fetch('same_date_knowledge').to_h do |date|
      ["/know_#{date}.html", "/knowledge/know_#{date}.html"]
    end
    inventory.fetch('fixed_redirects').merge(same_date).merge(inventory.fetch('renamed_knowledge'))
  end

  def test_inventory_has_complete_audited_counts
    assert_equal 100, expanded_redirects.length
    assert_equal 34, inventory.fetch('gone').length
    assert_equal ['/', '/idea.html'], inventory.fetch('unchanged')
    assert_empty expanded_redirects.keys & inventory.fetch('gone')
    assert_empty expanded_redirects.keys & inventory.fetch('unchanged')
  end
end
```

- [ ] **Step 2: Run the test and verify the missing inventory failure**

Run: `ruby test/iis_redirect_test.rb`

Expected: ERROR with `Errno::ENOENT` for `config/iis_legacy_urls.yml`.

- [ ] **Step 3: Add the complete inventory**

Create `config/iis_legacy_urls.yml` with this exact data:

```yaml
fixed_redirects:
  /index.html: /
  /about-tc.html: /taichung/index.html
  /about-tc-dr.html: /taichung/team.html
  /about-tc-eq.html: /taichung/medical-equipment.html
  /about-js.html: /zhushan/index.html
  /about-js-dr.html: /zhushan/team.html
  /about-js-eq.html: /zhushan/medical-equipment.html
  /about_news.html: /news.html
  /about_news_offday.html: /offday.html
  /about_news_appointment.html: /offday.html
  /online-reservation.html: /appointment.html
  /contact.html: /appointment.html
  /ao4/index.html: /services/all-on-4.html
  /bestimplant.html: /services/implant.html
  /invisalign.html: /services/invisalign.html
  /service00.html: /
  /service01.html: /services/implant.html
  /service02.html: /services/all-ceramic-crown.html
  /service03.html: /services/orthodontics.html
  /service04.html: /services/teeth-whitening.html
  /service05.html: /services/microscope-root-canal.html
  /service06.html: /services/periodontal-treatment.html
  /case-aesthetics.html: /cases/aesthetic-dentistry.html
  /case-ao4.html: /cases/all-on-4.html
  /case-crown.html: /cases/all-ceramic-crown.html
  /case-implant.html: /cases/digital-implant.html
  /case-ortho.html: /cases/orthodontics.html
  /know.html: /knowledge.html

same_date_knowledge:
  - '20150222'
  - '20150223'
  - '20150224'
  - '20150225'
  - '20150226'
  - '20150227'
  - '20150424'
  - '20170314'
  - '20170705'
  - '20170717'
  - '20170718'
  - '20170814'
  - '20170816'
  - '20170829'
  - '20170908'
  - '20171020'
  - '20171127'
  - '20171207'
  - '20171212'
  - '20180112'
  - '20180126'
  - '20180208'
  - '20180316'
  - '20180319'
  - '20180320'
  - '20180530'
  - '20180604'
  - '20180611'
  - '20180704'
  - '20180711'
  - '20180731'
  - '20180920'
  - '20181204'
  - '20181218'
  - '20190506'
  - '20190613'
  - '20190702'
  - '20190918'
  - '20191003'
  - '20191226'
  - '20191227'
  - '20200414'
  - '20200709'
  - '20200908'
  - '20201027'
  - '20210317'
  - '20210611'
  - '20211001'
  - '20211201'
  - '20220428'
  - '20221019'
  - '20221020'
  - '20230706'
  - '20231031'
  - '20240104'
  - '20250206'
  - '20250212'
  - '20250313'
  - '20250514'
  - '20250723'
  - '20250815'
  - '20260319'
  - '20260506'

renamed_knowledge:
  /know_20170912.html: /knowledge/20240912-root-coverage-surgery.html
  /know_20170913.html: /services/teeth-whitening.html
  /know_20200204.html: /knowledge/20200204-zirkonzahn-zirconia-crown.html
  /know_20231115.html: /knowledge/20231115-isq-implant-stability.html
  /know_20250821.html: /knowledge/20260626-front-tooth-gap-treatment.html
  /know_20250827.html: /knowledge/20250827-guided-vs-freehand-implant.html
  /know_20260225.html: /knowledge/20260225-air-polishing-whitening.html
  /know_20260305.html: /knowledge/20260305-tooth-wear-restoration.html
  /know_20260409.html: /knowledge/20260624-microscope-root-canal-guide.html

gone:
  - /about_news_20160106.html
  - /about_news_20160122.html
  - /about_news_20160224.html
  - /about_news_20160324.html
  - /about_news_20160426.html
  - /about_news_20160520.html
  - /about_news_20160824.html
  - /about_news_20161208.html
  - /about_news_20170807.html
  - /about_news_20180410.html
  - /about_news_20190814.html
  - /about_news_20200130.html
  - /about_news_20201216.html
  - /about_news_20220323.html
  - /about_news_20221103.html
  - /about_news_20230630.html
  - /about_news_20240626.html
  - /about_news_20250423.html
  - /about_news_20250603.html
  - /about_news_anti.html
  - /magazine.html
  - /magazine/1/index.html
  - /magazine/2/index.html
  - /magazine/3/index.html
  - /magazine/4/index.html
  - /magazine/5/index.html
  - /magazine/6/index.html
  - /magazine/7/index.html
  - /magazine/8/index.html
  - /magazine/9/index.html
  - /magazine/10/index.html
  - /magazine/11/index.html
  - /magazine/12/index.html
  - /magazine/13/index.html

unchanged:
  - /
  - /idea.html
```

- [ ] **Step 4: Run the inventory test and verify it passes**

Run: `ruby test/iis_redirect_test.rb`

Expected: 1 run, 7 assertions, 0 failures, 0 errors.

- [ ] **Step 5: Commit the inventory contract**

```bash
git add config/iis_legacy_urls.yml test/iis_redirect_test.rb
git commit -m "test: define IIS legacy URL inventory"
```

---

### Task 2: Generate and verify the 100 permanent redirects

**Files:**
- Create: `scripts/generate_iis_redirect_config.rb`
- Create: `web.config`
- Modify: `test/iis_redirect_test.rb`

**Interfaces:**
- Consumes: `config/iis_legacy_urls.yml` keys defined in Task 1.
- Produces: `IisRedirectConfig.load_inventory(path) -> Hash`.
- Produces: `IisRedirectConfig.expanded_redirects(inventory) -> Hash<String, String>`.
- Produces: `IisRedirectConfig.render(inventory) -> String`.
- Produces: CLI `ruby scripts/generate_iis_redirect_config.rb --write`, which writes root `web.config`.

- [ ] **Step 1: Add failing tests for redirect generation and destination validity**

Add the three `require` lines at the top of `test/iis_redirect_test.rb`. Add the constants and helper methods shown below inside `IisRedirectTest`, before its final `end`:

```ruby
require 'rexml/document'
require 'rexml/xpath'
require_relative '../scripts/generate_iis_redirect_config'

WEB_CONFIG_PATH = File.expand_path('../web.config', __dir__)
PROJECT_ROOT = File.expand_path('..', __dir__)

def redirect_rules
  document = REXML::Document.new(File.read(WEB_CONFIG_PATH))
  REXML::XPath.match(document, '//system.webServer/rewrite/rules/rule').select do |rule|
    REXML::XPath.first(rule, 'action').attributes['type'] == 'Redirect'
  end
end

def matching_rules(path, rules)
  relative_path = path.delete_prefix('/')
  rules.select do |rule|
    pattern = REXML::XPath.first(rule, 'match').attributes['url']
    Regexp.new(pattern, Regexp::IGNORECASE).match?(relative_path)
  end
end
```

Add these test methods inside `IisRedirectTest`:

```ruby
def test_generated_web_config_is_current
  assert_equal IisRedirectConfig.render(inventory), File.read(WEB_CONFIG_PATH)
end

def test_each_audited_redirect_has_one_permanent_direct_rule
  assert_equal 100, redirect_rules.length

  expanded_redirects.each do |source, destination|
    rules = matching_rules(source, redirect_rules)
    assert_equal 1, rules.length, source
    action = REXML::XPath.first(rules.first, 'action')
    assert_equal destination, action.attributes['url'], source
    assert_equal 'Permanent', action.attributes['redirectType'], source
    assert_equal 'true', action.attributes['appendQueryString'], source
  end
end

def test_redirect_destinations_exist_and_do_not_chain
  expanded_redirects.each do |source, destination|
    destination_file = destination == '/' ? 'index.html' : destination.delete_prefix('/')
    assert File.file?(File.join(PROJECT_ROOT, destination_file)), "missing target for #{source}: #{destination}"
    refute expanded_redirects.key?(destination), "redirect chain: #{source} -> #{destination}"
  end
end
```

- [ ] **Step 2: Run the redirect tests and verify the missing generator failure**

Run: `ruby test/iis_redirect_test.rb`

Expected: ERROR with `LoadError` for `scripts/generate_iis_redirect_config.rb`.

- [ ] **Step 3: Implement the redirect-only generator**

Create `scripts/generate_iis_redirect_config.rb`:

```ruby
require 'cgi'
require 'yaml'

module IisRedirectConfig
  module_function

  def load_inventory(path)
    YAML.safe_load(File.read(path))
  end

  def expanded_redirects(inventory)
    same_date = inventory.fetch('same_date_knowledge').to_h do |date|
      ["/know_#{date}.html", "/knowledge/know_#{date}.html"]
    end
    inventory.fetch('fixed_redirects').merge(same_date).merge(inventory.fetch('renamed_knowledge'))
  end

  def render(inventory)
    rules = expanded_redirects(inventory).sort.map.with_index(1) do |(source, destination), index|
      <<~XML.chomp
              <rule name="Legacy 301 #{format('%03d', index)}" stopProcessing="true">
                <match url="^#{CGI.escapeHTML(Regexp.escape(source.delete_prefix('/')))}$" ignoreCase="true" />
                <action type="Redirect" url="#{CGI.escapeHTML(destination)}" redirectType="Permanent" appendQueryString="true" />
              </rule>
      XML
    end

    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <configuration>
        <system.webServer>
          <rewrite>
            <rules>
      #{rules.join("\n")}
            </rules>
          </rewrite>
        </system.webServer>
      </configuration>
    XML
  end
end

if $PROGRAM_NAME == __FILE__
  root = File.expand_path('..', __dir__)
  inventory = IisRedirectConfig.load_inventory(File.join(root, 'config/iis_legacy_urls.yml'))
  output = IisRedirectConfig.render(inventory)
  if ARGV == ['--write']
    File.write(File.join(root, 'web.config'), output)
  else
    print output
  end
end
```

- [ ] **Step 4: Generate `web.config` and run the redirect tests**

Run: `ruby scripts/generate_iis_redirect_config.rb --write`

Run: `ruby test/iis_redirect_test.rb`

Expected: all inventory and 301 tests pass. No 410 behavior is asserted yet.

- [ ] **Step 5: Validate the generated XML independently**

Run: `xmllint --noout web.config`

Expected: exit 0 with no output.

- [ ] **Step 6: Commit the redirect generator and generated config**

```bash
git add scripts/generate_iis_redirect_config.rb test/iis_redirect_test.rb web.config
git commit -m "feat: add IIS legacy redirects"
```

---

### Task 3: Add and verify the 34 Gone responses

**Files:**
- Modify: `scripts/generate_iis_redirect_config.rb`
- Modify: `test/iis_redirect_test.rb`
- Regenerate: `web.config`

**Interfaces:**
- Consumes: `inventory.fetch('gone') -> Array<String>` from Task 1.
- Extends: `IisRedirectConfig.render(inventory) -> String` with exact 410 rules after all 301 rules.

- [ ] **Step 1: Add failing tests for 410 rules and unchanged paths**

Add this helper to `test/iis_redirect_test.rb`:

```ruby
def all_rules
  document = REXML::Document.new(File.read(WEB_CONFIG_PATH))
  REXML::XPath.match(document, '//system.webServer/rewrite/rules/rule')
end
```

Replace `redirect_rules` with:

```ruby
def redirect_rules
  all_rules.select { |rule| REXML::XPath.first(rule, 'action').attributes['type'] == 'Redirect' }
end
```

Add these test methods:

```ruby
def test_each_removed_url_has_one_gone_rule
  gone_rules = all_rules.select do |rule|
    action = REXML::XPath.first(rule, 'action')
    action.attributes['type'] == 'CustomResponse' && action.attributes['statusCode'] == '410'
  end
  assert_equal 34, gone_rules.length

  inventory.fetch('gone').each do |source|
    rules = matching_rules(source, gone_rules)
    assert_equal 1, rules.length, source
    action = REXML::XPath.first(rules.first, 'action')
    assert_equal 'Gone', action.attributes['statusReason'], source
  end
end

def test_unchanged_paths_match_no_migration_rule
  inventory.fetch('unchanged').each do |path|
    assert_empty matching_rules(path, all_rules), path
  end
end

def test_all_audited_urls_have_one_declared_outcome
  declared = expanded_redirects.keys + inventory.fetch('gone') + inventory.fetch('unchanged')
  assert_equal 136, declared.length
  assert_equal declared.length, declared.uniq.length
end
```

- [ ] **Step 2: Run the tests and verify the missing 410 failure**

Run: `ruby test/iis_redirect_test.rb`

Expected: FAIL in `test_each_removed_url_has_one_gone_rule`, reporting 0 instead of 34.

- [ ] **Step 3: Extend the generator with exact 410 rules**

Inside `render`, after building `rules`, add:

```ruby
gone_rules = inventory.fetch('gone').sort.map.with_index(1) do |source, index|
  <<~XML.chomp
          <rule name="Legacy 410 #{format('%03d', index)}" stopProcessing="true">
            <match url="^#{CGI.escapeHTML(Regexp.escape(source.delete_prefix('/')))}$" ignoreCase="true" />
            <action type="CustomResponse" statusCode="410" statusReason="Gone" statusDescription="The requested legacy content has been removed." />
          </rule>
  XML
end
```

Change the rules body in the XML template from:

```ruby
#{rules.join("\n")}
```

to:

```ruby
#{(rules + gone_rules).join("\n")}
```

- [ ] **Step 4: Regenerate and verify all migration tests**

Run: `ruby scripts/generate_iis_redirect_config.rb --write`

Run: `ruby test/iis_redirect_test.rb`

Expected: all tests pass with 100 redirect rules, 34 Gone rules, two unmatched unchanged paths, and 136 unique outcomes.

- [ ] **Step 5: Revalidate XML and generated-file freshness**

Run: `xmllint --noout web.config`

Run: `ruby scripts/generate_iis_redirect_config.rb | diff -u web.config -`

Expected: both commands exit 0 with no output.

- [ ] **Step 6: Commit the Gone rules**

```bash
git add scripts/generate_iis_redirect_config.rb test/iis_redirect_test.rb web.config
git commit -m "feat: return Gone for removed legacy pages"
```

---

### Task 4: Run repository-wide verification and prepare the IIS handoff

**Files:**
- Verify: `config/iis_legacy_urls.yml`
- Verify: `scripts/generate_iis_redirect_config.rb`
- Verify: `test/iis_redirect_test.rb`
- Verify: `web.config`
- Do not modify unrelated user files.

**Interfaces:**
- Consumes: all artifacts from Tasks 1–3.
- Produces: fresh local verification evidence and a deployment checklist in the final handoff.

- [ ] **Step 1: Run every Ruby test**

Run:

```bash
for test_file in test/*_test.rb; do
  ruby "$test_file" || exit 1
done
```

Expected: every test file exits 0 with no failures or errors.

- [ ] **Step 2: Run deterministic generation and XML checks**

Run:

```bash
ruby scripts/generate_iis_redirect_config.rb | diff -u web.config -
xmllint --noout web.config
git diff --check
```

Expected: all three commands exit 0 with no output.

- [ ] **Step 3: Inspect the scoped diff and working tree**

Run:

```bash
git diff -- config/iis_legacy_urls.yml scripts/generate_iis_redirect_config.rb test/iis_redirect_test.rb web.config
git status --short --branch
```

Expected: only the migration artifacts from this plan are part of its commits; pre-existing image/video files and the earlier `vercel.json` removal remain untouched unless explicitly included by the user in a later integration decision.

- [ ] **Step 4: Record the production prerequisites in the handoff**

The final handoff must state all of the following:

- Confirm IIS URL Rewrite is installed before uploading `web.config`.
- Back up the existing production root and any server-side `web.config` not present in this repository.
- If the server already has `web.config`, merge only the generated `<rewrite>` section into its existing `<system.webServer>` configuration; do not replace unrelated IIS or ASP.NET settings.
- Test on an IIS staging site first; local Ruby/XML tests do not prove IIS module behavior.
- After deployment, batch-request all 136 audited URLs and verify exact 301 `Location`, 410, and unchanged 200 responses.
- Check for HTTP 500.19, redirect chains, and custom error handling that converts 410 to 200.
- Keep 301 rules for at least one year, preferably indefinitely, and monitor IIS logs plus Google Search Console for unlisted legacy URLs.

- [ ] **Step 5: Commit any verification-only corrections, if required**

If verification exposes a defect, fix only the affected migration artifact, rerun Steps 1–3, then commit the scoped correction with a message describing that defect. If no correction is required, do not create an empty commit.
