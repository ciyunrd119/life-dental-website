# Knowledge Archive Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** 搬運舊站所有可取得、尚未被新版取代的牙醫知識文章與圖片，並按日期及分類加入 knowledge.html。

**Architecture:** 使用 Ruby 2.6、Nokogiri、Net::HTTP 與 YAML 建立可重跑的搬運器。搬運器分為清單解析、文章抽取、資產下載、現有頁面殼層渲染、索引重建與報告輸出；每一層先以本機 HTML fixture 做 TDD，再對已確認擁有權的舊站執行一次正式匯入。

**Tech Stack:** Ruby 2.6、Nokogiri 1.13.8、Minitest、YAML、Net::HTTP、靜態 HTML/CSS/JavaScript、Vercel CLI

**Spec:** docs/superpowers/specs/2026-08-27-knowledge-archive-migration-design.md

## Global Constraints

- 舊站來源固定為 https://www.gracelife.com.tw/know.html。
- 保留本機既有 12 篇文章，不覆寫人工編輯內容。
- 相同或已有新版替代的主題不重複建立。
- 搬運文字、圖片、署名、圖說與表格，不重寫醫療內容。
- 圖片必須下載到 knowledge/img/<YYYYMMDD>/，不得熱連結舊站。
- 搬運頁使用 knowledge/know_YYYYMMDD.html；特殊來源檔名使用穩定 ASCII 名稱。
- 沿用既有 know-* 元件，不修改 element.html，除非實作時新增元件語法。
- 搬運腳本必須冪等，不覆寫不是由腳本產生的檔案。
- 任何無法取得的頁面或圖片必須進入報告，不得靜默略過。
- 目前工作目錄另有尚未提交的 zhushan 路徑修改與原始素材；每次 git add 必須列出精確路徑，不得使用 git add .、git add -A 或 git add --all。

---

## File Structure

- Create: scripts/knowledge_archive/catalog.rb — 清單解析、日期正規化、來源連結候選與覆寫規則。
- Create: scripts/knowledge_archive/extractor.rb — 從 article.post.single 抽出標題、日期、正文與文章圖片。
- Create: scripts/knowledge_archive/fetcher.rb — 限定 gracelife.com.tw 的 HTTP 取得與重新導向。
- Create: scripts/knowledge_archive/renderer.rb — 以現有文章頁為殼層產生新文章，改寫圖片與內部連結。
- Create: scripts/knowledge_archive/index_builder.rb — 建立、去重並排序 knowledge-card。
- Create: scripts/import_knowledge_archive.rb — 命令列入口、冪等保護、批次執行與報告輸出。
- Create: scripts/knowledge_archive_overrides.yml — 新版替代、錯誤連結修正與特殊檔名規則。
- Create: test/fixtures/knowledge_archive/list.html — 最小文章清單 fixture。
- Create: test/fixtures/knowledge_archive/article.html — 含標題、段落、清單、圖片、圖說、表格與應排除區塊的文章 fixture。
- Create: test/knowledge_archive_catalog_test.rb — 清單解析、覆寫與去重測試。
- Create: test/knowledge_archive_extractor_test.rb — 文章抽取、清理與圖片發現測試。
- Create: test/knowledge_archive_renderer_test.rb — 文章渲染、圖片路徑與冪等測試。
- Create: test/knowledge_archive_index_test.rb — 卡片生成、分類、日期排序與重複 href 測試。
- Create: test/knowledge_content_integrity_test.rb — 全站文章卡、圖片、熱連結與報告完整性測試。
- Create: docs/reports/knowledge-archive-migration.md — 實際新增、跳過、修正與失敗報告。
- Modify: knowledge.html:170-end of .knowledge-card-grid — 插入並排序舊站文章卡。
- Create: knowledge/know_*.html — 成功搬運的舊站文章頁。
- Create: knowledge/img/<YYYYMMDD>/* — 成功下載的文章圖片。

---

### Task 1: Source Catalog and Explicit Overrides

**Files:**
- Create: test/fixtures/knowledge_archive/list.html
- Create: test/knowledge_archive_catalog_test.rb
- Create: scripts/knowledge_archive/catalog.rb
- Create: scripts/knowledge_archive_overrides.yml

**Interfaces:**
- Produces: KnowledgeArchive::Article keyword struct with source_path, title, date, candidates, local_path, replacement, categories.
- Produces: KnowledgeArchive::Catalog.parse(html, overrides:) -> Array<KnowledgeArchive::Article>.
- Produces: KnowledgeArchive::Catalog.load_overrides(path) -> Hash.

- [ ] **Step 1: Write the source-list fixture**

Use a real-shape minimal fixture that covers a normal link, a mismatched pair of links, and a source already replaced locally:

~~~html
<article>
  <h3><a href="know_20260506.html">案例分享｜告別門牙蛀牙變黑</a></h3>
  <a href="know_20260506.html"><img src="thumb.jpg" alt=""></a>
  <span>2026.05.06</span>
</article>
<article>
  <h3><a href="know_20250206.html">植牙前做功課 掌握這3個W</a></h3>
  <a href="know_20250212.html"><img src="thumb2.jpg" alt=""></a>
  <span>2025.02.12</span>
</article>
<article>
  <h3><a href="know_20231115.html">植牙穩固了沒 讓ISQ數據告訴你</a></h3>
  <span>2023.11.15</span>
</article>
~~~

- [ ] **Step 2: Write the failing catalog tests**

~~~ruby
require 'minitest/autorun'
require_relative '../scripts/knowledge_archive/catalog'

class KnowledgeArchiveCatalogTest < Minitest::Test
  FIXTURE = File.read('test/fixtures/knowledge_archive/list.html')
  OVERRIDES = {
    'know_20250212.html' => { 'source_path' => 'know_20250212.html' },
    'know_20231115.html' => {
      'replacement' => 'knowledge/20231115-isq-implant-stability.html'
    }
  }

  def test_extracts_title_date_and_all_candidate_links
    article = KnowledgeArchive::Catalog.parse(FIXTURE, overrides: OVERRIDES)[1]
    assert_equal '2025-02-12', article.date.iso8601
    assert_equal ['know_20250212.html', 'know_20250206.html'], article.candidates
    assert_equal 'knowledge/know_20250212.html', article.local_path
  end

  def test_marks_existing_new_version_as_replacement
    article = KnowledgeArchive::Catalog.parse(FIXTURE, overrides: OVERRIDES)[2]
    assert_equal 'knowledge/20231115-isq-implant-stability.html', article.replacement
  end
end
~~~

- [ ] **Step 3: Run the test and verify RED**

Run: ruby test/knowledge_archive_catalog_test.rb

Expected: LoadError for scripts/knowledge_archive/catalog.

- [ ] **Step 4: Implement the minimal catalog**

~~~ruby
require 'date'
require 'nokogiri'
require 'yaml'

module KnowledgeArchive
  Article = Struct.new(
    :source_path, :title, :date, :candidates, :local_path,
    :replacement, :categories, keyword_init: true
  )

  module Catalog
    module_function

    def load_overrides(path)
      YAML.safe_load(File.read(path), permitted_classes: [], aliases: false) || {}
    end

    def parse(html, overrides:)
      Nokogiri::HTML(html).css('article').map do |node|
        title = node.at_css('h3').text.strip
        date = Date.strptime(node.text[/20\d{2}\.\d{1,2}\.\d{1,2}/], '%Y.%m.%d')
        links = node.css('a[href]').map { |a| a['href'] }.compact.uniq
        dated = "know_#{date.strftime('%Y%m%d')}.html"
        rule_key = ([dated] + links).find { |candidate| overrides.key?(candidate) }
        rule = rule_key ? overrides.fetch(rule_key) : {}
        source = rule['source_path'] || (links.include?(dated) ? dated : links.first)
        candidates = ([source, dated] + links).compact.uniq
        Article.new(
          source_path: source,
          title: title,
          date: date,
          candidates: candidates,
          local_path: rule['local_path'] || "knowledge/#{source}",
          replacement: rule['replacement'],
          categories: Array(rule['categories'])
        )
      end
    end
  end
end
~~~

- [ ] **Step 5: Add explicit production overrides**

Create scripts/knowledge_archive_overrides.yml with these confirmed replacements and link repairs:

~~~yaml
know_20260409.html:
  replacement: knowledge/20260624-microscope-root-canal-guide.html
know_20260305.html:
  replacement: knowledge/20260305-tooth-wear-restoration.html
know_20260225.html:
  replacement: knowledge/20260225-air-polishing-whitening.html
know_20250827.html:
  replacement: knowledge/20250827-guided-vs-freehand-implant.html
know_20250821.html:
  replacement: knowledge/20260626-front-tooth-gap-treatment.html
know_20250212.html:
  source_path: know_20250212.html
know_20240426.html:
  source_path: know_20240426.html
know_20240104.html:
  source_path: know_20240104.html
know_20231115.html:
  replacement: knowledge/20231115-isq-implant-stability.html
know_20211022.html:
  source_path: know_20211022.html
know_20200204.html:
  replacement: knowledge/20200204-zirkonzahn-zirconia-crown.html
know_20170912.html:
  replacement: knowledge/20240912-root-coverage-surgery.html
台中冷光美白.html:
  source_path: 台中冷光美白.html
  local_path: knowledge/know_cold-light-whitening.html
bestimplant.html:
  source_path: bestimplant.html
  local_path: knowledge/know_bestimplant.html
~~~

Catalog must honor an explicit local_path when present; extend the Article construction and add this assertion:

~~~ruby
assert_equal 'knowledge/know_cold-light-whitening.html',
             article.local_path
~~~

- [ ] **Step 6: Run the test and verify GREEN**

Run: ruby test/knowledge_archive_catalog_test.rb

Expected: 3 tests, 0 failures, 0 errors.

- [ ] **Step 7: Commit Task 1**

~~~bash
git add -- test/fixtures/knowledge_archive/list.html test/knowledge_archive_catalog_test.rb scripts/knowledge_archive/catalog.rb scripts/knowledge_archive_overrides.yml
git commit -m "test: define knowledge archive catalog"
~~~

---

### Task 2: Safe Fetcher and Article Extraction

**Files:**
- Create: test/fixtures/knowledge_archive/article.html
- Create: test/knowledge_archive_extractor_test.rb
- Create: scripts/knowledge_archive/fetcher.rb
- Create: scripts/knowledge_archive/extractor.rb

**Interfaces:**
- Consumes: KnowledgeArchive::Article from Task 1.
- Produces: KnowledgeArchive::Fetcher#get(url) -> String and #download(url) -> binary String.
- Produces: KnowledgeArchive::ExtractedArticle keyword struct with title, date_text, summary, body_html, images.
- Produces: KnowledgeArchive::ImageRef keyword struct with source_url, alt, filename.
- Produces: KnowledgeArchive::Extractor.call(html, base_url:) -> ExtractedArticle.

- [ ] **Step 1: Write a representative article fixture**

~~~html
<article class="post single">
  <section>
    <h1>案例文章標題</h1>
    <span>2026.05.06</span>
    <p>這是文章第一段摘要，必須保留下來。</p>
    <h1>術前狀況分析</h1>
    <p>病例說明。</p>
    <ul><li>治療重點</li></ul>
    <figure>
      <img src="images/about/know/20260506/1.jpg" alt="術前術後比較">
      <figcaption>術前術後比較圖</figcaption>
    </figure>
    <table><tr><th>項目</th><td>內容</td></tr></table>
    <iframe src="https://www.facebook.com/plugin"></iframe>
  </section>
</article>
<footer><img src="images/qrcode.png" alt="LINE"></footer>
~~~

- [ ] **Step 2: Write the failing extractor tests**

~~~ruby
require 'minitest/autorun'
require_relative '../scripts/knowledge_archive/extractor'

class KnowledgeArchiveExtractorTest < Minitest::Test
  def setup
    @result = KnowledgeArchive::Extractor.call(
      File.read('test/fixtures/knowledge_archive/article.html'),
      base_url: 'https://www.gracelife.com.tw/know_20260506.html'
    )
  end

  def test_extracts_only_article_content
    assert_equal '案例文章標題', @result.title
    assert_equal '這是文章第一段摘要，必須保留下來。', @result.summary
    assert_includes @result.body_html, '<h2>術前狀況分析</h2>'
    assert_includes @result.body_html, '<table>'
    refute_includes @result.body_html, '<iframe'
    refute_includes @result.body_html, 'qrcode.png'
  end

  def test_discovers_article_images_with_absolute_urls
    image = @result.images.fetch(0)
    assert_equal 'https://www.gracelife.com.tw/images/about/know/20260506/1.jpg',
                 image.source_url
    assert_equal '術前術後比較', image.alt
    assert_equal '1.jpg', image.filename
  end
end
~~~

- [ ] **Step 3: Run the test and verify RED**

Run: ruby test/knowledge_archive_extractor_test.rb

Expected: LoadError for scripts/knowledge_archive/extractor.

- [ ] **Step 4: Implement Fetcher with a host allowlist**

~~~ruby
require 'net/http'
require 'uri'

module KnowledgeArchive
  class Fetcher
    ALLOWED_HOSTS = %w[www.gracelife.com.tw gracelife.com.tw].freeze

    def get(url, limit: 5)
      raise 'too many redirects' if limit.zero?
      uri = URI(url)
      raise "blocked host: #{uri.host}" unless ALLOWED_HOSTS.include?(uri.host)
      response = Net::HTTP.get_response(uri)
      return get(URI.join(url, response['location']).to_s, limit: limit - 1) if response.is_a?(Net::HTTPRedirection)
      raise "HTTP #{response.code}: #{url}" unless response.is_a?(Net::HTTPSuccess)
      response.body.force_encoding('UTF-8')
    end

    def download(url)
      get(url).b
    end
  end
end
~~~

- [ ] **Step 5: Implement Extractor against the confirmed DOM**

Use article.post.single > section as the source root, remove script/style/iframe/form/nav/footer, remove the first heading and date from the body, convert remaining h1 to h2 and h2 to h3, and resolve image URLs with URI.join.

~~~ruby
require 'nokogiri'
require 'uri'

module KnowledgeArchive
  ImageRef = Struct.new(:source_url, :alt, :filename, keyword_init: true)
  ExtractedArticle = Struct.new(
    :title, :date_text, :summary, :body_html, :images, keyword_init: true
  )

  module Extractor
    module_function

    def call(html, base_url:)
      doc = Nokogiri::HTML(html)
      root = doc.at_css('article.post.single > section') ||
             doc.at_css('article.post.single')
      raise 'article body not found' unless root
      root.css('script,style,iframe,form,nav,footer').remove
      title_node = root.at_css('h1,h2')
      title = title_node.text.strip
      title_node.remove
      date_text = root.text[/20\d{2}\.\d{1,2}\.\d{1,2}/]
      root.css('h1').each { |node| node.name = 'h2' }
      root.css('h2').drop(1).each { |node| node.name = 'h3' }
      images = root.css('img[src]').map do |img|
        absolute = URI.join(base_url, img['src']).to_s
        ImageRef.new(
          source_url: absolute,
          alt: img['alt'].to_s.strip,
          filename: File.basename(URI(absolute).path)
        )
      end
      summary = root.css('p').map { |p| p.text.strip }.find { |text| !text.empty? }
      ExtractedArticle.new(
        title: title,
        date_text: date_text,
        summary: summary,
        body_html: root.inner_html.strip,
        images: images
      )
    end
  end
end
~~~

- [ ] **Step 6: Run the test and verify GREEN**

Run: ruby test/knowledge_archive_extractor_test.rb

Expected: 2 tests, 0 failures, 0 errors.

- [ ] **Step 7: Commit Task 2**

~~~bash
git add -- test/fixtures/knowledge_archive/article.html test/knowledge_archive_extractor_test.rb scripts/knowledge_archive/fetcher.rb scripts/knowledge_archive/extractor.rb
git commit -m "feat: extract legacy knowledge articles"
~~~

---

### Task 3: Local Article Rendering, Image Rewriting, and Idempotency

**Files:**
- Create: test/knowledge_archive_renderer_test.rb
- Create: scripts/knowledge_archive/renderer.rb
- Modify: scripts/knowledge_archive/extractor.rb

**Interfaces:**
- Consumes: Article and ExtractedArticle from Tasks 1–2.
- Produces: KnowledgeArchive::Renderer#render(article:, extracted:, asset_map:) -> complete HTML String.
- Produces: KnowledgeArchive::Renderer#write(path:, html:) -> :created, :unchanged, or raises ExistingManualFile.
- asset_map type: Hash<String source_url, String article-relative-local-path>.

- [ ] **Step 1: Write the failing renderer test**

Use Dir.mktmpdir and a copy of knowledge/20231115-isq-implant-stability.html as the real shell:

~~~ruby
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../scripts/knowledge_archive/renderer'

class KnowledgeArchiveRendererTest < Minitest::Test
  def test_renders_into_current_article_shell_and_rewrites_images
    article = KnowledgeArchive::Article.new(
      source_path: 'know_20260506.html',
      title: '來源標題',
      date: Date.new(2026, 5, 6),
      local_path: 'knowledge/know_20260506.html',
      categories: %w[prosthodontics esthetic]
    )
    extracted = KnowledgeArchive::ExtractedArticle.new(
      title: '案例文章標題',
      summary: '文章摘要',
      body_html: '<p>文章摘要</p><img src="https://www.gracelife.com.tw/a.jpg" alt="">',
      images: []
    )
    html = KnowledgeArchive::Renderer.new(
      shell_path: 'knowledge/20231115-isq-implant-stability.html'
    ).render(
      article: article,
      extracted: extracted,
      asset_map: { 'https://www.gracelife.com.tw/a.jpg' => 'img/20260506/a.jpg' }
    )
    assert_includes html, '<h1>案例文章標題</h1>'
    assert_includes html, '2026.05.06'
    assert_includes html, 'src="img/20260506/a.jpg"'
    assert_includes html, 'data-migrated-source="know_20260506.html"'
    refute_includes html, 'ISQ'
  end

  def test_refuses_to_overwrite_manual_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'article.html')
      File.write(path, '<p>manual</p>')
      assert_raises(KnowledgeArchive::ExistingManualFile) do
        KnowledgeArchive::Renderer.write(path: path, html: '<p>new</p>')
      end
    end
  end
end
~~~

- [ ] **Step 2: Run the test and verify RED**

Run: ruby test/knowledge_archive_renderer_test.rb

Expected: LoadError for scripts/knowledge_archive/renderer.

- [ ] **Step 3: Implement the renderer**

Load the real article shell with Nokogiri. Replace title, description meta, breadcrumb terminal text, hero h1, hero date, hero category, and the complete know-article-body. Add data-migrated-source to body so reruns can identify generated files.

~~~ruby
require 'cgi'
require 'fileutils'
require 'nokogiri'

module KnowledgeArchive
  class ExistingManualFile < StandardError; end

  class Renderer
    def initialize(shell_path:)
      @shell_path = shell_path
    end

    def render(article:, extracted:, asset_map:)
      doc = Nokogiri::HTML(File.read(@shell_path))
      doc.at_css('title').content = "#{extracted.title}｜生活牙醫診所"
      doc.at_css('meta[name="description"]')['content'] = extracted.summary.to_s
      doc.at_css('.page-breadcrumb span:last-child').content = extracted.title
      doc.at_css('.know-article-hero h1').content = extracted.title
      meta = doc.css('.know-article-meta span')
      meta[0].content = article.date.strftime('%Y.%m.%d')
      meta[1].content = category_label(article.categories.first)
      body = doc.at_css('.know-article-body')
      body.children.remove
      fragment = Nokogiri::HTML::DocumentFragment.parse(extracted.body_html)
      fragment.css('img[src]').each do |img|
        img['src'] = asset_map.fetch(img['src'])
        img['alt'] = extracted.title if img['alt'].to_s.strip.empty?
      end
      body.add_child(fragment)
      doc.at_css('body')['data-migrated-source'] = article.source_path
      doc.to_html
    end

    def self.write(path:, html:)
      if File.exist?(path)
        current = File.read(path)
        return :unchanged if current == html
        raise ExistingManualFile unless current.include?('data-migrated-source=')
      end
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, html)
      :created
    end

    private

    def category_label(category)
      {
        'all-on-4' => 'All-on-4',
        'prosthodontics' => '假牙贋復',
        'implant' => '數位植牙',
        'ortho' => '齒顎矯正',
        'esthetic' => '美容牙科',
        'periodontal' => '牙周治療',
        'general' => '一般牙科'
      }.fetch(category, '一般牙科')
    end
  end
end
~~~

- [ ] **Step 4: Normalize source image attributes in Extractor**

Before returning body_html, replace each image src with its absolute source URL so Renderer can use asset_map directly:

~~~ruby
root.css('img[src]').zip(images).each do |img, image_ref|
  img['src'] = image_ref.source_url
end
~~~

- [ ] **Step 5: Run tests and verify GREEN**

Run: ruby test/knowledge_archive_extractor_test.rb && ruby test/knowledge_archive_renderer_test.rb

Expected: all tests pass with 0 failures and 0 errors.

- [ ] **Step 6: Commit Task 3**

~~~bash
git add -- test/knowledge_archive_renderer_test.rb scripts/knowledge_archive/renderer.rb scripts/knowledge_archive/extractor.rb
git commit -m "feat: render migrated knowledge pages"
~~~

---

### Task 4: Knowledge Card Builder and Integrity Contract

**Files:**
- Create: test/knowledge_archive_index_test.rb
- Create: scripts/knowledge_archive/index_builder.rb
- Create: test/knowledge_content_integrity_test.rb

**Interfaces:**
- Consumes: Article and ExtractedArticle.
- Produces: KnowledgeArchive::IndexBuilder#card(article:, extracted:, cover_path:) -> Nokogiri::XML::Node.
- Produces: KnowledgeArchive::IndexBuilder#rebuild(entries:) -> complete knowledge.html String.
- entries type: Array<Hash> with article, extracted, cover_path.

- [ ] **Step 1: Write failing index tests**

~~~ruby
require 'minitest/autorun'
require 'nokogiri'
require_relative '../scripts/knowledge_archive/index_builder'

class KnowledgeArchiveIndexTest < Minitest::Test
  def test_cards_are_unique_and_sorted_newest_first
    builder = KnowledgeArchive::IndexBuilder.new(path: 'knowledge.html')
    entries = [
      fixture_entry('knowledge/know_20180731.html', Date.new(2018, 7, 31)),
      fixture_entry('knowledge/know_20260506.html', Date.new(2026, 5, 6))
    ]
    html = builder.rebuild(entries: entries + [entries.first])
    doc = Nokogiri::HTML(html)
    hrefs = doc.css('.knowledge-card').map { |node| node['href'] }
    migrated = hrefs.grep(/know_/)
    assert_equal ['knowledge/know_20260506.html', 'knowledge/know_20180731.html'],
                 migrated
    assert_equal migrated.uniq, migrated
  end

  private

  def fixture_entry(path, date)
    {
      article: KnowledgeArchive::Article.new(
        source_path: File.basename(path),
        title: '固定測試標題',
        date: date,
        local_path: path,
        categories: ['general']
      ),
      extracted: KnowledgeArchive::ExtractedArticle.new(
        title: '固定測試標題',
        summary: '固定測試摘要',
        body_html: '<p>固定測試摘要</p>',
        images: []
      ),
      cover_path: 'knowledge/img/default.png'
    }
  end
end
~~~

- [ ] **Step 2: Run the test and verify RED**

Run: ruby test/knowledge_archive_index_test.rb

Expected: LoadError for scripts/knowledge_archive/index_builder.

- [ ] **Step 3: Implement card creation and full-grid sorting**

~~~ruby
require 'cgi'
require 'date'
require 'nokogiri'

module KnowledgeArchive
  class IndexBuilder
    def initialize(path:)
      @path = path
    end

    def rebuild(entries:)
      doc = Nokogiri::HTML(File.read(@path))
      grid = doc.at_css('.knowledge-card-grid')
      entries.each do |entry|
        href = entry.fetch(:article).local_path
        next if grid.at_css(%(a[href="#{href}"]))
        grid.add_child(card(**entry))
      end
      cards = grid.css(':scope > a.knowledge-card').to_a
      unique = cards.each_with_object({}) { |node, memo| memo[node['href']] ||= node }
      sorted = unique.values.sort_by do |node|
        Date.parse(node.at_css('time')['datetime'])
      end.reverse
      grid.children.remove
      sorted.each { |node| grid.add_child(node) }
      doc.to_html
    end

    def card(article:, extracted:, cover_path:)
      fragment = Nokogiri::HTML::DocumentFragment.parse(<<~HTML)
        <a href="#{article.local_path}" class="knowledge-card"
           data-knowledge-category="#{article.categories.join(' ')}"
           data-migrated-source="#{article.source_path}">
          <figure class="knowledge-card-media">
            <img src="#{CGI.escapeHTML(cover_path)}" alt="#{CGI.escapeHTML(extracted.title)}">
          </figure>
          <div class="knowledge-card-body">
            <span class="knowledge-card-tag">#{Categories.label(article.categories.first)}</span>
            <h3>#{CGI.escapeHTML(extracted.title)}</h3>
            <p class="knowledge-card-desc">#{CGI.escapeHTML(extracted.summary)}<span class="knowledge-card-more">閱讀更多...</span></p>
            <time datetime="#{article.date.iso8601}">#{article.date.strftime('%Y.%m.%d')}</time>
          </div>
        </a>
      HTML
      fragment.at_css('a')
    end
  end
end
~~~

Implement the shared category contract in scripts/knowledge_archive/categories.rb and make both Renderer and IndexBuilder call KnowledgeArchive::Categories.label(category):

~~~ruby
module KnowledgeArchive
  module Categories
    LABELS = {
      'all-on-4' => 'All-on-4',
      'prosthodontics' => '假牙贋復',
      'implant' => '數位植牙',
      'ortho' => '齒顎矯正',
      'esthetic' => '美容牙科',
      'periodontal' => '牙周治療',
      'general' => '一般牙科'
    }.freeze

    KEYWORDS = {
      'all-on-4' => %w[All-On-4 All-on-4 全口重建],
      'prosthodontics' => %w[假牙 全瓷冠 全鋯冠 貼片 齒雕 嵌體],
      'implant' => %w[植牙 植體 補骨 鼻竇增高 導引式],
      'ortho' => %w[矯正 隱適美 暴牙 齒列 反咬 阻生齒],
      'esthetic' => %w[美白 美學 貼片 牙縫 齒內美白],
      'periodontal' => %w[牙周 牙齦 牙根覆蓋 牙齦萎縮],
      'general' => %w[根管 蛀牙 洗牙 口腔]
    }.freeze

    module_function

    def label(category)
      LABELS.fetch(category, LABELS.fetch('general'))
    end

    def classify(text)
      matches = KEYWORDS.each_with_object([]) do |(category, keywords), found|
        found << category if keywords.any? { |keyword| text.include?(keyword) }
      end
      matches.empty? ? ['general'] : matches
    end
  end
end
~~~

In scripts/knowledge_archive/renderer.rb replace the temporary private mapping call with:

~~~ruby
meta[1].content = KnowledgeArchive::Categories.label(article.categories.first)
~~~

Remove Renderer#category_label after requiring categories.rb. IndexBuilder must also require categories.rb before calling Categories.label.

- [ ] **Step 4: Add failing whole-site integrity tests**

~~~ruby
require 'minitest/autorun'
require 'nokogiri'
require 'pathname'

class KnowledgeContentIntegrityTest < Minitest::Test
  def test_every_card_target_and_local_image_exists
    doc = Nokogiri::HTML(File.read('knowledge.html'))
    doc.css('a.knowledge-card').each do |card|
      assert File.file?(card['href']), "missing article: #{card['href']}"
      image = card.at_css('img')['src']
      assert File.file?(image), "missing card image: #{image}"
    end
  end

  def test_migrated_articles_do_not_hotlink_source_images
    Dir['knowledge/know_*.html'].each do |path|
      html = File.read(path)
      refute_match(%r{<img[^>]+src="https?://(?:www\.)?gracelife\.com\.tw/},
                   html, path)
    end
  end

  def test_cards_are_unique_and_sorted_descending
    doc = Nokogiri::HTML(File.read('knowledge.html'))
    cards = doc.css('a.knowledge-card')
    hrefs = cards.map { |card| card['href'] }
    dates = cards.map { |card| Date.parse(card.at_css('time')['datetime']) }
    assert_equal hrefs.uniq, hrefs
    assert_equal dates.sort.reverse, dates
  end
end
~~~

- [ ] **Step 5: Run tests and verify GREEN**

Run: ruby test/knowledge_archive_index_test.rb && ruby test/knowledge_content_integrity_test.rb

Expected before live migration: index tests pass; integrity tests pass against current articles.

- [ ] **Step 6: Commit Task 4**

~~~bash
git add -- test/knowledge_archive_index_test.rb test/knowledge_content_integrity_test.rb scripts/knowledge_archive/index_builder.rb scripts/knowledge_archive/categories.rb scripts/knowledge_archive/renderer.rb
git commit -m "test: enforce knowledge archive integrity"
~~~

---

### Task 5: Idempotent Batch Runner and Migration Report

**Files:**
- Create: test/knowledge_archive_runner_test.rb
- Create: scripts/import_knowledge_archive.rb
- Create: docs/reports/knowledge-archive-migration.md
- Modify: scripts/knowledge_archive/catalog.rb
- Modify: scripts/knowledge_archive/fetcher.rb

**Interfaces:**
- Consumes all Task 1–4 interfaces.
- Produces: KnowledgeArchive::Runner#run(list_url: String) -> Array<KnowledgeArchive::Result>.
- Result fields: source_path, status, local_path, images_downloaded, repaired_from, error.
- CLI: ruby scripts/import_knowledge_archive.rb --source URL --site-root PATH --report PATH.

- [ ] **Step 1: Write failing runner behavior tests**

Use a fixture-backed Fetcher object that returns complete fixture HTML and binary image bytes. Assert these real filesystem effects in Dir.mktmpdir:

~~~ruby
def test_runner_downloads_assets_writes_page_and_is_idempotent
  first = runner.run
  second = runner.run
  assert_equal :created, first.fetch(0).status
  assert_equal :unchanged, second.fetch(0).status
  assert File.file?(File.join(@root, 'knowledge/know_20260506.html'))
  assert File.file?(File.join(@root, 'knowledge/img/20260506/1.jpg'))
end

def test_runner_reports_replacements_and_fetch_failures
  results = runner.run
  assert_includes results.map(&:status), :replaced
  failed = results.find { |result| result.status == :failed }
  assert_match(/HTTP 404/, failed.error)
end
~~~

- [ ] **Step 2: Run the test and verify RED**

Run: ruby test/knowledge_archive_runner_test.rb

Expected: NameError for KnowledgeArchive::Runner.

- [ ] **Step 3: Implement Runner**

Runner algorithm:

1. Fetch and parse know.html.
2. For replacement records, emit :replaced without fetching the old page.
3. For each pending record, try candidates in order and accept the first page whose extracted title shares at least one normalized run of four Chinese characters or one ASCII keyword of six characters with the list title.
4. Classify categories from title plus extracted body using a literal keyword table.
5. Download each unique article image to knowledge/img/<date>/ with binary mode and SHA-256 duplicate detection.
6. Build asset_map, render the page, and write it with Renderer.write.
7. Collect successful entries and rebuild knowledge.html once, after all articles finish.
8. Write docs/reports/knowledge-archive-migration.md even when some records fail.
9. Exit nonzero only for unexpected program errors; per-article HTTP/title/image failures are report rows.

Implement the orchestration with these exact objects and return values:

~~~ruby
require 'digest'
require 'fileutils'
require_relative 'knowledge_archive/catalog'
require_relative 'knowledge_archive/categories'
require_relative 'knowledge_archive/extractor'
require_relative 'knowledge_archive/fetcher'
require_relative 'knowledge_archive/index_builder'
require_relative 'knowledge_archive/renderer'

module KnowledgeArchive
  Result = Struct.new(
    :source_path, :status, :local_path, :images_downloaded,
    :repaired_from, :error, keyword_init: true
  )

  class Runner
    def initialize(fetcher:, overrides:, root:, report_path:, write:)
      @fetcher = fetcher
      @overrides = overrides
      @root = root
      @report_path = report_path
      @write = write
      @renderer = Renderer.new(
        shell_path: File.join(root, 'knowledge/20231115-isq-implant-stability.html')
      )
      @index = IndexBuilder.new(path: File.join(root, 'knowledge.html'))
    end

    def run(list_url)
      catalog = Catalog.parse(@fetcher.get(list_url), overrides: @overrides)
      results = []
      entries = []
      catalog.each do |article|
        if article.replacement
          results << result(article, :replaced, local_path: article.replacement)
          next
        end
        begin
          extracted, accepted_url = resolve(article, list_url)
          article.categories = Categories.classify(
            "#{article.title} #{extracted.body_html}"
          )
          asset_map, cover_path, image_count = download_assets(article, extracted)
          html = @renderer.render(
            article: article, extracted: extracted, asset_map: asset_map
          )
          absolute_page = File.join(@root, article.local_path)
          status = @write ? Renderer.write(path: absolute_page, html: html) : :created
          entries << {
            article: article,
            extracted: extracted,
            cover_path: cover_path
          }
          results << result(
            article, status,
            local_path: article.local_path,
            images_downloaded: image_count,
            repaired_from: accepted_url.end_with?(article.source_path) ? nil : accepted_url
          )
        rescue StandardError => error
          results << result(article, :failed, error: error.message)
        end
      end
      if @write
        html = @index.rebuild(entries: entries)
        File.write(File.join(@root, 'knowledge.html'), html)
      end
      write_report(results)
      results
    end

    private

    def resolve(article, list_url)
      article.candidates.each do |candidate|
        url = URI.join(list_url, candidate).to_s
        begin
          extracted = Extractor.call(@fetcher.get(url), base_url: url)
          return [extracted, url] if title_match?(article.title, extracted.title)
        rescue StandardError
          next
        end
      end
      raise "no matching source page: #{article.candidates.join(', ')}"
    end

    def title_match?(listed, extracted)
      listed_tokens = normalized_tokens(listed)
      extracted_tokens = normalized_tokens(extracted)
      !(listed_tokens & extracted_tokens).empty?
    end

    def normalized_tokens(text)
      text.to_s
          .gsub(/[[:punct:]\s｜∣]+/, ' ')
          .scan(/[\p{Han}]{4,}|[A-Za-z0-9]{6,}/)
          .flat_map { |token| token.match?(/\A\p{Han}+\z/) ? token.chars.each_cons(4).map(&:join) : [token.downcase] }
          .uniq
    end

    def download_assets(article, extracted)
      date = article.date.strftime('%Y%m%d')
      directory = File.join(@root, 'knowledge/img', date)
      asset_map = {}
      extracted.images.each_with_index do |image, index|
        filename = safe_filename(image.filename, index)
        absolute = File.join(directory, filename)
        bytes = @fetcher.download(image.source_url)
        if @write
          FileUtils.mkdir_p(directory)
          File.binwrite(absolute, bytes) unless File.exist?(absolute) &&
                                                 Digest::SHA256.file(absolute).hexdigest == Digest::SHA256.hexdigest(bytes)
        end
        asset_map[image.source_url] = "img/#{date}/#{filename}"
      end
      first = asset_map.values.first
      cover = first ? "knowledge/#{first}" : 'img/hero/knowledge.webp'
      [asset_map, cover, asset_map.length]
    end

    def safe_filename(filename, index)
      extension = File.extname(filename)
      stem = File.basename(filename, extension)
                 .encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
                 .gsub(/[^A-Za-z0-9_-]+/, '-')
                 .gsub(/\A-+|-+\z/, '')
      stem = "image-#{index + 1}" if stem.empty?
      "#{stem}#{extension.downcase}"
    end

    def result(article, status, local_path: nil, images_downloaded: 0,
               repaired_from: nil, error: nil)
      Result.new(
        source_path: article.source_path,
        status: status,
        local_path: local_path,
        images_downloaded: images_downloaded,
        repaired_from: repaired_from,
        error: error
      )
    end

    def write_report(results)
      rows = results.map do |item|
        "| #{item.source_path} | #{item.status} | #{item.local_path} | " \
          "#{item.images_downloaded} | #{item.repaired_from} | #{item.error} |"
      end
      report = [
        '# 牙醫知識舊站搬運報告',
        '',
        '| Source | Status | Local page | Images | Repaired from | Error |',
        '|---|---|---|---:|---|---|',
        *rows,
        ''
      ].join("\n")
      return report unless @write
      absolute = File.join(@root, @report_path)
      FileUtils.mkdir_p(File.dirname(absolute))
      File.write(absolute, report)
      report
    end
  end
end
~~~

The report table must have exact columns:

~~~markdown
| Source | Status | Local page | Images | Repaired from | Error |
|---|---|---|---:|---|---|
~~~

- [ ] **Step 4: Add dry-run and write CLI modes**

The default is dry-run. Require --write to mutate knowledge/, knowledge.html, and docs/reports:

~~~ruby
options = {
  source: 'https://www.gracelife.com.tw/know.html',
  site_root: Dir.pwd,
  report: 'docs/reports/knowledge-archive-migration.md',
  write: false
}
~~~

Print a final summary with exact counters:

~~~text
created=N unchanged=N replaced=N failed=N images=N
~~~

- [ ] **Step 5: Run tests and verify GREEN**

Run: ruby test/knowledge_archive_runner_test.rb

Expected: all tests pass with 0 failures and 0 errors.

- [ ] **Step 6: Commit Task 5**

~~~bash
git add -- test/knowledge_archive_runner_test.rb scripts/import_knowledge_archive.rb scripts/knowledge_archive/catalog.rb scripts/knowledge_archive/fetcher.rb docs/reports/knowledge-archive-migration.md
git commit -m "feat: add knowledge archive migration runner"
~~~

---

### Task 6: Execute the Owned-Site Migration

**Files:**
- Modify: knowledge.html
- Create: knowledge/know_*.html
- Create: knowledge/img/<YYYYMMDD>/*
- Modify: docs/reports/knowledge-archive-migration.md

**Interfaces:**
- Consumes the CLI from Task 5.
- Produces the complete migrated content set and final report.

- [ ] **Step 1: Run a network-enabled dry run**

Run:

~~~bash
ruby scripts/import_knowledge_archive.rb --source https://www.gracelife.com.tw/know.html --site-root . --report docs/reports/knowledge-archive-migration.md
~~~

Expected:

- Source count is at least 70.
- replaced includes the eight confirmed newer local versions.
- created is greater than 50.
- Every failed row contains a concrete HTTP, title-mismatch, or image error.
- No files under knowledge/ or knowledge/img/ change during dry run.

- [ ] **Step 2: Review and encode any newly discovered source repairs**

For every title-mismatch failure, inspect the source article in the browser, add a precise source_path or local_path rule to scripts/knowledge_archive_overrides.yml, and add one fixture/test case reproducing the error before changing the override.

Run: ruby test/knowledge_archive_catalog_test.rb

Expected: all catalog tests pass.

- [ ] **Step 3: Run the write migration**

Run:

~~~bash
ruby scripts/import_knowledge_archive.rb --source https://www.gracelife.com.tw/know.html --site-root . --report docs/reports/knowledge-archive-migration.md --write
~~~

Expected: created plus replaced plus failed equals the source count; knowledge.html and report are written once.

- [ ] **Step 4: Prove idempotency**

Run the exact --write command again.

Expected: created=0; successful prior records report unchanged; no duplicate cards or files are added.

- [ ] **Step 5: Run integrity tests**

Run:

~~~bash
ruby test/knowledge_content_integrity_test.rb
~~~

Expected: 0 failures, 0 errors; every card page and image exists, dates are descending, hrefs are unique, and no source-image hotlinks remain.

- [ ] **Step 6: Inspect the migration report**

Confirm every source row appears exactly once. For each failed page or image, verify the report includes its exact source URL and error. Do not create empty placeholder pages.

- [ ] **Step 7: Commit the migrated content**

Generate an exact path list from the report and stage only:

- knowledge.html
- knowledge/know_*.html created by this runner
- knowledge/img/<YYYYMMDD>/ directories created by this runner
- docs/reports/knowledge-archive-migration.md
- scripts/knowledge_archive_overrides.yml if repaired
- corresponding new fixture/test files

Commit:

~~~bash
git commit -m "content: migrate legacy dental knowledge archive"
~~~

---

### Task 7: Full Verification and Responsive Visual QA

**Files:**
- Verify: knowledge.html
- Verify: knowledge/know_*.html
- Verify: css/style.css
- Verify: js/main.js
- Verify: element.html

**Interfaces:**
- Consumes the completed migrated site from Task 6.
- Produces verification evidence only; modify css/style.css and element.html only if a reusable layout defect is found.

- [ ] **Step 1: Run the complete automated suite**

Run:

~~~bash
for test_file in test/*_test.rb; do ruby "$test_file" || exit 1; done
node --check js/main.js
git diff --check
~~~

Expected: every command exits 0 with no failures or syntax errors.

- [ ] **Step 2: Run the Vercel production build**

Run:

~~~bash
vercel pull --yes --environment production
vercel build --prod
~~~

Expected: status ok and Build completed successfully.

- [ ] **Step 3: Start a local static server**

Run from the repository root:

~~~bash
python3 -m http.server 4173
~~~

Keep the session ID for browser verification.

- [ ] **Step 4: Desktop QA at 1440 × 1000**

Open http://127.0.0.1:4173/knowledge.html and verify:

- Cards are newest-first and no card is duplicated.
- All filter buttons show at least one matching card where the category exists.
- Long titles wrap inside cards.
- At least one recent migrated article, one table article, one image-heavy case article, and the oldest article open without 404.
- document.documentElement.scrollWidth equals document.documentElement.clientWidth.

- [ ] **Step 5: Mobile QA at 390 × 844**

Repeat the same representative pages and verify:

- No horizontal overflow.
- Article images stay within the content column.
- Tables scroll or wrap within their container.
- Navigation and footer remain usable.
- Card titles, dates, and descriptions do not overlap.

- [ ] **Step 6: Handle any reusable component defect**

If QA finds a shared know-* CSS defect, first add a failing assertion to test/knowledge_content_integrity_test.rb or a focused browser regression check, then modify css/style.css. Because AGENTS.md requires synchronization, update element.html preview, copyable example, and class reference for every changed reusable component rule.

- [ ] **Step 7: Re-run final evidence**

Run:

~~~bash
for test_file in test/*_test.rb; do ruby "$test_file" || exit 1; done
node --check js/main.js
vercel build --prod
git diff --check
git status --short --branch
~~~

Expected: tests and build pass; status contains only the intended migration plus pre-existing unrelated local assets.

- [ ] **Step 8: Commit QA fixes if any**

Stage only exact QA-modified paths and commit:

~~~bash
git commit -m "fix: harden migrated knowledge layouts"
~~~
