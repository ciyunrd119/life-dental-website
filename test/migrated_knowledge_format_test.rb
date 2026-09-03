require 'minitest/autorun'
require 'nokogiri'
require 'tmpdir'
require_relative '../scripts/normalize_migrated_knowledge'

class MigratedKnowledgeFormatTest < Minitest::Test
  def test_normalizes_a_page_without_changing_non_body_content_or_assets
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'know_sample.html')
      File.write(path, <<~HTML)
        <!doctype html><html><body data-migrated-source="know_sample.html">
        <div class="know-article-meta"><span>日期</span><span>時間</span><span>審閱醫師：<a class="know-reviewer-link" href="doctor.html">醫師</a></span></div>
        <div class="know-article-body"><p>摘要。</p><h2>主題</h2><p><img src="image.jpg" alt="圖"></p><table><tr><td>資料</td></tr></table></div>
        <footer>保留頁尾</footer></body></html>
      HTML

      result = KnowledgeArchive::MigratedPageNormalizer.call(path)
      first_pass = File.read(path)
      second_result = KnowledgeArchive::MigratedPageNormalizer.call(path)
      doc = Nokogiri::HTML(first_pass)

      assert_equal :updated, result
      assert_equal :unchanged, second_result
      assert_equal 1, doc.css('.know-article-content').length
      assert_equal 1, doc.css('.know-article-body img[src="image.jpg"]').length
      assert_equal 1, doc.css('.know-article-body table').length
      assert_equal 'doctor.html', doc.at_css('.know-reviewer-link')['href']
      assert_includes first_pass, '<footer>保留頁尾</footer>'
    end
  end

  def test_can_refresh_an_already_normalized_page_from_legacy_source_body
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'know_sample.html')
      File.write(path, <<~HTML)
        <!doctype html><html><body><div class="know-article-meta"><a class="know-reviewer-link" href="doctor.html">醫師</a></div>
        <div class="know-article-body"><div class="know-article-content"><section class="know-section"><p>舊的轉換結果</p></section></div></div>
        <footer>保留頁尾</footer></body></html>
      HTML

      result = KnowledgeArchive::MigratedPageNormalizer.call(
        path,
        source_body: <<~HTML
          <p>新版摘要。</p>
          <blockquote>治療內容：全瓷冠<br>同步發表於 <a href="https://example.blogspot.com/post">舊部落格</a></blockquote>
          <p>經<a href="https://drlichun.blogspot.com/">莊禮駿醫師</a>評估。</p>
          <p><img src="case.jpg" alt="案例">新版說明。</p>
        HTML
      )
      doc = Nokogiri::HTML(File.read(path))

      assert_equal :updated, result
      assert_equal '文章重點', doc.at_css('.know-article-toc a').text
      assert_equal 'case.jpg', doc.at_css('figure.know-image-placeholder img')['src']
      assert_equal 'doctor.html', doc.at_css('.know-reviewer-link')['href']
      assert doc.at_css('.know-article-body a[href="../taichung/dr-chuang-li-chun.html"]')
      refute_includes doc.text, '舊部落格'
      assert_includes doc.text, '保留頁尾'
    end
  end

  def test_all_migrated_articles_use_current_body_components
    pages = Dir['knowledge/know_*.html'].sort
    assert_equal 62, pages.length

    pages.each do |page|
      doc = Nokogiri::HTML(File.read(page))
      body = doc.at_css('.know-article-body')

      assert body&.at_css('.know-article-content'), "missing article content: #{page}"
      refute body.at_css('header.meta,.share-buttons,.info-banner,.clearfix'), "legacy controls remain: #{page}"
      assert doc.at_css('.know-reviewer-link[href]'), "missing reviewer link: #{page}"
      body.css('.know-article-toc a[href^="#"]').each do |link|
        assert body.at_css(link['href']), "broken table of contents link #{link['href']}: #{page}"
      end
    end
  end
end
