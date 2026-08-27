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
    assert_equal 'https://www.gracelife.com.tw/images/about/know/20260506/1.jpg', image.source_url
    assert_equal '術前術後比較', image.alt
    assert_equal '1.jpg', image.filename
  end

  def test_supports_legacy_post_content_and_unicode_image_paths
    html = <<~HTML
      <article class="post single">
        <section class="date"><span>30</span></section>
        <section class="post-content">
          <header class="meta"><h1>舊版文章標題</h1><span>2017.08.14</span></header>
          <p>舊版文章摘要。</p>
          <img src="images/about/know/20170814/台中全瓷冠01.jpg" alt="全瓷冠">
        </section>
      </article>
    HTML
    result = KnowledgeArchive::Extractor.call(
      html, base_url: 'https://www.gracelife.com.tw/know_20170814.html'
    )
    assert_equal '舊版文章標題', result.title
    assert_equal '台中全瓷冠01.jpg', result.images.first.filename
    assert_includes result.images.first.source_url, '%E5%8F%B0%E4%B8%AD'
  end
end
