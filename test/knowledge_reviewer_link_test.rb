require 'minitest/autorun'
require 'nokogiri'

class KnowledgeReviewerLinkTest < Minitest::Test
  REVIEWER_PATHS = {
    '曾吉杉醫師' => '../taichung/dr-tseng-ji-san.html',
    '薛青坡醫師' => '../taichung/dr-hsueh-ching-po.html',
    '陳嘉豪醫師' => '../taichung/dr-chen-chia-hao.html',
    '莊禮駿醫師' => '../taichung/dr-chuang-li-chun.html',
    '許瑛祺醫師' => '../taichung/dr-hsu-ying-chi.html',
    '朱明輝醫師' => '../taichung/dr-chu-ming-hui.html',
    '柳朝升醫師' => '../zhushan/team/dr-liu-chao-sheng.html'
  }.freeze

  def test_every_knowledge_article_links_its_reviewer_to_the_profile_page
    pages = Dir['knowledge/*.html'].sort
    assert_equal 74, pages.length

    pages.each do |page|
      doc = Nokogiri::HTML(File.read(page))
      organizer = doc.at_css('.know-article-meta span:nth-child(3)')
      link = doc.at_css('.know-article-meta span:nth-child(4) a.know-reviewer-link')

      assert_equal '內容整理：生活牙醫診所', organizer&.text&.strip, "missing content organizer: #{page}"
      refute_nil link, "missing reviewer link: #{page}"
      assert_equal REVIEWER_PATHS.fetch(link.text.strip), link['href'], page
      assert File.file?(File.expand_path(link['href'], File.dirname(page))), "missing reviewer page: #{page}"
    end
  end

  def test_component_library_documents_the_reviewer_link
    element = File.read('element.html')
    css = File.read('css/style.css')

    assert_includes element, 'class="know-reviewer-link"'
    assert_includes element, '&lt;a class="know-reviewer-link"'
    assert_includes element, '<code>know-reviewer-link</code>'
    assert_includes css, '.know-reviewer-link{'
  end
end
