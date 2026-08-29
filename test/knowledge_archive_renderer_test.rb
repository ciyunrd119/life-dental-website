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
    assert_includes html, '審閱醫師：'
    rendered = Nokogiri::HTML(html)
    refute rendered.at_css('.know-article-body .share-buttons')
    refute_includes html, 'ISQ'
    refute_match(/[ \t]+$/, html)
    refute_includes html, "\t"
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
