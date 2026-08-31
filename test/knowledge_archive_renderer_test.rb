require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
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
      body_html: <<~HTML,
        <p>文章摘要</p>
        <blockquote><h2>治療說明</h2></blockquote>
        <p><img src="https://www.gracelife.com.tw/a.jpg" alt=""></p>
        <div class="share-buttons">回到醫療新知</div>
      HTML
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
    assert_includes html, 'class="know-article-toc"'
    assert_includes html, 'class="know-article-content"'
    assert_includes html, 'class="know-section" id="section-1"'
    assert_includes html, 'href="#section-1"'
    assert_includes html, 'class="know-reviewer-link" href="../taichung/dr-chuang-li-chun.html"'
    assert_includes html, '<span>內容整理：生活牙醫診所</span>'
    assert_includes html, '審閱醫師：'
    rendered = Nokogiri::HTML(html)
    assert_equal 'https://www.gracelife.com.tw/knowledge/know_20260506.html',
                 rendered.at_css('link[rel="canonical"]')['href']
    structured_data = JSON.parse(rendered.at_css('script[type="application/ld+json"]').text)
    article_schema = structured_data.fetch('@graph').find { |item| item['@type'] == 'Article' }
    web_page_schema = structured_data.fetch('@graph').find { |item| item['@type'] == 'WebPage' }
    assert_equal '案例文章標題', article_schema['headline']
    assert_equal '文章摘要', article_schema['description']
    assert_equal '2026-05-06', article_schema['datePublished']
    assert_equal ['牙醫知識', '假牙贋復'], article_schema['articleSection']
    assert_equal 'https://www.gracelife.com.tw/knowledge/img/20260506/a.jpg', article_schema['image']
    assert_equal '莊禮駿', web_page_schema.dig('reviewedBy', 'name')
    refute rendered.at_css('.know-article-body .share-buttons')
    refute_includes html, 'ISQ'
    refute_match(/[ \t]+$/, html)
    refute_includes html, "\t"
  end

  def test_omits_schema_image_when_imported_article_has_no_image
    article = KnowledgeArchive::Article.new(
      source_path: 'know_20260101.html',
      title: '無圖文章',
      date: Date.new(2026, 1, 1),
      local_path: 'knowledge/know_20260101.html',
      categories: %w[general]
    )
    extracted = KnowledgeArchive::ExtractedArticle.new(
      title: '無圖文章',
      summary: '無圖文章摘要',
      body_html: '<p>無圖文章摘要</p>',
      images: []
    )

    html = KnowledgeArchive::Renderer.new(
      shell_path: 'knowledge/20231115-isq-implant-stability.html'
    ).render(article: article, extracted: extracted, asset_map: {})

    rendered = Nokogiri::HTML(html)
    structured_data = JSON.parse(rendered.at_css('script[type="application/ld+json"]').text)
    article_schema = structured_data.fetch('@graph').find { |item| item['@type'] == 'Article' }
    refute article_schema.key?('image')
    refute rendered.at_css('.know-article-media')
  end

  def test_preserves_unrelated_json_ld_before_article_schema
    shell = File.read('knowledge/20231115-isq-implant-stability.html')
    unrelated = <<~HTML
      <script type="application/ld+json">
      {"@context":"https://schema.org","@type":"Organization","name":"保留的組織"}
      </script>
    HTML
    shell = shell.sub('<script type="application/ld+json">',
                      "#{unrelated}<script type=\"application/ld+json\">")

    html = render_sample_shell(shell)
    documents = json_ld_documents(html)

    assert documents.any? { |document| document['@type'] == 'Organization' }
    articles = documents.flat_map { |document| document.fetch('@graph', [document]) }
                        .select { |item| item['@type'] == 'Article' }
    assert_equal 1, articles.length
    assert_equal '案例文章標題', articles.first['headline']
  end

  def test_creates_article_schema_when_shell_has_no_json_ld
    shell = File.read('knowledge/20231115-isq-implant-stability.html')
                .sub(%r{<script type="application/ld\+json">.*?</script>\s*}m, '')

    html = begin
      render_sample_shell(shell)
    rescue StandardError => error
      flunk "renderer 應建立 Article JSON-LD，而不是拋出 #{error.class}: #{error.message}"
    end
    articles = json_ld_documents(html)
               .flat_map { |document| document.fetch('@graph', [document]) }
               .select { |item| item['@type'] == 'Article' }

    assert_equal 1, articles.length
    assert_equal '案例文章標題', articles.first['headline']
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

  private

  def render_sample_shell(shell)
    Dir.mktmpdir do |dir|
      shell_path = File.join(dir, 'shell.html')
      File.write(shell_path, shell)
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
        body_html: '<p>文章摘要</p>',
        images: []
      )
      return KnowledgeArchive::Renderer.new(shell_path: shell_path).render(
        article: article,
        extracted: extracted,
        asset_map: {}
      )
    end
  end

  def json_ld_documents(html)
    Nokogiri::HTML(html).css('script[type="application/ld+json"]').map do |script|
      JSON.parse(script.text)
    end
  end
end
