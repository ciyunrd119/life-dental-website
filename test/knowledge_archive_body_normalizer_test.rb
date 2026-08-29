require 'minitest/autorun'
require 'nokogiri'
require_relative '../scripts/knowledge_archive/body_normalizer'

class KnowledgeArchiveBodyNormalizerTest < Minitest::Test
  def test_converts_legacy_body_into_current_article_components
    legacy = <<~HTML
      <header class="meta"><p>舊站日期</p></header>
      <p>這是一段文章摘要，說明讀者會在本文了解的重點。</p>
      <blockquote><h2>治療前評估</h2></blockquote>
      <p>醫師會先檢查口腔狀況，再依個別需求說明治療方向。</p>
      <p><img src="img/example.jpg" alt="治療示意圖"></p>
      <h3>治療方式</h3>
      <table><tbody><tr><th>項目</th><td>內容</td></tr></tbody></table>
      <div class="share-buttons"><a href="#">分享文章</a></div>
      <div class="info-banner">立即預約諮詢</div>
      <div class="clearfix"></div>
    HTML

    doc = fragment(KnowledgeArchive::BodyNormalizer.call(legacy))

    assert_equal 1, doc.css('.know-article-content').length
    assert_equal ['這是一段文章摘要，說明讀者會在本文了解的重點。'],
                 doc.css('.know-lead-box p').map { |node| node.text.strip }
    assert_equal ['治療前評估', '治療方式'], doc.css('.know-section h2').map { |node| node.text.strip }
    assert_equal ['#section-1', '#section-2'], doc.css('.know-article-toc a').map { |node| node['href'] }
    assert_equal %w[section-1 section-2], doc.css('.know-section').map { |node| node['id'] }
    assert_equal 'img/example.jpg', doc.at_css('figure.know-image-placeholder img')['src']
    assert_equal 1, doc.css('.know-table-wrap > table').length
    refute doc.at_css('header.meta')
    refute doc.at_css('.share-buttons')
    refute doc.at_css('.info-banner')
    refute doc.at_css('.clearfix')
  end

  def test_gives_paragraph_only_article_a_standard_article_summary_section
    doc = fragment(KnowledgeArchive::BodyNormalizer.call(
      '<p>第一段摘要。</p><p>第二段補充內容。</p>'
    ))

    assert_equal ['文章重點'], doc.css('.know-article-toc a').map { |node| node.text.strip }
    assert_equal '#section-1', doc.at_css('.know-article-toc a')['href']
    assert_equal '第一段摘要。', doc.at_css('.know-lead-box p').text
    assert_equal '文章重點', doc.at_css('.know-section h2').text
    assert_equal '第二段補充內容。', doc.at_css('.know-section p').text
  end

  def test_generates_unique_ids_for_repeated_headings
    doc = fragment(KnowledgeArchive::BodyNormalizer.call(
      '<h2>注意事項</h2><p>第一段。</p><h2>注意事項</h2><p>第二段。</p>'
    ))

    assert_equal %w[section-1 section-2], doc.css('.know-section').map { |node| node['id'] }
    assert_equal ['#section-1', '#section-2'], doc.css('.know-article-toc a').map { |node| node['href'] }
  end

  def test_does_not_wrap_an_already_normalized_body_twice
    normalized = <<~HTML
      <nav class="know-article-toc" aria-label="文章目錄"><ol><li><a href="#topic">主題</a></li></ol></nav>
      <div class="know-article-content"><section class="know-section" id="topic"><h2>主題</h2><p>內容。</p></section></div>
    HTML

    output = KnowledgeArchive::BodyNormalizer.call(normalized)
    doc = fragment(output)

    assert_equal 1, doc.css('.know-article-content').length
    assert_equal 1, doc.css('.know-article-toc').length
    assert_equal 1, doc.css('.know-section').length
  end

  def test_preserves_images_malformed_inside_an_empty_heading
    doc = fragment(KnowledgeArchive::BodyNormalizer.call(
      '<p>摘要。</p><h2>案例圖片</h2><h3><img src="before.jpg" alt="術前"></h3>'
    ))

    assert_equal ['before.jpg'], doc.css('.know-article-body img, .know-article-content img').map { |node| node['src'] }
    assert_equal 1, doc.css('figure.know-image-placeholder').length
    assert_equal ['案例圖片'], doc.css('.know-section h2').map { |node| node.text.strip }
  end

  def test_preserves_images_nested_in_a_heading_with_text
    doc = fragment(KnowledgeArchive::BodyNormalizer.call(
      '<p>摘要。</p><h2>全瓷冠<img src="crown.jpg" alt="全瓷冠"></h2><p>說明。</p>'
    ))

    assert_equal ['全瓷冠'], doc.css('.know-section h2').map { |node| node.text.strip }
    assert_equal ['crown.jpg'], doc.css('.know-section figure img').map { |node| node['src'] }
  end

  def test_separates_an_image_from_descriptive_text_in_the_same_paragraph
    doc = fragment(KnowledgeArchive::BodyNormalizer.call(
      '<p>摘要。</p><h2>治療過程</h2><p><img src="step.jpg" alt="步驟">治療步驟說明。</p>'
    ))

    assert_equal 'step.jpg', doc.at_css('.know-section figure.know-image-placeholder img')['src']
    assert_equal '治療步驟說明。', doc.at_css('.know-section p').text.strip
  end

  def test_removes_old_blog_attribution_but_keeps_treatment_metadata
    doc = fragment(KnowledgeArchive::BodyNormalizer.call(<<~HTML))
      <p>摘要。</p>
      <blockquote>醫師：王醫師<br>治療內容：全瓷冠<br>同步發表於 <a href="https://example.blogspot.com/post">舊部落格</a></blockquote>
      <p>治療說明。</p>
    HTML

    note = doc.at_css('.know-doctor-note')
    assert note
    assert_includes note.text, '醫師：王醫師'
    assert_includes note.text, '治療內容：全瓷冠'
    refute_includes doc.text, '同步發表'
    refute_includes doc.text, '舊部落格'
  end

  def test_wraps_images_nested_in_legacy_layout_divs
    doc = fragment(KnowledgeArchive::BodyNormalizer.call(
      '<p>摘要。</p><h2>案例</h2><div><p><img src="nested.jpg" alt="案例圖"></p></div>'
    ))

    assert_equal 1, doc.css('figure.know-image-placeholder img[src="nested.jpg"]').length
    assert_equal 0, doc.css('p img').length
  end

  def test_replaces_an_old_reviewer_blog_link_with_the_current_profile
    doc = fragment(KnowledgeArchive::BodyNormalizer.call(
      '<p>摘要。</p><h2>評估</h2><p>經<a href="https://drlichun.blogspot.com/">莊禮駿醫師</a>評估。</p>'
    ))

    link = doc.at_css('.know-section a')
    assert_equal '../taichung/dr-chuang-li-chun.html', link['href']
  end

  private

  def fragment(html)
    Nokogiri::HTML::DocumentFragment.parse(html)
  end
end
